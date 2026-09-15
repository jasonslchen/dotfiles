---
name: short-report
description: >-
    Build a grounded /short-style status report from a pasted GitHub issue,
    batch issue, epic, tracking issue, or related issue/PR list. Use when the
    user asks for a short report, status update, weekly update, leadership
    update, or asks to turn an epic/batch into a reusable report. The skill
    researches related GitHub issues, PRs, review issues, release issues,
    cross-repo references, comments, labels, milestones, linked work, and
    relevant Slack discussions through the Slack MCP before producing a
    concise report with risks, blockers, progress, decisions, and next steps.
    Triggers: "short report", "/short report", "short update",
    "status report", "weekly report", "build a report from this issue",
    "summarize this epic", "summarize this batch", "report update".
user-invocable: true
---

# Short Report — GitHub and Slack-Grounded Status Updates

Turn a pasted GitHub issue, batch, epic, or tracking list into a reusable
`/short`-style report. Ground it in current GitHub artifacts and relevant
Slack discussions, using the Slack MCP for Slack research, not just the
pasted text.

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
   GitHub artifacts and Slack discussions before writing.
2. **Use the right source for each claim.** Prefer `gh` CLI for GitHub
   research; GitHub is authoritative for issue, PR, and review-artifact state.
   Use the Slack MCP for current owner updates, decisions, operational
   evidence, and blockers that may not yet be reflected in tracking issues.
3. **Cite internally while working.** Track which issue, PR, comment, or
   Slack message supports each claim. Every non-obvious claim must be
   traceable to a GitHub URL, `owner/repo#number`, or Slack permalink.
   Record the author and timestamp for Slack evidence.
4. **Do not invent status.** If target date, owner, review state, or rollout
   state is not supported by the fetched sources or user-provided context,
   write "unknown" or omit it.
5. **Separate signal from detail.** Keep decisions, risks, progress, reviews,
   and next steps in the main update. When an investigation materially affects
   status, add one descriptively named subsection with only the root cause,
   evidence, mitigation, and remaining uncertainty needed to understand it.
6. **Read-only by default.** Draft the report. Do not comment on issues,
   update bodies, edit labels, change projects, or post Slack messages unless
   the user explicitly asks.
7. **Report delivery state precisely.** Distinguish implementation, merge,
   deployment, rollout, and completion. Never infer a later delivery state
   from an earlier one.
8. **Apply materiality.** Include details only when they change status,
   delivery confidence, scope, decisions, or required action. Routine
   work-in-progress details are not headline material unless they materially
   affect delivery.
9. **Use risks precisely.** Unfinished planned work is progress or a next
   step, not automatically a risk or blocker. List only genuine uncertainty,
   dependency, failure mode, or external constraint that could prevent the
   intended outcome.

## Input handling

Parse all identifiers from the user message:

- Full URLs: `https://github.com/OWNER/REPO/issues/123`,
  `https://github.com/OWNER/REPO/pull/123`
- Shorthand refs: `OWNER/REPO#123`, `REPO#123`, `#123`
- References to work tracked in dedicated review, release, compliance, or
  operational repositories
- Feature flags, ADR numbers, project names, milestone names, and target dates
- Slack message/thread permalinks, channel names, and owner references

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

### 2. Enumerate sub-issues and approval gates

Issue bodies and comments do not expose GitHub's structured sub-issue
relationships. For an issue seed, query those relationships directly; do not
assume linked text or reverse-reference searches are complete.

```sh
gh api graphql --paginate \
  -F owner=OWNER -F repo=REPO -F number=NUMBER \
  -f query='
    query($owner: String!, $repo: String!, $number: Int!, $endCursor: String) {
      repository(owner: $owner, name: $repo) {
        issue(number: $number) {
          subIssues(first: 100, after: $endCursor) {
            nodes {
              number
              title
              state
              url
              createdAt
              updatedAt
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      }
    }'
```

Read every sub-issue that is open, was created or updated during the reporting
window, or otherwise materially changes current status. Repeat this step for
relevant sub-issues that are themselves tracking artifacts.

Follow security, privacy, legal, compliance, release, and operational-review
tasks into their dedicated repositories. Treat required approvals as
first-class delivery artifacts and record their exact state: requested,
opened, queued, assigned, on hold, approved, or completed. An opened, queued,
or assigned review is not approved. If the tracking issue requires approval,
report it as a delivery gate; classify it as a risk or blocker only when
evidence shows it threatens the objective or target date.

### 3. Build the related-work graph

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

Do not stop at directly linked artifacts. When the tracking artifact may be
incomplete, search recent related implementation work by repository, author,
exact identifiers, and high-signal terminology.

For each discovered artifact, read enough detail to classify it:

- Merged / closed / done
- In flight / approved / waiting
- Blocked
- Review or approval
- Release / rollout
- Risk / incident / investigation
- Duplicate or irrelevant

### 4. Cross-repo coverage

Look across all relevant repos, not just the seed repo. Start with repos
mentioned by references, then use GitHub search for reverse references.

