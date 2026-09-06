"""Frozen balanced diagnostic sample: 15 original photos per enabled app class.

Not a held-out accuracy benchmark: legacy-model PlantVillage overlap is likely.
No training, augmentation or threshold selection is performed.
"""
from __future__ import annotations

import collections
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import time
from urllib.parse import quote

from PIL import Image
import requests

ROOT = Path(__file__).resolve().parents[2]
REVISION = '7f7ecc7e1eaca78107e3affe7cb5abd9427e139a'
REPO = 'spMohanty/PlantVillage-Dataset'
DEST = ROOT / 'ml/artifacts/classwise_app_audit_20260906'
RAW = ROOT / 'ml/data/raw/plantvillage-audit-15-per-class'
INPUT = DEST / 'audit-input'
HEADERS = {'User-Agent': 'KrishiDoc-classwise-diagnostic-audit'}


def fetch(url):
    for attempt in range(4):
        try:
            response = requests.get(url, headers=HEADERS, timeout=(12,60))
            response.raise_for_status()
            return response.content
        except requests.RequestException:
            if attempt == 3:
                raise
            time.sleep(attempt + 1)


def tree(sha):
    cached = RAW / f'tree-{sha}.json'
    if not cached.exists():
        cached.write_bytes(fetch(f'https://api.github.com/repos/{REPO}/git/trees/{sha}'))
    return json.loads(cached.read_text())['tree']


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    INPUT.mkdir(parents=True, exist_ok=True)
    cache = RAW / 'selection.json'
    if cache.exists():
        selection = json.loads(cache.read_text())
        assert selection['revision'] == REVISION
    else:
        root = tree(REVISION)
        raw = tree(next(x['sha'] for x in root if x['path'] == 'raw'))
        color = tree(next(x['sha'] for x in raw if x['path'] == 'color'))
        leaf_map_bytes = fetch(f'https://raw.githubusercontent.com/{REPO}/{REVISION}/leaf-map.json')
        (RAW / 'leaf-map.json').write_bytes(leaf_map_bytes)
        leaf_map = json.loads(leaf_map_bytes)
        metadata = json.loads((ROOT / 'app/assets/models/plant_disease_experimental.metadata.json').read_text())
        classes = [x for x in metadata['output']['labels'] if x['key'].split('_')[0] in ('tomato','potato','maize')]
        selected = []
        for label in classes:
            folder = label['sourceLabel']
            node = next(x for x in color if x['path'].rstrip('_') == folder.rstrip('_'))
            files = [x for x in tree(node['sha']) if x['type'] == 'blob' and x['path'].lower().endswith(('.jpg','.jpeg','.png'))]
            files.sort(key=lambda x: hashlib.sha256(('kd-classwise-15:' + x['sha']).encode()).hexdigest())
            groups = set()
            count = 0
            for item in files:
                identifier = Path(item['path']).stem.split('___')[-1].split('copy')[0].strip().lower()
                matches = [s for s in leaf_map.get(identifier, []) if s.split(':::')[0].rstrip('_') == folder.rstrip('_')]
                group = matches[0] if len(matches) == 1 else f'fallback:{identifier}'
                if group in groups:
                    continue
                groups.add(group)
                selected.append({'crop':label['key'].split('_')[0], 'condition_label':label['key'],
                                 'validity_label':'usable_target_leaf', 'source_id':'plantvillage-original',
                                 'split':'balanced_lab_diagnostic', 'source_path':f"raw/color/{node['path']}/{item['path']}",
                                 'git_blob_sha1':item['sha'], 'group_id':group,
                                 'group_verified':not group.startswith('fallback:'),
                                 'source_revision':REVISION})
                count += 1
                if count == 15:
                    break
            if count != 15:
                raise ValueError(f'{folder}: only {count} distinct available groups')
            print(f"Selected 15: {label['key']}", flush=True)
        selection = {'revision':REVISION, 'samples':selected}
        cache.write_text(json.dumps(selection,indent=2))

    def download(entry):
        path = RAW / (entry['git_blob_sha1'] + Path(entry['source_path']).suffix.lower())
        if not path.exists():
            content = fetch(f'https://raw.githubusercontent.com/{REPO}/{REVISION}/' + quote(entry['source_path'],safe='/'))
            path.write_bytes(content)
        content = path.read_bytes()
        blob = hashlib.sha1(f'blob {len(content)}\0'.encode() + content).hexdigest()
        if blob != entry['git_blob_sha1']:
            raise ValueError(f'Git blob mismatch: {path}')
        with Image.open(path) as image:
            image.verify()
        return {**entry, 'sha256':hashlib.sha256(content).hexdigest(), 'local_path':str(path.relative_to(ROOT))}

    with ThreadPoolExecutor(max_workers=6) as pool:
        selected = list(pool.map(download, selection['samples']))
    # Previously consumed field-development photos are a separate stress cohort.
    previous = json.loads((ROOT / 'ml/artifacts/mobile_audit_20260906/manifest.json').read_text())
    for entry in previous['samples']:
        if entry['split'] == 'external_test':
            selected.append({**entry, 'split':'field_development_stress',
                             'local_path':entry['image_path'], 'group_verified':True})
    hashes = set()
    entries = []
    for index, entry in enumerate(selected):
        source = ROOT / entry['local_path']
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != entry['sha256'] or digest in hashes:
            raise ValueError(f'Changed or duplicate photo {source}')
        hashes.add(digest)
        name = f'{index:04d}{source.suffix.lower()}'
        shutil.copyfile(source, INPUT / name)
        entries.append({**entry, 'id':index, 'file':name})
    manifest = {'schema_version':2, 'audit_id':'classwise-15-20260906-v1',
                'sampling':'15/class, deterministic blob-hash ordering, source leaf grouping when available',
                'training_independent':False, 'promotion_eligible':False,
                'limitations':['PlantVillage training overlap likely for legacy model.',
                               'Field cohort previously used in development, not Nepal validation.',
                               'Source labels have not been newly reviewed by an agronomist.'],
                'samples':entries}
    encoded = json.dumps(manifest,indent=2)
    (INPUT / 'manifest.json').write_text(encoded)
    (DEST / 'manifest.json').write_text(encoded)
    print(json.dumps({'samples':len(entries),'class_counts':dict(collections.Counter(
        x['condition_label'] for x in entries if x['split']=='balanced_lab_diagnostic')),
        'verified_leaf_groups':sum(x.get('group_verified',False) for x in entries),
        'input_bytes':sum(x.stat().st_size for x in INPUT.iterdir())},indent=2))


if __name__ == '__main__':
    main()
