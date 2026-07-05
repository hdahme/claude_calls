---
name: fable-effort-calibration
description: >
  Load this BEFORE starting work whenever you are deciding how hard to work on a task:
  whether to enter plan mode, how many subagents to spawn, how deeply to verify, which
  model tier to delegate to, or whether to ask questions first. Also load when you catch
  either miscalibration symptom: you are writing paragraphs of analysis for a one-line
  edit, spawning subagents for a rename, or adding speculative structure ("performing
  thoroughness"); OR you are about to declare a diagnosis after one look, skip a preflight
  ritual because the task "looks simple", or apply a fix to a system you haven't confirmed
  still works the way you remember ("skimming"). The output of this skill is a budget:
  planning depth, verification depth, parallelism, and ask-vs-act, sized to the task class.
---

# Fable: Effort Calibration

**Tenet 1 made executable: "Calibrate before you cogitate."** The first output of thinking is a budget, not an answer. Effort is a dial, not a virtue — the dial is set by cost-of-being-wrong, reversibility, and novelty, never by how impressive the work looks.

This skill exists because miscalibration is symmetric and both directions are real, observed failures:

- **Over-effort** wastes the session and annoys the owner ("would a senior engineer say this is overcomplicated?").
- **Under-effort** ships wrong diagnoses, destroys irreversible state, and skips the cheap rituals that catch expensive errors.

## Step 0: Score the task (30 seconds, always)

Before any tool call, answer four questions. Write the answers down for anything non-trivial (a one-line note is enough).

| Question | Low end | High end |
|---|---|---|
| **Cost of being wrong?** | typo in a comment | prod outage, destroyed user work, wrong money moved |
| **Reversible?** | git-tracked local edit (free undo) | overwriting a hand-formatted doc, deleting data, sending a message, deploying (push-to-main auto-deploy repos make "just a commit" irreversible-ish) |
| **Novel to me?** | pattern I've executed here before | new codebase, new API, stale mental model possible |
| **Cheap to verify?** | one command proves it | verification itself needs design |

High score on ANY axis promotes the task at least one row in the decision table below. Irreversibility alone promotes the task to `fable-change-control`'s slow path: proceed only under an explicit ask or durable authorization covering that specific mutation; otherwise ask first. (An irreversible action the user just explicitly requested does not need a redundant re-ask.)

Copy-pasteable budget note (fill in and keep at the top of your plan for anything above the trivial row):

```
BUDGET: class=<trivial|focused-fix|feature|multi-domain|research>
  wrong-cost=<low|med|high>  reversible=<yes|no|partly>  novel=<yes|no>  verify-cost=<cheap|expensive>
  plan=<none|1-line|plan-mode>  verify=<build|repro+rerun|e2e|per-seam|hypothesis-elimination>
  subagents=<0|N: one job each>  ask-first=<no|assumptions-stated|yes: about X>
```

## The decision table (core artifact)

| Task class | Planning depth | Verification depth | Parallelism / delegation | Ask questions first? |
|---|---|---|---|---|
| **Trivial edit** (rename, typo, config value, one obvious line) | None. No plan mode, no preamble. | Syntax/build check at most. Exception: an edit that gates a deploy (dependency manifests, CI config, anything in an auto-deploy repo) is never trivial-row — grep-confirm the change landed per `fable-change-control` §3.1; an Edit success message is not proof (canon 2026-04-19, AR-06). | None. Single-threaded, done in one pass. | No — unless the "trivial" edit touches something irreversible. |
| **Focused fix** (known bug, small surface, error message in hand) | Mental plan; state it in one sentence. Reproduce before fixing. | Reproduce → fix → re-run the reproduction. "Fix the bug" becomes "write a check that reproduces it, then make it pass." | Parallel *tool calls* (batch independent reads/greps in one block); no subagents. | No — act. But if the fix contradicts your model of the system, stop and re-diagnose. |
| **Standard feature** (one system, 3+ steps, some design choice) | Plan mode / written plan with checkable items and a verify step per item. | Run the real path end-to-end once, not just tests. Diff behavior before/after where relevant. | Parallel tool calls throughout; 0–2 subagents for research/exploration that would pollute main context. | Ask only if genuinely ambiguous (multiple live interpretations). Otherwise state assumptions explicitly and proceed. |
| **Multi-domain change** (crosses systems: API + infra + data; or unfamiliar codebase) | Full plan mode. Spec first; front-load the piece most likely to kill the design. Expected observation at every gate. | Per-seam verification (see `fable-decomposition`) plus one end-to-end proof. Never trust a stale environment model — re-verify deploy paths, scopes, versions. | Fan out: one subagent per independent exploration; consider worktrees for independent features. | Yes — surface interpretations and assumptions before implementation. Present a plan, get a nod. |
| **Research / open investigation** (unknown root cause, "why is X happening", feasibility) | Plan the *investigation*, not the fix: a weighted hypothesis list and the next discriminating check. | Highest. Every eliminated hypothesis needs evidence, not vibes. One mechanism must explain all observations before you call it. | Heavy: parallel subagents for independent hypothesis checks; parallel tool calls for every independent read. | Ask for symptoms/logs/access you're missing; do NOT ask the user to pick a hypothesis for you. |

**Promotions and demotions happen mid-task.** A "trivial edit" to a file that turns out to be generated → promote. A "research" task where the first grep finds the smoking gun → demote and finish. Re-sizing on new information is calibration working, not the plan failing.

## Session configuration axes (as of 2026-07-05)

These are the concrete knobs a Claude Code session has. The table above tells you where to set each.

### Plan mode
Enter plan mode for any non-trivial task (owner's rule: 3+ steps or architectural decisions). Plan mode is also for *verification design* — "how will I know each step worked" — not just build order. If something goes sideways mid-execution, stop and re-plan immediately; do not keep pushing. A plan without an expected observation per step is a to-do list, not a plan (see `fable-decomposition`).

### Subagent delegation
Use subagents liberally to keep the main context window clean — but with discipline:
- **One task per subagent.** A subagent with three jobs does all three at half depth.
- Delegate: research, codebase exploration, parallel independent hypothesis checks, bulk mechanical transforms.
- Do NOT delegate: the final judgment call, anything requiring the full session context, or irreversible actions.
- Give each subagent verifiable success criteria in the prompt ("return file:line evidence", not "look into X"). Weak criteria force the subagent to guess and force you to redo the work.

### Parallel tool calls
If multiple tool calls have no dependencies between them, issue them in one block. This is free speed and costs nothing in correctness. Reading five candidate files, running three greps, checking two versions — always batch. Serial calls are only for genuinely dependent steps.

### Model tiers for delegation (heuristic, as of 2026-07-05)
When you control which model runs a delegated task:
- **Haiku-class**: cheap, fast. Mechanical extraction, classification at volume, formatting, summarizing bounded text. Fails on multi-step judgment — don't give it ambiguity.
- **Sonnet-class**: the default workhorse. Well-specified implementation, focused fixes, research with clear success criteria. This library exists to let Sonnet-class sessions execute Fable-class judgment — the spec you write IS the intelligence transfer.
- **Opus/Fable-class**: reserve for ambiguity resolution, cross-domain synthesis, adversarial review of your own conclusion, and writing the specs that lower tiers execute.
- The delegation rule of thumb: **the tier needed is set by the ambiguity of the spec, not the size of the task.** A huge but crisply specified job is a Haiku/Sonnet job. A tiny but ambiguous one is not.
- Re-verify current model names/pricing against live API docs before hardcoding any model ID anywhere — they drift, and a config typo class exists here (see worked example 2 below).

### Reasoning-effort semantics
In this harness's review tooling (observed 2026-07-05), effort levels trade **breadth for confidence**: low/medium yields fewer, higher-confidence findings; high and above yields broader coverage including uncertain findings that need your triage. Match to the row: focused fix → low/medium (you want signal, not a haystack); pre-merge review of a multi-domain change → high. Other tools' effort/thinking knobs do not necessarily share these semantics — check the tool's own description before mapping this table onto them. On the API side the analogous knob is the extended-thinking token budget; note that a configured budget of 0 disables thinking entirely on that path — an effort setting silently pinned in config is a real failure mode to check when output quality drops.

## Anti-patterns: over-effort (performing thoroughness)

The test, verbatim from the owner's rules: **"Would a senior engineer say this is overcomplicated?" If yes, simplify. If you wrote 200 lines and it could be 50, rewrite.**

- **Speculative structure**: abstractions for single-use code, configurability nobody asked for, error handling for impossible scenarios. Minimum code that solves the problem.
- **Ceremony on trivial rows**: plan documents for a one-line fix; subagents for a grep; asking permission when the path is clear ("don't ask, just do" applies when the path is clear AND reversible).
- **Verification theater**: re-reading a file you just edited "to check", when the edit is cosmetic and nothing downstream depends on it; running the full test suite for a comment change; restating file contents back to the user. Carve-out — this never applies to load-bearing files: an Edit success message is tier-4 evidence, not proof (canon 2026-04-19: an Edit to requirements.txt reported success and the line never landed — see `fable-change-control` §3.1), so dependency manifests and anything auto-deployed always get a grep-confirm.
- **Improving adjacent code**: every changed line must trace to the request. Noticing unrelated issues → mention, don't fix (that's `fable-change-control` territory).

Over-effort is not "safe." It burns context (accelerating long-horizon decay), buries the actual change in noise, and trains the reader to skim your output.

## Anti-patterns: under-effort (skimming hard problems)

- **Diagnosis by first impression.** A "prompt regression" that is actually a typo; a "broken pipeline" that is actually a lossy formatting step. Before accepting the obvious story, spend one cheap check on the boring alternative (grep for the typo class, run the call path once and look at the raw response).
- **Acting on a stale environment model.** "This repo doesn't auto-deploy" (it did — push-to-main triggered Cloud Build; the memory was wrong and got corrected 2026-05-27). Before any action whose blast radius depends on an environment fact, re-verify the fact. Memories and docs are hypotheses, not state.
- **Treating irreversible operations at reversible-operation speed.** Overwriting user-formatted documents, wholesale file replaces, sends, deletes, deploys: these force a promotion to "ask first" regardless of how simple the edit itself is.
- **Assuming data completeness.** APIs truncate silently (pagination defaults, flaky filters). If your conclusion depends on "I saw everything," that's a hypothesis — test it (see `fable-verification-and-evidence`).
- **Skipping preflight because the task looks familiar.** See the process-lapse incident below.

## Calibration of process: the 2026-02-12 incident

Under-effort applies to *rituals*, not just analysis. On 2026-02-12, an entire implementation session (vesting panel + Slack alerts) ran without the owner's mandated session-start preflight (his Expert Lens semantic search). The work proceeded; the owner had to call out the lapse himself.

The lesson generalizes beyond that specific ritual:

> **Cheap rituals exist because they catch expensive errors. The expected value of a 30-second preflight is positive even when it usually finds nothing — skipping it is a miscalibration, not an efficiency.**

Rules derived:
1. Mandated preflights (whatever the host environment's CLAUDE.md mandates: lesson review, preflight searches, plan-mode entry) run at **session start for any non-trivial task**, unconditionally. "I was busy implementing" is precisely when they matter.
2. A ritual's cost is paid once per session; the error class it catches is paid in owner trust. Never trade the former to save the latter.
3. If a ritual genuinely never fires for a task class, the fix is to change the rule via `fable-self-improvement-loop` — never to silently skip it.

## Worked examples from the canon

**1. Right-sized high effort — the Excel diagnosis (2026-06-12).** Symptom: "bot still can't read xlsx" after two same-day fixes. The under-effort move was a third blind patch. Instead, effort went into *discriminating checks before any code*: verified the live token actually had `files:read` (the repo manifest was stale — negative space check), ran the exact download/extract path in the prod pod against a real file (all worked), confirmed the prod SDK version (0.109.1, vs old local — "test in the pod, not locally"), located the real token (`/proc/1/environ`, not the exec shell env). Each check eliminated a hypothesis; the surviving explanation (lossy 60K text dump, not a broken fetch) made the fix obvious and small. Research-row verification depth on what looked like a focused fix — justified because two prior fixes had already failed, which is a promotion trigger.

**2. Under-effort trap — the silent AttributeError (2026-04-21).** Two "regressions" (thin IC memos, empty calendar briefs) looked like prompt-tuning work — a standard-feature-sized effort. One grep-class check found the truth: `config.MODEL_SONNET` referenced where the real attribute was `SONNET_MODEL`; a broad `except Exception` swallowed the AttributeError across 9 call sites and callers returned canned fallbacks. Calibration lesson: when output gets "thin," the cheap boring hypothesis (typo/swallowed exception) gets one check *before* the expensive interesting one (model behavior changed). Cost of the check: one `rg`. Cost of skipping it: days of prompt tuning against a bug.

**3. Irreversibility misjudged — the pandoc roundtrip (2026-05-08).** Asked to push three small patches to a Google Doc the owner had hand-formatted. Treated as a trivial-row task (export → patch → pandoc → replace). But the replace path re-renders with default styles: it destroyed all the manual presentation work; the owner reverted the doc. The patches were small; the *operation* was irreversible — that single axis should have promoted it to "ask first / deliver targeted edits for manual application." Effort is sized by blast radius, not by diff size.

## Mid-task re-calibration triggers

Stop and re-size (don't push through) when:
- A gate's expected observation doesn't match reality (surprise = your model is wrong upstream).
- A fix you were sure about fails twice. Two failed attempts promote the task to the research row.
- You notice you're about to do something irreversible that wasn't in the plan.
- You've spent 3x the budgeted effort on the current row — either the classification was wrong or the approach is; re-plan.
- The task turned out simpler than classified — finish at the lower row; don't backfill ceremony.

## When NOT to use this skill

- You've set the budget and need to **cut the problem into stages** → `fable-decomposition` (the flagship).
- The question is **ask-vs-act on an ambiguous request**, enumerating interpretations → `fable-ambiguity-and-judgment` (this skill only tells you *whether* the row demands asking; that one tells you *how*).
- You need to know **what counts as proof** once you've decided to verify deeply → `fable-verification-and-evidence`.
- Session is long and decaying, constraints slipping → `fable-long-horizon`.
- You're sizing a **change's safety**, not the effort (reversibility ladder, surgical-change rules) → `fable-change-control`.
- You want the full gated runbook for a big vague task → `fable-session-campaign`.
- A correction just landed and a rule should change → `fable-self-improvement-loop` (never silently skip or rewrite rituals outside it).

## Provenance and maintenance

- **The dial inputs and both anti-pattern families**: owner's global workflow rules (Plan Mode Default, Subagent Strategy, Verification Before Done, Surgical Changes, Simplicity First / the senior-engineer test, "Don't ask, just do") and the manifesto's Tenets 1, 4, 7 (`skills/fable/README.md`). If this skill and either source conflict, the sources win.
- **Incidents**: owner's dated memory corpus — 2026-02-12 preflight lapse, 2026-04-21 silent AttributeError, 2026-05-08 pandoc roundtrip and wrong-project scratch, 2026-05-27 auto-deploy correction, 2026-06-12 Excel diagnosis and Redis dedup. Dates verified against the memory files 2026-07-05.
- **Configuration axes** (plan mode, subagent semantics, parallel tool calls, effort levels): the Claude Code harness as observed 2026-07-05. These drift with harness releases — re-check against the current session's tool descriptions and system prompt before relying on specifics.
- **Model-tier guidance**: first-person introspection by claude-fable-5 plus the delegation rule of thumb; labeled heuristic. Re-verify model lineup/pricing against live Anthropic API docs (or the host's `claude-api` skill if present) before hardcoding any model ID.
- **Corrections (2026-07-05, library review):** removed the claim that "the Edit tool erroring is your signal" for trivial edits — it contradicted the 2026-04-19 canon (an Edit reported success and the dep never landed; `fable-change-control` §3.1's grep-confirm is mandatory for load-bearing files regardless of task class). Rephrased "irreversibility forces ask-first" to match change-control's rung-3/4 gates (explicit ask OR durable authorization). Scoped the reasoning-effort semantics to this harness's tooling instead of all tools.
- Re-verification one-liners:
  - Manifesto still says effort is a dial: `grep -n "Calibrate before you cogitate" skills/fable/README.md`
  - Owner rules still mandate plan mode + the overcomplication test: `grep -n "overcomplicated" ~/.claude/CLAUDE.md`
  - Incident dates: `grep -rn "2026-02-12\|2026-04-21\|2026-05-08" ~/.claude/projects/-Users-hd-Projects/memory/ 2>/dev/null` (owner's machine only).
