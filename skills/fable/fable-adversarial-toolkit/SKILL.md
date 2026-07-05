---
name: fable-adversarial-toolkit
description: >
  Load this when you are about to PRESENT a conclusion, diagnosis, or "it works" claim
  and have not yet tried to break it; when several explanations for a symptom are still
  alive and you must pick the next check; when you are about to run a command/query and
  have not written down what you expect it to return; when data "looks complete" but you
  never tested completeness (API pagination, filters, truncation); or when one
  observation still doesn't fit your story and you're tempted to ignore it. This is the
  general prove-it-don't-believe-it method: assigned refutation, discriminating
  experiments, predict-before-run, negative-space audits, residue checks.
---

# Fable Adversarial Toolkit

Five bounded recipes for attacking your own conclusions before reality does. Each is a
*scheduled step with a checkbox*, not a mood (Tenet 8). The through-line: confirmation
is cheap and feels good; discrimination and refutation are what actually move
probability.

**Vocabulary used throughout:**
- **Live hypothesis** — an explanation you have not yet eliminated with evidence.
- **Discriminate** — an observation whose outcome differs depending on which hypothesis
  is true. A check that comes out the same either way discriminates nothing.
- **Fail open / fail closed** — on error, does the guard let the action through (open)
  or block it (closed)?

## When NOT to use this skill

| You actually need | Go to |
|---|---|
| Symptom→triage tables for a broken *system* (deploys, Slack bots, crons) | `fable-debugging-playbook` — it applies these recipes to concrete failures |
| What counts as proof; how to verify a *change you made* | `fable-verification-and-evidence` |
| "Has this exact battle been fought before?" | `fable-failure-archaeology` |
| Deciding how much effort the task deserves at all | `fable-effort-calibration` |
| The ask itself is ambiguous (which problem am I solving?) | `fable-ambiguity-and-judgment` |

This skill is for testing *beliefs and diagnoses*. If you already know what's true and
just need to change code safely, that's `fable-change-control`.

---

## Recipe 1 — Assigned refutation

**When to run:** Before presenting any conclusion whose cost-of-being-wrong is
non-trivial: a root-cause diagnosis, a "this is safe to deploy," an architecture
recommendation, a "the data shows X." Mandatory before the word "root cause" leaves
your mouth.

**Cost:** 2–5 minutes of thinking, occasionally one extra command. Bounded — set the
budget before starting and stop when it's spent.

**The move:** Switch roles. You are now a skeptic *paid to refute* this conclusion —
your bonus depends on finding the hole. You are not "double-checking"; you are
attacking. Ask, in order:

1. **What would the adversary attack first?** Usually the step you verified least —
   an Edit you never re-read, a log line you interpreted rather than quoted, a scope
   you assumed rather than queried.
2. **What single fact, if false, collapses the whole conclusion?** Go check that fact
   directly, not a proxy for it.
3. **What alternative explanation produces the exact same evidence I have?** If one
   exists, your evidence didn't discriminate (see Recipe 2) and the conclusion is
   provisional.

**Template (fill in before presenting):**

```
CONCLUSION: <one sentence>
WEAKEST LINK: <the least-verified step in the chain>
KILL-FACT: <fact that, if false, collapses it> → checked via: <command/observation>
SAME-EVIDENCE ALTERNATIVE: <rival explanation fitting all current evidence, or "none found">
VERDICT: confirmed | provisional (say which and why)
```

**Worked example (2026-04-19, hackgpt prod outage; canonical record AR-06 in
`fable-failure-archaeology`):** The conclusion "the KMS import
is safe to push" rested on an Edit tool reporting it had successfully added
`google-cloud-kms` to `requirements.txt`. An adversary attacks that first: an Edit
success message is a claim about the *edit*, not the *file* — content mismatches and
git races can leave the file unchanged. The kill-fact check was one command:
`grep -n 'google-cloud-kms' requirements.txt`. It was never run. The dep had not
landed, Cloud Build auto-deployed on push, the pod hit `ImportError`, and both replica
sets CrashLoopBackOff'd — a full prod outage. Refutation cost: one grep. Skipping it
cost: an outage. That asymmetry is the whole argument for this recipe.

