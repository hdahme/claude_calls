"""Fixture for truncation-check.sh. Do not reformat: SKILL.md quotes line numbers.

Recreates the two Slack canon incidents in miniature, plus a correct call.
"""


def fetch_thread_bad(client, channel, ts):
    # BAD: defaults to ~28 messages, no pagination -> silent truncation
    return client.conversations_replies(channel=channel, ts=ts)


def fetch_history_flaky(client, channel, cutoff_ts):
    # BAD: `oldest` returns 0 messages on ~80% of calls; no pagination loop either
    return client.conversations_history(
        channel=channel,
        oldest=cutoff_ts,
        limit=200,
    )


def fetch_thread_good(client, channel, ts):
    """Canonical pattern: limit=200 + next_cursor loop, age-filter client-side."""
    messages, cursor = [], None
    while True:
        resp = client.conversations_replies(
            channel=channel, ts=ts, limit=200, cursor=cursor
        )
        messages.extend(resp["messages"])
        cursor = resp.get("response_metadata", {}).get("next_cursor")
        if not cursor:
            break
    return messages
