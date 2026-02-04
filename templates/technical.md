# Technical Summary

## Purpose
Extract technical decisions, architecture discussions, and engineering TODOs.

## Prompt

Analyze this technical meeting transcript for engineering-relevant information.

<transcript>
{{TRANSCRIPT}}
</transcript>

*Technical Decisions*
For each decision:
- What was decided
- Alternatives considered
- Trade-offs discussed
- Owner for implementation

*Architecture Changes*
- Systems or components affected
- New patterns or approaches adopted
- Deprecations or removals planned

*Technical Debt*
- Shortcuts taken with awareness
- Items explicitly called out as debt
- Timeline for addressing

*TODOs & Tasks*
- Implementation tasks identified
- Bug fixes mentioned
- Refactoring needed

*Dependencies*
- External systems/APIs involved
- Team dependencies
- Blocking vs. non-blocking

*Open Technical Questions*
- Unresolved design decisions
- Areas needing investigation
- Spikes or POCs needed

*Risk & Complexity*
- High-risk changes identified
- Complexity concerns raised
- Testing/rollout considerations

*Documentation Needed*
- ADRs to write
- Runbooks to update
- API changes to document

Format for Slack:
- Use `*bold*` for section headers
- Use backticks for `code`, `functions`, `systems`
- Be specific about file paths, endpoints, etc.
- Maximum 1000 words
