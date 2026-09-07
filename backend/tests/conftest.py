import pytest

from krishidoc.platform.config import Settings


@pytest.fixture()
def settings() -> Settings:
    """Test settings with an explicit key: nothing here reads the environment,
    so a developer's shell cannot change what the suite proves."""
    return Settings(
        token_signing_key="test-signing-key-that-is-long-enough-32",
        access_token_ttl_seconds=900,
        refresh_token_ttl_seconds=3600,
    )
