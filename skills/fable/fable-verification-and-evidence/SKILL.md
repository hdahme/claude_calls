---
name: fable-verification-and-evidence
description: Load this BEFORE claiming anything is done, fixed, deployed, or working — and BEFORE starting a task whose success is not yet checkable. Triggers: you are about to write "done", "fixed", "should work", or a completion report; the task arrived vague ("fix the bug", "make it faster", "clean this up") with no test that proves success; you are tempted to trust an edit-tool success message, a doc, a memory file, or code-reading as proof; you are about to measure something without having stated the pass/fail threshold; you need a known-good reference to compare against; or you want to scan a codebase for silent-failure patterns (fails-open exception handlers, truncating paginated API calls, missing deps). Defines the evidence hierarchy, the verifiable-goal transform, the done-report template, threshold-before-measurement, the golden inventory, and ships tested scripts/.
---

# Verification and Evidence

The single behavior this skill installs: **you may not claim a thing is true unless you can name the observation that would have been different if it were false — and for "done" claims, that observation must be pasted output from a command you ran.** Everything else here is machinery for making that cheap.

This is Tenets 5, 7, and 8 of the manifesto (`skills/fable/README.md`) made executable: read the negative space, treat plans as prediction instruments, schedule your skepticism.

## 1. The evidence hierarchy

Every claim you make sits on exactly one of these tiers. Know which, and say which.

| Tier | Evidence | What it proves | Canonical failure when you skip it |
|---|---|---|---|
| **1** | **Fresh command output, pasted verbatim**, with the command that produced it | The behavior, now, in this environment | — (this is the bar) |
| **2** | **Logs / metrics from the running system**, timestamped and quoted | The behavior, recently, in prod — but at the granularity someone chose to log | Silent AttributeError (2026-04-21): handlers logged "synthesis failed" *without* the traceback, so logs existed and still hid the root cause |
| **3** | **Reading the code** (cite file and line, quote the lines) | What the code *says*, not what it *does* under real config, data, versions | Stale `manifest.json` (2026-06-12): repo file listed 2 bot events; live `auth.test` showed `files:read` present. The file was tier-3 and wrong; the API call was tier-1 and right |
| **4** | **Plausibility, memory, docs, "it should"** | Nothing. This is a hypothesis, not evidence | Auto-deploy misbelief (corrected 2026-05-27): memory said "no auto-deploy" for a repo where push-to-main *does* auto-deploy via Cloud Build. Acting on it would have shipped an unreviewed prod change |

Operating rules:

- **A tool's success message is tier 4, not tier 1.** On 2026-04-19 an Edit to `requirements.txt` "reported success" but the `google-cloud-kms` line never landed; the top-level import auto-deployed and both replica sets CrashLoopBackOff'd — full prod outage. The tier-1 version costs three seconds: `grep -n 'google-cloud-kms' requirements.txt` and paste the line.
- **Absence of errors is not presence of success.** Fails-open code (Section 6, script 1) converts errors into normal-looking return values. Verify the *positive* behavior happened, not that nothing complained.
- **Environment identity is part of the claim.** "Works" where? On 2026-06-12 the prod pod ran anthropic SDK 0.109.1 while the local env had 0.75.0 — tier-1 output from the wrong environment is tier-4 for the environment that matters. Name the host/pod/branch/version in the evidence.
- **Downgrade honestly.** In reports, anything at tier 3–4 is labeled "assumed" or "unverified", never blended into verified findings (house style: `fable-communication`).

## 2. Transform the task into a verifiable goal — BEFORE working

A task you cannot mechanically check is not yet a task; it is a wish. Do the transform first, at tier 1 wherever possible:

| Arrives as | Transform to |
|---|---|
| "Fix the bug" | Write a test (or a repro command) that fails, then make it pass |
| "Add validation" | Write tests for the invalid inputs, then make them pass |
| "Refactor X" | Capture passing test output before; show identical output after |
| "Make it faster" | State current measurement, state target threshold, then optimize |
| "Clean up the errors in logs" | Count them (`grep -c`), state target count, re-count after |
| "Integrate with Y" | One end-to-end command that exercises the real Y and prints proof |

For multi-step work, write the plan with an explicit verify per step, each verify being a runnable check with a predicted result:

```
1. [Step] → verify: [command] → expect: [observation]
2. [Step] → verify: [command] → expect: [observation]
```

