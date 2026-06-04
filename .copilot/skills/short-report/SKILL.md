---
name: short-report
description: >-
    Build a grounded /short-style status report from a pasted GitHub issue,
    batch issue, epic, tracking issue, or related issue/PR list. Use when the
    user asks for a short report, status update, weekly update, leadership
    update, or asks to turn an epic/batch into a reusable report. The skill
    researches related GitHub issues, PRs, review issues, release issues,
    cross-repo references, comments, labels, milestones, and linked work before
    producing a concise report with risks, blockers, progress, decisions, and
    next steps. Triggers: "short report", "/short report", "short update",
    "status report", "weekly report", "build a report from this issue",
    "summarize this epic", "summarize this batch", "report update".
user-invocable: true
---

# Short Report — GitHub-Grounded Status Updates

Turn a pasted GitHub issue, batch, epic, or tracking list into a reusable
`/short`-style report. The report must be grounded in current GitHub data,
not just the pasted text.

## Use when

- The user pastes a GitHub issue, epic, batch, PR list, or previous report and
  wants a status update.
- The user asks for a reusable `/short`, "weekly update", "leadership update",
  "status report", or "what changed since last week".
- The user wants related issues and PRs across repos pulled into one concise
  report.

Skip when the user asks only for copyediting and explicitly says not to look
anything up.

## Core rules

1. **Research first.** Read the seed issue/PR/batch, then discover related
   GitHub artifacts before writing.
2. **Use GitHub as source of truth.** Prefer `gh` CLI for issues, PRs,
   searches, comments, and cross-repo references.
3. **Cite internally while working.** Track which issue/PR/comment supports
   each claim. The final report can stay clean, but every non-obvious claim
   must be traceable to a GitHub URL or `owner/repo#number`.
4. **Do not invent status.** If target date, owner, review state, or rollout
   state is not visible from GitHub or user-provided context, write "unknown"
   or omit it.
5. **Separate signal from appendix.** Put decisions, risks, progress, and next
   steps in the main report. Put deep investigations, metrics details, and
   root-cause notes in an appendix.
6. **Read-only by default.** Draft the report. Do not comment on issues,
   update bodies, edit labels, or change projects unless the user explicitly
   asks.

## Input handling

Parse all identifiers from the user message:

- Full URLs: `https://github.com/OWNER/REPO/issues/123`,
  `https://github.com/OWNER/REPO/pull/123`
- Shorthand refs: `OWNER/REPO#123`, `REPO#123`, `#123`
- Review/release refs: `security-reviews#123`, `releases#123`,
  `product-and-privacy-legal#123`
- Feature flags, ADR numbers, project names, milestone names, and target dates

If a shorthand ref lacks owner/repo context and cannot be resolved from the
seed issue, ask one focused clarification with `ask_user`.

## Research workflow

### 1. Read the seed artifact

For issues:

```sh
gh issue view NUMBER --repo OWNER/REPO \
  --json number,title,state,body,author,assignees,labels,milestone,projectItems,comments,createdAt,updatedAt,url
```

For PRs:

```sh
gh pr view NUMBER --repo OWNER/REPO \
  --json number,title,state,body,author,assignees,labels,milestone,comments,reviews,commits,files,createdAt,updatedAt,mergedAt,url
```

Capture:

- Goal / scope
- Target date or milestone
- DRI / owners
- Status labels and project fields
- Explicit blockers, risks, and asks
- Linked issues, sub-issues, task lists, PRs, review issues, release issues
- Recently updated comments and decision comments

### 2. Build the related-work graph

Extract every GitHub reference from the seed body and comments. Then search
for reverse references so work that mentions the seed but is not linked from
it is included.

Useful searches:

```sh
gh search issues '"OWNER/REPO#NUMBER"' --json repository,number,title,state,url,updatedAt --limit 100
gh search issues '"REPO#NUMBER"' --json repository,number,title,state,url,updatedAt --limit 100
gh search prs '"OWNER/REPO#NUMBER"' --json repository,number,title,state,url,updatedAt --limit 100
gh search prs '"REPO#NUMBER"' --json repository,number,title,state,url,updatedAt --limit 100
```

