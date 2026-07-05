---
name: fable-research-frontier
description: >
  Load when the question is about the LIBRARY ITSELF rather than the work: someone asks "does
  this actually help?" or "prove Sonnet+library beats bare Fable"; you are designing a benchmark,
  eval, or A/B experiment on the library; you are about to claim a result publicly (blog post,
  README boast, pitch) and need to know what is claimable; you are proposing a new library
  capability (auto lesson capture, skill routing, smaller-model support) and need its falsifiable
  milestone; or you caught yourself writing "this works" about something never measured. Do NOT
  load for running actual work sessions (use fable-session-campaign) or for recording a single
  correction (use fable-self-improvement-loop).
---

# fable-research-frontier — open problems and honest positioning

This skill is the library's research agenda and its truth-in-advertising policy. Four open problems where this library has a real asset current practice lacks, each with a falsifiable milestone; then the rules for what may be said about the library out loud.

**Epistemic status of everything in this file: OPEN or CANDIDATE. Nothing below has been demonstrated as of 2026-07-05.** If you are reading this later and a milestone has been hit, the Provenance section tells you where the evidence must live; if the evidence isn't there, treat the claim as still open no matter what anyone says.

## Definitions (used throughout)

| Term | Meaning |
|---|---|
| **Gate journal** | The on-disk record a gated session produces: plan, the *predicted* observation at each gate, the *actual* observation, and what changed when they diverged. Defined by `fable-session-campaign`. It is the audit trail that makes judgment gradeable. |
| **Recurrence ledger** | The count, per known failure class, of how many times that class has bitten after its lesson was recorded. Defined by `fable-self-improvement-loop`. A ledger that stays at 1 per class means the library compounds; a class hitting 2+ means process failure. |
| **Matched pair** | The same task, same starting context, run twice: once by configuration A, once by configuration B. The only independent variable is the configuration. |
| **Blind grading** | The grader sees two completion reports labeled only A/B — no model names, no telltale formatting — and states a preference with reasons before unblinding. |
| **Trigger-hit-rate** | On a task set where the correct skill(s) to load are known in advance, the fraction of tasks where the router actually loaded them. |
| **BM25** | A classic lexical (keyword-statistics) ranking function for retrieval — no embeddings, no API calls, pure-python implementations exist. |
| **Progressive disclosure** | Index only names + descriptions; load a skill's full body from disk only after it is selected. Keeps context cost proportional to skills *used*, not skills *available*. |
| **Held-out** | Tasks not used while designing or tuning the thing being evaluated. Evaluating on the tasks you tuned on is self-grading homework. |

---

## Problem 1 — Measuring judgment transfer (does Sonnet+library ≥ bare Fable?)

**Status: OPEN.** This is the library's headline success criterion (manifesto, 2026-07-05) and it has never been measured.

**Why current practice fails.** Static prompt engineering and distillation are graded on *outputs*: did the answer match, did the eval pass. Judgment is a property of the *process* — did the session enumerate interpretations, pick the discriminating check, stop at a surprising gate? Two sessions can produce the same final diff where one guessed and one reasoned; output-only grading cannot tell them apart, so it cannot tell you whether judgment transferred or the small model just got lucky on easy tasks.

**This project's asset.** Two things make judgment auditable here that generic benchmarks lack:
1. A dated incident canon (2026-02 through 2026-07) of *real* failures with known root causes and known judgment errors — so benchmark tasks have ground truth about what good judgment looks like, not just what the right answer is.
2. The gated campaign protocol (`fable-session-campaign`) forces every session to write predictions before observations into a gate journal — so the process itself becomes a gradeable artifact.

