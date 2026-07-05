---
name: fable-long-horizon
description: >
  Load when a session will be LONG or RESUMABLE: multi-hour work, 10+ significant
  actions, work spanning compactions or multiple sessions, or picking up a
  campaign mid-flight. Also load at the first symptom of decay: you catch
  yourself re-investigating something already settled, violating a constraint
  the user stated earlier, unable to say what the current plan step is, or
  noticing the context was summarized/compacted. Provides the externalized-state
  discipline (plan file, constraint ledger, gate log, handoff note), the
  re-grounding ritual, the settled-battle check, and the cold-resume protocol.
---

# fable-long-horizon — Countermeasures to Session Decay

**Tenet 9 made executable: context decays; files don't.** (Manifesto: "Externalize state relentlessly.")

## The threat model (why this exists)

Long sessions fail in three specific ways, all observed in the incident corpus:

| Decay mode | What it looks like | Root mechanism |
|---|---|---|
| **Constraint loss** | A rule the user stated at message 3 is violated at message 80 | Attention dilutes; early messages fade; compaction may drop them entirely |
| **Re-fighting settled battles** | Re-investigating a dead end that was closed weeks ago (or an hour ago) | The settlement lives only in prose you no longer see; stale beliefs in memory outlive their corrections |
| **Plan drift** | Actions stop tracing to plan steps; you're "exploring" with no gate in sight | The plan was never on disk, or was on disk and never reread |

Working assumption you must adopt: **anything not written to disk can vanish at any moment.** A context compaction is a lossy summary written by something that doesn't know which sentence was load-bearing. Your own attention over a 200-message transcript is the same kind of lossy summary. Files are the only memory that survives both.

Definition used throughout: a **significant action** is any action whose effect outlives the session — a file edit, a commit/push, a deploy, a message sent, a resource created or deleted, a config change. Reads and greps are not significant actions.

---

## Practice 1 — The externalized plan file with a gate log

Before the first significant action of any campaign, create the plan file **on disk**. In this owner's environment the convention (global workflow rules, as of 2026-07-05) is `tasks/todo.md` in the project; portable rule: any path works as long as it is inside the named project's directory and you write its path into your first status message so it's findable.

A **gate** is a plan step with an *expected observation* attached (Tenet 7: plans are prediction instruments). The **gate log** records, for each gate: what you predicted, what you observed, what surprised you, and what decision you took. A gate log entry with no surprise field filled in means you didn't look.

### Template — plan file skeleton (verbatim)

```markdown
# Campaign: <one-line goal>
Started: <date>  Owner ask (verbatim quote): "<paste the user's actual words>"

## CONSTRAINT LEDGER
<!-- Every constraint the user states gets one line. Never delete; strike through with a date if lifted. -->
| # | Constraint (user's words, condensed) | Source | Status |
|---|---|---|---|
| C1 | <e.g. "don't touch the sibling project"> | user msg, <date> | ACTIVE |

## ENVIRONMENT FACTS (dated — treat as stale after any infra change)
| Fact | Verified how | As of |
|---|---|---|
| <e.g. push to main auto-deploys via CI trigger> | <command/output> | <date> |

## PLAN (gates)
- [ ] G1: <step> → expect: <specific observation if this works>
- [ ] G2: <step> → expect: <...>
- [ ] G3: <step> → expect: <...>

## GATE LOG
<!-- Append-only. One entry per gate attempt, pass or fail. -->
### G1 — <date, time>
- Predicted: <what you expected>
- Observed: <what actually happened; paste key output>
- Surprised by: <anything unexpected, or "nothing">
- Decision: <proceed / re-plan / escalate — and why>

## DEAD ENDS (settled battles — do not re-fight)
<!-- symptom → why it's closed → evidence. Check here BEFORE investigating anything. -->
1. <approach> — <why it fails> — <evidence, date>

## HANDOFF (overwrite after every gate — this is what a cold session reads first)
- Last gate passed: G_
- Currently doing: <one line>
- Next action: <exact command or edit, copy-pasteable>
- Blocked on / open questions: <...>
- World state a resumer must verify before acting: <e.g. "branch X pushed but NOT deployed">
```

