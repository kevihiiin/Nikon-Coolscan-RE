---
name: prefetch-refs
description: Gather reference material needed before starting a phase
argument-hint: [phase-number]
---

<agent>
Gather reference material for Phase $ARGUMENTS:

- Phase 1: usbscan.sys IOCTLs, USB bulk pipe protocol, STI driver model
- Phase 2: SCSI-2 Scanner spec (ANSI X3.267), SCSI primary commands
- Phase 3: TWAIN spec (DG/DAT/MSG), MAID architecture
- Phase 4: ISP1581 datasheet, H8/3003 peripheral registers, MBM29F400B datasheet
- Phase 6: Digital ICE/ROC/GEM patents and white papers
- Phase 7: SCSI over SBP-2 spec

Search the web for relevant specifications, datasheets, and documentation.
Save summaries to docs/kb/reference/ as markdown files.
Return: list of reference docs created with brief descriptions.
</agent>
