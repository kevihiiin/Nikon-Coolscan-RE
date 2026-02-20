---
name: ghidra-run
description: Run a Ghidra headless analysis script on a project
argument-hint: [project-name] [script-name]
---

<agent>
Run Ghidra headless script on the specified project.

Parse arguments: first word is project name, second is script name.

Projects: NikonScan_Drivers, NikonScan_Modules, NikonScan_TWAIN, NikonScan_ICE, CoolscanFirmware

Command:
```
/opt/ghidra/support/analyzeHeadless ghidra/projects/{project} {project} \
  -process -noanalysis -scriptPath ghidra/scripts -postScript {script}
```

This may take minutes. Report results when complete.
</agent>
