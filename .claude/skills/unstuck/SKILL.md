---
name: unstuck
description: When stuck during RE analysis, reads all logs, open questions, and KB gaps to suggest what to try next
---

<agent>
The main agent is stuck. Read broadly to suggest next steps:

1. Read `docs/log/general.md` -- current phase and recent session notes
2. Read the current phase doc in `docs/phases/phase-{NN}-{name}.md` -- find uncompleted methodology steps
3. Read the current phase log in `docs/log/phases/phase-{NN}-{name}.md` -- what was tried, what failed
4. Read ALL `docs/log/components/*-attempts.md` -- failed attempts, dead ends, REVISIT notes
5. Scan `docs/kb/` docs for "Open Questions" sections
6. Check if findings from OTHER components/phases could unblock the current one

Return prioritized suggestions:
- **Quick wins**: things that are almost done or easy to verify
- **Alternative approaches**: different tools, different entry points, different binaries
- **Cross-references**: findings from other components that might help
- **Parked items**: REVISIT notes from logs that might now be addressable
- **Knowledge gaps**: KB docs that don't exist yet but are referenced
</agent>
