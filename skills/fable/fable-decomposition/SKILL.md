---
name: fable-decomposition
description: >
  FLAGSHIP. Load this the moment you are about to attempt a task in one giant pass — before
  writing a plan, before spawning subagents, before touching code. Symptoms that trigger it:
  the ask is vague or multi-part ("make attachments work", "harden the service", "build the
  pipeline"); you catch yourself planning by deliverable ("first the backend, then the
  frontend"); a debugging session has three or more live hypotheses; you are about to
  parallelize work and don't know where to cut; a previous stage failed and you can't tell
  which part of the design it killed. Teaches cutting problems along VERIFIABLE seams:
  claim-based decomposition, risk-first ordering, per-stage verification with expected
  observations, and a rubric to grade your own decomposition before executing.
---

# fable-decomposition — cutting problems along verifiable seams

The flagship skill. The project owner named weak decomposition — "one giant attempt instead
of verifiable stages" — as the biggest gap between a Fable session and a smaller-model
session. This document is the entire method. `fable-session-campaign` is where the method
gets executed under gates; this is where the cuts get made.

**Definitions used throughout:**
- **Seam** — a boundary in the problem where you can cut it into pieces.
- **Claim** — a falsifiable statement about the system ("the lock fails closed", "the token
  is readable from inside the pod"). Falsifiable means a concrete observation could prove it wrong.
- **Gate** — a checkpoint between stages: a verification command plus the observation you
  expect it to produce. You do not pass a gate on vibes; you pass it on the observation.

## 1. Theory of seams: what makes a cut good

A cut is good when the piece it isolates can be **proven correct independently, cheaply,
and in any order**. All three properties matter:

| Property | Test | Why it matters |
|---|---|---|
| **Independent** | Can I verify this piece without the other pieces existing? | A failure localizes to one piece instead of "somewhere in the whole" |
| **Cheap** | Is verifying it much cheaper than building the whole? | Otherwise the gate costs more than the mistake it prevents |
| **Order-free** | Could I verify it first, last, or in parallel? | Order-free pieces become concurrent subagents for free (§5) |

The unit of decomposition is the **claim, not the deliverable**. "Frontend, then backend"
is a deliverable cut: neither half can be proven correct alone, failures don't localize,
and nothing is order-free. "The API returns the full thread, not the first page" is a claim
cut: one command verifies it, in isolation, whenever you like.

The deep reason claim cuts work: every task, even a build task, is secretly a bundle of
claims about the world ("this dependency exists in prod", "this API accepts this payload",
"this fallback fires when X is absent"). One-giant-attempt fails because it tests all the
claims simultaneously at the end, when a failure could be any of them. Decomposition is
just choosing to test the claims one at a time, cheapest-and-deadliest first.

## 2. The cut taxonomy

Four kinds of cut. Most real decompositions mix them; know which one you're making.

### Claim cuts
Split along falsifiable statements. Each piece is "prove claim C true or false."
This is the default cut for debugging and for any task with unknowns.
- *"the dedup gate fails closed on a backend error"* — one claim, one test.
- *"the Slack API returns the whole thread with default params"* — turned out FALSE
  (defaults to ~28 messages; the 2026-04-21 truncated-memos incident). A claim cut found it
  in one call; the deliverable cut ("build the summarizer") shipped the bug.

### Interface cuts
Split at a boundary where the contract between pieces can be written down and tested with
a stub. Good interface cuts have a contract you can state in one sentence per direction.
- The 2026-06-10 skill-retrieval rework cut at the index boundary: stage 1 produces
  `{name, description, path, source}` records; stages 2–3 consume only those. That contract
  let BM25 be verified without the LLM stage, and made the prefilter swappable later.
- Use when: two pieces must be built by different sessions/agents, or when one side is
  risky and you want to test the other side against a stub now.

### Risk cuts
Split so the piece **most likely to kill the design** is isolated and scheduled FIRST.
Ask: "if this whole approach is doomed, which single fact dooms it?" — that fact becomes
stage 1, even if it's not the natural "beginning" of the work.
- The 2026-06-12 Excel fix depended on one design-killing fact: the Messages API document
  block does NOT accept xlsx (only PDF + text). Verifying that first is what forced the
  code-execution/Files-API route — before any pipeline code was written around the wrong API.
- Use when: the task involves a new API, a capability you've never confirmed, or an
  assumption everyone is treating as obvious.

### Evidence cuts
Split where verification is cheapest — put the seam where a one-liner can decide it, even
if that's an unnatural place architecturally. A slightly awkward boundary that a `curl` can
test beats an elegant boundary that needs a deployed environment to test.
- Checking a bot token's actual scopes via one `auth.test` call (2026-06-12) instead of
  trusting the repo's manifest file — the manifest was stale; the API call was ground truth
  and cost nothing.
- Use when: two candidate seams are otherwise equal — take the one with the cheaper gate.

## 3. The algorithm: vague ask → risk-first schedule

Run these five steps **on disk** (a scratch file or the task's todo file), not in your head.
The intermediate artifacts are the point — they are what survives context decay
(`fable-long-horizon`) and what a reviewer can audit.

### Step 1 — Extract the claim list
Rewrite the ask as falsifiable claims. Include the *implicit* claims: environment
assumptions, API capabilities, "surely X works" beliefs. Format:

```
CLAIMS (from ask: "<verbatim ask>")
C1. <falsifiable statement>          [assumed by everyone — verify anyway?]
C2. <falsifiable statement>
C3. ...
```

Rules: each claim must have a conceivable observation that falsifies it. "The code is
clean" is not a claim. "The parser survives the malformed case" is. If the ask is
ambiguous enough that the claim list itself forks, stop — that's `fable-ambiguity-and-judgment`,
resolve the interpretation before decomposing.

### Step 2 — Dependency-order the claims
Mark which claims depend on others being settled first. Most claims are independent —
that's normal and valuable (it's the parallelism budget, §5).

```
DEPS
C3 needs C1 (can't test the fallback until the primary path exists)
C1, C2, C4: independent
```

### Step 3 — Attach a gate to every claim
For each claim: the **verification command** and the **EXPECTED observation** — written
BEFORE running it. A gate without an expected observation is decoration: you'll rationalize
whatever comes back. (This is Tenet 7: plans are prediction instruments; surprise means
stop and re-plan.)

```
GATES
C1: <command>            EXPECT: <specific output/behavior>
C2: <command>            EXPECT: <specific output/behavior>
```

If you cannot name a cheap gate for a claim, that is a signal the cut is wrong — re-cut
(usually toward an evidence cut) until every claim has one.

### Step 4 — Schedule risk-first
Order by `(probability it fails) × (cost of learning that late)`, respecting only the hard
deps from Step 2. The design-killer claims go first. Cheap gates on likely-true claims can
go anywhere; they're almost free.

### Step 5 — Execute with stop-on-surprise
Run gates in schedule order. Gate observation matches EXPECT → check it off, move on.
Observation differs → **stop**. Do not "push through" — a surprised gate means your model
of the system is wrong upstream, and every later stage was scheduled by that wrong model.
Update the claim list and re-run Steps 2–4 (usually a 2-minute edit, not a restart).
Escalation, rollback rules, and the full gated execution loop live in `fable-session-campaign`.

## 4. Three fully worked examples

### 4a. Debugging: the 2026-06-12 Excel attachment diagnosis

Ask (verbatim symptom): xlsx attachments "still can't be read" — after two same-day fixes
had already been shipped. The one-giant-attempt move here is "rewrite the attachment
pipeline." The diagnosis, reconstructed here in this skill's CLAIMS/GATES format — the
checks and their results are from the incident record; the written claim-list artifact
is this skill's rendering, not something that existed at the time:

```
CLAIMS
C1. The bot token has files:read scope             [manifest suggests maybe not]
C2. The download/extract pipeline is broken        [what the symptom implies]
C3. The prod SDK version supports the new API path
C4. The token is where the debug shell can see it
C5. xlsx can be sent as a native document block    [DESIGN-KILLER for the obvious fix]

GATES (each ran before any code was written)
C1: auth.test, read x-oauth-scopes header     EXPECT: files:read present
C2: run the exact gateway code in the prod pod against a real file
                                              EXPECT: download + extract succeed
C3: check anthropic SDK version in prod pod   EXPECT: recent enough for Files API
C4: inspect PID 1 environ in the pod          EXPECT: token present
C5: API docs: document-block accepted types   EXPECT: xlsx accepted
```

Observed: C1 TRUE (scopes fine — and the repo `manifest.json` was stale, a lesson in
itself: prefer the live API over a checked-in artifact). C2 FALSE — pipeline NOT broken:
download 50KB ✓, extract 60K chars ✓; the real problem was the lossy 60K text dump not
landing intact in context. C3: prod SDK 0.109.1, but local env was 0.75.0 — so gates must
run in the pod, not locally. C4: token in `/proc/1/environ`, not in exec shells. C5 FALSE —
document blocks accept only PDF + text, killing the "just attach it" design and forcing
the code-execution/Files-API route.

Every gate eliminated a hypothesis; by the end the fix was small and obvious. Note the
shape: **five cheap observations, zero code written, and the two FALSE results (C2, C5)
were exactly the ones that would have wasted a day if assumed true.**

### 4b. Feature/integration: skill-retrieval rework (2026-06-10 canon)

Ask: skill lookup over ~800 skill files is silently blind to most of them; fix retrieval
without blowing the context window. Deliverable cut would be "write the new retrieval
system." Claim cut (reconstructed in this skill's format — the architecture, the C1
diagnosis, and the shipped stages are from the incident record; the claim list, deps,
and gate schedule are retrospective renderings, not an artifact that existed then):

```
CLAIMS
C1. The current router really is blind (not a prompt issue)   [diagnose before building]
C2. Metadata-only indexing fits in RAM/context               [design-killer if false]
C3. A lexical prefilter (BM25) ranks the true skill into top-25 for real queries
C4. The LLM picker, given 25 candidates, selects valid keys
C5. Lazy body-load returns intact content for the selected 1–2

DEPS: C3 needs C2's index format. C4 needs C3's shortlist shape (interface cut:
      the index record {name, description, path, source} is the contract).
SCHEDULE: C1 (is there even a problem?) → C2 (kills design) → C3 → C4 → C5.
GATE STYLE: C3 = run the prefilter on a handful of known query→skill pairs,
      EXPECT the right skill in the top-25 every time — testable with zero LLM calls.
```

The interface cut at the index boundary is what made C3 verifiable alone and made the
prefilter swappable later (BM25 → embeddings) without touching stages 2–3. Also canon from
this incident: the diagnosis at C1 found the old catalog sampled only ~50 of 800+ skills —
confirming the claim before building saved building the wrong thing.

### 4c. Research: passive-sonar model evaluation (canon as of 2026-04-08)

Ask: "show the new architecture beats the baseline for the proposal." One-giant-attempt:
train both models, compare, write it up. Claim cut:

```
CLAIMS
C1. The data pipeline produces valid inputs (spectrograms sane, labels aligned)
C2. The BASELINE is competent on this data volume        [design-killer for any % delta]
C3. The new model beats the baseline on the target metrics
C4. The efficiency numbers (params/memory/latency) hold on target-class hardware
C5. The result is robust (seeds, ablations) — not a lucky run

SCHEDULE: C1 → C2 → C3 → C4; C5 deferred but LABELED open, never claimed.
```

C2 is the research-specific design-killer and it FIRED: the CNN baseline was degenerate
(below random) on the small partial dataset, so the impressive % deltas were technically
true against a broken comparator. Because C2 was a separate claim with its own gate, the
failure was localized and the honest framing was forced: *lead with absolute numbers, not
% deltas, until the full dataset arrives.* A deliverable decomposition would have shipped
the misleading deltas. Research decompositions must also keep unverified claims (C5)
visibly open — see `fable-verification-and-evidence` for the verified/assumed labeling rules.

## 5. Decomposition → parallelism

The Step-2 dependency graph is the parallelism plan. The mapping is mechanical:

| Decomposition artifact | Parallel-execution artifact |
|---|---|
| Independent claim | One subagent, one claim, one gate |
| Dependency edge C3→C1 | C3's agent launches only after C1's gate passes |
| Interface cut contract | The stub each side's agent codes/tests against |
| Gate EXPECT line | The subagent's success criterion, verbatim in its prompt |
| Design-killer claim | Runs first and ALONE — don't spend parallel budget downstream of a claim that may kill the design |

Rules:
- One claim per subagent. An agent given three claims returns one blended, unauditable answer.
- Paste the gate (command + EXPECT) into the subagent prompt. "Investigate X" produces
  prose; "run Y, report whether the output matches Z" produces evidence.
- Fan out only claims that are independent AND not downstream of an unsettled design-killer.
  In example 4a, C1–C5 were all independent: five probes could have run concurrently.
  In 4b, C2 should settle before anyone builds C3–C5.
- Subagents report observations; the parent integrates them against the claim list. Do not
  let a subagent both observe and re-plan the schedule.

## 6. Failure modes

| Failure | What it looks like | Countermeasure |
|---|---|---|
| **Deliverable decomposition** | Stages named after artifacts ("backend", "UI", "docs"); no stage provable alone | Rewrite each stage title as the claim it settles; if you can't, re-cut |
| **Over-decomposition of trivial work** | Five-gate plan for a one-line fix; ceremony exceeds the task | Calibrate first (`fable-effort-calibration`): if the whole task is cheaper than one gate, just do it and verify once |
| **Stages without gates** | A todo list of steps, no verification between them — failures surface at the end, delocalized | No stage enters the schedule without a gate; a gap means re-cut toward an evidence cut |
| **Gates without expected observations** | "Run the tests and see" — whatever happens gets rationalized as fine | Write EXPECT before running; a mismatch is a stop condition, not a footnote |
| **Risk-last scheduling** | Comfortable, buildable pieces first; the scary API question saved for the end | Ask "which single fact dooms this design?" and schedule it first |
| **Push-through on surprise** | Gate output differs from EXPECT; you shrug and continue | Stop-on-surprise is the rule (Tenet 7); re-plan costs minutes, pushing through costs the session |
| **Claim list frozen after step 1** | New facts arrive; schedule never updates | The claim list is a living file; every surprising gate edits it |

## 7. Grading rubric — score BEFORE executing

Score your written decomposition 0–2 per row (0 = no, 1 = partial, 2 = yes). **8+ / 12:
execute. Below 8: re-cut — do not start work.**

| # | Question | 0–2 |
|---|---|---|
| 1 | Is every stage a falsifiable claim (an observation could prove it wrong), not a deliverable? | |
| 2 | Does every claim have a gate: command + EXPECTED observation, written before running? | |
| 3 | Is each gate meaningfully cheaper than the work it protects? | |
| 4 | Is the claim most likely to kill the design scheduled first? | |
| 5 | If stage N's gate fails, is the damage localized to N (later stages unstarted or trivially reschedulable)? | |
| 6 | Are the implicit environment/API assumptions on the claim list (not silently trusted)? | |

Row 6 is the one experienced people fail: the canon is full of assumed-true claims that
were false — Slack defaults returning whole threads, a manifest reflecting live scopes, a
local SDK matching prod, a stale "no auto-deploy" belief about a repo that in fact
auto-deploys on push to main (corrected 2026-05-27). Assumptions about the environment are
claims; put them on the list.

## When NOT to use this skill

- **Trivial, single-claim tasks** (one-file edit, direct question): decomposing is overhead.
  Size the effort first with `fable-effort-calibration`.
- **The ask itself is ambiguous** (multiple reasonable interpretations of what's wanted):
  resolve interpretation FIRST with `fable-ambiguity-and-judgment` — decomposing the wrong
  interpretation produces beautifully-gated wrong work.
- **You have a decomposition and need to execute it under gates over hours/days**:
  `fable-session-campaign` (execution loop, escalation, rollback) and `fable-long-horizon`
  (keeping the claim file alive across context decay).
- **You need to design the gate itself** — what counts as proof, how to avoid eyeballing:
  `fable-verification-and-evidence`; for actively attacking your own favored hypothesis,
  `fable-adversarial-toolkit`.
- **Live debugging with a concrete symptom in a known system**: `fable-debugging-playbook`
  applies this method pre-instantiated for common symptom classes; check
  `fable-failure-archaeology` first so you don't re-fight a settled battle.
- Never use decomposition to slice a risky change into pieces small enough to dodge review
  or reversibility rules — `fable-change-control` still governs every stage that mutates
  anything.

## Provenance and maintenance

- **Theory (§1–§3, §5–§7):** first-person introspection by claude-fable-5 (written
  2026-07-05), operationalizing Tenets 3, 4, 7 of the library manifesto (`../README.md`).
  The rubric thresholds (8/12) are a calibrated starting point, not measured — candidate
  for tuning via `fable-self-improvement-loop`.
- **Worked example 4a:** the 2026-06-12 hackgpt Excel-attachment diagnosis, from the
  owner's dated incident memory. Facts embedded: prod SDK 0.109.1 vs local 0.75.0; token
  in PID 1 environ; stale manifest vs live `auth.test` scopes; document blocks = PDF+text
  only (as of 2026-06-12 — re-verify against current Anthropic API docs before relying on it).
- **Worked example 4b:** the 2026-06-10 skill-retrieval rework (metadata index → BM25
  prefilter → LLM pick + lazy load); counts (~800 skills, top-25 shortlist) are as of that date.
- **Correction (2026-07-05, library review):** 4a and 4b are now explicitly labeled as
  retrospective reconstructions in this skill's format — the incident memories record the
  checks and architecture, not written CLAIMS/GATES artifacts; presenting the blocks as
  "what actually ran" overstated the evidence that the method was used.
- **Worked example 4c:** the passive-sonar project state as of 2026-04-08 (degenerate CNN
  baseline on the 63-ship partial dataset; "lead with absolute numbers" framing decision).
- **Rubric row 6 canon:** Slack pagination truncation (2026-04-21), stale-manifest lesson
  (2026-06-12), auto-deploy misbelief correction (2026-05-27) — all from dated incident memories.
- **Re-verification:** incident details are frozen history and need no re-check; the only
  drift-prone claim is the xlsx/document-block API limitation (check current Messages API
  docs). If a worked example's system has since changed, the *decomposition shape* remains
  valid — update only the postscript facts. Edits to this skill go through
  `fable-self-improvement-loop`, not ad-hoc.