Rules of use:
- **Ledger is append-only.** A lifted constraint gets struck through with a date, never deleted — the strikethrough is itself a record that the battle was fought.
- **Gate log is append-only.** Re-running a gate gets a new entry.
- **HANDOFF is overwrite-in-place** — it describes *now*, not history. Update it after every gate and before anything risky. Cheap insurance: 30 seconds of writing buys resumability after any crash, compaction, or handoff.
- **If `fable-session-campaign` is driving the session**, its gate journal lives *inside* this skeleton: the campaign's CLAIMS table replaces the PLAN section; the CONSTRAINT LEDGER, ENVIRONMENT FACTS, DEAD ENDS, and HANDOFF sections stay. One file, one merged skeleton.

## Practice 2 — The constraint ledger

Every constraint the user states — scope limits, forbidden files, style rules, "don't deploy yet", "only the X project" — gets a numbered line in the CONSTRAINT LEDGER the moment it is uttered. Condense but keep the user's framing; don't translate into what you think they meant.

**The reread trigger is mechanical, not judgment-based: reread the full ledger immediately before any irreversible or hard-to-reverse action** (per the reversibility ladder in `fable-change-control`: push, deploy, delete, send, migrate, anything touching prod or another person's inbox). Rereading is ~10 seconds; violating a stated constraint costs the user's trust and a cleanup session.

**Worked example (2026-05-08, canon):** asked to evaluate project ELLMENT "using `passive-sonar/.plan` as a scratch doc," a session appended ELLMENT analysis into the *sibling* project's file. The owner's reaction: "omg, THIS is the project directory, we shouldn't be touching passive sonar." The constraint ("the subject project's directory is the destination; the sibling is a style reference only") existed in the conversation but nowhere the session reread before writing. One ledger line — `C1: writes go in the ELLMENT dir; passive-sonar is read-only reference` — plus the pre-write reread would have caught it.

## Practice 3 — The re-grounding ritual

Reread the plan file (ledger + plan + gate log + handoff) — the whole thing, not from memory — whenever ANY of these fire:

1. **Every 5 significant actions** since the last reread. Count them; don't estimate.
2. **On any surprise** — an observation that doesn't match a gate's prediction. (Owner's rule, verbatim intent: "If something goes sideways, STOP and re-plan immediately." Surprise means your model was wrong upstream; the plan built on that model is now suspect.)
3. **After any compaction or context summary** — assume the summary dropped something load-bearing.
4. **Before any irreversible action** (subsumes the Practice 2 reread).

While rereading, run this three-question check and write the answers into the gate log if any answer is "no":
- Does my *next intended action* trace to an unchecked gate? (If not: I'm drifting — re-plan or add the gate explicitly.)
- Am I currently compliant with every ACTIVE ledger line?
- Is there a dead-end entry that matches what I'm about to try?

**Worked example (2026-02-12, canon):** the owner's environment mandates a preflight ritual (a semantic search step) at the start of every non-trivial task. A session skipped it for an *entire implementation session* (vesting panel + Slack alerts) and the owner had to call it out. The lesson generalizes: **rituals held in working memory decay exactly like constraints do.** The fix is structural — mandated rituals become gate 0 in the plan file with a checkbox, so the plan reread re-surfaces them. Discipline you can't checkbox is discipline you will eventually skip.

## Practice 4 — The settled-battle check

**Before investigating any symptom, hypothesis, or "why doesn't X work" — grep first, think second.** Search these, in order:

1. The session's own plan file DEAD ENDS section and gate log.
2. `fable-failure-archaeology` (the library's chronicle of settled battles: symptom → root cause → evidence → status).
3. Any project memory / lessons files the environment provides (in this owner's setup: the project's `tasks/lessons.md` and the auto-memory corpus).

```bash
# Portable form — adjust roots to where the library and campaign files live:
grep -ril "<symptom keyword>" skills/fable/fable-failure-archaeology/ tasks/ 2>/dev/null
```

A hit doesn't end thought — it ends *re-derivation*. Read the entry, confirm its evidence still applies (check the date against known infra changes), and either proceed on the settled answer or explicitly reopen the battle with new evidence written into the gate log. Reopening silently is how the same hour gets burned twice.

**Canon examples of battles that exist precisely so you don't re-fight them** (details and evidence live in `fable-failure-archaeology`): Redis `get()`-based dedup fails open (2026-06-12 duplicate posts — use an atomic fail-closed lock); Slack conversations APIs silently truncate at ~28 messages without cursor pagination; broad `except Exception` around LLM calls masking an AttributeError typo as a "model regression" (2026-04-21). Each of these was expensive to settle once. Free the second time — *if you grep*.

## Practice 5 — Compaction survival

Assume a compaction can happen between any two of your messages, and that the summary will preserve vibes, not specifics. Countermeasures:

- **The HANDOFF section is written proactively, not reactively** — after every gate, before every risky action. Never let "I'll write it up when I finish this step" stand; the step is exactly when the compaction hits.
- **Specifics that must survive verbatim go in files, not prose**: exact commands, exact error strings, exact IDs/channel names/branch names, the verbatim user ask. A summary will paraphrase "the specific gcloud command with six flags" into "ran the deploy command" — and the flags were the point.
- **After a detected compaction, treat yourself as a cold resumer**: run the cold resume protocol (Practice 6) against your own files before taking the next significant action. Do not trust the summary's account of world state over the HANDOFF section's.
- **Environment facts get date-stamps in the plan file** (see the ENVIRONMENT FACTS table). A fact without a date can't be judged stale.

## Practice 6 — Cold resume protocol

How a brand-new session (or you, post-compaction) picks up mid-campaign **from the files alone**:

1. **Read HANDOFF first.** It names the last gate passed, the next action, and the world-state claims that need verification.
2. **Read the CONSTRAINT LEDGER in full.** You are now bound by every ACTIVE line, even though you never heard the user say them.
3. **Read the GATE LOG from the bottom up** until the story makes sense — last few entries usually suffice; surprises noted there are your inherited open questions.
4. **Verify, don't trust, the world state**: run the cheapest command that confirms the HANDOFF's claims (branch exists? service responding? file present?). The previous session may have died *between* acting and recording. Expected observation first, then run — if reality disagrees with HANDOFF, that's a surprise; log it and re-plan before proceeding.
5. **Read DEAD ENDS and skim `fable-failure-archaeology`** for the systems involved, so inherited settled battles stay settled.
6. **Resume at the next unchecked gate.** Your first gate log entry should be titled `RESUME — <date>` and record what step 4 found.

If the files don't exist or are too thin to resume from, that is a `fable-context-bootstrap` problem (rebuild context from the repo and environment) — and evidence the previous session failed Practice 5. Note it in lessons per `fable-self-improvement-loop`.

**Positive canon example (2026-05-27, workspace-audit pipeline):** an infra campaign with a long resumption horizon (open follow-ups spanning weeks) was kept resumable by a single memory file containing exactly the right sections — live config with verbatim commands, a numbered "Open follow-ups (do these in order when picking back up)" list, and an eight-item "Dead ends (don't repeat)" list (wrong admin toggle, allowlisted `bq` subcommands, wrong partition column, and more). A cold session can resume that campaign without a single question to the owner. That file is the standard this skill's templates aim at.

---

## Anti-pattern story: re-fighting the auto-deploy question

The canonical stale-environment-model failure, reconstructed from the memory corpus:

- **2026-04-19 (hackgpt):** a push to main auto-deployed via a Cloud Build trigger and shipped a missing-dependency import straight to prod — full CrashLoopBackOff outage. Auto-deploy on push was thus *demonstrated, expensively*, for that system.
- **Meanwhile, a memory entry for the sibling system (hack-mono) said the opposite** — that no auto-deploy existed and deploys were manual. That belief was wrong, and it stood until corrected.
- **2026-05-27:** the belief was finally corrected in the owner's memory: pushing hack-mono to `main` DOES auto-deploy via a Cloud Build GitHub trigger; the manual path is only a fallback. The correction had to be written with an explicit annotation ("earlier memory wrongly said no auto-deploy") because the stale version kept getting re-loaded and re-believed.

Why this is a long-horizon failure and not just a trivia error: **"does pushing deploy?" gates the risk class of every push.** A session believing "no auto-deploy" treats `git push` as reversible scratch work — and ships broken WIP to production. A session that missed the correction re-fights the settled question, or worse, "wins" it with the stale answer. Three practices each independently prevent this:
- The **ENVIRONMENT FACTS table** forces the deploy model to be written down *with a date and a verification method* — a dated fact invites re-verification; a floating belief doesn't.
- The **settled-battle check** surfaces the correction before you act on the old belief.
- The **ledger reread before irreversible actions** — `git push` on a repo whose deploy model you haven't verified this session *is* an irreversible action, and the reread is where "wait, when did I last confirm this?" fires.

Portable rule: **any belief about what an action triggers (deploys, notifications, billing, cascades) is stale until dated and verified in this campaign's plan file.** Verify with evidence, not memory — e.g. look for the CI config and its trigger, don't recall it.

---

## When NOT to use this skill

- **Short, single-sitting tasks** (a handful of significant actions, no resume risk) — the full apparatus is overhead; let `fable-effort-calibration` size what's worth externalizing (often just a 3-line plan in your head plus the constraint reread).
- **Starting cold with NO prior campaign files** — that's `fable-context-bootstrap` (recreate working context from scratch); come back here once a plan file exists.
- **Deciding what the gates should BE** — decomposition quality is `fable-decomposition`; the end-to-end gated runbook for a vague hard task is `fable-session-campaign` (this skill supplies its persistence layer).
- **Recording a lesson after a correction** — `fable-self-improvement-loop` owns correction → library update; this skill only tells you to *check* lessons, not how to write them.
- **The settled-battle archive itself** — entries live in `fable-failure-archaeology`; this skill mandates consulting it, not maintaining it.
- **Judging whether an action is irreversible** — the reversibility ladder is `fable-change-control`; this skill hooks its reread ritual onto that ladder, never replaces it.

## Provenance and maintenance

Written 2026-07-05 by Fable (claude-fable-5). Sources per claim class:

- **Decay modes and the three named gaps**: the project owner's statement of observed gaps (2026-07-05), recorded in this library's manifesto (`skills/fable/README.md`) — gap 2 is this skill's charter.
- **Plan-file and stop-and-replan conventions** (`tasks/todo.md`, `tasks/lessons.md`, "STOP and re-plan immediately"): the owner's global workflow rules, as of 2026-07-05. Re-verify: check the "Workflow Rules" and "Task Management" sections of the owner's global CLAUDE.md still name these files.
- **Incidents** (2026-02-12 preflight lapse; 2026-04-19 missing-dep outage; 2026-05-08 wrong-project scratch doc; 2026-05-27 auto-deploy correction and workspace-audit handoff exemplar; 2026-06-12 Redis fail-open; 2026-04-21 masked AttributeError and Slack truncation): the owner's dated memory corpus, spot-verified against the individual memory files on 2026-07-05. Full symptom→root-cause entries belong to `fable-failure-archaeology`; if details here conflict with that chronicle, the chronicle wins.
- **The compaction threat model and the "5 significant actions" reread cadence**: first-person introspection by claude-fable-5 about how attention over long transcripts actually degrades. The cadence value 5 is a **calibrated default, not a measured optimum** — tighten it if a constraint violation slips through, per `fable-self-improvement-loop`.
- **hack-mono auto-deploy fact** (as of 2026-07-05: push to `main` auto-deploys via Cloud Build GitHub trigger). Re-verify before relying on it: confirm `cloudbuild.yaml` exists in that repo and a GitHub trigger references it (`gcloud builds triggers list` in that project), or just ask — it is exactly the kind of fact this skill says goes stale.
- **Corrections (2026-07-05, library review):** dropped unverifiable duration claims (the workspace-audit example's recorded work spans ~two days — "multi-week" described the follow-up horizon, not the campaign; "persisted for weeks" for the auto-deploy misbelief is not datable from the corpus). Practice 1 now states how `fable-session-campaign`'s gate journal merges into this skeleton instead of competing for the same file.
