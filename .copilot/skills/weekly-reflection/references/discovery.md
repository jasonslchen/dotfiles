# Activity discovery and evidence

Use the currently available tool schemas, not remembered argument names.
Run independent bounded lookups in parallel. Never collect actual personal
activity while merely installing or editing this skill.

## Coverage and pagination contract

Maintain a per-source record: backend/scope, UTC bounds, query slices, page
cursor, rows returned, remaining pages, errors, and status. Statuses are
`accessed`, `no matches`, `unavailable`, `partial/truncated`, or `excluded`.
State coverage of the queries performed, not "all work" from a search sample.
Pagination is complete only when the backend's continuation is exhausted
without truncation/error. Detect repeated/nonadvancing cursors and stop with
a partial result. Split capped searches by date, then discovered org/repo
or other disjoint scope; deduplicate overlapping boundaries. If a cap cannot
be bypassed with supported narrower queries, disclose the gap.

Use exact UTC half-open comparisons for every underlying event. Establish
whether each API's bounds are inclusive or exclusive before constructing a
conservative superset that includes both boundary dates; pad date-only
filters outward when necessary, then filter actual timestamps afterward.
Older governing context
and newer state checks are not additional in-window contributions.

## Copilot sessions

Use `session_store_sql` to discover **all accessible personal session
activity**, not just currently open app sessions, the current project, or
sessions created during the week. Prefer cloud materialized views and also
query local-only data when supported: cloud results supplement local data
best-effort, which is not proof of local completeness. Never traverse raw
session files or credentials as a connector workaround.

### Cloud: discover IDs without transcripts

Start with `turns.timestamp` in the frozen window. These are SQL templates,
not runnable bindings: replace `START_UTC`/`END_UTC` with UTC timestamp text
and escape any substituted string literals; submit **one read-only query per
call**. Do not pass multiple statements. Use `source: "cloud"`.

```sql
SELECT session_id, turn_index, timestamp
FROM turns
WHERE timestamp >= TIMESTAMP 'START_UTC'
  AND timestamp < TIMESTAMP 'END_UTC'
ORDER BY timestamp, session_id, turn_index
LIMIT 200
```

For the next page, keep the same bounds and insert this predicate before
`ORDER BY`, using the last returned tuple. Continue until an empty page (or
an explicit exhausted result); `LIMIT 200` is a page size, not total coverage.

```sql
AND (timestamp, session_id, turn_index) >
    (TIMESTAMP 'CURSOR_UTC', 'CURSOR_SESSION', CURSOR_TURN)
```

Also discover sessions with in-window tool activity, which may occur in a
long-running turn started earlier. Query `tool_executions` twice with
`EVENT_TIME` replaced by `started_at` and then `completed_at`; union IDs.
Use a keyset predicate on `(EVENT_TIME, session_id, tool_call_id)` on later
pages. Do not filter a tool's start by session creation time.

```sql
SELECT session_id, tool_call_id, EVENT_TIME AS activity_at
FROM tool_executions
WHERE EVENT_TIME >= TIMESTAMP 'START_UTC'
  AND EVENT_TIME < TIMESTAMP 'END_UTC'
ORDER BY EVENT_TIME, session_id, tool_call_id
LIMIT 200
```

For additional discovery/context use bounded `checkpoints.created_at`
(keyset `created_at, session_id, checkpoint_number`), `session_refs.created_at`
and `session_files.first_seen_at`. Deduplicate distinct tuples before paging
views without unique row IDs. File `first_seen_at` is not every subsequent
edit timestamp. `session_usage.last_used_at` is only a latest-use hint:
its rows aggregate whole sessions/models, so do not sum them as weekly usage.
`sessions.updated_at` is a candidate hint, not proof of work in the window;
`sessions.created_at` alone would miss resumed sessions.

After collecting IDs, fetch metadata in small exact-ID batches from
`sessions` (`id`, `repository`, `branch`, `summary`, `task_id`, timestamps)
and `session_refs` (`session_id`, `ref_type`, `ref_value`, `created_at`).
Keep time bounds on queries; for known older sessions only, widen metadata
or reference bounds when needed to obtain earlier context. Never apply
that widening to an unrestricted transcript search.

### Local fallback: a separate SQLite schema

Use `source: "local"` explicitly. Local has `sessions`, `turns`,
`checkpoints`, `session_files`, and `session_refs`. It does **not** have cloud
`events`, `tool_executions`, `session_usage`, `tool_requests`, `attachments`,
or `sessions.task_id` / `agent_name` / `agent_description`. Do not reuse
cloud SQL with these columns, `ILIKE`, `INTERVAL`, or `date_diff`.