---

## Recipe 2 — Discriminating experiment design

**When to run:** Whenever two or more hypotheses are still live and you're choosing
what to check next. Especially when you notice you *have a favorite* — that's exactly
when you'll unconsciously pick the check that confirms it.

**Cost:** Zero extra — you were going to run *a* check anyway. This recipe only changes
*which* check. Often it's net negative cost because it eliminates hypotheses faster.

**The move:** List the live hypotheses explicitly (write them down — 3 to 5 is
typical). For each candidate observation, ask: *does its outcome differ across the
hypotheses?* Run the check that splits the set most evenly, ideally one that is cheap
and eliminates the most-expensive-to-fix hypothesis first. Never run a check whose
outcome you can predict under every hypothesis — it's theater.

**Template:**

```
SYMPTOM: <what was observed>
LIVE HYPOTHESES:
  H1: <...>   H2: <...>   H3: <...>
NEXT CHECK: <observation> — under H1 I expect <A>, under H2 <B>, under H3 <A>
  → splits {H2} from {H1,H3}. Cost: <cheap/expensive>.
(after result) ELIMINATED: <which> — REMAINING: <which>
```

**Worked example (2026-06-11/12, hackgpt Excel diagnosis):** Owner reported the bot
"still can't read" xlsx attachments after two same-day fixes. Live hypotheses: (a)
missing Slack `files:read` scope, (b) broken download/extract pipeline, (c) SDK too
old for the new API path, (d) auth token not where the code looks. Each check was
chosen to eliminate one before any code was touched:

1. `auth.test` → response header `x-oauth-scopes` showed `files:read` present (and the
   repo's `manifest.json` was stale — the *live* scopes were the ground truth, not the
   file). Eliminated (a).
2. Ran the exact gateway code in the prod pod against a real file: `download_file`
   (50KB) worked, `extract_office_text` (60K chars) worked, `file_share` events
   arrived with full metadata. Eliminated (b).
3. Checked prod SDK version: anthropic 0.109.1 (local conda env was 0.75.0 — so
   "test in the pod, not locally"). Eliminated (c).
4. Token located in PID 1's env (`/proc/1/environ`), not in `kubectl exec` shells.
   Eliminated (d).

What remained: the extraction *worked* but its output (a lossy 60K text dump prepended
to the message) wasn't landing intact — so the fix (route xlsx through the code
execution tool) was small and obvious. Four checks, zero code changed during
diagnosis, no fix attempted while multiple hypotheses were alive. Contrast with the
two prior fixes that day, which were patches to a pipeline that was never broken.

---

## Recipe 3 — Predict numbers before running

**When to run:** Before executing anything that returns a value you'll interpret:
a count query, a benchmark, a log grep, a test suite, an API call, a curl. Any time
you're about to type "let's see what this says."

**Cost:** Ten seconds. Write one line before pressing enter.

**The move:** Write down the expected value or range *before* running. Interpret
asymmetrically:

- **Match** → weak evidence. Your model *and* many rival models predicted this.
- **Miss** → strong information. Your model is wrong *somewhere upstream* — stop and
  locate where, do not rationalize the number after seeing it ("oh, that's probably
  because..."). Post-hoc rationalization is the failure mode this recipe exists to
  block: once you see the number, you can fit a story to anything.

A plan whose gates carry expected observations is a prediction instrument (Tenet 7);
this recipe is the per-command version of that.

**Template:**

```
ABOUT TO RUN: <command>
PREDICT: <value or range> because <one-line reason>
ACTUAL: <value>
→ match (weak confirm) | MISS: model wrong upstream — re-plan before next command
```

**Worked example (2026-04-27/05-04, Slack `oldest` param):** A weekly cron called
`conversations.history` with `oldest` set to find a roll-call message. Prediction, had
anyone written it down: "≥1 message — the roll call was visibly posted this week."
Actual: 0 messages. The miss was strong information — but the code treated 0 as a
plain "not found," logged one line, and skipped posting. It took two consecutive
silent Monday failures to notice. When finally investigated, reproduction showed the
`oldest` parameter returning 0 messages on ~4 of 5 identical calls even with in-range
data present. A written prediction turns "0" from an unremarkable result into an alarm
on day one: *the count cannot be zero if my model is right, therefore my model is
wrong.* (Fix pattern: omit `oldest`, paginate newest→oldest by cursor, cut off by
`ts` client-side.)

---

## Recipe 4 — Negative-space audit

**When to run:** Before trusting any dataset, log, thread, or listing as "complete";
and before declaring any diagnosis done. Trigger phrases in your own reasoning:
"the data shows…", "there are no errors in the log", "I fetched the whole thread".

**Cost:** 1–3 minutes: write the expectation list, check each item.

**The move:** Invert the usual question. Instead of "what does the evidence show?",
ask: **if my model is right, what MUST be present that I haven't looked for?** List
3–5 expected artifacts, then check each. **Absence of expected evidence is evidence**
— usually against your model, sometimes against your data's completeness.

**Template:**

```
MODEL: <what I believe is happening>
IF TRUE, I SHOULD SEE:
  [ ] <artifact 1> — checked: present/ABSENT
  [ ] <artifact 2> — ...
  [ ] <artifact 3> — ...
ANY ABSENT → either the model is wrong, or the data is incomplete. Decide which
by testing completeness directly (see canon below).
```

**The truncated-data canon — completeness is a hypothesis, test it.** "I queried it
and this is what came back" silently assumes the API gave you everything. Dated
counterexamples (as of 2026-07-05, from the incident corpus):

| Trap | What actually happens | Test / countermeasure |
|---|---|---|
| Slack `conversations.replies` / `.history` defaults | ~28 messages per call; everything past page 1 silently dropped — no error, no warning. Bit IC living memos 2026-04-21 (truncated at the API, then again at a `messages[:20]` slice — compounding loss). | Pass `limit=200`, loop on `has_more` + `response_metadata.next_cursor`. Compare fetched count vs. the thread's own reply count. Audit downstream `[:N]` slices. |
| Slack `conversations.history` with `oldest` | Returns 0 messages on ~80% of calls even with in-range data (confirmed on a real channel, 2026-05). Looks exactly like "no matching messages." | Never date-filter server-side with `oldest`; paginate by cursor and filter on `ts` client-side. |
| "The log shows no errors" | Broad `except Exception` swallowed an `AttributeError` (`config.MODEL_SONNET` vs. real attr `SONNET_MODEL`, 9 call sites, 2026-04-21) — the log genuinely had no traceback, and the symptom masqueraded as a model-quality regression. | Absence of errors in logs is only evidence if errors *would* reach the logs. Check the except-blocks on the path before trusting silence. |

Portable form of the canon: for any "give me all X" call, find the documented (or
undocumented) page size, fetch one page more than you think exists, and reconcile a
count you obtained *by an independent route* before believing you have everything.

---

## Recipe 5 — Residue check

**When to run:** At the moment you're about to declare a diagnosis final. Last gate
before "root cause found."

**Cost:** 1–2 minutes: enumerate observations, map each to the mechanism.

**The move:** One mechanism must explain **all** observations — including the negative
results and the weird ones you've been quietly ignoring (Tenet 6). List every
observation gathered during the investigation. Next to each, write how the proposed
mechanism produces it. Any observation left unexplained is **residue**. Residue does
not mean start over; it means the diagnosis ships labeled **provisional**, with the
residue named, so the next person (or your next session) knows the case isn't closed.

**Template:**

```
PROPOSED MECHANISM: <one sentence>
OBSERVATIONS → EXPLAINED BY MECHANISM?
  1. <obs> → yes: <how>
  2. <obs> → yes: <how>
  3. <weird one> → NO / hand-wave
RESIDUE: <list, or "none">
STATUS: confirmed (no residue) | PROVISIONAL — residue: <...>
```

**Worked example (2026-06-12, Redis dedup duplicate posts; canonical record AR-01 in
`fable-failure-archaeology`):** A podcast episode was
posted to Slack twice. Easy first mechanism: "the dedup key was never set / got
evicted." But that leaves residue: Redis reported `evicted_keys=0`, and the key
*existed the whole time*. A mechanism that can't explain "key present yet dedup
passed" is not the mechanism. The one that explains everything: `RedisToolkit.get()`
wraps its body in `try/except Exception: return None`, so a transient Redis blip is
indistinguishable from a missing key — the `get(key) is None` dedup gate **fails
open** and the side effect re-fires. That mechanism explains the duplicate, the
present key, and the zero evictions, with no residue. It also dictated the correct
fix class: claim atomically with a lock that **fails closed** (`SET key NX EX` —
raises on Redis error, returns False if already claimed) *before* the side effect —
plus a cross-replica run-lock, since the cron ran in every k8s replica. Note the same
residue discipline in the AttributeError case above: "prompt tuning regressed" never
explained why *two unrelated features* thinned out on the same day; the shared-typo
mechanism did.

---

## Composition: the recipes in one pass

For a real diagnosis they chain in this order:

1. **Negative-space audit** the input data first — you cannot reason over data whose
   completeness is untested (Recipe 4).
2. Enumerate live hypotheses; pick checks that **discriminate** (Recipe 2).
3. Before each check, **predict the number** (Recipe 3). A miss → re-plan, not
   rationalize.
4. When one hypothesis survives, run the **residue check** (Recipe 5).
5. Before presenting, run **assigned refutation** on the survivor (Recipe 1).

If the object under test is a code change rather than a belief, hand off to
`fable-verification-and-evidence` after step 5. If corrections come back from the
owner, feed them to `fable-self-improvement-loop` — every recipe miss that a human had
to catch becomes a library update.

**Honest limits (labeled, not oversold):** These recipes bound *bias*, not *ignorance*
— they cannot surface a hypothesis nobody generated. The refutation pass is only as
good as the adversary you can simulate; on domains where you're weak, say so and
escalate rather than perform skepticism. And each recipe is deliberately cheap:
if you find yourself spending 30 minutes on a refutation pass for a reversible
one-line change, you've mis-calibrated — see `fable-effort-calibration`.

---

## Provenance and maintenance

Written 2026-07-05 by Fable (claude-fable-5). Claim classes and sources:

- **The five recipes** — first-person introspection on how I actually sequence
  skepticism, constrained by the library manifesto (`../README.md`, Tenets 2, 5, 6,
  7, 8). Portable; no owner-specific dependencies.
- **Worked examples** — the owner's dated incident corpus (2026-02 through 2026-07);
  canonical incident records are the AR entries in `fable-failure-archaeology`
  (citations added 2026-07-05, library review — on conflict the chronicle wins):
  the requirements.txt/KMS outage (2026-04-19), the Excel diagnosis chain
  (2026-06-11/12), the Slack `oldest` cron failure (2026-04-27 and 2026-05-04), the
  IC-memo pagination truncation (2026-04-21), the swallowed-AttributeError regressions
  (2026-04-21), and the Redis fail-open duplicate posts (2026-06-12). Incident details
  (SDK version 0.109.1, ~28-message default, ~80% empty-return rate, `evicted_keys=0`)
  are as recorded at incident time — treat as point-in-time observations.
- **Slack API behavior** (page size, `oldest` flakiness) is third-party and volatile
  as of 2026-07-05. Re-verify before relying on it:
  `python -c "print(len(client.conversations_history(channel=CH)['messages']))"` —
  if this returns your true message count without pagination, the default changed;
  and re-test `oldest` against a channel with known in-range messages.
- **Redis/hackgpt code claims** (`RedisToolkit.get()` swallowing, `acquire_lock`
  raising) describe that codebase as of 2026-06; re-verify in the repo with
  `rg -n "except Exception" src/toolkits/redis_toolkit.py` before citing in new work.
- Cross-references name only sibling skills in this library
  (`skills/fable/<name>/SKILL.md`). Update this skill only via the protocol in
  `fable-self-improvement-loop`.
