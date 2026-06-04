---
name: ralph-loop
description: >-
    Use for tasks that fit an iterative, resumable workflow: work that can
    be broken into small verifiable stories, multi-phase implementation,
    long debugging, migrations, refactors, test work, background agents,
    model races, or anything that must survive compaction, /clear, sleep,
    or multiple sessions. Triggers include "break this down", "iterate",
    "continue later", "keep working", "multi-phase", "background agents",
    "model race", "resume after compaction", "spans more than one session",
    and "long debug". Maintains durable plan.md plus structured todos with
    verifiable acceptance criteria so progress is real and a fresh agent can
    resume from disk alone. Skip for one-shot edits, pure questions, and
    tasks that do not benefit from iterative decomposition.
user-invocable: true
---

# Ralph Loop — Resumable Orchestration

State lives on disk, not in chat. Every turn reads disk, makes one
verifiable unit of progress, writes disk, stops. A fresh agent — even one
spawned after compaction or `/clear` — can resume from the files alone.

## Use when

Use this loop when the task fits an iterative, resumable style. Good fits:

- Work that can be broken into small, verifiable stories
- Multi-phase implementation
- Debugging, QA, or investigation that needs repeated command/edit/verify cycles
- Refactoring, migration, or cleanup with several dependent steps
- Writing or expanding tests across multiple cases or files
- Background agents launched whose IDs need recovery
- Model races or other parallel agent coordination
- Work likely to span more than one session, or to outlive a compaction / `/clear`

Skip for pure questions, read-only lookups, single-line typo fixes,
straightforward one-shot edits, and tasks that do not need iterative
decomposition.

## Sizing rule (#1)

**One story per turn. Each story must fit in one context window** —
small enough to implement, verify, and summarize without exhausting the
agent's context.

Right-sized:
- Add a database column + migration
- Add a UI component to an existing page
- Wire one server action into one endpoint

Too big — split:
- "Build the dashboard" → schema, queries, components, filters
- "Add auth" → schema, middleware, login UI, session handling
- "Refactor the API" → one story per endpoint or pattern

Heuristic: if you can't describe the change in 2–3 sentences, it's too big.

## State location

1. `~/.copilot/session-state/<id>/` (preferred — auto-cleaned with session)
2. `mktemp -d -t ralph` if no session workspace
3. `.ralph/` at repo root, **only if** added to `.gitignore` first

Never commit ralph state.

## State files

| File          | Required | Purpose                                                                                  |
|---------------|----------|------------------------------------------------------------------------------------------|
| `plan.md`     | yes      | Current state, decisions, resume commands, background agents                             |
| `todos`       | yes      | Either SQL `todos` table OR `todos.md` checklist — pick one and name it in plan.md       |
| `patterns.md` | optional | Append-only reusable codebase patterns discovered while working                          |

### `plan.md` must contain

- **Status** — current phase, last verified state
- **Goal / constraints** — what's being solved, what not to change
- **Decisions** — settled choices; do not re-litigate
- **Todo tracker** — SQL query OR `todos.md` path
- **Background agents** — every launched agent's ID, model, purpose, how to poll/read, expected result, next action on completion
- **Resume** — exact next CLI command, query, or tool call to run on recovery
- **Verification** — smoke-test commands

Don't paste raw logs. Store the conclusion + the command that produced it.

If using SQL todos, pin the query, e.g.:

```sql
SELECT id, title, status, priority FROM todos ORDER BY priority, id;
```

### Background agent registry template

```md
## Background agents
- <agent-id> — purpose, model, started <timestamp>
  - poll with: <tool/command>
  - expected result: <what unblocks us>
  - next action on completion: <what to do>
```

## Todo schema

Every todo — SQL row or markdown line — must have:

- **id** (stable, kebab-case)
- **title** (one line)
- **status**: pending / in-progress / done / blocked
- **priority** (integer; lower = earlier)
- **acceptance criteria** — verifiable checks; **mandatory: include `Typecheck passes`** (or repo-equivalent: `tests pass`, `lint passes`, `build succeeds`)
- **dependencies** (other todo ids)
- **blocker reason** (required if `blocked`)

Markdown form:

```md
- [ ] add-priority-column (p:1) — Add priority enum to tasks table
      acceptance: migration runs cleanly; typecheck passes
      depends-on: —
- [>] priority-badge (p:2) — Render colored badge on TaskCard
      acceptance: badge visible; typecheck passes; verify in browser
      depends-on: add-priority-column
```