Local timestamps can mix SQLite and ISO formatting. Use date-prefix bounds
as a conservative narrowing filter, then `julianday` for exact instants.
`START_DATE`/`END_DATE` below enclose all represented date prefixes for the
interval (pad the UTC dates by one day if stored offsets are not known).
For timezone-less timestamps, follow the store's documented timezone; if it
is unknown, mark temporal attribution partial instead of assuming local time.

```sql
SELECT session_id, turn_index, timestamp, julianday(timestamp) AS activity_jd
FROM turns
WHERE substr(timestamp, 1, 10) >= 'START_DATE'
  AND substr(timestamp, 1, 10) <= 'END_DATE'
  AND julianday(timestamp) >= julianday('START_UTC')
  AND julianday(timestamp) < julianday('END_UTC')
ORDER BY activity_jd, session_id, turn_index
LIMIT 200
```

Later pages add the following before `ORDER BY`. Preserve the returned
numeric Julian-day precision, or recompute it from the full cursor timestamp.

```sql
AND (julianday(timestamp), session_id, turn_index) >
    (julianday('CURSOR_TIMESTAMP'), 'CURSOR_SESSION', CURSOR_TURN)
```

Query local checkpoints/references/files with the same date-prefix plus
`julianday` pattern on their available event timestamps and stable keysets.
These complement turns but cannot fully replace cloud tool-execution
history; mark that gap if cloud is unavailable. Fetch local metadata only
for discovered IDs, selecting local-supported columns. Diagnose unknown or
unparseable timestamps with bounded ID/date queries; do not silently count
unparseable rows as "no activity".

### Read only narrowed evidence

Union cloud/local IDs and deduplicate the same stable session ID. Preserve
backend provenance; merge complementary content rather than discarding one
backend wholesale. For different IDs, use verified task/parent relationships
and canonical artifact/event IDs to deduplicate child sessions and work.
Similar titles alone are not sufficient to collapse unrelated work.

Only now fetch small transcript pages for exact session IDs and the window,
using `(timestamp, session_id, turn_index)` keysets (the local equivalent
uses `julianday`). Select `user_message`, `assistant_response` as needed.
Guard nullable text with `COALESCE` before `substr`/`length`; label excerpts
as truncated and fetch the needed segment before relying on it. Do not
unboundedly `ILIKE`-scan turns/events or join an unfiltered text-search side.
For a tool-active session whose enclosing turn predates the window, fetch
only the bounded preceding turn/context for that exact ID; ground the date
in the actual tool event. Prefer views; raw cloud events are a fallback
only for unavailable semantics, filtered by exact session, event type, and
time with a stable cursor. If no safe cursor is exposed, report partial.

Do not treat generated assistant conclusions as independently verified
shipping evidence. Check referenced commits/PRs and distinguish the user's
request/direction/review from the agent's execution.

For app links, use the actual URL from `list_sessions_and_chats` when
available; that list is a link lookup, **not** a discovery boundary. A
`ghapp://sessions/<id>` link is allowed only for an ID explicitly verified
as an app session ID by app metadata. Never substitute a task UUID, guess
an ID, or construct an app URL from a raw store ID without that mapping.
If a historical session has no resolvable app link, cite its verified
GitHub artifact or disclose the missing session link.

## GitHub

Verify the active identity with `gh api user` (or an authenticated equivalent).
Use supported `gh` search/API commands or discover MCP schemas first. Search
user activity across accessible organizations and discovered repositories;
configured repository hints do not restrict the search. Follow linked
decision, documentation, release, incident, and implementation artifacts
across repos, within authorization and disclosure limits.

| Candidate discovery | Required event/state verification |
|---------------------|-----------------------------------|
| Authored PRs created, merged, or updated in the window | Read author, commits, timeline, current PR state, and exact event dates; include in-progress work without calling it delivered. |
| `reviewed-by:LOGIN`, `commenter:LOGIN`, `involves:LOGIN` PRs with relevant update dates | Paginate actual reviews, issue comments, and inline review comments; match actor and `submitted_at` / `created_at`. |
| Created, assigned, updated, or closed issues | Verify authored text, assignment/closure timeline and closing actor/reason; assignment is not proof of delivery. |
| `commenter:LOGIN` / `involves:LOGIN` issues, including others' issues | Paginate issue comments/timelines and verify the user's actual in-window contribution, even without authorship or assignment. |
| Authored/commented GitHub Discussions and decisions | Paginate discussions, comments **and replies**; verify author and `createdAt` for each relevant event. |
| Authored commits, including direct-to-branch work without a PR | Search commits by verified author/date across user/org activity and discovered repos; read commit/branch state and separate authorship from merge/deployment. |
| Linked commits, releases, incidents, docs | Verify commit/release/event timestamp, identity, and specific personal contribution; follow primary links rather than inferring ownership. |

