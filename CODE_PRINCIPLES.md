# Code Principles

Single source of truth for code quality standards in alpaca-skill.
Referenced by CLAUDE.md, CodeRabbit, OpenSpec, and implementation subagents.

## Hard Rules (must follow — violations are review blockers)

### 1. Single Responsibility
Every function does one thing. If a function needs "and" in its description, split it.
```bash
# BAD: fetch_and_format_account() — fetches account data AND formats it
# GOOD: fetch_account() + format_account_output()
```

### 2. No Magic Values
All literals that aren't self-evident (0, 1, "", true/false) must be named constants.
```bash
# BAD: curl -m 30 ...
# GOOD: readonly HTTP_TIMEOUT=30; curl -m "$HTTP_TIMEOUT" ...
```

### 3. Descriptive Names
Names reveal intent. No abbreviations, no generic names (data, info, item, temp, result).
Use snake_case for variables and functions per bash convention.
```bash
# BAD: local d; local res
# GOOD: local account_data; local order_response
```

### 4. Error Handling on Boundaries
Every HTTP call, file read, and external command must have explicit error handling.
```bash
# BAD: response=$(curl -s "$url")
# GOOD: response=$(_api_get "$endpoint") || { echo "..." >&2; return 1; }
```

### 5. Function Length ≤ 40 Lines
If a function exceeds 40 lines, decompose it. Long functions hide bugs.

### 6. Parameter Count ≤ 3
Functions with more than 3 positional parameters → use a subcommand pattern or named flags.

### 7. Nesting ≤ 3 Levels
Maximum 3 levels of nesting. Use early returns, extraction, or guard clauses.
```bash
# BAD: if ...; then if ...; then if ...; then ...
# GOOD: [[ -z "$var" ]] && { echo "error" >&2; return 1; }
```

### 8. No Duplicated Logic
If the same logic appears in 2+ places, extract it into a shared function in `_lib.sh`.

### 9. YAGNI
Only build what the current task requires. No speculative abstractions.

### 10. Law of Demeter
Functions interact with their direct inputs only. Don't chain through nested data structures.

### 11. Input Validation
User-provided values must be validated before interpolating into jq or shell expressions.
Integers must match `^[0-9]+$`. Strings must be passed via `--arg` to jq, never interpolated.
```bash
# BAD: jq ".[0:$limit]" — limit could be injected
# GOOD: validate [[ "$limit" =~ ^[0-9]+$ ]] first, or use jq --argjson
```

### 12. Exit Codes
Exit 0 for success (results on stdout), exit 1 for errors (messages on stderr).

## Soft Guidelines (prefer — deviation acceptable with justification)

### A. KISS
Pick the simplest solution that works. Three similar lines > a premature abstraction.

### B. Deep Modules
Scripts present a simple CLI interface (subcommand + flags) hiding complex API interaction.

### C. Consistent Output
All scripts output raw JSON on stdout. Use `alpaca_format.sh` for human-readable output.

### D. Idempotent Operations
GET operations are inherently safe. POST/DELETE operations should be clearly documented.

### E. Fail Fast
Validate required parameters and env vars at function entry, not deep in logic.

### F. Security First
- Never log or echo API keys
- Never put credentials in URLs (use headers)
- Default to paper trading
- No eval, no command injection vectors

### G. Pagination Handling
Use `_paginate` helper from `_lib.sh` for all list endpoints. Cap at MAX_PAGES.

### H. Test Coverage
Each script should have corresponding tests in `tests/` using bash assertions.
Tests follow Arrange-Act-Assert. Each test covers one behavior.
