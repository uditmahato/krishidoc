"""Frozen ONNX model on tensors produced by the actual Dart image pipeline.

This is desktop inference, NOT native phone runtime verification.
"""
from __future__ import annotations

import collections
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort

from summarize_mobile_audit import reference_result

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = ROOT / 'ml/artifacts/mobile_audit_20260906'


def main():
    manifest = json.loads((ARTIFACTS / 'manifest.json').read_text())
    quality = {r['id']: r for r in json.loads((ARTIFACTS / 'host_inputs/quality.json').read_text())}
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(ROOT / 'ml/artifacts/potato_field_v3_dg_rotation_1_oe003/efficientnet_b0/potato-efficientnet_b0-9e1854e4dabf.onnx'), sess_options=options, providers=['CPUExecutionProvider'])
    rows = []
    for sample in manifest['samples']:
        tensor = np.fromfile(ARTIFACTS / f"host_inputs/{sample['id']}.f32", dtype='<f4').reshape(224,224,3).transpose(2,0,1)[None]
        validity, condition = session.run(None, {'image': tensor})
        mobile = {'reference_validity': validity[0].tolist(), 'reference_condition': condition[0].tolist()}
        rows.append({**sample, **quality[sample['id']], 'mobile_validity': mobile['reference_validity'],
                     'mobile_condition': mobile['reference_condition'], 'mobile_top': reference_result(mobile),
                     'reference_top': reference_result(sample)})
    def summarize(items):
        known = [r for r in items if r['crop'] == 'potato' and r['condition_label'] in ('potato_early_blight','potato_late_blight','potato_healthy') and r['validity_label'] == 'usable_target_leaf']
        ood = [r for r in items if r not in known]
        return {'samples': len(items), 'known_potato': len(known),
                'mobile_correct': sum(r['mobile_top'] == r['condition_label'] for r in known),
                'mobile_rejected': sum(r['mobile_top'] is None for r in known),
                'reference_correct': sum(r['reference_top'] == r['condition_label'] for r in known),
                'ood': len(ood), 'mobile_ood_accepted': sum(r['mobile_top'] is not None for r in ood),
                'reference_ood_accepted': sum(r['reference_top'] is not None for r in ood),
                'changed_decisions': sum(r['reference_top'] != r['mobile_top'] for r in items),
                'gallery_rejected_potato': sum(not r['gallery_quality_pass'] for r in known)}
    groups = collections.defaultdict(list)
    for row in rows:
        groups[row['split']].append(row)
    summary = {'execution': 'desktop ONNX CPU; actual Dart preprocessing; not phone TFLite',
               'promotion_eligible': False, 'overall': summarize(rows),
               'by_split': {k: summarize(v) for k,v in groups.items()}}
    (ARTIFACTS / 'host_report.json').write_text(json.dumps({'summary':summary, 'rows':rows},indent=2))
    print(json.dumps(summary,indent=2))


if __name__ == '__main__':
    main()
