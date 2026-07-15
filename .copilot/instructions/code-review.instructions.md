---
applyTo: '**'
---

# Code & Security Review Augmentation

Apply these rules whenever a code review or security review is performed — via the
`/review` command, the `code-review` or `security-review` subagents, or any time the
user asks for a code review or security review.

## 1. Cross-model, blank-slate review

- **Run the review on a different model class than yourself.** Delegate the review to a
  subagent (via the `task` tool) using a model from a *different* provider/class than
  the one currently driving the session. The point is an independent second opinion, not
  a self-review.
  - If you are a **Claude** model, run the review on a **GPT** model
    (e.g. `gpt-5.5`, or the highest available GPT).
  - If you are a **GPT** model, run the review on a **Claude** model
    (e.g. `claude-opus-4.8`, or the highest available Claude).
  - If neither applies, pick any high-capability model from a different class than your
    own (e.g. a Gemini model).
- **Maximize reasoning and context.** Launch that review subagent with high reasoning
  effort (`reasoning_effort: "high"` or `xhigh`) and the long-context tier
  (`context_tier: "long_context"`) so it can hold the full diff plus surrounding code.
- **Fresh slate.** Instruct the review subagent to ignore any prior conclusions,
  summaries, or assumptions from this session and review the change from scratch by
  reading the actual code — not trusting earlier descriptions of it.
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
