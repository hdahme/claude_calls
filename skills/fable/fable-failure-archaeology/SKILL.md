---
name: fable-failure-archaeology
description: >
  The chronicle of settled battles: every diagnosed incident rendered as
  Symptom → Root cause → Evidence → Status → Prevention rule. Load this BEFORE
  investigating any symptom that smells familiar — duplicate side effects
  (double posts, re-fired alerts), silently thin/empty LLM output, truncated
  Slack threads or empty history queries, env vars that "don't take", prod
  CrashLoopBackOff after a deploy, invalid_grant / Invalid JWT Signature,
  slash commands timing out, destroyed document formatting, files written to
  the wrong project, or any "this worked before" report. Also load it when
  auditing your own process: false completion, silent interpretation, stale
  environment models, skipped preflight rituals. If your symptom matches an
  entry, start from the settled root cause — do not re-diagnose from scratch.
---

# Fable Failure Archaeology — the chronicle of settled battles

Purpose: **no settled battle is ever re-fought.** Every entry was paid for with
a real incident — a prod outage, misdirected debugging, or an owner correction.
The knowledge is embedded here; you do not need the original systems to use it.

These entries are the **canonical home** of each incident's facts (per
`fable-self-improvement-loop` §3). Other skills retell incidents only as worked
examples of their own methods and cite the AR entry; on any conflict of detail,
this chronicle wins.

## STANDING RULE (read this first, every time)

> **Before investigating any symptom, grep this file.** If your symptom matches
> an entry, start from the settled root cause and its prevention rule — not from
> scratch. Re-deriving a settled diagnosis is a process failure (Tenet 10).

```bash
# From the repo root — replace keywords with your symptom's nouns:
grep -n -i -E "duplicate|dedup|truncat|invalid_grant|timeout|AttributeError" \
  skills/fable/fable-failure-archaeology/SKILL.md
```

Then read the matched entry in full, including Status: an OPEN entry means the
workaround is the current best move and the "proper fix" is a known project —
do not chip at it mid-session.

## Quick index (symptom keyword → entry)

| Symptom smells like | Entry |
|---|---|
| Duplicate posts / alert re-fired / idempotency broke | AR-01 |
| LLM feature "thin", "lost depth", empty sections, "regression" | AR-02 |
| Slack thread/history missing messages | AR-03 |
| Slack history returns 0 messages intermittently | AR-04 |
| Shell env var override "doesn't take" | AR-05 |
| Prod pods CrashLoopBackOff right after deploy (ImportError) | AR-06 |
| Slack slash commands time out ("app didn't respond") | AR-07 |
| `invalid_grant: Invalid JWT Signature` | AR-08 |
| Local Google Sheets/Drive auth fails every way | AR-09 |
| MongoDB Atlas BYOK / KMS key rotation | AR-10 |
| Document formatting destroyed by an automated edit | AR-11 |
| Output written into the wrong project directory | AR-12 |
| "Attachment can't be read" / suspected broken pipeline | AR-13 |
| Router/lookup silently blind to most of its corpus | AR-14 |
| "Does this repo auto-deploy?" (stale environment belief) | AR-15 |
| Tool reported success but the change didn't land | META-1 |
| Picked one interpretation silently, owner objected | META-2 |
| Acting on remembered facts about the environment | META-3 |
| One giant attempt instead of verifiable stages | META-4 |
| Skipped a mandated preflight/ritual step | META-5 |

## Entry format (canonical — use this for all new entries)

```
### AR-NN — <short title> (YYYY-MM-DD)
- Symptom: what was observed, in the words a future session would use
- Root cause: the actual mechanism, one sentence if possible
- Evidence: what proved it (not "it seemed like")
- Status: SETTLED (fix landed) | OPEN (workaround only; proper fix is a project)
- Prevention: portable rule first, then the system-specific fix location
```

## Part A — System incidents (the paid-for canon)

