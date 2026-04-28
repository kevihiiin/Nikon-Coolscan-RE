# Recipe authoring

How to add a new test recipe.

## The DSL

```python
# src/coolscan_hil_agent/recipes/your_recipe.py
from ..recipe import Recipe

def build() -> Recipe:
    return (
        Recipe("your_recipe")
        .open_app("NikonScan.exe")
        .expect_screen("nikonscan-main-window")
        .click_at(425, 360)                        # Scanner menu
        .expect_screen("scanner-source-dialog")
        .click_at(380, 510)                        # Coolscan V entry
        .expect_screen("nikonscan-connected", baseline_hash="ff00...")
        .click_at(620, 130)                        # Preview button
        .wait_for_screen("preview-pane-shown", timeout_s=120)
        .assert_image_nonblank()
        .assert_file_exists(r"C:\scans\preview*.tiff")
    )
```

`recipes/__init__.py::discover()` finds your module automatically — no
registration needed. Naming convention: lowercase with underscores, one
recipe per file.

## Available primitives

| Primitive | Effect |
|---|---|
| `click_at(x, y, button="left")` | VNC mouse click at (x, y) |
| `double_click_at(x, y)` | VNC double-click |
| `type_text("hello")` | VNC keyboard typing |
| `key("Return")` | VNC single key press (vncdotool key names) |
| `wait_ms(500)` | sleep without action |
| `open_app("Notepad.exe")` | Win+R → type → Enter macro |
| `expect_screen(name, baseline_hash=None)` | Holo3 oracle check |
| `wait_for_screen(name, timeout_s=60)` | poll oracle until agreement |
| `assert_image_nonblank(min_unique_colors=100)` | guard against blank framebuffer |
| `assert_file_exists(r"C:\path")` | qemu-ga path check inside the VM |

## Capturing click coordinates

NikonScan 4.0.3's UI is pixel-stable, but you still need to find the right
(x, y). Two options:

### Option A — manual recording with `coolscan-hil record`

1. Boot the VM and bring NikonScan to the state you want to extend.
2. In another terminal:
   ```
   uv run coolscan-hil record your_recipe
   ```
   The recorder snapshots VNC every second and saves distinct frames to
   `recordings/your_recipe/frame-NNN.png`.
3. Drive NikonScan manually through the workflow. Stop the recorder
   (Ctrl-C) when done.
4. Open the captured frames in any image viewer that shows pixel coordinates
   (e.g., GIMP). Note the (x, y) of each button you clicked.
5. Translate into a `Recipe` chain.

### Option B — Holo3 grounding to extract coordinates

Send a captured screenshot to Holo3 with an instruction like "where is the
Preview button", let it return coordinates, paste them into the recipe.
Useful when the UI has many small targets.

```python
# scratch script
from coolscan_hil_agent.holo3 import Holo3Client
from PIL import Image
import asyncio

async def main():
    img = Image.open("recordings/your_recipe/frame-005.png")
    client = Holo3Client("https://...", "Hcompany/Holo3-35B-A3B", "...")
    call = await client.ground(img, "click the Preview button")
    print(call.action)  # → Click(x=620, y=130, ...)
    await client.aclose()

asyncio.run(main())
```

## Promoting a baseline

Once a recipe runs green against a known-good emulator commit, promote each
expected screen to a committed pHash baseline:

```python
# In Claude Code, via MCP:
record_baseline(recipe="preview_scan", state="nikonscan-connected", run_id="<green run id>")
```

Or directly:

```python
from coolscan_hil_agent.mcp_server import record_baseline
result = record_baseline("preview_scan", "nikonscan-connected", "<run_id>")
```

This writes `baselines/<recipe>/<state>.json` with the pHash + model_id +
source run id. Future runs will compare against it (`expect_screen(name,
baseline_hash="<the phash>")`) and fail with `BaselineMismatchError` if the
distance exceeds 5.

## Conventions

- **Recipe names** match the file: `inquiry_smoke.py` → `Recipe("inquiry_smoke")`.
- **State names** in `expect_screen("...")` are kebab-case strings that
  describe what should be visible: `"scanner-source-dialog"`, not
  `"step3"`.
- **Don't add an `expect_screen` after every click**. Group related clicks
  (e.g., navigating a menu) and check the screen at meaningful points.
  Excess oracle calls just slow CI without adding signal.
- **Avoid `wait_ms(...)`** unless you have a reason. Prefer
  `wait_for_screen(...)` so the timing self-adjusts.
- **Recipes are integration code, not unit-tested code** — `pyproject.toml`
  excludes `recipes/` from coverage. Test recipes by running them.
