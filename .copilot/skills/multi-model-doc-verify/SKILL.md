---
name: multi-model-doc-verify
description: >-
    Verify the factual accuracy of a markdown document against a real
    codebase by spawning multiple verifier subagents in parallel,
    requiring file:line citations on every claim, and reconciling
    findings before applying corrections. Use when a doc must be
    grounded in source (no hallucination), when you want to catch
    blind spots a single model would miss, or when the user explicitly
    asks to fact-check / audit / verify claims with multiple agents.
    Triggers: "verify this doc against the code", "fact-check with
    N agents", "audit accuracy of these claims", "find hallucinations
    in this markdown", "double-check using GPT 5.5 and Sonnet 4.6".
user-invocable: true
---

# Multi-Model Documentation Verification

A discipline for fact-checking technical docs against the codebase they
describe. The doc is the hypothesis; the code is the ground truth;
multiple model families catch different blind spots.

Use when:
- The user wants a doc verified for factual accuracy (claims, FF names,
  function names, file paths, line numbers, model lists, table marks).
- The doc was drafted with help from one model and the user wants
  independent fact-checking from others.
- High stakes: incorrect docs that downstream readers will trust.
- The user names specific models to verify with ("verify with GPT 5.5
  and Opus 4.7").

Skip when:
- Single trivial edit; just verify yourself.
- Doc is style/opinion content, not factual claims.

Single-verifier mode: if the user explicitly asks for one verifier (cost
or speed), proceed but tell them confidence is lower and a single
model's blind spots are unmitigated.

---

## Workflow

### 1. Set scope explicitly

Before launching any verifier, agree with the user on:

- **What's in scope**: which sections, which claim types (citations,
  FF names, marks in tables, model lists, prose claims).
- **What's out of scope**: external docs / URLs; stub / dev-only code
  unless it affects production behavior. **Runtime FF rollout state**
  (percentages, targeted user lists, stamp overrides) is not source-
  verifiable — exclude it. But FF **names**, **call sites**, **scope
  helpers**, and **default fallback behavior** ARE source-verifiable
  and must be in scope.
- **Source roots to consult**: e.g. `pkg/`, `cmd/`. Tell verifiers to
  ignore other audit / conclusion markdown so they verify against
  source, not other docs.
- **Source-class policy**: production source preferred; generated
  files (proto / OpenAPI) acceptable when they're the shipped
  interface; tests can corroborate behavior but never override
  production code; stubs/dev-only code require explicit labeling.
- **Resolve all paths to absolute** before passing them to verifiers.
  `~` doesn't always expand inside subagent contexts.

Capture the scope in the verifier prompt verbatim.

### 2. Pick verifiers — diverse models

**Default to ≥2 verifiers, from ≥2 model families.** Different families
have observed different blind-spot tendencies (these are tendencies,
not guarantees — model behavior shifts over time):

- Anthropic Claude (e.g. Opus 4.7-high, Sonnet 4.6) tends to be
  conservative with claims and good at admitting "cannot verify",
  but can miss broad cross-file searches.
- OpenAI GPT (e.g. GPT-5.5, GPT-5.4) tends to assert more confidently
  and explore more files, but more likely to claim "X doesn't exist"
  when it only searched part of the repo.
- Don't run two checks of the same family unless you also vary
  reasoning effort (`-high`, `-xhigh`).

Use currently available equivalent high-reasoning models from distinct
families. Recommended baseline: a high-reasoning Claude variant +
GPT-5.x.

If a chosen model fails (returns no output, times out, or rate-limits),
fall back to a sibling in the same family or an alternate model and
note the substitution.

### 3. Prompt every verifier with the same hard rules

Every verifier prompt MUST contain:

- `Cite path/to/file.go:LINE for every claim, AND quote the exact doc
  text being verified` (line numbers drift after edits — anchored
  quotes survive).
- `For each claim, state CONFIRMED / DISCREPANCY / CANNOT VERIFY.`
- `Discrepancies stated as "Doc line N says X, source says Y" with
  citations on both sides.`
