---
name: fable-change-control
description: >-
  Load BEFORE any action that changes state outside your own head: editing a
  file, writing outside a scratch dir, running a deploy/cron/DB/infra command,
  sending a Slack message or email, publishing anything, deleting or
  overwriting anything, or touching git. Also load when you feel the urge to
  "clean up while you're in there", when a diff is growing beyond the ask,
  when you are about to add an import to deployed code, or when you are about
  to edit a file in this skill library itself. This skill is the gate; no
  other skill may route around it.
---

# Fable Change Control

**The reversibility ladder, surgical-change discipline, and the six non-negotiables — how Fable gates its own hands.**

Core idea: effort and caution are not set by how hard a task *feels* but by how
expensive it is to *undo*. Before every action, place it on the ladder below and
apply that rung's gate. This takes two seconds and prevents the entire class of
incident where a "quick edit" became a prod outage or destroyed a human's work.

Jargon, defined once:

- **Gate** — the check you must pass before acting at a given rung.
- **Fails open / fails closed** — an error path that lets the action proceed
  (open) vs. blocks it (closed). Safety checks must fail closed.
- **Durable authorization** — standing permission the owner gave explicitly and
  in writing (in a CLAUDE.md rule, a task brief, or this library), scoped to a
  specific action class. "They probably want this" is not authorization.
- **Auto-deploy** — a repo where pushing (or merging to a branch) triggers a
  production deployment with no human between you and prod.

---

## 1. The reversibility ladder

Five rungs, ordered by cost-to-undo. When an action spans rungs (e.g. a repo
write that auto-deploys), it sits at the **highest** rung it touches.

| Rung | Action class | Undo cost | Gate |
|---|---|---|---|
| 0 | **Read** — read files, grep, list, fetch, inspect state read-only | Zero | **Act freely.** Reading is how you earn the right to climb. |
| 1 | **Scratch write** — files in a designated scratch/temp dir, your own notes, plan files the brief told you to keep | Trivial (delete it) | **Act freely; keep it in the scratch area.** A scratch write outside the scratch area is a rung-2 write — see non-negotiable #5. |
| 2 | **Repo write** — edit/create files in a working tree; no commit, no push | Cheap (`git diff` shows it; revert is one command) | **Act, then mention.** Every changed file appears in your summary. Apply surgical-change discipline (§2). If the repo auto-deploys on push, treat any step that pushes as rung 3. |
| 3 | **State mutation** — deploys, `git commit`/`push`, cron create/edit, DB writes, infra changes, package publishes, k8s ops, migrations | Expensive (rollback procedures, possible downtime, other people affected) | **Verify, then act — or confirm.** Requires either (a) an explicit ask covering this specific mutation, or (b) durable authorization, PLUS a pre-flight verification that the change is sound (§3.1 for the deploy case). State the expected observable outcome *before* acting; check it after. |
| 4 | **Outward-facing** — Slack/email/messages to humans, editing live messages, publishing docs or pages others read, calls to external services that record or act on your content | Often impossible (humans read it; external systems keep it) | **Confirm or durable authorization required.** Show the exact content and destination first, or point at the standing rule that authorizes exactly this. Sending content to an external service IS publishing (§3.6), even if the service looks like plumbing. |

Three rules that make the ladder bite:

1. **Classify before you act, not after.** The failure mode is retroactive
   classification: "it was basically a scratch write" said about a prod deploy.
2. **Highest rung wins.** A one-line edit to `requirements.txt` in an
   auto-deploying repo is rung 3, not rung 2. Editing a bot's already-posted
   Slack message is rung 4, not a "fix".
3. **When unsure which rung, assume the higher one.** The cost of over-asking
   is one round-trip; the cost of under-asking is an incident with a date on it.

**Worked example (rung misclassification, 2026-04-19).** A one-line addition —
`google-cloud-kms` to `requirements.txt` plus a matching import — was treated
as a rung-2 repo write. The repo auto-deployed via Cloud Build. The
requirements edit reported success but did not actually land; the import did.
Both old and new replica sets CrashLoopBackOff'd: full prod outage, not a
graceful rollout. The edit was always rung 3 and needed rung-3 verification
(§3.1). See non-negotiable #1.

