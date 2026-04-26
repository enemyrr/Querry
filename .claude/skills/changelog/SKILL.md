---
name: changelog
description: Generate a Pluk release: pull issues from a GitHub milestone, write Dia-style release notes, bump the Xcode version, append to CHANGELOG.md, and open a release PR.
---

# Changelog / Release Skill

Use this skill when the user runs `/changelog` (with or without a milestone number) or asks to create/generate release notes or a changelog for a Pluk version. It produces a complete release in one pass: notes, version bump, branch, commit, push, and PR.

If the user asks for a changelog for a concrete version (for example, "create a changelog for v0.0.1-beta.38"), treat that as release prep, not a docs-only edit. Draft the notes first, then after approval create the release branch, update both `CHANGELOG.md` and `pluk/version.xcconfig`, commit, push, and open the PR unless the user explicitly says "draft only", "changelog only", or "local only".

## Inputs

- Optional milestone number (e.g. `/changelog 16`). If omitted, inspect open milestones on `pluk-inc/Pluk`.
- Optional explicit version override (rare). Default behavior is to use the milestone title as the version.

If exactly one open milestone exists, use it. If multiple open milestones exist and the user did not specify one, **ask which to use** before continuing.

## Repo facts (don't re-discover)

- Issues live on the **public** repo: `pluk-inc/Pluk`
- PRs live on the **private** repo: `pluk-inc/app-pluk`
- Version file: `pluk/version.xcconfig` — `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
- Changelog: `CHANGELOG.md` at project root, newest entry at the top under the `# Pluk Release Notes` header
- Always use `gh` CLI (per `CLAUDE.md`), never the GitHub REST API directly through curl
- Milestone titles already follow the version format (e.g. `v0.0.1-beta.38`) — strip the leading `v` for the changelog heading

## Workflow

Run the steps in order. Surface progress with one-line updates between phases.

### 1. Resolve the milestone

```bash
# If user passed a number:
gh api "repos/pluk-inc/Pluk/milestones/<number>" \
  --jq '{number, title, state, open_issues, closed_issues, description}'

# Otherwise, list open milestones:
gh api "repos/pluk-inc/Pluk/milestones?state=open&sort=due_on&direction=desc" \
  --jq '.[] | {number, title, open_issues, closed_issues}'
```

If the list returns exactly one milestone, use it. If it returns multiple milestones, ask the user which one to release.

If `open_issues > 0`, **warn the user** and ask whether to proceed (open issues won't be in the notes). Don't auto-close issues.

### 2. Pull all issues in the milestone

```bash
gh issue list \
  --repo pluk-inc/Pluk \
  --milestone "<milestone-title>" \
  --state all \
  --limit 200 \
  --json number,title,body,labels,state,url
```

For each issue, keep `number`, `title`, `body` (truncate to ~600 chars when summarizing), and `labels[].name`. Group by label where useful (`bug`, `enhancement`, `performance`, `ai`, etc.) but the final notes should read as a narrative, not a label dump.

### 3. Determine the new version

- New `MARKETING_VERSION` = milestone title with the leading `v` stripped (e.g. `0.0.1-beta.38`).
- New `CURRENT_PROJECT_VERSION` = previous build number + 1. Read the current value from `pluk/version.xcconfig` first.
- New release date = today's date in `YYYY-MM-DD` format (use the `currentDate` from system context if present; otherwise `date +%Y-%m-%d`).

### 4. Draft the release notes in Dia style

**Canonical templates: read these first.** Open `CHANGELOG.md` and study **beta.25, beta.26, beta.27, beta.31, beta.32, beta.34** — these are the entries the user wants to match. Older entries (beta.18 through beta.24) use a deprecated format and **must not be copied**.

Reference for tone: <https://www.diabrowser.com/changelog>. The recent Pluk entries are already Dia-styled, so the existing CHANGELOG is the more accurate template.

**Structural template:**

```markdown
## [<version>] – <YYYY-MM-DD>

<One-paragraph summary. Lead with what this release feels like / what it unlocks for the user. 1–3 sentences. Use "Pluk vXX" or "This release" as the subject. Avoid changelog jargon like "version bump" or "patch".>

Here’s what’s new:

- **<Punchy feature name with period.>** <One- or two-sentence explanation in user-facing language. Link the issue at the end.> ([#<n>](https://github.com/pluk-inc/Pluk/issues/<n>))
- **<Next item.>** <Explanation.> ([#<n>](https://github.com/pluk-inc/Pluk/issues/<n>))

<Optional second group for smaller polish, intro'd with this exact sentence:>

We’ve also shipped some small but mighty updates:

- **<Polish item.>** <Explanation.> ([#<n>](https://github.com/pluk-inc/Pluk/issues/<n>))
```

The **two recurring section breaks** are literally these strings — use them verbatim. Use curly apostrophes in `Here’s` and `We’ve` to match recent Pluk entries:

- `Here’s what’s new:`
- `We’ve also shipped some small but mighty updates:` (or `…small but mighty fixes:` for a fix-heavy release, per beta.27)

If the release has only 2–3 user-facing items, drop the second group entirely — see beta.28 and beta.30.

**Voice & word choices (from Dia + existing Pluk entries — keep these):**

- Use contractions: "you can now", "we've", "it's"
- Lead bullet with **bold feature name ending in a period**, then the explanation as separate sentences
- Prefer "ship/shipped" over "release", "polish" over "minor improvements"
- Forward-looking, calm tone — not marketing-y, not overly casual either
- Em dashes (`—`) are fine for emphasis; avoid exclamation points
- Use the actual em dash character `–` in the version heading (matches existing entries)
- Group related fixes under one bullet rather than listing every commit
- A pure bug-fix release can use the "polish & stability" framing — see beta.30 for a template

**Dia-style rewrite heuristics:**

- Start each bullet with a concrete user-facing noun phrase, not an engineering verb: `Faster data loading`, `A calmer sidebar`, `More reliable PostgreSQL editing`.
- Make the first sentence about what users can now do or what feels better. Push implementation details into the second sentence only when they help explain the benefit.
- Collapse internal work into outcomes: "refactored connection routing" becomes "shortcuts route to the right window and database more reliably."
- Give the release a theme in the summary paragraph: speed, flow, table editing, workspace switching, stability, or polish. Avoid just listing issue categories.
- Prefer one strong grouped bullet over several tiny fix bullets when issues share the same user-facing area.

**What NOT to do:**

- Don't paste issue titles verbatim — rewrite for end users
- Don't list every issue if several roll up into one user-visible change
- Don't include internal refactors, CI changes, or dep bumps unless they ship a user-visible improvement
- Don't add emoji unless the existing changelog already uses them (it doesn't)
- Don't fabricate features. If an issue is unclear, read the issue body via `gh issue view <n> --repo pluk-inc/Pluk`

