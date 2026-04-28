"""Environment-driven configuration via pydantic-settings.

All settings come from env vars (or `.env`). Missing required values fail
fast at startup with `ConfigError` so misconfiguration never silently
flows into a recipe run.
"""

from __future__ import annotations

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from .errors import ConfigError


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    holo3_base_url: str = Field(default="", validation_alias="HOLO3_BASE_URL")
    holo3_model: str = Field(default="Hcompany/Holo3-35B-A3B", validation_alias="HOLO3_MODEL")
    holo3_api_key: str = Field(default="", validation_alias="HOLO3_API_KEY")

    vnc_host: str = Field(default="127.0.0.1", validation_alias="VNC_HOST")
    vnc_port: int = Field(default=5900, validation_alias="VNC_PORT")
    vnc_password: str = Field(default="", validation_alias="VNC_PASSWORD")

    libvirt_uri: str = Field(default="qemu:///system", validation_alias="LIBVIRT_URI")
    libvirt_domain: str = Field(default="win10-ltsc-nikonscan", validation_alias="LIBVIRT_DOMAIN")
    libvirt_snapshot: str = Field(
        default="nikonscan-installed", validation_alias="LIBVIRT_SNAPSHOT"
    )

    artifacts_dir: Path = Field(default=Path("artifacts"), validation_alias="ARTIFACTS_DIR")
    recordings_dir: Path = Field(default=Path("recordings"), validation_alias="RECORDINGS_DIR")
    baselines_dir: Path = Field(default=Path("baselines"), validation_alias="BASELINES_DIR")

    log_level: str = Field(default="INFO", validation_alias="LOG_LEVEL")
    log_format: str = Field(default="json", validation_alias="LOG_FORMAT")


def load_settings() -> Settings:
    """Load settings; raise `ConfigError` for the agent-loop entry points
    that need a Holo3 endpoint. CLI subcommands like `vm status` that don't
    use Holo3 should call `Settings()` directly to avoid the check.
    """
    settings = Settings()
    if not settings.holo3_base_url:
        raise ConfigError(
            "HOLO3_BASE_URL is required for agent-loop operations. "
            "See docs/holo3-endpoint.md for setup."
        )
    return settings
