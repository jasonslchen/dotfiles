---
name: codeflow
description: >-
    Use any time the user asks to draw, render, or generate a diagram,
    chart, flowchart, mermaid graph, or ASCII visualization OF CODE —
    including call graphs, dependency graphs, and execution traces. Also
    use for code exploration: "how does X work", "what calls Y", "trace
    this function", "find symbols matching Z". Codeflow generates diagrams
    from real static analysis (Python, Go, JavaScript, TypeScript, Java,
    C#, C, C++, PHP, Rust native; others via AI fallback). Triggers:
    "draw a diagram of...", "render as mermaid", "ASCII chart of this
    code", "call graph for", "visualize this function", "flowchart this",
    "how does X work", "what calls Y", "trace this Java method", "trace
    this Rust function", "trace this TypeScript", "trace this C#".
    Prefer this skill over hand-drawing diagrams in markdown.
user-invocable: true
---

# Codeflow — Code Path Analyzer & Diagram Generator

Codeflow statically analyzes a codebase and produces:
- Call graphs (which functions call which)
- Dependency graphs (which modules import which)
- Symbol indexes (searchable across the project)
- Branch-pruned traces (which paths run given parameter constraints)

Output formats: **ASCII** (terminal), **Mermaid** (markdown), **JSON** (programmatic).

Native (no AI required) — symbol indexing **and** call-graph tracing:

| Capability                       | Languages                                              |
|----------------------------------|--------------------------------------------------------|
| Trace + branch pruning (`--params`) | **Python, Go** (Go FF patterns: LaunchDarkly, OpenFeature, viper, `os.Getenv`) |
| Trace only (no branch pruning yet)  | **JS, TS, Java, C#, C, C++, PHP, Rust**             |

AI fallback (`--ai-extract`, symbol-only): Ruby, Swift, Kotlin, Scala, Dart, Elixir, etc.

The `codeflow` binary is on `$PATH`. From an agent context with MCP, you
can also call `codeflow-ask`, `codeflow-trace`, `codeflow-expand_node`,
`codeflow-search_symbols`, `codeflow-deps`, `codeflow-list_functions`,
`codeflow-index_project` directly — same semantics.

## Do not hand-draw code diagrams

When the user asks for a diagram, flowchart, mermaid graph, or ASCII chart
of code, **use codeflow**. Do not render the diagram yourself in markdown
from your understanding of the code. Codeflow's output is grounded in
static analysis; a hand-drawn diagram is grounded in your context window
and will lie subtly — missed edges, fabricated calls, dynamic dispatch
shown as real edges.

| User says…                                | Run (ASCII is the default)                         |
|-------------------------------------------|----------------------------------------------------|
| "draw a diagram of X" / "visualize X"     | `codeflow ask "X"`                                 |
| "call graph for `file.py:fn`"             | `codeflow trace file.py:fn`                        |
| "drill into this node"                    | `codeflow expand "<node_id>"`                      |
| User then asks for mermaid / json         | re-run with `--format mermaid` or `--format json`  |

If the code was already explored earlier in conversation, **re-trace from
source** — don't reconstruct the diagram from chat memory.

The only legitimate reason to hand-draw is when codeflow doesn't support
the language and `--ai-extract` also failed.

## ASCII-first rendering

**Default to ASCII for every diagram.** Codeflow's CLI and MCP both default
to `--render ascii` / `output_format="ascii"`. Use that default — it's
readable in any terminal and the cheapest format to render.

**After showing the ASCII output, ask the user before re-rendering** in
another format. Suggested phrasing:

> Want this in a different format? I can re-render as mermaid (for
> embedding in markdown) or json (for programmatic processing).

Re-render only when the user confirms — don't speculatively produce
multiple formats. Each codeflow invocation costs time and tokens.

## AI features require user consent

Some codeflow features send code snippets (function definitions, file
paths) to an external AI provider (Copilot SDK or GitHub Models) for
extraction, enrichment, or candidate reranking. Specifically:

- `--ai` / `use_ai=True` — AI candidate reranking on `ask`
- `--ai-extract` / `ai_extract=True` — AI symbol extraction for languages
  without a native adapter
- `--enrich` / `enrich=True` — AI one-line descriptions on indexed symbols

**Always ask the user before invoking codeflow with any of these flags
from the agent (MCP) surface.** Use this phrasing:

> Codeflow can use AI to [enrich symbols / extract symbols from
> unsupported languages / rerank candidates]. This sends code snippets
> to <copilot|github-models>. Proceed?

Wait for explicit user confirmation, then re-invoke with
`consent_granted=True` (or set `CODEFLOW_AI_CONSENT=1` for a session-wide
opt-in). Without consent the MCP tool will return
`{"error": "ai_consent_required", ...}` and refuse to call the provider.

**Direct CLI use bypasses this gate.** When the user themselves types
`codeflow ask "..." --ai` (or `--ai-extract`, or `--enrich`) at a shell,
that keystroke is the consent — the CLI runs without prompting so it
remains scriptable in CI. The consent gate exists only for the MCP path
where the agent, not the human, is choosing the flag.

## When to use codeflow

| User wants…                                | Run                                                          |
|--------------------------------------------|--------------------------------------------------------------|
| Diagram / chart / flowchart of code        | `codeflow ask "..."` (ASCII; ask before re-rendering)        |
| "How does X work?" / "What happens when…?" | `codeflow ask "..."`                                         |
| "What does function Y call?"               | `codeflow trace file.py:Y`                                   |
| Drill into a node from a previous trace    | `codeflow expand "<node_id>"`                                |
| "Find all functions doing X"               | `codeflow search "X"`                                        |
| "What does file Z import?"                 | `codeflow deps file.py`                                      |
| "What runs if param=X?" (Python + Go)      | `codeflow trace file:fn --params '{"X": ...}'`               |

Prefer `codeflow ask` when the entrypoint isn't known (it does NL parse →
search → rank → trace in one step). Prefer `codeflow trace` when you know
`file.py:function_name`.

