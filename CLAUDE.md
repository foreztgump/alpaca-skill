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
- Paper trading is the DEFAULT. Never switch to live (`APCA_PAPER=false`) without explicit user confirmation.
- Alpaca auth headers are `APCA-API-KEY-ID` and `APCA-API-SECRET-KEY` — NOT `Authorization: Bearer`.
- All monetary values from Alpaca are strings (not floats) — preserve as strings, never parse to float in bash.
- Alpaca order quantities: `qty` is shares (integer), `notional` is dollar amount (string) — never mix them.
- Alpaca timestamps are RFC 3339 (e.g., `2024-01-15T09:30:00Z`) — not Unix epoch.
- Rate limit: 200 req/min free tier. Scripts must check for HTTP 429 and report clearly.
- Market data pagination uses `page_token` parameter, not offset-based.
- Crypto symbols use slash format in API: `BTC/USD`, not `BTCUSD`.

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
