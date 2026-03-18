# Project Guidelines

## Code Quality
Mandatory: SRP, no magic values, descriptive names, error handling on boundaries,
max 40 lines / 3 params / 3 nesting, no duplication, YAGNI, Law of Demeter, AAA tests.
Prefer: KISS (simplest solution wins), deep modules, composition over inheritance,
strategic programming. See CODE_PRINCIPLES.md for full details.

## Behavioral Rules
- Never guess versions, APIs, or config syntax from training knowledge — always research first (see Tool Workflow below).
- When a task feels too complex or requires touching many files, stop and ask before proceeding.
- When encountering an unfamiliar pattern in the codebase, use LSP to understand it before modifying it.
- Before creating any abstraction, ask: does the current task require this? If not, don't build it.
- When stuck or confused for more than 2 attempts at the same problem, say so explicitly.
- Prefer modifying existing patterns over introducing new ones.
- Always request local code review (`superpowers:code-reviewer`) before committing.

## Alpaca API Gotchas
- Paper trading is the DEFAULT. Never switch to live (`APCA_PAPER=false`) without explicit user confirmation.
- Auth uses separate key pairs per environment:
  - Paper: `APCA_PAPER_KEY` + `APCA_PAPER_SECRET_KEY`
  - Live: `APCA_REAL_KEY` + `APCA_REAL_SECRET_KEY`
  - Fallback: `APCA_API_KEY_ID` + `APCA_API_SECRET_KEY`
  - `_lib.sh` auto-resolves based on `APCA_PAPER` env var.
- Auth headers are `APCA-API-KEY-ID` and `APCA-API-SECRET-KEY` — NOT `Authorization: Bearer`.
- All monetary values from Alpaca are strings (not floats) — preserve as strings, never parse to float in bash.
- Order quantities: `qty` is shares (integer/decimal), `notional` is dollar amount (string) — never mix them.
- Timestamps are RFC 3339 (e.g., `2024-01-15T09:30:00Z`) — not Unix epoch.
- Rate limit: 200 req/min free tier. Scripts check for HTTP 429 and report clearly.
- Pagination uses `page_token` / `next_page_token`, not offset-based.
- Crypto symbols use slash format: `BTC/USD`, not `BTCUSD`. Auto-normalized by `alpaca_data_crypto.sh`.
- Crypto API uses query params (`?symbols=BTC/USD`), NOT per-symbol path segments. Stock API uses per-symbol paths (`/v2/stocks/AAPL/bars`). This is why `alpaca_data_crypto.sh` has its own URL construction instead of delegating to `_data_lib.sh`.
- Crypto orders only support `market`, `limit`, `stop_limit` types with `gtc` and `ioc` TIF.
- Options use OCC contract format: `AAPL250321C00185000` (SYMBOL + YYMMDD + C/P + STRIKE*1000).
- Options API uses `/v1beta1/options` prefix with multi-symbol query params.
- `--limit` flag values must be validated as positive integers before interpolating into jq expressions (prevents jq injection).
- Bulk cancel/close endpoints return HTTP 207 multi-status, not 200/204.

## Testing
- Run `bash tests/run_tests.sh` to run all tests (158 assertions across 4 suites)
- Run `shellcheck scripts/*.sh` to lint all scripts
- Tests mock `curl` — no real API calls in unit tests
- Integration tests require paper credentials in `.env` (see `.env.example`)

## Tool Workflow
- **Research**: Context7 (`resolve-library-id` → `query-docs`) → Tavily (`tavily_search`, `tavily_extract`, `tavily_research`, `tavily_crawl`, `tavily_map`) → OpenMemory (`openmemory query`). Never use built-in WebSearch or WebFetch.
- **Spec**: `/opsx:new` → `/opsx:ff` → review → implement → `/opsx:verify` → `/opsx:archive`
- **Plan & Execute**: `/superpowers:brainstorm` → `/superpowers:write-plan` → `/superpowers:execute-plan`
- **Review**: `superpowers:code-reviewer` before every commit. `coderabbit:code-review` for PR-level review.
- **Navigate**: LSP (`goToDefinition`, `findReferences`, `documentSymbol`, `workspaceSymbol`) — prefer over grep. Requires `ENABLE_LSP_TOOL=1`.
- **Test**: Playwright for E2E and visual validation.

## OpenMemory Checkpoints
**Mandatory** — do not skip. Query before starting, store after completing.

| When | Action |
|------|--------|
| Before `/opsx:new`, `/opsx:ff`, `/fix` | `openmemory query "<topic> patterns" --limit 5` |
| After `/opsx:ff`, `/opsx:continue` (artifacts done) | Store design summary and key decisions |
| During `/opsx:apply` (every 3–4 tasks) | Store progress, surprises, deviations |
| After `/opsx:verify` | Store findings (pass/fail, issues, fixes) |
| After `/opsx:archive` | Store completion record, patterns learned, follow-ups |
| After `/superpowers:brainstorm` | Store chosen approach, rejected alternatives, and why |
| After `/superpowers:write-plan` | Store plan summary, key architectural decisions |
| After `/superpowers:execute-plan` batch | Store what was built, deviations from plan |
| After code review (superpowers or coderabbit) | Store non-obvious issues that apply beyond the current PR |
| After `/fix` confirmed | Store error pattern, root cause, resolution |
| On `/resume` or session start | `openmemory query "recent context $REPO" --limit 5` |
| Before context compacts | Store any unsaved decisions or findings |

## Workflows
- `/work-local "<description>"` — full pipeline from spec to PR
- `/resume` — pick up where you left off
- `/fix "<bug>"` — debug and fix workflow

## Documentation Updates
After every implementation, check and update: README.md, CHANGELOG.md, API docs, CLAUDE.md, OpenSpec specs.

## Git
Branch: `feature/short-desc` | Commit: `type(scope): desc` | PR against `main`
