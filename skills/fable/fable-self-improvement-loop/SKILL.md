---
name: fable-self-improvement-loop
description: >-
  Load the moment any of these happens: the user corrects you, pushes back,
  reverts your work, or says any variant of "no, that's wrong" / "we already
  solved this" / "why did you do that"; a surprise costs you more than 15
  minutes; you catch yourself re-fighting a battle that a doc or memory says
  was already settled; you finish diagnosing an incident and are about to
  write it up; you are deciding WHERE a new lesson should live; or you are
  ending a session whose transcript contains a correction you have not yet
  captured. This skill turns those events into permanent library updates and
  owns the metric that decides whether the library is actually improving.
---

# Fable Self-Improvement Loop

**Correction → captured lesson → routed update → measured recurrence. The compounding mechanism of the whole library.**

Core idea (Tenet 10): a mistake made twice is a process failure, not a model
failure. Every correction is raw material; this skill is the refinery. The
library's success bar explicitly includes "the library improves itself after
every correction" — that clause is implemented *here*, and the falsifiable
metric that proves it lives at the bottom of this file.

Jargon, defined once:

- **Correction** — any signal that your output or process was wrong: an
  explicit user rebuke, a revert of your work, a re-ask with narrowed scope,
  or your own discovery that you violated a documented rule.
- **Lesson** — a correction written down in the fixed five-field format (§2).
- **Canonize** — give a lesson a permanent home in the library via §3–§4.
- **Recurrence** — the same failure *class* firing again AFTER its lesson was
  canonized. (The same bug firing twice before diagnosis is one incident.)
- **Ledger** — the table of incident classes × recurrence dates (§5).
- **Attic** — the dated graveyard for retired rules (§6). Nothing is ever
  silently deleted.

---

## 0. The loop at a glance

| # | Step | Output | Time budget |
|---|---|---|---|
| 1 | **TRIGGER** — recognize a loop-worthy event | decision: capture or not | seconds |
| 2 | **CAPTURE** — write the lesson in the fixed format | 5-field lesson block | 2–5 min |
| 3 | **ROUTE** — choose the one home for the fact | destination file + section | 1 min |
| 4 | **UPDATE** — smallest diff, via change-control | dated edit + provenance line | 5–10 min |
| 5 | **MEASURE** — update the recurrence ledger | ledger row touched | 1 min |

Run all five. Steps 2–5 skipped "because the session was ending" is itself a
canon failure mode: the 2026-02-12 incident (below) was a mandated ritual
skipped for an entire session until the owner had to call it out.

---

## 1. TRIGGER — what starts the loop

Any ONE of these fires the loop. Do not wait for two.

1. **User correction** — of any size. "Actually, use X", a revert, an
   exasperated quote, a re-explanation of something you should have known.
   The owner's global rule is explicit: *after ANY correction, capture the
   pattern.* Not "significant corrections" — any.
2. **Surprise costing >15 minutes** — you predicted one observation and got
   another, and recovering ate real time. Surprise means your model of the
   system was wrong somewhere; that delta is a lesson even if nobody
   corrected you.