- `Don't propose new content; only verify.`
- `Search BROADLY — flags / functions can be defined in unexpected
  packages.` Specifically, **before reporting "X doesn't exist"**, the
  verifier must:
    1. Grep the literal string across all in-scope source roots from
       the repo root, not just the obvious package.
    2. Try variants: snake_case, camelCase, the constant name, the
       enum value, the function name.
    3. Search generated/config/test files unless explicitly excluded.
    4. State which paths and patterns were searched.
- The exclusions from step 1 (rollout state, other docs, stubs).
- Output file path inside the session-state files folder, with a
  prescribed section structure.

For nit-pick mode, add:
- `Be as thorough as possible. Treat every word as a hypothesis.`
- `Examples of nitpicks worth flagging: imprecise scope wording,
  off-by-one line numbers, conflated code paths, model IDs not in
  prod registry, FF names not exactly matching source literals,
  table marks that don't match the code path, ordering / fallback /
  precedence claims.`

### 4. Launch in parallel as background tasks

Use the environment's background subagent API (e.g. the `task` tool
with `mode: background` if available) so all verifiers run
simultaneously. Capture each `agent_id`. If background mode is
supported, tell the user you're waiting and end your turn — a
notification will arrive when each verifier completes. If the
environment has no background mode, run verifiers sequentially and
warn the user about the increased latency.

### 5. Reconcile — don't trust verifiers blindly

When notifications arrive, read each report. **Re-verify every reported
discrepancy against source before acting.** Verifiers regularly:

- **Falsely claim a flag/function "doesn't exist"** because they only
  searched part of the repo. Always grep the whole repo.
- **Mis-cite line numbers off by one** because of how they counted.
  Open the file at the cited line and confirm.
- **Confuse two similarly-named code paths** (chat vs responses, raw
  cobs check vs `feature.Flag().IsEnabled`). Verify which path the doc
  is actually talking about.

Categorize each finding and tag it with severity:

| Category | Action |
| --- | --- |
| Real defect, source-confirmed | Apply fix |
| Wording imprecision (technically true but understated/overstated) | Surface to user |
| Presentation choice (e.g. enum order in user-friendly vs source order) | Skip with brief note |
| Verifier mistake (re-verification fails) | Downgrade and move on |

Severity labels (use in your summary to the user):

| Severity | Meaning |
| --- | --- |
| **Blocking** | Doc claim that's factually wrong in a way readers will act on (e.g. wrong FF name, wrong provider for a model, wrong ✅/❌ mark). |
| **Material** | Imprecise wording where stricter source semantics matter (e.g. scope is "per-user OR per-integration" but source actually checks 4 scopes). |
| **Citation-only** | Off-by-one line number, citation points to wrong helper, file path moved. |
| **Presentation** | Style or ordering choice; doc isn't claiming to mirror source ordering. |
| **Non-actionable** | CANNOT VERIFY items where the doc is honest about uncertainty. |

### 6. Apply corrections surgically

- Use the environment's surgical edit tool (e.g. `edit` / `apply_patch`)
  with enough context to be unambiguous; don't full-replace large
  blocks (you'll clobber hand-edits).
- **Re-read the cited doc lines before editing.** A verifier report
  written 5 minutes ago may reference line numbers that have since
  shifted. Always confirm the current text matches what the verifier
  saw before applying its suggested change.
- **Preserve user-edited cells** (e.g. rollout-state columns the user
  has been hand-filling) by scoping `old_str` narrowly to just the
  text being changed. Never replace an entire row or table.
- **Don't upgrade cautious wording** ("appears to", "in most cases",
  "not source-verifiable") into false certainty unless source fully
  supports it.
- After non-trivial edits, run the verifiers again on just the
  changed sections.

### 7. Report a consolidated summary

Tell the user, per finding:
- Verifier source
- Source citation(s) you used to re-verify
- Decision (applied / surfaced / skipped)
- One-sentence reason