Follow the actual work graph into implementation, dependency, configuration,
schema, review, release, compliance, rollout, and operational repositories
when the evidence points there. Do not assume a fixed repository list.

### 5. Search Slack for current decisions and operational updates

Search Slack as well as GitHub unless the user explicitly excludes it or the
Slack MCP is unavailable. Discover the available Slack MCP tools and their
schemas before calling them; do not guess tool prefixes or arguments. Use
the MCP, not browser scraping, shell credentials, or Slack API workarounds.

**Public first; private access requires consent**

- Start with `slack_search_public`. A general request for a report or Slack
  research is not permission to search private channels or DMs.
- Before searching or reading private channels, DMs, or group DMs, use
  `ask_user` to obtain explicit permission for the required scope, unless the
  user has already explicitly authorized that scope for this task.
- Only then use `slack_search_public_and_private`, setting `channel_types`
  explicitly and constraining the query to the approved scope. Do not rely
  on its default, which includes all channel types. Permission for private
  channels does not include DMs or group DMs.
- Do not broaden denied access. Continue with public/GitHub evidence and
  disclose any material coverage gap.

**Find the relevant discussions**

- Extract Slack links from the seed and related GitHub bodies/comments.
  Follow material linked threads, subject to the consent rules above.
- Start with a small batch of independent searches for the exact issue/PR
  reference or URL, feature flag, project name, or other high-signal terms.
  Use the reporting window or the last report as the initial date bound;
  otherwise start with the last seven days. Widen only when needed to find
  missing context or an older governing decision.
- Narrow by known channel or owner when possible. Use
  `slack_search_channels` to resolve relevant channel names and
  `slack_search_users` only when an author's identity needs clarification.
  Do not assume a Slack display name is a GitHub login.

Example `query` values for `slack_search_public` (replace placeholders):

```text
"OWNER/REPO#NUMBER" after:YYYY-MM-DD
"https://github.com/OWNER/REPO/issues/NUMBER" after:YYYY-MM-DD
"feature_flag_name" in:relevant-channel after:YYYY-MM-DD
```

Prefer concise, bounded search results, then read only material discussions.
Run independent searches in parallel. If exact searches return no matches,
try a specific project phrase or a targeted semantic question; no matches
are not proof that no discussion or implementation exists.

**Read context and connect it back to delivery**

- Use `slack_read_thread` with the channel ID and parent message timestamp
  from the results or linked thread. Resolve reply links to their parent
  thread and paginate replies so later decisions or reversals are not missed.
  Do not base a material claim on a search snippet alone.
- Use `slack_read_channel` only when bounded surrounding history is needed.
  Record the source permalink, author, timestamp, channel, and the exact
  scope of a decision, blocker, deployment, or rollout claim.
- Follow newly discovered GitHub links and verify their current state.
  Slack saying "merged" does not replace checking the PR; a deployment
  announcement applies only to its stated environment and rollout cohort.
- Distinguish a proposal, a request for approval, an authorized decision,
  an experiment, and completed work. Do not turn an informal acknowledgment
  into required approval.
- Include a permalink for material Slack-only updates in the report. Do
  not copy private-channel or DM content into a broader-audience report
  without explicit permission for that disclosure; permission to search
  is not permission to redistribute.

Stop expanding when the material status questions have adequate evidence.
Do not delay a useful draft for exhaustive Slack history; disclose unresolved
material gaps rather than guessing.

### 6. Determine trend and headline

Classify the update:

- `🟢 on track`
- `🟡 at risk`
- `🔴 off track`
- `⚪ unknown`

Trend is based on the primary project or release objective:

- **On track:** no unresolved blocker threatens the date.
- **At risk:** one or more risks could miss the date, but there is a credible
  mitigation path.
- **Off track:** the target is expected to slip, or a required decision,
  dependency, approval, or fix has no credible path in time.
- **Unknown:** available evidence is insufficient.

The headline should answer:

1. Did status change since the last update?
2. What is the primary blocker or risk?
3. What new material risk, decision, or progress matters most?

### 7. Reconcile conflicts

When sources disagree:

- Prefer explicit current DRI/owner updates over stale issue bodies or
  summaries, including Slack updates that have not reached the tracker.
- Verify structured GitHub states directly. Prefer the PR's actual state
  over a checklist or Slack claim that it merged.
- Prefer explicit DRI/owner statements over inferred ownership.
- Prefer the exact deployment or rollout state over assumptions based on merge
  state. Attribute Slack-only operational evidence and preserve its scope.
- A newer Slack message does not automatically supersede a formal approval
  or authoritative decision. Check the decision maker, scope, and full thread;
  if the recorded approval and discussion disagree, report the discrepancy.
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
- [Trend emoji] [Highest-signal status movement, blocker, risk, decision, or progress.]

**[Optional: specific investigation or dependency title]**
[Briefly explain why this investigation matters to the target.]

Findings:
- [Verified root cause, evidence, impact, mitigation, or uncertainty.]

[Summarize the fix or next validation step and link its issue or pull request.]