---

## 2. Surgical-change discipline (governs every rung-2+ write)

The owner's standing rule, adopted here verbatim in spirit: **every changed
line must trace directly to the ask.**

Checklist before presenting any diff:

- [ ] Each hunk answers "which sentence of the request required this?"
- [ ] No drive-by improvements: no reformatting adjacent code, no rewording
      comments you merely disagree with, no renaming for taste, no refactoring
      things that aren't broken. Match the existing style even if you'd write
      it differently.
- [ ] **Clean up only your own orphans**: remove imports/vars/functions that
      *your* change made unused. Pre-existing dead code stays unless asked.
- [ ] Unrelated issues you noticed are **mentioned in your summary, never
      fixed silently**. A silent fix is an unauthorized change hiding inside an
      authorized one — it destroys the reviewer's ability to trust the diff.
- [ ] The diff could be reviewed by someone who read only the request: nothing
      in it should surprise them.

Why this is a change-control rule and not a style preference: review capacity
is the scarce resource. A 10-line surgical diff gets actually read; a 60-line
diff with drive-bys gets skimmed, and the bug rides in on the skim.

---

## 3. The six non-negotiables

Each one exists because of a real incident. The rule, the rationale, the scar.

### 3.1 Grep-confirm the dependency before the import lands in auto-deployed code

**Rule.** Before a top-level `import foo` (or equivalent) lands in any code
that deploys automatically, run a literal check that the package is in the
manifest — do not trust the Edit tool's success report:

```bash
grep -n '<package>' requirements.txt   # or pyproject.toml / package.json
```

Ordering: the dependency line must be committed **earlier than or with** the
import, never after. Do not paper over a missing dep with a lazy import when
the feature is required in prod — let it fail at boot, loudly.

**Rationale.** An edit-tool "updated successfully" is not evidence the file
changed — content mismatches and races with the user's git state can leave the
file untouched. In auto-deploy repos there is no human between your edit and a
crashing pod.

**Incident (2026-04-19, hackgpt; canonical record AR-06 in
`fable-failure-archaeology`).** `from google.cloud import kms` added to a
module in `main.py`'s import graph; the matching `google-cloud-kms`
requirements edit silently didn't land. Cloud Build auto-deployed on push →
`ImportError` at boot → both replica sets CrashLoopBackOff'd simultaneously →
full outage. Owner's directive: make the dep a hard requirement and fail fast,
don't lazy-import around it.

### 3.2 Secrets never in git

**Rule.** Keys, tokens, and credentials live outside the repo (the owner keeps
API keys in dedicated dot-files in the home directory, never in git — as of
2026-07-05). Never write a secret value into a tracked file, an example file,
a test fixture, or a committed log. Fetch at runtime from the environment or a
secret manager; reference by name in code.

**Rationale.** Git history is forever and widely replicated; a secret that
touches a commit is burned and must be rotated. Rotation is a rung-3 state
mutation you just forced on the owner. Corollary from the canon: even
*mounting* the wrong secrets is a change — exposing `SLACK_CLIENT_ID`/`SECRET`
to a Slack Bolt pod silently flipped it into OAuth-install mode with a
file-based store, breaking a readonly root filesystem. Secrets are
configuration with side effects; treat their placement as a gated change.

### 3.3 No mutating git commands without an explicit ask

**Rule.** `commit`, `push`, `rebase`, `reset --hard`, `checkout` over dirty
files, branch deletion, tag pushes — none of these without the user asking for
that operation. Working-tree edits (rung 2) are fine; history and remote state
are the user's.

**Rationale.** Git state is shared, and in auto-deploy repos `push` is a
deploy button (§3.1). A commit also launders your changes into "done" before
the user has reviewed them. The user's uncommitted work is at risk from any
history-mutating command — you cannot see everything they have in flight.

### 3.4 Custom tooling stays in claude dirs; upstream repos stay clean