Run from project root (or pass `--root`). Codeflow auto-detects via
`.git`, `pyproject.toml`, `package.json`, etc.

## Core commands

### `codeflow ask "<natural-language question>"`

Best for exploratory / NL queries.

Options:
- `--render ascii` — terminal box-drawing (**default**)
- `--render tree` — Rich tree view
- `--format mermaid` — for markdown embedding (only when the user asks)
- `--format json` — for programmatic processing (only when the user asks)
- `--depth N` — max trace depth (default 5)
- `--params '{"key": value}'` — explicit param constraints (else extracted from query)
- `--ai` — AI rerank of candidate entrypoints
- `--no-extract-params` — disable auto param extraction

```
codeflow ask "how does payment handle expired cards"
codeflow ask "trace check_fraud with amount > 10000"
# Only after the user confirms they want a different format:
codeflow ask "what happens when user submits POST /api/orders" --format mermaid
```

Output: parsed query, selected entrypoint, branch decisions (if params),
the diagram, and a 1–3 sentence prose summary. **Read the summary first.**

### `codeflow trace <file>:<function>`

Direct trace from a known entrypoint. Works on all 10 native languages
(Python, Go, JS, TS, Java, C#, C, C++, PHP, Rust). Method syntax:
`file.go:Type.Method`, `Foo.java:Class.method`, etc.

Options: `--depth`, `--max-fanout`, `--no-externals`,
`--params '{"key": value}'` (**Python + Go only**),
`--render ascii|tree|table`, `--format mermaid|json`.

```
codeflow trace payments.py:process_payment --render ascii
codeflow trace payments.py:process_payment --params '{"expired": true}' --render ascii
codeflow trace main.go:main --format mermaid
codeflow trace service/handler.go:Handler.Handle --render ascii
```

With `--params` (Python + Go), output shows ✅ taken / ❌ not_taken / ❓
unknown for each conditional, plus pruned calls. Go branch pruning
recognizes feature-flag patterns (LaunchDarkly, OpenFeature, viper,
`os.Getenv`).

### `codeflow expand <node_id>`

Drill into a specific node from a previous `trace`/`ask` without
re-running the whole trace. Use the node ID from JSON output (e.g.
`src/foo.py:Class.method`). UNRESOLVED and EXTERNAL nodes can't be
expanded.

```
codeflow expand "src/codeflow/index/symbol_index.py:SymbolIndexer._extract_for_path" --render ascii
```

Same options as `trace`.

### `codeflow search "<query>"`

Fuzzy symbol search.

Options: `--limit N`, `--kind function|method|class|module|route`,
`--format text|json`, `--enrich` (AI descriptions, cached).

```
codeflow search "payment validation"
codeflow search "POST /api" --kind route
codeflow search "expired" --enrich
```

### `codeflow deps <file>`

Import / dependency graph for a file. Options: `--depth`, `--no-externals`,
`--render`, `--format`.

### `codeflow index`

Build/refresh the symbol index. Usually unnecessary — other commands
index lazily. Options: `--force`, `--ai-extract` (enable AI fallback for
unsupported languages), `--enrich` (AI symbol descriptions).

## Rendering

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

Format selection (ASCII is the default — see "ASCII-first rendering"):
- `--render ascii` — default; responsive (horizontal for small graphs, vertical tree `├──` when fanout is wide)
- `--format mermaid` — only when the user asks for markdown-embeddable output
- `--format json` — only when the user asks for programmatic output

## Guarantees

- **Static-grounded.** Names appear literally in source; AI (`--ai`) is opt-in for ranking only, never symbol invention.
- **Unresolved calls are explicit.** Dynamic dispatch and missing definitions emit `❓ <unresolved>` nodes with `metadata.reason` and `metadata.candidates` — never silently dropped.
- **Caches per-file** in `.codeflow/segments/` (gitignore it).
- **Branch tracing is constrained.** Boolean checks, comparisons, `is None`, `and`/`or`/`not`. Unknown branches are explicit (❓), never guessed.

## Notes

- Call graph tracing supports **Python, Go, JS, TS, Java, C#, C, C++, PHP, Rust** natively. Branch pruning (`--params`) is currently Python + Go only; the other 8 are deferred.
- For Ruby/Swift/Kotlin/Scala/Dart/etc., run `codeflow index --ai-extract --enrich` once, then use `search`.
- If a query returns "needs clarification", surface the closest matches and ask which the user meant.
