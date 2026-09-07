import numpy as np

from krishidoc_ml.pipeline import _validation_source_diagnostics


def test_diagnostics_separate_small_source_and_do_not_count_ood_as_known():
    predictions = {
        "source_id": ["large", "small", "small"],
        "condition_targets": np.array([0, 0, -1]),
        "condition_logits": np.array([[2, 0], [0, 2], [2, 0]]),
        "validity_targets": np.array([0, 0, 4]),
        "validity_logits": np.array(
            [[2, 0, 0, 0, 0], [2, 0, 0, 0, 0], [0, 0, 0, 0, 2]]
        ),
    }
    result = _validation_source_diagnostics(predictions, ["early", "late"])
    assert result["large"]["raw_condition"]["early"] == {"count": 1, "correct": 1}
    assert result["small"]["raw_condition"]["early"] == {"count": 1, "correct": 0}
    assert result["small"]["raw_condition"]["late"]["count"] == 0
    assert result["small"]["validity_correct"] == 2
    assert _validation_source_diagnostics({}, []) == {}
