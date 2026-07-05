---
name: fable-debugging-playbook
description: >
  Load this when you are handed a bug in a running system: "feature X stopped working",
  "output is thin/empty/duplicated", "the cron didn't fire", "it works locally but not in prod",
  a regression report with no obvious diff, a crash loop after deploy, or any symptom where the
  cause is not yet known. Also load it BEFORE blaming a model, a prompt, an API, or "flakiness" —
  the trap canon below covers the failure classes that masquerade as those. Do NOT load it for
  designing experiments in the abstract (fable-adversarial-toolkit) or for checking whether a bug
  was already solved (fable-failure-archaeology).
---

# Fable Debugging Playbook

Symptom → triage for real systems. This is how I actually debug: a fixed loop, then a canon of
traps that real production incidents (2026-02 through 2026-06) burned into the process. Every
trap below cost real hours or a real outage; each entry gives you the discriminating check that
would have found it in minutes.

**Jargon, defined once:**
- **Discriminating check** — an observation whose outcome differs depending on which hypothesis is true. A check that passes under every hypothesis teaches you nothing.
- **Fails open / fails closed** — on an internal error, a fails-open guard reports "safe to proceed"; a fails-closed guard reports "stop". Guards in front of side effects must fail closed.
- **Root cause** — the earliest fact in the causal chain that, if changed, prevents the whole symptom class, not just this instance.

## The loop

Run these five steps in order. Skipping a step is how debugging sessions go sideways.

