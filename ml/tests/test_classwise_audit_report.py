"""Guard diagnostic metric denominators: refusals never disappear from recall."""
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location('classwise_report',Path(__file__).resolve().parents[1]/'scripts/report_classwise_app_audit.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def test_refusals_are_false_negatives_and_false_matches_reduce_precision():
    key = 'tomato_early_blight'
    rows = [
        {'label':key,'app_top':key,'raw_condition_top':key,'gallery_app_top':key,'gallery_disposition':'ready','ranked':[{'label':key}]},
        {'label':key,'app_top':None,'raw_condition_top':key,'gallery_app_top':None,'gallery_disposition':'ready','ranked':[]},
        {'label':'tomato_healthy','app_top':key,'raw_condition_top':key,'gallery_app_top':None,'gallery_disposition':'blocked_exposure','ranked':[{'label':key}]},
    ]
    result = module.metric(rows,key)
    assert result['n'] == 2
    assert result['correct'] == 1
    assert result['raw_condition_correct'] == 2
    assert result['rejected'] == 1
    assert result['precision'] == result['recall'] == result['f1'] == .5


def test_gallery_block_is_not_claimed_as_a_successful_photo_flow():
    key = 'potato_healthy'
    rows = [{'label':key,'app_top':key,'raw_condition_top':key,'gallery_app_top':None,
             'gallery_disposition':'blocked_exposure','ranked':[{'label':key}]}]
    result = module.metric(rows,key)
    assert result['correct'] == 1
    assert result['gallery_correct'] == 0
    assert result['gallery_blocked'] == 1