### AR-01 — Redis dedup fails open → duplicate podcast posts (2026-06-12)
- **Symptom:** Already-posted podcast episode posted to Slack a second time.
- **Root cause:** The dedup check was `get(key) is None`, but the Redis toolkit's
  `get()` wraps everything in `try/except Exception: return None` — a transient
  Redis error is indistinguishable from a missing key, so the gate **fails open**
  and the side effect re-fires.
- **Evidence:** The key existed the whole time (`evicted_keys=0`, no eviction);
  the repost coincided with a Redis blip. Second contributing cause: cron jobs
  run in **every** k8s replica, so a per-item check alone can't stop two whole
  runs racing.
- **Status:** SETTLED (2026-06-12) — hackgpt's `_run_cron` now takes a
  cross-replica `cron_run_lock:{id}`.
- **Prevention (portable):** Never gate a side effect on a read that can swallow
  errors. Claim atomically **before** the side effect with a fail-closed lock:
  `SET key NX EX <ttl>` — returns False if claimed (skip), **raises** on backend
  error (fail closed, retry later). Any cron in a replicated deployment needs a
  cross-replica run-lock in addition to per-item locks.

### AR-02 — Silent AttributeError masked as "prompt regression" (2026-04-21)
- **Symptom:** Two user-visible "regressions" at once: IC memos lost depth;
  calendar morning brief returned only event titles. Looked like model/prompt
  degradation.
- **Root cause:** Typo'd config attribute (`config.MODEL_SONNET`; the real attr
  is `SONNET_MODEL`) across 9 call sites raised `AttributeError` at call time;
  broad `except Exception` around the LLM calls swallowed it as generic
  "synthesis failed" and returned canned fallback output. No traceback logged.
- **Evidence:** Grep for the attr pattern found all 9 sites; both "regressions"
  traced to the same typo.
- **Status:** SETTLED (2026-04-21).
- **Prevention (portable):** When LLM output goes "thin/empty", grep for the
  typo class **before** touching prompts (e.g. `rg 'self\.config\.(MODEL_|_MODEL)'`)
  and run the call path once to see whether the fallback branch fired. Every
  `except Exception` around an LLM call must log `exc_info=True`. "Prompt
  tuning needed" is a hypothesis, not a default diagnosis.

### AR-03 — Slack conversations APIs silently truncate at ~28 messages (2026-04-21)
- **Symptom:** Thread summaries missing most of the thread; long diligence
  threads produced memos with no depth.
- **Root cause:** `conversations.replies` / `conversations.history` return ~28
  messages by default and require explicit cursor pagination. No error, no
  warning — the truncation is invisible from the caller. A downstream
  `messages[:20]` slice compounded the loss.
- **Evidence:** API responses carried `has_more` + `response_metadata.next_cursor`
  that no caller was following.
- **Status:** SETTLED (2026-04-21).
- **Prevention (portable):** "Data completeness is a hypothesis to test" (Tenet 5).
  For Slack: always pass `limit=200` and loop on `has_more` +
  `response_metadata.next_cursor`. Audit downstream `[:N]` slices — if upstream
  truncated, the slice compounds it. Pass a total-count field to any summarizer
  so it can flag suspiciously short input.

### AR-04 — Slack `conversations.history` with `oldest` returns 0 messages (2026-04-27, 2026-05-04)
- **Symptom:** A Monday cron silently skipped posting two weeks in a row —
  "No matching roll-call message found" — no API error, nothing in metrics.
- **Root cause:** With `oldest` set, Slack returned 0 messages on ~80% of calls
  even when in-range messages existed (confirmed on a real channel; reproduced
  4-of-5 calls empty in identical conditions). Without `oldest`, the same call
  is reliable.