**First three steps (in this repo):**
1. Write `skills/fable/fable-research-frontier/experiments/judgment-transfer/tasks.md` defining 5 benchmark tasks reconstructed from the incident canon, each with the symptom as given to the session, the ground-truth root cause, and 3–5 *judgment markers* (process behaviors the winning session should exhibit). Candidate set, one per failure class:
   - **T1 — Fails-open dedup** (canon 2026-06-12): symptom "duplicate posts after an infra blip; the dedup key existed the whole time." Markers: distinguishes fail-open vs fail-closed; notes the cache-get that swallows exceptions; checks eviction stats before blaming eviction; spots the every-replica cron race as a second mechanism.
   - **T2 — Silent AttributeError** (canon 2026-04-21): symptom "LLM feature output got thin; looks like a prompt regression." Markers: greps for swallowed-exception/typo patterns *before* prompt tuning; runs the call path once and inspects whether the fallback branch fired.
   - **T3 — Silent truncation** (canon 2026-04-21): symptom "thread summaries lack depth." Markers: treats data completeness as a hypothesis (negative space); checks API pagination defaults and downstream `[:N]` slices before touching the prompt.
   - **T4 — Attachment pipeline** (canon 2026-06-11/12, the positive exemplar): symptom "bot says it can't read the file, after two fixes." Markers: eliminates hypotheses with cheap discriminating checks (scopes present? download works? extraction works? SDK version?) before writing any code.
   - **T5 — Stale environment model** (canon corrected 2026-05-27): a deploy task where the recorded belief about the deploy mechanism is wrong. Markers: re-verifies the deployment path before acting instead of trusting the stale note.
2. Write `experiments/judgment-transfer/protocol.md`: matched pairs — configuration A = Sonnet-class model with `fable-core` + campaign runbook loaded; configuration B = bare Fable-class model, same task text, no library. Both must produce a completion report and (for A, natively; for B, whatever it produces) their working notes. Fix the grading rubric *before* any runs: per-task, score each judgment marker hit/miss, plus a blinded overall preference.
3. Write `experiments/judgment-transfer/grading-sheet.md` (the blind template) and run one pilot pair on T1 only, to debug the protocol before spending on all five.

**You have a result when:** a blinded grader prefers Sonnet+library on a majority of the 5 tasks, **and** the gate journals show the tenets actually firing in-flight (predictions written before observations, a surprise triggering a re-plan) rather than being pasted in as post-hoc narration. Both clauses required — preference without journal evidence is indistinguishable from luck. A negative result (bare Fable wins) is also a result: it localizes which skills fail to transfer, per task and per marker.

---

## Problem 2 — Automated lesson capture (corrections → library without human routing)

**Status: OPEN.**

**Why current practice fails.** The state of the art is a standing instruction: "after any correction, update lessons.md." That relies on the model *remembering to run its own ritual*, and the canon documents exactly this failing: on 2026-02-12 a mandated preflight ritual was skipped for an entire implementation session until the owner called it out. A discipline that depends on in-context memory is exactly the kind of discipline that decays over a long session — the corrections most worth capturing (end of a hard session) arrive when compliance is lowest.

**This project's asset.** (a) `fable-self-improvement-loop` already defines the lesson format, routing, and the recurrence ledger — the *destination* exists; only detection and drafting are missing. (b) The harness supports hooks (pre/post-tool and prompt-submit interception) that run *outside* the model's context, so detection cannot decay. (c) The canon's 11 feedback memories are a labeled training set of what real corrections looked like in-session.

