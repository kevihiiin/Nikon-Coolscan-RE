---
name: phase-check
description: Check completion status of the current or specified phase
argument-hint: [phase-number (optional)]
---

<agent>
Check phase completion status:

1. If no argument given, read `docs/log/general.md` to find current phase number
2. Read `docs/phases/phase-{NN}-{name}.md` -- extract completion criteria checklist
3. Read `docs/log/phases/phase-{NN}-{name}.md` -- check status header and logged progress
4. Spot-check: for each "met" criterion, verify the KB doc actually exists

Return: phase name, criteria checklist with status for each item, suggested next action.
</agent>
