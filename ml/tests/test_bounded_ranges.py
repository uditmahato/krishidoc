import pytest

from ml.scripts.download_bounded_ranges import validate_range


def test_exact_response_required():
    validate_range(206, "bytes 4-7/10", 4, 7, 10, 4)


@pytest.mark.parametrize(
    "status,header,length",
    [
        (200, "bytes 4-7/10", 4),
        (206, "bytes 0-3/10", 4),
        (206, "bytes 4-7/11", 4),
        (206, "bytes 4-7/10", 3),
        (206, None, 4),
    ],
)
def test_reject_ignored_wrong_or_truncated_ranges(status, header, length):
    with pytest.raises(ValueError, match="Invalid range"):
        validate_range(status, header, 4, 7, 10, length)
