"""Compare actual phone potato logits with frozen ONNX on matching Dart inputs."""
from pathlib import Path
import json

import numpy as np
import onnxruntime as ort

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'ml/artifacts/classwise_app_audit_20260906'


def main():
    report = json.loads((ART/'device_report.json').read_text())
    calibration = json.loads((ROOT/'app/assets/models/potato_field_v3_efficientnet_b0.metadata.json').read_text())['calibration']
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(ROOT/'ml/artifacts/potato_field_v3_dg_rotation_1_oe003/efficientnet_b0/potato-efficientnet_b0-9e1854e4dabf.onnx'),sess_options=options,providers=['CPUExecutionProvider'])
    rows = []
    for row in report['rows']:
        if row['crop'] != 'potato':
            continue
        tensor = np.fromfile(ART/f"host_inputs/{row['id']}.f32",dtype='<f4').reshape(224,224,3).transpose(2,0,1)[None]
        validity,condition = session.run(None,{'image':tensor})
        def softmax(values, temperature):
            scaled = np.asarray(values,dtype=np.float64)/temperature
            exponents = np.exp(scaled-scaled.max())
            return exponents/exponents.sum()
        vp = softmax(validity[0],calibration['validityTemperature'])
        cp = softmax(condition[0],calibration['conditionTemperature'])
        scaled = condition[0].astype(np.float64)/calibration['conditionTemperature']
        energy = -calibration['conditionTemperature']*(scaled.max()+np.log(np.exp(scaled-scaled.max()).sum()))
        accepted = bool(vp[0]>=calibration['validityProbabilityMin'] and cp.max()>=calibration['conditionProbabilityMin'] and energy<=calibration['conditionEnergyMax'])
        rows.append({'id':row['id'],
                     'validity_max_error':float(np.abs(validity[0]-row['potato_validity_logits']).max()),
                     'condition_max_error':float(np.abs(condition[0]-row['potato_condition_logits']).max()),
                     'validity_argmax_same':int(validity[0].argmax())==int(np.argmax(row['potato_validity_logits'])),
                     'condition_argmax_same':int(condition[0].argmax())==int(np.argmax(row['potato_condition_logits']))})
        rows[-1]['gate_decision_same'] = accepted == (row['app_top'] is not None)
    summary = {'samples':len(rows),'maximum_logit_error':max(max(r['validity_max_error'],r['condition_max_error']) for r in rows),
               'validity_argmax_disagreements':sum(not r['validity_argmax_same'] for r in rows),
               'condition_argmax_disagreements':sum(not r['condition_argmax_same'] for r in rows),
               'gate_decision_disagreements':sum(not r['gate_decision_same'] for r in rows),
               'comparison':'Phone TFLite vs frozen desktop ONNX, same Dart image preparation', 'rows':rows}
    (ART/'native_parity.json').write_text(json.dumps(summary,indent=2))
    print(json.dumps({k:v for k,v in summary.items() if k!='rows'},indent=2))


if __name__ == '__main__':
    main()