A surprise at any verify gate means your model was wrong upstream: stop and re-plan, don't push through (manifesto Tenet 7). Weak criteria ("make it work") force constant clarification; strong criteria let you loop independently.

## 3. Threshold before measurement

**State the acceptance threshold before you run the measurement.** Written down, in the plan or the report draft — not in your head.

Why: once numbers are on screen, any threshold you pick afterward will be suspiciously close to what you got. That is goalpost drift, and it is invisible from the inside. The threshold is a *prediction*; the measurement then either passes or fails it, and a fail is information, not an invitation to renegotiate.

Template (fill the left column before running anything):

```
Metric:      thread messages retrieved
Threshold:   == thread_message_count reported by Slack (100% of thread)
Measured:    <run, then paste>
Verdict:     PASS / FAIL
```

If you genuinely cannot set a threshold (no baseline exists), say so, measure once to *establish* the baseline, and set the threshold for the next measurement. What you may not do is measure first and declare the result acceptable in the same breath.

Worked example from canon: the truncation bug (2026-04-21, AR-03 in `fable-failure-archaeology`) survived as long as it did because "get the whole thread" had no stated threshold — nobody compared messages-retrieved against thread length, so ~28-message pages looked like success. The documented countermeasure includes passing `thread_message_count` downstream so depth can be checked against a threshold (recorded as how-to-apply guidance in the incident memory, not as a verified component of the landed fix).

## 4. Done means proven — the done-report

**Never mark a task complete without the command that proves it, and paste that output in the report.** Not a description of the output. The output.

```markdown
## Done: <task>
**Claim:** <one sentence, e.g. "duplicate posts can no longer fire on a Redis blip">
**Proof (tier 1):**
    $ <exact command>
    <verbatim output>
**Environment:** <host/pod/branch/versions the command ran in>
**Threshold stated beforehand:** <yes — quote it / no — say why>
**Behavior diff (when relevant):**
    before (main):  <command → output>
    after (change): <same command → output>
**Assumed, not verified:** <explicit list, or "none">
```

**Diff-your-behavior**: when the change modifies existing behavior, run the same probe against the before-state (main / previous deploy) and the after-state, and paste both. A single after-measurement can't distinguish "my change did this" from "it always did this." Relevant whenever the task verb is fix/improve/speed up/reduce.

**The staff-engineer test** — the final gate before sending. Ask: *would a staff engineer approve this report?* Concretely they would ask:

- [ ] Is the proof at tier 1, or is a lower tier smuggled in as fact?
- [ ] Was the proof run in the environment the claim is about?
- [ ] Does one mechanism explain *all* observations, including the weird residue — or is something unexplained and unlabeled?
- [ ] Did you try to break it once (the adversarial pass — recipes in `fable-adversarial-toolkit`)?
- [ ] Is every "assumed" item actually cheap to verify? If yes, why is it still assumed?

## 5. The golden inventory

A **golden artifact** (also: certified reference) is an input, output, config, or code pattern that has been proven correct at tier 1, so future work can be verified *by comparison* instead of from first principles. Goldens turn expensive verification into `diff`.

To certify an artifact, record all four fields — an artifact without them is just a file you like:

```markdown
- **Artifact:** <path or identifier>
- **Certified by:** <exact command + pasted output that proved it>
- **Date / environment:** <when, where — goldens go stale>
- **Scope:** <what comparisons it is valid for; what it does NOT prove>
```

Keep the inventory in the repo (e.g. `GOLDEN.md` or a `verified/` directory of known-good outputs) so it survives sessions — externalized state, per `fable-long-horizon`.

What earns golden status, from canon (as of 2026-07-05):

- **A certified code pattern:** the Slack `oldest`-flake fix — cursor pagination newest→oldest with a client-side `ts` age cutoff, landed in `SlackGateway.get_channel_top_level_messages` (commit c34ede3; AR-04) — was explicitly designated "the canonical approach for any new caller." Its companion rule from the separate truncation incident (AR-03) is `limit=200` plus a `next_cursor` loop on every `conversations.*` call. New call sites are verified by *matching the goldens*, not by re-deriving pagination semantics. The fixture `scripts/fixtures/slack_calls.py::fetch_thread_good` reproduces the paginated pattern portably.
- **A certified environment:** after the 2026-06-12 SDK-version finding, "test SDK-new code in the prod pod, not locally" — the pod is the golden environment for API-behavior claims; the local env is certified *not* equivalent.
- **A certified input:** the real cap-table xlsx used to prove `download_file` and `extract_office_text` worked end-to-end. Rerunning the pipeline against it is a one-command regression check.
- **Anti-golden (label these too):** the repo's `manifest.json` for Slack scopes — looked authoritative, certified stale. Recording *known-bad references* prevents the next session from trusting them.

