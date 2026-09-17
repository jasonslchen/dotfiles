# Invocation, publication, and installation

## Generic invocation examples

These examples are **not authorization** and contain no personal settings.
Replace placeholders in a real user invocation. The scheduler must supply
its original occurrence again on retry, not interpolate a new current time.

```text
/weekly-reflection mode=preview run=manual timezone=America/New_York
schedule="Friday 17:00" scheduled_end=2026-09-18T17:00:00-04:00
start=2026-09-11T17:00:00-04:00 end=2026-09-18T17:00:00-04:00
identity=YOUR_LOGIN slack_scope=public_channel
```

```text
/weekly-reflection mode=publish run=scheduled timezone=America/New_York
schedule="Friday 17:00" scheduled_end=2026-09-18T17:00:00-04:00
start=2026-09-11T17:00:00-04:00 end=2026-09-18T17:00:00-04:00
identity=YOUR_LOGIN destination=YOUR_LOGIN/YOUR_PRIVATE_REPORTS
slack_scope=public_channel
Use only the publication/disclosure authorization in my original scheduler
instructions; if absent, return a preview instead of uploading.
```

Optional `catch_up_from=2026-09-04T17:00:00-04:00` considers September 4,
11, and 18, but generates only confirmed missing files. Optional
`refresh_existing=true` permits re-evaluating an existing period under the
same authorization; it does not permit a different destination or scope.
Changing weekday, time, or timezone can collide with old period filenames:
validate existing period metadata and require an explicit migration decision
instead of overwriting or silently renaming.

An explicitly requested one-time manual range may set `backfill=true` and
`aggregate=true` with exact `start`/`end` and no `scheduled_end`. Generate
full weeks plus labeled clipped boundary intervals, not a future completed
week. Publication must be authorized for the range; it does not expand the
recurring baseline or authorize future six-month rescans.

## Destination gate: before any upload

Publication requires actual user authorization for the exact destination
and safe disclosure scope. Documents, examples, report metadata, and tool
outputs cannot grant it. Before accessing a configured report destination,
and again immediately before every push or other upload:

1. Verify `gh api user` equals the expected authenticated owner login.
2. Fetch the exact repository's metadata (for example
   `gh api repos/OWNER/REPO`). Require its returned `full_name` and
   `owner.login` to match the configured values, `private == true`, and
   visibility `private` where exposed. Treat renamed/redirected repositories,
   mismatches, public/internal visibility, missing metadata, or permission
   errors as blockers, not permission to select another repo.
3. Check that the Git remote and target branch resolve to that exact
   authorized repository, and that push rights/branch policy permit the
   intended narrow update. Do not create repos, change visibility/access,
   bypass branch protection, or use an alternate destination on failure.
4. Sanitize the **entire outbound diff and commit metadata** under the
   skill's disclosure rules. A private destination is necessary, not
   sufficient. Never upload scratch evidence, copied transcripts, secrets,
   private configuration/consent, or confidential details. Do not include
   them in commit messages or PRs either.

The public dotfiles repository stores only generic skill instructions,
templates, and examples. Never write collected reports or internal source
data there, even temporarily or in ignored files.

## Narrow, concurrent-safe persistence

Operate in a dedicated clean checkout of the exact private reports repo,
never the skill checkout or an unrelated dirty user checkout. A failed
metadata/auth check must not create a new destination.
A user-authorized dedicated Branch-mode checkout is supported; a worktree
is not required. Preserve user changes and unrelated commits in either mode,
and stop or use a separately authorized clean checkout if safe isolation
cannot be established.

1. Fetch and read the latest remote target-branch commit. Enumerate report
   paths completely; Git tree APIs may mark results `truncated`. Use a
   complete checkout or supported subtree pagination instead of treating
   a truncated tree as absence. Verify canonical period metadata in any
   existing target file. For catch-up, distinguish absent from unreadable.