**Engineering progress (merged this period)**
- ✅ [owner/repo#123](https://github.com/owner/repo/pull/123) (@owner): [Short impact.]

**Engineering progress (in flight)**
- 🚧 [owner/repo#123](https://github.com/owner/repo/pull/123) (@owner): [Current state, gate, or dependency.]

**Reviews**
- [Review type]: [Substantive status and link.]

**Risks and blockers**
- [🔴/🟡] **[Risk or blocker]:** [Impact, status, owner, and mitigation or decision needed.]

**Next up**
- [Concrete next action.]
<!-- data end -->

<!-- data key="isReport" value="true" -->
<!-- data key="howieReportName" value="short" -->
```

Formatting rules:

- Use one to four headline bullets. Start the first bullet with the current
  trend emoji and state whether the trend improved, worsened, stayed the same,
  or remains unknown.
- Include meaningful positive movement even when the overall trend is at risk
  or off track.
- Keep merged and in-flight work separate; include only items that materially
  affect delivery, risk, or scope.
- Use concrete implementation artifacts in engineering progress. For software
  projects that use pull requests, report merged and active pull requests;
  place planning-only tracking issues under `Next up`.
- Use a named investigation subsection instead of a generic appendix. Keep it
  only when root-cause or rollout detail is necessary for decision-making.
- Add descriptively named workstream, handoff, rollout, or investigation
  sections when they materially explain status. Do not force every report into
  the same set of optional sections.
- Put decisions and asks directly in the relevant risk or `Next up` item.
- Include routine draft, review, or CI details only when they materially change
  delivery confidence or required action.
- Do not use `Risks and blockers` as a backlog. Move ordinary implementation
  work, review work, and rollout tasks to engineering progress or `Next up`.
- Name risks by the affected system, dimension, and consequence instead of
  using vague umbrella terms. Do not add redundant contrasts once the meaning
  is clear.
- Never emit an empty, placeholder, `none`, `unknown`, or `no update` bullet
  for an optional item. If there is no substantive content, omit the bullet.
- Do not add a review bullet solely to say that no review or review issue was
  found. Include the absence only when it is an explicit blocker or ask, and
  place it under `Risks and blockers`.
- Omit an entire optional section when it would otherwise contain no
  substantive bullets. `Trending` and `Target date` remain required data
  fields and may explicitly be unknown.
- Always include the `isReport` and `howieReportName` markers.

Emoji semantics:

- `🟢`, `🟡`, `🔴`, and `⚪` represent the overall trend.
- `✅` marks completed implementation or rollout work.
- `🚧` marks active implementation work.
- `🆕` may precede `🚧` only when the item is new since a known previous
  report.
- `🔴` marks a blocker to the primary objective or target date.
- `🟡` marks a material risk that does not currently block the primary
  objective.
- Use emojis as compact status metadata, not decoration.
- Separate optional or post-target follow-ups from true blockers when that
  distinction is material.

## Quality bar

Before responding, verify:

- The seed issue/PR was read from GitHub unless the user explicitly asked not
  to look it up.
- Structured sub-issue relationships were queried for issue seeds and relevant
  nested tracking issues.
- Every material open or recently changed sub-issue was classified, including
  required review and approval artifacts in dedicated repositories.
- Review state is reported precisely; requested, opened, queued, assigned, on
  hold, approved, and completed are not treated as interchangeable.
- Reverse references were searched.
- Relevant public Slack discussions and material linked threads were
  researched, or a material coverage gap was disclosed if Slack was
  unavailable, out of scope, or explicitly excluded.
- Private-channel/DM access stayed within explicit consent, and private
  content is not being redistributed beyond the approved audience.
- Material Slack claims have full-thread context, author/timestamp evidence,
  and source permalinks; linked GitHub artifact states were verified.
- All material completed and active implementation artifacts are represented.
- Every merged/in-flight item has current state from GitHub.
- Delivery-state wording matches the source exactly.
- Planning-only items are not presented as implementation progress.
- Routine work-in-progress details are not overstated.
- Risks are distinct from next steps.
- Every risk is a real threat or blocker, not merely unfinished project work.
- The headline matches the risks and blockers section.
- Unknowns are labeled instead of guessed.
- No empty, placeholder, or content-free bullet remains in the report.
- The report contains the required Howie data markers with correctly matched
  `start` and `end` comments.
- The report is short enough to paste into a GitHub update, with only material
  investigation details retained.

## If data access fails

If GitHub or the Slack MCP is unavailable, authentication fails, permission
is denied, or a source is restricted:

1. Say which service or repo/ref/channel/thread could not be read, without
   exposing private details to an unauthorized audience.
2. Handle sources independently: retain verified accessible GitHub and
   Slack evidence plus user-provided context. A Slack failure does not
   invalidate verified GitHub work or prevent a GitHub-only draft.
3. Mark affected claims as unverified or unknown and disclose material
   research gaps. Distinguish an access failure from a successful search
   with no relevant results.
4. Do not bypass access controls, switch tools to retrieve denied content,
   or claim inaccessible discussions were reviewed.