### 5. Show the draft for approval

Before writing files or creating a PR, **print the drafted release notes inline** and ask the user to confirm or edit. They may want to tweak wording, reorder bullets, or drop items. Don't skip this step even in auto mode — the notes ship to users.

### 6. Apply the changes

After approval:

Do not stop after local file edits. A normal release run is complete only after the release branch is pushed and the PR is opened.

1. **Check the working tree before changing files.** If it has unrelated changes, stop and ask — don't stash or discard.
2. **Create a release branch** off `main` before editing files:
   ```bash
   git checkout main && git pull --ff-only
   git checkout -b release/<version>   # e.g. release/0.0.1-beta.38
   ```
3. **Update `pluk/version.xcconfig`** — bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Use the Edit tool, not sed.
4. **Update `CHANGELOG.md`** — insert the new section directly under the `# Pluk Release Notes` heading (newest first). Do not reorder or rewrite older entries.
5. **Commit** with a message like:
   ```
   Release <version>
   ```
   Stage only `pluk/version.xcconfig` and `CHANGELOG.md`. Do not add generated-by or co-author attribution unless the user explicitly asks for it.
6. **Push** with `git push -u origin release/<version>`.

### 7. Open the PR

This step is mandatory for normal release prep. Skip it only when the user explicitly requests draft-only, changelog-only, or local-only output.

```bash
gh pr create \
  --repo pluk-inc/app-pluk \
  --base main \
  --title "Release <version>" \
  --body "$(cat <<'EOF'
## Summary

Cuts <version> from milestone [<milestone-title>](https://github.com/pluk-inc/Pluk/milestone/<n>).

<Paste the release notes body here — same content that landed in CHANGELOG.md, minus the `## [version] – date` heading.>

## Test plan

- [ ] Build the `Collection` scheme locally and smoke-test the highlighted features
- [ ] Verify About box shows `<MARKETING_VERSION> (<CURRENT_PROJECT_VERSION>)`
- [ ] Confirm appcast generation picks up the new CHANGELOG section
EOF
)"
```

Return the PR URL to the user.

## Style cheatsheet (quick reference)

Good (matches existing entries):

> **More reliable PostgreSQL editing.** Updates and deletes now work better for non-public schemas and UUID primary keys. ([#105](https://github.com/pluk-inc/Pluk/issues/105))

Bad (issue title pasted, no narrative):

> - Fix UUID PK update bug in PG driver (#105)

Good summary paragraph:

> This release is focused on making everyday table work feel smoother and more reliable. We tightened up editing, improved QuickLook for JSON-heavy fields, fixed a bunch of database-specific edge cases, and cleaned up a few rough spots when switching between connections and databases.

Bad summary:

> Version 0.0.1-beta.32 has been released. It contains 12 bug fixes and 3 new features.

## Failure modes to handle

- **No open milestone found** → tell the user and stop. Don't invent a version.
- **Milestone has 0 closed issues** → ask the user whether to release anyway (e.g. for a polish-only build referencing recent merged PRs instead).
- **Working tree dirty** → list the dirty files and ask before branching. Never discard work.
- **`main` not fast-forwardable** → stop and surface the conflict; let the user resolve.
- **PR creation fails (auth, branch protection)** → surface the exact `gh` error, don't retry blindly.

## Don't do

- Don't run `xcodebuild` to verify the version bump (per `CLAUDE.local.md` the user builds manually).
- Don't tag the release or publish a GitHub release — that's a separate step the user owns.
- Don't close the milestone automatically — the user does that after the release ships.
- Don't push to `main` directly. The PR is the gate.