3. **Re-fought settled battle** — you spent effort rediscovering something a
   memory, skill, or doc already recorded. The lesson here is usually about
   *routing or retrieval* (the fact existed but wasn't found), not about the
   fact itself. Capture where the lookup failed.
4. **Incident closed** — you just root-caused a production or workflow
   failure. The postmortem IS the capture step; don't write it twice in two
   formats.

**Negative trigger (do not capture):** one-off trivia with no prevention rule
("the user prefers this variable name here"), and anything already canonized
verbatim — for those, go to §5 and log the recurrence instead of re-writing
the lesson.

---

## 2. CAPTURE — the fixed lesson format

Write every lesson in exactly these five fields. The format is the contract
that makes lessons greppable, auditable, and mergeable across sessions.

```markdown
### <short class name, kebab-case>
- Symptom: <what was observably wrong, as the user or system saw it>
- Wrong move: <what was actually done, stated plainly, no face-saving>
- Right move: <what should have been done instead>
- Prevention rule: <a checkable, mechanical rule that would have blocked the wrong move>
- Date: <YYYY-MM-DD of the correction, not of the writing>
```

Quality bar for the **Prevention rule** field — it must be:

- **Triggered by an observable condition**, not a mood. Bad: "be careful with
  Slack APIs." Good: "any `conversations.history`/`conversations.replies`
  call passes `limit=200` and loops on `next_cursor`, no exceptions."
- **Mechanical** — a mid-level engineer or Sonnet-class model can execute it
  without judgment. If it needs judgment, you haven't found the rule yet.
- **Checkable after the fact** — a reviewer can grep or diff to see whether
  it was followed.

A lesson whose prevention rule fails this bar is not done. Rewrite it before
routing.

**Worked example (from the canon, incident of 2026-06-12; canonical record: AR-01
in `fable-failure-archaeology`).** A dedup check in
a Slack-posting cron was built on "cache `get(key)` returned None ⇒ not yet
sent." The cache client swallowed exceptions and returned None on error, so a
transient Redis blip made an already-sent item look unsent and it re-posted.
Captured in format:

```markdown
### fails-open-safety-check
- Symptom: duplicate podcast posts to a live Slack channel.
- Wrong move: gated a side effect on `get(key) is None`, where get() swallows
  exceptions and returns None on any Redis error — the guard fails OPEN.
- Right move: claim atomically BEFORE the side effect with a lock that fails
  closed: SET key NX EX (acquire_lock); False ⇒ already claimed ⇒ skip;
  exception ⇒ fail closed ⇒ retry later. Also: crons running in every replica
  need a cross-replica run-lock, not just a per-item key.
- Prevention rule: never gate an irreversible side effect on a read that can
  return the same value for "absent" and "errored". Grep the client for
  `except` before trusting it as a guard.
- Date: 2026-06-12
```

Note what the format forces: the wrong move is stated without cushioning, and
the prevention rule generalizes past Redis to the whole class ("any read that
conflates absent with errored").

---

## 3. ROUTE — one home per fact

Every lesson gets exactly ONE canonical home. Everything else that mentions
it is a cross-reference pointing there. Duplicated facts drift independently
and then contradict each other — that is worse than no fact at all.

| Lesson type | Canonical home (this library) | Test |
|---|---|---|
| Dated incident: symptom → root cause → evidence | `fable-failure-archaeology` | "It happened once, on a date, in a system." |
| Recurring **reasoning** error (a wrong move any project could make) | The anti-patterns section of the relevant method skill (`fable-debugging-playbook`, `fable-decomposition`, `fable-verification-and-evidence`, …) | "The mistake is in the thinking, not the system." |
| New **non-negotiable** (a rule that gates actions) | `fable-change-control` | "Violating it once caused an incident; it must bind every future session." |
| Retrieval/routing failure (the fact existed, wasn't found) | `fable-core` (the router) or the mis-triggering skill's `description` | "The library had it; the session missed it." |
| Wrong-recurrence signal (a canonized lesson fired again) | §5 ledger in THIS skill | "Nothing new to learn; the measurement changed." |

Most incidents produce **two** entries: the dated story in
`fable-failure-archaeology` (canonical) and a one-line prevention rule in a
method skill or `fable-change-control` (cross-referencing the story). The
story is the home; the rule cites it.

**Worked-example clause (clarified 2026-07-05).** A method skill may
additionally retell an incident as a worked example, but only where it
illustrates that skill's own method, and every retelling must cite the
canonical AR entry. On any conflict of detail between a retelling and its AR
entry, the AR entry wins and the retelling gets corrected — a drifted
retelling is a §5 recurrence event for this rule, not a debate. Do not add new
retellings where a two-line pointer to the AR entry would serve.

**Portable layer:** in a plain project without this library, the same routing
applies with plain files — dated incidents to the project's postmortem log,
prevention rules to `tasks/lessons.md` (the owner's global convention as of
2026-07-05), environment facts to the project memory/CLAUDE.md. The invariant
is identical: one home, cross-reference elsewhere.

**Worked example (routing done right, 2026-05-20).** Four externally-sourced
coding principles were merged into the owner's global workflow rules. The
decision on record: integrate them INTO the existing numbered rules — fold
"Think Before Coding" into the plan-mode rule, add "Surgical Changes" as a
new numbered rule — rather than append a separate section. Reason, quoted
from the memory: the file should read as *"one coherent rule set, not stacked
layers."* And the routing decision itself was then captured as a lesson so no
future session re-extracts those principles into a separate section. Routing
decisions are themselves facts worth one home.

---

## 4. UPDATE — via change-control, smallest diff

Editing this library is a state change like any other. **Load
`fable-change-control` and follow it** — this skill does not and may not
route around it. The specific discipline for lesson-driven edits:

1. **Smallest diff that encodes the rule.** Add the lesson block or the
   one-line rule; do not reorganize the section, do not "improve" adjacent
   prose, do not re-flow tables. A lesson edit that touches 40 lines to add
   4 is wrong.
2. **Date-stamp everything volatile.** The lesson carries its correction
   date; any claim about an external system carries "as of YYYY-MM-DD".
3. **Update the destination skill's Provenance section** — one line: what was
   added, sourced from which correction, on which date.
4. **Correct in place, visibly.** If the lesson *contradicts* something the
   library already says, the old claim is not silently overwritten: fix it
   and leave a dated correction note (see the worked example in §6 — the
   canon does exactly this), or move the old rule to the attic.
5. **Never re-preach.** If the lesson already exists and recurred anyway,
   adding a second, louder copy is forbidden. Go to §5: the existing lesson
   failed and must be *rewritten* — sharper trigger, more mechanical rule,
   better routing — in its one home.

---

## 5. MEASURE — the recurrence ledger and the metric

**The falsifiable metric of this whole library:** recurrence of canonized
failure classes trends to zero across sessions. If the ledger shows a class
recurring after canonization, the lesson is defective — rewrite it (per §4.5)
until the class stops recurring. A lesson that doesn't reduce recurrence gets
rewritten, not re-preached.

The live ledger is the table below, in this file. On every recurrence: add
the date to the row, then rewrite the failed lesson in its canonical home
(that rewrite goes through §4 like any edit). On every new canonized lesson:
add a row.

### Recurrence ledger (seeded from the incident canon, as of 2026-07-05)

| Failure class | Canonized | Recurrences since canonization | Status |
|---|---|---|---|
| fails-open-safety-check (dedup on a read that swallows errors) | 2026-06-12 | — | watch |
| silent-exception-masking (broad `except` hides AttributeError; looks like model regression) | 2026-04-21 | — | watch |
| pagination-truncation (API default page ≈28 msgs; no cursor loop) | 2026-04-21 | — | watch |
| flaky-server-filter (Slack `oldest` returns 0 msgs ~80% of calls; filter client-side) | 2026-05-04 | — | watch. Fired 2026-04-27 and 2026-05-04 *before* diagnosis — counted as one incident |
| dep-before-import (import landed in auto-deployed code before dep verified in requirements.txt → prod CrashLoop) | 2026-04-19 | — | watch |
| stale-environment-model (acted on outdated belief about deploy behavior; corrected 2026-05-27) | 2026-05-27 | — | watch |
| preflight-ritual-skipped (mandated session-start step skipped whole session) | 2026-02-12 | — | watch |
| destroyed-human-formatting (export→patch→pandoc→replace on a hand-styled doc) | 2026-05-08 | — | watch |
| wrong-destination-write (scratch written into sibling project holding the style template) | 2026-05-08 | — | watch |
| env-flag-side-effect (SLACK_CLIENT_ID/SECRET in env flips Bolt to file-based install store; breaks readonly rootfs) | 2026 (session of 2026-04-19 hardening) | — | watch |

Reading the ledger honestly:

- "—" means *no recurrence observed*, which is weaker than *prevented*. Only
  a class that had real opportunities to recur and didn't counts as evidence
  the lesson works. Note opportunities when you can.
- The flaky-server-filter row shows the distinction that keeps the metric
  honest: two consecutive Monday failures (2026-04-27, 2026-05-04) were the
  same undiagnosed bug — one incident. A recurrence is only counted after
  the lesson existed.
- If you cannot decide whether an event is a recurrence or a new class, it is
  a new class that cross-references the old one. Splitting is cheap; merging
  contaminated rows is not.

---

## 6. RETIRE — the attic protocol

Rules go stale: the system they guard gets decommissioned, the API gets
fixed, the owner changes the convention. A stale rule that still *binds* is
noise that erodes trust in the live rules.

Protocol:

1. A rule is retirement-eligible only when its **precondition has vanished**
   (verifiable — e.g. the code path no longer exists), not when it is merely
   annoying or hasn't fired lately.
2. Move it to an **"Attic"** section at the bottom of its home file, with the
   retirement date and one line of reason. **Never silently delete.** The
   attic is how a future session distinguishes "we decided this no longer
   applies" from "someone lost it".
3. If the precondition returns, promote it back out of the attic — with a new
   date.

**Worked example (correction-in-place, from the canon).** An earlier memory
stated that a production repo had *no* auto-deploy; manual build + rollout
was documented as required. On 2026-05-27 this was discovered to be wrong —
push to main auto-deploys via a Cloud Build trigger. The fix on record did
not delete the old belief silently: the corrected memory carries the note
*"(Corrected 2026-05-27 — earlier memory wrongly said no auto-deploy.)"*.
That parenthetical is the attic pattern in miniature: the wrong belief, its
correction date, and the reason survive together. And note the stakes: the
direction of the error mattered — believing "no auto-deploy" when pushes DO
deploy means every push was an unreviewed prod deploy. Corrections to
environment models are safety-critical lessons, not bookkeeping.

---

## 7. Where good lessons historically come from

Verified against the incident corpus (2026-02 through 2026-07): **every
canonized lesson began as either an owner correction or an incident
postmortem.** Not one came from speculative "what could go wrong" exercises.
Concretely: the wrong-destination write and the destroyed formatting were
owner rebukes quoted verbatim in the record ("THIS is the project
directory"; "it messed too much up and presentation really matters"); the
fails-open dedup, the silent AttributeError, the pagination truncation, and
the dep-before-import outage were incident postmortems; the skipped
preflight ritual was an owner call-out.

Implication for effort allocation: mine corrections and incidents *hard* —
they are proven signal. Do not pad the library with hypothetical lessons; an
unfired rule has an unknown false-positive rate and dilutes the ledger.

**Open candidate — automated capture (labeled candidate as of 2026-07-05,
unproven).** The trigger step (§1) currently depends on the session noticing
its own correction, and the canon shows sessions failing at exactly that
(2026-02-12). A hook-based detector — a posttool/user-message hook that flags
probable-correction turns ("no", "revert", "why did you", re-asks) and
prompts the loop — would remove the weakest link. This is an idea, not a
recommendation: false-positive rate, prompt-injection surface, and annoyance
cost are unmeasured. It is tracked in `fable-research-frontier`; do not build
it ad hoc.

---

## When NOT to use this skill

- **You are mid-diagnosis of a live failure** — use `fable-debugging-playbook`
  first; come back here when the incident is closed (§1, trigger 4).
- **You want the history of a specific past incident** — read
  `fable-failure-archaeology`; this skill only decides where new entries go.
- **You are about to make any edit** (including the edits this skill
  mandates) — the gate is `fable-change-control`; this skill defers to it.
- **You are starting a session and want to load past lessons** — that is
  `fable-context-bootstrap` (cold start) and `fable-core` (routing), not the
  capture loop.
- **The "lesson" is really an open research question** with no prevention
  rule yet — route it to `fable-research-frontier` instead of forcing a rule
  that fails the §2 quality bar.

---

## Provenance and maintenance

- **The five-step loop and lesson format**: authored 2026-07-05 by Fable
  (claude-fable-5), generalizing (a) the owner's global Self-Improvement
  Loop rule (capture after ANY correction; rewrite until mistake rate
  drops), and (b) the observed structure of the correction corpus, whose
  entries consistently carry symptom / why / how-to-apply fields.
- **All incident details** (dates, quotes, failure mechanics in §2, §5, §6,
  §7): verified 2026-07-05 against the owner's dated memory corpus
  (2026-02-12 through 2026-06-12 entries). Systems are named because they
  are the canon; the prevention rules beside them are portable.
- **Ledger rows**: seeded 2026-07-05 from that corpus. The ledger is LIVE
  data — future sessions edit it (through `fable-change-control`) and its
  "as of" date must move with each edit.
- **Automated-capture candidate**: introspection + one canon data point
  (2026-02-12); explicitly unproven.
- **Correction (2026-07-05, library review)**: §3 gained the worked-example
  clause after an audit found the major incidents retold substantively across
  most skills without citations — violating this file's own one-home rule and
  already producing drift (two doctrinal contradictions caught the same day).
  AR entries were affirmed as the canonical home; citations were added at the
  retelling sites; the chronicle is the tiebreaker.
- Re-verification: `ls skills/fable/` (repo-relative) confirms the sibling
  skills routed to in §3 still exist under those names; `grep -n "Attic"`
  across `skills/fable/*/SKILL.md` finds any attic sections when checking
  whether a retired rule already exists before re-adding it.
