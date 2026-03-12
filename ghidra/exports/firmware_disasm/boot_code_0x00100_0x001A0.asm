; === boot_code (0x000100 - 0x0001A0) ===
; Size: 160 bytes
; NOTE: r2 h8300 is 16-bit only. 32-bit H8/300H ops may show as invalid.
; Use Ghidra H8/300H SLEIGH for authoritative disassembly.

0x00000100      7a             invalid
0x00000101      0700           ldc #0x0:8,ccr
0x00000103      ffff           mov.b #0xff:8,r7l
0x00000105      0007           nop
0x00000107      c0f8           or #0xf8:8,r0h
0x00000109      006a           nop
0x0000010b      88fd           add.b #0xfd:8,r0l
0x0000010d      4c58           bge @@0x58:8
0x0000010f      0000           nop
0x00000111      5c             invalid
0x00000112      7a             invalid
0x00000113      0700           ldc #0x0:8,ccr
0x00000115      ffff           mov.b #0xff:8,r7l
0x00000117      0007           nop
0x00000119      c0f8           or #0xf8:8,r0h
0x0000011b      016a88fd       sleep
0x0000011f      4c6a           bge @@0x6a:8
0x00000121      2800           mov.b @0x0:8,r0l
0x00000123      4006           bra @@0x6:8
0x00000125      b26a           subx #0x6a:8,r2h
0x00000127      88fd           add.b #0xfd:8,r0l
0x00000129      4d6a           blt @@0x6a:8
0x0000012b      2800           mov.b @0x0:8,r0l
0x0000012d      4006           bra @@0x6:8
0x0000012f      b36a           subx #0x6a:8,r3h
0x00000131      88fd           add.b #0xfd:8,r0l
0x00000133      4e7a           bgt @@0x7a:8
0x00000135      0500           xorc #0x0:8,ccr
0x00000137      4006           bra @@0x6:8
0x00000139      b47a           subx #0x7a:8,r4h
0x0000013b      0600           andc #0x0:8,ccr
0x0000013d      fffd           mov.b #0xfd:8,r7l
0x0000013f      50fc           mulxu r7l,r4
0x00000141      087b           add.b r7h,r3l
0x00000143      5c             invalid
0x00000144      598f           jmp @r0
0x00000146      7a             invalid
0x00000147      0500           xorc #0x0:8,ccr
0x00000149      4006           bra @@0x6:8
0x0000014b      bc7a           subx #0x7a:8,r4l
0x0000014d      0600           andc #0x0:8,ccr
0x0000014f      fffd           mov.b #0xfd:8,r7l
0x00000151      58             invalid
0x00000152      fca0           mov.b #0xa0:8,r4l
0x00000154      7b5c598f       eepmov
0x00000158      7a             invalid
0x00000159      0500           xorc #0x0:8,ccr
0x0000015b      4007           bra @@0x7:8
0x0000015d      5c             invalid
0x0000015e      7a             invalid
0x0000015f      0600           andc #0x0:8,ccr
0x00000161      fffd           mov.b #0xfd:8,r7l
0x00000163      f8fc           mov.b #0xfc:8,r0l
0x00000165      087b           add.b r7h,r3l
0x00000167      5c             invalid
0x00000168      598f           jmp @r0
0x0000016a      58             invalid
0x0000016b      0000           nop
0x0000016d      006a           nop
0x0000016f      2800           mov.b @0x0:8,r0l
0x00000171      0040           nop
0x00000173      01a80058       sleep
0x00000177      6000           bset r0h,r0h
0x00000179      045a           orc #0x5a:8,ccr
0x0000017b      0203           stc ccr,r3h
0x0000017d      345a           mov.b r4h,@0x5a:8
0x0000017f      01033400       sleep
0x00000183      0040           nop
0x00000185      fc00           mov.b #0x0:8,r4l
0x00000187      0040           nop
0x00000189      fcff           mov.b #0xff:8,r4l
0x0000018b      ffff           mov.b #0xff:8,r7l
0x0000018d      ffff           mov.b #0xff:8,r7l
0x0000018f      ffff           mov.b #0xff:8,r7l
0x00000191      ffff           mov.b #0xff:8,r7l
0x00000193      ffff           mov.b #0xff:8,r7l
0x00000195      ffff           mov.b #0xff:8,r7l
0x00000197      ffff           mov.b #0xff:8,r7l
0x00000199      ffff           mov.b #0xff:8,r7l
0x0000019b      ffff           mov.b #0xff:8,r7l
