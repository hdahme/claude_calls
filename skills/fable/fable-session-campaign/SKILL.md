---
name: fable-session-campaign
description: >
  THE EXECUTABLE. Load this when you have been handed a vague, hard, or multi-hour task and
  are about to just start working — before the first file edit, before the first hypothesis.
  Symptoms that trigger it: the ask fits in one sentence but the work clearly doesn't ("make
  attachments work", "harden the service", "figure out why the cron is silent"); you feel
  the pull to open an editor immediately; you are a fresh session inheriting a half-done
  task; a previous attempt at this task died in a swamp of un-localized failures; you cannot
  currently state what observation would prove the task done. This is the end-to-end gated
  runbook — Phase 0 through Phase 6 — that sequences the other fable skills into one
  campaign: calibrate → interpret → decompose → execute claim-by-claim → adversarial pass →
  report → compound. Its output always includes a gate journal. Do NOT load it for trivial
  single-claim tasks (one-file edits, direct questions) — that's over-ceremony.
---

# fable-session-campaign — the gated runbook from vague ask to verified done

This is the executable spine of the library. Every other fable skill teaches a move; this
one tells you **which move, in which order, with a gate between each** — so that a
mid-level engineer or a Sonnet-class session can walk from "make attachments work" to a
completion report a staff engineer would sign, without judgment calls being made by vibe.

It exists to close the three owner-named gaps at once (README, 2026-07-05): silent
interpretation (Phase 1 forces enumeration), weak decomposition (Phase 2 forces the rubric),
and long-horizon decay (the gate journal externalizes every decision to disk).

**Definitions (used throughout):**
- **Claim** — a falsifiable statement about the system; a concrete observation could prove it wrong.
- **Gate** — a checkpoint: a verification command **plus the observation you EXPECT**, written before running.
- **Surprise** — the gate's observed output differs from EXPECT. Surprise is a stop condition, never a footnote.
- **Gate journal** — the on-disk file recording budget, interpretation, claims, gate results, surprises, and escalations. It is a mandatory output of the campaign, equal in rank to the work product itself.

## The campaign at a glance

| Phase | Name | Gate artifact (must exist on disk before next phase) |
|---|---|---|
| 0 | Calibrate | One-line budget statement |
| 1 | Interpret | Interpretations enumerated with costs; one selected or asked |
| 2 | Decompose | Claim tree scoring ≥ 8/12 on the decomposition rubric |
| 3 | Execute | Every claim's gate row filled: EXPECT vs observed, verdict |
| 4 | Adversarial pass | Refutation attempt logged; survivors and casualties listed |
| 5 | Report | Completion report with proof pasted per claim |
| 6 | Compound | Lessons filed per `fable-self-improvement-loop` |

**Rule zero: no phase is skippable, but phases scale with the budget from Phase 0.** For a
mid-size task, Phases 0–2 might total ten minutes. What never scales to zero is the gate
artifact — a one-line journal entry still gets written.

## Start the gate journal first

