"""Fixture for fails-open-scan.sh. Do not reformat: SKILL.md quotes line numbers.

Recreates the two canon incidents in miniature:
  - get() swallowing errors -> dedup fails open (2026-06-12 duplicate posts)
  - broad except around prompt() swallowing AttributeError (2026-04-21)
plus a correct fail-closed handler that must NOT be flagged.
"""


class RedisLike:
    def get(self, key):
        try:
            return self.client.get(key)
        except Exception:
            return None  # BAD: error indistinguishable from "missing key"

    def acquire_lock(self, key):
        try:
            return self.client.set(key, 1, nx=True, ex=600)
        except Exception:
            raise  # GOOD: fails closed — must NOT be flagged


def post_if_new(redis, slack, key):
    if redis.get(key) is None:  # fails-open gate...
        slack.chat_postMessage(channel="C123", text="episode!")  # ...on a side effect


def synthesize(self):
    try:
        return prompt(model=self.config.MODEL_SONNET)  # AttributeError at runtime
    except Exception as exc:
        logger.warning("synthesis failed: %s", exc)
        return None  # BAD: typo masked as generic failure


def narrow_ok(path):
    try:
        return open(path).read()
    except FileNotFoundError:
        return None  # narrow except: not flagged (by design)