1. **Reproduce.** Get the symptom to happen on demand, or get the artifact that proves it happened (log line, duplicate message, empty payload). No reproduction → you cannot prove any fix. If you truly can't reproduce, your deliverable changes: instrument so the *next* occurrence is diagnosable, and say so.
2. **Isolate.** Cut the system in half repeatedly: which layer still sees correct data, which layer first sees wrong data? Run each stage of the pipeline independently with the real inputs. The bug lives at the first boundary where good-in becomes bad-out.
3. **Discriminate.** Hold 2+ hypotheses simultaneously (never one). Pick the next check by which hypothesis it can *eliminate*, and predict the outcome before you run it. Full recipes: `fable-adversarial-toolkit`. The trap canon below is a pre-built hypothesis list — check it before inventing exotic theories.
4. **Fix the root cause.** No temporary patches, no papering over (e.g., don't hide a missing dependency behind a lazy import — fix the dependency and let boot fail fast). If the same mechanism exists at other call sites, fix the *class*: grep for siblings.
5. **Prove with the reproduction.** Re-run the exact reproduction from step 1 and show the symptom gone. "The code looks right now" is not proof — see `fable-verification-and-evidence`. Any change you ship goes through `fable-change-control`.

**Worked example of steps 2–3 done right (2026-06-12, Slack bot Excel attachments):** the report was "the bot still can't read xlsx files" after two same-day fixes — an invitation to start rewriting code. Instead, four checks, each eliminating a hypothesis before any edit: (1) queried the live token's OAuth scopes — `files:read` present, so not permissions (and this exposed that the repo's manifest file was stale: verify against the *live* system, not the repo's description of it); (2) ran the exact download/extract gateway code inside the prod pod against the real file — worked, so the fetch pipeline was not broken; (3) checked the prod SDK version (0.109.1) vs. local (0.75.0) — so local tests of new-SDK code were meaningless, test in the pod; (4) located the real runtime env (PID 1's environment, not the exec shell's). Result: the fault was the lossy text-dump handoff to the model, and the fix was small and obvious. Diagnosis cost: minutes per check. Not doing them: another day of fixing the wrong layer.

## The trap canon

Six failure classes that recur in real systems and disguise themselves as something else.
Format per trap: Symptom / Mechanism / Discriminating check / Fix pattern / Story.

### (a) Fails-open reads guarding side effects

- **Symptom:** A side effect fires twice — duplicate posts, double emails, repeated charges — intermittently, with no code change.
- **Mechanism:** The "already done?" check is a read (cache get, DB lookup) whose error path returns the same value as "not found". A transient infrastructure blip makes "done" look like "not done", and the side effect re-fires. The guard fails open.
- **Discriminating check:** Read the guard's error handling. Does `except`/`catch` return the "proceed" value? Then it fails open — the bug needs no repro beyond one infra blip. Confirm by checking infra health at the incident timestamp (a blip there + fails-open guard = complete mechanism). Rule out the alternative (key actually missing) with store metrics, e.g. eviction counters.
- **Fix pattern:** Gate side effects with an **atomic, fail-closed claim**: in Redis, `SET key NX EX <ttl>` (claim-before-act). Claim taken → skip. Store error → exception → fail closed, retry later. Never gate a side effect on `get(key) is None`.
- **Story (2026-06-12; canonical record AR-01 in `fable-failure-archaeology`):** hackgpt's podcast pipeline reposted already-sent episodes to Slack. `RedisToolkit.get()` wrapped everything in `except Exception: return None`, so a Redis blip made the sent-marker read as absent — the key existed the whole time (`evicted_keys=0`). Fix: `acquire_lock` (SET NX EX, which raises on Redis errors) claimed before posting. See also trap (f) — the same incident had a second multiplier.

### (b) Broad exception swallowing masquerading as a behavior regression

- **Symptom:** Output got "thin", "shallow", "lost depth", or reverted to placeholder/fallback content. Everyone's first theory is "the model/prompt/upstream service regressed."
- **Mechanism:** A broad `except Exception` around the call (added, reasonably, for rate limits and transient failures) also swallows programming errors — an `AttributeError` from a typo'd config attribute, a `TypeError` — and the caller silently returns its fallback. No traceback lands in logs because the handler logs a generic message without `exc_info`.
- **Discriminating check:** Before touching any prompt or blaming any model: (1) grep the code path for broad except sites (`rg 'except Exception' <path>`); (2) run the call path once end-to-end and inspect the raw response / whether the fallback branch executed. A code typo produces deterministic 100% fallback; a genuine model regression produces degraded-but-real output. Those are distinguishable in one run.
- **Fix pattern:** Fix the typo at *every* call site (grep for the pattern class, not the one instance). Then make every broad handler around a critical call log `exc_info=True` so the next swallowed error is visible. Do not narrow/remove safety handlers wholesale — that's a separate, deliberate change.
- **Story (2026-04-21):** Two "regressions" in hackgpt — IC memos losing depth, calendar briefs reduced to bare titles — were one root cause: `self.config.MODEL_SONNET` at 9 call sites when the real attribute was `SONNET_MODEL`. The `AttributeError` was swallowed as "synthesis failed", callers returned fallback sections, and it looked exactly like a prompt-quality problem. Grep found it; prompt tuning would have found nothing.

### (c) Silent truncation: you are reasoning over partial data

- **Symptom:** Summaries/analyses miss things that are plainly in the source; long inputs behave worse than short ones; downstream logic "randomly" misses old items.
- **Mechanism:** An API's default page size is small and the response doesn't error — it just omits. Slack's `conversations.replies`/`conversations.history` return roughly 28 messages by default and require cursor pagination; without `limit=` and a cursor loop, everything past page one silently vanishes. Downstream slices (`messages[:20]`) then compound the loss.
- **Discriminating check:** Confirm you hold ALL the data before reasoning about any of it. Compare `len(fetched)` against an independent count (e.g. Slack's `thread_message_count`, a DB `COUNT(*)`, the UI). Check the response for a pagination signal (`has_more`, `next_cursor`, `nextPageToken`). If counts disagree or a cursor is present and unfollowed, stop — fix the fetch first.
- **Fix pattern:** Pass the max page size (`limit=200` for Slack) AND loop on `has_more` + `response_metadata.next_cursor` until exhausted. Then audit every downstream `[:N]` slice. Treat "I have the complete dataset" as a hypothesis to verify, never an assumption — this is the negative-space tenet applied to data.
- **Story (2026-04-21):** hackgpt IC memos went shallow because long diligence threads were truncated at ~28 messages by the API default, then truncated again by `messages[:20]` in the summarizer. The model was summarizing a stub and being blamed for it.

### (d) Flaky server-side filters

- **Symptom:** A query that "should" return data returns empty — but only most of the time. Retries sometimes work. Scheduled jobs quietly no-op.
- **Mechanism:** A server-side filter parameter is unreliable: Slack's `conversations.history` with `oldest` set returned 0 messages on ~80% of calls even with in-range messages present (confirmed 2026-04/05 on a real channel; 4-of-5 identical calls empty). No error is raised — "no results" is a valid-looking response, so nothing alarms.
- **Discriminating check:** Run the same call **with and without the filter parameter, several times each**. Probabilistic emptiness with the filter + reliable data without it = the filter is the bug. One run of each is not enough — flakiness needs repetition to show its rate.
- **Fix pattern:** Prefer client-side filtering when a server-side filter behaves probabilistically: fetch unfiltered (paginated, newest-first where the API allows), and break out client-side once items pass the cutoff (`ts < cutoff` short-circuits cleanly on newest-first ordering). Costs a little bandwidth, buys determinism.
- **Story (2026-04-27 and 2026-05-04):** an IC-memo cron silently skipped posting two Mondays running — `oldest` returned 0 messages, the code logged "no roll call message found", and no metric flagged it, because an empty result is not an error.

### (e) Wrong environment model: the system you imagine is not the system running

Three sub-traps, one lesson: **verify your beliefs about the environment against the live environment, not against memory, docs, or the repo.** Stale environment models are a canon failure class of their own.

**(e1) Config load order clobbers your overrides**
- **Symptom:** You set an env var in the shell (`FOO=bar python script.py`) and the program behaves as if you hadn't.
- **Mechanism:** A config module runs dotenv loading with override-shell semantics (`load_dotenv(override=True)`) at *import time*, and nearly everything imports it transitively — so `.env` silently wins over your shell.
- **Discriminating check:** Print the config value from *inside* the process, after imports, and compare with what you set. Grep for `load_dotenv` and check the `override` flag and where in the import graph it fires.
- **Fix pattern:** For one-offs against such a codebase: import the config module first, then mutate its attributes in code (and `os.environ.pop` anything downstream libraries read directly). Beware helper entrypoints that re-run env loading and resurrect popped vars.
- **Story (2026-05-13):** in hack-mono, shell overrides of `ENABLED_PROVIDERS` and `GOOGLE_APPLICATION_CREDENTIALS` were silently replaced by `.env` values via `load_dotenv(override=True)` in `src/configs/config.py`, sending a debugging session down an auth rabbit hole (`invalid_grant: Invalid JWT Signature`) that was really a config-precedence problem.

**(e2) Stale deploy beliefs**
- **Symptom:** You act on "how deployment works here" from memory and either miss that your push already shipped, or hand-deploy something that would have shipped itself.
- **Mechanism:** Deployment topology changes; notes and recollections don't. Both error directions are live: believing auto-deploy exists when it doesn't (fix never ships) and believing it doesn't when it does (untested code ships the moment you push).
- **Discriminating check:** Before pushing or declaring "deployed", read the actual trigger config (CI config files, Cloud Build / GitHub Actions triggers) and check what the running workload is actually running (image tag, revision, recent rollout events). One minute of looking beats any memory.
- **Fix pattern:** Treat deployment behavior as a fact to re-verify per session, and correct the written record the moment reality disagrees (see `fable-self-improvement-loop`).
- **Story (corrected 2026-05-27):** the owner's notes on hack-mono said "no auto-deploy" — wrong; pushing to `main` auto-deploys via a Cloud Build GitHub trigger. Every session that trusted the stale note was one push away from shipping unreviewed code while believing it was staging a manual deploy. Related (2026-04-19): an edit to `requirements.txt` that silently didn't land + a top-level import + auto-deploy = prod-wide CrashLoopBackOff (`ImportError`). Grep-confirm the dep line exists in the file before the import lands in auto-deployed code; a tool reporting "edit succeeded" is not proof.

**(e3) Env-var *presence* has side effects**
- **Symptom:** A service breaks or changes mode after a secrets/env sync that "only added variables no one reads."
- **Mechanism:** Some frameworks change behavior on the mere presence of variables. Slack Bolt (Python): if `SLACK_CLIENT_ID` + `SLACK_CLIENT_SECRET` are in the env, Bolt auto-enables OAuth-install mode with a *file-based* InstallationStore (writes to `./data/`) and **ignores `SLACK_BOT_TOKEN`** — incompatible with a read-only root filesystem and with multi-replica pods. Symptom presents as slash-command timeouts.
- **Discriminating check:** Read framework startup logs — Bolt announces exactly this ("Bolt has enabled the file-based InstallationStore… token will be ignored"). Generally: diff the full env of the working vs. broken deployment, including variables you believe are inert.
- **Fix pattern:** For single-workspace bots, exclude client-ID/secret from what gets mounted into the pod (bulk secret-sync mechanisms are the usual leak path). Ship only the token + signing secret. Treat "which env vars exist" as part of the interface, not just "which are read."
- **Story (2026-04, hackgpt hardening):** a bulk secret sync exposed the OAuth vars; the fix was an exclude-regex in the secret-mount generator so the values stay in the secret manager but never reach the pod.

### (f) Replica multiplicity: your job runs once per replica

- **Symptom:** Scheduled work happens N times; N mysteriously equals the deployment's replica count. Per-item dedup "mostly" contains it, until two runs race.
- **Mechanism:** In-process schedulers (APScheduler, node-cron, `@Scheduled`) start in *every* replica of a horizontally scaled service. "The cron" is actually N crons. Per-item idempotency checks can still race when two whole runs start simultaneously.
- **Discriminating check:** How many replicas does the deployment run? If >1 and the scheduler is in-process, multiplicity is a fact, not a hypothesis. Look for the same job's start log line at the same timestamp from different pod names.
- **Fix pattern:** Wrap the *entire run* in a cross-replica run-lock (the same fail-closed SET NX EX claim from trap (a), keyed per job + window) — item-level locks alone are insufficient because they don't stop two runs from interleaving.
- **Story (2026-06-12):** the podcast duplicate-posts incident was traps (a) + (f) compounded: fails-open per-item dedup AND the cron firing in every k8s replica. The fix was both a per-item `acquire_lock` and a `cron_run_lock:{id}` around each scheduled run. One mechanism must explain all observations — here it took two mechanisms, and stopping at the first would have left the second live.

## First 15 minutes with any new bug

Copy-paste this as your working checklist:

```
[ ] 1. State the symptom in one sentence, with the exact artifact (log line, message ID,
       screenshot). No artifact → get one before theorizing.
[ ] 2. Check the archaeology: has this been fought before? (fable-failure-archaeology,
       project lessons files, git log of the affected file.)
[ ] 3. When did it last work, and what changed between then and now? (deploys, config,
       secrets syncs, dependency bumps, replica count — not just code diffs.)
[ ] 4. Reproduce it, or timestamp it precisely enough to correlate with infra events.
[ ] 5. Verify your environment model against the LIVE system (trap e): what's actually
       deployed, actual env of the running process, actual dependency versions,
       actual auto-deploy behavior. Never from memory.
[ ] 6. Verify data completeness (trap c): counts vs. independent totals; any pagination
       cursor left unfollowed; any [:N] slices downstream.
[ ] 7. Grep the failure path for broad except/catch sites (trap b) and read what their
       error branches return (trap a: does any guard fail open?).
[ ] 8. If scheduled/background work is involved: replica count × in-process scheduler
       (trap f)? Any server-side filter that could be flaky (trap d)?
[ ] 9. Write down 2+ live hypotheses and the ONE check that best discriminates them.
       Predict the outcome before running it (fable-adversarial-toolkit).
[ ] 10. Only now consider editing code — and only at the confirmed root cause.
```

If step 9's check surprises you, that surprise is information: your system model is wrong somewhere upstream. Stop and re-plan; do not push through (Tenet 7).

## When NOT to use this skill

| Situation | Use instead |
|---|---|
| Designing a discriminating experiment or refutation in general (no live bug) | `fable-adversarial-toolkit` |
| Checking whether this exact battle was already fought and settled | `fable-failure-archaeology` |
| You've found the root cause and are deciding how to ship the fix safely | `fable-change-control` |
| Deciding whether the bug even deserves deep investigation | `fable-effort-calibration` |
| The "bug" is an ambiguous report and you're not sure what's being asked | `fable-ambiguity-and-judgment` |
| Proving a fix works / what counts as evidence | `fable-verification-and-evidence` |
| Cold-starting in an unfamiliar codebase before any debugging | `fable-context-bootstrap` |

After the bug is fixed: the correction goes into the library via `fable-self-improvement-loop` — a trap survived without a canon entry is a trap scheduled to recur.

## Provenance and maintenance

As of 2026-07-05. Written by Fable (claude-fable-5); doctrine per `../README.md` (this repo, `skills/fable/README.md`).

- **The loop and the discriminating-check discipline:** first-person introspection, consistent with Tenets 2, 5, 6, 7 in the manifesto.
- **Canonical incident records** are the AR entries in `fable-failure-archaeology` (trap (a)/(f) = AR-01, (b) = AR-02, (c) = AR-03, (d) = AR-04, (e1) = AR-05, (e2) = AR-15/AR-06, (e3) = AR-07); on any conflict of detail, that chronicle wins. (Citation added 2026-07-05, library review.)
- **Trap (a):** owner memory of the 2026-06-12 Redis dedup incident (hackgpt podcast duplicate posts; `RedisToolkit.get()` fails open, `acquire_lock` fails closed).
- **Trap (b):** owner memory of the 2026-04-21 `MODEL_SONNET` vs `SONNET_MODEL` AttributeError incident (9 call sites, swallowed by broad except).
- **Trap (c):** owner memory of the 2026-04-21 Slack pagination truncation (same incident cluster as (b)). The "~28 messages" default is empirical, not documented — re-verify: call `conversations.replies` on a long thread with no `limit` and count the result.
- **Trap (d):** owner memory of the `oldest`-param flake (reproduced 4-of-5 empty on a real channel; cron no-ops 2026-04-27, 2026-05-04). Slack may fix this — re-verify with 5 repeated calls with/without `oldest` before relying on it either way.
- **Trap (e1):** owner memory, observed 2026-05-13 in hack-mono (`load_dotenv(override=True)` at import in `src/configs/config.py`). Re-verify in that repo: `rg -n 'load_dotenv' src/configs/config.py`.
- **Trap (e2):** owner memory correction dated 2026-05-27 (hack-mono auto-deploys from `main` via Cloud Build trigger) plus the 2026-04-19 requirements.txt/ImportError outage. Deploy topology drifts — always re-verify per session against trigger config + running image tag.
- **Trap (e3):** owner memory of the Bolt OAuth-install trigger (Bolt logs the mode switch at startup; fix shipped as an exclude-regex in hackgpt's secret-mount generator). Bolt behavior may change across versions — re-verify against Bolt's startup log lines.
- **Trap (f):** same 2026-06-12 incident as (a); cross-replica `cron_run_lock:{id}` landed in hackgpt's scheduler.
- **Positive worked example:** owner memory of the 2026-06-12 Excel attachment diagnosis (scopes via `auth.test`, in-pod gateway run, SDK 0.109.1 vs 0.75.0, token in PID 1 env).

All incident details were re-read from the owner's dated memory corpus on 2026-07-05 before embedding here. If a trap's fix pattern stops matching the named codebase, update this file through `fable-self-improvement-loop` — do not fork the canon.