If a story has testable logic, also include `tests pass`. If it changes
UI, include browser verification (compose with `dev-browser` or
equivalent skill). A todo isn't `[x]` until its acceptance criteria pass.
Lying breaks the loop.

## The loop

Each turn:

1. **Read state.** plan.md → todos → patterns.md (if present).
2. **Recover context.** After compaction, `/clear`, or new session: trust files over chat memory.
3. **Pick the next ready todo.** First pending whose dependencies are done.
4. **Mark in-progress** before starting work.
5. **Execute one story.** Multiple tools/edits fine if they implement one story; unrelated work goes in the next turn.
6. **Verify.** Run the acceptance criteria commands. If any fails, fix in the same turn or flip to blocked with reason.
7. **Persist.** Update plan.md (Status, new Decisions), flip todo status, append new todos discovered, append patterns to patterns.md.
8. **Stop.** 1–3 sentence report. End the turn.

The next prompt — even just "continue" — must be enough to resume.

## Recovery protocol (after compaction, /clear, or new session)

The highest-value behavior of the loop:

1. Read `plan.md` **before** acting on the user's current message.
2. Run every command in plan.md's **Resume** and **Background agents** sections to refresh state.
3. Reconcile: if agents finished or tests now pass, update plan.md before doing new work.
4. Then act on the user's prompt.

Don't depend on the chat summary for task-critical state.

## Patterns capture

When a turn discovers something reusable about the **codebase** (not the
task), record it in two places:

1. Append a one-line bullet to `patterns.md`
2. If the pattern is local to a directory, also append it to the nearest `AGENTS.md` / `CLAUDE.md` (create if needed)

Examples worth recording:
- "Use `sql<n>` template for aggregations"
- "Migrations require `IF NOT EXISTS`"
- "Tests need dev server on PORT 3000"

Do **not** record story-specific details, debug notes, or anything
already in plan.md.

## Patterns: write to AGENTS.md every iteration

**Every iteration that modifies code MUST check whether a reusable
codebase pattern was discovered.** Before stopping the turn, ask: "Did
I learn something a future agent would benefit from?" If yes, append a
one-line bullet to the nearest existing `AGENTS.md` (or create one in
the directory of the most-edited file). Patterns include: API
conventions, gotchas, dependencies between files, testing
requirements, configuration that's non-obvious. NOT patterns:
bug-specific fixes, story-specific implementation details, anything
already in `plan.md`.

If you're unsure whether something qualifies, err on the side of
writing it down — `AGENTS.md` is cheap to grep, expensive to
re-derive.

## Cleanup

Conditional, not automatic:

- **Keep state** if: background agents still running, user paused, session compacted/cleared, work spans days
- **Delete state** if: shipped end-to-end and no follow-up expected (`rm -rf` temp dir or `.ralph/`)

Session workspace under `~/.copilot/session-state/` is auto-cleaned with
the session — usually no manual step needed.

## Common mistakes

- Holding state in conversation → invisible after compaction
- Multiple unrelated todos in one turn → not resumable
- Re-planning every iteration → trust the plan; re-plan only when verification disproves it
- Marking done without verification → breaks the loop
- Forgetting to register background agent IDs → unrecoverable
- Pasting raw logs into plan.md → bloats recovery cost
- Recording failed-attempt transcripts → record a one-line lesson ("X
  doesn't work because Y") and discard the trace; dead ends should be
  forgotten, not paid for on every iteration

## Parallel sub-agents: branch + squash

When dispatching multiple parallel sub-agents that may touch
overlapping files (e.g., several language adapters or several CLI
subcommands), use the **branch + squash** protocol to eliminate
concurrent-edit races:

1. Each sub-agent works on a feature branch named `ralph/<agent-id>`
   (created from `main`).
2. Sub-agent commits to that branch, pushes, and reports the branch
   name back.
3. Orchestrator merges branches into `main` **one at a time** with
   `git merge --squash <branch> && git commit`, running tests between
   each merge.
4. On merge failure, orchestrator either resolves manually or
   re-dispatches the failing agent with the latest `main` as base.

**Trade-off**: serialization adds wall-clock time vs. reckless
parallel commits, but eliminates the "agent A's commit accidentally
bundled in agent B's WIP files" failure mode that we hit during the
multi-language tracer rollout.

**When to skip**: if all parallel agents truly touch disjoint files
(verified by you in the dispatch plan), parallel commits to `main`
are fine. The branch + squash protocol is for the cases where overlap
is possible.
