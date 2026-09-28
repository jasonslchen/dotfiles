---
applyTo: '**'
---

# Global Copilot Instructions

## General guidelines

- At the beginning of each response, acknowledge these instructions by saying
  `Acknowledged copilot-instructions.md`.
- Be precise, direct, and concise. Avoid filler, hedging, and unnecessary
  explanation.
- Match response length to the question. Use one word or one sentence when that
  fully answers it.
- Preserve unrelated user changes and avoid modifying files outside the task.

## Planning complex changes

When working with large files (more than 300 lines) or complex changes:

1. Create a detailed plan before making edits.
2. Include:
   - Every file, function, or section that needs modification.
   - The order in which changes should be applied.
   - Dependencies between changes.
   - The estimated number of separate edits.
3. Use this format:

   ```markdown
   ## PROPOSED EDIT PLAN
   Working with: [files or sections]
   Total planned edits: [number]

   ### MAKING EDITS
   - Focus on one conceptual change at a time.
   - Show clear before and after snippets when proposing changes.
   - Explain concisely what changes and why.
   - Confirm each edit follows the repository's conventions.

   ### Edit sequence:
   1. [First specific change] - Purpose: [why]
   2. [Second specific change] - Purpose: [why]

   ### EXECUTION PHASE
   - After each edit, report: `Completed edit [number] of [total].`
   - If additional changes become necessary, stop and update the plan first.
   ```

## Repository discovery and commands

- Read repository-level instructions and relevant documentation before editing.
- Discover the repository's supported commands from its build files, package
  manifests, task runners, scripts, and CI configuration.
- Use repository-native commands instead of assuming a particular language,
  framework, package manager, or build system.
- Use the smallest existing build, format, lint, or test command that validates
  the changed behavior.
- Do not introduce new development tools when the repository already provides
  an appropriate one.

## Code changes

- Follow the language's idioms and the repository's established conventions.
- Keep changes focused, maintainable, type-safe, and DRY.
- Prefer explicit dependencies and dependency injection when they improve
  testability or modularity.
- Use interfaces, protocols, traits, or equivalent abstractions at dependency
  boundaries when supported and useful.
- Handle errors explicitly and add useful context when propagating them.
- Preserve cancellation, request, or execution context through call chains.
- Use the language's cleanup mechanisms for files, connections, locks, and
  other resources.
- Use named constants or configuration for repeated values and timeouts.
- Avoid broad exception handling, silent failures, and unsafe type escapes.

## Comments

- Keep comments synchronized with the current behavior.
- Comments should explain intent or non-obvious constraints, not narrate change
  history or restate straightforward code.
- Do not remove commented-out code unless the task requires it or the user
  explicitly approves its removal.

## Testing and quality

- Add focused tests for new or changed behavior when tests are applicable.
- Follow the repository's existing test organization, naming, and mocking
  conventions.
- Prefer table-driven, parameterized, or suite-based tests when idiomatic for
  the language and test framework.
- Keep tests deterministic and independent of external state.
- Mock external dependencies using the repository's existing tools.
- Use clear Arrange, Act, and Assert phases where that structure improves
  readability.
- Comment on test intent and complex setup or assertions, not routine mechanics.
- Run the relevant existing tests and fix failures introduced by the change.

## Investigation and answering

- Read the relevant code before answering investigative questions.
- Do not guess. Answer only from code evidence, command output, cited examples, or explicitly provided context.
- If the answer cannot be verified, say that clearly. Do not invent an answer.
- For complicated tasks that require substantial reasoning, use cross-model verification: delegate to a subagent running a different model provider, compare the findings, and reconcile differences before answering.

## Code changes, tests, communication, and uncertainty

1. **Keep changes succinct, simple, surgical, and within scope.**
   Make only the changes necessary to fulfill the user's request.
   Do not add unrelated fixes, refactors, features, or cleanup.
   If additional work appears necessary or beneficial, explain the
   proposed scope expansion and why it matters. Obtain explicit user
   approval before making those additional changes.

2. **Write focused tests without duplication.**
   Cover the changed behavior and meaningful edge cases with the
   smallest sufficient set of tests. Inspect existing tests before
   adding new ones; extend or reuse them where appropriate.
   Confirm that each added test covers a distinct behavior, failure
   mode, or integration boundary—not something already covered.
   Avoid exhaustive permutations that add no meaningful coverage.

3. **Lead with the main point; omit filler.**
   Answer directly and include only what the user needs to understand
   the result, make a decision, or take action. Include material risks,
   blockers, and uncertainty; these are not filler.
   If optional context would be useful, briefly describe it and ask
   whether the user wants the details. Do not provide those details
   unless requested.

4. **Resolve uncertainty with evidence, not assumptions.**
   Do not guess or present an unverified answer as fact.
   First investigate using available code, documentation, tools, or
   other relevant sources. If uncertainty remains, ask the user or
   consult an agent from a different model family. Another agent's
   agreement alone is not proof; verify its supporting evidence.
   When asking the user, briefly state what you checked, what remains
   unknown, and why it matters. Present 2–3 relevant options with
   tradeoffs when applicable; do not invent options to meet a quota.
   Do not make changes that depend on an unresolved decision.
