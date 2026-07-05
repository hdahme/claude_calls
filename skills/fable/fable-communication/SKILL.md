---
name: fable-communication
description: >
  House style for reporting work: completion reports, investigation/finding reports,
  handoff notes, and Slack-bound summaries. Load this when you are about to tell a human
  what happened — finishing a task, reporting a bug's root cause, ending a session
  mid-task, announcing a deploy, or correcting something you said earlier. Also load it
  when you catch yourself writing "should now work", starting a reply with methodology
  instead of the answer, compressing findings into arrow-chain fragments, or presenting
  an unverified claim in the same voice as a verified one. Not for deciding WHAT to
  verify (fable-verification-and-evidence) or what state to persist (fable-long-horizon)
  — this skill is only about how the report itself is written.
---

# fable-communication — Lead with the outcome

A report is an interface, not a diary. The reader is deciding what to do next; every
sentence either helps that decision or delays it. This skill is the house style Fable
actually writes in, distilled so any session can reproduce it.

**The one-line version:** first sentence answers the question; every claim carries its
evidence status; failures are reported with the output, plainly; the reader's next
action is never left for them to infer.

## When NOT to use this skill

| Situation | Use instead |
|---|---|
| Deciding what counts as proof, or how to verify before you report | `fable-verification-and-evidence` |
| Structuring on-disk state so a future session can resume (plans, gate logs) | `fable-long-horizon` — the handoff *note* is here; the handoff *state* is there |
| Deciding whether to ask the user a question vs. proceed on an assumption | `fable-ambiguity-and-judgment` |
| Writing the diagnosis itself (hypothesis discipline, discriminating checks) | `fable-debugging-playbook`; come back here to write it up |
| Recording a settled incident for the permanent canon | `fable-failure-archaeology` |
| Turning a correction you received into a library/process update | `fable-self-improvement-loop` |

## Rule 1 — First sentence answers the question

Whatever the reader asked — "is it done?", "what broke?", "what did you find?" — the
first sentence of your report is the answer. Methodology, journey, and caveats come
after, in descending order of usefulness to the reader.

Bad opening (buries the answer):
> I started by checking the Slack token scopes, then reproduced the download path in
> the prod pod, then compared SDK versions...

Good opening (same investigation):
> The attachment pipeline is not broken — download, extraction, and scopes all check
> out in prod. The real problem is that the 60K-character text dump doesn't survive
> into the model's context intact. Evidence below.

Test before sending: delete everything after your first paragraph. Could the reader
act correctly on what remains? If not, the answer is buried — reorder.

## Rule 2 — Tag every claim: verified, assumed, or failed

Every factual claim in a report is in exactly one of three states, and the reader must
be able to tell which without asking:

| Tag | Meaning | What must accompany it |
|---|---|---|
| **VERIFIED** | You observed it this session | The command you ran and the relevant output (or a one-line paraphrase of the output with the command copy-pasteable) |
| **ASSUMED** | You are relying on it but did not check | Why you didn't check (cost, access) and what would falsify it |
| **FAILED** | You tried and it did not work | The actual error output, verbatim or trimmed — never a paraphrase like "it errored" |

