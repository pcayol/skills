---
name: pr-comments-triage
description: Bulk triage of a PR with too many review comments to answer one by one. Fetches every unanswered thread, gives each an ID (R1, R2…), checks each claim against the code, decides if the bug is reachable and if this PR introduced it, then delivers a verdict table and a plain explanation per comment. Read-only. It never edits code, posts, or drafts replies. Use when the user says "trier les retours", "faire le tri dans les commentaires", "y a trop de commentaires sur cette PR", "which of these are real bugs", or hands over a PR URL asking what deserves a fix.
---

# pr-comments-triage

Sort a pile of review comments into "needs a change in this PR" and "does not", with the reasoning shown.

**Read-only.** No code edit, no post, no reply drafted. The user decides what to answer.

Write the deliverable in the user's language.

## 1. Frame the PR

Before reading any comment, establish two facts:

- **The base branch.** `gh pr view <N> --json baseRefName`. Every scope question compares against it.
- **The kind of PR.** On a behaviour-preserving refactor, "this could be better" is usually a separate ticket. On a feature PR, it may be in scope. The description usually says. If not, ask one question.

Note what the PR claims to change. On those behaviours, "it was already like that" is not a valid defence.

## 2. Build the worklist

```bash
scripts/unanswered.sh <pr-number> [owner/repo]
```

It lists threads that are unresolved **and** never answered by the author, then the review bodies and issue comments.

- Use `gh`, not WebFetch. Repos are often private.
- Do not rebuild this from the REST `/pulls/<N>/comments` endpoint. It has no `isResolved`, so settled threads come back.
- `isOutdated` is not resolution. It only means the line moved.

**Number the comments** `R1`, `R2`… in this order: threads by date, review bodies, issue comments by date. An ID is never reused or renumbered. On a rerun, new comments continue the sequence.

**Sort each comment.** Does it name an input, a timing or an environment that makes the code behave wrongly?

- Yes → **defect list**, goes through the four questions.
- No → **other comments**: naming, doc, test to add, question. Only check facts they state.
- Unsure → defect list.

## 3. Find what is already fixed

```bash
git log --format='%h %ad %s' --date=iso <base>..HEAD
```

Compare comment dates with later commits. Confirm each fix in the code, not from the commit subject.

## 4. Four questions per defect

They are independent. A claim can be true and reachable, and still need no change.

1. **Is the claim true?** Check the line, the grep, the "never tested". Stop here if it is false.
2. **Is it reachable?** Write the trigger in one sentence: which user, data, timing, environment. No sentence, not reachable.
3. **Whose bug is it?** Run `git show <base>:<path>` and compare.
   - Identical on base → pre-existing.
   - Introduced by this PR → in scope.
   - Dead code on base that this PR brought to life → in scope too. This is the case people miss.
4. **Is the suggested fix correct?** Judge it apart from the diagnosis. A right diagnosis often comes with a wrong fix, especially from AI reviewers.

## 5. Verdicts

### Defect list

| Verdict | Meaning |
|---|---|
| **CONFIRMÉ** | Reachable, caused or activated by this PR. Requires the trigger sentence. |
| **DÉJÀ CORRIGÉ** | Fixed on the branch since. Proof is a `file:line`. |
| **PRÉEXISTANT** | Identical on base. Out of scope by default, ticket. |
| **NON ATTEIGNABLE** | Real mechanism, no trigger. Say what blocks it. |
| **INFIRMÉ** | The claim is false. Say what it got wrong. |
| **INDÉCIDABLE** | Rare. Name the exact check you could not run. |

The suggested fix gets its own column: **correct**, **partiel**, **incorrect**, or **aucun**.

### Other comments

| Decision | Meaning |
|---|---|
| **ACCEPTER** | Cheap, right, on code this PR wrote. |
| **DÉCLINER** | Wrong, not worth it, or taste. One line why. |
| **TICKET** | Right but bigger than this PR. |
| **À TRANCHER** | Only the user can decide. |

## 6. Deliverable

In this order:

1. **Framing.** A few lines: how many comments, how many already fixed, the one fact that drives the scope calls.
2. **Defect table.** ID, `file:line`, claim, verdict, trigger or blocker, fix. CONFIRMÉ first.
3. **Other-comments table.** ID, `file:line`, type, subject, decision.
4. **Detail.** Only where the row is not enough: every CONFIRMÉ, and any verdict likely to be contested. Group IDs that share a root cause.
5. **One section per comment**, headed `R3 · <github-id>`:
   - **Le problème**: one plain sentence, as said to a colleague.
   - **Quand ça arrive**: the concrete scenario in two or three lines, with the `file:line`.
   - **Verdict**: a few words.

   A reader new to the file must get it on the first read. Prefer an example sequence over a description of the mechanism. Five lines max.

### Citation rules

- **Every mention of a comment is a link**, with our ID as text. Only the per-comment headings stay plain.
  - Thread: `https://github.com/<owner>/<repo>/pull/<N>#discussion_r<ID>`
  - Issue comment: `…/pull/<N>#issuecomment-<ID>`
  - Review body: `…/pull/<N>#pullrequestreview-<ID>`
- **Never cite a commit by hash alone.** Write `File.js:781 (5a02e613f7)`: path and line first, hash as provenance. Read the line number from the current file, not from an old diff.

## Common mistakes

- Skipping Q3. Pre-existing behaviour then gets rewritten in a PR meant to preserve it.
- Confusing "real mechanism" with "reachable".
- Accepting a fix because the diagnosis was right.
- Hedging. "Not reachable, because X" is the answer, not "maybe".
- Moving a defect to "other comments" to avoid checking it.