Surface to the user (don't unilaterally skip):
- Presentation / style choices (e.g. table row order, terminology
  variants, level of detail).
- Findings that touch wording the user has previously edited.
- Any "wording imprecision" finding where the literal source semantics
  are stricter than the doc's prose.

### 8. Stop when signal flatlines

A natural stopping criterion: **two consecutive verification rounds
with zero source-confirmed defects**. Beyond that, additional rounds
mostly surface presentation quibbles or re-discover already-dismissed
findings. If the user wants more rounds, run them — but call out the
diminishing returns.

### 9. Track dismissed findings to avoid re-litigating

Verifiers are stateless and will independently rediscover the same
"finding" each round (e.g. "the enum is in source-int order but doc
shows severity-ascending" — that's a presentation choice).

When you decide to skip a finding, append it to a session-local
`dismissed-findings.md`. On future verification rounds, reference that
file in the verifier prompt as "the following findings have been
intentionally accepted; do not re-flag" so the verifiers can short-
circuit them.

### 10. When verifiers disagree

If verifier A says CONFIRMED and verifier B says DISCREPANCY for the
same claim, the **source is always the tiebreaker** — re-verify
yourself. Don't take the majority vote between models.

If you can't reproduce either side from source, that's the most
important finding to surface to the user — the doc is making a claim
that's not crisply verifiable.

---

## Anti-patterns to avoid

- **Single verifier**: one model has consistent blind spots; you'll
  miss them.
- **Same model family twice**: cuts diversity in half.
- **Acting on a verifier finding without re-checking source**: the
  verifier may be wrong. We've seen `flag.go` call sites missed,
  off-by-one line cites, and wrong-path conflations.
- **Letting verifiers consult other docs**: they'll verify the doc
  against another doc, not against code. Tell them to read source only.
- **Batching multiple section edits before re-verification**: each
  edit can introduce regressions; verify after each meaningful change.
- **Including rollout-state in source verification**: it lives in
  runtime FF config, not source. Verifiers will (correctly) say
  "not verifiable" — wasted cycles. Exclude it explicitly.
- **Verbose reconciliation reports**: the user usually wants the bottom
  line, not the methodology. Surface findings + decisions; keep
  reasoning behind a fold.

---

## Suggested model selection

| Stakes | Recommended verifiers |
| --- | --- |
| Quick sanity check | GPT-5.5 + Sonnet 4.6 |
| Standard fact-check | Opus 4.7-high + GPT-5.5 |
| Maximum thoroughness ("nitpick everything") | Opus 4.7-high + GPT-5.5 + Sonnet 4.6 (3 verifiers, two families) |
| Final pass before publishing | Opus 4.7-high + GPT-5.5 in nitpick mode, then final reconciliation |

---

## Output file convention

Each verifier writes to:
`<absolute-path-to-session-state>/files/<phase>-<model>.md`

Resolve `~/.copilot/session-state/<session-id>/files/` to an absolute
path before passing it to the verifier. Subagents do not always expand
`~`.

Examples:
- `fullverify-opus47high.md`
- `nitpick-gpt55.md`
- `final-reconciliation.md`
- `dismissed-findings.md` (also lives in this folder, not in the repo)

Phase prefixes (`fullverify`, `nitpick`, `pathaudit`, `postchange`)
make it easy to look back at which round of verification each report
came from. Keep all rounds — they form the audit trail.

---

## Standard verifier prompt scaffold

```
EXHAUSTIVE verification of <doc-path>.

Read the doc plus actual source under <source-roots>. Do NOT consult
other audit/conclusions markdown.

Verify every claim. Specifically check:
<bulleted list of high-risk claims with file:line hints>

HARD RULES:
- Cite path/to/file.go:LINE for every claim.
- Each section: CONFIRMED / DISCREPANCY / CANNOT VERIFY.
- Discrepancies: "Doc line N says X, source says Y" with citations.
- Don't propose rewrites; only report discrepancies.
- EXCLUDE <out-of-scope items>.
- Search BROADLY — <known traps, e.g. "flag X is defined in
  pkg/foo/bar.go, not the obvious package">.

OUTPUT: write to <session-state-files-dir>/<phase>-<model>.md

Structure:
# <Phase> verification (<model>)
## Method
## <Section 1>
## <Section 2>
...
## Discrepancies summary
## Items not verifiable

Write the output file before reporting completion.
```