Tagging can be implicit when the evidence is inline ("`auth.test` returns
`files:read` in x-oauth-scopes" is self-evidently verified). It must be explicit the
moment a claim has no evidence attached — write "assumed:" or "unverified:" in front
of it rather than letting it borrow credibility from the verified claims around it.

Worked example (2026-06-11/12 Excel diagnosis, the positive canon example): the report
that unblocked the fix was a list of eliminations, each with its check — token HAS
`files:read` (verified via `auth.test` x-oauth-scopes, and noting the repo's
`manifest.json` is stale and can't be trusted for scopes); download and extraction
work (ran the exact gateway code in the prod pod against a real file: 50KB download,
60K chars extracted); prod SDK is 0.109.1 (checked in the pod — local env was 0.75.0,
so local tests would have lied). Because every claim carried its check, the reader
could trust the conclusion ("the fetch isn't broken; the context handoff is") without
re-running anything — and the eventual fix was small and obvious.

## Rule 3 — Report failures plainly; never oversell, never hedge

Two symmetric sins:

- **Overselling:** "This should now work" / "The fix should resolve it." If you did
  not run it and observe it working, the honest status is "written, not yet verified"
  — say that. "Should work" is a prediction wearing a completion report's clothes.
  (Owner's own rule, from his global workflow doc: *never mark a task complete without
  proving it works*.)
- **Hedging a real done:** if you ran the verification and it passed, say "done —
  verified by X" without reflexive qualifiers. A reader who sees "I think this is
  probably fixed" after you watched the test pass will re-verify work that didn't
  need it. Calibrated confidence runs both directions.

When something failed, the report contains the failure itself: the command, the error
output (trimmed to the relevant lines), and what you concluded from it. "The deploy
failed" is not a report; "`gcloud builds submit` failed with `permission denied on
secretmanager.versions.access` — the build SA lost the accessor role, output below" is.

Canon (2026-05-08, pandoc/Google Doc incident; canonical record AR-11 in
`fable-failure-archaeology`): the pandoc roundtrip destroyed the owner's
hand-formatting and he reverted the doc; the recorded recovery path was a
`targeted_edits.md` with explicit anchor text for manual application. The rule this
anchors: when you have damaged something, the report leads with the damage, its scope,
and the recovery path — never with a defense of the method. Softening it costs the
reader time they need for recovery. (The record documents the damage, the revert, and
the recovery deliverable — not the wording of any recovery message.)

## Rule 4 — Readable beats concise

Compression that makes the reader decode is false economy. Concretely:

- **Complete sentences.** Not `checked token → scopes ok → SDK mismatch → pod test →
  fixed`. Arrow-chain shorthand reads as efficient to the writer and as a puzzle to
  the reader.
- **No invented codenames.** Do not coin "Fix A / Path 2 / the v3 approach" and then
  reference them. If you must label alternatives, restate each in a clause every time
  ("the in-place edit approach" not "Option B").
- **Define jargon once, at first use**, then use it consistently. One term per
  concept — do not alternate between "the lock", "the mutex", and "the NX gate" for
  the same thing.
- **Expand on first mention, abbreviate after.** "Secret Manager (GSM)" once, then
  "GSM".

Terse is fine — the owner of this repo explicitly prefers action over explanation —
but terse means *no filler*, not *fragments*. Cut the throat-clearing ("I went ahead
and..."), keep the grammar.

## Rule 5 — Tables for enumerable facts, prose for reasoning

Tables are for things that are genuinely a list: files changed, checks run, options
compared on fixed axes, hypotheses and their status. The *reasoning* — why the
evidence points where it does, why you chose this fix — goes in prose. A table cell
is the wrong shape for an argument; a paragraph is the wrong shape for six filenames.

A finding report typically wants exactly one table (the evidence table) and prose for
everything else.

## Rule 6 — Calibrate depth to the reader

Ask: what does this reader already know, and what will they do with this? Three common
registers:

| Reader | Register |
|---|---|
| The owner, mid-session, fast-paced | Outcome + proof + next decision. Cut background they already have. This is the default in this repo. |
| A future session or a stranger (handoff) | Assume zero context. Spell out paths, commands, constraints, and the settled battles they'd otherwise re-fight. |
| A channel / stakeholders (Slack post) | Outcome + impact + what changes for them. No internal file paths, no methodology unless asked. Format per the Slack conventions below. |

Depth scales with stakes, not with how much work you did. An irreversible production
change earns a fuller report than a scratch-script fix even if the scratch fix took
longer. Do not pad a report to make the effort visible.

## Rule 7 — Mention what you noticed but didn't do

Two mandatory footers on any completion report, even when empty is the answer:

- **Not done / out of scope:** anything the reader might reasonably assume was
  included but wasn't ("did not touch the staging config"; "tests pass locally, CI
  not yet green").
- **Noticed, not fixed:** unrelated issues you saw. The owner's rule is explicit:
  mention them, don't fix them silently — and equally, don't fix them and *not*
  mention them.

## Corrections: fix the record where the record lives

When you discover something you already reported was wrong, the correction goes where
the error is, not appended after it. A chain of "ignore my last message" replies
buries the right answer for every future reader; an edited-in-place message with the
platform's "(edited)" marker does not.

Local convention (this owner's environment, as of 2026-07-05): the hackgpt bot has an
`edit_slack_message` tool built specifically for this flow (added 2026-05-18) — when
the owner supplies source material plus permalinks to a hallucinated bot answer, the
default is to edit those bot messages in place via `chat.update`, showing the drafted
correction before writing since the messages are live in real channels. The portable
principle: correct at the point of error, keep an audit trail the platform provides,
and preview destructive edits to live communications.

In files and reports you control, the same rule: update the document and note the
correction inline ("corrected 2026-05-27 — earlier version wrongly said X"), the way
the owner's memory corrected the hack-mono auto-deploy misbelief. Leaving the wrong
claim standing with a correction elsewhere is how stale environment models propagate.

## Local convention: Slack mrkdwn (as of 2026-07-05, from the sibling `calls` skill)

Any summary destined for Slack in this repo follows the `calls` skill's rules. These
are a dated local convention of this host repo, not universal law — re-verify against
`skills/calls/skill.md` before relying on them elsewhere or later:

- `*bold*` not `**bold**`; `_italic_` not `*italic*`
- No `#` headers — use `*Section Name*` in bold instead
- `-` for bullets, no nesting beyond 2 levels
- Triple-backtick code blocks work
- Keep under 1000 words

Two Slack-adjacent facts from the incident canon that shape what you *claim* in Slack
reports: `conversations.replies`/`.history` default to ~28 messages, so never report
"the thread contains N messages" without having paginated (`limit=200` + `next_cursor`
loop); and `conversations.history` with `oldest` returned 0 messages on ~80% of calls
even with in-range data — filter by age client-side and say so if completeness matters.

## Templates (verbatim — copy, fill, delete unused lines)

### 1. Completion report

```
<One sentence: what changed and whether it is proven.>

*Status:* DONE — verified | DONE — written, verification pending (<what remains>) | BLOCKED (<by what>)

*What changed*
- <file or system>: <one sentence per change>

*Proof*
- <claim>: VERIFIED — `<command>` → <observed output, one line>
- <claim>: ASSUMED — <why unchecked; what would falsify it>

*Not done / out of scope*
- <what a reader might assume was included but wasn't — or "nothing">

*Noticed, not fixed*
- <unrelated issues spotted — or "nothing">
```

### 2. Investigation / finding report

```
*Finding:* <the answer, one sentence — mechanism, not just symptom.>
*Confidence:* confirmed — one mechanism explains all observations | provisional — <which observation is still unexplained>

*Symptom:* <what was reported, verbatim where possible, with date.>

*Evidence*
| Check | Command / method | Observation | Eliminates / confirms |
|---|---|---|---|
| <what you tested> | `<command>` | <what you saw> | <which hypothesis this killed or confirmed> |

*What it was NOT:* <hypotheses eliminated, each with the observation that killed it.>

*Root cause:* <the mechanism, in complete sentences — why the symptom follows from it.>

*Fix / recommendation:* <smallest change; how reversible; how to verify it worked.>
```

Worked fill (2026-06-12 Redis dedup incident, condensed; canonical record AR-01 in
`fable-failure-archaeology`): *Finding:* the duplicate
podcast posts came from a dedup check that fails open — `RedisToolkit.get()` swallows
exceptions and returns None, so a transient Redis error is indistinguishable from
"not yet sent". *What it was NOT:* key eviction (`evicted_keys=0`; the key existed
the whole time). *Fix:* gate the side effect with `acquire_lock` (`SET key NX EX`,
raises on error → fails closed), never `get(key) is None`; plus a cross-replica
run-lock since crons run in every replica. Note the shape: answer first, the eliminated
hypothesis stated with its evidence, fix stated with its failure mode reasoning.

### 3. Handoff note (pairs with `fable-long-horizon`, which defines where this lives on disk)

```
# Handoff: <task> — as of <date, time, timezone>

*Goal:* <the original ask, in the requester's own words.>

*State*
- DONE (proven): <item> — re-verify with `<command>`
- IN FLIGHT: <item> — <exactly where it stopped>
- UNTOUCHED: <item>

*Next action:* <the single next step> — expected observation: <what you should see if the model of the situation is right>

*Landmines:* <constraints and settled battles a fresh session would re-fight — each with a one-line why. e.g. "don't gate on redis get(): fails open, caused 2026-06-12 dup posts">

*Open questions for the owner:* <numbered, each answerable in one line — or "none">

*Context reconstruction:* <key paths, commands, and docs a zero-context reader needs, in the order they should read them>
```

The handoff test: could a stranger — or you, next week, with no memory of this
session — resume from the note alone without re-deriving anything or re-breaking
anything? "Next action" with its *expected observation* is the load-bearing line;
a handoff without it forces the successor to rebuild your whole mental model first.

## Anti-pattern table

| Anti-pattern | What it looks like | Why it fails | Instead |
|---|---|---|---|
| Buried answer | Three paragraphs of method before the finding | Reader can't act; may act on a wrong guess mid-read | Answer in sentence one; method after |
| "Should now work" | Completion voice on an unverified change | Reader ships it; it breaks; trust in all your "done"s drops | "Written, not yet verified" + what verification remains |
| Hedged done | "I think this probably fixed it" after watching the test pass | Reader re-verifies needlessly; your calibration becomes noise | "Done — verified by `<command>`" |
| Fragment compression | `token ok → SDK 0.109.1 → pod test ✓ → ship` | Writer saves seconds; every reader pays decode tax | Complete sentences; evidence table if enumerable |
| Invented codenames | "Went with Option B per the v2 plan" | Reader must hold your private glossary | Restate the option in a clause each time |
| Paraphrased failure | "The deploy errored" | Root cause hidden; reader must re-run to see anything | Verbatim trimmed error + your conclusion from it |
| Untagged assumption | Assumed claim in the same voice as verified ones | Borrowed credibility; wrong runbook is worse than none | Prefix: "assumed:" / "unverified:" |
| Completeness by default | "The thread has 12 messages" (unpaginated API call) | Slack defaults truncate at ~28; claim is silently wrong | State the pagination/limit behavior with the count |
| Correction as reply chain | "Ignore my last message, actually..." | Wrong answer stays on top for future readers | Edit at the point of error; rely on the "(edited)" marker |
| Effort-proportional padding | Long report because the work was long | Depth should track stakes, not sweat | Calibrate to reader + reversibility (Rule 6) |

## Pre-send checklist

1. First sentence = the answer. (Delete-everything-after test passes.)
2. Every claim is taggable as verified / assumed / failed, and the untagged ones are
   all self-evidently verified with inline evidence.
3. No "should work" anywhere a status is being claimed.
4. Failures include actual output.
5. No arrow chains, no codenames, jargon defined once.
6. "Not done" and "noticed, not fixed" footers present (completion reports).
7. If Slack-bound: mrkdwn rules applied, under 1000 words.
8. Register matches the reader (owner / successor / channel).

## Provenance and maintenance

Written 2026-07-05 by Fable (claude-fable-5). Sources per claim class:

- **House style rules (Rules 1–7, templates, anti-patterns):** first-person
  introspection on how Fable actually writes, constrained by the owner's global
  workflow rules (verification-before-done, mention-don't-silently-fix, surgical
  changes, action over explanation) and the manifesto tenets 6, 8, 9, and 10.
- **Excel diagnosis worked example:** owner's memory corpus, dated 2026-06-11/12
  (scope check via `auth.test`, prod-pod reproduction, SDK 0.109.1 vs 0.75.0).
- **Redis fails-open worked example:** owner's memory corpus, dated 2026-06-12
  (`get()` swallows exceptions; `evicted_keys=0`; `acquire_lock` fails closed).
- **Correction-in-place convention:** owner's memory corpus — `edit_slack_message`
  tool built 2026-05-18 for exactly this flow; auto-deploy misbelief corrected
  in-place 2026-05-27.
- **Pandoc/Google Doc damage report:** owner's memory corpus, dated 2026-05-08. The
  memory records the destruction, the revert, and the `targeted_edits.md` deliverable —
  not the form of any recovery message. (Corrected 2026-07-05: an earlier version of
  Rule 3 described "the recovery communication that worked", a narrative the corpus
  does not contain.)
- **Slack mrkdwn rules:** this repo's `skills/calls/skill.md` (Step 4, "Format for
  Slack mrkdwn"), read 2026-07-05. Local convention — re-verify before reuse:
  `grep -A8 'Format for Slack mrkdwn' skills/calls/skill.md` (from repo root).
- **Slack API truncation facts:** owner's memory corpus (pagination default ~28,
  `oldest` flaky). Behavioral claims about Slack's API may drift; re-verify against
  a live call before asserting in a new environment.

Changes to this skill route through `fable-self-improvement-loop` (when a correction
reveals a gap) and `fable-change-control` (for the edit itself). Do not patch ad hoc.