**First three steps (in this repo):**
1. Write `experiments/lesson-capture/signal-taxonomy.md`: go through the canon's correction incidents and classify the in-session surface form of each correction — explicit contradiction ("that's wrong, it actually auto-deploys"), user re-doing/reverting the agent's work, user pasting an error the agent said couldn't happen, user restating an instruction already given. Each signal class gets a detection heuristic and an estimated false-positive rate.
2. Write `experiments/lesson-capture/hook-spec.md`: a spec (not yet an install — hooks are owner config, out of this repo's write scope) for a prompt-submit hook that pattern-matches signal classes and appends `{timestamp, session, triggering exchange}` to a `pending-lessons.md` inbox file, plus an end-of-session step where the model drafts each pending item into the `fable-self-improvement-loop` lesson template.
3. Dry-run the taxonomy backwards: for each of 5 canon corrections, verify the heuristics *would have* flagged the actual exchange (reconstruct the exchange from the memory's description). Record precision/recall of the taxonomy on this historical set in `experiments/lesson-capture/backtest.md`.

**You have a result when:** a real session's correction lands in the library as a routed lesson **without a human deciding to capture it**, and a later session hits the same situation and does *not* repeat the mistake — i.e., the auto-captured lesson demonstrably prevented a recurrence (ledger entry created at 1 and staying at 1). Detection alone is not a result; prevention is.

**Guardrail:** auto-*capture* may be automated; auto-*merge* may not. Drafted lessons still enter the library through `fable-self-improvement-loop`'s review step. Do not build anything that edits skills unreviewed.

---

## Problem 3 — Skill-load routing (the right skill at the right moment)

**Status: OPEN, with local precedent.**

**Why current practice fails.** Two failure modes dominate. *Always-load-everything* burns context: 15 skills × hundreds of lines each crowds out the actual task, and long-horizon decay (see `fable-long-horizon`) hits sooner. *Static keyword triggers* are brittle: the moment a skill matters is a *symptom* ("evidence contradicts itself", "this bug makes no sense"), and symptoms rarely contain the skill's name. Routing is a retrieval problem over trigger-rich descriptions, and most skill systems never treat it as one.

**This project's asset.** (a) Every skill in this library has a description written as symptoms-and-situations, not topics — that is a deliberately retrieval-friendly surface. (b) There is working local precedent: as of 2026-06-10, the owner's ecosystem runs progressive disclosure over an 806-skill library — metadata-only index, BM25 lexical prefilter to a top-25 shortlist, a small model picks 1–2, and only those bodies are read from disk. It replaced a sampled catalog that had left the router blind to 750+ skills, and it chose BM25 over embeddings specifically to avoid runtime embedding calls. The architecture is proven at 50× this library's size; the open question is whether it beats always-load on *this* library's 15 skills, where the fixed cost of just loading everything is much lower.

**First three steps (in this repo):**
1. Write `experiments/skill-routing/index.md`: extract every sibling's frontmatter description into one routing table (name → trigger text). This is the retrieval corpus; it also doubles as an audit that descriptions are actually symptom-rich (any description that reads as a topic label gets flagged for the maintainers via `fable-self-improvement-loop`).
2. Write `experiments/skill-routing/heldout-tasks.md`: 20 short task prompts, each labeled with the skill(s) a Fable-grade session *should* load for it — drawn from real session shapes (a vague feature ask, a "makes no sense" bug, a prod-touching change, a cold start on an unknown repo), written by someone other than whoever tunes the router, and kept out of any tuning loop.
3. Write `experiments/skill-routing/scoring.md`: define the two baselines (always-load-all-15; load-fable-core-only) and the metrics — trigger-hit-rate on the held-out set, total tokens loaded per task, and task success. Then run the cheapest router first (BM25 over the index from step 1) before anything fancier.

**You have a result when:** on the held-out task set, routed loading matches always-load-everything on task success while beating it on tokens, with trigger-hit-rate high enough that misses are noise, not a pattern. If always-load wins at 15 skills, record that honestly — it bounds the library size at which routing starts paying, which is itself a publishable finding.

---

## Problem 4 — Cross-model portability (does the library transfer down to Haiku-class?)

**Status: OPEN.** The manifesto's bet is that the gap between models is *unprompted moves*, not capability. Sonnet-class is the design target; Haiku-class is the stress test of the thesis.

**Why current practice fails.** Prompts and scaffolds are typically tuned on one model and silently regress on smaller ones; distillation transfers input→output mappings, not the discipline of *when to stop and check*. There is no standard way to even measure whether a process discipline survives a model downshift — output benchmarks confound "worse model" with "discipline stopped firing."

**This project's asset.** The recurrence ledger is a model-independent metric: it counts repeats of *known failure classes*, not answer quality. If Haiku+library keeps the ledger flat on the same task classes where Sonnet+library keeps it flat, the discipline transferred even if the prose got worse. No other asset here separates those two things.

**First three steps (in this repo):**
1. Write `experiments/portability/protocol.md`: reuse Problem 1's task set (do not invent a new one — comparability across model tiers is the point). Select the 3 lowest-blast-radius tasks (T2, T3, T5 are diagnosis-shaped and reversible).
2. Define the downshifted loadout in the same file: Haiku-class gets `fable-core` plus at most one targeted sibling per task — context budget is the scarcest resource at that tier, so portability testing *requires* Problem 3's routing rather than always-load. Note the dependency explicitly: P4 results are only interpretable after P3 has a routing decision.
3. Write `experiments/portability/ledger-tracking.md`: per model tier (Fable / Sonnet / Haiku, each +library), record for each task: judgment markers hit, gates honored (prediction written before observation, yes/no per gate), and any canon failure class repeated. Grade with the same blind sheet as Problem 1.

**You have a result when:** the recurrence ledger stays flat as model size drops — Haiku+library repeats none of the canon failure classes on the task set, even if its reports are rougher. Partial results are expected and must be reported as such: "gates honored but marker X dropped at Haiku tier" is more useful than a pass/fail. If the ledger climbs at Haiku, the library's floor is Sonnet-class; say so in the manifesto rather than quietly hoping.

---

## Shared experimental hygiene (applies to all four)

- **Rubric before runs.** Grading criteria are written and frozen before the first matched pair executes. Changing the rubric after seeing results is the eval version of a fail-open check.
- **Predict, then run.** Before each experiment, write the expected outcome and what result would falsify the library's claim (Tenet 7 applied to the library itself; recipes in `fable-adversarial-toolkit`).
- **One variable per pair.** Model tier OR library presence OR routing policy — never two at once.
- **Negative results are results.** They get recorded in the same experiment directory with the same rigor, and they update the manifesto's claims via `fable-self-improvement-loop`. An experiment that can only ever confirm is not an experiment.
- **Small n honesty.** Five tasks and one grader is a pilot, not a study. Report it as "pilot evidence," never "we showed."

---

## External positioning rules (what may be said about this library out loud)

These bind anyone writing a README claim, a blog post, a pitch slide, or a conference abstract about this library.

### 1. Claim ceiling

You may publicly claim **exactly what a milestone above has demonstrated, and nothing beyond it.** Mapping, as of 2026-07-05 (all rows currently at the bottom state):

| If this is true | You may say | You may NOT say |
|---|---|---|
| P1 milestone hit | "In a 5-task pilot, blinded grading preferred Sonnet+library over bare Fable on a majority of tasks; gate journals attached." | "The library makes small models as good as big ones." |
| P2 milestone hit | "One correction was auto-captured and prevented one recurrence." | "The library learns automatically." |
| P3 milestone hit | "Routed loading matched full-load success at N% fewer tokens on a held-out set." | "Skill routing is solved." |
| P4 milestone hit | "The recurrence ledger stayed flat down to Haiku-class on 3 diagnosis tasks." | "Works on any model." |
| No milestone hit (current state) | "We built X and here is the open problem + protocol." | Any results language at all. |

### 2. Reproducibility standard

**A claim ships with its gate journal.** Any public statement of a result must link or attach: the frozen rubric, the task definitions, the raw completion reports (both arms), the blind grading sheets, and the gate journals. If a result's evidence bundle cannot be assembled, the result does not exist for positioning purposes — regardless of how confident anyone feels about it. This is Tenet 9 applied outward: externalized state is what makes a claim auditable by a stranger.

### 3. Novelty honesty

Be precise about what is old and what is candidate-new. Overselling known practice as novel is the fastest way to lose technically literate audiences.

**Old ideas — never claim novelty:**
- Gated runbooks with predicted observations: aviation checklists and SRE playbooks have done this for decades.
- Postmortems and lesson files: standard blameless-retro practice.
- Skill/prompt libraries and progressive disclosure: known practice; the 806-skill BM25 router precedent (2026-06) already exists in the owner's own ecosystem.
- Distillation and model cascades: well-trodden research.

**Novelty candidates — "candidate" until a milestone lands:**
- **The self-measuring recurrence loop:** a skill library whose success metric is *its own* recurrence ledger, and which updates itself through a defined correction protocol — closing the loop between "we wrote a lesson" and "the lesson measurably prevented a repeat." (Becomes claimable at P2's milestone.)
- **Model-downshift portability as a falsifiable target:** using a model-independent process metric (ledger flatness) to test whether a discipline, not just an output distribution, transfers to smaller models. (Becomes claimable at P4's milestone.)
- **Judgment auditability via gate journals as grading substrate:** grading the *process record* blind, not the output. (Becomes claimable at P1's milestone.)

When in doubt, the honest frame is: "old ideas, unusually tightly instrumented." That sentence is always safe.

---

## When NOT to use this skill

| You are actually trying to... | Load instead |
|---|---|
| Run a real work session end-to-end with gates | `fable-session-campaign` |
| Record one correction or new lesson into the library | `fable-self-improvement-loop` |
| Decide what counts as proof for an ordinary code change | `fable-verification-and-evidence` |
| Design a discriminating experiment inside a live debugging hunt | `fable-adversarial-toolkit` |
| Get routed to the right skill for a task (the *practice* of routing, not the research on it) | `fable-core` |

This skill never authorizes bypassing `fable-change-control` or `fable-self-improvement-loop` — experiments write only inside `skills/fable/fable-research-frontier/experiments/`, and any library change an experiment motivates goes through the normal protocols.

## Provenance and maintenance

As of 2026-07-05. Sources by claim class:

- **The success bar and observed gaps** (Sonnet+library ≥ bare Fable; judgment/long-horizon/decomposition) — the library manifesto at `skills/fable/README.md` (this repo). On conflict, the manifesto wins.
- **Incident details behind benchmark tasks T1–T5** — the owner's dated memory corpus: fails-open dedup + `evicted_keys=0` + every-replica cron race (2026-06-12); silent AttributeError masking a "prompt regression" across 9 call sites (2026-04-21); Slack `conversations.*` ~28-message default + compounding `[:20]` slice (2026-04-21); attachment-pipeline discriminating diagnosis incl. prod SDK 0.109.1 and token in PID-1 env (2026-06-11/12); auto-deploy misbelief corrected 2026-05-27; skipped preflight ritual (2026-02-12). All verified against the memory files at authoring time. Memories are point-in-time — re-verify code-level details against live systems before embedding them in actual benchmark task text.
- **BM25/progressive-disclosure precedent** — owner's ecosystem memory dated 2026-06-10: 806 skills, metadata-only index, `rank_bm25` prefilter to top-25, small-model pick, lazy body load; chosen over embeddings to avoid runtime embed calls. Architecture details may have drifted since; re-check before citing numbers publicly.
- **"Nothing demonstrated yet"** — true at authoring time by construction (the experiments/ directory did not exist). This is the claim most likely to go stale — see re-verification below.
- **SOTA characterizations** ("output-only grading", "distillation transfers outputs not process") — first-person assessment by claude-fable-5 as of its January 2026 knowledge cutoff. Treat as informed opinion; re-survey the literature before any public novelty claim.

Re-verification one-liners (run from the repo root):

```bash
# Has any experiment actually run? (If this shows results files, the "all OPEN" labels above are stale.)
find skills/fable/fable-research-frontier/experiments -type f 2>/dev/null

# Do the sibling skills this file routes to still exist?
ls skills/fable/ | grep -E 'session-campaign|self-improvement|verification|adversarial|core'

# Has the manifesto's success bar changed?
grep -n "Success bar" skills/fable/README.md
```

Update protocol: when a milestone is hit or falsified, update the Status line of that problem AND the claim-ceiling table in the same change, with the evidence bundle path — routed through `fable-self-improvement-loop`. Never update positioning language without updating (or citing) evidence.
