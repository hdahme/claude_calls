---
name: calls
description: Extract insights from meeting transcripts using customizable templates. Point at a transcript, pick a template, get a Slack-ready summary.
tools: Bash, Read, Write, Glob
args: <transcript_path> [template_name]
user-invocable: true
---

# Calls - Meeting Transcript Analyzer

Extract maximum nuance from meeting transcripts using specialized templates.

## Usage

```bash
/calls ~/Movies/meetily-recordings/Meeting\ 2026-01-21/transcripts.json action-items
/calls /path/to/transcript.txt first-call
```

## Arguments

1. `transcript_path` (required) - Path to the transcript file (JSON from Meetily or plain text)
2. `template_name` (optional) - Template to use. Defaults to `executive-summary`

## Available Templates

### General Purpose (`claude_calls/templates/`)

| Template | Purpose |
|----------|---------|
| `executive-summary` | High-level summary for leadership |
| `action-items` | Extract todos, owners, deadlines |
| `decisions` | Document decisions made and rationale |
| `stakeholder-update` | Summary for people not on the call |
| `coaching` | Communication and leadership analysis |
| `sales-intel` | Extract sales signals and objections |
| `technical` | Technical decisions, architecture, TODOs |

### VC / Investing (`call_transcript_templates/`)

| Template | Purpose |
|----------|---------|
| `first-call` | First founder call - full diligence framework |
| `tech-diligence-call` | Deep technical diligence |
| `customer-reference` | Customer reference call analysis |
| `portfolio-company-catch-up` | Portfolio company updates |
| `investor-catchup` | Investor-to-investor catch-up |
| `interview` | Hiring interview scorecard |
| `generic` | Follow-up call with existing context |

## Workflow

### Step 1: Load Transcript

Read the transcript file. Handle both JSON (Meetily format) and plain text.

For Meetily JSON:
```json
{
  "segments": [
    {"speaker": "Speaker 1", "text": "...", "start": 0.0, "end": 5.0}
  ]
}
```

For plain text, use as-is.

### Step 2: Load Template

Search for template in order:
1. `/Users/hd/Projects/.cursor/call_transcript_templates/{template}.md`
2. `/Users/hd/Projects/hack/claude_calls/templates/{template}.md`

Template names are case-insensitive and accept hyphen/underscore variants:
- `first-call` = `first_call` = `first_call.md`
- `tech-diligence-call` = `tech_diligence_call`

### Step 3: Apply Template

Process the transcript through the template prompt. The template contains the extraction instructions.

For templates with `{{TRANSCRIPT}}` placeholder, substitute the transcript content.
For VC templates (raw prompts), prepend the transcript and apply the template.

### Step 4: Output Summary

Write output to `summary.md` in the *same directory* as the transcript.

**CRITICAL**: Format for Slack mrkdwn:
- Use `*bold*` not `**bold**`
- Use `_italic_` not `*italic*`
- Use `-` for bullets, no nesting beyond 2 levels
- Code blocks with triple backticks work
- No headers (#) - use `*Section Name*` with bold instead
- Keep under 1000 words for maximum nuance density

## Example Output Path

Input: `~/Movies/meetily-recordings/Meeting 2026-01-21/transcripts.json`
Output: `~/Movies/meetily-recordings/Meeting 2026-01-21/summary.md`

## Template Directories

| Location | Purpose |
|----------|---------|
| `/Users/hd/Projects/.cursor/call_transcript_templates/` | VC-specific templates |
| `/Users/hd/Projects/hack/claude_calls/templates/` | General purpose templates |

## Template Development

General templates use this format:
```markdown
# Template Name

## Purpose
What this template extracts

## Prompt
The actual extraction prompt with {{TRANSCRIPT}} placeholder
```

VC templates are raw prompts - just the instructions, the transcript will be prepended.
