# `<project or initiative>` Decision Log

This discussion is the durable place to propose, review, and record important
decisions for **`<project or initiative>`**.

## Related

- **Epic / tracking issue:** `<link>`
- **Project brief:** `<link>`
- **Owners:** `@handle`, `@handle`

## Background and references

- `<design document, prior decision, research, or policy>`
- `<design document, prior decision, research, or policy>`

## Dashboards and operational links

- `<dashboard, runbook, service, or repository>`

## How to use this thread

1. Assign the next decision number and post a new top-level comment using the
   template below.
2. Keep discussion, questions, evidence, and sign-offs in replies to that
   comment so each decision has one review thread.
3. When resolved, edit the original comment:
   - Set the final status.
   - Add the decision date and final outcome.
   - Record consequences, owners, and follow-up work.
   - Link the authoritative ADR, issue, or pull request when one exists and
     summarize any material difference from the original proposal.
4. Add or update the decision in the index below, linking directly to its
   top-level comment.
5. Never delete old decisions. Mark replaced decisions as
   `Superseded by #NNN` so the history remains traceable.

The owner is responsible for moving a proposal to a final state and keeping its
index entry current. The index is the quick summary; the comment thread is the
review record; a linked ADR or merged artifact is the source of truth when
explicitly identified as such.

## Decision index

| # | Decision | Status | Decision date | Owner | Link |
|---|----------|--------|---------------|-------|------|
| 001 | `<short title>` | Proposed | - | `@handle` | `<comment link>` |

## Decision template

Copy this into a new top-level comment:

```markdown
### Decision NNN: <short title>

- **Status:** Proposed
- **Proposed:** YYYY-MM-DD
- **Decided:** -
- **Owner:** @handle
- **Decision makers:** @handle, @handle
- **Stakeholders:** @handle, @handle

**Context**

What problem or question needs a decision? Include relevant constraints,
deadlines, assumptions, and why the decision matters now.

**Decision drivers**

- What outcomes or principles matter most?
- What requirements are non-negotiable?

**Options considered**

1. **Option A** - summary; benefits; costs and risks.
2. **Option B** - summary; benefits; costs and risks.
3. **Do nothing / defer** - impact of not deciding now.

**Decision**

Pending. Once resolved, replace this text with what was decided and why this
option best satisfies the decision drivers.

**Consequences**

- Benefits and intended outcomes.
- Risks, trade-offs, and mitigations.
- Work or behavior explicitly out of scope.

**Follow-ups**

- [ ] `@owner` - `<action>` - `<issue or PR>` - due `YYYY-MM-DD`

**Links**

- Related issues, pull requests, ADRs, documents, dashboards, or evidence.
```

## Status reference

| Status | Meaning |
|--------|---------|
| Proposed | Open for review; no final decision has been recorded. |
| Decided | Final outcome and rationale are recorded. |
| Rejected | Proposal was considered and explicitly declined. |
| Superseded by #NNN | Replaced by a newer decision; retained for history. |