Also search by exact title phrases, feature flag names, ADR IDs, release IDs,
and high-signal identifiers from the seed. Keep searches specific; broad
GitHub searches produce noise.

For each discovered artifact, read enough detail to classify it:

- Merged / closed / done
- In flight / approved / waiting
- Blocked
- Review or approval
- Release / rollout
- Risk / incident / investigation
- Duplicate or irrelevant

### 3. Cross-repo coverage

Look across all relevant repos, not just the seed repo. Start with repos
mentioned by references, then use GitHub search for reverse references.

Common Copilot report surfaces include:

- `github/github`
- `github/copilot-api`
- `github/copilot-experiences`
- `github/copilot-discovery-team`
- `github/copilot-model-registry`
- `github/copilot-proxy`
- `github/copilot-token-service`
- `github/copilot-limiter`
- `github/security-reviews`
- `github/product-and-privacy-legal`
- `github/releases`

Do not assume this list is complete. Follow the actual references and search
results from the seed issue.

### 4. Determine trend and headline

Classify the update:

- `🟢 on track`
- `🟡 at risk`
- `🔴 blocked`
- `⚪ unknown`

Trend is based on the primary GA/release objective:

- **On track:** no unresolved blocker threatens the date.
- **At risk:** one or more risks could miss the date, but there is a credible
  mitigation path.
- **Blocked:** a required decision, dependency, approval, or fix has no clear
  path or owner.
- **Unknown:** GitHub evidence is insufficient.

The headline should answer:

1. Did status change since the last update?
2. What is the primary blocker or risk?
3. What new material risk, decision, or progress matters most?

### 5. Reconcile conflicts

When sources disagree:

- Prefer newer comments over older body text.
- Prefer merged PR state over issue checklist text.
- Prefer explicit DRI/owner comments over inferred ownership.
- Preserve uncertainty if no source clearly resolves it.

Do not silently collapse conflicting evidence. Mention the conflict if it
affects decisions or risk.

## Output format

Use this format by default.

```md
Trending
[🟢 on track / 🟡 at risk / 🔴 blocked / ⚪ unknown]

Target date
[YYYY-MM-DD or unknown]

Headline
[1-3 sentences. Lead with status change, primary blocker, new material risk,
and the highest-signal progress.]

Status since last update
- Status: [unchanged / improved / worsened / unknown]
- Primary blocker: [...]
- New risks: [...]
- Resolved risks: [...]
- Key movement: [...]

Workstreams

| Workstream | Status | Owner / DRI | Update | Next step |
|---|---:|---|---|---|
| [Name] | 🟢/🟡/🔴/🚧/⚪ | @owner or unknown | [Short factual update] | [Concrete next action] |

Risks and blockers

| Risk | Severity | Status | Owner | Mitigation / ask |
|---|---:|---|---|---|
| [Risk] | 🟡/🔴 | [new / unchanged / improving / blocked] | @owner or unknown | [Decision, fix, or mitigation needed] |

Engineering progress

Merged
- ✅ owner/repo#123: [short impact]

In flight
- 🚧 owner/repo#123: [short impact, gate, or ETA if visible]

Reviews / approvals
- Security: [...]
- Privacy / Legal: [...]
- RAI: [...]
- Release: [...]

Decisions / asks
- [Decision needed, owner if visible, deadline if visible]

Next up
- [Top concrete action]
- [Next concrete action]
- [Next concrete action]

Appendix: investigation details
[Optional. Include root-cause details, rollout metrics, comment-derived
findings, and source notes that are too detailed for the main report.]
```

## Quality bar

Before responding, verify:

- The seed issue/PR was read from GitHub unless the user explicitly asked not
  to look it up.
- Reverse references were searched.
- Every merged/in-flight item has current state from GitHub.
- Risks are distinct from next steps.
- The headline matches the risk table.
- Unknowns are labeled instead of guessed.
- The report is short enough to paste into a GitHub update, with details moved
  to the appendix.

## If data access fails

If `gh` is not authenticated, content is restricted, or a private repo is
inaccessible:

1. Say exactly which repo/ref could not be read.
2. Use only the user's pasted text for that area.
3. Mark affected claims as unverified or unknown.
4. Do not try to bypass access controls.