Before Phase 0, create the journal file. Location: the task's working notes file if the
project has a convention (this owner's convention: `tasks/todo.md` in the project); else a
scratch file you can find again. Skeleton:

```
# GATE JOURNAL — <verbatim ask> — <date> — session <n>
BUDGET: (Phase 0)
INTERPRETATION: (Phase 1)
CLAIMS (rubric score: _/12): (Phase 2)
| # | claim | gate command | EXPECT | observed | verdict | when |
|---|-------|-------------|--------|----------|---------|------|
SURPRISES / RE-PLANS:
ESCALATIONS:
ADVERSARIAL PASS:
LESSONS FILED:
```

**When `fable-long-horizon` is loaded** (Phase 3 mandates it for sessions over ~1 hour or
multi-session work), the gate journal lives *inside* that skill's plan-file skeleton —
the CLAIMS table above replaces its PLAN section; keep its CONSTRAINT LEDGER,
ENVIRONMENT FACTS, DEAD ENDS, and HANDOFF sections (their rules are in
`fable-long-horizon` Practice 1). One file, one merged skeleton — never two rival
skeletons claiming `tasks/todo.md`.

If you are **resuming** a campaign (fresh session, decayed context): do not re-derive
anything — read the journal top to bottom, run `fable-context-bootstrap` to rebuild the
environment picture, and re-enter at the first unfilled gate row. The journal *is* the
resume point (Tenet 9: context decays; files don't).

---

## Phase 0 — Calibrate

**Loads:** `fable-effort-calibration` (the full dial). This phase is its output, applied.

**Steps:**
1. Run any preflight ritual the host project mandates (project CLAUDE.md, house rules)
   — FIRST, before the campaign's own steps. Host-mandated rituals outrank this
   runbook's ordering; a mandated preflight is a gate, not a suggestion.
2. Restate the ask verbatim in the journal header.
3. Set the effort dial from three inputs — cost-of-being-wrong, reversibility, novelty —
   not from how impressive the task sounds.
4. Decide which fable skills this campaign needs loaded now vs. on-demand (typical hard
   task: `fable-decomposition` now; `fable-debugging-playbook` / `fable-adversarial-toolkit`
   at their phases; `fable-failure-archaeology` if the system has a chronicle).
5. Write the budget statement:

```
BUDGET: effort=<low|standard|high> | cost-of-wrong=<one phrase> | reversibility=<one phrase>
        | skills: <list> | done-when: <the final observation that proves completion>
```

**Gate — EXPECT:** a budget line exists in the journal AND `done-when` names an
*observation*, not a feeling ("dedup survives a simulated backend error" ✓; "dedup is
robust" ✗).

**Branches:**
- `done-when` comes out as a feeling → you don't yet understand the ask → go to Phase 1
  early; interpretation is the blocker, not effort.
- Effort lands at *low* and the task is a single claim → **exit the campaign.** Do the
  work, verify once, skip to Phase 5's one-paragraph report. Ceremony must never exceed task.

**Canon:** 2026-02-12 — the owner's mandated preflight (a semantic-search ritual) was
skipped for an *entire implementation session*; the owner had to call it out. The lapse was
not a knowledge gap — the rule was written down — it was the absence of a gate. Step 1
exists so that "I was eager to start" can never again skip a written ritual.

---

## Phase 1 — Interpret

**Loads:** `fable-ambiguity-and-judgment` (the full protocol). This phase is its gated summary.

**Steps:**
1. Enumerate every reasonable interpretation of the ask. Two is common; one is suspicious
   for a vague ask — look again.
2. For each: the cost if you build it and it's the wrong one (wasted hours? destroyed
   user work? prod outage?).
3. Try to kill interpretations with **sources, not questions**: the codebase, docs, prior
   threads, the failure chronicle. Questions to the human are for what sources cannot answer.
4. If interpretations survive with materially different costs: ask, per the question
   budget in `fable-ambiguity-and-judgment` (the canonical home of the rule) — **one
   question per unresolved interpretation-fork, usually exactly one, batched into a
   single message**, each with your recommendation attached and naming the
   interpretations it discriminates between. If costs are similar and everything is
   reversible: pick the most likely, and **write the assumption in the journal** so it
   is visible, not silent.

**Gate — EXPECT:** journal shows ≥ 2 interpretations considered (or an explicit "genuinely
unambiguous because …"), each with a cost, and either `SELECTED: In because …` or
`ASKED: <the batched questions>`.

**Branches:**
- You catch yourself with one interpretation and high confidence on a vague ask → that is
  the exact failure mode this library exists for; force a second reading before proceeding.
- The human is unavailable and interpretations differ in *irreversibility* → take the
  reversible path or stop; never resolve an irreversibility fork by guessing
  (`fable-change-control` governs).
- Mid-campaign you notice the ask meant something else → **do not silently re-interpret**
  (fenced path §F3). Return here, log the re-interpretation, re-gate Phase 2.

**Canon:** 2026-05-08, twice in one day. (a) "Use `<other-project>/.plan` as a scratch doc"
had two readings — *destination* vs *style template*. The wrong one was picked silently and
analysis was appended into an unrelated project's file. (b) "Push the three patches to the
Doc" had two readings — *surgical edits* vs *wholesale replace*. The replace path
(export → pandoc → re-import) destroyed the owner's hand-formatting; he reverted the doc.
Both asks would have been resolved by **one batched question each**. Cost of asking:
seconds. Cost of the silent pick: reverted work and lost trust.

---

## Phase 2 — Decompose

**Loads:** `fable-decomposition` — do not paraphrase it from memory; open it. This phase
only states the gate.

**Steps:**
1. Run the five-step algorithm from `fable-decomposition` §3: extract the claim list
   (including implicit environment claims), dependency-order, attach a gate + EXPECT to
   every claim, schedule risk-first (design-killer claim first), all **written into the
   journal's claim table**.
2. Score the decomposition against the rubric (`fable-decomposition` §7), 0–2 per row,
   six rows. Record the score in the journal.

**Gate — EXPECT:** rubric score ≥ 8/12, recorded.

**Branches:**
- Score < 8 → **DO NOT proceed. Re-cut.** The usual repairs: rewrite deliverable-shaped
  stages as claims; move the seam to where a one-liner can test it; put the scary claim
  first. Re-score. This loop costs minutes; executing a bad decomposition costs the session.
- You cannot find a cheap gate for a claim after re-cutting → the claim may be untestable
  as posed; consult `fable-verification-and-evidence` for what counts as proof, or split
  the claim.
- The claim list itself forks on interpretation → you skipped something in Phase 1; go back.

---

## Phase 3 — Execute, claim by claim, riskiest first

**Loads on demand:** `fable-debugging-playbook` (if a claim is a bug), `fable-change-control`
(before ANY mutation — it governs every stage that changes anything; this skill never
overrides it), `fable-long-horizon` (sessions > ~1 hour or multi-session).

**The loop, per claim, in schedule order:**
1. Re-read the claim's gate row: command + EXPECT. If EXPECT is missing, stop and write it
   *before* running — a gate run without a pre-stated expectation will be rationalized.
2. Do the work the claim requires (or, for pure-diagnostic claims, nothing — just run the gate).
3. Run the gate command. Paste the *actual observed output* (or the load-bearing lines of
   it) into the journal row. Not a summary — the output.
4. Compare:
   - **Observed matches EXPECT** → verdict `PASS`, timestamp, next claim.
   - **Observed differs — SURPRISE** → verdict `SURPRISE`. Stop the schedule. Log what you
     expected, what you saw, and your current best explanation in `SURPRISES / RE-PLANS`.
     Then re-plan: update the claim list (the surprise usually adds or falsifies a claim),
     re-run Phase 2's rubric on the edited tree (usually a 2-minute edit), resume. Pushing
     through a surprise is fenced (§F1) — every later stage was scheduled by the model of
     the world the surprise just falsified.
5. Same gate fails 3+ attempts → go to the **escalation menu** below. Do not grind.

**Execution rules with canon behind them** (canonical incident records: the AR entries
in `fable-failure-archaeology`; on any conflict of detail, that chronicle wins):

| Rule | Canon |
|---|---|
| A tool reporting success is not the gate. Verify the *state*, not the return code. | 2026-04-19 (AR-06): an Edit to `requirements.txt` reported success but the dep never landed; the import auto-deployed; both replica sets CrashLoopBackOff'd — full prod outage. The gate was `grep -n '<package>' requirements.txt` *after* the edit, and it wasn't run. |
| For claims about failure behavior, the gate must *induce* the failure, not observe the happy path. | 2026-06-12 (AR-01): `RedisToolkit.get()` swallows exceptions → returns None → a dedup check built on `get() is None` **fails open**; duplicate posts fired on a Redis blip. The happy-path gate ("dedup works when Redis is up") passes; the real gate is "simulate a backend error, EXPECT the side effect is *blocked*" — which forces the `SET NX` fail-closed lock. |
| Absence of errors is not evidence of health — read the negative space. | 2026-04-21 (AR-02): broad `except Exception` swallowed an `AttributeError` typo across 9 call sites; users saw "thin output," logs showed nothing. The visible symptom pointed at prompt tuning; the discriminating gate (run the call path once, inspect the raw response / fallback branch) pointed at the typo. |
| A gate that behaves inconsistently across runs is itself evidence — of a flaky dependency, not of your code being "almost right." | 2026-04-27 → 2026-05-04 (AR-04): Slack `conversations.history` with `oldest` set returned 0 messages on ~80% of calls even with in-range data; a cron silently skipped two Mondays running. Reproducing 4-of-5 empty was the observation that falsified the claim "`oldest` filters correctly." |
| Run gates in the environment that matters. | 2026-06-12 (AR-13): prod SDK was 0.109.1, the local env 0.75.0 — a gate passing locally proved nothing about the pod. |

**Escalation menu — gate failed 3+ honest attempts.** Choose top-down; log the choice
under `ESCALATIONS`:

| # | Option | Choose when |
|---|---|---|
| 1 | **Re-decompose locally** — split this claim into sub-claims, gate each | The failure is stable and localized, and you can name at least two distinct sub-mechanisms that could each explain it. Cheapest option; try it first. |
| 2 | **Question the claim itself** — maybe it's false or ill-posed, and the *approach* built on it must change | The gate is verified sound (you've checked the gate, not just the work) and output is *consistent* across attempts. Canon: after repeated empty results, the right move on the Slack `oldest` failure was not a fourth retry but abandoning `oldest` and filtering client-side — the claim was false. |
| 3 | **Widen the hypothesis portfolio** — the cause may be outside the claim tree entirely: environment, config, another actor | Output is *inconsistent* across identical attempts, or the failure smells like state you don't control. Canon: `load_dotenv(override=True)` at import silently clobbering shell env; crons running once per k8s replica. Ask: "what actor or config have I not put on the claim list?" |
| 4 | **Escalate to the human** with a crisp blocked-on statement | Options 1–3 exhausted, OR resolution needs authority/access/product-intent you cannot obtain, OR the only next probe is irreversible. Template: `BLOCKED ON: <one sentence>. Tried: <gate + observed, per attempt>. Ruled out: <claims falsified>. Need from you: <the one thing>. Meanwhile I will: <safe parallel work or "nothing">.` |

**Gate for the phase — EXPECT:** every scheduled claim's row shows a verdict (`PASS`,
`FALSIFIED` + re-plan reference, or `ESCALATED` + menu choice). No blank rows, no verdicts
of "probably fine."

---

## Phase 4 — Adversarial pass

**Loads:** `fable-adversarial-toolkit`. Refutation is a scheduled step with a checkbox
(Tenet 8), not a mood — and it runs on the *whole result*, after the last claim passes,
because per-claim gates cannot catch cross-claim failures (each piece correct, the
composition wrong).

**Steps:**
1. Adopt the assignment: "I am paid to prove this work wrong or incomplete."
2. Attack at minimum these four surfaces, logging each attempt in `ADVERSARIAL PASS`:
   - **Composition:** do the passed claims actually entail `done-when` from Phase 0, or is
     there a gap between what was proven and what was asked?
   - **Negative space:** what should be observable if the work is correct that you haven't
     looked at? (Logs that should have a line; a metric that should have moved; a second
     replica behaving the same way.)
   - **Rival mechanism:** is there one alternative explanation for every gate passing?
     (E.g., a fallback path silently handling what you think your fix handles — the
     2026-04-21 pattern in reverse.)
   - **Failure induction:** for anything claiming robustness, induce the failure once more
     end-to-end, not per-unit.
3. Anything that survives stays. Anything that falls → new claim, back to Phase 3.

**Gate — EXPECT:** journal lists the refutation attempts and their outcomes. "I attacked
it and found nothing" with zero listed attempts is a fail — the attempts are the evidence
the pass happened.

---

## Phase 5 — Report

**Loads:** `fable-communication` (house style: lead with the outcome; verified vs. assumed
explicitly separated; no oversell).

**Steps:**
1. Open with the outcome in one sentence, mapped to Phase 0's `done-when`.
2. Per claim: one line + the pasted proof (the gate's observed output), lifted from the
   journal. **Proof is pasted, not asserted.**
3. Separate sections: `VERIFIED` (gated claims) / `ASSUMED` (Phase 1 assumptions that were
   never promoted to gated claims — they must appear here, visibly) / `OPEN` (deferred
   claims, labeled, never silently dropped).
4. Attach or link the gate journal. **The journal is part of the deliverable** — it is what
   makes "done" auditable by a human junior, which is this library's success bar.

**Gate — EXPECT:** a reader who trusts nothing can check every `VERIFIED` line against
pasted evidence without asking you anything.

**Branch:** you notice while writing that a claim has no pasted proof → it is not verified;
move it to `OPEN` or go run its gate. Never promote at report time.

---

## Phase 6 — Compound

**Loads:** `fable-self-improvement-loop` — the only sanctioned channel for turning this
campaign's lessons into library/rule changes; do not edit skills or project rules ad-hoc.

**Steps:**
1. Harvest: every SURPRISE, every escalation, every human correction from this campaign.
2. For each: is it a one-off, or a *class*? Classes get filed (a lesson entry, a chronicle
   entry in `fable-failure-archaeology`'s format, or a proposed skill edit via the loop).
3. Write `LESSONS FILED:` in the journal — even if it is "none; no surprises" (that itself
   is data on your calibration).

**Gate — EXPECT:** the line exists. A campaign with three surprises and zero filed lessons
is an unfinished campaign — a mistake made twice is a process failure (Tenet 10).

---

## §F — Fenced-off wrong paths

These are not tips; they are walls, each anchored to a real incident. Crossing one
invalidates the campaign's "done."

- **F1 — Pushing through a surprise.** The gate said X, you saw Y, you kept going because
  the schedule had momentum. Every downstream stage was planned by the world-model Y just
  falsified. (Two silent Mondays of a skipped cron, 2026-04/05, were downstream of exactly
  this: "0 messages" was rationalized as "no matching message" instead of stopping the plan.)
- **F2 — Skipping the gate on an "easy" stage.** Easy stages are where gates are cheapest
  and skipped most. The 2026-04-19 outage was a *trivially easy* stage — add one line to
  requirements.txt — whose ten-second gate (`grep`) was skipped.
- **F3 — Silently re-interpreting mid-task.** New information changes what you think the
  ask meant, and you swerve without logging it. The human is still expecting the Phase 1
  interpretation; you are now building something nobody agreed to. Re-enter Phase 1 in the
  journal, even if the answer is obvious.
- **F4 — Verifying by eye.** "The output looks right" / "the diff looks clean" is not an
  observation; it is a mood. Every verdict in the journal traces to a command's pasted
  output. (`fable-verification-and-evidence` is the arbiter of what counts.)
- **F5 — Marking done on plausibility.** "This should work" + a passing happy path is how
  fail-open dedup shipped (2026-06-12). Done = `done-when` observed + adversarial pass
  logged + journal complete. Nothing else is done.
- **F6 — Using phase structure to dodge review.** Slicing a risky change into per-claim
  pieces small enough that no single gate looks scary does not exempt the whole from
  `fable-change-control`'s reversibility ladder. The campaign runs *inside* change control,
  never around it.

## When NOT to use this skill

- **Trivial or single-claim tasks** — one-file edit, a direct question: run
  `fable-effort-calibration`'s quick check and just do the work; Phase 0's exit branch
  exists precisely for this.
- **You only need the cuts, not the campaign** (planning/estimating, or feeding subagents):
  `fable-decomposition` alone.
- **The ask is ambiguous but small** — a one-question clarification, no multi-phase work:
  `fable-ambiguity-and-judgment` directly.
- **Live incident with a concrete symptom in a known system**: `fable-debugging-playbook`
  first (it front-loads symptom→triage), and check `fable-failure-archaeology` before
  hypothesizing — you may be re-fighting a settled battle.
- **You are mid-campaign and the problem is context loss, not process**: `fable-long-horizon`
  (decay countermeasures) and `fable-context-bootstrap` (cold start), then re-enter here at
  the journal's first unfilled row.
- **Designing what counts as proof** for one hard gate: `fable-verification-and-evidence`.

## Provenance and maintenance

- **Phase structure, gate-journal format, escalation menu ranking, §F fences:** first-person
  introspection by claude-fable-5 (written 2026-07-05), operationalizing Tenets 1, 3, 7, 8,
  9, 10 of the manifesto (`../README.md`) and the owner's global workflow rules (plan-first,
  verification-before-done, stop-and-re-plan, todo/lessons files). Phase 1's question
  budget is NOT an owner rule — its canonical home is `fable-ambiguity-and-judgment`
  (first-person doctrine); Phase 1 cites it rather than restating a number. The
  "3+ attempts" escalation trigger and "≥8/12" Phase 2 threshold are calibrated starting
  points, not measured constants — tune via `fable-self-improvement-loop`.
- **Incident facts** (all embedded above with dates; frozen history, no re-check needed):
  requirements.txt/CrashLoopBackOff outage (2026-04-19); Redis fail-open dedup duplicates
  (2026-06-12); swallowed AttributeError masquerading as a prompt regression (2026-04-21);
  Slack `oldest` returning empty ~80% of calls, two skipped cron Mondays (2026-04-27,
  2026-05-04); wrong-project scratch append and pandoc-roundtrip formatting destruction
  (both 2026-05-08); skipped mandated preflight session (2026-02-12); prod/local SDK skew
  0.109.1 vs 0.75.0 (2026-06-12); `load_dotenv(override=True)` env clobber and
  crons-per-replica (owner's memory corpus, 2026).
- **Cross-references:** rubric and five-step algorithm live in `fable-decomposition` §3/§7
  — if that skill's rubric changes, update Phase 2's threshold reference here. Re-verify
  with: `grep -n "8+ / 12" ../fable-decomposition/SKILL.md`.
- **Journal location convention** ("tasks/todo.md") is this owner's rule as of 2026-07-05;
  the portable rule is only *a findable on-disk file per campaign*. Re-verify the owner
  convention against their global CLAUDE.md (Task Management section) if it matters.
- **Corrections (2026-07-05, library review):** Phase 1's question budget now defers to
  `fable-ambiguity-and-judgment` (was a conflicting "≤ 5 questions" restated here, and
  was wrongly attributed to the owner's rules); Phase 0's host-mandated preflight moved
  to step 1 (running it fourth re-created the 2026-02-12 deferral failure mode); the
  journal skeleton now states how it merges with `fable-long-horizon`'s plan-file
  skeleton instead of rivaling it for `tasks/todo.md`; execution-rules canon now cites
  its AR entries.
- Edits to this skill go through `fable-self-improvement-loop`, not ad-hoc.
