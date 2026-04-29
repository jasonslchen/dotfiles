---
name: ralph-loop
description: >-
    Skill for executing non-trivial coding tasks using the Ralph Wiggum loop
    pattern (Geoffrey Huntley): persist all state to temporary markdown files
    between iterations, make incremental progress, and ensure every step is
    resumable so the same prompt can be re-run until the task is complete.
    Use for any task that spans multiple files, multiple phases, or could
    plausibly be interrupted and resumed.
user-invocable: true
---

# Ralph Loop — Resumable Iterative Task Execution

The "Ralph loop" (after Ralph Wiggum, popularized by Geoffrey Huntley) is a
discipline for working on long-running coding tasks: keep the agent dumb and
the state on disk. Every iteration reads the plan, makes one small,
verifiable step of progress, writes the new state back to disk, and stops.
Run the same prompt again and the next iteration picks up exactly where the
last left off.

The point is **not** that you literally re-spawn the agent in a `while` loop
(though you can). The point is that the work is structured so you *could* —
because state lives in files, not in the conversation buffer.

## When to use the ralph loop

Use it for **any task that is non-trivial**:
- Spans multiple files or phases
- Involves a refactor, a migration, or a multi-step implementation
- Could plausibly take more than one session
- Has any chance of partial failure mid-way

Skip it for trivial tasks:
- One-line edits
- Single-file lookups
- Pure questions

## State files (markdown only — no SQL, no databases)

All state lives in **temporary** markdown files that exist only for the
lifetime of the task. They are scratch space for the loop, not artifacts
of the work — delete them on termination.

**Where to put them (in priority order):**

