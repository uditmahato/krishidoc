import pytest

from ml.scripts.audit_manifest import ManifestAuditError, audit_manifest
from ml.tests.test_audit_manifest import (
    TAXONOMY,
    _prepared_manifest,
    _read_rows,
    _write_rows,
)


def test_parallel_matches_serial_and_rejects_modified_hashes(tmp_path):
    manifest, aliases, config = _prepared_manifest(tmp_path)
    kwargs = {"aliases_path": aliases, "config_path": config, "verify_images": True}
    assert audit_manifest(
        manifest, TAXONOMY, image_workers=4, **kwargs
    ) == audit_manifest(manifest, TAXONOMY, **kwargs)
    rows = _read_rows(manifest)
    rows[0]["sha256"] = "0" * 64
    _write_rows(manifest, rows)
    for workers in (1, 4):
        with pytest.raises(ManifestAuditError, match="SHA256 mismatch"):
            audit_manifest(manifest, TAXONOMY, image_workers=workers, **kwargs)


@pytest.mark.parametrize("workers", [0, 17, True, 1.5])
def test_rejects_invalid_worker_count(tmp_path, workers):
    with pytest.raises(ManifestAuditError, match="image_workers"):
        audit_manifest(tmp_path / "missing.csv", TAXONOMY, image_workers=workers)
