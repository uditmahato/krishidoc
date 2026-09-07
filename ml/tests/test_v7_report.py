import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from summarize_potato_v7 import known_summary


def test_refusals_cannot_be_counted_as_perfect_disease_accuracy():
    frame = pd.DataFrame(
        [
            {
                "known": True,
                "condition_label": label,
                "raw_condition": label,
                "accepted": False,
                "correct": False,
                "wrong_accepted": False,
            }
            for label in ["potato_early_blight", "potato_late_blight", "potato_healthy"]
        ]
    )
    summary = known_summary(frame)
    assert summary["raw_macro_f1"] == 1.0
    assert summary["accepted_macro_f1"] == 0.0
    assert summary["worst_accepted_recall"] == 0.0
    assert summary["known_acceptance_rate"] == 0.0


def test_group_report_exposes_repeated_view_weighting():
    import pandas as pd
    from summarize_potato_v7 import group_diagnostics

    frame = pd.DataFrame(
        {
            "known": [True] * 4,
            "condition_label": ["potato_early_blight"] * 4,
            "group_id": ["a", "a", "a", "b"],
            "correct": [True, True, True, False],
        }
    )
    result = group_diagnostics(frame)["potato_early_blight"]
    assert result["images"] == 4
    assert result["proxy_groups"] == 2
    assert result["image_weighted_accepted_recall"] == 0.75
    assert result["equal_group_accepted_recall"] == 0.5