Maintenance rule: a golden invalidated by an environment change is removed or re-certified the day you notice — a stale golden is an anti-golden wearing a badge.

## 6. Shipped scanners (`scripts/`)

Three tested, portable (POSIX sh + awk + find + grep, no owner-specific paths) tools. Each exits 0 when clean, 1 with findings printed, 2 on usage error — safe to use as CI gates. Fixtures live in `scripts/fixtures/`; the outputs below are pasted from real runs on 2026-07-05.

### 6.1 `fails-open-scan.sh [dir-or-file]`

Finds broad `except Exception` / `except BaseException` / bare `except:` handlers whose body swallows the error (`return None/False/[]/{}/""`, `pass`, `continue`) without re-raising — the pattern behind the 2026-06-12 Redis duplicate-post incident (AR-01: a `get()` that swallowed exceptions made a transient Redis error indistinguishable from "not sent yet", so the dedup gate re-fired) and the 2026-04-21 silent AttributeError incident (AR-02: a typo'd config attribute swallowed as "synthesis failed" across 9 call sites, misread as a prompt regression). `[NEAR-SIDE-EFFECT]` is a proximity heuristic: a send/post/publish/set(/execute(-style call within ~12 lines — those findings are the ones where an error becomes a repeated side effect.

```
$ ./fails-open-scan.sh fixtures/fails_open.py
fixtures/fails_open.py:14: broad except swallows error [NEAR-SIDE-EFFECT]
            except Exception:
fixtures/fails_open.py:32: broad except swallows error [NEAR-SIDE-EFFECT]
        except Exception as exc:
$ echo $?
1
```

Not flagged, by design: the fail-closed handler (`except Exception: raise`) and the narrow `except FileNotFoundError`. The remedy for a true finding is *fail closed*: gate side effects with an atomic claim that raises on infrastructure error (Redis: `SET key NX EX` before the side effect — never `get(key) is None`), and log swallowed exceptions with the traceback (`exc_info=True`), not just the message.

### 6.2 `truncation-check.sh [dir-or-file]`

Finds Slack-style `conversations.history` / `conversations_replies` call sites (py/js/ts) missing `limit=` or cursor handling within the call window, and flags any use of `oldest=`. Canon: defaults return ~28 messages with no warning (threads silently truncated, 2026-04-21), and `oldest` returned 0 messages on ~80% of calls with in-range data (cron silently skipped two Mondays, 2026-04-27 / 2026-05-04 — filter by age client-side instead).

```
$ ./truncation-check.sh fixtures/slack_calls.py
fixtures/slack_calls.py:9: MISSING-LIMIT MISSING-CURSOR
        return client.conversations_replies(channel=channel, ts=ts)
fixtures/slack_calls.py:14: MISSING-CURSOR USES-OLDEST
        return client.conversations_history(
$ echo $?
1
```

Not flagged, by design: the paginated `fetch_thread_good` in the same fixture (limit + cursor loop). After fixing a finding, verify at tier 1 with a threshold: retrieved count == the thread's reported message count, per Section 3.

### 6.3 `dep-check.sh <package> [manifest ...]`

Grep-confirms a dependency line actually exists in `requirements*.txt` / `pyproject.toml` / `package.json` (auto-discovered in cwd if not named) and prints the matching line — i.e., it *produces the tier-1 evidence* for the dep-before-import rule (2026-04-19 outage, Section 1). Run it after editing the manifest and before the import lands in anything auto-deployed.

```
$ ../dep-check.sh google-cloud-kms        # run in fixtures/
3:google-cloud-kms>=2.21
dep-check: FOUND 'google-cloud-kms' in requirements.txt (lines above are the evidence)
$ ../dep-check.sh pyppeteer; echo $?
dep-check: NOT FOUND: 'pyppeteer' in: requirements.txt
1
```

Limits (stated so you don't over-trust the tools — they are tier-1 evidence *of what they check*, nothing more): all three are line-regex heuristics. `fails-open-scan` misses swallowing via sentinel objects or `except (A, Exception)` tuples; `truncation-check` misses calls aliased through wrappers; `dep-check` matches substrings, so verify the matched line is the package you meant, and it cannot tell you the *installed* version — for that, ask the environment (`pip show <pkg>`), per Section 1's environment-identity rule.

## 7. Worked example: the discriminating diagnosis (positive canon)

2026-06-12, "the bot still can't read xlsx attachments" after two same-day fixes. The tier-1-first approach, before touching any code:

| Hypothesis | Check (tier 1) | Result |
|---|---|---|
| Token lacks `files:read` | live `auth.test` → `x-oauth-scopes` header | scope present → eliminated (and exposed the repo manifest as stale) |
| Download/extract broken | ran the exact gateway code in the prod pod against a real cap table | 50KB download, 60K chars extracted → eliminated |
| Events missing metadata | inspected a live `file_share` event | full metadata → eliminated |
| SDK too old for new API | checked prod SDK version in the pod | 0.109.1 (local was 0.75.0 — wrong env for testing) |

Four checks, four hypotheses retired, each check's output recorded. The surviving explanation — the lossy text-dump wasn't landing intact in context — made the fix small and obvious. Contrast the same-vintage negative example: "memos lost depth" was *plausibly* a prompt regression, and only a grep for the typo class (`rg 'self\.config\.MODEL_'`) revealed nine swallowed AttributeErrors. Plausibility pointed at the model; evidence pointed at a typo. Evidence won. (Designing which check to run next is `fable-adversarial-toolkit`'s job; this skill's job is refusing to conclude without one.)

## 8. When NOT to use this skill

| Situation | Use instead |
|---|---|
| Designing the *experiment* — which observation best discriminates hypotheses, predict-then-run | `fable-adversarial-toolkit` |
| Live triage of a broken system, symptom → suspect list | `fable-debugging-playbook` |
| Checking whether this failure was already diagnosed and settled | `fable-failure-archaeology` |
| Deciding how to make the change safely (reversibility, surgical scope) | `fable-change-control` |
| Cutting a big task into stages worth verifying separately | `fable-decomposition` |
| How to *phrase* verified-vs-assumed in the report | `fable-communication` |
| Deciding how much verification effort this task deserves at all | `fable-effort-calibration` |
| Whole-session gated execution (this skill is one gate of that runbook) | `fable-session-campaign` |
| Turning a verification miss into a library update | `fable-self-improvement-loop` |

This skill also does not license skipping change control: proof that something works is necessary for shipping it, never sufficient.

## 9. Provenance and maintenance

- **Evidence hierarchy, done-report, staff-engineer test, verifiable-goal transforms:** the project owner's global workflow rules (Verification Before Done; goal-driven execution) plus first-person introspection by claude-fable-5, aligned with Tenets 5/7/8 in `skills/fable/README.md`.
- **Threshold-before-measurement and the golden inventory:** doctrine extensions by claude-fable-5 (2026-07-05), grounded in the truncation and canonical-pattern incidents above. Labeled: the framing is Fable's; the incidents are real.
- **All dated incidents** (2026-04-19 dep outage, 2026-04-21 AttributeError + truncation, 2026-04-27/05-04 `oldest` flake, 2026-05-27 auto-deploy correction, 2026-06-12 Redis dup + Excel diagnosis): verified against the owner's dated incident-memory corpus on 2026-07-05. Slack API behaviors (~28-message default, `oldest` flakiness) are third-party-service behavior observed then — re-verify against the live API before relying on the exact numbers.
- **Scripts:** written and tested 2026-07-05 against `scripts/fixtures/`; outputs in Section 6 are pasted from those runs, not typed from memory.
- **Corrections (2026-07-05, library review):** §3's `thread_message_count` claim was downgraded to match the record (a how-to-apply recommendation, not a verified part of the landed fix); §5's first golden no longer conflates the `oldest`-flake fix (`get_channel_top_level_messages`, c34ede3, AR-04) with the `limit=200`/cursor rule from the separate truncation incident (AR-03); incident retellings now cite their AR entries (canonical home: `fable-failure-archaeology`).
- **Re-verification commands** (from this skill's directory; expected: outputs match Section 6):

```sh
cd scripts
./fails-open-scan.sh fixtures/fails_open.py;  echo "exit=$? (expect 1, 2 findings: lines 14, 32)"
./truncation-check.sh fixtures/slack_calls.py; echo "exit=$? (expect 1, 2 findings: lines 9, 14)"
( cd fixtures && ../dep-check.sh google-cloud-kms && ! ../dep-check.sh pyppeteer ) && echo "dep-check OK"
```
