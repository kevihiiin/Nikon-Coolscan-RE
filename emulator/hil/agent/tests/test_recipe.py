"""Recipe DSL — verify steps are recorded with the right kind/payload."""

from __future__ import annotations

from coolscan_hil_agent.actions import Click
from coolscan_hil_agent.recipe import Recipe


def test_empty_recipe() -> None:
    r = Recipe("empty")
    assert r.name == "empty"
    assert r.steps == []


def test_fluent_chain_records_each_step() -> None:
    r = (
        Recipe("foo")
        .open_app("Notepad.exe")
        .expect_screen("opened")
        .click_at(10, 20)
        .wait_for_screen("done", timeout_s=30)
        .assert_image_nonblank(min_unique_colors=50)
        .assert_file_exists(r"C:\out.txt")
    )
    kinds = [s.kind for s in r.steps]
    assert kinds == [
        "open_app",
        "expect_screen",
        "action",
        "wait_for_screen",
        "assert_image_nonblank",
        "assert_file_exists",
    ]
    click_step = r.steps[2]
    assert isinstance(click_step.payload["action"], Click)
    assert click_step.payload["action"].x == 10


def test_baseline_hash_is_optional() -> None:
    r = Recipe("baseline_test").expect_screen("foo")
    assert r.steps[0].payload["baseline_hash"] is None
    r2 = Recipe("baseline_test").expect_screen("foo", baseline_hash="abc123")
    assert r2.steps[0].payload["baseline_hash"] == "abc123"


def test_inquiry_smoke_recipe_builds() -> None:
    from coolscan_hil_agent.recipes import discover

    recipes = discover()
    assert "inquiry_smoke" in recipes
    r = recipes["inquiry_smoke"]()
    assert r.name == "inquiry_smoke"
    assert len(r.steps) >= 1
