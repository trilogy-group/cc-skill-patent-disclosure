# Bad Fixture: Deliberately Failing Disclosure

## 1. Executive Summary

This fixture is intentionally broken so the validator's failure paths are exercised by `tests/run-smoke.sh`. It has:
- Only 2 sections (canonical coverage check fails)
- Zero diagrams (mandated-diagram check fails)
- Duplicate H2 headers (structural check fails)
- A leftover `DIAGRAM_BLOCKED:` sentinel (means a section generator gave up)

## 1. Executive Summary

(Duplicate header — the validator must catch this.)

## 6. What It Does and How It Works

DIAGRAM_BLOCKED: system_architecture — synthetic test sentinel; the validator should fail when this is present.