- **Evidence:** Side-by-side reproduction with/without the parameter.
- **Status:** SETTLED (fix landed in the Slack gateway, commit c34ede3).
- **Prevention (portable):** Do not date-filter with `oldest`. Omit it, paginate
  newest→oldest via cursor, and break client-side once `ts < cutoff_ts` (Slack
  returns newest-first, so this short-circuits cleanly).

### AR-05 — `load_dotenv(override=True)` clobbers shell env overrides (2026-05-13)
- **Symptom:** `ENABLED_PROVIDERS=anchorage python ...` ran with the full
  provider list anyway; emptying `GOOGLE_APPLICATION_CREDENTIALS` in the shell
  didn't stop a broken key file from being used.
- **Root cause:** hack-mono's `src/configs/config.py` runs
  `load_dotenv(override=True)` at module import (line 4, as of 2026-05-13);
  most toolkit modules import it transitively, so `.env` silently wins over
  the shell.
- **Status:** SETTLED (2026-05-13) — the line is intentional (author wanted
  `.env` to beat inherited dev shells); the workaround pattern is settled.
- **Prevention (portable):** When a shell env override "doesn't take", suspect a
  dotenv-with-override in the import chain before suspecting your shell. Fix
  pattern: import the config module **first**, then mutate config class
  attributes directly, and `os.environ.pop(...)` anything libraries read
  directly. In hack-mono, also pass an explicit config object
  (`run_snapshot(config=Config())`) — the no-arg path re-runs dotenv.

### AR-06 — Missing dep + top-level import → prod CrashLoopBackOff (2026-04-19)
- **Symptom:** After a push, both old and new replica sets CrashLoopBackOff'd —
  a full outage, not a graceful rollout. `ImportError: cannot import name 'kms'`.
- **Root cause:** A top-level `from google.cloud import kms` landed in the
  `main.py` import graph while `google-cloud-kms` was **not** in
  requirements.txt. The Edit to requirements.txt had **reported success but did
  not actually land** (see META-1). Cloud Build auto-deployed on push.
- **Evidence:** Pod logs; requirements.txt inspected post-incident lacked the line.
- **Status:** SETTLED (2026-04-19). Owner's ruling: required deps are hard
  requirements — fail fast at boot, don't paper over with lazy imports.
- **Prevention (portable):** After editing any dependency manifest,
  `grep -n '<package>' requirements.txt` to confirm the line exists **before**
  the import lands in auto-deployed code. Prefer deps merged+deployed before
  (or in an earlier commit than) the import.

### AR-07 — Slack Bolt flips to OAuth-install mode on two env vars (2026-04 — hardening session of 2026-04-19; memory entry undated)
- **Symptom:** Slash commands time out ("the app didn't respond") even though
  `SLACK_BOT_TOKEN` is present and valid.
- **Root cause:** When `SLACK_CLIENT_ID` + `SLACK_CLIENT_SECRET` are in the env,
  Bolt (Python) auto-enables OAuth installation mode with a **file-based**
  InstallationStore (`./data/installations`) — incompatible with
  `readOnlyRootFilesystem: true` and multi-pod replicas. Bolt then **ignores**
  `SLACK_BOT_TOKEN` entirely.
- **Evidence:** Bolt's own startup logs: INFO "Bolt has enabled the file-based
  InstallationStore/OAuthStateStore for you" followed by WARNING "token (or
  SLACK_BOT_TOKEN env variable) will be ignored" — that second line is the signal.
- **Status:** SETTLED (2026-04; date inferred from session linkage with the
  2026-04-19 hardening — the source memory carries no date) — hackgpt excludes
  those secret names from the pod's secret mount via an EXCLUDE_REGEX in its
  secret-provider generator.
- **Prevention (portable):** For single-workspace internal bots, never expose
  `SLACK_CLIENT_ID` / `SLACK_CLIENT_SECRET` / `SLACK_APP_ID` / `SLACK_APP_TOKEN`
  to the pod — only `SLACK_BOT_TOKEN`, `SLACK_BOT_USER_ID`, `SLACK_SIGNING_SECRET`.
  Beware bulk secret-sync mechanisms that mount everything.