Use broad user-scoped queries first (for example `author:LOGIN is:pr`
with separate created/updated/merged date slices and
`reviewed-by:LOGIN is:pr updated:DATE..DATE`), then organization/discovered-repo
slices as necessary. `reviewed-by` plus a merge date is **candidate discovery
only**: an old review on a PR merged this week is not this week's review.
An artifact's latest update can be later than a historical catch-up window.
For historical candidate searches, use an update lower bound through the
current lookup date (then partition it), contribution-event discovery, or
known artifact links so later edits do not hide older in-window events.
Always filter actual events back to the frozen period.

Discover direct commits with supported author/date commit search (for example
`gh search commits --author=LOGIN --author-date=DATE..DATE`), then use
paginated `repos/OWNER/REPO/commits` with `author`, `since`, `until`, and
relevant discovered branch `sha` where needed. Commit search and default
branch listings can miss nondefault branches; follow session/artifact branch
references and disclose residual branch/index coverage gaps. Verify author
identity and author versus committer dates; a commit timestamp alone does
not prove that it was pushed or shipped then. Deduplicate commits against
their PR contributions, and explicitly exclude report-generation commits.

For candidate PRs, use paginated REST endpoints
`repos/OWNER/REPO/pulls/NUMBER/reviews`,
`repos/OWNER/REPO/pulls/NUMBER/comments`, and
`repos/OWNER/REPO/issues/NUMBER/comments`; paginate issue timelines when
needed. An embedded `gh pr view --json reviews,comments` collection is not
an exhaustive event history. Pending/draft reviews with no submission
timestamp are not submitted reviews.

Use `gh api --paginate` for REST and GraphQL `pageInfo` cursors for
connections. Paginate nested connections independently; an outer page does
not exhaust each discussion's comments or each comment's replies.
Search APIs have result caps (commonly 1000), CLI `--limit` can truncate,
and search results may be incomplete. Check totals, continuation, errors,
and `incomplete_results`; partition saturated queries until exhausted or
record partial coverage. Do not rely solely on the retention-limited public
Events API, a default page, or repositories where the user currently has
open work.

For Discussions, search authored/commented or involved discussions with
supported search qualifiers, then query candidate repository Discussion
connections and comment/reply connections. If the available API lacks a
global commenter index, expand through user/org activity and discovered
repos, including references from Slack/sessions. Report the remaining
cross-repository discovery gap; do not claim complete coverage from that
subset or equate an unsupported search qualifier with zero discussions.

Use canonical GitHub URLs returned by the API, specific comment/review
permalinks, and immutable commit/file links when citing exact content.
Verify attribution and delivery state separately from event discovery.

## Slack

Use **only Slack MCP**. Discover current schemas before searching/reading;
no token scraping, raw API calls, browser scraping, or credential fallback.
Verify the Slack identity through the connector's authenticated-user/profile
information; do not assume it matches the GitHub login or a display name.
If unresolved, do not attribute person-scoped results to the user.

Start with `slack_search_public`. A general weekly-report request permits
no private-channel/DM expansion. With explicit user consent, use
`slack_search_public_and_private` and set `channel_types` **every time** to
only the authorized subset of `public_channel,private_channel,im,mpim`.
Private-channel consent does not include one-to-one DMs (`im`) or group
DMs (`mpim`). Do not inherit the tool's broad default. Channel discovery
must also set authorized `channel_types`; reading linked threads must
respect the same scope. Unattended runs skip unauthorized scopes, not ask
or infer approval.

Use message-only searches (`content_types: "messages"` where supported),
bounded timestamp/date filters, the verified author ID, mentions, and
specific discovered artifacts. Search the user's messages plus relevant
mentions/threads, not just messages they authored. Use structural filters,
keywords, and semantic fields according to the live schema. Page cursors
to exhaustion or disclose truncation; semantic ranking is not completeness.
Prefer the search tools' explicit inclusive Unix timestamp `after`/`before`
parameters for the frozen bounds, then filter `start <= ts < end`. These
parameters differ from Slack's native date modifiers inside `filters` or
`query`: do not assume `after:DATE before:DATE` includes the named days.
If date modifiers are needed, pad at least one calendar day outward on each
side (and account for workspace/search timezone differences) before exact
timestamp filtering. Never rely on post-filtering to recover boundary
messages that an exclusive date query already omitted.

Read each material thread with `slack_read_thread`, including its parent and
all paginated replies needed to understand decisions/reversals. An older
parent may contain in-window replies. Widen only that material thread for
context, retaining author and timestamp and distinguishing out-of-window
context. Search snippets or truncated context are not sufficient proof.
Use canonical Slack message permalinks returned by the connector; if absent,
resolve through available supported tools, never invent workspace URLs.

Attribute colleagues' implementation and decisions accurately. Read access
does not authorize copying private content into a report, even a private
repository. Apply the skill's separate disclosure and sanitization rules;
omit sensitive links/text and disclose a generic omission when necessary.