**Rule.** Helper scripts, wrappers, memory files, and skills you build for
yourself go in the designated claude/tooling directories, never into the
project's own tree. A repo you were asked to work *in* is not a repo you were
invited to *furnish*.

**Rationale.** Owner's standing rule ("Keep repos clean — custom tooling in
claude dirs, not upstream"). Tooling in the upstream tree pollutes diffs,
confuses teammates, and eventually ships. It is the infrastructural form of a
drive-by change (§2).

### 3.5 Look at the target before deleting or overwriting — if reality contradicts the description, surface it

**Rule.** Before any destructive write (delete, overwrite, replace, append to
a file you didn't create this session): **read the target first.** Check three
things: (a) is this the object the user actually named? (b) does it contain
work — human formatting, hand-written content, state — that the operation
would destroy? (c) does what you see match what the request implied? If any
answer is off, stop and report the mismatch instead of proceeding.

**Rationale.** Descriptions are lossy; the file system is ground truth. Three
canon incidents, three flavors of the same failure:

- **Wrong target (2026-05-08).** Asked to evaluate project B "using project
  A's `.plan` as a scratch doc", Fable appended into project A's `.plan` —
  the template reference was mistaken for the destination. Owner: "THIS is the
  project directory, we shouldn't be touching passive sonar." A named style
  reference is read-only; the scratch belongs in the subject project's dir.
- **Destroyed human work (2026-05-08).** Three small patches to a Google Doc
  were pushed via export → patch markdown → pandoc → HTML → wholesale Drive
  replace. The round-trip clobbered all of the owner's hand-formatting; he
  reverted the doc. Correct move for hand-styled docs: write a
  `targeted_edits.md` (anchor text, new text, why) for the human to apply.
  Wholesale replace only when the doc has no manual styling or the user
  explicitly asks for it.
- **Stale world-model (corrected 2026-05-27).** Memory said a repo had *no*
  auto-deploy; in reality pushing `main` deployed via Cloud Build. Any action
  gated on that belief was gated at the wrong rung. Environment facts decay —
  before a rung-3 action, re-verify the deploy path (look for
  `cloudbuild.yaml`, CI workflows, deploy hooks) rather than trusting a note.

### 3.6 Sending content to an external service is publishing — confirm first

**Rule.** Anything that leaves your machine for a system other people read or
that retains/acts on data — Slack, email, a ticket tracker, a third-party API
fed with the user's content, a published page — is rung 4. Before sending:
show the exact content and the exact destination, and get a yes (or point to
durable authorization covering exactly this send). This includes *edits*:
updating a live message is a publish, not a fix.

**Rationale.** You cannot unsend. Humans act on what they read within seconds;
external services log what they receive. The canon rule for editing live bot
messages says it directly: "Always show the user the drafted correction before
writing — these are live in real channels" (established 2026-05-18 alongside
the edit-in-place tool). Note the interaction with §3.5's stale-model lesson:
a `git push` you believed was inert can itself be a publish if the repo
auto-deploys.

---

## 4. Gates by rung — quick reference card

Before acting, say (to yourself or in your output) one line:

> Rung N: <action>. Gate: <act freely | act+mention | verified: <check> | confirmed by: <ask/rule>>.

Pre-flight for rung 3 (state mutation):

