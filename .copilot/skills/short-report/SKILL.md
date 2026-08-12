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
5. **Separate signal from detail.** Keep decisions, risks, progress, reviews,
   and next steps in the main update. When an investigation materially affects
   status, add one descriptively named subsection with only the root cause,
   evidence, mitigation, and remaining uncertainty needed to understand it.
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
- `🔴 off track`
- `⚪ unknown`

Trend is based on the primary GA/release objective:

- **On track:** no unresolved blocker threatens the date.
- **At risk:** one or more risks could miss the date, but there is a credible
  mitigation path.
- **Off track:** the target is expected to slip, or a required decision,
  dependency, approval, or fix has no credible path in time.
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

Use this Howie-compatible format by default. Preserve the HTML data markers
exactly, replace every placeholder, and omit the optional investigation
subsection when it does not add material context.

```md
### Trending

<!-- data key="trending" start -->
[🟢 on track / 🟡 at risk / 🔴 off track / ⚪ unknown]
<!-- data end -->

### Target date

<!-- data key="target_date" start -->
[YYYY-MM-DD or unknown]
<!-- data end -->

### Update

<!-- data key="update" start -->
**Headline**
- [Whether status changed and the primary blocker or risk.]
- [The most important new risk, decision, or resolved issue.]
- [The highest-signal engineering or rollout progress.]

**[Optional: specific investigation or dependency title]**
[Briefly explain why this investigation matters to the target.]

Findings:
- [Verified root cause or evidence with a GitHub reference.]
- [Impact, mitigation, or remaining uncertainty.]

[Summarize the fix or next validation step and link its issue or pull request.]

**Engineering progress (merged)**
- ✅ [owner/repo#123](https://github.com/owner/repo/pull/123) (@owner): [Short impact.]

**Engineering progress (in flight)**
- 🚧 [owner/repo#123](https://github.com/owner/repo/pull/123) (@owner): [Current state, gate, or dependency.]

**Reviews**
- Security: [Status and link, or unknown.]
- Privacy / Legal: [Status and link, or unknown.]
- RAI: [Status and link, or unknown.]
- Release: [Status and link, or unknown.]

**Risks and blockers**
- **[Primary risk]:** [Impact, change since the last update, owner, and mitigation or decision needed.]
- **[Additional risk]:** [Impact, status, owner, and mitigation.]

**Next up**
- [Top concrete action.]
- [Next concrete action.]
- [Next concrete action.]
<!-- data end -->

<!-- data key="isReport" value="true" -->
<!-- data key="howieReportName" value="short" -->
<!-- gh project="<project-number>" update-field="Update" value="<exact contents of the Update data block>" -->
```

Formatting rules:

- Use one to four headline bullets and lead with trend movement.
- Keep merged and in-flight work separate; include only items that materially
  affect delivery, risk, or scope.
- Use a named investigation subsection instead of a generic appendix. Keep it
  only when root-cause or rollout detail is necessary for decision-making.
- Put decisions and asks directly in the relevant risk or `Next up` item.
- Omit empty optional lines or sections rather than emitting placeholders.
- Always include the `isReport` and `howieReportName` markers.
- Include the `gh project` marker only when the project number is known. Its
  `value` must contain the exact rendered contents between the `update`
  markers, without the markers themselves.

## Quality bar

Before responding, verify:

- The seed issue/PR was read from GitHub unless the user explicitly asked not
  to look it up.
- Reverse references were searched.
- Every merged/in-flight item has current state from GitHub.
- Risks are distinct from next steps.
- The headline matches the risks and blockers section.
- Unknowns are labeled instead of guessed.
- The report contains the required Howie data markers with correctly matched
  `start` and `end` comments.
- The report is short enough to paste into a GitHub update, with only material
  investigation details retained.

## If data access fails

If `gh` is not authenticated, content is restricted, or a private repo is
inaccessible:

1. Say exactly which repo/ref could not be read.
2. Use only the user's pasted text for that area.
3. Mark affected claims as unverified or unknown.
4. Do not try to bypass access controls.
