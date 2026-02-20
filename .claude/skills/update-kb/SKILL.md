---
name: update-kb
description: Create or update a knowledge base document with proper format and cross-references
argument-hint: [kb-path-relative-to-docs/kb]
---

Update the KB document at `docs/kb/$ARGUMENTS`:

Follow KB rules from CLAUDE.md:
- Header: Status, Last Updated, Phase, Confidence level
- Explain the "why" not just the "what"
- Evidence must cite source: `BINARY.dll:0xADDRESS` or `firmware:0xADDRESS`
- Include hex dumps, decompiled code snippets where helpful
- Cross-reference related docs with relative links

If the file doesn't exist, create it with this template:
```markdown
# [Topic]
**Status**: Draft
**Last Updated**: YYYY-MM-DD  |  **Phase**: N  |  **Confidence**: [level]
## Summary
## Findings
## Open Questions
## Cross-References
```
