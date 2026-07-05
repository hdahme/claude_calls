---
name: fable-context-bootstrap
description: >
  Cold-start protocol for recreating Fable-grade working context from zero. Load this when: you are
  a fresh session with no memory of this project; you are resuming work another session or another
  person started; you were handed a task in a repo you have never opened ("just fix X in this
  codebase"); you are about to write your first file in an unfamiliar directory tree; or you notice
  you are acting on remembered facts about an environment (deploy model, API scopes, DB engine)
  that you have not re-verified this session. Symptoms that you skipped it: an edit that violates a
  house rule you'd have found in CLAUDE.md, a file written in the wrong style or wrong directory,
  or a decision made on a stale memory claim.
---

# fable-context-bootstrap — the cold-start protocol

A zero-context session is not a handicap; it is the default condition. Every session starts cold.
The difference between a Fable session and a flailing one is that Fable spends the first minutes
rebuilding context *in a fixed order*, writes down what it learned, and only then touches anything.

**The core claim:** orientation is cheaper than any mistake it prevents. Ten minutes of reading
beats one wrong edit to auto-deployed code. Do not negotiate with this.

**Jargon defined once:**
- *Rules files* — instruction files the owner maintains for agents: a global one (e.g.
  `~/.claude/CLAUDE.md`) and optionally project-local ones (`./CLAUDE.md`, `./.claude/`,
  `AGENTS.md`, `CONTRIBUTING.md`). They override your defaults.
- *Memory index* — a curated summary of past sessions' conclusions (e.g. a `MEMORY.md`, a
  `memory/_map.md`, a `tasks/lessons.md`). Treat every claim in it as a **dated hypothesis**, not
  a fact — see the staleness rule below.
- *Constraint ledger* — the artifact this bootstrap produces: a short written list of the hard
  constraints governing your work, each tagged with its source and whether you verified it or
  merely read it.

## The bootstrap order (do not reorder)

The order matters because each layer can veto the next. Owner rules override repo conventions;
repo reality overrides memory claims.

| Phase | Read | You are answering |
|---|---|---|
| 1 | Owner rules: global, then project-local | "What am I *never* allowed to do here, and what rituals are mandatory?" |
| 2 | Memory / lesson indexes, if present | "What did past sessions already learn, and which of those claims are volatile?" |
| 3 | This library: `skills/fable/README.md`, then `fable-core` | "What discipline am I applying, and which sibling skills does this task need?" |
| 4 | Repo orientation (detail below) | "How does this codebase build, test, deploy — and what changed recently?" |
| 5 | Write the constraint ledger | "What are the ten facts that, if I forget them, cause an incident?" |

### Phase 1 — owner and project rules

Read the global rules file completely, then any project-local one. Global first: it usually holds
the owner's non-negotiables (secrets handling, "plan before non-trivial work", surgical-change
rules, mandatory preflight rituals). Project-local files refine or override for this repo.

**Mandatory rituals are not optional on busy days.** Canon: on 2026-02-12 an entire implementation
session ran without the owner's mandated preflight step (a semantic search ritual his rules file
marks CRITICAL and "run first"). The work was fine; the owner still had to call out the lapse, and
it became a permanent lesson entry. If a rules file says "always do X first," X goes at the top of
your checklist, before the interesting work — that is exactly when it gets skipped.

### Phase 2 — memory and lesson indexes

Look for them; do not assume them. Common locations: a `MEMORY.md` auto-loaded by the harness, a
`memory/` directory with a `_map.md` navigation file, a `tasks/lessons.md` in the project. Read
the **index** first, then only the individual entries relevant to today's task — the index exists
so you don't read everything.

Classify each claim you plan to act on:

- **Stable** (a lesson about an API's behavior, a settled design decision) — take it.
- **Volatile** (deploy pipeline, credentials, versions, what's currently running) — take it as a
  hypothesis and re-verify before acting. See the staleness rule.

### Phase 3 — this library

Read `skills/fable/README.md` (the Ten Tenets), then load `fable-core`, which routes to whichever
sibling skill today's task needs (debugging → `fable-debugging-playbook`; a vague hard task →
`fable-session-campaign`; and so on). Bootstrap is Tenet 9 (externalize state) plus Tenet 5 (read
the negative space: what *should* exist in this repo that doesn't?).

### Phase 4 — repo orientation

Answer five questions, in roughly this order:

1. **What is this?** — `README.md`, top-level directory listing.
2. **What are its declared dependencies and entrypoints?** — the manifest for the ecosystem
   (`package.json`, `pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`), plus
   `Makefile` / `justfile` / `scripts/` for how humans actually run it.
3. **How is it tested?** — test directory, test runner config, the exact invocation. Run the
   suite (or its fastest slice) once *before changing anything* so you know the baseline. A
   pre-existing failure discovered after your edit will be blamed on your edit — by you.
4. **How does it deploy?** — CI config (`.github/workflows/`, `cloudbuild.yaml`, `Jenkinsfile`).
   This is the highest-stakes fact in the ledger: it determines whether a merged mistake is an
   inconvenience or an outage. Canon (2026-04-19): a top-level import was added to auto-deployed
   code while the matching `requirements.txt` edit silently failed to land; Cloud Build shipped
   it on push and both replica sets CrashLoopBackOff'd — a full prod outage. Knowing "push to
   main deploys" changes how much verification an edit deserves *before* it lands.
5. **What just happened here?** — recent git history. Reverts and rapid re-edits of the same file
   are settled battles; do not re-fight them (see `fable-failure-archaeology`).

### Phase 5 — the constraint ledger

Write it to disk (your scratch/plan file, per `fable-long-horizon`), not just into your head.
Format — one line per constraint, tagged:

```markdown
## Constraint ledger (bootstrapped 2026-07-05)
- [VERIFIED] push to main auto-deploys via CI (checked .github/workflows/deploy.yml)
- [VERIFIED] tests: `make test`, 212 pass on clean checkout
- [ASSERTED, memory 2026-05-27] DB is MySQL 8.0 not Postgres — re-verify before schema work
- [RULE] owner: no API keys in git; keys live in ~/.X-keys
- [RULE] owner: plan mode for any 3+ step task
- OPEN: how is the sidecar container built? (not found yet)
```

`VERIFIED` = you observed it this session. `ASSERTED` = a rules file or memory says so, with the
date. `RULE` = owner mandate, not falsifiable, just obey. `OPEN` = a known unknown — negative
space you noticed. Promote ASSERTED to VERIFIED before it becomes load-bearing.

## Copy-pasteable bootstrap checklist

Portable — adjust filenames to the ecosystem; every command is read-only.

```bash
# Phase 1: rules files (global, then project-local)
cat ~/.claude/CLAUDE.md 2>/dev/null
cat ./CLAUDE.md ./AGENTS.md 2>/dev/null; ls ./.claude/ 2>/dev/null

# Phase 2: memory / lesson indexes, if present
ls ./tasks/lessons.md ./tasks/todo.md 2>/dev/null
# harness-loaded MEMORY.md is usually already in your context — read it, note dates

# Phase 3: this library
cat skills/fable/README.md          # then load fable-core

# Phase 4: repo orientation
cat README.md; ls -la
cat package.json pyproject.toml requirements.txt Makefile 2>/dev/null | head -80
ls .github/workflows/ 2>/dev/null; cat cloudbuild.yaml 2>/dev/null | head -40
git log --oneline -25
git log --oneline -i --grep='revert' -15    # settled battles
git status                                   # dirty tree = someone mid-flight; do not clobber

# Baseline the tests BEFORE any edit (use the repo's real invocation)
# e.g.  make test  |  pytest -x -q  |  npm test

# Phase 5: write the constraint ledger into your plan/scratch file
```

Gate: **no Write/Edit to repo files until the ledger exists.** If the task is genuinely trivial
(one obvious line, blast radius fully understood), you may compress phases 2–4 — but phase 1 and
the deploy-model question are never skippable, because they are exactly what makes a "trivial"
edit dangerous.

## Convention detection — the nearest-sibling rule

Before writing *any* new artifact (file, skill, config, doc, test), find the existing sibling
most like it and match its style: naming, frontmatter, directory placement, section order, tone.
Your training-data default is not the house style.

Procedure:
1. List the directory where the artifact will live; open the closest existing example.
2. If there are several, prefer the most recently touched one (`git log -1 --format=%ci -- <path>`).
3. Diff your draft's *shape* against it before writing content.

**Worked example (this very repo, as of 2026-07-05):** the host repo has two skill subtrees with
*different* conventions. `skills/calls/skill.md` is lowercase `skill.md` with frontmatter keys
`name / description / tools / args / user-invocable`. The Fable library standardized on uppercase
`skills/fable/<name>/SKILL.md` with `name / description` only. A session about to add a Fable
skill that pattern-matched on `calls` (the older, superficially similar sibling) would ship the
wrong filename and frontmatter. Nearest sibling means nearest *in kind and in tree* — another
`skills/fable/*/SKILL.md` — not merely the first skill file you find. When the tree has zero
siblings of the right kind, the convention decision is real: check the library README or ask.

Directory placement is part of convention detection, and it has canon: on 2026-05-08 a scratch
analysis for project A was appended into sibling project B's `.plan` file because B's file was the
*style template* being copied. Owner's reaction: "we shouldn't be touching [B]". The rule: a
template tells you the *format*; the named project tells you the *destination*. Sibling projects
are read-only references unless explicitly targeted.

## Efficiency discipline

Bootstrap must be cheap or you will (rationally) skip it. Two rules:

1. **Read regions, not files.** When you know what you need, grep first, then read the matching
   region with an offset/limit — not the whole 3,000-line file. Whole-file reads are for phase-4
   orientation of *small* top-level files (README, manifest, CI config), where the whole file is
   the payload.
2. **Delegate broad sweeps; keep conclusions, not dumps.** "Find every caller of X across the
   repo" or "characterize how error handling works here" goes to a search subagent whose report
   is 10 lines of conclusions with file:line citations. Never paste raw file dumps into your own
   context — that is spending the context budget the constraint ledger exists to protect (see
   `fable-long-horizon` on context decay).

## The staleness rule — memory is a hypothesis with a date

Any volatile claim from memory gets re-verified against the repo before you act on it. The canon
case: the owner's memory index once stated a production repo had **no** auto-deploy, so pushes to
main were "safe" pending a manual deploy. Corrected 2026-05-27: pushing to main **does**
auto-deploy via a Cloud Build GitHub trigger. A session trusting the stale claim would treat a
push as reversible when it was, in effect, a production deploy — the exact asymmetry Tenet 4 says
you must not get wrong. The corrected memory entry now carries the correction date inline; that
is the pattern to follow when *you* fix a stale claim (route the fix through
`fable-self-improvement-loop`).

Second canon case, same class: during a 2026-06-12 diagnosis, the repo's committed `manifest.json`
listed a Slack app's scopes — and was stale. The *live* token, checked via `auth.test`, had the
scopes the manifest lacked. Even files inside the repo can be stale mirrors of external state;
"VERIFIED" means checked against the authoritative source, not against a file that describes it.

Re-verification is usually one command: read the CI config, run `--version`, hit the auth
endpoint, grep the actual requirements file. If one command settles it, there is no excuse for
acting on the assertion.

## What NOT to do

- **Do not start editing before orientation.** The first Write/Edit comes after the constraint
  ledger. Every incident in this library's canon that involved a wrong edit (wrong directory,
  missing dep in auto-deployed code, house-rule violation) had a bootstrap step that would have
  prevented it.
- **Do not act on a volatile memory claim without re-verifying.** See the staleness rule; the
  auto-deploy misbelief is the type specimen.
- **Do not skip a ritual the owner's rules file marks mandatory** because the task "doesn't need
  it." The 2026-02-12 lapse shows the owner notices, and the cost of the ritual is minutes.
- **Do not write into a sibling directory** because it held your template (2026-05-08 canon).
- **Do not pattern-match conventions from the wrong sibling** — nearest in kind and tree wins.
- **Do not "bootstrap" by pasting whole files into context.** Conclusions and citations, not dumps.
- **Do not treat a green Edit-tool response as ground truth for a load-bearing file.** Canon
  (2026-04-19): an edit to `requirements.txt` reported success but did not land; grep-confirm
  (`grep -n '<package>' requirements.txt`) before the dependent change ships.

## When NOT to use this skill

- You already have working context from earlier in *this* session and just need to keep it from
  decaying across a long run → `fable-long-horizon`.
- You are oriented and now sizing how much effort the task deserves → `fable-effort-calibration`.
- You are starting a vague, hard, multi-stage task and want the full gated runbook (which
  *includes* a bootstrap gate) → `fable-session-campaign`; this skill is that runbook's first gate
  expanded, not a substitute for the rest of it.
- You hit a specific past-failure smell (dedup re-firing, truncated API results) and want the
  incident details → `fable-failure-archaeology` / `fable-debugging-playbook`.
- You are deciding whether a change is safe to make at all → `fable-change-control`. Bootstrap
  feeds it (the deploy-model fact) but never replaces it.

## Provenance and maintenance

Written 2026-07-05 by Fable (claude-fable-5).

- **Doctrine** (bootstrap-before-edit, constraint ledger, nearest-sibling rule): first-person
  introspection, consistent with the Ten Tenets in `skills/fable/README.md` (Tenets 4, 5, 9).
- **Owner rules referenced** (mandatory preflight ritual, plan-mode default, keys outside git,
  lessons files): the owner's global CLAUDE.md, read 2026-07-05. Re-verify: read the current
  global rules file at session start — that *is* phase 1.
- **Incidents** (2026-02-12 skipped ritual; 2026-04-19 dep-before-import outage; 2026-05-08
  wrong-directory scratch doc; 2026-05-27 auto-deploy correction; 2026-06-12 stale manifest):
  the owner's dated memory corpus, read 2026-07-05. System names (Cloud Build, Slack, MySQL) are
  canon and may not exist in your environment; the *moves* are the portable content.
- **Convention worked example**: `skills/calls/skill.md` vs `skills/fable/*/SKILL.md` in this
  repo, verified 2026-07-05. Re-verify: `ls skills/calls/ skills/fable/*/ | head` and compare
  frontmatter — if the calls skill has since migrated to the SKILL.md convention, update the
  example (via `fable-self-improvement-loop`, not an ad-hoc edit).
- **Volatile**: file locations of memory indexes and rules files vary by machine and harness
  version (as of 2026-07-05: `~/.claude/CLAUDE.md`, harness-injected MEMORY.md). The checklist's
  `2>/dev/null` guards exist because these are expected to be absent sometimes; absence is a
  finding (negative space), not an error.
