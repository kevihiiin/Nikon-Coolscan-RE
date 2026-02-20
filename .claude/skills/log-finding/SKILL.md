---
name: log-finding
description: Log an RE finding to the appropriate component and phase log files
argument-hint: [component-name]
---

Log a finding for component $ARGUMENTS:

1. Append a new entry to `docs/log/components/$ARGUMENTS-attempts.md`:
   ### YYYY-MM-DD: [target function/address]
   **Tool**: [tool used]
   **What was tried**: [description]
   **Result**: [what happened]
   **Confidence**: Low | Medium | High | Verified
   **KB Updated**: [which kb doc, or "not yet"]
2. Append a progress note to the current phase log in `docs/log/phases/`
3. If confidence is High or Verified, suggest running /update-kb