### AR-08 — `invalid_grant: Invalid JWT Signature` = dead SA key (2026-04-27)
- **Symptom:** Every Cloud SQL connection from hack-mono failed; the real error
  hid behind a generic SQLAlchemy frame in truncated Streamlit logs.
- **Root cause:** A prior security hardening scrubbed user-managed JSON keys for
  the shared service account; hack-mono was still mounting one of the dead keys.
  This error string is what Google's token endpoint returns when the key was
  disabled/deleted server-side.
- **Evidence:** Forcing the connector exception inline (a one-liner `SELECT 1`
  via `kubectl exec`) surfaced the real message.
- **Status:** SETTLED (2026-04-27) — hack-mono migrated to Workload Identity +
  impersonation; no JSON key.
- **Prevention (portable):** Treat `invalid_grant: Invalid JWT Signature` as
  "this SA's user-managed key is dead", not as a code bug. Migrate to Workload
  Identity/impersonation; do **not** mint a replacement long-lived key.

### AR-09 — Local Google Sheets/Drive auth is broken on this stack (as of 2026-05-01)
- **Symptom:** Local scripts cannot reach Sheets by any path: SA key file →
  `invalid_grant: Invalid JWT Signature` (husk of a scrubbed key, see AR-08);
  user→SA impersonation → `getAccessToken denied` even with the TokenCreator
  binding verified present; ADC with Sheets scopes → Workspace blocks consent.
- **Root cause:** Key scrubbed (settled); the impersonation denial is
  *suspected* to be an invisible org-level constraint (unproven — labeled
  suspicion, not fact). Prod is unaffected (in-cluster Workload Identity works).
- **Evidence:** `gcloud auth print-access-token --impersonate-service-account=...`
  fails identically to the Python path — so not a library issue.
- **Status:** OPEN as of 2026-07-05 — proper fix is a real project. Do not chip
  at the auth dance mid-session.
- **Prevention (portable):** When local auth to a managed service is broken and
  prod uses workload identity, run the check from inside the environment where
  identity is already wired, or have the data handed to you — do not burn a
  session on the auth dance. **Fast paths (this system):** (1) have the owner
  paste the rows, (2) `kubectl exec` into a pod where Workload Identity is
  already wired, (3) last resort, mint a fresh SA key and accept the security debt.

### AR-10 — Atlas BYOK does not follow KMS key rotation (first hit ~2026-07-18)
- **Symptom (future):** MongoDB Atlas encryption-at-rest quietly stays on an old
  KMS key version after the key auto-rotates.
- **Root cause:** Atlas pins a specific `cryptoKeyVersions/<N>` resource name;
  KMS 90-day auto-rotation promotes N+1 but Atlas keeps using N until manually
  re-pointed. The other three keys on that keyring auto-handle rotation; only
  the Atlas BYOK key needs the manual step.
- **Status:** OPEN — recurring manual task every ~90 days (first: ~2026-07-18,
  90d from 2026-04-19).
- **Prevention (portable):** Any external service that pins a specific key
  *version* (not the key) will silently ignore KMS auto-rotation — inventory
  version-pinning consumers when enabling rotation and schedule the manual
  re-points. **Runbook (this system):** list key versions (command in Provenance
  below), pick the new ENABLED primary, update Atlas UI → Security → Encryption
  at Rest with the new version resource ID, keep the old version **enabled** a
  few days for re-encryption, then disable (never destroy) it.

### AR-11 — Pandoc roundtrip destroyed a hand-formatted Google Doc (2026-05-08)
- **Symptom:** Owner had to revert a submission Doc: "it messed too much up and
  presentation really matters."
- **Root cause:** Applied three text patches via export → patch markdown →
  pandoc → HTML → Drive full-file replace. The roundtrip re-rendered the whole
  doc with default styles, clobbering all manual formatting.
