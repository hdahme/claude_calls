# Claude Calls

Extract insights from meeting transcripts using Claude Code skills.

## Quick Start

```bash
# Point at a transcript, get a summary
/calls ~/Movies/meetily-recordings/Meeting\ 2026-01-21/transcripts.json

# Use a specific template
/calls ~/Movies/meetily-recordings/Meeting\ 2026-01-21/transcripts.json first-call
```

## Setup

### 1. Skill Installation

The skill lives at `~/Projects/.claude/skills/calls/skill.md`.

### 2. Install Cleanup Cron

Automatically delete recordings older than 24 hours:

```bash
# Make script executable
chmod +x ~/Projects/hack/claude_calls/scripts/cleanup-recordings.sh

# Add to crontab (runs hourly)
(crontab -l 2>/dev/null; echo "0 * * * * $HOME/Projects/hack/claude_calls/scripts/cleanup-recordings.sh") | crontab -

# Verify
crontab -l
```

Logs: `~/.local/log/meetily-cleanup.log`

## Templates

### General Purpose (`~/Projects/hack/claude_calls/templates/`)

| Template | Use Case |
|----------|----------|
| `executive-summary` | Leadership updates, high-level outcomes |
| `action-items` | Extract todos with owners and deadlines |
| `decisions` | Document decisions with rationale |
| `stakeholder-update` | Async summary for people not on call |
| `coaching` | Communication analysis and feedback |
| `sales-intel` | Customer call analysis, objections, signals |
| `technical` | Engineering decisions, architecture, TODOs |

### VC / Investing (`~/.cursor/call_transcript_templates/`)

| Template | Use Case |
|----------|----------|
| `first-call` | First founder call - full diligence framework |
| `tech-diligence-call` | Deep technical diligence |
| `customer-reference` | Customer reference call analysis |
| `portfolio-company-catch-up` | Portfolio company updates |
| `investor-catchup` | Investor-to-investor catch-up |
| `interview` | Hiring interview scorecard |
| `generic` | Follow-up call with existing context |

## Output

- Written to `summary.md` in the same directory as the transcript
- Formatted for Slack (`*bold*`, `_italic_`, `-` bullets)
- Maximum 1000 words for nuance density

## Transcript Formats

Supports:
- Meetily JSON (`transcripts.json`)
- Plain text transcripts
- Any text file with meeting content

## Creating New Templates

Add to either template directory:

```markdown
# Template Name

Brief description of the template purpose.

## Instructions
- What to extract
- How to format

## Output Sections
- *Section One*
- *Section Two*
```

## Project Structure

```
~/Projects/hack/claude_calls/
├── README.md
├── templates/                          # General purpose
│   ├── executive-summary.md
│   ├── action-items.md
│   ├── decisions.md
│   ├── stakeholder-update.md
│   ├── coaching.md
│   ├── sales-intel.md
│   └── technical.md
└── scripts/
    └── cleanup-recordings.sh

~/Projects/.cursor/call_transcript_templates/   # VC-specific
├── first_call.md
├── tech_diligence_call.md
├── customer_reference.md
├── portfolio_company_catch_up.md
├── investor_catchup.md
├── interview.md
└── generic.md

~/Projects/.claude/skills/calls/
└── skill.md
```