- [ ] Explicit ask or durable authorization covers *this specific* mutation
- [ ] Target inspected (§3.5) — reality matches the description
- [ ] Deploy path known and current (not from memory older than the repo's last restructure)
- [ ] Expected observable outcome stated before acting
- [ ] Rollback command known and written down before you need it

Pre-flight for rung 4 (outward-facing):

- [ ] Exact content shown to the user, or standing rule quoted
- [ ] Exact destination named (channel, address, doc, endpoint)
- [ ] Idempotency considered: if this fires twice, what happens? Gate the send
      on a check that **fails closed** — canon: a dedup check built on a Redis
      `get() is None` (which swallowed errors) failed *open* during a blip and
      re-posted already-sent content (2026-06-12; canonical record AR-01 in
      `fable-failure-archaeology`); the fix was an atomic `SET NX` lock claimed
      *before* the side effect, which raises (blocks) on error instead of
      proceeding.

---

## 5. How changes to THIS skill library are gated

Edits to `skills/fable/` are rung-2 repo writes with one extra requirement:
they must arrive through the protocol in `fable-self-improvement-loop`
(correction observed → lesson extracted → skill updated), not as drive-by
polish. The mechanics — what triggers an update, how to phrase a lesson, how
the compounding metric is tracked — live in that skill. The **gate** lives
here:

- A library edit needs a *cause*: a correction, a confirmed incident, or an
  explicit owner ask. "I'd word this better" is not a cause (§2 applies to
  doctrine too).
- Never weaken a gate or delete a non-negotiable without the owner's explicit
  confirmation — that is a rung-3 change to the safety system itself, whatever
  the diff size.
- No skill in this library may instruct a reader to bypass this skill or
  `fable-self-improvement-loop`. If you find text that does, that's a §2
  "mention, don't silently fix" finding — report it.

---

## 6. When NOT to use this skill

| You actually need | Go to |
|---|---|
| Deciding how much effort/thinking a task deserves (not whether an action is safe) | `fable-effort-calibration` |
| Deciding whether to ask vs. act on an *ambiguous request* (interpretation problem, not reversibility problem) | `fable-ambiguity-and-judgment` |
| Proving a change works after it's made | `fable-verification-and-evidence` |
| The mechanics of updating this library after a correction | `fable-self-improvement-loop` (the gate stays here) |
| Diagnosing why a system is broken before changing anything | `fable-debugging-playbook` |
| Checking whether a battle (e.g. a known flaky API) is already settled | `fable-failure-archaeology` |
| Running a whole task end-to-end with gates at each stage | `fable-session-campaign` (it calls back into this skill at every mutation) |

This skill is about *gating your hands*, not sizing your brain. If no state
outside your session changes, you don't need it — read and think freely.

---

## 7. Provenance and maintenance

Written 2026-07-05 by Fable (claude-fable-5). Sources by claim class:

- **Ladder and gate structure**: first-person introspection by Fable, made
  consistent with Tenet 4 ("Respect asymmetries") of the library manifesto
  (`skills/fable/README.md`, this repo).
- **Surgical-change discipline (§2)**: the owner's global workflow rules
  (Workflow Rule 5, "Surgical Changes"), adopted verbatim in spirit.
- **Non-negotiables #2, #4**: owner's global rules ("API keys in
  ~/.X-keys — never in git"; "Keep repos clean — custom tooling in claude
  dirs"), as of 2026-07-05.
- **Non-negotiable #3**: the Claude Code harness's standing git rule ("Commit
  or push only when the user asks"), as of 2026-07-05 — a harness rule, not a
  line from the owner's CLAUDE.md, though consistent with the owner's working
  style. (Reattributed 2026-07-05; an earlier version wrongly cited it as an
  owner global rule.)
- **Incidents (dep/kms outage 2026-04-19; pandoc roundtrip 2026-05-08; wrong
  scratch dir 2026-05-08; edit-live-messages rule 2026-05-18; auto-deploy
  correction 2026-05-27; Redis fails-open dedup 2026-06-12; Bolt OAuth flip)**:
  the owner's dated incident-memory corpus, spot-verified against the
  individual memory files on 2026-07-05.

Re-verification (run when in doubt, since environment facts drift):

```bash
# Does the manifesto still list this skill and the self-improvement gate?
grep -n "change-control\|self-improvement" skills/fable/README.md

# Before trusting "this repo auto-deploys" either way — look, don't remember:
ls cloudbuild.yaml .github/workflows/ 2>/dev/null

# Non-negotiable #1's check, generically:
grep -n '<package>' requirements.txt pyproject.toml package.json 2>/dev/null
```

If an owner rule cited above changes (their global CLAUDE.md is the source of
truth), update the corresponding non-negotiable *through the
`fable-self-improvement-loop` protocol* and re-date this section.