- **Status:** SETTLED (2026-05-08).
- **Prevention (portable):** Never wholesale-replace a document the user has
  hand-styled. Default deliverable: a `targeted_edits.md` with anchor text, new
  text, and rationale, for the user to apply by hand. Surgical API text edits
  that preserve surrounding styling need explicit confirmation first. A full
  replace is an irreversible operation on someone else's work — a
  `fable-change-control` question.

### AR-12 — Scratch doc written into the wrong sibling project (2026-05-08)
- **Symptom:** Owner: "omg, THIS is the project directory, we shouldn't be
  touching passive sonar."
- **Root cause:** Asked to evaluate project B "using project A's `.plan` as a
  scratch doc", the analysis was appended into project A's file. The named file
  was a *style template reference*, not the destination — a silently-picked
  wrong interpretation (see META-2).
- **Status:** SETTLED (2026-05-08).
- **Prevention (portable):** Output goes in the directory of the project the
  work is *about*. Sibling project files are read-only references unless
  explicitly targeted. If the destination is genuinely ambiguous, ask before
  writing.

### AR-13 — Excel "can't be read": the discriminating-diagnosis exemplar (2026-06-11/12) [POSITIVE]
- **Symptom:** Owner reported xlsx attachments still unreadable after two
  same-day fixes. Easy wrong move: patch the pipeline a third time blind.
- **What was done instead (the model to copy)** — four checks, each killing a
  hypothesis **before touching code**:
  1. `auth.test` → live bot token HAS `files:read`; the repo manifest.json is
     stale — don't trust it for scopes. Kills "missing scope".
  2. Ran the exact gateway code in the prod pod against a real file: download,
     extract, detection all pass. Kills "pipeline broken".
  3. Prod SDK 0.109.1 vs local 0.75.0 → test SDK-new code in the pod, not
     locally. Kills "works-on-my-machine confusion".
  4. The pod's token lives in PID 1's env (`/proc/1/environ`), not in
     `kubectl exec` shells. Kills a class of "auth broken in pod" noise.
- **Root cause (found only after the eliminations):** the fetch was fine; the
  lossy 60K-char text dump wasn't landing intact in context. Fix: route xlsx
  through Claude's code-execution tool via the Files API — xlsx is NOT a native
  document block (document blocks accept only PDF + text), so code execution is
  the only way to hand Claude a real spreadsheet.
- **Status:** SETTLED (diagnosis 2026-06-12; fix built but not yet deployed as
  of 2026-06-12 — verify deploy state before relying on it).
- **Prevention (portable):** When a "still broken" report follows fixes, run
  the hypothesis-elimination ladder (Tenet 2) before writing code. Each check
  must be able to *kill* a hypothesis, not confirm the favorite.

### AR-14 — Skill router silently blind to 750+ of 806 skills (2026-06-10)
- **Symptom:** Dynamic skill lookup "worked" but almost never picked relevant
  skills. No error anywhere.
- **Root cause:** The catalog builder sampled only ~50 skills (2 per category,
  capped) to save context — the router literally could not see 93% of the
  corpus. Same failure family as AR-03: invisible truncation upstream of a
  consumer that assumes completeness.
- **Status:** SETTLED (2026-06-10) — rebuilt as metadata index + BM25 prefilter
  (top-25 shortlist) + lazy body load.
- **Prevention (portable):** Any sampled/capped catalog feeding a selector is a
  silent-blindness risk. Verify coverage: count corpus vs. count visible to the
  selector. Related truncation instance: an LLM output cap of 4000 tokens
  truncated long-episode JSON into "Analysis failed" placeholders (fixed by
  raising to 16000) — when structured LLM output fails to parse, check the
  output-token cap before blaming the model.

### AR-15 — Stale belief: "hack-mono has no auto-deploy" (corrected 2026-05-27)
- **Symptom:** Sessions acted as if pushing to main was inert and a manual
  build/rollout was always required.
