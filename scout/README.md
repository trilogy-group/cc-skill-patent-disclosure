# repo-scout

A patent-candidate discovery agent. Runs on a cron, scans a curated list
of repos, and pushes candidate inventions into Patents Manager as
`Ideating` rows tagged `source = "scout"`.

## What's in this directory

| File | Purpose |
| --- | --- |
| `watchlist.yaml` | The curated list of repos to scan. Edit this to add/remove repos. |
| `runner.ts` | The orchestrator. Reads the watchlist, clones each due repo, invokes Claude headlessly, parses candidates, POSTs them to Patents Manager. |
| `prompts/explore.md` | The prompt Claude reads. Defines what counts as patentable, the JSON output shape, and the bias toward strictness. |

## Adding a repo

1. Open a PR editing `scout/watchlist.yaml`.
2. Add an entry under `repos:` with:
   - `name` — short identifier (used as the slug prefix on candidates)
   - `git` — clone URL (SSH preferred for private repos)
   - `business_unit` — CNU / Andy's Group / Samy's Group / Non Education
   - `enabled: true`
   - optional: `project`, `schedule` (weekly | monthly | manual), `confidence_min` (low | medium | high)
3. Merge → next scheduled cron run will scan it.

## Required secrets (in this repo's GitHub Actions secrets)

| Secret | Used for |
| --- | --- |
| `PATENTS_API_TOKEN` | A `disclosures:write` PAT issued from `https://patents.ti.trilogy.com/settings/tokens`. Long-lived. Recommended name: `repo-scout`. |
| `ANTHROPIC_API_KEY` | For `claude -p` headless mode. |
| `SCOUT_DEPLOY_KEY` (optional) | SSH private key with read-only access to the listed private repos. Alternative: a GitHub App token. |

Optional repository variable: `PATENTS_API_URL` (defaults to `https://patents.ti.trilogy.com`).

## How idempotency works

Every candidate is POSTed with `plugin_slug = <repo-name>-<candidate-slug>`.
The Patents Manager API is idempotent on `plugin_slug` — second run on
unchanged candidates returns 200 with the existing row, never duplicates.

The runner ALSO records the repo's HEAD SHA in `ids_json.last_sha`. Before
scanning, it queries the manager for prior scout rows on this repo; if any
of them are at the same SHA, it skips the run entirely (no point running
Claude when nothing changed).

## Manual run / one-off scan

```bash
# Full scan of all due repos:
npx tsx scout/runner.ts

# Scan a single repo by name (overrides "due" check via FORCE):
ONLY_REPO=comic-creator FORCE=1 npx tsx scout/runner.ts
```

## Cost shape

Each repo's scan is one `claude -p` invocation reading enough of the
codebase to score candidates. With the bias-toward-strictness prompt, most
runs produce 0–1 candidates and use a few hundred thousand tokens. Cost
controls in the watchlist:

- `enabled: false` — kill switch.
- `schedule: monthly` — most repos shouldn't need weekly.
- `confidence_min: high` — drops noisy repos' contribution.

## Where the output lands

Each new candidate becomes an `Ideating` row in Patents Manager:
- `source = "scout"`
- `current_status_notes` = the 1-page brief from Claude
- `inventors` = top 5 git-blame contributors of the relevant files
- `ids_json` = `{ repo_name, repo_url, last_sha, confidence, files, scanned_at }`

The dashboard hides scout rows by default — toggle "Show scout candidates"
to see them. Filter chip is in the dashboard filter row.
