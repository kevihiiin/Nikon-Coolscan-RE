"""Interactive recipe recorder.

Operator drives the VM manually (via virt-viewer or a separate VNC client);
the recorder periodically snapshots the framebuffer and records the diff
against the previous frame. The output is a JSONL file in `recordings/`
that `mcp_server.record_recipe` post-processes into a recipe skeleton.

This is deliberately minimal — it doesn't try to reverse-engineer mouse
clicks. The operator separately writes the click coordinates by inspecting
the saved screenshots, or hands the recording to Claude Code which uses
Holo3 grounding to extract candidate coordinates.

Output format (JSONL, one record per frame):
    {"ts": 1714190600.5, "frame": "frame-000.png", "phash": "..."}
"""

from __future__ import annotations

import asyncio
import json
import time
from pathlib import Path

import imagehash

from .errors import VmStateError
from .logging_setup import get_logger
from .vnc import VncClient

log = get_logger(__name__)


class RecipeRecorder:
    def __init__(self, vnc: VncClient, recordings_dir: Path) -> None:
        self._vnc = vnc
        self._dir = recordings_dir

    async def record(self, name: str, max_frames: int = 200, poll_s: float = 1.0) -> Path:
        """Record up to `max_frames` distinct frames from the VM.

        A frame is recorded only when its pHash differs from the previous
        recorded frame (avoids hundreds of identical idle screens).
        """
        out_dir = self._dir / name
        out_dir.mkdir(parents=True, exist_ok=True)
        manifest_path = out_dir / "manifest.jsonl"

        last_hash: imagehash.ImageHash | None = None
        recorded = 0
        log.info("recorder_start", name=name, dir=str(out_dir))

        with manifest_path.open("a", encoding="utf-8") as manifest:
            while recorded < max_frames:
                try:
                    img = self._vnc.capture()
                except VmStateError as e:
                    log.warning("recorder_capture_failed", error=str(e))
                    break

                ph = imagehash.phash(img)
                if last_hash is not None and (ph - last_hash) <= 2:
                    await asyncio.sleep(poll_s)
                    continue

                frame_name = f"frame-{recorded:03d}.png"
                img.save(out_dir / frame_name)
                manifest.write(
                    json.dumps({"ts": time.time(), "frame": frame_name, "phash": str(ph)}) + "\n"
                )
                manifest.flush()
                last_hash = ph
                recorded += 1
                await asyncio.sleep(poll_s)

        log.info("recorder_done", name=name, frames=recorded)
        return manifest_path
