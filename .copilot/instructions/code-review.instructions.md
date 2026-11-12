---
applyTo: '**'
---

# Code & Security Review Augmentation

Apply these rules whenever a code review or security review is performed — via the
`/review` command, the `code-review` or `security-review` subagents, or any time the
user asks for a code review or security review.

## 1. Cross-model, blank-slate review

- **Run the review on a different model class than yourself.** Delegate the review to a
  subagent using an exact model ID from the delegation tool's currently advertised
  available models, from a *different* provider/class than the current session.
  The point is an independent second opinion, not a self-review.
  - If you are a **Claude** model, select an available **GPT** model.
  - If you are a **GPT** model, select an available **Claude** model.
  - Otherwise, select an available high-capability model from a different class.
  - Do not invent model IDs. If no suitable tool or model is available, state
    the limitation; do not claim independent cross-model verification.
- **Use supported reasoning and context options.** Select high reasoning effort
  and a long-context tier when the tool advertises support for the selected model.
  Use only advertised option values. If either is unavailable, use supported
  settings and disclose the constraint.
- **Fresh slate.** Instruct the reviewer to preserve verified user requirements
  and decisions as scope constraints, including explicit user rejections. Review
  the change from scratch by reading the actual code. Treat earlier Copilot
  decisions, rationale, summaries, and assumptions as claims to verify against
  that code, not review conclusions to accept.
- **No recursion.** The review subagent performs the review itself and must not further
  delegate to another review subagent.

## 2. Output: top 10 concerns, ranked by risk

Report the **top 10 areas of concern, ranked from highest risk to lowest** (rank 1 =
most severe). For each item include:

1. Rank and a short title
2. Risk level: **Critical / High / Medium / Low**
3. `file:line` citation(s)
4. What the problem is and why it matters
5. A concrete suggested fix

If there are fewer than 10 genuine concerns, list only the real ones — never pad the
list. Do not flag style, formatting, or trivial nits unless they cause an actual bug or
security issue.
