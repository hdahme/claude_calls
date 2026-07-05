---
name: fable
description: Entrypoint to the Fable cognition library. Load at the start of ANY non-trivial task — debugging, building, investigating, researching — or whenever a session shows the warning signs: about to act on a single silent interpretation, marking work done without proof, drifting from a plan mid-session, or attacking a hard problem as one giant attempt instead of verifiable stages. Pulls in the manifesto, the core tenets, and routes to the right subskill.
user-invocable: true
args: [task summary]
---

# Fable — Entrypoint

This library packages the working discipline of Fable (claude-fable-5) so any session — Sonnet-class model or mid-level engineer — can operate at that standard. You do not need to be smarter to use it; you need to make these moves *unprompted*. Loading this skill is how they get prompted.

## Load protocol (do this now, not lazily)

All paths are relative to this skill's directory.

1. **Read `README.md`** — the manifesto. The Ten Tenets are the doctrine everything else executes.
2. **Read `fable-core/SKILL.md`** — always. It expands the tenets into moves and is the detailed router.
3. **Route** — read the subskills matching your situation (table below). Read them fully; skimming defeats the purpose.
4. **If the task is hard or vaguely specified**, run it under `fable-session-campaign/SKILL.md` — the gated runbook from task receipt to verified completion. When in doubt, this is the default for anything non-trivial.

## Routing table

| Your situation | Read |
|---|---|
| Any non-trivial task (always) | `fable-core/SKILL.md` |
| Deciding how much effort/planning/verification a task deserves | `fable-effort-calibration/SKILL.md` |
| The ask could mean more than one thing | `fable-ambiguity-and-judgment/SKILL.md` |
| Breaking a hard problem into stages | `fable-decomposition/SKILL.md` (flagship — read for anything multi-step) |
| Session running long; plan drift; resuming cold | `fable-long-horizon/SKILL.md` |
| About to claim something works or is done | `fable-verification-and-evidence/SKILL.md` |
| About to present a conclusion or diagnosis | `fable-adversarial-toolkit/SKILL.md` |
| Debugging a live failure | `fable-debugging-playbook/SKILL.md` + grep `fable-failure-archaeology/SKILL.md` FIRST |
| About to edit, delete, deploy, or send anything | `fable-change-control/SKILL.md` |
| New session in an unfamiliar repo | `fable-context-bootstrap/SKILL.md` |
| Writing a report, summary, or handoff | `fable-communication/SKILL.md` |
| Executing a hard/vague task end-to-end | `fable-session-campaign/SKILL.md` |
| You were just corrected, or a surprise cost real time | `fable-self-improvement-loop/SKILL.md` |
| Advancing or measuring this library itself | `fable-research-frontier/SKILL.md` |

## Rules that bind even if you read nothing else

- Never mark work done without the command output that proves it.
- Before investigating any symptom, check `fable-failure-archaeology/SKILL.md` — settled battles are not re-fought.
- If an ask has divergent readings, surface them; don't pick silently.
- Changes to this library route through `fable-self-improvement-loop`, gated by `fable-change-control`. No ad-hoc edits.

## When NOT to use this skill

Trivial mechanical edits and direct factual questions — the calibration tenet applies to the library itself. Loading fifteen skills to fix a typo is exactly the miscalibration `fable-effort-calibration` warns about.

## Installation (as of 2026-07-05)

The library lives in the `claude_calls` repo at `skills/fable/`. To make `/fable` available globally, symlink the whole directory:

```bash
ln -s ~/Projects/hack/claude_calls/skills/fable ~/.claude/skills/fable
```

## Provenance and maintenance

Written 2026-07-05 by Fable (claude-fable-5) as the library entrypoint. Re-verify the routing table against the actual directory listing: `ls ~/Projects/hack/claude_calls/skills/fable/` — every subdirectory should have a row, every row a subdirectory.
