"""RecipeRunner — drives a Recipe through VNC + Holo3 + libvirt.

Per-step flow:
1. Execute step (VNC action, file-exists check, app launch, etc.)
2. Capture VNC frame, save to artifacts/<run-id>/steps/<idx>.png
3. Append OracleRecord to artifacts/<run-id>/oracle.jsonl
4. For oracle/wait-for steps: call Holo3 oracle; on disagreement, fall back to
   grounding (up to MAX_RETRIES times); abort if grounding can't recover
5. Per-step watchdog (asyncio.timeout); if VM goes missing, abort

Artifacts layout:
    artifacts/<run-id>/
        manifest.json          # run metadata: recipe, started_at, model_id, commit
        steps/<NNN>-<kind>.png # per-step screenshot
        oracle.jsonl           # one OracleRecord per oracle/grounding call
        logs/recipe.jsonl      # structlog output for this run
"""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import TYPE_CHECKING

import imagehash
from PIL import Image

from .actions import Action, Key, Type, Wait, validate_in_frame
from .errors import (
    BaselineMismatchError,
    InvalidGroundingError,
    OracleUnavailableError,
    RecipeAbortedError,
    VmStateError,
)
from .logging_setup import bind_run, clear_run, get_logger
from .metrics import OracleRecord, append_oracle

if TYPE_CHECKING:
    from .holo3 import Holo3Client
    from .lifecycle import Lifecycle
    from .recipe import Recipe, Step
    from .vnc import VncClient


log = get_logger(__name__)

MAX_GROUNDING_RETRIES = 3
PER_STEP_TIMEOUT_S = 60
WAIT_FOR_POLL_S = 2.0
PHASH_DISTANCE_THRESHOLD = 5


@dataclass(slots=True)
class StepResult:
    idx: int
    kind: str
    success: bool
    elapsed_ms: float
    oracle_reason: str = ""
    error: str = ""


@dataclass(slots=True)
class RecipeResult:
    recipe: str
    run_id: str
    success: bool
    artifacts_dir: str
    model_id: str
    failure_step: int | None = None
    oracle_reasoning: str = ""
    steps: list[StepResult] = field(default_factory=list)


