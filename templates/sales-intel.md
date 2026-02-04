# Sales Intelligence

## Purpose
Extract sales-relevant signals from customer/prospect calls. Objections, buying signals, competitive intel.

## Prompt

Analyze this sales/customer call transcript for actionable intelligence.

<transcript>
{{TRANSCRIPT}}
</transcript>

*Deal Summary*
- Current stage/status
- Key stakeholders mentioned
- Timeline indicators

*Buying Signals*
- Positive indicators (interest, urgency, budget mentions)
- Questions about implementation, pricing, next steps
- Comparisons to current state ("we're doing X now...")

*Objections & Concerns*
- Explicit objections raised
- Implicit hesitations (hedging language, "but...", "what if...")
- How objections were handled (effective/ineffective)

*Competitive Intel*
- Competitors mentioned
- Feature comparisons made
- What they like/dislike about alternatives

*Pain Points*
- Problems they're trying to solve
- Quantified impact ("costs us X", "takes Y hours")
- Emotional language around problems

*Champions & Blockers*
- Who's pushing for this internally?
- Who might block?
- Decision-making process revealed

*Follow-up Required*
- Questions left unanswered
- Information promised
- Next meeting/milestone

*Risk Assessment*
- Deal health: Strong / Needs Attention / At Risk
- Key risk factors
- Actions to de-risk

Format for Slack:
- Use `*bold*` for section headers
- Quantify where possible
- Maximum 1000 words
