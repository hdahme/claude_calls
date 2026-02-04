# Action Items

## Purpose
Extract all actionable items from the meeting with clear owners and deadlines.

## Prompt

Analyze this meeting transcript and extract all action items.

<transcript>
{{TRANSCRIPT}}
</transcript>

For each action item, identify:

*Action Items*

Format each as:
`[ ]` *Task* - Owner (Deadline if mentioned)

Group by:

*Immediate (This Week)*
- Items with urgent language or explicit near-term deadlines

*Soon (Next 2 Weeks)*
- Items mentioned for follow-up

*Backlog*
- Items mentioned but not prioritized

*Decisions Needed*
- Items blocked waiting for decisions
- Include who needs to make the decision

*Follow-ups Required*
- People to loop in
- Information to gather
- Meetings to schedule

*Unassigned*
- Action items mentioned without clear owner
- Flag these for assignment

Format for Slack:
- Use `*bold*` for section headers
- Use checkbox emoji or `[ ]` for items
- Keep each item to one line when possible
- Maximum 1000 words
