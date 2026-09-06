"""Validate the complete phone report and generate classwise diagnostic evidence."""
from __future__ import annotations

import collections
import csv
import hashlib
import json
import math
from pathlib import Path
import statistics
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'ml/artifacts/classwise_app_audit_20260906'
LABEL_META = json.loads((ROOT / 'app/assets/models/plant_disease_experimental.metadata.json').read_text())
CLASSES = [x['key'] for x in LABEL_META['output']['labels'] if x['key'].split('_')[0] in ('maize','potato','tomato')]
POTATO_META = json.loads((ROOT/'app/assets/models/potato_field_v3_efficientnet_b0.metadata.json').read_text())


def label(key):
    return (key or 'Rejected / no match').replace('_',' ')


def pct(n, total):
    return f'{n}/{total} ({n/total:.1%})' if total else 'N/A (0 examples)'


def metric(rows, key):
    actual = [r for r in rows if r['label'] == key]
    tp = sum(r.get('app_top') == key for r in actual)
    fp = sum(r.get('app_top') == key and r['label'] != key for r in rows)
    fn = len(actual) - tp
    precision = tp/(tp+fp) if tp+fp else 0
    recall = tp/len(actual) if actual else 0
    return {'label':key,'n':len(actual),'correct':tp,
            'raw_condition_correct':sum(r['raw_condition_top']==key for r in actual),
            'wrong':sum(r.get('app_top') is not None and r.get('app_top') != key for r in actual),
            'rejected':sum(r.get('app_top') is None for r in actual),
            'gallery_correct':sum(r.get('gallery_app_top') == key for r in actual),
            'gallery_blocked':sum(r['gallery_disposition'].startswith('blocked') for r in actual),
            'blur_warning':sum(r['gallery_disposition']=='blur_warning_requires_confirmation' for r in actual),
            'top3':sum(key in [p['label'] for p in r.get('ranked',[])[:3]] for r in actual),
            'precision':precision,'recall':recall,'f1':2*precision*recall/(precision+recall) if precision+recall else 0,
            'confusions':dict(collections.Counter(r.get('app_top') or 'REJECT' for r in actual if r.get('app_top') != key))}


