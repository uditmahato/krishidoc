"""Runtime configuration.

Secrets come from the environment, which in production is Secret Manager
mounted via the CSI driver (D-37). Nothing here carries a usable default: a
signing key with a fallback value is the same class of mistake as V1's
committed API key, so an unset key fails at startup rather than silently
signing tokens anyone can forge.
"""

from __future__ import annotations

import os
from dataclasses import dataclass


class ConfigurationError(RuntimeError):
    """Raised when required configuration is missing or unusable."""


@dataclass(frozen=True)
class Settings:
    token_signing_key: str
    access_token_ttl_seconds: int = 900  # 15 minutes (D-13)
    refresh_token_ttl_seconds: int = 60 * 60 * 24 * 30  # 30 days (D-13)

    @staticmethod
    def from_env(environ: dict[str, str] | None = None) -> Settings:
        env = environ if environ is not None else dict(os.environ)
        key = env.get("KRISHIDOC_TOKEN_SIGNING_KEY", "")
        if len(key) < 32:
            raise ConfigurationError(
                "KRISHIDOC_TOKEN_SIGNING_KEY must be set to at least 32 characters"
            )
        return Settings(
            token_signing_key=key,
            access_token_ttl_seconds=int(env.get("KRISHIDOC_ACCESS_TOKEN_TTL_SECONDS", 900)),
            refresh_token_ttl_seconds=int(
                env.get("KRISHIDOC_REFRESH_TOKEN_TTL_SECONDS", 60 * 60 * 24 * 30)
            ),
        )
