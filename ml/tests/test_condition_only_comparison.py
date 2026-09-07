import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from compare_condition_only_v6 import unsupported_breakdown


def test_unsupported_condition_cannot_hide_behind_invalid_image_count():
    frame = pd.DataFrame(
        [
            {"known": False, "validity_label": "usable_target_leaf", "accepted": True},
            *[
                {"known": False, "validity_label": "other_plant", "accepted": False}
                for _ in range(99)
            ],
            {"known": True, "validity_label": "usable_target_leaf", "accepted": True},
        ]
    )
    groups = {x["validity_label"]: x for x in unsupported_breakdown(frame)}
    assert groups["usable_target_leaf"]["count"] == 1
    assert groups["usable_target_leaf"]["observed_false_accept_rate"] == 1.0
    assert (
        groups["usable_target_leaf"]["role"] == "unsupported_condition_on_usable_leaf"
    )
    assert groups["other_plant"]["observed_false_accept_rate"] == 0.0
    assert sum(x["count"] for x in groups.values()) == 100


def test_no_unsupported_inputs_is_empty_not_zero_error_evidence():
    frame = pd.DataFrame(
        [
            {
                "known": True,
                "validity_label": "usable_target_leaf",
                "accepted": True,
            }
        ]
    )
    assert unsupported_breakdown(frame) == []
