"""UUIDv7 minting (D-28).

Time-ordered identifiers keep index locality without being sequentially
predictable, which is why the schema uses them for primary keys. Python's
stdlib gains `uuid.uuid7` in a later release; until then this is the whole
implementation, per RFC 9562 layout:

    unix_ts_ms (48 bits) | ver=7 (4) | rand_a (12) | var=0b10 (2) | rand_b (62)
"""

from __future__ import annotations

import os
import time
import uuid


def uuid7() -> uuid.UUID:
    timestamp_ms = time.time_ns() // 1_000_000
    random_bytes = os.urandom(10)

    value = timestamp_ms << 80
    value |= 0x7 << 76
    value |= (random_bytes[0] & 0x0F) << 72
    value |= random_bytes[1] << 64
    value |= 0b10 << 62
    value |= int.from_bytes(random_bytes[2:], "big") & ((1 << 62) - 1)

    return uuid.UUID(int=value)