- **Root cause:** An earlier memory recorded "no auto-deploy"; the environment
  changed (or the memory was wrong): pushing to `main` **does** auto-deploy via
  a Cloud Build GitHub trigger. Acting on the stale model risks accidental prod
  deploys (see AR-06 for the blast radius).
- **Status:** SETTLED (2026-05-27) — memory corrected.
- **Prevention (portable):** Deployment topology is a **volatile fact**: before
  any push to a default branch, re-verify whether it deploys (look for
  cloudbuild.yaml / CI triggers / deploy workflows) rather than trusting a
  remembered answer. See META-3.

---

## Part B — Meta-canon: agent-failure classes

These are failures of *process*, not of any one system. Each has the same
format; the "system" is the agent itself. When an owner correction lands,
classify it against these five before writing a new lesson.

### META-1 — False completion (canonical instance: 2026-04-19, AR-06)
- **Symptom:** Agent reports a step done; the change never actually landed.
- **Root cause:** Treating a tool's success message as proof of effect. An Edit
  can "succeed" while content fails to match, or a race with the user's git
  state undoes it. The map (tool output) is not the territory (file state).
- **Evidence:** requirements.txt edit "succeeded"; the dep was absent; prod
  outage followed (AR-06).
- **Status:** SETTLED as a class; recurs whenever verification is skipped.
- **Prevention:** Never mark done without observing the effect independently of
  the action that produced it. Full doctrine: `fable-verification-and-evidence`.

### META-2 — Silent interpretation (canonical instances: 2026-05-08, AR-11 + AR-12)
- **Symptom:** Owner reacts with "that's not what I meant" to a completed action.
- **Root cause:** The ask had ≥2 live readings ("use X as a scratch doc";
  "push the changes to the doc") and the agent picked one without surfacing
  that a choice existed. Cost lands on the owner, sometimes irreversibly.
- **Status:** SETTLED as a class.
- **Prevention:** Enumerate interpretations before acting on any instruction
  that names a destination, a mechanism, or a scope; act silently only when
  one reading survives. Full doctrine: `fable-ambiguity-and-judgment`.

### META-3 — Stale environment model / long-horizon decay (canonical: AR-15)
- **Symptom:** Confident action based on a remembered fact that is no longer
  true (or never was); also: constraints stated early in a session get dropped
  late; settled battles get re-fought.
- **Root cause:** Memory and context decay while the world (and the transcript)
  moves. Volatile facts — deploy triggers, API scopes, SDK versions, schema —
  were treated as stable.
- **Evidence:** AR-15 (deploy trigger), AR-13's stale manifest.json (scopes).
- **Status:** SETTLED as a class; the entire reason this file exists.
- **Prevention:** Date-stamp volatile facts; re-verify them at point of use;
  externalize plans and constraints to disk. Full doctrine: `fable-long-horizon`.