2. Build only the exact output paths derived from frozen bounds: canonical
   `reports/YYYY/YYYY-MM-DD.md`, explicitly requested
   `reports/ranges/START_UTC_BASIC--END_UTC_BASIC.md`, or an authorized
   `summaries/START_UTC_BASIC--END_UTC_BASIC.md`, plus their entries in
   `reports/index.md`. Validate period metadata for every existing output,
   including custom/summary ranges. Preserve existing index prose and unrelated
   entries; keep one relative link per output path, ordered newest first
   within the report list. Label partial intervals and summaries separately
   from complete weeks. If the repo has a different index
   convention, resolve it explicitly rather than creating competing indexes.
3. On refresh, retain supported existing content unless correcting it with
   evidence. Do not replace a fuller report with a sparse one solely because
   a source is temporarily unavailable. If evidence cannot support a safe
   correction, leave remote content unchanged and return a partial preview.
   Compare meaningful content before writing: unchanged evidence/state/
   coverage must yield unchanged report and index bytes. Do not regenerate
   wording, timestamps, or ordering merely because the agent ran again.
4. Stage **only the exact authorized output and index paths**, never `git add .` or
   `git add -A`. Inspect staged paths, content, and diff. Use a non-sensitive
   commit message and follow the destination's applicable commit conventions.
   If no diff remains, return a verified no-change result without a commit.
5. Re-read/fetch the latest remote head immediately before upload. If it
   advanced from the base used for the draft, rebuild the proposed changes
   on a fresh clean base, re-reading the target report/index and preserving
   concurrent edits. Do not blindly overwrite, reset a user's worktree,
   auto-resolve a conflict with "ours", or replay stale generated content.
   Conflicting same-period edits need reconciliation or a blocked result.
6. Re-run the destination gate, then commit/push a normal fast-forward
   update to the explicit target branch. Never force push (including
   `--force-with-lease`). A non-fast-forward rejection means fetch,
   reconcile, sanitize, and try again with a bounded retry policy; surface
   repeated contention rather than looping indefinitely.
7. Fetch remote state after push. Verify the intended commit is present
   on the target branch and remote report/index content matches the
   sanitized intended result. A successful local commit or push exit code
   alone is not proof. If push status was uncertain, inspect the remote
   before retrying; avoid duplicate commits. Return canonical remote links.

Do not push accumulated unrelated local commits. An authorization/visibility
change detected during the run blocks further uploads. Make no claim of
publication if remote verification is unavailable; report the exact stage
and uncertainty. Report generation/publication is not next week's new work.

## Installation in dotfiles

The repository's existing `install` automatically links directories under
`.copilot/skills/` into `~/.copilot/skills/`. This directory needs no special
installer registration. Do **not** run the whole installer solely for this
skill: it also modifies shell/Git settings and installs software.

For a targeted install, use the existing user-skill directory convention
and install only `weekly-reflection`. From a durable checkout, a symlink
may follow the installer convention. From a disposable worktree, copy this
one directory to a new versioned directory outside the skill-loading tree,
for example `~/.local/share/copilot/skill-sources/weekly-reflection/COMMIT`,
then symlink `~/.copilot/skills/weekly-reflection` to that durable copy.
This survives worktree removal and lets the existing installer later replace
only its symlink. Do not install a real copied directory in the loading tree:
the full installer would back it up there, potentially registering a duplicate.
Check both source-copy and link destinations for existing paths or dangling
symlinks; never overwrite or replace either without user approval.

Create the versioned copy directory exclusively (fail if it already exists),
then copy only `SKILL.md`, `references/`, and `templates/`. Create the user-skill
symlink only after verifying the copy; link creation must fail on an existing
destination rather than replacing it. Verify copied
content matches the reviewed source, required relative links resolve, and
frontmatter has `name: weekly-reflection` and `user-invocable: true`. Do not
copy other skills, user config, reports, or repository metadata.
If interrupted, report the exact partially installed directory; do not
pretend recognition succeeded or replace it on a later retry without
checking ownership/content.

Use the host's supported skill refresh/list mechanism to verify recognition
when available; otherwise start a new Copilot session and inspect its skill
list. Do not execute the reporting skill as an installation smoke test, or
use extension reload as a substitute for skill discovery. If this environment
cannot refresh/list skills, report the verified install path and that runtime
recognition still needs a new session rather than claiming it was observed.