class RecipeRunner:
    def __init__(
        self,
        vnc: VncClient,
        holo3: Holo3Client,
        lifecycle: Lifecycle,
        artifacts_root: Path,
        baselines_dir: Path,
    ) -> None:
        self._vnc = vnc
        self._holo3 = holo3
        self._lifecycle = lifecycle
        self._artifacts_root = artifacts_root
        self._baselines_dir = baselines_dir

    async def run(self, recipe: Recipe) -> RecipeResult:
        run_id = uuid.uuid4().hex  # uuid7 not in stdlib; uuid4 is fine for run_ids
        artifacts_dir = self._artifacts_root / run_id
        (artifacts_dir / "steps").mkdir(parents=True, exist_ok=True)
        (artifacts_dir / "logs").mkdir(parents=True, exist_ok=True)
        oracle_jsonl = artifacts_dir / "oracle.jsonl"

        bind_run(run_id)
        log.info("recipe_start", recipe=recipe.name, run_id=run_id)

        manifest = {
            "recipe": recipe.name,
            "run_id": run_id,
            "started_at": time.time(),
            "model_id": self._holo3.model_id,
        }
        (artifacts_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))

        result = RecipeResult(
            recipe=recipe.name,
            run_id=run_id,
            success=True,
            artifacts_dir=str(artifacts_dir),
            model_id=self._holo3.model_id,
        )

        try:
            for idx, step in enumerate(recipe.steps):
                step_result = await self._execute_step(
                    idx, step, recipe.name, artifacts_dir, oracle_jsonl
                )
                result.steps.append(step_result)
                if not step_result.success:
                    result.success = False
                    result.failure_step = idx
                    result.oracle_reasoning = step_result.oracle_reason or step_result.error
                    break
        finally:
            clear_run()
            log.info(
                "recipe_end",
                recipe=recipe.name,
                run_id=run_id,
                success=result.success,
                failure_step=result.failure_step,
            )

        return result

    async def _execute_step(
        self,
        idx: int,
        step: Step,
        recipe_name: str,
        artifacts_dir: Path,
        oracle_jsonl: Path,
    ) -> StepResult:
        t0 = time.perf_counter()
        try:
            async with self._step_timeout(idx, step.kind):
                match step.kind:
                    case "action":
                        await self._do_action(step.payload["action"])
                    case "open_app":
                        await self._open_app(str(step.payload["exe"]))
                    case "expect_screen":
                        await self._do_expect_screen(
                            idx,
                            step,
                            recipe_name,
                            artifacts_dir,
                            oracle_jsonl,
                        )
                    case "wait_for_screen":
                        await self._do_wait_for_screen(
                            idx, step, recipe_name, artifacts_dir, oracle_jsonl
                        )
                    case "assert_image_nonblank":
                        self._do_assert_nonblank(int(step.payload["min_unique_colors"]))
                    case "assert_file_exists":
                        self._do_assert_file_exists(str(step.payload["path"]))
        except RecipeAbortedError as e:
            return StepResult(
                idx=idx,
                kind=step.kind,
                success=False,
                elapsed_ms=(time.perf_counter() - t0) * 1000,
                error=str(e),
            )
        except (
            OracleUnavailableError,
            BaselineMismatchError,
            InvalidGroundingError,
            VmStateError,
        ) as e:
            return StepResult(
                idx=idx,
                kind=step.kind,
                success=False,
                elapsed_ms=(time.perf_counter() - t0) * 1000,
                error=str(e),
            )

        # Always capture a screenshot after a successful step for forensic value.
        png_path = artifacts_dir / "steps" / f"{idx:03d}-{step.kind}.png"
        try:
            self._vnc.save_capture(png_path)
        except VmStateError as e:
            log.warning("post_step_capture_failed", idx=idx, error=str(e))

        return StepResult(
            idx=idx,
            kind=step.kind,
            success=True,
            elapsed_ms=(time.perf_counter() - t0) * 1000,
        )

    @asynccontextmanager
    async def _step_timeout(self, idx: int, kind: str) -> AsyncIterator[None]:
        try:
            async with asyncio.timeout(PER_STEP_TIMEOUT_S):
                yield
        except TimeoutError as e:
            status = self._lifecycle.status()
            if status.state != "running":
                raise VmStateError(f"step {idx} ({kind}) timed out; VM state={status.state}") from e
            raise RecipeAbortedError(
                f"step {idx} ({kind}) timed out after {PER_STEP_TIMEOUT_S}s"
            ) from e

    # --- step kinds ---

    async def _do_action(self, action: Action) -> None:
        img = self._vnc.capture()
        validate_in_frame(action, img.width, img.height)
        await asyncio.to_thread(self._vnc.execute, action)

    async def _open_app(self, exe: str) -> None:
        # Open via Start menu search rather than Win+R Run dialog: Run
        # treats whitespace as exe/arg separator (so "Nikon Scan" tries
        # to launch "Nikon" with arg "Scan"), but Start search treats
        # the whole string as a query and launches the top match. That
        # plays nicely with multi-word app names like "Nikon Scan".
        for action in (
            Key(type="key", key="super"),
            Wait(type="wait", ms=800),
            Type(type="type", text=exe),
            Wait(type="wait", ms=800),
            Key(type="key", key="Return"),
            Wait(type="wait", ms=3000),
        ):
            await asyncio.to_thread(self._vnc.execute, action)

    async def _do_expect_screen(
        self,
        idx: int,
        step: Step,
        recipe_name: str,
        artifacts_dir: Path,
        oracle_jsonl: Path,
    ) -> None:
        state = str(step.payload["state"])
        baseline_hash = step.payload.get("baseline_hash")

        img = self._vnc.capture()
        await self._oracle_with_fallback(
            idx=idx,
            step_kind=step.kind,
            state=state,
            image=img,
            recipe_name=recipe_name,
            oracle_jsonl=oracle_jsonl,
            artifacts_dir=artifacts_dir,
        )
        if baseline_hash is not None:
            # Re-capture so the baseline check sees the screen the oracle
            # just signed off on, not the pre-grounding-fallback frame. If
            # grounding closed a leftover dialog, the baseline hash should
            # match the recovered state, not the disrupted one.
            self._check_baseline(self._vnc.capture(), str(baseline_hash))

    async def _do_wait_for_screen(
        self,
        idx: int,
        step: Step,
        recipe_name: str,
        artifacts_dir: Path,
        oracle_jsonl: Path,
    ) -> None:
        state = str(step.payload["state"])
        timeout_s = int(step.payload.get("timeout_s", 60))
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            img = self._vnc.capture()
            phash = str(imagehash.phash(img))
            call = await self._holo3.oracle(img, state)
            append_oracle(
                oracle_jsonl,
                OracleRecord(
                    run_id=artifacts_dir.name,
                    step_idx=idx,
                    expected_state=state,
                    frame_phash=phash,
                    agreed=call.agreed,
                    reason=call.reason,
                    latency_ms=call.latency_ms,
                    model_id=call.model_id,
                ),
            )
            if call.agreed:
                return
            await asyncio.sleep(WAIT_FOR_POLL_S)
        raise RecipeAbortedError(f"wait_for_screen({state!r}) timed out after {timeout_s}s")

    async def _oracle_with_fallback(
        self,
        *,
        idx: int,
        step_kind: str,
        state: str,
        image: Image.Image,
        recipe_name: str,
        oracle_jsonl: Path,
        artifacts_dir: Path,
    ) -> None:
        phash = str(imagehash.phash(image))
        call = await self._holo3.oracle(image, state)
        record = OracleRecord(
            run_id=artifacts_dir.name,
            step_idx=idx,
            expected_state=state,
            frame_phash=phash,
            agreed=call.agreed,
            reason=call.reason,
            latency_ms=call.latency_ms,
            model_id=call.model_id,
        )
        append_oracle(oracle_jsonl, record)
        if call.agreed:
            return

        # Grounding fallback: ask Holo3 for a recovery action up to N times.
        last_reason = call.reason
        for retry in range(MAX_GROUNDING_RETRIES):
            log.warning(
                "oracle_disagreement",
                idx=idx,
                state=state,
                reason=last_reason,
                retry=retry,
            )
            current = self._vnc.capture()
            grounding = await self._holo3.ground(
                current,
                f"Expected screen state {state!r} but oracle disagreed: {last_reason}. "
                "Recover with one Action, or emit Abort.",
            )
            action = grounding.action
            if action.type == "abort":
                raise RecipeAbortedError(f"Holo3 grounding aborted: {action.reason}")
            if action.type == "done":
                return
            validate_in_frame(action, current.width, current.height)
            await asyncio.to_thread(self._vnc.execute, action)

            recheck_img = self._vnc.capture()
            recheck = await self._holo3.oracle(recheck_img, state)
            append_oracle(
                oracle_jsonl,
                OracleRecord(
                    run_id=artifacts_dir.name,
                    step_idx=idx,
                    expected_state=state,
                    frame_phash=str(imagehash.phash(recheck_img)),
                    agreed=recheck.agreed,
                    reason=recheck.reason,
                    latency_ms=recheck.latency_ms,
                    model_id=recheck.model_id,
                    fallback_taken=True,
                ),
            )
            if recheck.agreed:
                return
            last_reason = recheck.reason

        raise RecipeAbortedError(
            f"step {idx} ({step_kind}): oracle disagreement on state={state!r} "
            f"could not be recovered in {MAX_GROUNDING_RETRIES} retries; "
            f"last reason: {last_reason}"
        )

    def _check_baseline(self, image: Image.Image, baseline_hex: str) -> None:
        baseline = imagehash.hex_to_hash(baseline_hex)
        current = imagehash.phash(image)
        distance = current - baseline
        if distance > PHASH_DISTANCE_THRESHOLD:
            raise BaselineMismatchError(
                f"pHash distance {distance} > {PHASH_DISTANCE_THRESHOLD} "
                f"(current={current}, baseline={baseline})"
            )

    def _do_assert_nonblank(self, min_unique_colors: int) -> None:
        img = self._vnc.capture()
        # PIL.Image.getcolors returns None if there are more colors than maxcolors;
        # we only care that there are enough for the screen to be "alive".
        colors = img.getcolors(maxcolors=min_unique_colors + 1)
        if colors is not None and len(colors) <= min_unique_colors:
            raise RecipeAbortedError(
                f"assert_image_nonblank: only {len(colors)} unique colors (min {min_unique_colors})"
            )

    def _do_assert_file_exists(self, path: str) -> None:
        if not self._lifecycle.file_exists(path):
            raise RecipeAbortedError(f"assert_file_exists: {path!r} not found in guest")