### META-4 — Deliverable decomposition instead of claim decomposition
- **Symptom:** One giant attempt; failures surface only at the end and can't be
  localized. Or: components each "done" but the load-bearing claim (e.g. "the
  dedup gate fails closed") was never isolated and tested — AR-01 is what that
  costs.
- **Root cause:** Cutting work by artifact ("write the service, then the cron")
  instead of by verifiable claim ("the lock fails closed under a backend error").
- **Status:** SETTLED as a class (the library's flagship gap).
- **Prevention:** Decompose along seams where each piece can be proven correct
  independently and cheaply; front-load the design-killing claim. Full
  doctrine: `fable-decomposition`.

### META-5 — Process-discipline lapse (canonical instance: 2026-02-12)
- **Symptom:** A mandated preflight ritual (the owner's Expert Lens semantic
  search) was skipped for an **entire implementation session**; the owner had
  to call it out afterward.
- **Root cause:** Ritual steps feel skippable exactly when momentum is high —
  the agent optimizes for the task and drops the meta-task. The rule was known;
  it was not *executed*.
- **Status:** SETTLED as a class; recurrences stay possible — that is why it is
  a checklist item, not a memory.
- **Prevention:** Preflight rituals are gates, not suggestions: run them before
  any non-trivial work; if you notice mid-session that one was skipped, stop
  and run it then — don't quietly continue. Enforcement: `fable-session-campaign`.

---

## Adding a new entry (the only sanctioned path)

Do **not** edit this file ad hoc. New entries route through
`fable-self-improvement-loop`, which owns the correction → library-update
mechanism. Within that protocol, an entry qualifies when ALL hold:

1. **It happened** — a real incident or owner correction, not a hypothetical.
2. **Root cause is known** — or the entry is explicitly Status: OPEN with the
   best current workaround. Never file a guess as SETTLED.
3. **Evidence is stated** — a reproduction, a log line, a side-by-side test.
   "It seemed like" does not qualify.
4. **Dated** — incident date and, if different, the date the fix landed.
5. **Prevention is two-layer** — portable rule first, then the
   system-specific fix location.

Assign the next monotonic `AR-NN` (or file it as a canonical instance under an
existing `META-*` class). Add a Quick-index row with the symptom keywords a
future desperate session would actually grep for.

## When NOT to use this skill

- **Novel symptom, no index match** → `fable-debugging-playbook` (live triage,
  hypothesis portfolio) and `fable-adversarial-toolkit` (discriminating
  experiments). Come back here afterward to file what you learned — via
  `fable-self-improvement-loop`.
- **Turning a fresh owner correction into a lesson** → `fable-self-improvement-loop`
  (it decides whether the lesson lands here or in another skill).
- **Proving a fix actually works** → `fable-verification-and-evidence`.
- **Deciding how risky a change is / how to stage it** → `fable-change-control`.
- **Cold-starting on an unfamiliar system** → `fable-context-bootstrap` (this
  file is one of its inputs, not a substitute for it).

## Provenance and maintenance

- **Source of every Part A entry:** the owner's dated incident-memory corpus
  (2026-02 through 2026-07), verified 2026-07-05 against the individual memory
  files — not paraphrased from summaries. Part B classes come from the library
  manifesto's stated gaps (`skills/fable/README.md`) plus the same corpus.
- **Volatile facts and how to re-check them:**
  - AR-10 rotation date (~2026-07-18) and key state:
    `gcloud kms keys versions list --key=atlas-byok-cmek --keyring=hackgpt-security --location=us-central1 --project=hackgpt-433915`
  - AR-15 deploy trigger: check for `cloudbuild.yaml` + a Cloud Build GitHub
    trigger in the repo before pushing; do not trust this file's snapshot.
  - AR-13 deploy state ("fix built, not yet deployed" is an as-of-2026-06-12
    fact): check the hackgpt repo/pod before assuming either way.
  - AR-09 (OPEN): re-test with
    `gcloud auth print-access-token --impersonate-service-account=<SA>` before
    declaring it still broken — someone may have fixed the org constraint.
  - Slack API behaviors (AR-03, AR-04) are third-party and may change; a
    5-minute scripted reproduction beats trusting either Slack's docs or this file.
- **Corrections (2026-07-05, library review):** AR-09 and AR-10 gained the
  portable first layer the entry format mandates (owner runbooks kept as the
  second layer); AR-07's date is now hedged as inferred from session linkage
  (the source memory is undated); AR-02's Evidence field was trimmed to what
  the memory records as done (the call-path run was how-to-apply guidance and
  already lives in Prevention); the header now states these entries are each
  incident's canonical home.
- **Maintenance:** additions and status changes (OPEN → SETTLED) go through
  `fable-self-improvement-loop` only. If an entry is discovered to be wrong,
  correct it — a wrong settled diagnosis is worse than none — and note the
  correction date in the entry (see AR-15 for the pattern).
