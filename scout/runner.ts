#!/usr/bin/env tsx
/**
 * repo-scout — patent-candidate discovery agent.
 *
 * Reads scout/watchlist.yaml, clones each enabled repo whose schedule is
 * due, runs `claude -p <explore-prompt>` headlessly inside the clone,
 * parses the JSON candidates Claude emits, and POSTs each new candidate
 * into Patents Manager via the public REST API.
 *
 * Idempotency: every POST uses `plugin_slug = <repo-name>-<candidate-slug>`.
 * The manager's POST handler is idempotent on plugin_slug — second run
 * returns 200 (existing) instead of inserting a duplicate.
 *
 * Required env:
 *   PATENTS_API_URL    — e.g. https://patents.ti.trilogy.com
 *   PATENTS_API_TOKEN  — a `disclosures:write` PAT
 *   ANTHROPIC_API_KEY  — for Claude Code headless mode
 *
 * Optional:
 *   WATCHLIST_PATH     — path to watchlist.yaml (default: scout/watchlist.yaml)
 *   ONLY_REPO          — if set, scan ONLY this named repo (for manual runs)
 *   FORCE              — "1" to bypass the schedule + already-scanned check
 */

import { execSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import yaml from "js-yaml";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type Schedule = "weekly" | "monthly" | "manual";
type Confidence = "low" | "medium" | "high";

type RepoEntry = {
  name: string;
  git: string;
  business_unit?: string;
  project?: string;
  enabled?: boolean;
  schedule?: Schedule;
  confidence_min?: Confidence;
  max_tokens?: number;
  notes?: string;
};

type Watchlist = {
  version: number;
  defaults?: Partial<RepoEntry>;
  repos: RepoEntry[];
};

type Candidate = {
  slug: string;
  title: string;
  brief: string;
  confidence: Confidence;
  files: string[];
};

// ---------------------------------------------------------------------------
// Config + env
// ---------------------------------------------------------------------------

const SCOUT_DIR = path.dirname(new URL(import.meta.url).pathname);
const WATCHLIST_PATH = process.env.WATCHLIST_PATH || path.join(SCOUT_DIR, "watchlist.yaml");
const PROMPT_PATH = path.join(SCOUT_DIR, "prompts", "explore.md");

const API_URL = (process.env.PATENTS_API_URL || "").replace(/\/$/, "");
const API_TOKEN = process.env.PATENTS_API_TOKEN || "";
const ONLY_REPO = process.env.ONLY_REPO || "";
const FORCE = process.env.FORCE === "1";

if (!API_URL) die("PATENTS_API_URL is required");
if (!API_TOKEN) die("PATENTS_API_TOKEN is required");
if (!process.env.ANTHROPIC_API_KEY) {
  console.warn("[scout] ANTHROPIC_API_KEY is not set — `claude -p` will fail.");
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const watchlist = loadWatchlist(WATCHLIST_PATH);
  const explorePrompt = readFileSync(PROMPT_PATH, "utf8");

  const summary: { repo: string; outcome: string; candidates_new: number; candidates_existing: number; error?: string }[] = [];

  for (const raw of watchlist.repos) {
    const repo = withDefaults(raw, watchlist.defaults || {});
    if (!repo.enabled) {
      summary.push({ repo: repo.name, outcome: "disabled", candidates_new: 0, candidates_existing: 0 });
      continue;
    }
    if (ONLY_REPO && repo.name !== ONLY_REPO) {
      continue;
    }
    try {
      const r = await scanRepo(repo, explorePrompt);
      summary.push({ repo: repo.name, ...r });
    } catch (e) {
      const msg = (e as Error).message;
      console.error(`[${repo.name}] ERROR: ${msg}`);
      summary.push({ repo: repo.name, outcome: "error", candidates_new: 0, candidates_existing: 0, error: msg });
    }
  }

  // Print summary as a final block — the cron output captures this.
  console.log("\n=== scout summary ===");
  console.table(summary);
  const errors = summary.filter((s) => s.outcome === "error").length;
  if (errors > 0) {
    console.error(`[scout] ${errors} repo(s) errored.`);
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
// Per-repo scan
// ---------------------------------------------------------------------------

async function scanRepo(
  repo: Required<Pick<RepoEntry, "name" | "git" | "business_unit" | "schedule" | "confidence_min">> & RepoEntry,
  explorePrompt: string,
): Promise<{ outcome: string; candidates_new: number; candidates_existing: number }> {
  console.log(`\n[${repo.name}] starting scan (${repo.schedule}, min=${repo.confidence_min})`);

  // 1. Schedule gate.
  if (!FORCE && !isDue(repo)) {
    console.log(`[${repo.name}] not due (schedule=${repo.schedule}); skipping`);
    return { outcome: "not-due", candidates_new: 0, candidates_existing: 0 };
  }

  // 2. Clone shallow.
  const workdir = mkdtempSync(path.join(tmpdir(), `scout-${repo.name}-`));
  try {
    run(`git clone --depth 50 --quiet ${shellQuote(repo.git)} ${shellQuote(workdir)}`);
    const head = run(`git -C ${shellQuote(workdir)} rev-parse HEAD`).trim();
    console.log(`[${repo.name}] HEAD=${head.slice(0, 8)}`);

    // 3. Skip if we've already created rows for this repo at this SHA.
    if (!FORCE) {
      const alreadyScanned = await alreadyScannedAtSha(repo.name, head);
      if (alreadyScanned) {
        console.log(`[${repo.name}] HEAD already scanned; skipping`);
        return { outcome: "unchanged-sha", candidates_new: 0, candidates_existing: 0 };
      }
    }

    // 4. Run Claude headlessly.
    const candidates = await invokeClaude(workdir, explorePrompt, repo.name);

    // 5. Filter by confidence threshold.
    const minRank = rankConfidence(repo.confidence_min);
    const filtered = candidates.filter((c) => rankConfidence(c.confidence) >= minRank);
    if (filtered.length < candidates.length) {
      console.log(`[${repo.name}] filtered ${candidates.length - filtered.length} low-confidence candidate(s)`);
    }

    // 6. POST each candidate.
    let newRows = 0;
    let existingRows = 0;
    for (const c of filtered) {
      const slug = `${repo.name}-${c.slug}`.replace(/[^a-z0-9-]/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "");
      const inventors = gitBlameInventors(workdir, c.files);
      const res = await postDisclosure({
        slug,
        repo,
        head,
        candidate: c,
        inventors,
      });
      if (res === "created") newRows++;
      else if (res === "existing") existingRows++;
    }

    console.log(`[${repo.name}] done — ${newRows} new, ${existingRows} existing, ${filtered.length} total`);
    return { outcome: "scanned", candidates_new: newRows, candidates_existing: existingRows };
  } finally {
    try { rmSync(workdir, { recursive: true, force: true }); } catch { /* best effort */ }
  }
}

// ---------------------------------------------------------------------------
// Schedule helpers
// ---------------------------------------------------------------------------

function isDue(repo: { name: string; schedule: Schedule }): boolean {
  // Crude scheduler. Stateless: we use the current day-of-week / day-of-month
  // as the trigger. Cron fires daily; this gates which repos actually scan.
  const now = new Date();
  switch (repo.schedule) {
    case "weekly":
      // Run on Sundays.
      return now.getUTCDay() === 0;
    case "monthly":
      // Run on the 1st.
      return now.getUTCDate() === 1;
    case "manual":
      return false;
    default:
      return false;
  }
}

// ---------------------------------------------------------------------------
// Manager API
// ---------------------------------------------------------------------------

async function alreadyScannedAtSha(repoName: string, sha: string): Promise<boolean> {
  // Lookup by plugin_slug pattern would be ideal; for v1 we use the lookup
  // endpoint with the FIRST candidate's anticipated slug — but we don't know
  // the candidate slugs yet. Instead, list rows where source=scout and
  // disclosure_title contains repoName (cheap, approximate). If any of them
  // have ids_json.last_sha == sha, we've already scanned.
  //
  // The list endpoint doesn't filter by ids_json shape, so we fetch the
  // (small) set of scout rows for this repo and inspect client-side.
  const resp = await fetch(`${API_URL}/api/v1/disclosures?limit=200`, {
    headers: { Authorization: `Bearer ${API_TOKEN}` },
  });
  if (!resp.ok) {
    console.warn(`[scout] could not list disclosures (${resp.status}); proceeding without skip`);
    return false;
  }
  const body = (await resp.json()) as { data: Array<{ source?: string; ids_json?: Record<string, unknown> | null; plugin_slug?: string | null }> };
  for (const row of body.data || []) {
    if (row.source !== "scout") continue;
    if (!row.plugin_slug?.startsWith(`${repoName}-`)) continue;
    const sha2 = (row.ids_json as { last_sha?: string } | null)?.last_sha;
    if (sha2 === sha) return true;
  }
  return false;
}

type PostResult = "created" | "existing" | "error";

async function postDisclosure(args: {
  slug: string;
  repo: RepoEntry & { business_unit: string };
  head: string;
  candidate: Candidate;
  inventors: { name?: string; email?: string }[];
}): Promise<PostResult> {
  const body = {
    business_unit: args.repo.business_unit,
    disclosure_title: args.candidate.title,
    plugin_slug: args.slug,
    source: "scout",
    project: args.repo.project ?? null,
    inventors: args.inventors,
    current_status_notes: args.candidate.brief,
    ids_json: {
      source: "scout",
      repo_name: args.repo.name,
      repo_url: args.repo.git,
      last_sha: args.head,
      confidence: args.candidate.confidence,
      files: args.candidate.files,
      scanned_at: new Date().toISOString(),
    },
  };
  const resp = await fetch(`${API_URL}/api/v1/disclosures`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${API_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (resp.status === 201) {
    console.log(`  + NEW   ${args.slug} — ${args.candidate.title}`);
    return "created";
  }
  if (resp.status === 200) {
    console.log(`  · seen  ${args.slug}`);
    return "existing";
  }
  const txt = await resp.text();
  console.error(`  ! FAIL  ${args.slug}  (${resp.status}) ${txt.slice(0, 200)}`);
  return "error";
}

// ---------------------------------------------------------------------------
// Claude headless invocation
// ---------------------------------------------------------------------------

async function invokeClaude(workdir: string, prompt: string, repoName: string): Promise<Candidate[]> {
  const result = spawnSync("claude", ["-p", prompt], {
    cwd: workdir,
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024,
    timeout: 30 * 60 * 1000, // 30 min hard cap per repo
  });
  if (result.status !== 0) {
    throw new Error(`claude -p failed (exit ${result.status}): ${result.stderr.slice(0, 500)}`);
  }
  return parseCandidates(result.stdout, repoName);
}

function parseCandidates(stdout: string, repoName: string): Candidate[] {
  // The prompt asks for a single JSON document at the end. Find the last
  // {"candidates": ...} block and parse that.
  const m = stdout.match(/\{[\s\S]*"candidates"\s*:\s*\[[\s\S]*\][\s\S]*\}/);
  if (!m) {
    console.warn(`[${repoName}] no JSON candidates block found in output; treating as empty`);
    return [];
  }
  let parsed: { candidates?: Candidate[] };
  try {
    parsed = JSON.parse(m[0]);
  } catch (e) {
    throw new Error(`Could not parse JSON: ${(e as Error).message}. First 200 chars: ${m[0].slice(0, 200)}`);
  }
  return Array.isArray(parsed.candidates) ? parsed.candidates : [];
}

// ---------------------------------------------------------------------------
// Inventors via git blame
// ---------------------------------------------------------------------------

function gitBlameInventors(workdir: string, files: string[]): { name?: string; email?: string }[] {
  // Aggregate authors across the named files; cap at top 5 by line count.
  const counts = new Map<string, { name: string; email: string; lines: number }>();
  for (const f of files) {
    let blame: string;
    try {
      blame = run(`git -C ${shellQuote(workdir)} blame --line-porcelain -- ${shellQuote(f)}`, { silent: true });
    } catch {
      continue; // file may have been moved or never existed
    }
    let curName = "";
    let curEmail = "";
    for (const line of blame.split("\n")) {
      if (line.startsWith("author ")) curName = line.slice(7);
      else if (line.startsWith("author-mail ")) curEmail = line.slice(12).replace(/[<>]/g, "");
      else if (line.startsWith("\t")) {
        if (curEmail) {
          const key = curEmail.toLowerCase();
          const e = counts.get(key);
          if (e) e.lines += 1;
          else counts.set(key, { name: curName, email: curEmail, lines: 1 });
        }
      }
    }
  }
  return [...counts.values()]
    .sort((a, b) => b.lines - a.lines)
    .slice(0, 5)
    .map((c) => ({ name: c.name || undefined, email: c.email || undefined }));
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function loadWatchlist(p: string): Watchlist {
  const w = yaml.load(readFileSync(p, "utf8")) as Watchlist;
  if (!w || !Array.isArray(w.repos)) throw new Error(`watchlist at ${p} is invalid`);
  return w;
}

function withDefaults(
  repo: RepoEntry,
  defaults: Partial<RepoEntry>,
): Required<Pick<RepoEntry, "name" | "git" | "business_unit" | "schedule" | "confidence_min">> & RepoEntry {
  return {
    ...defaults,
    ...repo,
    schedule: (repo.schedule || defaults.schedule || "weekly") as Schedule,
    confidence_min: (repo.confidence_min || defaults.confidence_min || "medium") as Confidence,
    business_unit: (repo.business_unit || defaults.business_unit || "CNU") as string,
  };
}

function rankConfidence(c: Confidence): number {
  return c === "high" ? 3 : c === "medium" ? 2 : 1;
}

function run(cmd: string, opts?: { silent?: boolean }): string {
  try {
    return execSync(cmd, { encoding: "utf8", stdio: opts?.silent ? "pipe" : ["pipe", "pipe", "inherit"] });
  } catch (e) {
    throw new Error(`command failed: ${cmd}\n${(e as Error).message}`);
  }
}

function shellQuote(s: string): string {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

function die(msg: string): never {
  console.error(`[scout] ${msg}`);
  process.exit(2);
}

main().catch((e) => {
  console.error("[scout] fatal:", e);
  process.exit(1);
});