def main():
    manifest = json.loads((ART/'manifest.json').read_text())
    report = json.loads((ART/'device_report.json').read_text())
    parity = json.loads((ART/'native_parity.json').read_text())
    rows = report['rows']
    expected = {r['id']:r for r in manifest['samples']}
    apk = ART/'krishidoc-classwise-audit.apk'
    receipt = {'audit_apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
               'manifest_sha256':hashlib.sha256((ART/'manifest.json').read_bytes()).hexdigest(),
               'device_report_sha256':hashlib.sha256((ART/'device_report.json').read_bytes()).hexdigest(),
               'native_platform_version':report['platform_version'],'models':{}}
    with zipfile.ZipFile(apk) as archive:
        for name,metadata in [('global',LABEL_META),('potato',POTATO_META)]:
            entry = 'assets/flutter_assets/'+metadata['artifact']['path']
            digest = hashlib.sha256(archive.read(entry)).hexdigest()
            assert digest == metadata['artifact']['sha256'], f'{name} model payload mismatch'
            receipt['models'][name] = digest
    (ART/'execution_receipt.json').write_text(json.dumps(receipt,indent=2))
    assert report['complete'] and report['expected_count'] == len(expected) == len(rows) == 320
    assert len({r['id'] for r in rows}) == len(rows)
    assert report['audit_id'] == manifest['audit_id']
    for row in rows:
        source = expected[row['id']]
        assert row['label'] == source['condition_label'] and row['photo_sha256'] == source['sha256']
        assert 'error' not in row, row
        assert row.get('state') != 'confident', 'Experimental confidence policy unexpectedly bypassed'
        row['source_file'] = source['local_path']
        row['group_id'] = source['group_id']
        row['top3_labels'] = [p['label'] for p in row.get('ranked',[])[:3]]
        row['raw_condition_top'] = row['global_top']
        if row['crop']=='potato':
            calibration = POTATO_META['calibration']
            def softmax(values, temperature):
                scaled = [x/temperature for x in values]
                exponentials = [math.exp(x-max(scaled)) for x in scaled]
                return [x/sum(exponentials) for x in exponentials]
            validity = softmax(row['potato_validity_logits'],calibration['validityTemperature'])
            condition = softmax(row['potato_condition_logits'],calibration['conditionTemperature'])
            scaled = [x/calibration['conditionTemperature'] for x in row['potato_condition_logits']]
            energy = -calibration['conditionTemperature']*(max(scaled)+math.log(sum(math.exp(x-max(scaled)) for x in scaled)))
            row['raw_condition_top'] = POTATO_META['outputs'][1]['labels'][condition.index(max(condition))]
            row['potato_validity_top'] = POTATO_META['outputs'][0]['labels'][validity.index(max(validity))]
            row['potato_usable_probability'] = validity[0]
            row['potato_condition_probability'] = max(condition)
            row['potato_energy'] = energy
            row['failed_gates'] = [name for name,failed in (
                ('usable_leaf',validity[0]<calibration['validityProbabilityMin']),
                ('condition_probability',max(condition)<calibration['conditionProbabilityMin']),
                ('energy',energy>calibration['conditionEnergyMax'])) if failed]
            assert bool(row['failed_gates']) == (row.get('app_top') is None)
    lab = [r for r in rows if r['split']=='balanced_lab_diagnostic']
    field = [r for r in rows if r['split']=='field_development_stress']
    assert collections.Counter(r['label'] for r in lab) == {k:15 for k in CLASSES}
    classes = [metric(lab,key) for key in CLASSES]
    crops = {}
    for crop in ('tomato','maize','potato'):
        subset = [r for r in lab if r['crop']==crop]
        members = [m for m in classes if m['label'].startswith(crop+'_')]
        suggestions = [r for r in subset if r['crop_suggestion_raw'] is not None]
        crops[crop] = {'n':len(subset),'correct':sum(r['app_top']==r['label'] for r in subset),
                       'rejected':sum(r['app_top'] is None for r in subset),
                       'macro_f1':statistics.mean(m['f1'] for m in members),
                       'suggestions':len(suggestions),
                       'correct_suggestions':sum(r['crop_suggestion_raw']==crop for r in suggestions),
                       'median_diagnosis_ms':statistics.median(r['diagnosis_ms'] for r in subset)}
    field_known = [r for r in field if r['label'] in CLASSES]
    field_unknown = [r for r in field if r['crop'] in crops and r['label'] not in CLASSES]
    field_other = [r for r in field if r['crop'] not in crops]
    field_metrics = {crop:{'n':sum(r['crop']==crop for r in field_known),
                           'correct':sum(r['crop']==crop and r.get('app_top')==r['label'] for r in field_known),
                           'rejected':sum(r['crop']==crop and r.get('app_top') is None for r in field_known)} for crop in crops}
    wrong = [r for r in lab if r.get('app_top') and r['app_top'] != r['label']]
    high_wrong = [r for r in wrong if r.get('ranked') and r['ranked'][0]['probability'] >= .9]
    suspicious_healthy = [r for r in rows if r['label'] in CLASSES and not r['label'].endswith('_healthy') and (r.get('app_top') or '').endswith('_healthy')]
    potato_lab = [r for r in lab if r['crop']=='potato']
    potato_details = {'n':len(potato_lab),
                      'raw_condition_correct':sum(r['raw_condition_top']==r['label'] for r in potato_lab),
                      'legacy_global_raw_correct':sum(r['global_top']==r['label'] for r in potato_lab),
                      'rejected_despite_correct_raw_condition':sum(r['raw_condition_top']==r['label'] and r['app_top'] is None for r in potato_lab),
                      'failed_gates':dict(collections.Counter(g for r in potato_lab for g in r['failed_gates'])),
                      'validity_predictions':dict(collections.Counter(r['potato_validity_top'] for r in potato_lab))}
    summary = {'audit_id':report['audit_id'],'complete':True,'total_images':len(rows),
               'lab':{'n':len(lab),'correct':sum(r['app_top']==r['label'] for r in lab),'by_crop':crops,'by_class':classes},
               'field':{'known':field_metrics,'unknown_condition_n':len(field_unknown),
                        'unknown_condition_accepted':sum(r.get('app_top') is not None for r in field_unknown),
                        'other_crop_n':len(field_other),'other_crop_suggestions':sum(r.get('crop_suggestion_raw') is not None for r in field_other)},
               'wrong_with_score_at_least_0_9':len(high_wrong),
               'potato_diagnosis':potato_details,
               'diseased_label_predicted_healthy_ids':[r['id'] for r in suspicious_healthy]}
    (ART/'summary.json').write_text(json.dumps(summary,indent=2))
    with (ART/'per_image_results.csv').open('w',newline='',encoding='utf-8-sig') as stream:
        columns = ['id','split','crop','label','app_top','state','gallery_disposition','gallery_app_top',
                   'crop_suggestion_raw','crop_suggestion_shown','global_top','global_score','top3_labels',
                   'raw_condition_top','potato_validity_top','potato_usable_probability','potato_condition_probability',
                   'potato_energy','failed_gates','diagnosis_ms','global_ms','elapsed_ms','source_file','group_id','photo_sha256']
        writer = csv.DictWriter(stream,fieldnames=columns,extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)
    with (ART/'per_class_results.csv').open('w',newline='',encoding='utf-8-sig') as stream:
        writer = csv.DictWriter(stream,fieldnames=list(classes[0]))
        writer.writeheader()
        writer.writerows(classes)

    lines = ['# In-app classwise disease-model audit — 6 September 2026','',
             '## Executive result','',
             f"**320/320 photos completed on the connected Realme RMX3741 using an Android release diagnostic app and the production classification providers; zero processing errors.** The balanced test contains exactly 15 images for each of the 17 classes. The additional 65 field images are reported separately. No model weights, thresholds or normal-app features were changed during this evaluation.",'',
             '| Plant | Classes × images | Correct top match | Rejected | Macro F1 | Median diagnosis time |',
             '| --- | ---: | ---: | ---: | ---: | ---: |']
    for crop,m in crops.items():
        lines.append(f"| {crop.title()} | {m['n']//15} × 15 | {pct(m['correct'],m['n'])} | {m['rejected']} | {m['macro_f1']:.3f} | {m['median_diagnosis_ms']:.0f} ms |")
    lines += ['', '**These are diagnostic results, not Nepal field-accuracy claims.** PlantVillage likely overlaps the legacy model’s training data. The field cohort was previously used in development and contains only a few known-condition examples. Labels are supplied by the datasets, not newly certified by an agronomist. Fifteen examples per class are enough to expose some failures, not certify reliability.','',
              '## What “in the app” means','',
              '- Actual phone TensorFlow Lite execution in release mode, through `imagePreparationProvider`, `galleryQualityProvider`, and `classificationServiceProvider(crop)` from the app. Potato therefore uses EfficientNet; tomato/maize use the existing 38-class model with crop scoping. No fake classifier or desktop substitution.',
              '- The test supplies each photo’s correct crop, equivalent to the farmer confirming/correcting it. Crop-suggestion performance is measured separately so wrong suggestions do not silently contaminate disease-class scores.',
              '- This is an instrumented batch test, not 320 manual taps through the native gallery picker or tests of live camera focus/exposure. Public input files enter the shared app preparation path directly. Native picker resizing before that path is not tested.',
              '- Raw model checking also runs for images the gallery would block, to distinguish model failure from image-quality refusal. “Gallery correct” below counts a block as unsuccessful and assumes the user explicitly proceeds after a blur-only warning.',
              '- Every app output remains a possible match (`uncertain`) or a refusal. A correct possible match counts as top-1 recognition; uncertainty is not falsely counted as an incorrect class. Model probabilities are uncalibrated scores, not correctness guarantees.',
              '- The isolated `com.krishidoc.app.modelaudit` package never replaced normal `com.krishidoc.app`. Screen locking does not intentionally stop batch computation. Results were saved after every photo.','',
              '## All 17 classes — 15 images each','',
              '| Class | Correct | Raw condition correct | Wrong class | Rejected | Gallery correct | Blur warnings | Top-3 includes label | Precision | Recall | F1 |',
              '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |']
    for m in classes:
        lines.append(f"| {label(m['label'])} | {m['correct']}/15 | {m['raw_condition_correct']}/15 | {m['wrong']} | {m['rejected']} | {m['gallery_correct']}/15 | {m['blur_warning']} | {m['top3']}/15 | {m['precision']:.3f} | {m['recall']:.3f} | {m['f1']:.3f} |")
    lines += ['', 'Precision/recall/F1 use the balanced cohort only; rejected cases are false negatives. Top-3 for potato is weak evidence because there are only three potato classes. Latency includes the app’s diagnosis preprocessing/inference, not photographer effort, and the first call includes warm-up.','',
              '## Exact class confusions','']
    for crop in crops:
        keys = [k for k in CLASSES if k.startswith(crop+'_')]
        short = lambda k: k.removeprefix(crop+'_').replace('_',' ') if k != 'REJECT' else 'Rejected'
        lines += [f'### {crop.title()}','', 'Rows are source labels; columns are the app’s top possible match.','',
                  '| Expected \\ predicted | ' + ' | '.join(short(k) for k in keys+['REJECT'])+' |',
                  '| --- |'+' ---: |'*(len(keys)+1)]
        for key in keys:
            counts = collections.Counter(r.get('app_top') or 'REJECT' for r in lab if r['label']==key)
            lines.append('| '+short(key)+' | '+' | '.join(str(counts[k]) for k in keys+['REJECT'])+' |')
        lines.append('')
    lines += ['## Why the potato app refuses so many photos','',
              f"On the 45 balanced potato images, the disease head alone identifies **{potato_details['raw_condition_correct']}/45** correctly; **{potato_details['rejected_despite_correct_raw_condition']}** of those correct raw predictions are removed by the gate. This separates recognition errors from refusal errors.",
              '', 'Gate failures (an image can fail more than one): '+', '.join(f'{k}: {v}' for k,v in potato_details['failed_gates'].items())+'.',
              'Validity-head top classes: '+', '.join(f'{k}: {v}' for k,v in potato_details['validity_predictions'].items())+'.',
              '', f"For comparison only, the legacy global model’s raw top label is correct on **{potato_details['legacy_global_raw_correct']}/45** of these same potato photos. That is not an unbiased reason to switch back: PlantVillage likely overlaps its training data, and unknown-condition safety/field performance must also be compared.",
              '', 'A likely explanation is source/domain dependence in the potato validity head, which needs source-grouped validation and inspection of negative labels. That mechanism is a hypothesis; the measured facts are the raw scores and failed gates in the CSV. Raising acceptance without checking false positives would hide the symptom rather than establish reliability.','',
              f"**Native-versus-desktop check:** all {parity['samples']} potato inputs (45 balanced + 19 field) were also processed through the frozen ONNX export using matching Dart-prepared tensors. Maximum absolute logit difference: {parity['maximum_logit_error']:.8f}. Validity argmax disagreements: {parity['validity_argmax_disagreements']}; condition argmax disagreements: {parity['condition_argmax_disagreements']}; gate-decision disagreements: {parity['gate_decision_disagreements']}. Thus the rejection pattern is reproducible in the model, not a phone-only conversion/routing fault on these tested examples. This does not prove all possible images are numerically equivalent.",'',
              '## Crop recognition before confirmation','',
              '| Plant | Suggestion offered (raw) | Correct when offered | No suggestion |',
              '| --- | ---: | ---: | ---: |']
    for crop,m in crops.items():
        lines.append(f"| {crop.title()} | {m['suggestions']}/{m['n']} | {pct(m['correct_suggestions'],m['suggestions'])} | {m['n']-m['suggestions']} |")
    lines += ['', 'These are raw crop-suggestion opportunities. The UI suppresses suggestions for blur warnings/blocked photos; per-image CSV includes both raw and actually eligible suggestions. Correct-crop confirmation must remain mandatory.','',
              '## Separate field stress test','',
              '| Plant | Known-condition examples | Correct top match | Rejected |',
              '| --- | ---: | ---: | ---: |']
    for crop,m in field_metrics.items():
        lines.append(f"| {crop.title()} | {m['n']} | {pct(m['correct'],m['n'])} | {m['rejected']} |")
    lines += ['', f"Unknown-condition images of supported crops incorrectly given a covered-condition match: **{pct(summary['field']['unknown_condition_accepted'],len(field_unknown))}**.",
              f"Other/unknown-crop field photos receiving a supported-crop suggestion: **{pct(summary['field']['other_crop_suggestions'],len(field_other))}**. These photos have no valid manual crop route; they are not credited as successful disease rejections simply because the test has no correct crop to select.",
              '', 'This cohort includes wide shots and multi-leaf photographs. Some are labelled usable by the source despite weak visual evidence at leaf scale; usability labels need review before retraining. Do not merge this cohort into the balanced laboratory score.','',
              '## Failures to inspect first','',
              f"{len(high_wrong)} wrong balanced-cohort predictions had a top score ≥0.90. This measures overconfident scores, not the UI’s confidence state.",
              f"Source-labelled disease images predicted healthy across both cohorts: {len(suspicious_healthy)}. IDs: {', '.join(str(r['id']) for r in suspicious_healthy) or 'none'}.",'',
              '| Image ID | Source cohort | Expected | App output | Score |',
              '| ---: | --- | --- | --- | ---: |']
    failures = sorted([r for r in rows if r['label'] in CLASSES and r.get('app_top') != r['label']],
                      key=lambda r: (not (r.get('app_top') or '').endswith('_healthy'), -(r.get('ranked') or [{'probability':0}])[0]['probability']))
    for r in failures[:25]:
        score = (r.get('ranked') or [{'probability':0}])[0]['probability']
        photo = expected[r['id']]['local_path'].replace('\\','/')
        lines.append(f"| [{r['id']}](../{photo}) | {r['split']} | {label(r['label'])} | {label(r.get('app_top'))} | {score:.3f} |")
    weakest = sorted(classes,key=lambda m:(m['recall'],m['f1']))[:5]
    lines += ['', '## Improvement priorities supported by this run','',
              '1. **Audit the weakest classes and their confusion pairs first.** The lowest recall classes are '+', '.join(f"{label(m['label'])} ({m['correct']}/15)" for m in weakest)+'. Inspect the exact failed photos in the CSV before attributing every mismatch to disease appearance. Verify tensor label order, source labels, crop routing, and pixel normalization against the pinned training/export artifacts.',
              '   - Potato: the usability head is the immediate bottleneck, but raw late-blight recognition is also weak (see the raw-condition column). Expand positive potato coverage across backgrounds, leaf scales, camera styles and sources; audit false “other plant” negatives. Keep a separate negative test set before recalibrating.',
              '   - Tomato mosaic virus: inspect the eight mosaic-labelled photos called Septoria. Verify source labels, then add difficult mosaic/Septoria/target-spot contrasts and evaluate per-class recall on unseen farms. Do not report a high average score that hides this class.',
              '2. **Prioritize false-healthy and unknown-condition acceptance.** These can falsely reassure farmers. Review the listed IDs, add independently labelled unknown disease/pest/nutrient/stress and non-leaf examples, and evaluate a separate crop/leaf-validity detector. Do not simply raise or lower a score threshold on these test images.',
              '3. **Address the field/laboratory gap with source-grouped data.** Collect close leaf photos plus difficult wide shots from Nepal, with independent expert labels, farm/plant grouping, device/lighting metadata and a locked test split. Existing public/lab results cannot establish field readiness. Re-review source-labelled “usable” whole-plot images.',
              '4. **Keep crop confirmation and cautious output.** Crop suggestions and disease classification are separate failure points. The existing model has no reliable explicit non-plant class; wrong-crop/non-plant refusal needs its own evaluated data and gate.',
              '5. **Only then train/compare candidates.** Use the failed-class review to design a training plan, calibrate on a separate set, and evaluate macro F1, per-class recall, false-healthy rate, unknown-condition false acceptance, and the exact release TensorFlow Lite app path. This audit is now development evidence, not a future untouched test set.',
              '', 'No retraining or threshold changes were performed for this report. A larger independent field test is required before selecting a “best” model.','',
              '## Evidence and reproducibility','',
              '- [Per-image results CSV](../ml/artifacts/classwise_app_audit_20260906/per_image_results.csv): every expected/predicted label, crop suggestion, gallery disposition, score, timing, source file, leaf group and SHA-256.',
              '- [Per-class metrics CSV](../ml/artifacts/classwise_app_audit_20260906/per_class_results.csv), [summary JSON](../ml/artifacts/classwise_app_audit_20260906/summary.json), [raw phone report](../ml/artifacts/classwise_app_audit_20260906/device_report.json), [input manifest](../ml/artifacts/classwise_app_audit_20260906/manifest.json). These are local ignored evaluation artifacts, not bundled app assets.',
              '- Original lab source: [PlantVillage](https://github.com/spMohanty/PlantVillage-Dataset), pinned at `7f7ecc7e1eaca78107e3affe7cb5abd9427e139a`. Original RGB files only; deterministic SHA ordering and source leaf grouping when available. Git blob hashes and local SHA-256 verified. No exact image duplicates. 138/255 balanced examples have mapped source leaf groups; 117 use filename-based fallback groups, so full independence is not asserted.',
              f"- Phone model versions: `{report['global_model']}` and `{report['potato_model']}`. The audit APK and model payload hashes are retained in the execution receipt.",
              f"- Run timestamps (UTC): {report['started_at']} to {report['completed_at']}. Runtime: {report['runtime']}.",
              '- Recreate inputs with `ml/scripts/prepare_classwise_app_audit.py`; build the explicit `app/tool/labelled_model_audit_classwise.dart` target in release mode with real models enabled; verify the separate package ID; transfer `audit-input` to that package’s external files directory; launch; pull the completed report; run `ml/scripts/report_classwise_app_audit.py`.',
              '', 'The normal app installation and its records were not modified by this audit.']
    destination = ROOT/'docs/CLASSWISE_IN_APP_MODEL_REPORT_2026-09-06.md'
    destination.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(summary,indent=2))
    print(destination)


if __name__ == '__main__':
    main()