1. The session workspace (`~/.copilot/session-state/<id>/files/` for
   Copilot CLI, or the equivalent for whatever agent you're running in).
   Preferred — it's already isolated per-task and never enters the repo.
2. A fresh temp directory: `mktemp -d -t ralph` → e.g.
   `/tmp/ralph.XXXXXX/`. Use this when there's no session workspace.
3. **Last resort only:** a `.ralph/` directory at the repo root.
   If you have to use this, add `.ralph/` to `.gitignore` *before*
   creating any files in it.

**Cleanup is mandatory.** When the task terminates (success or abandoned):
- Delete the temp directory (`rm -rf "$RALPH_DIR"`) or the `.ralph/`
  folder.
- Never commit ralph state. Never leave it lying around for the next
  unrelated task — start each new task with a fresh set of files.

**Files used:**

| File         | Purpose                                                      |
|--------------|--------------------------------------------------------------|
| `plan.md`    | Problem statement, approach, decisions, open questions, notes |
| `todos.md`   | Checklist of work units with status                          |
| `notes.md`   | (optional) Findings, gotchas, command outputs worth keeping  |

### `plan.md` shape

```markdown
# <task title>

## Problem
<1–3 sentence statement of what we're solving and why>

## Approach
<bullet list of the chosen strategy, including any rejected alternatives
 and why they were rejected — so future-you doesn't reconsider them>

## Constraints / decisions
<things that were settled and shouldn't be re-litigated>

## Open questions
<anything blocked on user input — also reflected as a `[blocked]` todo>

## Notes
<anything learned during execution that future iterations need>
```

### `todos.md` shape

Plain GitHub-flavored checklist. Status lives in the marker; reasons live
inline.

```markdown
# Todos

- [x] discover-config — read existing config layout
- [>] migrate-auth — port auth module to new API
      depends-on: discover-config
- [ ] update-tests — fix snapshot mismatches
      depends-on: migrate-auth
- [!] publish-package — blocked: waiting on npm token from user
```

Markers:
- `[ ]` pending
- `[>]` in progress
- `[x]` done
- `[!]` blocked (always include a `blocked: <reason>` line)

Notes:
- Use kebab-case ids before the em dash so you can refer to them unambiguously.
- Express dependencies with an indented `depends-on:` line. A todo is *ready*
  only when every id it depends on is `[x]`.
- Append new todos as you discover them; never silently drop one.

## The loop

For each task, on every turn:

1. **Read state first.** Before doing anything, read `plan.md`, `todos.md`,
   and `notes.md` (if present). If they don't exist, create them — the
   first iteration's job is usually "write the plan and the initial todo
   list, stop".
2. **Pick the next ready todo.** First `[ ]` whose `depends-on` ids are
   all `[x]`. If nothing is ready and there are `[!]` blockers, surface
   them to the user and stop.
3. **Mark it `[>]` in `todos.md`.** Write the file before starting work.
4. **Do one unit of work.** Small enough that you can verify it (a test, a
   build, a lint) before moving on. Resist the urge to do "just one more
   thing".
5. **Verify.** Run the relevant test/build/lint. If it fails, either fix
   it in the same iteration or flip the todo to `[!]` with a `blocked:`
   reason.
6. **Persist new state.** Update `plan.md` with anything you learned, flip
   the todo to `[x]` (or `[!]`), and append any newly discovered todos.
7. **Stop.** Report what you did in 1–3 sentences and end the turn.

The next prompt — even an empty one like "continue" — should be enough to
restart the loop because everything you need is on disk.

## Choosing the right model per iteration

The ralph loop runs many iterations. Using a premium model for every step
is expensive and slow; using a fast model for hard reasoning ships bugs.
Match the model to the *kind* of work this iteration is doing.

Three categories of work, three model tiers:

| Iteration kind                          | Tier      | Examples                                                     |
|----------------------------------------|-----------|--------------------------------------------------------------|
| **Look stuff up / mechanical**         | fast      | reading files, grepping, listing symbols, running tests/builds, summarizing logs |
| **Do the thing**                       | standard  | typical edits, implementing a planned change, writing tests, fixing a known failure |
| **Decide what to do / hard reasoning** | premium   | initial planning, redesigns mid-task, debugging a non-obvious failure, rubber-duck reviews of a non-trivial plan |

In Copilot CLI you don't switch the main model mid-session, but you *can*
route per-iteration work through sub-agents (`task` tool) with an explicit
`model` override:

- **fast tier** → delegate research/exploration to the `explore` agent
  (defaults to Haiku); delegate verbose build/test runs to the `task`
  agent (also Haiku). Keeps the main context clean and avoids burning
  premium tokens on `cat` and `npm test`.
- **standard tier** → just do the work in the main loop. This is the
  default and usually right.
- **premium tier** → call `rubber-duck` (defaults to Sonnet, override to
  an Opus/GPT-5.5 variant for genuinely architectural calls) before
  committing to a plan, after writing tests, or when stuck. For deep
  debugging, you can launch a `general-purpose` agent with an explicit
  premium `model` override.

Heuristics:

- **Plan once, premium.** The first iteration that produces `plan.md` is
  high-leverage — bias toward a stronger model (or follow up immediately
  with `rubber-duck`). Cheap planning is the most expensive kind of
  cheap.
- **Execute many, standard.** The bulk of the loop should be standard
  tier. If you find yourself constantly escalating, the plan is wrong —
  re-plan, don't keep throwing premium tokens at it.
- **Verify cheap.** Running tests, tailing logs, listing files: always
  fast tier via a sub-agent. Never read 5000 lines of build output into
  the main context.
- **Escalate on surprise, not on difficulty.** "This is hard" is not a
  reason to escalate; "this failed in a way the plan didn't predict" is.
- **Don't downshift mid-decision.** If you're in the middle of a design
  call, finish it at the current tier; switching models mid-thought
  loses context.

Record any deliberate model choice in `notes.md` so the next iteration
knows why a given step was routed where it was.

## Anti-patterns

- **Holding state in the conversation.** If a fact only exists in chat
  history, the next iteration can't see it. Write it down.
- **Using a database for state.** Ralph state is markdown only. SQL/JSON
  stores hide diff context and break the "fresh agent could resume this"
  guarantee.
- **Doing five todos in one turn.** Defeats the resumability guarantee.
  One todo per turn unless they're truly atomic.
- **Skipping verification.** A todo isn't `[x]` until the relevant test
  or build passes. Lying to the checklist breaks the loop.
- **Re-planning every iteration.** Read the plan, trust the plan. Only
  re-plan when verification surfaces something the plan didn't account
  for — and when you do, record *why* in `plan.md`'s Notes section.
- **Forgetting the user.** If you hit a real ambiguity, mark the todo
  `[!]`, write the question into "Open questions" in `plan.md`, and ask
  via `ask_user`. Don't guess silently.
- **One model fits all.** The loop has phases of very different cost
  profiles — research, execution, deciding. Route them accordingly
  instead of paying premium prices for `ls`.
- **Leaving ralph files behind.** Ralph state is temporary scratch space.
  Always delete the temp dir / `.ralph/` folder on termination. Never
  carry state from one task into an unrelated next task.

## Termination

The loop is done when:
- Every todo in `todos.md` is `[x]`, **or**
- Every remaining todo is `[!]` (surface the blockers to the user).

On termination:
1. Summarize what shipped, what's blocked, and any follow-ups.
2. **Delete the ralph state directory.** `rm -rf` the temp dir or
   `.ralph/` folder. The files are scratch — they have no value once the
   task is wrapped.
