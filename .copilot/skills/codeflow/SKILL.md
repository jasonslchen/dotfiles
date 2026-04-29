---
name: codeflow
description: >-
    Skill for using the codeflow CLI to analyze codebases — visualize call graphs,
    trace function execution paths, search symbols across languages, and answer
    natural-language questions about how code works. Use when the user asks to
    trace a function, find what calls/imports something, explore code paths,
    visualize a flow, search for symbols, or understand how a feature works.
user-invocable: false
---

# Codeflow — Code Path Analyzer

Codeflow is a CLI tool that statically analyzes codebases and produces:
- Call graphs (which functions call which)
- Dependency graphs (which modules import which)
- Symbol indexes (searchable across the project)
- Branch-pruned traces (which paths run given parameter constraints)

Native support: **Python, JavaScript, TypeScript, Go, Java**.
AI-extracted (opt-in): Ruby, Rust, Swift, Kotlin, C/C++, C#, PHP, Scala, Dart, Elixir, etc.

The binary lives at: `/Users/jasonslchen/projects/codeflow/.venv/bin/codeflow`

## When to use codeflow

| User wants… | Run |
|---|---|
| "How does X work?" / "What happens when…?" | `codeflow ask "..."` |
| "What does function Y call?" | `codeflow trace file.py:Y` |
| "Find all functions doing X" | `codeflow search "X"` |
| "What does file Z import?" | `codeflow deps file.py` |
| "What runs if param=X?" | `codeflow trace file:fn --params '{"X": ...}'` |
| Visualize a flow | append `--render ascii` (terminal) or `--format mermaid` |

Prefer `codeflow ask` when the entrypoint isn't known — it does NL parse → search → rank → trace in one step. Prefer `codeflow trace` when you already know `file.py:function_name`.

**Always run from the project root** (cd to it first). Codeflow auto-detects via `.git`, `pyproject.toml`, `package.json`, etc.

## Core commands

### `codeflow ask "<natural language question>"`

Best for exploratory / NL queries.

Options:
- `--render ascii` — terminal box-drawing diagram (preferred for in-CLI viewing)
- `--render tree` — Rich tree view
- `--depth N` — max trace depth (default 5)
- `--params '{"key": value}'` — explicit param constraints (else extracted from query)
- `--ai` — use AI to rerank candidate entrypoints
- `--no-extract-params` — disable auto param extraction

Examples:
```
codeflow ask "how does payment handle expired cards" --render ascii
codeflow ask "what happens when user submits POST /api/orders"
codeflow ask "trace check_fraud with amount > 10000"
```

Output: prints the parsed query, selected entrypoint, branch decisions (if params), and the diagram.

### `codeflow trace <file>:<function> [options]`

Direct trace from a known entrypoint.

Options:
- `--depth N`, `--max-fanout N`, `--no-externals`
- `--params '{"key": value}'` — branch-prune given concrete inputs
- `--render ascii|tree|table`
- `--format mermaid|json` (when not using --render)

Examples:
```
codeflow trace payments.py:process_payment --render ascii
codeflow trace payments.py:process_payment --params '{"expired": true}' --render ascii
```

When `--params` is used, output shows ✅ taken / ❌ not_taken / ❓ unknown for each conditional, plus pruned calls.

### `codeflow search "<query>"`

Fuzzy symbol search across the project.

Options:
- `--limit N` (default 15)
- `--kind function|method|class|module|route`
- `--format text|json`
- `--enrich` — add AI one-line descriptions (costs API calls, cached)

Examples:
```
codeflow search "payment validation"
codeflow search "POST /api" --kind route
codeflow search "expired" --enrich
```

### `codeflow deps <file>`

Import / dependency graph for a file.

Options: `--depth`, `--no-externals`, `--render`, `--format`

### `codeflow index [options]`

Build/refresh the project symbol index. Usually unnecessary — other commands index lazily.

Options:
- `--force` — rebuild from scratch
- `--ai-extract` — enable AI fallback for unsupported languages
- `--enrich` — generate AI descriptions for all symbols

## Output rendering for the terminal

For in-CLI display, prefer `--render ascii` — it produces text-only Unicode box-drawing diagrams that are readable in any terminal:

```
┌───────────────┐
│process_payment│
│payments.py:42 │
└───────────────┘
        │
 ┌──────┴────────┐
 ▼               ▼
┌─────────┐  ┌─────────┐
│validate │  │charge   │
└─────────┘  └─────────┘

── Cross-references ──
  ↺ helper → utils [calls]
```

Other formats:
- `--format mermaid` — for embedding in markdown (default when `--render` not set)
- `--format json` — structured data for further processing

## Behaviors and guarantees

- **Static analysis grounds the trace.** AI is opt-in via `--ai` for ranking only — never invents symbols.
- **AI-extracted symbols are validated.** Names must appear literally in source.
- **Caching is automatic.** Per-file segmented cache (`.codeflow/segments/`) and content-hash AI cache (`.codeflow/ai_cache/`) live in the project root. Both should be gitignored.
- **Branch tracing is constrained, not symbolic.** Handles boolean checks, comparisons, `is None`, `and`/`or`, `not`. Unknown branches are explicit (❓), never silently chosen.
- **Multi-language indexing works for search/listing.** Call graph tracing is currently Python-only.

## Common workflows

**1. User asks "how does X work" in a codebase you haven't seen:**
```bash
cd <project>
codeflow ask "how does X work" --render ascii
```
Read the output. Then optionally drill in by reading the files codeflow surfaced.

**2. User asks about a specific code path with parameters:**
```bash
codeflow trace path/to/file.py:function_name --params '{"key": value}' --render ascii
```
The branch report will show which conditionals are taken/skipped.

**3. User asks "what calls foo":** (reverse lookup not supported directly — use search)
```bash
codeflow search "foo"   # find foo
# then trace each candidate caller
```

**4. User wants AI-described symbols (for unfamiliar code):**
```bash
codeflow search "<concept>" --enrich
```

**5. Project includes Ruby/Rust/Swift/etc:**
```bash
codeflow index --ai-extract --enrich
codeflow search "<query>"
```

## Notes

- Codeflow installed in a Python venv. Always use the absolute path
  `/Users/jasonslchen/projects/codeflow/.venv/bin/codeflow`.
- For very large repos, the first index can be slow; subsequent runs use the segmented cache.
- If a query returns "needs clarification", surface the closest matches to the user and ask which they meant.
