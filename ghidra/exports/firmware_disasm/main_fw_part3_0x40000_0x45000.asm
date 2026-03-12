; === main_fw_part3 (0x040000 - 0x045000) ===
; Size: 20480 bytes
; NOTE: r2 h8300 is 16-bit only. 32-bit H8/300H ops may show as invalid.
; Use Ghidra H8/300H SLEIGH for authoritative disassembly.

0x00040000      0074           nop
0x00040002      01006b20       sleep
0x00040006      0040           nop
0x00040008      6e6a1130       mov.b @(0x1130:16,r6),r2l
0x0004000c      6f710074       mov.w @(0x74:16,r7),r1
0x00040010      1d01           cmp.w r0,r1
0x00040012      4c04           bge @@0x4:8
0x00040014      5a03ffc8       jmp @0xffc8:16
0x00040018      7a             invalid
0x00040019      0000           nop
0x0004001b      404e           bra @@0x4e:8
0x0004001d      9668           addx #0x68:8,r6h
0x0004001f      09d9           add.w r13,r1
0x00040021      0168896f       sleep
0x00040025      7000           bset #0x0:3,r0h
0x00040027      8a46           add.b #0x46:8,r2l
0x00040029      045a           orc #0x5a:8,ccr
0x0004002b      0400           orc #0x0:8,ccr
0x0004002d      ce6f           or #0x6f:8,r6l
0x0004002f      7000           bset #0x0:3,r0h
0x00040031      8a1b           add.b #0x1b:8,r2l
0x00040033      506f           mulxu r6h,r7
0x00040035      f000           mov.b #0x0:8,r0h
0x00040037      8a6a           add.b #0x6a:8,r2l
0x00040039      2000           mov.b @0x0:8,r0h
0x0004003b      400f           bra @@0xf:8
0x0004003d      6901           mov.w @r0,r1
0x0004003f      006b           nop
0x00040041      2100           mov.b @0x0:8,r1h
0x00040043      400f           bra @@0xf:8
0x00040045      6c6e           mov.b @r6+,r6l
0x00040047      78             invalid
0x00040048      0090           nop
0x0004004a      5e035a9a       jsr @0x5a9a:16
0x0004004e      01006b20       sleep
0x00040052      0040           nop
0x00040054      6e6a0100       mov.b @(0x100:16,r6),r2l
0x00040058      6ba00040       mov.w r0,@0x40:16
0x0004005c      078c           ldc #0x8c:8,ccr
0x0004005e      6b200040       mov.w @0x40:16,r0
0x00040062      0776           ldc #0x76:8,ccr
0x00040064      7370           btst #0x7:3,r0h
0x00040066      4704           beq @@0x4:8
0x00040068      5a0400e6       jmp @0xe6:16
0x0004006c      6b200040       mov.w @0x40:16,r0
0x00040070      0778           ldc #0x78:8,ccr
0x00040072      79200300       mov.w #0x300:16,r0
0x00040076      4604           bne @@0x4:8
0x00040078      5a04008c       jmp @0x8c:16
0x0004007c      6b200040       mov.w @0x40:16,r0
0x00040080      0778           ldc #0x78:8,ccr
0x00040082      79200310       mov.w #0x310:16,r0
0x00040086      4704           beq @@0x4:8
0x00040088      5a04009a       jmp @0x9a:16
0x0004008c      01006b20       sleep
0x00040090      0040           nop
0x00040092      0896           add.b r1l,r6h
0x00040094      4604           bne @@0x4:8
0x00040096      5a0400e6       jmp @0xe6:16
0x0004009a      01006b20       sleep
0x0004009e      0040           nop
0x000400a0      078c           ldc #0x8c:8,ccr
0x000400a2      4604           bne @@0x4:8
0x000400a4      5a0400b0       jmp @0xb0:16
0x000400a8      5e0109e2       jsr @0x9e2:16
0x000400ac      5a04005e       jmp @0x5e:16
0x000400b0      f802           mov.b #0x2:8,r0l
0x000400b2      6aa80020       mov.b r0l,@0x20:16
0x000400b6      0001           nop
0x000400b8      6a280020       mov.b @0x20:16,r0l
0x000400bc      0002           nop
0x000400be      7338           btst #0x3:3,r0l
0x000400c0      4604           bne @@0x4:8
0x000400c2      5a040024       jmp @0x24:16
0x000400c6      5e0109e2       jsr @0x9e2:16
0x000400ca      5a0400b8       jmp @0xb8:16
0x000400ce      f881           mov.b #0x81:8,r0l
0x000400d0      6aa80040       mov.b r0l,@0x40:16
0x000400d4      4eb7           bgt @@0xb7:8
0x000400d6      6e790027       mov.b @(0x27:16,r7),r1l
0x000400da      6f780028       mov.w @(0x28:16,r7),r0
0x000400de      6f70002a       mov.w @(0x2a:16,r7),r0
0x000400e2      5e040318       jsr @0x318:16
0x000400e6      1888           sub.b r0l,r0l
0x000400e8      6aa80040       mov.b r0l,@0x40:16
0x000400ec      52             invalid
0x000400ed      ef18           and #0x18:8,r7l
0x000400ef      886a           add.b #0x6a:8,r0l
0x000400f1      a800           cmp.b #0x0:8,r0l
0x000400f3      4052           bra @@0x52:8
0x000400f5      f16b           mov.b #0x6b:8,r1h
0x000400f7      2000           mov.b @0x0:8,r0h
0x000400f9      4007           bra @@0x7:8
0x000400fb      78             invalid
0x000400fc      79200300       mov.w #0x300:16,r0
0x00040100      4604           bne @@0x4:8
0x00040102      5a040116       jmp @0x116:16
0x00040106      6b200040       mov.w @0x40:16,r0
0x0004010a      0778           ldc #0x78:8,ccr
0x0004010c      79200310       mov.w #0x310:16,r0
0x00040110      4704           beq @@0x4:8
0x00040112      5a040124       jmp @0x124:16
0x00040116      01006b20       sleep
0x0004011a      0040           nop
0x0004011c      0896           add.b r1l,r6h
0x0004011e      4604           bne @@0x4:8
0x00040120      5a040148       jmp @0x148:16
0x00040124      01006b20       sleep
0x00040128      0040           nop
0x0004012a      078c           ldc #0x8c:8,ccr
0x0004012c      4604           bne @@0x4:8
0x0004012e      5a040148       jmp @0x148:16
0x00040132      6b200040       mov.w @0x40:16,r0
0x00040136      0776           ldc #0x76:8,ccr
0x00040138      7370           btst #0x7:3,r0h
0x0004013a      4704           beq @@0x4:8
0x0004013c      5a040148       jmp @0x148:16
0x00040140      5e0109e2       jsr @0x9e2:16
0x00040144      5a0400f6       jmp @0xf6:16
0x00040148      1a80           dec r0h
0x0004014a      01006ba0       sleep
0x0004014e      0040           nop
0x00040150      078c           ldc #0x8c:8,ccr
0x00040152      f802           mov.b #0x2:8,r0l
0x00040154      6aa80020       mov.b r0l,@0x20:16
0x00040158      0001           nop
0x0004015a      6b200040       mov.w @0x40:16,r0
0x0004015e      0778           ldc #0x78:8,ccr
0x00040160      79200300       mov.w #0x300:16,r0
0x00040164      4604           bne @@0x4:8
0x00040166      5a04017a       jmp @0x17a:16
0x0004016a      6b200040       mov.w @0x40:16,r0
0x0004016e      0778           ldc #0x78:8,ccr
0x00040170      79200310       mov.w #0x310:16,r0
0x00040174      4704           beq @@0x4:8
0x00040176      5a040188       jmp @0x188:16
0x0004017a      01006b20       sleep
0x0004017e      0040           nop
0x00040180      0896           add.b r1l,r6h
0x00040182      4604           bne @@0x4:8
0x00040184      5a04019e       jmp @0x19e:16
0x00040188      6a280020       mov.b @0x20:16,r0l
0x0004018c      0002           nop
0x0004018e      7338           btst #0x3:3,r0l
0x00040190      4604           bne @@0x4:8
0x00040192      5a04019e       jmp @0x19e:16
0x00040196      5e0109e2       jsr @0x9e2:16
0x0004019a      5a04015a       jmp @0x15a:16
0x0004019e      6b200040       mov.w @0x40:16,r0
0x000401a2      58             invalid
0x000401a3      fc79           mov.b #0x79:8,r4l
0x000401a5      2000           mov.b @0x0:8,r0h
0x000401a7      0f45           daa r5h
0x000401a9      045a           orc #0x5a:8,ccr
0x000401ab      0401           orc #0x1:8,ccr
0x000401ad      ee6e           and #0x6e:8,r6l
0x000401af      78             invalid
0x000401b0      003f           nop
0x000401b2      4704           beq @@0x4:8
0x000401b4      5a0401ee       jmp @0x1ee:16
0x000401b8      6b200040       mov.w @0x40:16,r0
0x000401bc      0778           ldc #0x78:8,ccr
0x000401be      79200300       mov.w #0x300:16,r0
0x000401c2      4604           bne @@0x4:8
0x000401c4      5a0401ee       jmp @0x1ee:16
0x000401c8      6b200040       mov.w @0x40:16,r0
0x000401cc      0778           ldc #0x78:8,ccr
0x000401ce      79200310       mov.w #0x310:16,r0
0x000401d2      4604           bne @@0x4:8
0x000401d4      5a0401ee       jmp @0x1ee:16
0x000401d8      6b200040       mov.w @0x40:16,r0
0x000401dc      0776           ldc #0x76:8,ccr
0x000401de      7370           btst #0x7:3,r0h
0x000401e0      4704           beq @@0x4:8
0x000401e2      5a0401ee       jmp @0x1ee:16
0x000401e6      79000320       mov.w #0x320:16,r0
0x000401ea      6ff00040       mov.w r0,@(0x40:16,r7)
0x000401ee      6f700040       mov.w @(0x40:16,r7),r0
0x000401f2      4604           bne @@0x4:8
0x000401f4      5a040222       jmp @0x222:16
0x000401f8      6b200040       mov.w @0x40:16,r0
0x000401fc      0778           ldc #0x78:8,ccr
0x000401fe      7920           mov.w #0x1001:16,r0
0x00040202      4604           bne @@0x4:8
0x00040204      5a040222       jmp @0x222:16
0x00040208      6b200040       mov.w @0x40:16,r0
0x0004020c      0778           ldc #0x78:8,ccr
0x0004020e      79200310       mov.w #0x310:16,r0
0x00040212      4604           bne @@0x4:8
0x00040214      5a040222       jmp @0x222:16
0x00040218      6f700040       mov.w @(0x40:16,r7),r0
0x0004021c      6ba00040       mov.w r0,@0x40:16
0x00040220      0778           ldc #0x78:8,ccr
0x00040222      6b200040       mov.w @0x40:16,r0
0x00040226      0778           ldc #0x78:8,ccr
0x00040228      79200300       mov.w #0x300:16,r0
0x0004022c      4604           bne @@0x4:8
0x0004022e      5a040262       jmp @0x262:16
0x00040232      6b200040       mov.w @0x40:16,r0
0x00040236      0778           ldc #0x78:8,ccr
0x00040238      79200310       mov.w #0x310:16,r0
0x0004023c      4604           bne @@0x4:8
0x0004023e      5a040262       jmp @0x262:16
0x00040242      6b200040       mov.w @0x40:16,r0
0x00040246      0778           ldc #0x78:8,ccr
0x00040248      79200320       mov.w #0x320:16,r0
0x0004024c      4604           bne @@0x4:8
0x0004024e      5a040262       jmp @0x262:16
0x00040252      6b200040       mov.w @0x40:16,r0
0x00040256      0778           ldc #0x78:8,ccr
0x00040258      79200330       mov.w #0x330:16,r0
0x0004025c      4704           beq @@0x4:8
0x0004025e      5a040272       jmp @0x272:16
0x00040262      f801           mov.b #0x1:8,r0l
0x00040264      6aa80040       mov.b r0l,@0x40:16
0x00040268      52             invalid
0x00040269      f3f8           mov.b #0xf8:8,r3h
0x0004026b      066a           andc #0x6a:8,ccr
0x0004026d      a800           cmp.b #0x0:8,r0l
0x0004026f      400e           bra @@0xe:8
0x00040271      9218           addx #0x18:8,r2h
0x00040273      885a           add.b #0x5a:8,r0l
0x00040275      0402           orc #0x2:8,ccr
0x00040277      a21a           cmp.b #0x1a:8,r2h
0x00040279      806e           add.b #0x6e:8,r0h
0x0004027b      78             invalid
0x0004027c      0091           nop
0x0004027e      1a91           dec r1h
0x00040280      6e790091       mov.b @(0x91:16,r7),r1l
0x00040284      1031           shal r1h
0x00040286      1031           shal r1h
0x00040288      01007810       sleep
0x0004028c      6b210004       mov.w @0x4:16,r1
0x00040290      a41c           cmp.b #0x1c:8,r4h
0x00040292      78             invalid
0x00040293      006a           nop
0x00040295      2800           mov.b @0x0:8,r0l
0x00040297      404e           bra @@0x4e:8
0x00040299      5068           mulxu r6h,r0
0x0004029b      986e           addx #0x6e:8,r0l
0x0004029d      78             invalid
0x0004029e      0091           nop
0x000402a0      0a08           inc r0l
0x000402a2      6ef80091       mov.b r0l,@(0x91:16,r7)
0x000402a6      a804           cmp.b #0x4:8,r0l
0x000402a8      4404           bcc @@0x4:8
0x000402aa      5a040278       jmp @0x278:16
0x000402ae      28e8           mov.b @0xe8:8,r0l
0x000402b0      e89f           and #0x9f:8,r0l
0x000402b2      38e8           mov.b r0l,@0xe8:8
0x000402b4      5e035ddc       jsr @0x5ddc:16
0x000402b8      6b200040       mov.w @0x40:16,r0
0x000402bc      0776           ldc #0x76:8,ccr
0x000402be      7370           btst #0x7:3,r0h
0x000402c0      4604           bne @@0x4:8
0x000402c2      5a04030c       jmp @0x30c:16
0x000402c6      6a280040       mov.b @0x40:16,r0l
0x000402ca      6bd26a29       mov.w r2,@0x6a29:16
0x000402ce      0040           nop
0x000402d0      6be31c98       mov.w r3,@0x1c98:16
0x000402d4      4604           bne @@0x4:8
0x000402d6      5a04030c       jmp @0x30c:16
0x000402da      6a280040       mov.b @0x40:16,r0l
0x000402de      6bd24704       mov.w r2,@0x4704:16
0x000402e2      5a0402f4       jmp @0x2f4:16
0x000402e6      7a             invalid
0x000402e7      0000           nop
0x000402e9      4058           bra @@0x58:8
0x000402eb      fc69           mov.b #0x69:8,r4l
0x000402ed      011b515a       sleep
0x000402f1      0402           orc #0x2:8,ccr
0x000402f3      fe7a           mov.b #0x7a:8,r6l
0x000402f5      0000           nop
0x000402f7      4058           bra @@0x58:8
0x000402f9      fc69           mov.b #0x69:8,r4l
0x000402fb      010b5169       sleep
0x000402ff      816a           add.b #0x6a:8,r1h
0x00040301      28             mov.b @0x10:8,r0l
0x00040303      406b           bra @@0x6b:8
0x00040305      e36a           and #0x6a:8,r3h
0x00040307      a800           cmp.b #0x0:8,r0l
0x00040309      406b           bra @@0x6b:8
0x0004030b      d27a           xor #0x7a:8,r2h
0x0004030d      1700           not r0h
0x0004030f      0000           nop
0x00040311      9201           addx #0x1:8,r2h
0x00040313      006d           nop
0x00040315      7254           bclr #0x5:3,r4h
0x00040317      705e           bset #0x5:3,r6l
0x00040319      0164587a       sleep
0x0004031d      3700           mov.b r7h,@0x0:8
0x0004031f      0000           nop
0x00040321      147a           or r7h,r2l
0x00040323      0300           ldc r0h,ccr
0x00040325      4052           bra @@0x52:8
0x00040327      987a           addx #0x7a:8,r0l
0x00040329      0500           xorc #0x0:8,ccr
0x0004032b      4052           bra @@0x52:8
0x0004032d      887a           add.b #0x7a:8,r0l
0x0004032f      0600           andc #0x0:8,ccr
0x00040331      4052           bra @@0x52:8
0x00040333      900d           addx #0xd:8,r0h
0x00040335      046f           orc #0x6f:8,ccr
0x00040337      f800           mov.b #0x0:8,r0l
0x00040339      020d           stc ccr,r5l
0x0004033b      4447           bcc @@0x47:8
0x0004033d      045a           orc #0x5a:8,ccr
0x0004033f      0404           orc #0x4:8,ccr
0x00040341      6801           mov.b @r0,r1h
0x00040343      0069           nop
0x00040345      52             invalid
0x00040346      6922           mov.w @r2,r2
0x00040348      69e2           mov.w r2,@r6
0x0004034a      01006b22       sleep
0x0004034e      0040           nop
0x00040350      52             invalid
0x00040351      8469           add.b #0x69:8,r4h
0x00040353      2cf8           mov.b @0xf8:8,r4l
0x00040355      036e           ldc r6l,ccr
0x00040357      f800           mov.b #0x0:8,r0l
0x00040359      0e79           addx r7h,r1l
0x0004035b      0400           orc #0x0:8,ccr
0x0004035d      015a0404       sleep
0x00040361      500d           mulxu r0h,r5
0x00040363      4017           bra @@0x17:8
0x00040365      7010           bset #0x1:3,r0h
0x00040367      3001           mov.b r0h,@0x1:8
0x00040369      0069           nop
0x0004036b      510a           divxu r0h,r2
0x0004036d      8168           add.b #0x68:8,r1h
0x0004036f      1818           sub.b r1h,r0l
0x00040371      00e8           nop
0x00040373      7f             invalid
0x00040374      6ef8000f       mov.b r0l,@(0xf:16,r7)
0x00040378      a801           cmp.b #0x1:8,r0l
0x0004037a      4704           beq @@0x4:8
0x0004037c      5a04038c       jmp @0x38c:16
0x00040380      6e79000e       mov.b @(0xe:16,r7),r1l
0x00040384      7309           btst #0x0:3,r1l
0x00040386      4704           beq @@0x4:8
0x00040388      5a0403a4       jmp @0x3a4:16
0x0004038c      6e78000f       mov.b @(0xf:16,r7),r0l
0x00040390      a803           cmp.b #0x3:8,r0l
0x00040392      4704           beq @@0x4:8
0x00040394      5a040432       jmp @0x432:16
0x00040398      6e78000e       mov.b @(0xe:16,r7),r0l
0x0004039c      7318           btst #0x1:3,r0l
0x0004039e      4604           bne @@0x4:8
0x000403a0      5a040432       jmp @0x432:16
0x000403a4      0d40           mov.w r4,r0
0x000403a6      1770           neg r0h
0x000403a8      1030           shal r0h
0x000403aa      01006b21       sleep
0x000403ae      0040           nop
0x000403b0      52             invalid
0x000403b1      840a           add.b #0xa:8,r4h
0x000403b3      8169           add.b #0x69:8,r1h
0x000403b5      111d           shar r5l
0x000403b7      1c47           cmp.b r4h,r7h
0x000403b9      045a           orc #0x5a:8,ccr
0x000403bb      0404           orc #0x4:8,ccr
0x000403bd      0a0d           inc r5l
0x000403bf      4c5a           bge @@0x5a:8
0x000403c1      0403           orc #0x3:8,ccr
0x000403c3      fc0d           mov.b #0xd:8,r4l
0x000403c5      c017           or #0x17:8,r0h
0x000403c7      7010           bset #0x1:3,r0h
0x000403c9      3001           mov.b r0h,@0x1:8
0x000403cb      0069           nop
0x000403cd      510a           divxu r0h,r2
0x000403cf      8168           add.b #0x68:8,r1h
0x000403d1      1818           sub.b r1h,r0l
0x000403d3      00e8           nop
0x000403d5      7f             invalid
0x000403d6      6e79000f       mov.b @(0xf:16,r7),r1l
0x000403da      1c98           cmp.b r1l,r0l
0x000403dc      4704           beq @@0x4:8
0x000403de      5a04040a       jmp @0x40a:16
0x000403e2      6960           mov.w @r6,r0
0x000403e4      79100006       mov.w #0x6:16,r0
0x000403e8      69e0           mov.w r0,@r6
0x000403ea      0dc0           mov.w r12,r0
0x000403ec      1770           neg r0h
0x000403ee      1030           shal r0h
0x000403f0      01006951       sleep
0x000403f4      0a81           inc r1h
0x000403f6      6960           mov.w @r6,r0
0x000403f8      6990           mov.w r0,@r1
0x000403fa      0b5c           adds #1,r4
0x000403fc      6b200040       mov.w @0x40:16,r0
0x00040400      52             invalid
0x00040401      821d           add.b #0x1d:8,r2h
0x00040403      0c44           mov.b r4h,r4h
0x00040405      045a           orc #0x5a:8,ccr
0x00040407      0403           orc #0x3:8,ccr
0x00040409      c46e           or #0x6e:8,r4h
0x0004040b      78             invalid
0x0004040c      000f           nop
0x0004040e      a801           cmp.b #0x1:8,r0l
0x00040410      4704           beq @@0x4:8
0x00040412      5a040426       jmp @0x426:16
0x00040416      7a             invalid
0x00040417      0000           nop
0x00040419      0000           nop
0x0004041b      0e0a           addx r0h,r2l
0x0004041d      f07d           mov.b #0x7d:8,r0h
0x0004041f      0072           nop
0x00040421      005a           nop
0x00040423      0404           orc #0x4:8,ccr
0x00040425      327a           mov.b r2h,@0x7a:8
0x00040427      0000           nop
0x00040429      0000           nop
0x0004042b      0e0a           addx r0h,r2l
0x0004042d      f07d           mov.b #0x7d:8,r0h
0x0004042f      0072           nop
0x00040431      100d           shll r5l
0x00040433      4017           bra @@0x17:8
0x00040435      7010           bset #0x1:3,r0h
0x00040437      3001           mov.b r0h,@0x1:8
0x00040439      0069           nop
0x0004043b      510a           divxu r0h,r2
0x0004043d      8169           add.b #0x69:8,r1h
0x0004043f      1169           shar r1l
0x00040441      e101           and #0x1:8,r1h
0x00040443      006b           nop
0x00040445      2100           mov.b @0x0:8,r1h
0x00040447      4052           bra @@0x52:8
0x00040449      840a           add.b #0xa:8,r4h
0x0004044b      8169           add.b #0x69:8,r1h
0x0004044d      1c0b           cmp.b r0h,r3l
0x0004044f      546b           rts
0x00040451      2000           mov.b @0x0:8,r0h
0x00040453      4052           bra @@0x52:8
0x00040455      821d           add.b #0x1d:8,r2h
0x00040457      0445           orc #0x45:8,ccr
0x00040459      045a           orc #0x5a:8,ccr
0x0004045b      0404           orc #0x4:8,ccr
0x0004045d      686e           mov.b @r6,r6l
0x0004045f      78             invalid
0x00040460      000e           nop
0x00040462      4704           beq @@0x4:8
0x00040464      5a040362       jmp @0x362:16
0x00040468      6a280040       mov.b @0x40:16,r0l
0x0004046c      74b8           bior #0x3:3,r0l
0x0004046e      4604           bne @@0x4:8
0x00040470      5a040624       jmp @0x624:16
0x00040474      6a280040       mov.b @0x40:16,r0l
0x00040478      6b50a801       mov.w @0xa801:16,r0
0x0004047c      4604           bne @@0x4:8
0x0004047e      5a040624       jmp @0x624:16
0x00040482      fc03           mov.b #0x3:8,r4l
0x00040484      6b200040       mov.w @0x40:16,r0
0x00040488      52             invalid
0x00040489      825a           add.b #0x5a:8,r2h
0x0004048b      0406           orc #0x6:8,ccr
0x0004048d      1269           rotl r1l
0x0004048f      300d           mov.b r0h,@0xd:8
0x00040491      a109           cmp.b #0x9:8,r1h
0x00040493      1017           shal r7h
0x00040495      7010           bset #0x1:3,r0h
0x00040497      3001           mov.b r0h,@0x1:8
0x00040499      0069           nop
0x0004049b      510a           divxu r0h,r2
0x0004049d      8168           add.b #0x68:8,r1h
0x0004049f      1818           sub.b r1h,r0l
0x000404a1      00e8           nop
0x000404a3      7f             invalid
0x000404a4      6ef8000f       mov.b r0l,@(0xf:16,r7)
0x000404a8      a802           cmp.b #0x2:8,r0l
0x000404aa      4704           beq @@0x4:8
0x000404ac      5a0404b8       jmp @0x4b8:16
0x000404b0      730c           btst #0x0:3,r4l
0x000404b2      4704           beq @@0x4:8
0x000404b4      5a0404cc       jmp @0x4cc:16
0x000404b8      6e78000f       mov.b @(0xf:16,r7),r0l
0x000404bc      a804           cmp.b #0x4:8,r0l
0x000404be      4704           beq @@0x4:8
0x000404c0      5a040610       jmp @0x610:16
0x000404c4      731c           btst #0x1:3,r4l
0x000404c6      4604           bne @@0x4:8
0x000404c8      5a040610       jmp @0x610:16
0x000404cc      0dac           mov.w r10,r4
0x000404ce      5a0405a6       jmp @0x5a6:16
0x000404d2      6930           mov.w @r3,r0
0x000404d4      09c0           add.w r12,r0
0x000404d6      1770           neg r0h
0x000404d8      1030           shal r0h
0x000404da      01006951       sleep
0x000404de      0a81           inc r1h
0x000404e0      6818           mov.b @r1,r0l
0x000404e2      1800           sub.b r0h,r0h
0x000404e4      e87f           and #0x7f:8,r0l
0x000404e6      0c84           mov.b r0l,r4h
0x000404e8      a802           cmp.b #0x2:8,r0l
0x000404ea      4604           bne @@0x4:8
0x000404ec      5a0404f8       jmp @0x4f8:16
0x000404f0      a804           cmp.b #0x4:8,r0l
0x000404f2      4704           beq @@0x4:8
0x000404f4      5a040518       jmp @0x518:16
0x000404f8      a402           cmp.b #0x2:8,r4h
0x000404fa      4704           beq @@0x4:8
0x000404fc      5a040508       jmp @0x508:16
0x00040500      730c           btst #0x0:3,r4l
0x00040502      46             bne @@0x10:8
0x00040504      5a040518       jmp @0x518:16
0x00040508      a404           cmp.b #0x4:8,r4h
0x0004050a      4704           beq @@0x4:8
0x0004050c      5a040582       jmp @0x582:16
0x00040510      731c           btst #0x1:3,r4l
0x00040512      4704           beq @@0x4:8
0x00040514      5a040582       jmp @0x582:16
0x00040518      6930           mov.w @r3,r0
0x0004051a      09c0           add.w r12,r0
0x0004051c      1770           neg r0h
0x0004051e      1030           shal r0h
0x00040520      01006951       sleep
0x00040524      0a81           inc r1h
0x00040526      6911           mov.w @r1,r1
0x00040528      7271           bclr #0x7:3,r1h
0x0004052a      69e1           mov.w r1,@r6
0x0004052c      6ffc0010       mov.w r4,@(0x10:16,r7)
0x00040530      5a040570       jmp @0x570:16
0x00040534      6930           mov.w @r3,r0
0x00040536      6f710010       mov.w @(0x10:16,r7),r1
0x0004053a      0910           add.w r1,r0
0x0004053c      1770           neg r0h
0x0004053e      1030           shal r0h
0x00040540      01006951       sleep
0x00040544      0a81           inc r1h
0x00040546      01006ff1       sleep
0x0004054a      0008           nop
0x0004054c      01006f70       sleep
0x00040550      0008           nop
0x00040552      6900           mov.w @r0,r0
0x00040554      79608000       mov.w #0x8000:16,r0
0x00040558      6962           mov.w @r6,r2
0x0004055a      0902           add.w r0,r2
0x0004055c      6992           mov.w r2,@r1
0x0004055e      6960           mov.w @r6,r0
0x00040560      79100006       mov.w #0x6:16,r0
0x00040564      69e0           mov.w r0,@r6
0x00040566      6f700010       mov.w @(0x10:16,r7),r0
0x0004056a      0b50           adds #1,r0
0x0004056c      6ff00010       mov.w r0,@(0x10:16,r7)
0x00040570      6f700010       mov.w @(0x10:16,r7),r0
0x00040574      0da1           mov.w r10,r1
0x00040576      1d10           cmp.w r1,r0
0x00040578      4204           bhi @@0x4:8
0x0004057a      5a040534       jmp @0x534:16
0x0004057e      5a0405ae       jmp @0x5ae:16
0x00040582      6e78000f       mov.b @(0xf:16,r7),r0l
0x00040586      1c48           cmp.b r4h,r0l
0x00040588      4604           bne @@0x4:8
0x0004058a      5a0405a6       jmp @0x5a6:16
0x0004058e      a402           cmp.b #0x2:8,r4h
0x00040590      4704           beq @@0x4:8
0x00040592      5a04059c       jmp @0x59c:16
0x00040596      720c           bclr #0x0:3,r4l
0x00040598      5a0405a6       jmp @0x5a6:16
0x0004059c      a404           cmp.b #0x4:8,r4h
0x0004059e      4704           beq @@0x4:8
0x000405a0      5a0405a6       jmp @0x5a6:16
0x000405a4      721c           bclr #0x1:3,r4l
0x000405a6      1b5c           subs #1,r4
0x000405a8      4704           beq @@0x4:8
0x000405aa      5a0404d2       jmp @0x4d2:16
0x000405ae      0dcc           mov.w r12,r4
0x000405b0      4704           beq @@0x4:8
0x000405b2      5a0405fc       jmp @0x5fc:16
0x000405b6      6f700002       mov.w @(0x2:16,r7),r0
0x000405ba      69e0           mov.w r0,@r6
0x000405bc      19cc           sub.w r12,r4
0x000405be      5a0405f2       jmp @0x5f2:16
0x000405c2      6930           mov.w @r3,r0
0x000405c4      09c0           add.w r12,r0
0x000405c6      1770           neg r0h
0x000405c8      1030           shal r0h
0x000405ca      01006951       sleep
0x000405ce      0a81           inc r1h
0x000405d0      01006ff1       sleep
0x000405d4      0008           nop
0x000405d6      01006f70       sleep
0x000405da      0008           nop
0x000405dc      6900           mov.w @r0,r0
0x000405de      79608000       mov.w #0x8000:16,r0
0x000405e2      6962           mov.w @r6,r2
0x000405e4      0902           add.w r0,r2
0x000405e6      6992           mov.w r2,@r1
0x000405e8      6960           mov.w @r6,r0
0x000405ea      79100006       mov.w #0x6:16,r0
0x000405ee      69e0           mov.w r0,@r6
0x000405f0      0b5c           adds #1,r4
0x000405f2      0da0           mov.w r10,r0
0x000405f4      1d0c           cmp.w r0,r4
0x000405f6      4204           bhi @@0x4:8
0x000405f8      5a0405c2       jmp @0x5c2:16
0x000405fc      6e78000f       mov.b @(0xf:16,r7),r0l
0x00040600      a802           cmp.b #0x2:8,r0l
0x00040602      4704           beq @@0x4:8
0x00040604      5a04060e       jmp @0x60e:16
0x00040608      720c           bclr #0x0:3,r4l
0x0004060a      5a040610       jmp @0x610:16
0x0004060e      721c           bclr #0x1:3,r4l
0x00040610      0da0           mov.w r10,r0
0x00040612      1b50           subs #1,r0
0x00040614      0d0a           mov.w r0,r2
0x00040616      4604           bne @@0x4:8
0x00040618      5a040624       jmp @0x624:16
0x0004061c      0ccc           mov.b r4l,r4l
0x0004061e      4704           beq @@0x4:8
0x00040620      5a04048e       jmp @0x48e:16
0x00040624      7a             invalid
0x00040625      1700           not r0h
0x00040627      0000           nop
0x00040629      145e           or r5h,r6l
0x0004062b      01643654       sleep
0x0004062f      705e           bset #0x5:3,r6l
0x00040631      044e           orc #0x4e:8,ccr
0x00040633      405e           bra @@0x5e:8
0x00040635      0453           orc #0x53:8,ccr
0x00040637      6e5a0406       mov.b @(0x406:16,r5),r2l
0x0004063b      605e           bset r5h,r6l
0x0004063d      044e           orc #0x4e:8,ccr
0x0004063f      405e           bra @@0x5e:8
0x00040641      0453           orc #0x53:8,ccr
0x00040643      905a           addx #0x5a:8,r0h
0x00040645      0406           orc #0x6:8,ccr
0x00040647      605e           bset r5h,r6l
0x00040649      044e           orc #0x4e:8,ccr
0x0004064b      405e           bra @@0x5e:8
0x0004064d      0453           orc #0x53:8,ccr
0x0004064f      ca5a           or #0x5a:8,r2l
0x00040651      0406           orc #0x6:8,ccr
0x00040653      605e           bset r5h,r6l
0x00040655      044e           orc #0x4e:8,ccr
0x00040657      405e           bra @@0x5e:8
0x00040659      0453           orc #0x53:8,ccr
0x0004065b      d65a           xor #0x5a:8,r6h
0x0004065d      0406           orc #0x6:8,ccr
0x0004065f      605e           bset r5h,r6l
0x00040661      0164581b       sleep
0x00040665      971b           addx #0x1b:8,r7h
0x00040667      877a           add.b #0x7a:8,r7h
0x00040669      0300           ldc r0h,ccr
0x0004066b      4007           bra @@0x7:8
0x0004066d      7618           band #0x1:3,r0l
0x0004066f      557a           bsr .122
0x00040671      0400           orc #0x0:8,ccr
0x00040673      4007           bra @@0x7:8
0x00040675      907a           addx #0x7a:8,r0h
0x00040677      0600           andc #0x0:8,ccr
0x00040679      400b           bra @@0xb:8
0x0004067b      2418           mov.b @0x18:8,r4h
0x0004067d      dd5a           xor #0x5a:8,r5l
0x0004067f      0406           orc #0x6:8,ccr
0x00040681      8c0c           add.b #0xc:8,r4l
0x00040683      d00c           xor #0xc:8,r0h
0x00040685      58             invalid
0x00040686      5e039c6c       jsr @0x9c6c:16
0x0004068a      0a0d           inc r5l
0x0004068c      ad03           cmp.b #0x3:8,r5l
0x0004068e      4204           bhi @@0x4:8
0x00040690      5a040682       jmp @0x682:16
0x00040694      6a280040       mov.b @0x40:16,r0l
0x00040698      0f34           daa r4h
0x0004069a      1750           neg r0h
0x0004069c      17f0           neg r0h
0x0004069e      79010009       mov.w #0x9:16,r1
0x000406a2      01d05310       sleep
0x000406a6      6aa80040       mov.b r0l,@0x40:16
0x000406aa      0f6a           daa r2l
0x000406ac      f801           mov.b #0x1:8,r0l
0x000406ae      6aa80040       mov.b r0l,@0x40:16
0x000406b2      0f69           daa r1l
0x000406b4      1a80           dec r0h
0x000406b6      01006ba0       sleep
0x000406ba      0040           nop
0x000406bc      0f6c           daa r4l
0x000406be      6a280040       mov.b @0x40:16,r0l
0x000406c2      0773           ldc #0x73:8,ccr
0x000406c4      a801           cmp.b #0x1:8,r0l
0x000406c6      4604           bne @@0x4:8
0x000406c8      5a0406dc       jmp @0x6dc:16
0x000406cc      a804           cmp.b #0x4:8,r0l
0x000406ce      4604           bne @@0x4:8
0x000406d0      5a0406dc       jmp @0x6dc:16
0x000406d4      a805           cmp.b #0x5:8,r0l
0x000406d6      4704           beq @@0x4:8
0x000406d8      5a0407be       jmp @0x7be:16
0x000406dc      7a             invalid
0x000406dd      0000           nop
0x000406df      0000           nop
0x000406e1      040a           orc #0xa:8,ccr
0x000406e3      f001           mov.b #0x1:8,r0h
0x000406e5      006d           nop
0x000406e7      f07a           mov.b #0x7a:8,r0h
0x000406e9      0000           nop
0x000406eb      0000           nop
0x000406ed      060a           andc #0xa:8,ccr
0x000406ef      f001           mov.b #0x1:8,r0h
0x000406f1      006d           nop
0x000406f3      f07a           mov.b #0x7a:8,r0h
0x000406f5      01000000       sleep
0x000406f9      080a           add.b r0h,r2l
0x000406fb      f17a           mov.b #0x7a:8,r1h
0x000406fd      0000           nop
0x000406ff      400f           bra @@0xf:8
0x00040701      285e           mov.b @0x5e:8,r0l
0x00040703      03             ldc r0h,ccr
0x00040705      3c0b           mov.b r4l,@0xb:8
0x00040707      970b           addx #0xb:8,r7h
0x00040709      976e           addx #0x6e:8,r7h
0x0004070b      7000           bset #0x0:3,r0h
0x0004070d      046f           orc #0x6f:8,ccr
0x0004070f      7100           bnot #0x0:3,r0h
0x00040711      0269           stc ccr,r1l
0x00040713      78             invalid
0x00040714      f811           mov.b #0x11:8,r0l
0x00040716      5e030322       jsr @0x322:16
0x0004071a      5e0308e6       jsr @0x8e6:16
0x0004071e      6a280040       mov.b @0x40:16,r0l
0x00040722      52             invalid
0x00040723      9aa8           addx #0xa8:8,r2l
0x00040725      0147045a       sleep
0x00040729      0407           orc #0x7:8,ccr
0x0004072b      8c6b           add.b #0x6b:8,r4l
0x0004072d      2000           mov.b @0x0:8,r0h
0x0004072f      4058           bra @@0x58:8
0x00040731      fc6b           mov.b #0x6b:8,r4l
0x00040733      a000           cmp.b #0x0:8,r0h
0x00040735      4052           bra @@0x52:8
0x00040737      8c0b           add.b #0xb:8,r4l
0x00040739      d011           xor #0x11:8,r0h
0x0004073b      1011           shal r1h
0x0004073d      1011           shal r1h
0x0004073f      106a           shal r2l
0x00040741      a800           cmp.b #0x0:8,r0l
0x00040743      400e           bra @@0xe:8
0x00040745      9468           addx #0x68:8,r4h
0x00040747      c8a8           or #0xa8:8,r0l
0x00040749      2944           mov.b @0x44:8,r1l
0x0004074b      045a           orc #0x5a:8,ccr
0x0004074d      0407           orc #0x7:8,ccr
0x0004074f      58             invalid
0x00040750      f828           mov.b #0x28:8,r0l
0x00040752      68c8           mov.b r0l,@r4
0x00040754      5a040764       jmp @0x764:16
0x00040758      6848           mov.b @r4,r0l
0x0004075a      4704           beq @@0x4:8
0x0004075c      5a040764       jmp @0x764:16
0x00040760      f801           mov.b #0x1:8,r0l
0x00040762      68c8           mov.b r0l,@r4
0x00040764      1a80           dec r0h
0x00040766      6848           mov.b @r4,r0l
0x00040768      1030           shal r0h
0x0004076a      1030           shal r0h
0x0004076c      01007800       sleep
0x00040770      6b200040       mov.w @0x40:16,r0
0x00040774      5098           mulxu r1l,r0
0x00040776      01006ba0       sleep
0x0004077a      0040           nop
0x0004077c      52             invalid
0x0004077d      7c7a0000       biand #0x0:3,@r7
0x00040781      4007           bra @@0x7:8
0x00040783      7c7d0070       biand #0x7:3,@r7
0x00040787      405a           bra @@0x5a:8
0x00040789      0408           orc #0x8:8,ccr
0x0004078b      e46b           and #0x6b:8,r4h
0x0004078d      2000           mov.b @0x0:8,r0h
0x0004078f      400f           bra @@0xf:8
0x00040791      2a6b           mov.b @0x6b:8,r2l
0x00040793      a000           cmp.b #0x0:8,r0h
0x00040795      400f           bra @@0xf:8
0x00040797      266a           mov.b @0x6a:8,r6h
0x00040799      2800           mov.b @0x0:8,r0l
0x0004079b      400f           bra @@0xf:8
0x0004079d      5ba8           jmp @@0xa8:8
0x0004079f      0147045a       sleep
0x000407a3      0407           orc #0x7:8,ccr
0x000407a5      b069           subx #0x69:8,r0h
0x000407a7      606f           bset r6h,r7l
0x000407a9      6100           bnot r0h,r0h
0x000407ab      0a5a           inc r2l
0x000407ad      0407           orc #0x7:8,ccr
0x000407af      b669           subx #0x69:8,r6h
0x000407b1      606f           bset r6h,r7l
0x000407b3      6100           bnot r0h,r0h
0x000407b5      1209           rotxl r1l
0x000407b7      106b           shal r3l
0x000407b9      a000           cmp.b #0x0:8,r0h
0x000407bb      400f           bra @@0xf:8
0x000407bd      266a           mov.b @0x6a:8,r6h
0x000407bf      2800           mov.b @0x0:8,r0l
0x000407c1      4007           bra @@0x7:8
0x000407c3      73a8           btst #0x2:3,r0l
0x000407c5      0247           stc ccr,r7h
0x000407c7      045a           orc #0x5a:8,ccr
0x000407c9      0407           orc #0x7:8,ccr
0x000407cb      d66a           xor #0x6a:8,r6h
0x000407cd      2800           mov.b @0x0:8,r0l
0x000407cf      406e           bra @@0x6e:8
0x000407d1      865e           add.b #0x5e:8,r6h
0x000407d3      034d           ldc r5l,ccr
0x000407d5      f66b           mov.b #0x6b:8,r6h
0x000407d7      2000           mov.b @0x0:8,r0h
0x000407d9      4007           bra @@0x7:8
0x000407db      78             invalid
0x000407dc      4704           beq @@0x4:8
0x000407de      5a0408e4       jmp @0x8e4:16
0x000407e2      7c307370       biand #0x7:3,@r3
0x000407e6      4704           beq @@0x4:8
0x000407e8      5a0408e4       jmp @0x8e4:16
0x000407ec      0c58           mov.b r5h,r0l
0x000407ee      6df0           push r0
0x000407f0      1a91           dec r1h
0x000407f2      6b200040       mov.w @0x40:16,r0
0x000407f6      0f26           daa r6h
0x000407f8      5e02d7ae       jsr @0xd7ae:16
0x000407fc      0b87           adds #2,r7
0x000407fe      5e02d598       jsr @0xd598:16
0x00040802      0c88           mov.b r0l,r0l
0x00040804      46             bne @@0x10:8
0x00040806      5a0407ec       jmp @0x7ec:16
0x0004080a      fa01           mov.b #0x1:8,r2l
0x0004080c      5e0411e8       jsr @0x11e8:16
0x00040810      7c307370       biand #0x7:3,@r3
0x00040814      4704           beq @@0x4:8
0x00040816      5a0408e4       jmp @0x8e4:16
0x0004081a      18dd           sub.b r5l,r5l
0x0004081c      5a04089a       jmp @0x89a:16
0x00040820      5e037d18       jsr @0x7d18:16
0x00040824      7c307370       biand #0x7:3,@r3
0x00040828      4704           beq @@0x4:8
0x0004082a      5a0408e4       jmp @0x8e4:16
0x0004082e      6b200040       mov.w @0x40:16,r0
0x00040832      0778           ldc #0x78:8,ccr
0x00040834      4704           beq @@0x4:8
0x00040836      5a0408e4       jmp @0x8e4:16
0x0004083a      5e0358ec       jsr @0x58ec:16
0x0004083e      f822           mov.b #0x22:8,r0l
0x00040840      6aa80020       mov.b r0l,@0x20:16
0x00040844      01020ca8       sleep
0x00040848      5e0408fe       jsr @0x8fe:16
0x0004084c      7c307370       biand #0x7:3,@r3
0x00040850      4704           beq @@0x4:8
0x00040852      5a0408e4       jmp @0x8e4:16
0x00040856      ad01           cmp.b #0x1:8,r5l
0x00040858      4704           beq @@0x4:8
0x0004085a      5a040866       jmp @0x866:16
0x0004085e      5e041ea6       jsr @0x1ea6:16
0x00040862      5a0408a2       jmp @0x8a2:16
0x00040866      5e0414e4       jsr @0x14e4:16
0x0004086a      0c88           mov.b r0l,r0l
0x0004086c      4704           beq @@0x4:8
0x0004086e      5a0408a2       jmp @0x8a2:16
0x00040872      0c58           mov.b r5h,r0l
0x00040874      6df0           push r0
0x00040876      6f6101a4       mov.w @(0x1a4:16,r6),r1
0x0004087a      790903e8       mov.w #0x3e8:16,r1
0x0004087e      52             invalid
0x0004087f      916b           addx #0x6b:8,r1h
0x00040881      2000           mov.b @0x0:8,r0h
0x00040883      400f           bra @@0xf:8
0x00040885      265e           mov.b @0x5e:8,r6h
0x00040887      02d7           stc ccr,r7h
0x00040889      ae0b           cmp.b #0xb:8,r6l
0x0004088b      875e           add.b #0x5e:8,r7h
0x0004088d      02d5           stc ccr,r5h
0x0004088f      980c           addx #0xc:8,r0l
0x00040891      8846           add.b #0x46:8,r0l
0x00040893      045a           orc #0x5a:8,ccr
0x00040895      0408           orc #0x8:8,ccr
0x00040897      720a           bclr #0x0:3,r2l
0x00040899      0dad           mov.w r10,r5
0x0004089b      0244           stc ccr,r4h
0x0004089d      045a           orc #0x5a:8,ccr
0x0004089f      0408           orc #0x8:8,ccr
0x000408a1      205e           mov.b @0x5e:8,r0h
0x000408a3      02d4           stc ccr,r4h
0x000408a5      e27c           and #0x7c:8,r2h
0x000408a7      3073           mov.b r0h,@0x73:8
0x000408a9      7047           bset #0x4:3,r7h
0x000408ab      045a           orc #0x5a:8,ccr
0x000408ad      0408           orc #0x8:8,ccr
0x000408af      e45e           and #0x5e:8,r4h
0x000408b1      041e           orc #0x1e:8,ccr
0x000408b3      e86a           and #0x6a:8,r0l
0x000408b5      2800           mov.b @0x0:8,r0l
0x000408b7      4010           bra @@0x10:8
0x000408b9      66             invalid
0x000408ba      a801           cmp.b #0x1:8,r0l
0x000408bc      4704           beq @@0x4:8
0x000408be      5a0408c6       jmp @0x8c6:16
0x000408c2      5e037338       jsr @0x7338:16
0x000408c6      1a80           dec r0h
0x000408c8      6a280040       mov.b @0x40:16,r0l
0x000408cc      0f5b           daa r3l
0x000408ce      1030           shal r0h
0x000408d0      1030           shal r0h
0x000408d2      1030           shal r0h
0x000408d4      1030           shal r0h
0x000408d6      7a             invalid
0x000408d7      1000           shll r0h
0x000408d9      400f           bra @@0xf:8
0x000408db      ae5e           cmp.b #0x5e:8,r6l
0x000408dd      039c           ldc r4l,ccr
0x000408df      8a5a           add.b #0x5a:8,r2l
0x000408e1      0408           orc #0x8:8,ccr
0x000408e3      f46a           mov.b #0x6a:8,r4h
0x000408e5      2800           mov.b @0x0:8,r0l
0x000408e7      400f           bra @@0xf:8
0x000408e9      5b47           jmp @@0x47:8
0x000408eb      045a           orc #0x5a:8,ccr
0x000408ed      0408           orc #0x8:8,ccr
0x000408ef      f45e           mov.b #0x5e:8,r4h
0x000408f1      0373           ldc r3h,ccr
0x000408f3      380b           mov.b r0l,@0xb:8
0x000408f5      870b           add.b #0xb:8,r7h
0x000408f7      975e           addx #0x5e:8,r7h
0x000408f9      01643654       sleep
0x000408fd      705e           bset #0x5:3,r6l
0x000408ff      0164587a       sleep
0x00040903      3700           mov.b r7h,@0x0:8
0x00040905      00             nop
0x00040907      6e7a0300       mov.b @(0x300:16,r7),r2l
0x0004090b      400f           bra @@0xf:8
0x0004090d      556e           bsr .110
0x0004090f      f800           mov.b #0x0:8,r0l
0x00040911      65             invalid
0x00040912      6a290040       mov.b @0x40:16,r1l
0x00040916      0773           ldc #0x73:8,ccr
0x00040918      a902           cmp.b #0x2:8,r1l
0x0004091a      4604           bne @@0x4:8
0x0004091c      5a040938       jmp @0x938:16
0x00040920      a901           cmp.b #0x1:8,r1l
0x00040922      4604           bne @@0x4:8
0x00040924      5a040938       jmp @0x938:16
0x00040928      a904           cmp.b #0x4:8,r1l
0x0004092a      4604           bne @@0x4:8
0x0004092c      5a040938       jmp @0x938:16
0x00040930      a905           cmp.b #0x5:8,r1l
0x00040932      4704           beq @@0x4:8
0x00040934      5a04094a       jmp @0x94a:16
0x00040938      1888           sub.b r0l,r0l
0x0004093a      7ed27710       bld #0x1:3,@0xd2:8
0x0004093e      6708           bst #0x0:3,r0l
0x00040940      6aa80040       mov.b r0l,@0x40:16
0x00040944      53             invalid
0x00040945      037f           ldc r7l,ccr
0x00040947      d270           xor #0x70:8,r2h
0x00040949      10f8           shal r0l
0x0004094b      026a           stc ccr,r2l
0x0004094d      a800           cmp.b #0x0:8,r0l
0x0004094f      2000           mov.b @0x0:8,r0h
0x00040951      0118cc7a       sleep
0x00040955      0000           nop
0x00040957      400f           bra @@0xf:8
0x00040959      8801           add.b #0x1:8,r0l
0x0004095b      006f           nop
0x0004095d      f000           mov.b #0x0:8,r0h
0x0004095f      66             invalid
0x00040960      5a040bca       jmp @0xbca:16
0x00040964      0cc8           mov.b r4l,r0l
0x00040966      1750           neg r0h
0x00040968      1770           neg r0h
0x0004096a      78             invalid
0x0004096b      006a           nop
0x0004096d      2e00           mov.b @0x0:8,r6l
0x0004096f      400f           bra @@0xf:8
0x00040971      5647           rte
0x00040973      045a           orc #0x5a:8,ccr
0x00040975      0409           orc #0x9:8,ccr
0x00040977      9a0c           addx #0xc:8,r2l
0x00040979      e817           and #0x17:8,r0l
0x0004097b      5017           mulxu r1h,r7
0x0004097d      7010           bset #0x1:3,r0h
0x0004097f      3010           mov.b r0h,@0x10:8
0x00040981      307a           mov.b r0h,@0x7a:8
0x00040983      01000000       sleep
0x00040987      440a           bcc @@0xa:8
0x00040989      f10a           mov.b #0xa:8,r1h
0x0004098b      817a           add.b #0x7a:8,r1h
0x0004098d      0000           nop
0x0004098f      c080           or #0x80:8,r0h
0x00040991      0001           nop
0x00040993      0069           nop
0x00040995      905a           addx #0x5a:8,r0h
0x00040997      0409           orc #0x9:8,ccr
0x00040999      eaae           and #0xae:8,r2l
0x0004099b      0147045a       sleep
0x0004099f      0409           orc #0x9:8,ccr
0x000409a1      c40c           or #0xc:8,r4h
0x000409a3      e817           and #0x17:8,r0l
0x000409a5      5017           mulxu r1h,r7
0x000409a7      7010           bset #0x1:3,r0h
0x000409a9      3010           mov.b r0h,@0x10:8
0x000409ab      307a           mov.b r0h,@0x7a:8
0x000409ad      01000000       sleep
0x000409b1      440a           bcc @@0xa:8
0x000409b3      f10a           mov.b #0xa:8,r1h
0x000409b5      817a           add.b #0x7a:8,r1h
0x000409b7      0000           nop
0x000409b9      8380           add.b #0x80:8,r3h
0x000409bb      0001           nop
0x000409bd      0069           nop
0x000409bf      905a           addx #0x5a:8,r0h
0x000409c1      0409           orc #0x9:8,ccr
0x000409c3      eaae           and #0xae:8,r2l
0x000409c5      0247           stc ccr,r7h
0x000409c7      045a           orc #0x5a:8,ccr
0x000409c9      0409           orc #0x9:8,ccr
0x000409cb      ea0c           and #0xc:8,r2l
0x000409cd      e817           and #0x17:8,r0l
0x000409cf      5017           mulxu r1h,r7
0x000409d1      7010           bset #0x1:3,r0h
0x000409d3      3010           mov.b r0h,@0x10:8
0x000409d5      307a           mov.b r0h,@0x7a:8
0x000409d7      01000000       sleep
0x000409db      440a           bcc @@0xa:8
0x000409dd      f10a           mov.b #0xa:8,r1h
0x000409df      817a           add.b #0x7a:8,r1h
0x000409e1      0000           nop
0x000409e3      4180           brn @@0x80:8
0x000409e5      0001           nop
0x000409e7      0069           nop
0x000409e9      900c           addx #0xc:8,r0h
0x000409eb      ed17           and #0x17:8,r5l
0x000409ed      5517           bsr .23
0x000409ef      750f           bxor #0x0:3,r7l
0x000409f1      d010           xor #0x10:8,r0h
0x000409f3      3019           mov.b r0h,@0x19:8
0x000409f5      1178           shar r0l
0x000409f7      006b           nop
0x000409f9      a100           cmp.b #0x0:8,r1h
0x000409fb      406e           bra @@0x6e:8
0x000409fd      2219           mov.b @0x19:8,r2h
0x000409ff      1178           shar r0l
0x00040a01      006b           nop
0x00040a03      a100           cmp.b #0x0:8,r1h
0x00040a05      406e           bra @@0x6e:8
0x00040a07      2a78           mov.b @0x78:8,r2l
0x00040a09      506a           mulxu r6h,r2
0x00040a0b      2800           mov.b @0x0:8,r0l
0x00040a0d      404e           bra @@0x4e:8
0x00040a0f      5047           mulxu r4h,r7
0x00040a11      045a           orc #0x5a:8,ccr
0x00040a13      040a           orc #0xa:8,ccr
0x00040a15      820c           add.b #0xc:8,r2h
0x00040a17      ed17           and #0x17:8,r5l
0x00040a19      5517           bsr .23
0x00040a1b      7510           bxor #0x1:3,r0h
0x00040a1d      3510           mov.b r5h,@0x10:8
0x00040a1f      357a           mov.b r5h,@0x7a:8
0x00040a21      0000           nop
0x00040a23      0000           nop
0x00040a25      540a           rts
0x00040a27      f00a           mov.b #0xa:8,r0h
0x00040a29      d001           xor #0x1:8,r0h
0x00040a2b      0078           nop
0x00040a2d      506b           mulxu r6h,r3
0x00040a2f      2100           mov.b @0x0:8,r1h
0x00040a31      400f           bra @@0xf:8
0x00040a33      9e01           addx #0x1:8,r6l
0x00040a35      006f           nop
0x00040a37      f000           mov.b #0x0:8,r0h
0x00040a39      287a           mov.b @0x7a:8,r0l
0x00040a3b      0000           nop
0x00040a3d      0000           nop
0x00040a3f      2c0a           mov.b @0xa:8,r4l
0x00040a41      f05e           mov.b #0x5e:8,r0h
0x00040a43      01648001       sleep
0x00040a47      0078           nop
0x00040a49      506b           mulxu r6h,r3
0x00040a4b      2100           mov.b @0x0:8,r1h
0x00040a4d      4010           bra @@0x10:8
0x00040a4f      8801           add.b #0x1:8,r0l
0x00040a51      006f           nop
0x00040a53      f000           mov.b #0x0:8,r0h
0x00040a55      1c7a           cmp.b r7h,r2l
0x00040a57      0000           nop
0x00040a59      0000           nop
0x00040a5b      200a           mov.b @0xa:8,r0h
0x00040a5d      f05e           mov.b #0x5e:8,r0h
0x00040a5f      015f3401       sleep
0x00040a63      006f           nop
0x00040a65      7100           bnot #0x0:3,r0h
0x00040a67      1c0f           cmp.b r0h,r7l
0x00040a69      827a           add.b #0x7a:8,r2h
0x00040a6b      0000           nop
0x00040a6d      0000           nop
0x00040a6f      140a           or r0h,r2l
0x00040a71      f05e           mov.b #0x5e:8,r0h
0x00040a73      01551801       sleep
0x00040a77      006b           nop
0x00040a79      2100           mov.b @0x0:8,r1h
0x00040a7b      400f           bra @@0xf:8
0x00040a7d      845a           add.b #0x5a:8,r4h
0x00040a7f      040a           orc #0xa:8,ccr
0x00040a81      ec0c           and #0xc:8,r4l
0x00040a83      ed17           and #0x17:8,r5l
0x00040a85      5517           bsr .23
0x00040a87      7510           bxor #0x1:3,r0h
0x00040a89      3510           mov.b r5h,@0x10:8
0x00040a8b      357a           mov.b r5h,@0x7a:8
0x00040a8d      0000           nop
0x00040a8f      0000           nop
0x00040a91      540a           rts
0x00040a93      f00a           mov.b #0xa:8,r0h
0x00040a95      d001           xor #0x1:8,r0h
0x00040a97      0078           nop
0x00040a99      506b           mulxu r6h,r3
0x00040a9b      2100           mov.b @0x0:8,r1h
0x00040a9d      400f           bra @@0xf:8
0x00040a9f      9e01           addx #0x1:8,r6l
0x00040aa1      006f           nop
0x00040aa3      f000           mov.b #0x0:8,r0h
0x00040aa5      287a           mov.b @0x7a:8,r0l
0x00040aa7      0000           nop
0x00040aa9      0000           nop
0x00040aab      2c0a           mov.b @0xa:8,r4l
0x00040aad      f05e           mov.b #0x5e:8,r0h
0x00040aaf      01648001       sleep
0x00040ab3      0078           nop
0x00040ab5      506b           mulxu r6h,r3
0x00040ab7      2100           mov.b @0x0:8,r1h
0x00040ab9      4010           bra @@0x10:8
0x00040abb      8801           add.b #0x1:8,r0l
0x00040abd      006f           nop
0x00040abf      f000           mov.b #0x0:8,r0h
0x00040ac1      1c7a           cmp.b r7h,r2l
0x00040ac3      0000           nop
0x00040ac5      0000           nop
0x00040ac7      200a           mov.b @0xa:8,r0h
0x00040ac9      f05e           mov.b #0x5e:8,r0h
0x00040acb      015f3401       sleep
0x00040acf      006f           nop
0x00040ad1      7100           bnot #0x0:3,r0h
0x00040ad3      1c0f           cmp.b r0h,r7l
0x00040ad5      827a           add.b #0x7a:8,r2h
0x00040ad7      0000           nop
0x00040ad9      0000           nop
0x00040adb      140a           or r0h,r2l
0x00040add      f05e           mov.b #0x5e:8,r0h
0x00040adf      01551801       sleep
0x00040ae3      006f           nop
0x00040ae5      7100           bnot #0x0:3,r0h
0x00040ae7      66             invalid
0x00040ae8      01006911       sleep
0x00040aec      01006ff0       sleep
0x00040af0      0008           nop
0x00040af2      7a             invalid
0x00040af3      0000           nop
0x00040af5      0000           nop
0x00040af7      0c0a           mov.b r0h,r2l
0x00040af9      f05e           mov.b #0x5e:8,r0h
0x00040afb      015db401       sleep
0x00040aff      006f           nop
0x00040b01      7100           bnot #0x0:3,r0h
0x00040b03      080f           add.b r0h,r7l
0x00040b05      820f           add.b #0xf:8,r2h
0x00040b07      f05e           mov.b #0x5e:8,r0h
0x00040b09      0159a45e       sleep
0x00040b0d      015d2e01       sleep
0x00040b11      006f           nop
0x00040b13      7100           bnot #0x0:3,r0h
0x00040b15      2801           mov.b @0x1:8,r0l
0x00040b17      0069           nop
0x00040b19      90ae           addx #0xae:8,r0h
0x00040b1b      0346           ldc r6h,ccr
0x00040b1d      045a           orc #0x5a:8,ccr
0x00040b1f      040b           orc #0xb:8,ccr
0x00040b21      c41a           or #0x1a:8,r4h
0x00040b23      d50c           xor #0xc:8,r5h
0x00040b25      ed10           and #0x10:8,r5l
0x00040b27      3510           mov.b r5h,@0x10:8
0x00040b29      357a           mov.b r5h,@0x7a:8
0x00040b2b      0000           nop
0x00040b2d      0000           nop
0x00040b2f      440a           bcc @@0xa:8
0x00040b31      f00a           mov.b #0xa:8,r0h
0x00040b33      8501           add.b #0x1:8,r5h
0x00040b35      0069           nop
0x00040b37      551a           bsr .26
0x00040b39      e65a           and #0x5a:8,r6h
0x00040b3b      040b           orc #0xb:8,ccr
0x00040b3d      480f           bvc @@0xf:8
0x00040b3f      d00b           xor #0xb:8,r0h
0x00040b41      f519           mov.b #0x19:8,r5h
0x00040b43      1169           shar r1l
0x00040b45      810b           add.b #0xb:8,r1h
0x00040b47      767a           band #0x7:3,r2l
0x00040b49      2600           mov.b @0x0:8,r6h
0x00040b4b      0010           nop
0x00040b4d      0044           nop
0x00040b4f      045a           orc #0x5a:8,ccr
0x00040b51      040b           orc #0xb:8,ccr
0x00040b53      3e5e           mov.b r6l,@0x5e:8
0x00040b55      0109e27a       sleep
0x00040b59      0600           andc #0x0:8,ccr
0x00040b5b      0010           nop
0x00040b5d      005a           nop
0x00040b5f      040b           orc #0xb:8,ccr
0x00040b61      6c0f           mov.b @r0+,r7l
0x00040b63      d00b           xor #0xb:8,r0h
0x00040b65      f519           mov.b #0x19:8,r5h
0x00040b67      1169           shar r1l
0x00040b69      810b           add.b #0xb:8,r1h
0x00040b6b      767a           band #0x7:3,r2l
0x00040b6d      2600           mov.b @0x0:8,r6h
0x00040b6f      0020           nop
0x00040b71      0044           nop
0x00040b73      045a           orc #0x5a:8,ccr
0x00040b75      040b           orc #0xb:8,ccr
0x00040b77      625e           bclr r5h,r6l
0x00040b79      0109e27a       sleep
0x00040b7d      0600           andc #0x0:8,ccr
0x00040b7f      0020           nop
0x00040b81      005a           nop
0x00040b83      040b           orc #0xb:8,ccr
0x00040b85      900f           addx #0xf:8,r0h
0x00040b87      d00b           xor #0xb:8,r0h
0x00040b89      f519           mov.b #0x19:8,r5h
0x00040b8b      1169           shar r1l
0x00040b8d      810b           add.b #0xb:8,r1h
0x00040b8f      767a           band #0x7:3,r2l
0x00040b91      2600           mov.b @0x0:8,r6h
0x00040b93      0030           nop
0x00040b95      0044           nop
0x00040b97      045a           orc #0x5a:8,ccr
0x00040b99      040b           orc #0xb:8,ccr
0x00040b9b      865e           add.b #0x5e:8,r6h
0x00040b9d      0109e27a       sleep
0x00040ba1      0600           andc #0x0:8,ccr
0x00040ba3      0030           nop
0x00040ba5      005a           nop
0x00040ba7      040b           orc #0xb:8,ccr
0x00040ba9      b40f           subx #0xf:8,r4h
0x00040bab      d00b           xor #0xb:8,r0h
0x00040bad      f519           mov.b #0x19:8,r5h
0x00040baf      1169           shar r1l
0x00040bb1      810b           add.b #0xb:8,r1h
0x00040bb3      767a           band #0x7:3,r2l
0x00040bb5      2600           mov.b @0x0:8,r6h
0x00040bb7      0040           nop
0x00040bb9      0044           nop
0x00040bbb      045a           orc #0x5a:8,ccr
0x00040bbd      040b           orc #0xb:8,ccr
0x00040bbf      aa5e           cmp.b #0x5e:8,r2l
0x00040bc1      0109e25e       sleep
0x00040bc5      0109e20a       sleep
0x00040bc9      0c68           mov.b r6h,r0l
0x00040bcb      381c           mov.b r0l,@0x1c:8
0x00040bcd      8c44           add.b #0x44:8,r4l
0x00040bcf      045a           orc #0x5a:8,ccr
0x00040bd1      0409           orc #0x9:8,ccr
0x00040bd3      64             invalid
0x00040bd4      6838           mov.b @r3,r0l
0x00040bd6      a801           cmp.b #0x1:8,r0l
0x00040bd8      4704           beq @@0x4:8
0x00040bda      5a040bec       jmp @0xbec:16
0x00040bde      6a280040       mov.b @0x40:16,r0l
0x00040be2      0f56           daa r6h
0x00040be4      a803           cmp.b #0x3:8,r0l
0x00040be6      4604           bne @@0x4:8
0x00040be8      5a040bf4       jmp @0xbf4:16
0x00040bec      1900           sub.w r0,r0
0x00040bee      6ba00040       mov.w r0,@0x40:16
0x00040bf2      6e321ad5       mov.b @(0x1ad5:16,r3),r2h
0x00040bf6      18ee           sub.b r6l,r6l
0x00040bf8      5a040cc2       jmp @0xcc2:16
0x00040bfc      0cec           mov.b r6l,r4l
0x00040bfe      1754           neg r4h
0x00040c00      1774           neg r4h
0x00040c02      0fc2           daa r2h
0x00040c04      1032           shal r2h
0x00040c06      10             shal r0h
0x00040c08      7a             invalid
0x00040c09      0000           nop
0x00040c0b      0000           nop
0x00040c0d      340a           mov.b r4h,@0xa:8
0x00040c0f      f00a           mov.b #0xa:8,r0h
0x00040c11      a01a           cmp.b #0x1a:8,r0h
0x00040c13      9178           addx #0x78:8,r1h
0x00040c15      406a           bra @@0x6a:8
0x00040c17      2900           mov.b @0x0:8,r1l
0x00040c19      400f           bra @@0xf:8
0x00040c1b      5610           rte
0x00040c1d      3110           mov.b r1h,@0x10:8
0x00040c1f      317a           mov.b r1h,@0x7a:8
0x00040c21      0200           stc ccr,r0h
0x00040c23      0000           nop
0x00040c25      540a           rts
0x00040c27      f20a           mov.b #0xa:8,r2h
0x00040c29      9201           addx #0x1:8,r2h
0x00040c2b      006f           nop
0x00040c2d      f000           mov.b #0x0:8,r0h
0x00040c2f      3001           mov.b r0h,@0x1:8
0x00040c31      0069           nop
0x00040c33      207a           mov.b @0x7a:8,r0h
0x00040c35      01000000       sleep
0x00040c39      0a5e           inc r6l
0x00040c3b      0163ea7a       sleep
0x00040c3f      01000003       sleep
0x00040c43      e85e           and #0x5e:8,r0l
0x00040c45      015cf201       sleep
0x00040c49      006f           nop
0x00040c4b      7100           bnot #0x0:3,r0h
0x00040c4d      3001           mov.b r0h,@0x1:8
0x00040c4f      0069           nop
0x00040c51      9068           addx #0x68:8,r0h
0x00040c53      3817           mov.b r0l,@0x17:8
0x00040c55      501b           mulxu r1h,r3
0x00040c57      500c           mulxu r0h,r4
0x00040c59      e917           and #0x17:8,r1l
0x00040c5b      511d           divxu r1h,r5
0x00040c5d      0146045a       sleep
0x00040c61      040c           orc #0xc:8,ccr
0x00040c63      9a0c           addx #0xc:8,r2l
0x00040c65      e817           and #0x17:8,r0l
0x00040c67      5017           mulxu r1h,r7
0x00040c69      7010           bset #0x1:3,r0h
0x00040c6b      3010           mov.b r0h,@0x10:8
0x00040c6d      307a           mov.b r0h,@0x7a:8
0x00040c6f      01000000       sleep
0x00040c73      340a           mov.b r4h,@0xa:8
0x00040c75      f10a           mov.b #0xa:8,r1h
0x00040c77      816b           add.b #0x6b:8,r1h
0x00040c79      2000           mov.b @0x0:8,r0h
0x00040c7b      400c           bra @@0xc:8
0x00040c7d      de17           xor #0x17:8,r6l
0x00040c7f      7001           bset #0x0:3,r1h
0x00040c81      0069           nop
0x00040c83      111f           shar r7l
0x00040c85      8143           add.b #0x43:8,r1h
0x00040c87      045a           orc #0x5a:8,ccr
0x00040c89      040c           orc #0xc:8,ccr
0x00040c8b      9a6b           addx #0x6b:8,r2l
0x00040c8d      2000           mov.b @0x0:8,r0h
0x00040c8f      400c           bra @@0xc:8
0x00040c91      de17           xor #0x17:8,r6l
0x00040c93      700a           bset #0x0:3,r2l
0x00040c95      855a           add.b #0x5a:8,r5h
0x00040c97      040c           orc #0xc:8,ccr
0x00040c99      b40c           subx #0xc:8,r4h
0x00040c9b      e817           and #0x17:8,r0l
0x00040c9d      5017           mulxu r1h,r7
0x00040c9f      7010           bset #0x1:3,r0h
0x00040ca1      3010           mov.b r0h,@0x10:8
0x00040ca3      307a           mov.b r0h,@0x7a:8
0x00040ca5      01000000       sleep
0x00040ca9      340a           mov.b r4h,@0xa:8
0x00040cab      f10a           mov.b #0xa:8,r1h
0x00040cad      8101           add.b #0x1:8,r1h
0x00040caf      0069           nop
0x00040cb1      110a           shlr r2l
0x00040cb3      9568           addx #0x68:8,r5h
0x00040cb5      3817           mov.b r0l,@0x17:8
0x00040cb7      501b           mulxu r1h,r3
0x00040cb9      500c           mulxu r0h,r4
0x00040cbb      e917           and #0x17:8,r1l
0x00040cbd      511d           divxu r1h,r5
0x00040cbf      010a0e68       sleep
0x00040cc3      381c           mov.b r0l,@0x1c:8
0x00040cc5      8e44           add.b #0x44:8,r6l
0x00040cc7      045a           orc #0x5a:8,ccr
0x00040cc9      040b           orc #0xb:8,ccr
0x00040ccb      fc7a           mov.b #0x7a:8,r4l
0x00040ccd      2500           mov.b @0x0:8,r5h
0x00040ccf      0009           nop
0x00040cd1      6045           bset r4h,r5h
0x00040cd3      045a           orc #0x5a:8,ccr
0x00040cd5      040c           orc #0xc:8,ccr
0x00040cd7      de1a           xor #0x1a:8,r6l
0x00040cd9      d55a           xor #0x5a:8,r5h
0x00040cdb      040c           orc #0xc:8,ccr
0x00040cdd      e47a           and #0x7a:8,r4h
0x00040cdf      3500           mov.b r5h,@0x0:8
0x00040ce1      0009           nop
0x00040ce3      607a           bset r7h,r2l
0x00040ce5      2500           mov.b @0x0:8,r5h
0x00040ce7      0000           nop
0x00040ce9      c845           or #0x45:8,r0l
0x00040ceb      045a           orc #0x5a:8,ccr
0x00040ced      040c           orc #0xc:8,ccr
0x00040cef      f61a           mov.b #0x1a:8,r6h
0x00040cf1      d55a           xor #0x5a:8,r5h
0x00040cf3      040c           orc #0xc:8,ccr
0x00040cf5      fc7a           mov.b #0x7a:8,r4l
0x00040cf7      3500           mov.b r5h,@0x0:8
0x00040cf9      0000           nop
0x00040cfb      c87a           or #0x7a:8,r0l
0x00040cfd      0600           andc #0x0:8,ccr
0x00040cff      0231           stc ccr,r1h
0x00040d01      601a           bset r1h,r2l
0x00040d03      806a           add.b #0x6a:8,r0h
0x00040d05      2800           mov.b @0x0:8,r0l
0x00040d07      40             bra @@0x10:8
0x00040d09      5610           rte
0x00040d0b      3010           mov.b r0h,@0x10:8
0x00040d0d      307a           mov.b r0h,@0x7a:8
0x00040d0f      01000000       sleep
0x00040d13      540a           rts
0x00040d15      f10a           mov.b #0xa:8,r1h
0x00040d17      8101           add.b #0x1:8,r1h
0x00040d19      0069           nop
0x00040d1b      110b           shlr r3l
0x00040d1d      711f           bnot #0x1:3,r7l
0x00040d1f      e145           and #0x45:8,r1h
0x00040d21      045a           orc #0x5a:8,ccr
0x00040d23      040e           orc #0xe:8,ccr
0x00040d25      0c6a           mov.b r6h,r2l
0x00040d27      2c00           mov.b @0x0:8,r4l
0x00040d29      400f           bra @@0xf:8
0x00040d2b      560c           rte
0x00040d2d      c817           or #0x17:8,r0l
0x00040d2f      5017           mulxu r1h,r7
0x00040d31      7010           bset #0x1:3,r0h
0x00040d33      3010           mov.b r0h,@0x10:8
0x00040d35      307a           mov.b r0h,@0x7a:8
0x00040d37      01000000       sleep
0x00040d3b      540a           rts
0x00040d3d      f10a           mov.b #0xa:8,r1h
0x00040d3f      8101           add.b #0x1:8,r1h
0x00040d41      0069           nop
0x00040d43      111a           shar r2l
0x00040d45      967a           addx #0x7a:8,r6h
0x00040d47      1600           and r0h,r0h
0x00040d49      0001           nop
0x00040d4b      2a0c           mov.b @0xc:8,r2l
0x00040d4d      c846           or #0x46:8,r0l
0x00040d4f      045a           orc #0x5a:8,ccr
0x00040d51      040d           orc #0xd:8,ccr
0x00040d53      70a8           bset #0x2:3,r0l
0x00040d55      0146045a       sleep
0x00040d59      040d           orc #0xd:8,ccr
0x00040d5b      98a8           addx #0xa8:8,r0l
0x00040d5d      0246           stc ccr,r6h
0x00040d5f      045a           orc #0x5a:8,ccr
0x00040d61      040d           orc #0xd:8,ccr
0x00040d63      c0a8           or #0xa8:8,r0h
0x00040d65      0346           ldc r6h,ccr
0x00040d67      045a           orc #0x5a:8,ccr
0x00040d69      040d           orc #0xd:8,ccr
0x00040d6b      e85a           and #0x5a:8,r0l
0x00040d6d      040e           orc #0xe:8,ccr
0x00040d6f      0c0d           mov.b r0h,r5l
0x00040d71      e019           and #0x19:8,r0h
0x00040d73      886a           add.b #0x6a:8,r0l
0x00040d75      a800           cmp.b #0x0:8,r0l
0x00040d77      2004           mov.b @0x4:8,r0h
0x00040d79      6d0f           mov.w @r0+,r7
0x00040d7b      e0f9           and #0xf9:8,r0h
0x00040d7d      0811           add.b r1h,r1h
0x00040d7f      301a           mov.b r0h,@0x1a:8
0x00040d81      094f           add.w r4,r7
0x00040d83      045a           orc #0x5a:8,ccr
0x00040d85      040d           orc #0xd:8,ccr
0x00040d87      7e6aa800       biand #0x0:3,@0x6a:8
0x00040d8b      2004           mov.b @0x4:8,r0h
0x00040d8d      6e6aae00       mov.b @(0xae00:16,r6),r2l
0x00040d91      2004           mov.b @0x4:8,r0h
0x00040d93      6f5a040e       mov.w @(0x40e:16,r5),r2
0x00040d97      0c0d           mov.b r0h,r5l
0x00040d99      e019           and #0x19:8,r0h
0x00040d9b      886a           add.b #0x6a:8,r0l
0x00040d9d      a800           cmp.b #0x0:8,r0l
0x00040d9f      2004           mov.b @0x4:8,r0h
0x00040da1      750f           bxor #0x0:3,r7l
0x00040da3      e0f9           and #0xf9:8,r0h
0x00040da5      0811           add.b r1h,r1h
0x00040da7      301a           mov.b r0h,@0x1a:8
0x00040da9      094f           add.w r4,r7
0x00040dab      045a           orc #0x5a:8,ccr
0x00040dad      040d           orc #0xd:8,ccr
0x00040daf      a66a           cmp.b #0x6a:8,r6h
0x00040db1      a800           cmp.b #0x0:8,r0l
0x00040db3      2004           mov.b @0x4:8,r0h
0x00040db5      766a           band #0x6:3,r2l
0x00040db7      ae00           cmp.b #0x0:8,r6l
0x00040db9      2004           mov.b @0x4:8,r0h
0x00040dbb      775a           bld #0x5:3,r2l
0x00040dbd      040e           orc #0xe:8,ccr
0x00040dbf      0c0d           mov.b r0h,r5l
0x00040dc1      e019           and #0x19:8,r0h
0x00040dc3      886a           add.b #0x6a:8,r0l
0x00040dc5      a800           cmp.b #0x0:8,r0l
0x00040dc7      2004           mov.b @0x4:8,r0h
0x00040dc9      7d             invalid
0x00040dca      0fe0           daa r0h
0x00040dcc      f908           mov.b #0x8:8,r1l
0x00040dce      1130           shar r0h
0x00040dd0      1a09           dec r1l
0x00040dd2      4f04           ble @@0x4:8
0x00040dd4      5a040dce       jmp @0xdce:16
0x00040dd8      6aa80020       mov.b r0l,@0x20:16
0x00040ddc      047e           orc #0x7e:8,ccr
0x00040dde      6aae0020       mov.b r6l,@0x20:16
0x00040de2      047f           orc #0x7f:8,ccr
0x00040de4      5a040e0c       jmp @0xe0c:16
0x00040de8      0de0           mov.w r14,r0
0x00040dea      1988           sub.w r8,r0
0x00040dec      6aa80020       mov.b r0l,@0x20:16
0x00040df0      0485           orc #0x85:8,ccr
0x00040df2      0fe0           daa r0h
0x00040df4      f908           mov.b #0x8:8,r1l
0x00040df6      1130           shar r0h
0x00040df8      1a09           dec r1l
0x00040dfa      4f04           ble @@0x4:8
0x00040dfc      5a040df6       jmp @0xdf6:16
0x00040e00      6aa80020       mov.b r0l,@0x20:16
0x00040e04      0486           orc #0x86:8,ccr
0x00040e06      6aae00         mov.b r6l,@0x10:16
0x00040e0a      0487           orc #0x87:8,ccr
0x00040e0c      1966           sub.w r6,r6
0x00040e0e      5a040f36       jmp @0xf36:16
0x00040e12      5e0109e2       jsr @0x9e2:16
0x00040e16      5e02d5e4       jsr @0xd5e4:16
0x00040e1a      6b200040       mov.w @0x40:16,r0
0x00040e1e      0776           ldc #0x76:8,ccr
0x00040e20      7370           btst #0x7:3,r0h
0x00040e22      4704           beq @@0x4:8
0x00040e24      5a041106       jmp @0x1106:16
0x00040e28      6b200040       mov.w @0x40:16,r0
0x00040e2c      0f30           daa r0h
0x00040e2e      1770           neg r0h
0x00040e30      01006df0       sleep
0x00040e34      0d60           mov.w r6,r0
0x00040e36      1770           neg r0h
0x00040e38      01006df0       sleep
0x00040e3c      01006df5       sleep
0x00040e40      6a280040       mov.b @0x40:16,r0l
0x00040e44      0f33           daa r3h
0x00040e46      6df0           push r0
0x00040e48      6e700073       mov.b @(0x73:16,r7),r0h
0x00040e4c      7a             invalid
0x00040e4d      01000000       sleep
0x00040e51      620a           bclr r0h,r2l
0x00040e53      f168           mov.b #0x68:8,r1h
0x00040e55      385e           mov.b r0l,@0x5e:8
0x00040e57      0362           ldc r2h,ccr
0x00040e59      f47a           mov.b #0x7a:8,r4h
0x00040e5b      1700           not r0h
0x00040e5d      0000           nop
0x00040e5f      0e01           addx r0h,r1h
0x00040e61      006d           nop
0x00040e63      f001           mov.b #0x1:8,r0h
0x00040e65      006d           nop
0x00040e67      f101           mov.b #0x1:8,r1h
0x00040e69      006d           nop
0x00040e6b      f201           mov.b #0x1:8,r2h
0x00040e6d      006d           nop
0x00040e6f      f301           mov.b #0x1:8,r3h
0x00040e71      006d           nop
0x00040e73      f401           mov.b #0x1:8,r4h
0x00040e75      006d           nop
0x00040e77      f501           mov.b #0x1:8,r5h
0x00040e79      006d           nop
0x00040e7b      f67a           mov.b #0x7a:8,r6h
0x00040e7d      0300           ldc r0h,ccr
0x00040e7f      400f           bra @@0xf:8
0x00040e81      5518           bsr .24
0x00040e83      cc58           or #0x58:8,r4l
0x00040e85      0000           nop
0x00040e87      880c           add.b #0xc:8,r0l
0x00040e89      ce17           or #0x17:8,r6l
0x00040e8b      5617           rte
0x00040e8d      761a           band #0x1:3,r2l
0x00040e8f      8078           add.b #0x78:8,r0h
0x00040e91      606a           bset r6h,r2l
0x00040e93      2800           mov.b @0x0:8,r0l
0x00040e95      400f           bra @@0xf:8
0x00040e97      5678           rte
0x00040e99      606a           bset r6h,r2l
0x00040e9b      2d00           mov.b @0x0:8,r5l
0x00040e9d      400f           bra @@0xf:8
0x00040e9f      5610           rte
0x00040ea1      3010           mov.b r0h,@0x10:8
0x00040ea3      3001           mov.b r0h,@0x1:8
0x00040ea5      0078           nop
0x00040ea7      006b           nop
0x00040ea9      2600           mov.b @0x0:8,r6h
0x00040eab      404e           bra @@0x4e:8
0x00040ead      a26b           cmp.b #0x6b:8,r2h
0x00040eaf      2200           mov.b @0x0:8,r2h
0x00040eb1      400f           bra @@0xf:8
0x00040eb3      2e17           mov.b @0x17:8,r6l
0x00040eb5      7210           bclr #0x1:3,r0h
0x00040eb7      320a           mov.b r2h,@0xa:8
0x00040eb9      e2ad           and #0xad:8,r2h
0x00040ebb      0347           ldc r7h,ccr
0x00040ebd      36ad           mov.b r6h,@0xad:8
0x00040ebf      0047           nop
0x00040ec1      0cad           mov.b r2l,r5l
0x00040ec3      0147107a       sleep
0x00040ec7      0500           xorc #0x0:8,ccr
0x00040ec9      4180           brn @@0x80:8
0x00040ecb      0040           nop
0x00040ecd      1e7a           subx r7h,r2l
0x00040ecf      0500           xorc #0x0:8,ccr
0x00040ed1      c080           or #0x80:8,r0h
0x00040ed3      0040           nop
0x00040ed5      167a           and r7h,r2l
0x00040ed7      0500           xorc #0x0:8,ccr
0x00040ed9      8380           add.b #0x80:8,r3h
0x00040edb      0040           nop
0x00040edd      0e6d           addx r6h,r5l
0x00040edf      6017           bset r1h,r7h
0x00040ee1      7010           bset #0x1:3,r0h
0x00040ee3      300a           mov.b r0h,@0xa:8
0x00040ee5      d069           xor #0x69:8,r0h
0x00040ee7      010b5169       sleep
0x00040eeb      811f           add.b #0x1f:8,r1h
0x00040eed      a645           cmp.b #0x45:8,r6h
0x00040eef      ee0a           and #0xa:8,r6l
0x00040ef1      0c40           mov.b r4h,r0h
0x00040ef3      1c17           cmp.b r1h,r7h
0x00040ef5      5517           bsr .23
0x00040ef7      7510           bxor #0x1:3,r0h
0x00040ef9      357a           mov.b r5h,@0x7a:8
0x00040efb      1500           xor r0h,r0h
0x00040efd      406e           bra @@0x6e:8
0x00040eff      226d           mov.b @0x6d:8,r2h
0x00040f01      6169           bnot r6h,r1l
0x00040f03      591d           jmp @r1
0x00040f05      9145           addx #0x45:8,r1h
0x00040f07      0269           stc ccr,r1l
0x00040f09      d1             xor #0x10:8,r1h
0x00040f0b      a645           cmp.b #0x45:8,r6h
0x00040f0d      f20a           mov.b #0xa:8,r2h
0x00040f0f      0c68           mov.b r6h,r0l
0x00040f11      381c           mov.b r0l,@0x1c:8
0x00040f13      8c58           add.b #0x58:8,r4l
0x00040f15      50ff           mulxu r7l,r7
0x00040f17      7001           bset #0x0:3,r1h
0x00040f19      006d           nop
0x00040f1b      7601           band #0x0:3,r1h
0x00040f1d      006d           nop
0x00040f1f      7501           bxor #0x0:3,r1h
0x00040f21      006d           nop
0x00040f23      7401           bor #0x0:3,r1h
0x00040f25      006d           nop
0x00040f27      7301           btst #0x0:3,r1h
0x00040f29      006d           nop
0x00040f2b      7201           bclr #0x0:3,r1h
0x00040f2d      006d           nop
0x00040f2f      7101           bnot #0x0:3,r1h
0x00040f31      006d           nop
0x00040f33      700b           bset #0x0:3,r3l
0x00040f35      566b           rte
0x00040f37      2000           mov.b @0x0:8,r0h
0x00040f39      400f           bra @@0xf:8
0x00040f3b      301d           mov.b r0h,@0x1d:8
0x00040f3d      0644           andc #0x44:8,ccr
0x00040f3f      045a           orc #0x5a:8,ccr
0x00040f41      040e           orc #0xe:8,ccr
0x00040f43      126b           rotl r3l
0x00040f45      2000           mov.b @0x0:8,r0h
0x00040f47      4007           bra @@0x7:8
0x00040f49      7673           band #0x7:3,r3h
0x00040f4b      7047           bset #0x4:3,r7h
0x00040f4d      045a           orc #0x5a:8,ccr
0x00040f4f      0411           orc #0x11:8,ccr
0x00040f51      0618           andc #0x18:8,ccr
0x00040f53      555a           bsr .90
0x00040f55      0410           orc #0x10:8,ccr
0x00040f57      fc0c           mov.b #0xc:8,r4l
0x00040f59      58             invalid
0x00040f5a      1750           neg r0h
0x00040f5c      1770           neg r0h
0x00040f5e      78             invalid
0x00040f5f      006a           nop
0x00040f61      2d00           mov.b @0x0:8,r5l
0x00040f63      400f           bra @@0xf:8
0x00040f65      56ad           rte
0x00040f67      0346           ldc r6h,ccr
0x00040f69      045a           orc #0x5a:8,ccr
0x00040f6b      0410           orc #0x10:8,ccr
0x00040f6d      e00c           and #0xc:8,r0h
0x00040f6f      d817           xor #0x17:8,r0l
0x00040f71      5017           mulxu r1h,r7
0x00040f73      7010           bset #0x1:3,r0h
0x00040f75      3010           mov.b r0h,@0x10:8
0x00040f77      307a           mov.b r0h,@0x7a:8
0x00040f79      01000000       sleep
0x00040f7d      440a           bcc @@0xa:8
0x00040f7f      f10a           mov.b #0xa:8,r1h
0x00040f81      8101           add.b #0x1:8,r1h
0x00040f83      0069           nop
0x00040f85      1001           shll r1h
0x00040f87      006f           nop
0x00040f89      f000           mov.b #0x0:8,r0h
0x00040f8b      6a6b2000       mov.b @0x2000:16,r3l
0x00040f8f      400f           bra @@0xf:8
0x00040f91      2e17           mov.b @0x17:8,r6l
0x00040f93      706b           bset #0x6:3,r3l
0x00040f95      2100           mov.b @0x0:8,r1h
0x00040f97      400f           bra @@0xf:8
0x00040f99      3017           mov.b r0h,@0x17:8
0x00040f9b      715e           bnot #0x5:3,r6l
0x00040f9d      0163ea6b       sleep
0x00040fa1      2100           mov.b @0x0:8,r1h
0x00040fa3      400d           bra @@0xd:8
0x00040fa5      0617           andc #0x17:8,ccr
0x00040fa7      715e           bnot #0x5:3,r6l
0x00040fa9      0163ea7a       sleep
0x00040fad      01000027       sleep
0x00040fb1      105e           shal r6l
0x00040fb3      015cf20d       sleep
0x00040fb7      0e19           addx r1h,r1l
0x00040fb9      66             invalid
0x00040fba      1ac4           dec r4h
0x00040fbc      0cd8           mov.b r5l,r0l
0x00040fbe      1750           neg r0h
0x00040fc0      1770           neg r0h
0x00040fc2      1030           shal r0h
0x00040fc4      7a             invalid
0x00040fc5      1000           shll r0h
0x00040fc7      406e           bra @@0x6e:8
0x00040fc9      2a01           mov.b @0x1:8,r2l
0x00040fcb      006f           nop
0x00040fcd      f000           mov.b #0x0:8,r0h
0x00040fcf      66             invalid
0x00040fd0      5a04101e       jmp @0x101e:16
0x00040fd4      0fc0           daa r0h
0x00040fd6      1030           shal r0h
0x00040fd8      01006f71       sleep
0x00040fdc      006a           nop
0x00040fde      0a81           inc r1h
0x00040fe0      6911           mov.w @r1,r1
0x00040fe2      1de1           cmp.w r14,r1
0x00040fe4      4304           bls @@0x4:8
0x00040fe6      5a04102a       jmp @0x102a:16
0x00040fea      0fc0           daa r0h
0x00040fec      1030           shal r0h
0x00040fee      01006f71       sleep
0x00040ff2      006a           nop
0x00040ff4      0a81           inc r1h
0x00040ff6      6911           mov.w @r1,r1
0x00040ff8      191e           sub.w r1,r6
0x00040ffa      01006f70       sleep
0x00040ffe      0066           nop
0x00041000      6984           mov.w r4,@r0
0x00041002      0b56           adds #1,r6
0x00041004      79260fff       mov.w #0xfff:16,r6
0x00041008      4704           beq @@0x4:8
0x0004100a      5a             jmp @0x100:16
0x0004100e      79005a00       mov.w #0x5a00:16,r0
0x00041012      6b80ffa8       mov.w r0,@0xffa8:16
0x00041016      5e0109e2       jsr @0x9e2:16
0x0004101a      1966           sub.w r6,r6
0x0004101c      0b74           adds #1,r4
0x0004101e      7a             invalid
0x0004101f      2400           mov.b @0x0:8,r4h
0x00041021      0040           nop
0x00041023      0044           nop
0x00041025      045a           orc #0x5a:8,ccr
0x00041027      040f           orc #0xf:8,ccr
0x00041029      d479           xor #0x79:8,r4h
0x0004102b      005a           nop
0x0004102d      006b           nop
0x0004102f      80ff           add.b #0xff:8,r0h
0x00041031      a85e           cmp.b #0x5e:8,r0l
0x00041033      0109e219       sleep
0x00041037      66             invalid
0x00041038      1ac4           dec r4h
0x0004103a      0cd8           mov.b r5l,r0l
0x0004103c      1750           neg r0h
0x0004103e      1770           neg r0h
0x00041040      1030           shal r0h
0x00041042      7a             invalid
0x00041043      1000           shll r0h
0x00041045      406e           bra @@0x6e:8
0x00041047      2201           mov.b @0x1:8,r2h
0x00041049      006f           nop
0x0004104b      f000           mov.b #0x0:8,r0h
0x0004104d      66             invalid
0x0004104e      5a04109a       jmp @0x109a:16
0x00041052      7a             invalid
0x00041053      0000           nop
0x00041055      003f           nop
0x00041057      ff1a           mov.b #0x1a:8,r7l
0x00041059      c010           or #0x10:8,r0h
0x0004105b      3001           mov.b r0h,@0x1:8
0x0004105d      006f           nop
0x0004105f      7100           bnot #0x0:3,r0h
0x00041061      6a0a8169       mov.b @0x8169:16,r2l
0x00041065      1046           shal r6h
0x00041067      045a           orc #0x5a:8,ccr
0x00041069      0410           orc #0x10:8,ccr
0x0004106b      7e79003f       biand #0x3:3,@0x79:8
0x0004106f      ff19           mov.b #0x19:8,r7l
0x00041071      4001           bra @@0x1:8
0x00041073      006f           nop
0x00041075      7100           bnot #0x0:3,r0h
0x00041077      66             invalid
0x00041078      6990           mov.w r0,@r1
0x0004107a      5a0410a6       jmp @0x10a6:16
0x0004107e      0b56           adds #1,r6
0x00041080      79260fff       mov.w #0xfff:16,r6
0x00041084      4704           beq @@0x4:8
0x00041086      5a041098       jmp @0x1098:16
0x0004108a      79005a00       mov.w #0x5a00:16,r0
0x0004108e      6b80ffa8       mov.w r0,@0xffa8:16
0x00041092      5e0109e2       jsr @0x9e2:16
0x00041096      1966           sub.w r6,r6
0x00041098      0b74           adds #1,r4
0x0004109a      7a             invalid
0x0004109b      2400           mov.b @0x0:8,r4h
0x0004109d      0040           nop
0x0004109f      0044           nop
0x000410a1      045a           orc #0x5a:8,ccr
0x000410a3      0410           orc #0x10:8,ccr
0x000410a5      52             invalid
0x000410a6      0cd8           mov.b r5l,r0l
0x000410a8      1750           neg r0h
0x000410aa      1770           neg r0h
0x000410ac      1030           shal r0h
0x000410ae      6b210040       mov.w @0x40:16,r1
0x000410b2      6e327800       mov.b @(0x7800:16,r3),r2h
0x000410b6      6b200040       mov.w @0x40:16,r0
0x000410ba      6e221d01       mov.b @(0x1d01:16,r2),r2h
0x000410be      4504           bcs @@0x4:8
0x000410c0      5a0410e0       jmp @0x10e0:16
0x000410c4      0cd8           mov.b r5l,r0l
0x000410c6      1750           neg r0h
0x000410c8      1770           neg r0h
0x000410ca      1030           shal r0h
0x000410cc      78             invalid
0x000410cd      006b           nop
0x000410cf      2000           mov.b @0x0:8,r0h
0x000410d1      406e           bra @@0x6e:8
0x000410d3      226b           mov.b @0x6b:8,r2h
0x000410d5      a000           cmp.b #0x0:8,r0h
0x000410d7      406e           bra @@0x6e:8
0x000410d9      326a           mov.b r2h,@0x6a:8
0x000410db      ad00           cmp.b #0x0:8,r5l
0x000410dd      406e           bra @@0x6e:8
0x000410df      341a           mov.b r4h,@0x1a:8
0x000410e1      e60c           and #0xc:8,r6h
0x000410e3      de10           xor #0x10:8,r6l
0x000410e5      3678           mov.b r6h,@0x78:8
0x000410e7      606b           bset r6h,r3l
0x000410e9      2000           mov.b @0x0:8,r0h
0x000410eb      406e           bra @@0x6e:8
0x000410ed      2278           mov.b @0x78:8,r2h
0x000410ef      606b           bset r6h,r3l
0x000410f1      a000           cmp.b #0x0:8,r0h
0x000410f3      406e           bra @@0x6e:8
0x000410f5      1a5e           dec r6l
0x000410f7      0109e20a       sleep
0x000410fb      0568           xorc #0x68:8,ccr
0x000410fd      381c           mov.b r0l,@0x1c:8
0x000410ff      8544           add.b #0x44:8,r5h
0x00041101      045a           orc #0x5a:8,ccr
0x00041103      040f           orc #0xf:8,ccr
0x00041105      58             invalid
0x00041106      6a280040       mov.b @0x40:16,r0l
0x0004110a      0773           ldc #0x73:8,ccr
0x0004110c      a802           cmp.b #0x2:8,r0l
0x0004110e      4604           bne @@0x4:8
0x00041110      5a04112c       jmp @0x112c:16
0x00041114      a801           cmp.b #0x1:8,r0l
0x00041116      4604           bne @@0x4:8
0x00041118      5a04112c       jmp @0x112c:16
0x0004111c      a804           cmp.b #0x4:8,r0l
0x0004111e      4604           bne @@0x4:8
0x00041120      5a04112c       jmp @0x112c:16
0x00041124      a805           cmp.b #0x5:8,r0l
0x00041126      4704           beq @@0x4:8
0x00041128      5a041138       jmp @0x1138:16
0x0004112c      6a280040       mov.b @0x40:16,r0l
0x00041130      53             invalid
0x00041131      0377           ldc r7h,ccr
0x00041133      087f           add.b r7h,r7l
0x00041135      d267           xor #0x67:8,r2h
0x00041137      106a           shal r2l
0x00041139      2800           mov.b @0x0:8,r0l
0x0004113b      400f           bra @@0xf:8
0x0004113d      5646           rte
0x0004113f      045a           orc #0x5a:8,ccr
0x00041141      0411           orc #0x11:8,ccr
0x00041143      60a8           bset r2l,r0l
0x00041145      0146045a       sleep
0x00041149      0411           orc #0x11:8,ccr
0x0004114b      7ca80246       biand #0x4:3,@r10
0x0004114f      045a           orc #0x5a:8,ccr
0x00041151      0411           orc #0x11:8,ccr
0x00041153      98a8           addx #0xa8:8,r0l
0x00041155      0346           ldc r6h,ccr
0x00041157      045a           orc #0x5a:8,ccr
0x00041159      0411           orc #0x11:8,ccr
0x0004115b      b45a           subx #0x5a:8,r4h
0x0004115d      0411           orc #0x11:8,ccr
0x0004115f      cc18           or #0x18:8,r4l
0x00041161      886a           add.b #0x6a:8,r0l
0x00041163      a800           cmp.b #0x0:8,r0l
0x00041165      2004           mov.b @0x4:8,r0h
0x00041167      6df8           push r0
0x00041169      016aa800       sleep
0x0004116d      2004           mov.b @0x4:8,r0h
0x0004116f      6ef82b6a       mov.b r0l,@(0x2b6a:16,r7)
0x00041173      a800           cmp.b #0x0:8,r0l
0x00041175      2004           mov.b @0x4:8,r0h
0x00041177      6f5a0411       mov.w @(0x411:16,r5),r2
0x0004117b      cc18           or #0x18:8,r4l
0x0004117d      886a           add.b #0x6a:8,r0l
0x0004117f      a800           cmp.b #0x0:8,r0l
0x00041181      2004           mov.b @0x4:8,r0h
0x00041183      75f8           bixor #0x7:3,r0l
0x00041185      016aa800       sleep
0x00041189      2004           mov.b @0x4:8,r0h
0x0004118b      76f8           biand #0x7:3,r0l
0x0004118d      2b6a           mov.b @0x6a:8,r3l
0x0004118f      a800           cmp.b #0x0:8,r0l
0x00041191      2004           mov.b @0x4:8,r0h
0x00041193      775a           bld #0x5:3,r2l
0x00041195      0411           orc #0x11:8,ccr
0x00041197      cc18           or #0x18:8,r4l
0x00041199      886a           add.b #0x6a:8,r0l
0x0004119b      a800           cmp.b #0x0:8,r0l
0x0004119d      2004           mov.b @0x4:8,r0h
0x0004119f      7d             invalid
0x000411a0      f801           mov.b #0x1:8,r0l
0x000411a2      6aa80020       mov.b r0l,@0x20:16
0x000411a6      047e           orc #0x7e:8,ccr
0x000411a8      f82b           mov.b #0x2b:8,r0l
0x000411aa      6aa80020       mov.b r0l,@0x20:16
0x000411ae      047f           orc #0x7f:8,ccr
0x000411b0      5a0411cc       jmp @0x11cc:16
0x000411b4      1888           sub.b r0l,r0l
0x000411b6      6aa80020       mov.b r0l,@0x20:16
0x000411ba      0485           orc #0x85:8,ccr
0x000411bc      f801           mov.b #0x1:8,r0l
0x000411be      6aa80020       mov.b r0l,@0x20:16
0x000411c2      0486           orc #0x86:8,ccr
0x000411c4      f82b           mov.b #0x2b:8,r0l
0x000411c6      6aa80020       mov.b r0l,@0x20:16
0x000411ca      0487           orc #0x87:8,ccr
0x000411cc      1888           sub.b r0l,r0l
0x000411ce      6aa80020       mov.b r0l,@0x20:16
0x000411d2      01c1f880       sleep
0x000411d6      6aa80020       mov.b r0l,@0x20:16
0x000411da      0001           nop
0x000411dc      7a             invalid
0x000411dd      1700           not r0h
0x000411df      0000           nop
0x000411e1      6e5e0164       mov.b @(0x164:16,r5),r6l
0x000411e5      3654           mov.b r6h,@0x54:8
0x000411e7      705e           bset #0x5:3,r6l
0x000411e9      0164587a       sleep
0x000411ed      3700           mov.b r7h,@0x0:8
0x000411ef      0000           nop
0x000411f1      447a           bcc @@0x7a:8
0x000411f3      0300           ldc r0h,ccr
0x000411f5      4010           bra @@0x10:8
0x000411f7      78             invalid
0x000411f8      7a             invalid
0x000411f9      0400           orc #0x0:8,ccr
0x000411fb      400f           bra @@0xf:8
0x000411fd      9e7a           addx #0x7a:8,r6l
0x000411ff      0600           andc #0x0:8,ccr
0x00041201      400b           bra @@0xb:8
0x00041203      2418           mov.b @0x18:8,r4h
0x00041205      550f           bsr .15
0x00041207      c00b           or #0xb:8,r0h
0x00041209      9001           addx #0x1:8,r0h
0x0004120b      006f           nop
0x0004120d      f0             mov.b #0x10:8,r0h
0x0004120f      300f           mov.b r0h,@0xf:8
0x00041211      b00b           subx #0xb:8,r0h
0x00041213      9001           addx #0x1:8,r0h
0x00041215      006f           nop
0x00041217      f000           mov.b #0x0:8,r0h
0x00041219      3c0f           mov.b r4l,@0xf:8
0x0004121b      c00b           or #0xb:8,r0h
0x0004121d      900b           addx #0xb:8,r0h
0x0004121f      9001           addx #0x1:8,r0h
0x00041221      006f           nop
0x00041223      f000           mov.b #0x0:8,r0h
0x00041225      280f           mov.b @0xf:8,r0l
0x00041227      b00b           subx #0xb:8,r0h
0x00041229      900b           addx #0xb:8,r0h
0x0004122b      9001           addx #0x1:8,r0h
0x0004122d      006f           nop
0x0004122f      f000           mov.b #0x0:8,r0h
0x00041231      2c0f           mov.b @0xf:8,r4l
0x00041233      c07a           or #0x7a:8,r0h
0x00041235      1000           shll r0h
0x00041237      0000           nop
0x00041239      0c01           mov.b r0h,r1h
0x0004123b      006f           nop
0x0004123d      f000           mov.b #0x0:8,r0h
0x0004123f      380f           mov.b r0l,@0xf:8
0x00041241      b07a           subx #0x7a:8,r0h
0x00041243      1000           shll r0h
0x00041245      0000           nop
0x00041247      0c01           mov.b r0h,r1h
0x00041249      006f           nop
0x0004124b      f000           mov.b #0x0:8,r0h
0x0004124d      345a           mov.b r4h,@0x5a:8
0x0004124f      0414           orc #0x14:8,ccr
0x00041251      ca0c           or #0xc:8,r2l
0x00041253      58             invalid
0x00041254      1750           neg r0h
0x00041256      1770           neg r0h
0x00041258      78             invalid
0x00041259      006a           nop
0x0004125b      2d00           mov.b @0x0:8,r5l
0x0004125d      400f           bra @@0xf:8
0x0004125f      566a           rte
0x00041261      2800           mov.b @0x0:8,r0l
0x00041263      400f           bra @@0xf:8
0x00041265      5ba8           jmp @@0xa8:8
0x00041267      0147045a       sleep
0x0004126b      0413           orc #0x13:8,ccr
0x0004126d      24ad           mov.b @0xad:8,r4h
0x0004126f      0346           ldc r6h,ccr
0x00041271      045a           orc #0x5a:8,ccr
0x00041273      0412           orc #0x12:8,ccr
0x00041275      ac1a           cmp.b #0x1a:8,r4l
0x00041277      800c           add.b #0xc:8,r0h
0x00041279      d810           xor #0x10:8,r0l
0x0004127b      3010           mov.b r0h,@0x10:8
0x0004127d      3001           mov.b r0h,@0x1:8
0x0004127f      006f           nop
0x00041281      f000           mov.b #0x0:8,r0h
0x00041283      400a           bra @@0xa:8
0x00041285      c001           or #0x1:8,r0h
0x00041287      006f           nop
0x00041289      7100           bnot #0x0:3,r0h
0x0004128b      400a           bra @@0xa:8
0x0004128d      b101           subx #0x1:8,r1h
0x0004128f      0069           nop
0x00041291      1101           shlr r1h
0x00041293      006f           nop
0x00041295      f000           mov.b #0x0:8,r0h
0x00041297      1c7a           cmp.b r7h,r2l
0x00041299      0000           nop
0x0004129b      0000           nop
0x0004129d      200a           mov.b @0xa:8,r0h
0x0004129f      f05e           mov.b #0x5e:8,r0h
0x000412a1      0164806f       sleep
0x000412a5      6101           bnot r0h,r1h
0x000412a7      d45a           xor #0x5a:8,r4h
0x000412a9      0412           orc #0x12:8,ccr
0x000412ab      de1a           xor #0x1a:8,r6l
0x000412ad      800c           add.b #0xc:8,r0h
0x000412af      d810           xor #0x10:8,r0l
0x000412b1      3010           mov.b r0h,@0x10:8
0x000412b3      3001           mov.b r0h,@0x1:8
0x000412b5      006f           nop
0x000412b7      f000           mov.b #0x0:8,r0h
0x000412b9      400a           bra @@0xa:8
0x000412bb      c001           or #0x1:8,r0h
0x000412bd      006f           nop
0x000412bf      7100           bnot #0x0:3,r0h
0x000412c1      400a           bra @@0xa:8
0x000412c3      b101           subx #0x1:8,r1h
0x000412c5      0069           nop
0x000412c7      1101           shlr r1h
0x000412c9      006f           nop
0x000412cb      f000           mov.b #0x0:8,r0h
0x000412cd      1c7a           cmp.b r7h,r2l
0x000412cf      0000           nop
0x000412d1      0000           nop
0x000412d3      200a           mov.b @0xa:8,r0h
0x000412d5      f05e           mov.b #0x5e:8,r0h
0x000412d7      0164806f       sleep
0x000412db      6101           bnot r0h,r1h
0x000412dd      d601           xor #0x1:8,r6h
0x000412df      006f           nop
0x000412e1      f000           mov.b #0x0:8,r0h
0x000412e3      107a           shal r2l
0x000412e5      0000           nop
0x000412e7      0000           nop
0x000412e9      140a           or r0h,r2l
0x000412eb      f05e           mov.b #0x5e:8,r0h
0x000412ed      0164fe7a       sleep
0x000412f1      010004a4       sleep
0x000412f5      f00f           mov.b #0xf:8,r0h
0x000412f7      827a           add.b #0x7a:8,r2h
0x000412f9      0000           nop
0x000412fb      0000           nop
0x000412fd      080a           add.b r0h,r2l
0x000412ff      f05e           mov.b #0x5e:8,r0h
0x00041301      0159a401       sleep
0x00041305      006f           nop
0x00041307      7100           bnot #0x0:3,r0h
0x00041309      100f           shll r7l
0x0004130b      820f           add.b #0xf:8,r2h
0x0004130d      f05e           mov.b #0x5e:8,r0h
0x0004130f      0160305e       sleep
0x00041313      015d2e01       sleep
0x00041317      006f           nop
0x00041319      7100           bnot #0x0:3,r0h
0x0004131b      1c01           cmp.b r0h,r1h
0x0004131d      0069           nop
0x0004131f      905a           addx #0x5a:8,r0h
0x00041321      0414           orc #0x14:8,ccr
0x00041323      c80c           or #0xc:8,r0l
0x00041325      d846           xor #0x46:8,r0l
0x00041327      045a           orc #0x5a:8,ccr
0x00041329      0413           orc #0x13:8,ccr
0x0004132b      48a8           bvc @@0xa8:8
0x0004132d      0146045a       sleep
0x00041331      0413           orc #0x13:8,ccr
0x00041333      a2a8           cmp.b #0xa8:8,r2h
0x00041335      0246           stc ccr,r6h
0x00041337      045a           orc #0x5a:8,ccr
0x00041339      0414           orc #0x14:8,ccr
0x0004133b      04a8           orc #0xa8:8,ccr
0x0004133d      0346           ldc r6h,ccr
0x0004133f      045a           orc #0x5a:8,ccr
0x00041341      0414           orc #0x14:8,ccr
0x00041343      66             invalid
0x00041344      5a0414c8       jmp @0x14c8:16
0x00041348      01006931       sleep
0x0004134c      7a             invalid
0x0004134d      0000           nop
0x0004134f      0000           nop
0x00041351      200a           mov.b @0xa:8,r0h
0x00041353      f05e           mov.b #0x5e:8,r0h
0x00041355      0164806f       sleep
0x00041359      6101           bnot r0h,r1h
0x0004135b      cc01           or #0x1:8,r4l
0x0004135d      006f           nop
0x0004135f      f000           mov.b #0x0:8,r0h
0x00041361      147a           or r7h,r2l
0x00041363      0000           nop
0x00041365      0000           nop
0x00041367      180a           sub.b r0h,r2l
0x00041369      f05e           mov.b #0x5e:8,r0h
0x0004136b      0164fe7a       sleep
0x0004136f      010004a4       sleep
0x00041373      f00f           mov.b #0xf:8,r0h
0x00041375      827a           add.b #0x7a:8,r2h
0x00041377      0000           nop
0x00041379      0000           nop
0x0004137b      0c0a           mov.b r0h,r2l
0x0004137d      f05e           mov.b #0x5e:8,r0h
0x0004137f      0159a401       sleep
0x00041383      006f           nop
0x00041385      7100           bnot #0x0:3,r0h
0x00041387      140f           or r0h,r7l
0x00041389      827a           add.b #0x7a:8,r2h
0x0004138b      0000           nop
0x0004138d      0000           nop
0x0004138f      040a           orc #0xa:8,ccr
0x00041391      f05e           mov.b #0x5e:8,r0h
0x00041393      0160305e       sleep
0x00041397      015d2e01       sleep
0x0004139b      0069           nop
0x0004139d      c05a           or #0x5a:8,r0h
0x0004139f      0414           orc #0x14:8,ccr
0x000413a1      c801           or #0x1:8,r0l
0x000413a3      006f           nop
0x000413a5      7100           bnot #0x0:3,r0h
0x000413a7      3c01           mov.b r4l,@0x1:8
0x000413a9      0069           nop
0x000413ab      117a           shar r2l
0x000413ad      0000           nop
0x000413af      0000           nop
0x000413b1      200a           mov.b @0xa:8,r0h
0x000413b3      f05e           mov.b #0x5e:8,r0h
0x000413b5      0164806f       sleep
0x000413b9      6101           bnot r0h,r1h
0x000413bb      ce01           or #0x1:8,r6l
0x000413bd      006f           nop
0x000413bf      f000           mov.b #0x0:8,r0h
0x000413c1      147a           or r7h,r2l
0x000413c3      0000           nop
0x000413c5      0000           nop
0x000413c7      180a           sub.b r0h,r2l
0x000413c9      f05e           mov.b #0x5e:8,r0h
0x000413cb      0164fe7a       sleep
0x000413cf      010004a4       sleep
0x000413d3      f00f           mov.b #0xf:8,r0h
0x000413d5      827a           add.b #0x7a:8,r2h
0x000413d7      0000           nop
0x000413d9      0000           nop
0x000413db      0c0a           mov.b r0h,r2l
0x000413dd      f05e           mov.b #0x5e:8,r0h
0x000413df      0159a401       sleep
0x000413e3      006f           nop
0x000413e5      7100           bnot #0x0:3,r0h
0x000413e7      140f           or r0h,r7l
0x000413e9      827a           add.b #0x7a:8,r2h
0x000413eb      0000           nop
0x000413ed      0000           nop
0x000413ef      040a           orc #0xa:8,ccr
0x000413f1      f05e           mov.b #0x5e:8,r0h
0x000413f3      0160305e       sleep
0x000413f7      015d2e01       sleep
0x000413fb      006f           nop
0x000413fd      7100           bnot #0x0:3,r0h
0x000413ff      305a           mov.b r0h,@0x5a:8
0x00041401      0414           orc #0x14:8,ccr
0x00041403      c401           or #0x1:8,r4h
0x00041405      006f           nop
0x00041407      7100           bnot #0x0:3,r0h
0x00041409      2c01           mov.b @0x1:8,r4l
0x0004140b      0069           nop
0x0004140d      117a           shar r2l
0x0004140f      0000           nop
0x00041411      0000           nop
0x00041413      200a           mov.b @0xa:8,r0h
0x00041415      f05e           mov.b #0x5e:8,r0h
0x00041417      0164806f       sleep
0x0004141b      6101           bnot r0h,r1h
0x0004141d      d001           xor #0x1:8,r0h
0x0004141f      006f           nop
0x00041421      f000           mov.b #0x0:8,r0h
0x00041423      147a           or r7h,r2l
0x00041425      0000           nop
0x00041427      0000           nop
0x00041429      180a           sub.b r0h,r2l
0x0004142b      f05e           mov.b #0x5e:8,r0h
0x0004142d      0164fe7a       sleep
0x00041431      010004a4       sleep
0x00041435      f00f           mov.b #0xf:8,r0h
0x00041437      827a           add.b #0x7a:8,r2h
0x00041439      0000           nop
0x0004143b      0000           nop
0x0004143d      0c0a           mov.b r0h,r2l
0x0004143f      f05e           mov.b #0x5e:8,r0h
0x00041441      0159a401       sleep
0x00041445      006f           nop
0x00041447      7100           bnot #0x0:3,r0h
0x00041449      140f           or r0h,r7l
0x0004144b      827a           add.b #0x7a:8,r2h
0x0004144d      0000           nop
0x0004144f      0000           nop
0x00041451      040a           orc #0xa:8,ccr
0x00041453      f05e           mov.b #0x5e:8,r0h
0x00041455      0160305e       sleep
0x00041459      015d2e01       sleep
0x0004145d      006f           nop
0x0004145f      7100           bnot #0x0:3,r0h
0x00041461      285a           mov.b @0x5a:8,r0l
0x00041463      0414           orc #0x14:8,ccr
0x00041465      c401           or #0x1:8,r4h
0x00041467      006f           nop
0x00041469      7100           bnot #0x0:3,r0h
0x0004146b      3401           mov.b r4h,@0x1:8
0x0004146d      0069           nop
0x0004146f      117a           shar r2l
0x00041471      0000           nop
0x00041473      0000           nop
0x00041475      200a           mov.b @0xa:8,r0h
0x00041477      f05e           mov.b #0x5e:8,r0h
0x00041479      0164806f       sleep
0x0004147d      6101           bnot r0h,r1h
0x0004147f      d201           xor #0x1:8,r2h
0x00041481      006f           nop
0x00041483      f000           mov.b #0x0:8,r0h
0x00041485      147a           or r7h,r2l
0x00041487      0000           nop
0x00041489      0000           nop
0x0004148b      180a           sub.b r0h,r2l
0x0004148d      f05e           mov.b #0x5e:8,r0h
0x0004148f      0164fe7a       sleep
0x00041493      010004a4       sleep
0x00041497      f00f           mov.b #0xf:8,r0h
0x00041499      827a           add.b #0x7a:8,r2h
0x0004149b      0000           nop
0x0004149d      0000           nop
0x0004149f      0c0a           mov.b r0h,r2l
0x000414a1      f05e           mov.b #0x5e:8,r0h
0x000414a3      0159a401       sleep
0x000414a7      006f           nop
0x000414a9      7100           bnot #0x0:3,r0h
0x000414ab      140f           or r0h,r7l
0x000414ad      827a           add.b #0x7a:8,r2h
0x000414af      0000           nop
0x000414b1      0000           nop
0x000414b3      040a           orc #0xa:8,ccr
0x000414b5      f05e           mov.b #0x5e:8,r0h
0x000414b7      0160305e       sleep
0x000414bb      015d2e01       sleep
0x000414bf      006f           nop
0x000414c1      7100           bnot #0x0:3,r0h
0x000414c3      3801           mov.b r0l,@0x1:8
0x000414c5      0069           nop
0x000414c7      900a           addx #0xa:8,r0h
0x000414c9      056a           xorc #0x6a:8,ccr
0x000414cb      2800           mov.b @0x0:8,r0l
0x000414cd      400f           bra @@0xf:8
0x000414cf      551c           bsr .28
0x000414d1      8544           add.b #0x44:8,r5h
0x000414d3      045a           orc #0x5a:8,ccr
0x000414d5      0412           orc #0x12:8,ccr
0x000414d7      52             invalid
0x000414d8      7a             invalid
0x000414d9      1700           not r0h
0x000414db      0000           nop
0x000414dd      445e           bcc @@0x5e:8
0x000414df      01643654       sleep
0x000414e3      705e           bset #0x5:3,r6l
0x000414e5      0164587a       sleep
0x000414e9      3700           mov.b r7h,@0x0:8
0x000414eb      0000           nop
0x000414ed      427a           bhi @@0x7a:8
0x000414ef      0300           ldc r0h,ccr
0x000414f1      406e           bra @@0x6e:8
0x000414f3      227a           mov.b @0x7a:8,r2h
0x000414f5      0400           orc #0x0:8,ccr
0x000414f7      400f           bra @@0xf:8
0x000414f9      557a           bsr .122
0x000414fb      0500           xorc #0x0:8,ccr
0x000414fd      400f           bra @@0xf:8
0x000414ff      9ef6           addx #0xf6:8,r6l
0x00041501      0168486a       sleep
0x00041505      a800           cmp.b #0x0:8,r0l
0x00041507      406e           bra @@0x6e:8
0x00041509      3518           mov.b r5h,@0x18:8
0x0004150b      8868           add.b #0x68:8,r0l
0x0004150d      c86a           or #0x6a:8,r0l
0x0004150f      a800           cmp.b #0x0:8,r0l
0x00041511      4010           bra @@0x10:8
0x00041513      766a           band #0x6:3,r2l
0x00041515      2800           mov.b @0x0:8,r0l
0x00041517      400f           bra @@0xf:8
0x00041519      22a8           mov.b @0xa8:8,r2h
0x0004151b      4046           bra @@0x46:8
0x0004151d      045a           orc #0x5a:8,ccr
0x0004151f      0415           orc #0x15:8,ccr
0x00041521      54a8           rts
0x00041523      0447           orc #0x47:8,ccr
0x00041525      045a           orc #0x5a:8,ccr
0x00041527      0415           orc #0x15:8,ccr
0x00041529      386a           mov.b r0l,@0x6a:8
0x0004152b      2900           mov.b @0x0:8,r1l
0x0004152d      400f           bra @@0xf:8
0x0004152f      5ba9           jmp @@0xa9:8
0x00041531      0146045a       sleep
0x00041535      0415           orc #0x15:8,ccr
0x00041537      546a           rts
0x00041539      2800           mov.b @0x0:8,r0l
0x0004153b      400f           bra @@0xf:8
0x0004153d      22a8           mov.b @0xa8:8,r2h
0x0004153f      0847           add.b r4h,r7h
0x00041541      045a           orc #0x5a:8,ccr
0x00041543      0419           orc #0x19:8,ccr
0x00041545      446a           bcc @@0x6a:8
0x00041547      2900           mov.b @0x0:8,r1l
0x00041549      400f           bra @@0xf:8
0x0004154b      5ba9           jmp @@0xa9:8
0x0004154d      0147045a       sleep
0x00041551      0419           orc #0x19:8,ccr
0x00041553      446b           bcc @@0x6b:8
0x00041555      2000           mov.b @0x0:8,r0h
0x00041557      406e           bra @@0x6e:8
0x00041559      3279           mov.b r2h,@0x79:8
0x0004155b      201f           mov.b @0x1f:8,r0h
0x0004155d      ff43           mov.b #0x43:8,r7l
0x0004155f      045a           orc #0x5a:8,ccr
0x00041561      0418           orc #0x18:8,ccr
0x00041563      0e6b           addx r6h,r3l
0x00041565      2100           mov.b @0x0:8,r1h
0x00041567      406e           bra @@0x6e:8
0x00041569      320b           mov.b r2h,@0xb:8
0x0004156b      517a           divxu r7h,r2
0x0004156d      0000           nop
0x0004156f      0000           nop
0x00041571      200a           mov.b @0xa:8,r0h
0x00041573      f05e           mov.b #0x5e:8,r0h
0x00041575      0164fe7a       sleep
0x00041579      010004a4       sleep
0x0004157d      f80f           mov.b #0xf:8,r0l
0x0004157f      827a           add.b #0x7a:8,r2h
0x00041581      0000           nop
0x00041583      0000           nop
0x00041585      280a           mov.b @0xa:8,r0l
0x00041587      f05e           mov.b #0x5e:8,r0h
0x00041589      0159a468       sleep
0x0004158d      480a           bvc @@0xa:8
0x0004158f      0868           add.b r6h,r0l
0x00041591      c81a           or #0x1a:8,r0l
0x00041593      0817           add.b r1h,r7h
0x00041595      5017           mulxu r1h,r7
0x00041597      706a           bset #0x6:3,r2l
0x00041599      2900           mov.b @0x0:8,r1l
0x0004159b      406e           bra @@0x6e:8
0x0004159d      3478           mov.b r4h,@0x78:8
0x0004159f      006a           nop
0x000415a1      a900           cmp.b #0x0:8,r1l
0x000415a3      400f           bra @@0xf:8
0x000415a5      5618           rte
0x000415a7      66             invalid
0x000415a8      5a04172a       jmp @0x172a:16
0x000415ac      0c68           mov.b r6h,r0l
0x000415ae      1750           neg r0h
0x000415b0      1770           neg r0h
0x000415b2      78             invalid
0x000415b3      006a           nop
0x000415b5      2e00           mov.b @0x0:8,r6l
0x000415b7      406e           bra @@0x6e:8
0x000415b9      36ae           mov.b r6h,@0xae:8
0x000415bb      0346           ldc r6h,ccr
0x000415bd      045a           orc #0x5a:8,ccr
0x000415bf      0417           orc #0x17:8,ccr
0x000415c1      280c           mov.b @0xc:8,r0l
0x000415c3      e917           and #0x17:8,r1l
0x000415c5      5117           divxu r1h,r7
0x000415c7      7110           bnot #0x1:3,r0h
0x000415c9      3110           mov.b r1h,@0x10:8
0x000415cb      3101           mov.b r1h,@0x1:8
0x000415cd      006f           nop
0x000415cf      f100           mov.b #0x0:8,r1h
0x000415d1      380a           mov.b r0l,@0xa:8
0x000415d3      d101           xor #0x1:8,r1h
0x000415d5      0069           nop
0x000415d7      117a           shar r2l
0x000415d9      0000           nop
0x000415db      0000           nop
0x000415dd      200a           mov.b @0xa:8,r0h
0x000415df      f05e           mov.b #0x5e:8,r0h
0x000415e1      0164800f       sleep
0x000415e5      817a           add.b #0x7a:8,r1h
0x000415e7      0200           stc ccr,r0h
0x000415e9      0000           nop
0x000415eb      280a           mov.b @0xa:8,r0l
0x000415ed      f27a           mov.b #0x7a:8,r2h
0x000415ef      0000           nop
0x000415f1      0000           nop
0x000415f3      180a           sub.b r0h,r2l
0x000415f5      f05e           mov.b #0x5e:8,r0h
0x000415f7      0160305e       sleep
0x000415fb      015d2e01       sleep
0x000415ff      006f           nop
0x00041601      7100           bnot #0x0:3,r0h
0x00041603      3801           mov.b r0l,@0x1:8
0x00041605      006f           nop
0x00041607      7200           bclr #0x0:3,r0h
0x00041609      3801           mov.b r0l,@0x1:8
0x0004160b      0078           nop
0x0004160d      206b           mov.b @0x6b:8,r0h
0x0004160f      2200           mov.b @0x0:8,r2h
0x00041611      4010           bra @@0x10:8
0x00041613      78             invalid
0x00041614      01007810       sleep
0x00041618      6b210040       mov.w @0x40:16,r1
0x0004161c      1088           shal r0l
0x0004161e      0a92           inc r2h
0x00041620      1032           shal r2h
0x00041622      1032           shal r2h
0x00041624      1032           shal r2h
0x00041626      1032           shal r2h
0x00041628      1fa0           das r0h
0x0004162a      4204           bhi @@0x4:8
0x0004162c      5a041728       jmp @0x1728:16
0x00041630      0ce9           mov.b r6l,r1l
0x00041632      1751           neg r1h
0x00041634      1771           neg r1h
0x00041636      1031           shal r1h
0x00041638      1031           shal r1h
0x0004163a      01006ff1       sleep
0x0004163e      0038           nop
0x00041640      01006f70       sleep
0x00041644      0038           nop
0x00041646      01007810       sleep
0x0004164a      6b210040       mov.w @0x40:16,r1
0x0004164e      1078           shal r0l
0x00041650      01007800       sleep
0x00041654      6b200040       mov.w @0x40:16,r0
0x00041658      1088           shal r0l
0x0004165a      0a81           inc r1h
0x0004165c      1031           shal r1h
0x0004165e      1031           shal r1h
0x00041660      1031           shal r1h
0x00041662      1031           shal r1h
0x00041664      7a             invalid
0x00041665      0000           nop
0x00041667      0000           nop
0x00041669      200a           mov.b @0xa:8,r0h
0x0004166b      f05e           mov.b #0x5e:8,r0h
0x0004166d      015f3401       sleep
0x00041671      006f           nop
0x00041673      7100           bnot #0x0:3,r0h
0x00041675      380a           mov.b r0l,@0xa:8
0x00041677      d101           xor #0x1:8,r1h
0x00041679      0069           nop
0x0004167b      1101           shlr r1h
0x0004167d      006f           nop
0x0004167f      f000           mov.b #0x0:8,r0h
0x00041681      147a           or r7h,r2l
0x00041683      0000           nop
0x00041685      0000           nop
0x00041687      180a           sub.b r0h,r2l
0x00041689      f05e           mov.b #0x5e:8,r0h
0x0004168b      01648001       sleep
0x0004168f      006f           nop
0x00041691      7100           bnot #0x0:3,r0h
0x00041693      140f           or r0h,r7l
0x00041695      827a           add.b #0x7a:8,r2h
0x00041697      0000           nop
0x00041699      0000           nop
0x0004169b      0c0a           mov.b r0h,r2l
0x0004169d      f05e           mov.b #0x5e:8,r0h
0x0004169f      0159a40f       sleep
0x000416a3      817a           add.b #0x7a:8,r1h
0x000416a5      0000           nop
0x000416a7      0000           nop
0x000416a9      280a           mov.b @0xa:8,r0l
0x000416ab      f05e           mov.b #0x5e:8,r0h
0x000416ad      015e9e0d       sleep
0x000416b1      0046           nop
0x000416b3      045a           orc #0x5a:8,ccr
0x000416b5      0417           orc #0x17:8,ccr
0x000416b7      281a           mov.b @0x1a:8,r0l
0x000416b9      910c           addx #0xc:8,r1h
0x000416bb      e910           and #0x10:8,r1l
0x000416bd      3110           mov.b r1h,@0x10:8
0x000416bf      3101           mov.b r1h,@0x1:8
0x000416c1      006f           nop
0x000416c3      f100           mov.b #0x0:8,r1h
0x000416c5      3801           mov.b r0l,@0x1:8
0x000416c7      006f           nop
0x000416c9      7000           bset #0x0:3,r0h
0x000416cb      3801           mov.b r0l,@0x1:8
0x000416cd      0078           nop
0x000416cf      106b           shal r3l
0x000416d1      2100           mov.b @0x0:8,r1h
0x000416d3      4010           bra @@0x10:8
0x000416d5      78             invalid
0x000416d6      01007800       sleep
0x000416da      6b200040       mov.w @0x40:16,r0
0x000416de      1088           shal r0l
0x000416e0      0a81           inc r1h
0x000416e2      1031           shal r1h
0x000416e4      1031           shal r1h
0x000416e6      1031           shal r1h
0x000416e8      1031           shal r1h
0x000416ea      7a             invalid
0x000416eb      0000           nop
0x000416ed      0000           nop
0x000416ef      200a           mov.b @0xa:8,r0h
0x000416f1      f05e           mov.b #0x5e:8,r0h
0x000416f3      015f3401       sleep
0x000416f7      006f           nop
0x000416f9      7100           bnot #0x0:3,r0h
0x000416fb      380a           mov.b r0l,@0xa:8
0x000416fd      d101           xor #0x1:8,r1h
0x000416ff      0069           nop
0x00041701      1101           shlr r1h
0x00041703      006f           nop
0x00041705      f000           mov.b #0x0:8,r0h
0x00041707      147a           or r7h,r2l
0x00041709      0000           nop
0x0004170b      0000           nop
0x0004170d      180a           sub.b r0h,r2l
0x0004170f      f05e           mov.b #0x5e:8,r0h
0x00041711      01648001       sleep
0x00041715      006f           nop
0x00041717      7100           bnot #0x0:3,r0h
0x00041719      140f           or r0h,r7l
0x0004171b      827a           add.b #0x7a:8,r2h
0x0004171d      0000           nop
0x0004171f      0000           nop
0x00041721      280a           mov.b @0xa:8,r0l
0x00041723      f05e           mov.b #0x5e:8,r0h
0x00041725      0159a40a       sleep
0x00041729      066a           andc #0x6a:8,ccr
0x0004172b      2800           mov.b @0x0:8,r0l
0x0004172d      406e           bra @@0x6e:8
0x0004172f      351c           mov.b r5h,@0x1c:8
0x00041731      8644           add.b #0x44:8,r6h
0x00041733      045a           orc #0x5a:8,ccr
0x00041735      0415           orc #0x15:8,ccr
0x00041737      ac18           cmp.b #0x18:8,r4l
0x00041739      ee5a           and #0x5a:8,r6l
0x0004173b      0417           orc #0x17:8,ccr
0x0004173d      fa17           mov.b #0x17:8,r2l
0x0004173f      5617           rte
0x00041741      7678           band #0x7:3,r0l
0x00041743      606a           bset r6h,r2l
0x00041745      2600           mov.b @0x0:8,r6h
0x00041747      406e           bra @@0x6e:8
0x00041749      36a6           mov.b r6h,@0xa6:8
0x0004174b      0346           ldc r6h,ccr
0x0004174d      045a           orc #0x5a:8,ccr
0x0004174f      0417           orc #0x17:8,ccr
0x00041751      f81a           mov.b #0x1a:8,r0l
0x00041753      800c           add.b #0xc:8,r0h
0x00041755      6801           mov.b @r0,r1h
0x00041757      006f           nop
0x00041759      f000           mov.b #0x0:8,r0h
0x0004175b      3810           mov.b r0l,@0x10:8
0x0004175d      3010           mov.b r0h,@0x10:8
0x0004175f      300a           mov.b r0h,@0xa:8
0x00041761      d001           xor #0x1:8,r0h
0x00041763      006f           nop
0x00041765      f000           mov.b #0x0:8,r0h
0x00041767      3c01           mov.b r4l,@0x1:8
0x00041769      006f           nop
0x0004176b      7100           bnot #0x0:3,r0h
0x0004176d      3c01           mov.b r4l,@0x1:8
0x0004176f      0069           nop
0x00041771      1101           shlr r1h
0x00041773      006f           nop
0x00041775      f000           mov.b #0x0:8,r0h
0x00041777      1c7a           cmp.b r7h,r2l
0x00041779      0000           nop
0x0004177b      0000           nop
0x0004177d      200a           mov.b @0xa:8,r0h
0x0004177f      f05e           mov.b #0x5e:8,r0h
0x00041781      0164800f       sleep
0x00041785      817a           add.b #0x7a:8,r1h
0x00041787      0200           stc ccr,r0h
0x00041789      0000           nop
0x0004178b      280a           mov.b @0xa:8,r0l
0x0004178d      f27a           mov.b #0x7a:8,r2h
0x0004178f      0000           nop
0x00041791      0000           nop
0x00041793      140a           or r0h,r2l
0x00041795      f05e           mov.b #0x5e:8,r0h
0x00041797      0160305e       sleep
0x0004179b      015d2e01       sleep
0x0004179f      006f           nop
0x000417a1      7100           bnot #0x0:3,r0h
0x000417a3      1c01           cmp.b r0h,r1h
0x000417a5      0069           nop
0x000417a7      9001           addx #0x1:8,r0h
0x000417a9      006f           nop
0x000417ab      7000           bset #0x0:3,r0h
0x000417ad      3810           mov.b r0l,@0x10:8
0x000417af      307a           mov.b r0h,@0x7a:8
0x000417b1      1000           shll r0h
0x000417b3      406e           bra @@0x6e:8
0x000417b5      1a01           dec r1h
0x000417b7      006f           nop
0x000417b9      f000           mov.b #0x0:8,r0h
0x000417bb      3c01           mov.b r4l,@0x1:8
0x000417bd      006f           nop
0x000417bf      7100           bnot #0x0:3,r0h
0x000417c1      3c69           mov.b r4l,@0x69:8
0x000417c3      1101           shlr r1h
0x000417c5      006f           nop
0x000417c7      f000           mov.b #0x0:8,r0h
0x000417c9      1c7a           cmp.b r7h,r2l
0x000417cb      0000           nop
0x000417cd      0000           nop
0x000417cf      200a           mov.b @0xa:8,r0h
0x000417d1      f05e           mov.b #0x5e:8,r0h
0x000417d3      0164fe0f       sleep
0x000417d7      817a           add.b #0x7a:8,r1h
0x000417d9      0200           stc ccr,r0h
0x000417db      0000           nop
0x000417dd      280a           mov.b @0xa:8,r0l
0x000417df      f27a           mov.b #0x7a:8,r2h
0x000417e1      0000           nop
0x000417e3      0000           nop
0x000417e5      140a           or r0h,r2l
0x000417e7      f05e           mov.b #0x5e:8,r0h
0x000417e9      0160305e       sleep
0x000417ed      015d2e01       sleep
0x000417f1      006f           nop
0x000417f3      7100           bnot #0x0:3,r0h
0x000417f5      1c69           cmp.b r6h,r1l
0x000417f7      900a           addx #0xa:8,r0h
0x000417f9      0e6a           addx r6h,r2l
0x000417fb      2800           mov.b @0x0:8,r0l
0x000417fd      406e           bra @@0x6e:8
0x000417ff      351c           mov.b r5h,@0x1c:8
0x00041801      8e44           add.b #0x44:8,r6l
0x00041803      045a           orc #0x5a:8,ccr
0x00041805      0417           orc #0x17:8,ccr
0x00041807      3e18           mov.b r6l,@0x18:8
0x00041809      66             invalid
0x0004180a      5a041e92       jmp @0x1e92:16
0x0004180e      18             sub.b r1h,r0h
0x00041810      5a04185c       jmp @0x185c:16
0x00041814      1a80           dec r0h
0x00041816      6e780041       mov.b @(0x41:16,r7),r0l
0x0004181a      78             invalid
0x0004181b      006a           nop
0x0004181d      2e00           mov.b @0x0:8,r6l
0x0004181f      406e           bra @@0x6e:8
0x00041821      36ae           mov.b r6h,@0xae:8
0x00041823      0346           ldc r6h,ccr
0x00041825      045a           orc #0x5a:8,ccr
0x00041827      0418           orc #0x18:8,ccr
0x00041829      560c           rte
0x0004182b      e817           and #0x17:8,r0l
0x0004182d      5017           mulxu r1h,r7
0x0004182f      7010           bset #0x1:3,r0h
0x00041831      300a           mov.b r0h,@0xa:8
0x00041833      b069           subx #0x69:8,r0h
0x00041835      0079           nop
0x00041837      203f           mov.b @0x3f:8,r0h
0x00041839      ff47           mov.b #0x47:8,r7l
0x0004183b      045a           orc #0x5a:8,ccr
0x0004183d      0418           orc #0x18:8,ccr
0x0004183f      5668           rte
0x00041841      480a           bvc @@0xa:8
0x00041843      0868           add.b r6h,r0l
0x00041845      c81a           or #0x1a:8,r0l
0x00041847      0817           add.b r1h,r7h
0x00041849      5017           mulxu r1h,r7
0x0004184b      7078           bset #0x7:3,r0l
0x0004184d      006a           nop
0x0004184f      ae00           cmp.b #0x0:8,r6l
0x00041851      400f           bra @@0xf:8
0x00041853      5618           rte
0x00041855      66             invalid
0x00041856      6e780041       mov.b @(0x41:16,r7),r0l
0x0004185a      0a08           inc r0l
0x0004185c      6ef80041       mov.b r0l,@(0x41:16,r7)
0x00041860      6a290040       mov.b @0x40:16,r1l
0x00041864      6e351c98       mov.b @(0x1c98:16,r3),r5h
0x00041868      4404           bcc @@0x4:8
0x0004186a      5a041814       jmp @0x1814:16
0x0004186e      0c66           mov.b r6h,r6h
0x00041870      4704           beq @@0x4:8
0x00041872      5a041e92       jmp @0x1e92:16
0x00041876      18ee           sub.b r6l,r6l
0x00041878      5a041932       jmp @0x1932:16
0x0004187c      0ce8           mov.b r6l,r0l
0x0004187e      1750           neg r0h
0x00041880      1770           neg r0h
0x00041882      78             invalid
0x00041883      006a           nop
0x00041885      2800           mov.b @0x0:8,r0l
0x00041887      406e           bra @@0x6e:8
0x00041889      36a8           mov.b r6h,@0xa8:8
0x0004188b      0346           ldc r6h,ccr
0x0004188d      045a           orc #0x5a:8,ccr
0x0004188f      0419           orc #0x19:8,ccr
0x00041891      3017           mov.b r0h,@0x17:8
0x00041893      5017           mulxu r1h,r7
0x00041895      7001           bset #0x0:3,r1h
0x00041897      006f           nop
0x00041899      f000           mov.b #0x0:8,r0h
0x0004189b      3810           mov.b r0l,@0x10:8
0x0004189d      3010           mov.b r0h,@0x10:8
0x0004189f      3001           mov.b r0h,@0x1:8
0x000418a1      006f           nop
0x000418a3      f000           mov.b #0x0:8,r0h
0x000418a5      3c0a           mov.b r4l,@0xa:8
0x000418a7      d001           xor #0x1:8,r0h
0x000418a9      006f           nop
0x000418ab      7100           bnot #0x0:3,r0h
0x000418ad      3c01           mov.b r4l,@0x1:8
0x000418af      0078           nop
0x000418b1      106b           shal r3l
0x000418b3      2100           mov.b @0x0:8,r1h
0x000418b5      4010           bra @@0x10:8
0x000418b7      78             invalid
0x000418b8      01006981       sleep
0x000418bc      01006f70       sleep
0x000418c0      0038           nop
0x000418c2      1030           shal r0h
0x000418c4      7a             invalid
0x000418c5      1000           shll r0h
0x000418c7      406e           bra @@0x6e:8
0x000418c9      1a01           dec r1h
0x000418cb      006f           nop
0x000418cd      f000           mov.b #0x0:8,r0h
0x000418cf      3c6b           mov.b r4l,@0x6b:8
0x000418d1      2100           mov.b @0x0:8,r1h
0x000418d3      400c           bra @@0xc:8
0x000418d5      f801           mov.b #0x1:8,r0l
0x000418d7      006f           nop
0x000418d9      f000           mov.b #0x0:8,r0h
0x000418db      1c7a           cmp.b r7h,r2l
0x000418dd      0000           nop
0x000418df      0000           nop
0x000418e1      200a           mov.b @0xa:8,r0h
0x000418e3      f05e           mov.b #0x5e:8,r0h
0x000418e5      0164fe0f       sleep
0x000418e9      817a           add.b #0x7a:8,r1h
0x000418eb      0200           stc ccr,r0h
0x000418ed      04a4           orc #0xa4:8,ccr
0x000418ef      f07a           mov.b #0x7a:8,r0h
0x000418f1      0000           nop
0x000418f3      0000           nop
0x000418f5      140a           or r0h,r2l
0x000418f7      f05e           mov.b #0x5e:8,r0h
0x000418f9      0159a401       sleep
0x000418fd      006f           nop
0x000418ff      7100           bnot #0x0:3,r0h
0x00041901      3c69           mov.b r4l,@0x69:8
0x00041903      1101           shlr r1h
0x00041905      006f           nop
0x00041907      f000           mov.b #0x0:8,r0h
0x00041909      087a           add.b r7h,r2l
0x0004190b      0000           nop
0x0004190d      0000           nop
0x0004190f      0c             mov.b r1h,r0h
0x00041911      f05e           mov.b #0x5e:8,r0h
0x00041913      0164fe01       sleep
0x00041917      006f           nop
0x00041919      7100           bnot #0x0:3,r0h
0x0004191b      080f           add.b r0h,r7l
0x0004191d      820f           add.b #0xf:8,r2h
0x0004191f      f05e           mov.b #0x5e:8,r0h
0x00041921      0160305e       sleep
0x00041925      015d2e01       sleep
0x00041929      006f           nop
0x0004192b      7100           bnot #0x0:3,r0h
0x0004192d      1c69           cmp.b r6h,r1l
0x0004192f      900a           addx #0xa:8,r0h
0x00041931      0e6a           addx r6h,r2l
0x00041933      2800           mov.b @0x0:8,r0l
0x00041935      406e           bra @@0x6e:8
0x00041937      351c           mov.b r5h,@0x1c:8
0x00041939      8e44           add.b #0x44:8,r6l
0x0004193b      045a           orc #0x5a:8,ccr
0x0004193d      0418           orc #0x18:8,ccr
0x0004193f      7c5a041e       biand #0x1:3,@r5
0x00041943      926a           addx #0x6a:8,r2h
0x00041945      2800           mov.b @0x0:8,r0l
0x00041947      400f           bra @@0xf:8
0x00041949      22a8           mov.b @0xa8:8,r2h
0x0004194b      2046           mov.b @0x46:8,r0h
0x0004194d      045a           orc #0x5a:8,ccr
0x0004194f      0419           orc #0x19:8,ccr
0x00041951      80a8           add.b #0xa8:8,r0h
0x00041953      0447           orc #0x47:8,ccr
0x00041955      045a           orc #0x5a:8,ccr
0x00041957      0419           orc #0x19:8,ccr
0x00041959      66             invalid
0x0004195a      6a290040       mov.b @0x40:16,r1l
0x0004195e      0f5b           daa r3l
0x00041960      4604           bne @@0x4:8
0x00041962      5a041980       jmp @0x1980:16
0x00041966      6a280040       mov.b @0x40:16,r0l
0x0004196a      0f22           daa r2h
0x0004196c      a808           cmp.b #0x8:8,r0l
0x0004196e      4704           beq @@0x4:8
0x00041970      5a041e92       jmp @0x1e92:16
0x00041974      6a290040       mov.b @0x40:16,r1l
0x00041978      0f5b           daa r3l
0x0004197a      4704           beq @@0x4:8
0x0004197c      5a041e92       jmp @0x1e92:16
0x00041980      6b200040       mov.w @0x40:16,r0
0x00041984      0cfc           mov.b r7l,r4l
0x00041986      6ff00030       mov.w r0,@(0x30:16,r7)
0x0004198a      6b200040       mov.w @0x40:16,r0
0x0004198e      0cfe           mov.b r7l,r6l
0x00041990      6ff00032       mov.w r0,@(0x32:16,r7)
0x00041994      6b200040       mov.w @0x40:16,r0
0x00041998      0d00           mov.w r0,r0
0x0004199a      6ff00034       mov.w r0,@(0x34:16,r7)
0x0004199e      1888           sub.b r0l,r0l
0x000419a0      6aa80040       mov.b r0l,@0x40:16
0x000419a4      1076           shal r6h
0x000419a6      1888           sub.b r0l,r0l
0x000419a8      5a041ae4       jmp @0x1ae4:16
0x000419ac      1a80           dec r0h
0x000419ae      6e780041       mov.b @(0x41:16,r7),r0l
0x000419b2      78             invalid
0x000419b3      006a           nop
0x000419b5      2e00           mov.b @0x0:8,r6l
0x000419b7      406e           bra @@0x6e:8
0x000419b9      36ae           mov.b r6h,@0xae:8
0x000419bb      0346           ldc r6h,ccr
0x000419bd      045a           orc #0x5a:8,ccr
0x000419bf      041a           orc #0x1a:8,ccr
0x000419c1      de0c           xor #0xc:8,r6l
0x000419c3      e917           and #0x17:8,r1l
0x000419c5      5117           divxu r1h,r7
0x000419c7      7101           bnot #0x0:3,r1h
0x000419c9      006f           nop
0x000419cb      f100           mov.b #0x0:8,r1h
0x000419cd      3c10           mov.b r4l,@0x10:8
0x000419cf      3110           mov.b r1h,@0x10:8
0x000419d1      3101           mov.b r1h,@0x1:8
0x000419d3      006f           nop
0x000419d5      f100           mov.b #0x0:8,r1h
0x000419d7      380a           mov.b r0l,@0xa:8
0x000419d9      d101           xor #0x1:8,r1h
0x000419db      0069           nop
0x000419dd      117a           shar r2l
0x000419df      0000           nop
0x000419e1      0000           nop
0x000419e3      200a           mov.b @0xa:8,r0h
0x000419e5      f05e           mov.b #0x5e:8,r0h
0x000419e7      01648001       sleep
0x000419eb      006f           nop
0x000419ed      7100           bnot #0x0:3,r0h
0x000419ef      3801           mov.b r0l,@0x1:8
0x000419f1      0078           nop
0x000419f3      106b           shal r3l
0x000419f5      2100           mov.b @0x0:8,r1h
0x000419f7      4010           bra @@0x10:8
0x000419f9      78             invalid
0x000419fa      01006ff0       sleep
0x000419fe      0014           nop
0x00041a00      7a             invalid
0x00041a01      0000           nop
0x00041a03      0000           nop
0x00041a05      180a           sub.b r0h,r2l
0x00041a07      f05e           mov.b #0x5e:8,r0h
0x00041a09      01648001       sleep
0x00041a0d      006f           nop
0x00041a0f      7100           bnot #0x0:3,r0h
0x00041a11      140f           or r0h,r7l
0x00041a13      827a           add.b #0x7a:8,r2h
0x00041a15      0000           nop
0x00041a17      406e           bra @@0x6e:8
0x00041a19      625e           bclr r5h,r6l
0x00041a1b      0159a401       sleep
0x00041a1f      006f           nop
0x00041a21      7100           bnot #0x0:3,r0h
0x00041a23      3c10           mov.b r4l,@0x10:8
0x00041a25      310a           mov.b r1h,@0xa:8
0x00041a27      b169           subx #0x69:8,r1h
0x00041a29      117a           shar r2l
0x00041a2b      0000           nop
0x00041a2d      0000           nop
0x00041a2f      200a           mov.b @0xa:8,r0h
0x00041a31      f05e           mov.b #0x5e:8,r0h
0x00041a33      0164fe01       sleep
0x00041a37      006f           nop
0x00041a39      7100           bnot #0x0:3,r0h
0x00041a3b      3c10           mov.b r4l,@0x10:8
0x00041a3d      3110           mov.b r1h,@0x10:8
0x00041a3f      3110           mov.b r1h,@0x10:8
0x00041a41      317a           mov.b r1h,@0x7a:8
0x00041a43      1100           shlr r0h
0x00041a45      4010           bra @@0x10:8
0x00041a47      267a           mov.b @0x7a:8,r6h
0x00041a49      0200           stc ccr,r0h
0x00041a4b      406e           bra @@0x6e:8
0x00041a4d      6201           bclr r0h,r1h
0x00041a4f      006f           nop
0x00041a51      f000           mov.b #0x0:8,r0h
0x00041a53      147a           or r7h,r2l
0x00041a55      0000           nop
0x00041a57      0000           nop
0x00041a59      180a           sub.b r0h,r2l
0x00041a5b      f05e           mov.b #0x5e:8,r0h
0x00041a5d      0160300f       sleep
0x00041a61      8101           add.b #0x1:8,r1h
0x00041a63      006f           nop
0x00041a65      7000           bset #0x0:3,r0h
0x00041a67      145e           or r5h,r6l
0x00041a69      015f140d       sleep
0x00041a6d      0046           nop
0x00041a6f      045a           orc #0x5a:8,ccr
0x00041a71      041a           orc #0x1a:8,ccr
0x00041a73      de1a           xor #0x1a:8,r6l
0x00041a75      910c           addx #0xc:8,r1h
0x00041a77      e910           and #0x10:8,r1l
0x00041a79      3101           mov.b r1h,@0x1:8
0x00041a7b      006f           nop
0x00041a7d      f100           mov.b #0x0:8,r1h
0x00041a7f      380a           mov.b r0l,@0xa:8
0x00041a81      b169           subx #0x69:8,r1h
0x00041a83      117a           shar r2l
0x00041a85      0000           nop
0x00041a87      0000           nop
0x00041a89      200a           mov.b @0xa:8,r0h
0x00041a8b      f05e           mov.b #0x5e:8,r0h
0x00041a8d      0164fe01       sleep
0x00041a91      006f           nop
0x00041a93      7100           bnot #0x0:3,r0h
0x00041a95      3878           mov.b r0l,@0x78:8
0x00041a97      106b           shal r3l
0x00041a99      2100           mov.b @0x0:8,r1h
0x00041a9b      406e           bra @@0x6e:8
0x00041a9d      2a01           mov.b @0x1:8,r2l
0x00041a9f      006f           nop
0x00041aa1      f000           mov.b #0x0:8,r0h
0x00041aa3      147a           or r7h,r2l
0x00041aa5      0000           nop
0x00041aa7      0000           nop
0x00041aa9      180a           sub.b r0h,r2l
0x00041aab      f05e           mov.b #0x5e:8,r0h
0x00041aad      0164fe01       sleep
0x00041ab1      006f           nop
0x00041ab3      7100           bnot #0x0:3,r0h
0x00041ab5      140f           or r0h,r7l
0x00041ab7      827a           add.b #0x7a:8,r2h
0x00041ab9      0000           nop
0x00041abb      0000           nop
0x00041abd      0c0a           mov.b r0h,r2l
0x00041abf      f05e           mov.b #0x5e:8,r0h
0x00041ac1      0159a47a       sleep
0x00041ac5      010004a5       sleep
0x00041ac9      005e           nop
0x00041acb      015f140d       sleep
0x00041acf      0046           nop
0x00041ad1      045a           orc #0x5a:8,ccr
0x00041ad3      041a           orc #0x1a:8,ccr
0x00041ad5      def8           xor #0xf8:8,r6l
0x00041ad7      016aa800       sleep
0x00041adb      4010           bra @@0x10:8
0x00041add      766e           band #0x6:3,r6l
0x00041adf      78             invalid
0x00041ae0      0041           nop
0x00041ae2      0a08           inc r0l
0x00041ae4      6ef80041       mov.b r0l,@(0x41:16,r7)
0x00041ae8      6a290040       mov.b @0x40:16,r1l
0x00041aec      6e351c98       mov.b @(0x1c98:16,r3),r5h
0x00041af0      4404           bcc @@0x4:8
0x00041af2      5a0419ac       jmp @0x19ac:16
0x00041af6      1888           sub.b r0l,r0l
0x00041af8      5a041e80       jmp @0x1e80:16
0x00041afc      1a80           dec r0h
0x00041afe      6e780041       mov.b @(0x41:16,r7),r0l
0x00041b02      78             invalid
0x00041b03      006a           nop
0x00041b05      2e00           mov.b @0x0:8,r6l
0x00041b07      406e           bra @@0x6e:8
0x00041b09      36ae           mov.b r6h,@0xae:8
0x00041b0b      0346           ldc r6h,ccr
0x00041b0d      045a           orc #0x5a:8,ccr
0x00041b0f      041d           orc #0x1d:8,ccr
0x00041b11      b80c           subx #0xc:8,r0l
0x00041b13      e817           and #0x17:8,r0l
0x00041b15      5017           mulxu r1h,r7
0x00041b17      7010           bset #0x1:3,r0h
0x00041b19      300a           mov.b r0h,@0xa:8
0x00041b1b      b069           subx #0x69:8,r0h
0x00041b1d      0079           nop
0x00041b1f      201f           mov.b @0x1f:8,r0h
0x00041b21      ff43           mov.b #0x43:8,r7l
0x00041b23      045a           orc #0x5a:8,ccr
0x00041b25      041d           orc #0x1d:8,ccr
0x00041b27      b80c           subx #0xc:8,r0l
0x00041b29      e917           and #0x17:8,r1l
0x00041b2b      5117           divxu r1h,r7
0x00041b2d      7110           bnot #0x1:3,r0h
0x00041b2f      3110           mov.b r1h,@0x10:8
0x00041b31      3101           mov.b r1h,@0x1:8
0x00041b33      006f           nop
0x00041b35      f100           mov.b #0x0:8,r1h
0x00041b37      380a           mov.b r0l,@0xa:8
0x00041b39      d101           xor #0x1:8,r1h
0x00041b3b      0069           nop
0x00041b3d      117a           shar r2l
0x00041b3f      0000           nop
0x00041b41      0000           nop
0x00041b43      200a           mov.b @0xa:8,r0h
0x00041b45      f05e           mov.b #0x5e:8,r0h
0x00041b47      01648001       sleep
0x00041b4b      006f           nop
0x00041b4d      7100           bnot #0x0:3,r0h
0x00041b4f      3801           mov.b r0l,@0x1:8
0x00041b51      0078           nop
0x00041b53      106b           shal r3l
0x00041b55      2100           mov.b @0x0:8,r1h
0x00041b57      4010           bra @@0x10:8
0x00041b59      78             invalid
0x00041b5a      01006ff0       sleep
0x00041b5e      0014           nop
0x00041b60      7a             invalid
0x00041b61      0000           nop
0x00041b63      0000           nop
0x00041b65      180a           sub.b r0h,r2l
0x00041b67      f05e           mov.b #0x5e:8,r0h
0x00041b69      01648001       sleep
0x00041b6d      006f           nop
0x00041b6f      7100           bnot #0x0:3,r0h
0x00041b71      140f           or r0h,r7l
0x00041b73      827a           add.b #0x7a:8,r2h
0x00041b75      0000           nop
0x00041b77      406e           bra @@0x6e:8
0x00041b79      625e           bclr r5h,r6l
0x00041b7b      0159a46a       sleep
0x00041b7f      2800           mov.b @0x0:8,r0l
0x00041b81      400f           bra @@0xf:8
0x00041b83      22a8           mov.b @0xa8:8,r2h
0x00041b85      0847           add.b r4h,r7h
0x00041b87      045a           orc #0x5a:8,ccr
0x00041b89      041d           orc #0x1d:8,ccr
0x00041b8b      1e6a           subx r6h,r2l
0x00041b8d      2800           mov.b @0x0:8,r0l
0x00041b8f      400f           bra @@0xf:8
0x00041b91      5b47           jmp @@0x47:8
0x00041b93      045a           orc #0x5a:8,ccr
0x00041b95      041d           orc #0x1d:8,ccr
0x00041b97      1e0c           subx r0h,r4l
0x00041b99      e917           and #0x17:8,r1l
0x00041b9b      5117           divxu r1h,r7
0x00041b9d      7101           bnot #0x0:3,r1h
0x00041b9f      006f           nop
0x00041ba1      f100           mov.b #0x0:8,r1h
0x00041ba3      3810           mov.b r0l,@0x10:8
0x00041ba5      310a           mov.b r1h,@0xa:8
0x00041ba7      b169           subx #0x69:8,r1h
0x00041ba9      117a           shar r2l
0x00041bab      0000           nop
0x00041bad      0000           nop
0x00041baf      200a           mov.b @0xa:8,r0h
0x00041bb1      f05e           mov.b #0x5e:8,r0h
0x00041bb3      0164fe01       sleep
0x00041bb7      006f           nop
0x00041bb9      7100           bnot #0x0:3,r0h
0x00041bbb      3810           mov.b r0l,@0x10:8
0x00041bbd      3110           mov.b r1h,@0x10:8
0x00041bbf      3110           mov.b r1h,@0x10:8
0x00041bc1      317a           mov.b r1h,@0x7a:8
0x00041bc3      1100           shlr r0h
0x00041bc5      4010           bra @@0x10:8
0x00041bc7      267a           mov.b @0x7a:8,r6h
0x00041bc9      0200           stc ccr,r0h
0x00041bcb      406e           bra @@0x6e:8
0x00041bcd      6201           bclr r0h,r1h
0x00041bcf      006f           nop
0x00041bd1      f000           mov.b #0x0:8,r0h
0x00041bd3      147a           or r7h,r2l
0x00041bd5      0000           nop
0x00041bd7      0000           nop
0x00041bd9      180a           sub.b r0h,r2l
0x00041bdb      f05e           mov.b #0x5e:8,r0h
0x00041bdd      0160300f       sleep
0x00041be1      8101           add.b #0x1:8,r1h
0x00041be3      006f           nop
0x00041be5      7000           bset #0x0:3,r0h
0x00041be7      145e           or r5h,r6l
0x00041be9      015f140d       sleep
0x00041bed      0046           nop
0x00041bef      045a           orc #0x5a:8,ccr
0x00041bf1      041c           orc #0x1c:8,ccr
0x00041bf3      500c           mulxu r0h,r4
0x00041bf5      e817           and #0x17:8,r0l
0x00041bf7      5017           mulxu r1h,r7
0x00041bf9      7001           bset #0x0:3,r1h
0x00041bfb      006f           nop
0x00041bfd      f000           mov.b #0x0:8,r0h
0x00041bff      3810           mov.b r0l,@0x10:8
0x00041c01      300a           mov.b r0h,@0xa:8
0x00041c03      b001           subx #0x1:8,r0h
0x00041c05      006f           nop
0x00041c07      7100           bnot #0x0:3,r0h
0x00041c09      3810           mov.b r0l,@0x10:8
0x00041c0b      3110           mov.b r1h,@0x10:8
0x00041c0d      3110           mov.b r1h,@0x10:8
0x00041c0f      3101           mov.b r1h,@0x1:8
0x00041c11      006f           nop
0x00041c13      f000           mov.b #0x0:8,r0h
0x00041c15      247a           mov.b @0x7a:8,r4h
0x00041c17      0000           nop
0x00041c19      4010           bra @@0x10:8
0x00041c1b      260a           mov.b @0xa:8,r6h
0x00041c1d      905e           addx #0x5e:8,r0h
0x00041c1f      015d2e0d       sleep
0x00041c23      017a0000       sleep
0x00041c27      0000           nop
0x00041c29      1c0a           cmp.b r0h,r2l
0x00041c2b      f05e           mov.b #0x5e:8,r0h
0x00041c2d      0164fe0f       sleep
0x00041c31      817a           add.b #0x7a:8,r1h
0x00041c33      0200           stc ccr,r0h
0x00041c35      406e           bra @@0x6e:8
0x00041c37      627a           bclr r7h,r2l
0x00041c39      0000           nop
0x00041c3b      0000           nop
0x00041c3d      140a           or r0h,r2l
0x00041c3f      f05e           mov.b #0x5e:8,r0h
0x00041c41      0160305e       sleep
0x00041c45      015d2e01       sleep
0x00041c49      006f           nop
0x00041c4b      7100           bnot #0x0:3,r0h
0x00041c4d      2469           mov.b @0x69:8,r4h
0x00041c4f      906a           addx #0x6a:8,r0h
0x00041c51      2800           mov.b @0x0:8,r0l
0x00041c53      4010           bra @@0x10:8
0x00041c55      76a8           biand #0x2:3,r0l
0x00041c57      0146045a       sleep
0x00041c5b      041d           orc #0x1d:8,ccr
0x00041c5d      1e0c           subx r0h,r4l
0x00041c5f      e917           and #0x17:8,r1l
0x00041c61      5117           divxu r1h,r7
0x00041c63      7101           bnot #0x0:3,r1h
0x00041c65      006f           nop
0x00041c67      f100           mov.b #0x0:8,r1h
0x00041c69      3810           mov.b r0l,@0x10:8
0x00041c6b      3178           mov.b r1h,@0x78:8
0x00041c6d      106b           shal r3l
0x00041c6f      2100           mov.b @0x0:8,r1h
0x00041c71      406e           bra @@0x6e:8
0x00041c73      2a7a           mov.b @0x7a:8,r2l
0x00041c75      0000           nop
0x00041c77      0000           nop
0x00041c79      200a           mov.b @0xa:8,r0h
0x00041c7b      f05e           mov.b #0x5e:8,r0h
0x00041c7d      0164fe01       sleep
0x00041c81      006f           nop
0x00041c83      7100           bnot #0x0:3,r0h
0x00041c85      3810           mov.b r0l,@0x10:8
0x00041c87      3110           mov.b r1h,@0x10:8
0x00041c89      3110           mov.b r1h,@0x10:8
0x00041c8b      317a           mov.b r1h,@0x7a:8
0x00041c8d      1100           shlr r0h
0x00041c8f      4010           bra @@0x10:8
0x00041c91      467a           bne @@0x7a:8
0x00041c93      0200           stc ccr,r0h
0x00041c95      406e           bra @@0x6e:8
0x00041c97      6201           bclr r0h,r1h
0x00041c99      006f           nop
0x00041c9b      f000           mov.b #0x0:8,r0h
0x00041c9d      147a           or r7h,r2l
0x00041c9f      0000           nop
0x00041ca1      0000           nop
0x00041ca3      180a           sub.b r0h,r2l
0x00041ca5      f05e           mov.b #0x5e:8,r0h
0x00041ca7      0160300f       sleep
0x00041cab      8101           add.b #0x1:8,r1h
0x00041cad      006f           nop
0x00041caf      7000           bset #0x0:3,r0h
0x00041cb1      145e           or r5h,r6l
0x00041cb3      015e9e0d       sleep
0x00041cb7      0046           nop
0x00041cb9      045a           orc #0x5a:8,ccr
0x00041cbb      041d           orc #0x1d:8,ccr
0x00041cbd      1e0c           subx r0h,r4l
0x00041cbf      e817           and #0x17:8,r0l
0x00041cc1      5017           mulxu r1h,r7
0x00041cc3      7001           bset #0x0:3,r1h
0x00041cc5      006f           nop
0x00041cc7      f000           mov.b #0x0:8,r0h
0x00041cc9      3810           mov.b r0l,@0x10:8
0x00041ccb      3001           mov.b r0h,@0x1:8
0x00041ccd      006f           nop
0x00041ccf      7100           bnot #0x0:3,r0h
0x00041cd1      3810           mov.b r0l,@0x10:8
0x00041cd3      3110           mov.b r1h,@0x10:8
0x00041cd5      3110           mov.b r1h,@0x10:8
0x00041cd7      3101           mov.b r1h,@0x1:8
0x00041cd9      006f           nop
0x00041cdb      f000           mov.b #0x0:8,r0h
0x00041cdd      247a           mov.b @0x7a:8,r4h
0x00041cdf      0000           nop
0x00041ce1      4010           bra @@0x10:8
0x00041ce3      460a           bne @@0xa:8
0x00041ce5      905e           addx #0x5e:8,r0h
0x00041ce7      015d2e0d       sleep
0x00041ceb      017a0000       sleep
0x00041cef      0000           nop
0x00041cf1      1c0a           cmp.b r0h,r2l
0x00041cf3      f05e           mov.b #0x5e:8,r0h
0x00041cf5      0164fe0f       sleep
0x00041cf9      817a           add.b #0x7a:8,r1h
0x00041cfb      0200           stc ccr,r0h
0x00041cfd      406e           bra @@0x6e:8
0x00041cff      627a           bclr r7h,r2l
0x00041d01      0000           nop
0x00041d03      0000           nop
0x00041d05      140a           or r0h,r2l
0x00041d07      f05e           mov.b #0x5e:8,r0h
0x00041d09      0160305e       sleep
0x00041d0d      015d2e01       sleep
0x00041d11      006f           nop
0x00041d13      7100           bnot #0x0:3,r0h
0x00041d15      2478           mov.b @0x78:8,r4h
0x00041d17      106b           shal r3l
0x00041d19      a000           cmp.b #0x0:8,r0h
0x00041d1b      406e           bra @@0x6e:8
0x00041d1d      2a68           mov.b @0x68:8,r2l
0x00041d1f      480a           bvc @@0xa:8
0x00041d21      0868           add.b r6h,r0l
0x00041d23      c81a           or #0x1a:8,r0l
0x00041d25      0817           add.b r1h,r7h
0x00041d27      5017           mulxu r1h,r7
0x00041d29      7078           bset #0x7:3,r0l
0x00041d2b      006a           nop
0x00041d2d      ae00           cmp.b #0x0:8,r6l
0x00041d2f      400f           bra @@0xf:8
0x00041d31      560c           rte
0x00041d33      e817           and #0x17:8,r0l
0x00041d35      5017           mulxu r1h,r7
0x00041d37      7001           bset #0x0:3,r1h
0x00041d39      006f           nop
0x00041d3b      f000           mov.b #0x0:8,r0h
0x00041d3d      3c10           mov.b r4l,@0x10:8
0x00041d3f      3010           mov.b r0h,@0x10:8
0x00041d41      300a           mov.b r0h,@0xa:8
0x00041d43      d001           xor #0x1:8,r0h
0x00041d45      006f           nop
0x00041d47      f000           mov.b #0x0:8,r0h
0x00041d49      3801           mov.b r0l,@0x1:8
0x00041d4b      006f           nop
0x00041d4d      7100           bnot #0x0:3,r0h
0x00041d4f      3c10           mov.b r4l,@0x10:8
0x00041d51      310a           mov.b r1h,@0xa:8
0x00041d53      b169           subx #0x69:8,r1h
0x00041d55      110b           shlr r3l
0x00041d57      5101           divxu r0h,r1
0x00041d59      006f           nop
0x00041d5b      f000           mov.b #0x0:8,r0h
0x00041d5d      1c7a           cmp.b r7h,r2l
0x00041d5f      0000           nop
0x00041d61      0000           nop
0x00041d63      200a           mov.b @0xa:8,r0h
0x00041d65      f05e           mov.b #0x5e:8,r0h
0x00041d67      0164fe7a       sleep
0x00041d6b      010004a4       sleep
0x00041d6f      f80f           mov.b #0xf:8,r0l
0x00041d71      827a           add.b #0x7a:8,r2h
0x00041d73      0000           nop
0x00041d75      0000           nop
0x00041d77      140a           or r0h,r2l
0x00041d79      f05e           mov.b #0x5e:8,r0h
0x00041d7b      0159a401       sleep
0x00041d7f      006f           nop
0x00041d81      7100           bnot #0x0:3,r0h
0x00041d83      3801           mov.b r0l,@0x1:8
0x00041d85      0069           nop
0x00041d87      1101           shlr r1h
0x00041d89      006f           nop
0x00041d8b      f000           mov.b #0x0:8,r0h
0x00041d8d      087a           add.b r7h,r2l
0x00041d8f      0000           nop
0x00041d91      0000           nop
0x00041d93      0c0a           mov.b r0h,r2l
0x00041d95      f05e           mov.b #0x5e:8,r0h
0x00041d97      01648001       sleep
0x00041d9b      006f           nop
0x00041d9d      7100           bnot #0x0:3,r0h
0x00041d9f      080f           add.b r0h,r7l
0x00041da1      820f           add.b #0xf:8,r2h
0x00041da3      f05e           mov.b #0x5e:8,r0h
0x00041da5      0160305e       sleep
0x00041da9      015d2e01       sleep
0x00041dad      006f           nop
0x00041daf      7100           bnot #0x0:3,r0h
0x00041db1      1c01           cmp.b r0h,r1h
0x00041db3      0069           nop
0x00041db5      9018           addx #0x18:8,r0h
0x00041db7      66             invalid
0x00041db8      ae03           cmp.b #0x3:8,r6l
0x00041dba      4604           bne @@0x4:8
0x00041dbc      5a041e7a       jmp @0x1e7a:16
0x00041dc0      0ce8           mov.b r6l,r0l
0x00041dc2      1750           neg r0h
0x00041dc4      1770           neg r0h
0x00041dc6      1030           shal r0h
0x00041dc8      0ab0           inc r0h
0x00041dca      6900           mov.w @r0,r0
0x00041dcc      79203fff       mov.w #0x3fff:16,r0
0x00041dd0      4704           beq @@0x4:8
0x00041dd2      5a041e7a       jmp @0x1e7a:16
0x00041dd6      6848           mov.b @r4,r0l
0x00041dd8      0a08           inc r0l
0x00041dda      68c8           mov.b r0l,@r4
0x00041ddc      1a08           dec r0l
0x00041dde      1750           neg r0h
0x00041de0      1770           neg r0h
0x00041de2      78             invalid
0x00041de3      006a           nop
0x00041de5      ae00           cmp.b #0x0:8,r6l
0x00041de7      400f           bra @@0xf:8
0x00041de9      561a           rte
0x00041deb      800c           add.b #0xc:8,r0h
0x00041ded      e801           and #0x1:8,r0l
0x00041def      006f           nop
0x00041df1      f000           mov.b #0x0:8,r0h
0x00041df3      3c10           mov.b r4l,@0x10:8
0x00041df5      3010           mov.b r0h,@0x10:8
0x00041df7      3001           mov.b r0h,@0x1:8
0x00041df9      006f           nop
0x00041dfb      f000           mov.b #0x0:8,r0h
0x00041dfd      380a           mov.b r0l,@0xa:8
0x00041dff      d001           xor #0x1:8,r0h
0x00041e01      006f           nop
0x00041e03      7100           bnot #0x0:3,r0h
0x00041e05      3c10           mov.b r4l,@0x10:8
0x00041e07      317a           mov.b r1h,@0x7a:8
0x00041e09      0200           stc ccr,r0h
0x00041e0b      0000           nop
0x00041e0d      300a           mov.b r0h,@0xa:8
0x00041e0f      f20a           mov.b #0xa:8,r2h
0x00041e11      9269           addx #0x69:8,r2h
0x00041e13      2101           mov.b @0x1:8,r1h
0x00041e15      006f           nop
0x00041e17      f000           mov.b #0x0:8,r0h
0x00041e19      1c7a           cmp.b r7h,r2l
0x00041e1b      0000           nop
0x00041e1d      0000           nop
0x00041e1f      200a           mov.b @0xa:8,r0h
0x00041e21      f05e           mov.b #0x5e:8,r0h
0x00041e23      0164fe7a       sleep
0x00041e27      010004a4       sleep
0x00041e2b      f80f           mov.b #0xf:8,r0l
0x00041e2d      827a           add.b #0x7a:8,r2h
0x00041e2f      0000           nop
0x00041e31      0000           nop
0x00041e33      140a           or r0h,r2l
0x00041e35      f05e           mov.b #0x5e:8,r0h
0x00041e37      0159a401       sleep
0x00041e3b      006f           nop
0x00041e3d      7100           bnot #0x0:3,r0h
0x00041e3f      3801           mov.b r0l,@0x1:8
0x00041e41      0078           nop
0x00041e43      106b           shal r3l
0x00041e45      2100           mov.b @0x0:8,r1h
0x00041e47      4010           bra @@0x10:8
0x00041e49      78             invalid
0x00041e4a      01006ff0       sleep
0x00041e4e      0008           nop
0x00041e50      7a             invalid
0x00041e51      0000           nop
0x00041e53      0000           nop
0x00041e55      0c0a           mov.b r0h,r2l
0x00041e57      f05e           mov.b #0x5e:8,r0h
0x00041e59      01648001       sleep
0x00041e5d      006f           nop
0x00041e5f      7100           bnot #0x0:3,r0h
0x00041e61      080f           add.b r0h,r7l
0x00041e63      820f           add.b #0xf:8,r2h
0x00041e65      f05e           mov.b #0x5e:8,r0h
0x00041e67      0160305e       sleep
0x00041e6b      015d2e01       sleep
0x00041e6f      006f           nop
0x00041e71      7100           bnot #0x0:3,r0h
0x00041e73      1c01           cmp.b r0h,r1h
0x00041e75      0069           nop
0x00041e77      9018           addx #0x18:8,r0h
0x00041e79      66             invalid
0x00041e7a      6e780041       mov.b @(0x41:16,r7),r0l
0x00041e7e      0a08           inc r0l
0x00041e80      6ef80041       mov.b r0l,@(0x41:16,r7)
0x00041e84      6a290040       mov.b @0x40:16,r1l
0x00041e88      6e351c98       mov.b @(0x1c98:16,r3),r5h
0x00041e8c      4404           bcc @@0x4:8
0x00041e8e      5a041afc       jmp @0x1afc:16
0x00041e92      0fd0           daa r0h
0x00041e94      5e039c8a       jsr @0x9c8a:16
0x00041e98      0c68           mov.b r6h,r0l
0x00041e9a      7a             invalid
0x00041e9b      1700           not r0h
0x00041e9d      0000           nop
0x00041e9f      425e           bhi @@0x5e:8
0x00041ea1      01643654       sleep
0x00041ea5      706a           bset #0x6:3,r2l
0x00041ea7      2800           mov.b @0x0:8,r0l
0x00041ea9      400f           bra @@0xf:8
0x00041eab      22a8           mov.b @0xa8:8,r2h
0x00041ead      0446           orc #0x46:8,ccr
0x00041eaf      045a           orc #0x5a:8,ccr
0x00041eb1      041e           orc #0x1e:8,ccr
0x00041eb3      bca8           subx #0xa8:8,r4l
0x00041eb5      0847           add.b r4h,r7h
0x00041eb7      045a           orc #0x5a:8,ccr
0x00041eb9      041e           orc #0x1e:8,ccr
0x00041ebb      e618           and #0x18:8,r6h
0x00041ebd      995a           addx #0x5a:8,r1l
0x00041ebf      041e           orc #0x1e:8,ccr
0x00041ec1      d8a1           xor #0xa1:8,r0l
0x00041ec3      0346           ldc r6h,ccr
0x00041ec5      045a           orc #0x5a:8,ccr
0x00041ec7      041e           orc #0x1e:8,ccr
0x00041ec9      d617           xor #0x17:8,r6h
0x00041ecb      5117           divxu r1h,r7
0x00041ecd      7178           bnot #0x7:3,r0l
0x00041ecf      106a           shal r2l
0x00041ed1      2100           mov.b @0x0:8,r1h
0x00041ed3      400f           bra @@0xf:8
0x00041ed5      560a           rte
0x00041ed7      096a           add.w r6,r2
0x00041ed9      2800           mov.b @0x0:8,r0l
0x00041edb      400f           bra @@0xf:8
0x00041edd      551c           bsr .28
0x00041edf      8944           add.b #0x44:8,r1l
0x00041ee1      045a           orc #0x5a:8,ccr
0x00041ee3      041e           orc #0x1e:8,ccr
0x00041ee5      c254           or #0x54:8,r2h
0x00041ee7      705e           bset #0x5:3,r6l
0x00041ee9      0164587a       sleep
0x00041eed      3700           mov.b r7h,@0x0:8
0x00041eef      0000           nop
0x00041ef1      407a           bra @@0x7a:8
0x00041ef3      0300           ldc r0h,ccr
0x00041ef5      400f           bra @@0xf:8
0x00041ef7      9e7a           addx #0x7a:8,r6l
0x00041ef9      0400           orc #0x0:8,ccr
0x00041efb      400f           bra @@0xf:8
0x00041efd      5b7a           jmp @@0x7a:8
0x00041eff      0500           xorc #0x0:8,ccr
0x00041f01      406e           bra @@0x6e:8
0x00041f03      427a           bhi @@0x7a:8
0x00041f05      0600           andc #0x0:8,ccr
0x00041f07      400f           bra @@0xf:8
0x00041f09      2268           mov.b @0x68:8,r2h
0x00041f0b      68a8           mov.b r0l,@r2
0x00041f0d      4046           bra @@0x46:8
0x00041f0f      045a           orc #0x5a:8,ccr
0x00041f11      041f           orc #0x1f:8,ccr
0x00041f13      4468           bcc @@0x68:8
0x00041f15      68a8           mov.b r0l,@r2
0x00041f17      0447           orc #0x47:8,ccr
0x00041f19      045a           orc #0x5a:8,ccr
0x00041f1b      041f           orc #0x1f:8,ccr
0x00041f1d      2c6a           mov.b @0x6a:8,r4l
0x00041f1f      2800           mov.b @0x0:8,r0l
0x00041f21      400f           bra @@0xf:8
0x00041f23      5ba8           jmp @@0xa8:8
0x00041f25      0146045a       sleep
0x00041f29      041f           orc #0x1f:8,ccr
0x00041f2b      4468           bcc @@0x68:8
0x00041f2d      68a8           mov.b r0l,@r2
0x00041f2f      0847           add.b r4h,r7h
0x00041f31      045a           orc #0x5a:8,ccr
0x00041f33      0423           orc #0x23:8,ccr
0x00041f35      d46a           xor #0x6a:8,r4h
0x00041f37      2800           mov.b @0x0:8,r0l
0x00041f39      400f           bra @@0xf:8
0x00041f3b      5ba8           jmp @@0xa8:8
0x00041f3d      0147045a       sleep
0x00041f41      0423           orc #0x23:8,ccr
0x00041f43      d47a           xor #0x7a:8,r4h
0x00041f45      0000           nop
0x00041f47      04a5           orc #0xa5:8,ccr
0x00041f49      087a           add.b r7h,r2l
0x00041f4b      01000000       sleep
0x00041f4f      300a           mov.b r0h,@0xa:8
0x00041f51      f15e           mov.b #0x5e:8,r1h
0x00041f53      01640a18       sleep
0x00041f57      66             invalid
0x00041f58      0fd0           daa r0h
0x00041f5a      7a             invalid
0x00041f5b      1000           shll r0h
0x00041f5d      0000           nop
0x00041f5f      1801           sub.b r0h,r1h
0x00041f61      006f           nop
0x00041f63      f000           mov.b #0x0:8,r0h
0x00041f65      385a           mov.b r0l,@0x5a:8
0x00041f67      0420           orc #0x20:8,ccr
0x00041f69      f40c           mov.b #0xc:8,r4h
0x00041f6b      6817           mov.b @r1,r7h
0x00041f6d      5017           mulxu r1h,r7
0x00041f6f      7078           bset #0x7:3,r0l
0x00041f71      006a           nop
0x00041f73      2e00           mov.b @0x0:8,r6l
0x00041f75      406e           bra @@0x6e:8
0x00041f77      36ae           mov.b r6h,@0xae:8
0x00041f79      0346           ldc r6h,ccr
0x00041f7b      045a           orc #0x5a:8,ccr
0x00041f7d      0420           orc #0x20:8,ccr
0x00041f7f      78             invalid
0x00041f80      0ce9           mov.b r6l,r1l
0x00041f82      1751           neg r1h
0x00041f84      1771           neg r1h
0x00041f86      1031           shal r1h
0x00041f88      1031           shal r1h
0x00041f8a      01006ff1       sleep
0x00041f8e      003c           nop
0x00041f90      01006f70       sleep
0x00041f94      003c           nop
0x00041f96      01007810       sleep
0x00041f9a      6b210040       mov.w @0x40:16,r1
0x00041f9e      1078           shal r0l
0x00041fa0      01007800       sleep
0x00041fa4      6b200040       mov.w @0x40:16,r0
0x00041fa8      1088           shal r0l
0x00041faa      0a81           inc r1h
0x00041fac      1031           shal r1h
0x00041fae      1031           shal r1h
0x00041fb0      1031           shal r1h
0x00041fb2      1031           shal r1h
0x00041fb4      7a             invalid
0x00041fb5      0000           nop
0x00041fb7      0000           nop
0x00041fb9      280a           mov.b @0xa:8,r0l
0x00041fbb      f05e           mov.b #0x5e:8,r0h
0x00041fbd      015f3401       sleep
0x00041fc1      006f           nop
0x00041fc3      7100           bnot #0x0:3,r0h
0x00041fc5      3c0a           mov.b r4l,@0xa:8
0x00041fc7      b101           subx #0x1:8,r1h
0x00041fc9      0069           nop
0x00041fcb      1101           shlr r1h
0x00041fcd      006f           nop
0x00041fcf      f000           mov.b #0x0:8,r0h
0x00041fd1      1c7a           cmp.b r7h,r2l
0x00041fd3      0000           nop
0x00041fd5      0000           nop
0x00041fd7      200a           mov.b @0xa:8,r0h
0x00041fd9      f05e           mov.b #0x5e:8,r0h
0x00041fdb      01648001       sleep
0x00041fdf      006f           nop
0x00041fe1      7100           bnot #0x0:3,r0h
0x00041fe3      1c0f           cmp.b r0h,r7l
0x00041fe5      827a           add.b #0x7a:8,r2h
0x00041fe7      0000           nop
0x00041fe9      0000           nop
0x00041feb      140a           or r0h,r2l
0x00041fed      f05e           mov.b #0x5e:8,r0h
0x00041fef      0159a40f       sleep
0x00041ff3      817a           add.b #0x7a:8,r1h
0x00041ff5      0000           nop
0x00041ff7      0000           nop
0x00041ff9      300a           mov.b r0h,@0xa:8
0x00041ffb      f05e           mov.b #0x5e:8,r0h
0x00041ffd      015e9e0d       sleep
0x00042001      0046           nop
0x00042003      045a           orc #0x5a:8,ccr
0x00042005      0420           orc #0x20:8,ccr
0x00042007      f21a           mov.b #0x1a:8,r2h
0x00042009      910c           addx #0xc:8,r1h
0x0004200b      e910           and #0x10:8,r1l
0x0004200d      3110           mov.b r1h,@0x10:8
0x0004200f      3101           mov.b r1h,@0x1:8
0x00042011      006f           nop
0x00042013      f100           mov.b #0x0:8,r1h
0x00042015      3c01           mov.b r4l,@0x1:8
0x00042017      006f           nop
0x00042019      7000           bset #0x0:3,r0h
0x0004201b      3c01           mov.b r4l,@0x1:8
0x0004201d      0078           nop
0x0004201f      106b           shal r3l
0x00042021      2100           mov.b @0x0:8,r1h
0x00042023      4010           bra @@0x10:8
0x00042025      78             invalid
0x00042026      01007800       sleep
0x0004202a      6b200040       mov.w @0x40:16,r0
0x0004202e      1088           shal r0l
0x00042030      0a81           inc r1h
0x00042032      1031           shal r1h
0x00042034      1031           shal r1h
0x00042036      1031           shal r1h
0x00042038      1031           shal r1h
0x0004203a      7a             invalid
0x0004203b      0000           nop
0x0004203d      0000           nop
0x0004203f      280a           mov.b @0xa:8,r0l
0x00042041      f05e           mov.b #0x5e:8,r0h
0x00042043      015f3401       sleep
0x00042047      006f           nop
0x00042049      7100           bnot #0x0:3,r0h
0x0004204b      3c0a           mov.b r4l,@0xa:8
0x0004204d      b101           subx #0x1:8,r1h
0x0004204f      0069           nop
0x00042051      1101           shlr r1h
0x00042053      006f           nop
0x00042055      f000           mov.b #0x0:8,r0h
0x00042057      1c7a           cmp.b r7h,r2l
0x00042059      0000           nop
0x0004205b      0000           nop
0x0004205d      200a           mov.b @0xa:8,r0h
0x0004205f      f05e           mov.b #0x5e:8,r0h
0x00042061      01648001       sleep
0x00042065      006f           nop
0x00042067      7100           bnot #0x0:3,r0h
0x00042069      1c0f           cmp.b r0h,r7l
0x0004206b      827a           add.b #0x7a:8,r2h
0x0004206d      0000           nop
0x0004206f      0000           nop
0x00042071      300a           mov.b r0h,@0xa:8
0x00042073      f05a           mov.b #0x5a:8,r0h
0x00042075      0420           orc #0x20:8,ccr
0x00042077      ee01           and #0x1:8,r6l
0x00042079      006f           nop
0x0004207b      7000           bset #0x0:3,r0h
0x0004207d      381a           mov.b r0l,@0x1a:8
0x0004207f      910c           addx #0xc:8,r1h
0x00042081      e910           and #0x10:8,r1l
0x00042083      3110           mov.b r1h,@0x10:8
0x00042085      3101           mov.b r1h,@0x1:8
0x00042087      006f           nop
0x00042089      f100           mov.b #0x0:8,r1h
0x0004208b      3c01           mov.b r4l,@0x1:8
0x0004208d      006f           nop
0x0004208f      7200           bclr #0x0:3,r0h
0x00042091      3c01           mov.b r4l,@0x1:8
0x00042093      0078           nop
0x00042095      106b           shal r3l
0x00042097      2100           mov.b @0x0:8,r1h
0x00042099      4010           bra @@0x10:8
0x0004209b      78             invalid
0x0004209c      01007820       sleep
0x000420a0      6b220040       mov.w @0x40:16,r2
0x000420a4      1088           shal r0l
0x000420a6      0aa1           inc r1h
0x000420a8      1031           shal r1h
0x000420aa      1031           shal r1h
0x000420ac      1031           shal r1h
0x000420ae      1031           shal r1h
0x000420b0      01006ff0       sleep
0x000420b4      0024           nop
0x000420b6      7a             invalid
0x000420b7      0000           nop
0x000420b9      0000           nop
0x000420bb      280a           mov.b @0xa:8,r0l
0x000420bd      f05e           mov.b #0x5e:8,r0h
0x000420bf      015f3401       sleep
0x000420c3      006f           nop
0x000420c5      7100           bnot #0x0:3,r0h
0x000420c7      3c0a           mov.b r4l,@0xa:8
0x000420c9      b101           subx #0x1:8,r1h
0x000420cb      0069           nop
0x000420cd      1101           shlr r1h
0x000420cf      006f           nop
0x000420d1      f000           mov.b #0x0:8,r0h
0x000420d3      187a           sub.b r7h,r2l
0x000420d5      0000           nop
0x000420d7      0000           nop
0x000420d9      1c0a           cmp.b r0h,r2l
0x000420db      f05e           mov.b #0x5e:8,r0h
0x000420dd      01648001       sleep
0x000420e1      006f           nop
0x000420e3      7100           bnot #0x0:3,r0h
0x000420e5      180f           sub.b r0h,r7l
0x000420e7      8201           add.b #0x1:8,r2h
0x000420e9      006f           nop
0x000420eb      7000           bset #0x0:3,r0h
0x000420ed      245e           mov.b @0x5e:8,r4h
0x000420ef      0159a40a       sleep
0x000420f3      066a           andc #0x6a:8,ccr
0x000420f5      2800           mov.b @0x0:8,r0l
0x000420f7      406e           bra @@0x6e:8
0x000420f9      351c           mov.b r5h,@0x1c:8
0x000420fb      8644           add.b #0x44:8,r6h
0x000420fd      045a           orc #0x5a:8,ccr
0x000420ff      041f           orc #0x1f:8,ccr
0x00042101      6a7a0000       mov.b @0x0:16,r2l
0x00042105      0000           nop
0x00042107      300a           mov.b r0h,@0xa:8
0x00042109      f00f           mov.b #0xf:8,r0h
0x0004210b      d15e           xor #0x5e:8,r1h
0x0004210d      01640a7a       sleep
0x00042111      0000           nop
0x00042113      0000           nop
0x00042115      300a           mov.b r0h,@0xa:8
0x00042117      f07a           mov.b #0x7a:8,r0h
0x00042119      01000000       sleep
0x0004211d      080a           add.b r0h,r2l
0x0004211f      d15e           xor #0x5e:8,r1h
0x00042121      01640a7a       sleep
0x00042125      0000           nop
0x00042127      0000           nop
0x00042129      300a           mov.b r0h,@0xa:8
0x0004212b      f07a           mov.b #0x7a:8,r0h
0x0004212d      01000000       sleep
0x00042131      100a           shll r2l
0x00042133      d15e           xor #0x5e:8,r1h
0x00042135      01640a18       sleep
0x00042139      66             invalid
0x0004213a      5a0423c2       jmp @0x23c2:16
0x0004213e      0c68           mov.b r6h,r0l
0x00042140      1750           neg r0h
0x00042142      1770           neg r0h
0x00042144      78             invalid
0x00042145      006a           nop
0x00042147      2e00           mov.b @0x0:8,r6l
0x00042149      406e           bra @@0x6e:8
0x0004214b      36ae           mov.b r6h,@0xae:8
0x0004214d      0346           ldc r6h,ccr
0x0004214f      045a           orc #0x5a:8,ccr
0x00042151      0421           orc #0x21:8,ccr
0x00042153      ae0c           cmp.b #0xc:8,r6l
0x00042155      e917           and #0x17:8,r1l
0x00042157      5117           divxu r1h,r7
0x00042159      7101           bnot #0x0:3,r1h
0x0004215b      006f           nop
0x0004215d      f100           mov.b #0x0:8,r1h
0x0004215f      2c01           mov.b @0x1:8,r4l
0x00042161      006f           nop
0x00042163      7000           bset #0x0:3,r0h
0x00042165      2c78           mov.b @0x78:8,r4l
0x00042167      006a           nop
0x00042169      2900           mov.b @0x0:8,r1l
0x0004216b      400f           bra @@0xf:8
0x0004216d      6117           bnot r1h,r7h
0x0004216f      517a           divxu r7h,r2
0x00042171      0000           nop
0x00042173      0000           nop
0x00042175      240a           mov.b @0xa:8,r4h
0x00042177      f05e           mov.b #0x5e:8,r0h
0x00042179      0164fe0f       sleep
0x0004217d      817a           add.b #0x7a:8,r1h
0x0004217f      0200           stc ccr,r0h
0x00042181      04a5           orc #0xa5:8,ccr
0x00042183      107a           shal r2l
0x00042185      0000           nop
0x00042187      0000           nop
0x00042189      1c0a           cmp.b r0h,r2l
0x0004218b      f05e           mov.b #0x5e:8,r0h
0x0004218d      0160300f       sleep
0x00042191      817a           add.b #0x7a:8,r1h
0x00042193      0200           stc ccr,r0h
0x00042195      04a5           orc #0xa5:8,ccr
0x00042197      187a           sub.b r7h,r2l
0x00042199      0000           nop
0x0004219b      0000           nop
0x0004219d      140a           or r0h,r2l
0x0004219f      f05e           mov.b #0x5e:8,r0h
0x000421a1      0159a46b       sleep
0x000421a5      2100           mov.b @0x0:8,r1h
0x000421a7      406e           bra @@0x6e:8
0x000421a9      325a           mov.b r2h,@0x5a:8
0x000421ab      0422           orc #0x22:8,ccr
0x000421ad      140c           or r0h,r4l
0x000421af      e917           and #0x17:8,r1l
0x000421b1      5117           divxu r1h,r7
0x000421b3      7101           bnot #0x0:3,r1h
0x000421b5      006f           nop
0x000421b7      f100           mov.b #0x0:8,r1h
0x000421b9      3c01           mov.b r4l,@0x1:8
0x000421bb      006f           nop
0x000421bd      f100           mov.b #0x0:8,r1h
0x000421bf      2c01           mov.b @0x1:8,r4l
0x000421c1      006f           nop
0x000421c3      7000           bset #0x0:3,r0h
0x000421c5      2c78           mov.b @0x78:8,r4l
0x000421c7      006a           nop
0x000421c9      2900           mov.b @0x0:8,r1l
0x000421cb      400f           bra @@0xf:8
0x000421cd      6117           bnot r1h,r7h
0x000421cf      517a           divxu r7h,r2
0x000421d1      0000           nop
0x000421d3      0000           nop
0x000421d5      240a           mov.b @0xa:8,r4h
0x000421d7      f05e           mov.b #0x5e:8,r0h
0x000421d9      0164fe0f       sleep
0x000421dd      817a           add.b #0x7a:8,r1h
0x000421df      0200           stc ccr,r0h
0x000421e1      04a5           orc #0xa5:8,ccr
0x000421e3      107a           shal r2l
0x000421e5      0000           nop
0x000421e7      0000           nop
0x000421e9      1c0a           cmp.b r0h,r2l
0x000421eb      f05e           mov.b #0x5e:8,r0h
0x000421ed      0160300f       sleep
0x000421f1      817a           add.b #0x7a:8,r1h
0x000421f3      0200           stc ccr,r0h
0x000421f5      04a5           orc #0xa5:8,ccr
0x000421f7      187a           sub.b r7h,r2l
0x000421f9      0000           nop
0x000421fb      0000           nop
0x000421fd      140a           or r0h,r2l
0x000421ff      f05e           mov.b #0x5e:8,r0h
0x00042201      0159a401       sleep
0x00042205      006f           nop
0x00042207      7100           bnot #0x0:3,r0h
0x00042209      3c10           mov.b r4l,@0x10:8
0x0004220b      3178           mov.b r1h,@0x78:8
0x0004220d      106b           shal r3l
0x0004220f      2100           mov.b @0x0:8,r1h
0x00042211      406e           bra @@0x6e:8
0x00042213      2201           mov.b @0x1:8,r2h
0x00042215      006f           nop
0x00042217      f000           mov.b #0x0:8,r0h
0x00042219      087a           add.b r7h,r2l
0x0004221b      0000           nop
0x0004221d      0000           nop
0x0004221f      0c0a           mov.b r0h,r2l
0x00042221      f05e           mov.b #0x5e:8,r0h
0x00042223      0164fe01       sleep
0x00042227      006f           nop
0x00042229      7100           bnot #0x0:3,r0h
0x0004222b      080f           add.b r0h,r7l
0x0004222d      820f           add.b #0xf:8,r2h
0x0004222f      f05e           mov.b #0x5e:8,r0h
0x00042231      0159a47a       sleep
0x00042235      0100406e       sleep
0x00042239      3a5e           mov.b r2l,@0x5e:8
0x0004223b      01640a0c       sleep
0x0004223f      e917           and #0x17:8,r1l
0x00042241      5117           divxu r1h,r7
0x00042243      7110           bnot #0x1:3,r0h
0x00042245      3110           mov.b r1h,@0x10:8
0x00042247      3110           mov.b r1h,@0x10:8
0x00042249      310a           mov.b r1h,@0xa:8
0x0004224b      d17a           xor #0x7a:8,r1h
0x0004224d      0000           nop
0x0004224f      406e           bra @@0x6e:8
0x00042251      3a5e           mov.b r2l,@0x5e:8
0x00042253      015e9e0d       sleep
0x00042257      0046           nop
0x00042259      045a           orc #0x5a:8,ccr
0x0004225b      0422           orc #0x22:8,ccr
0x0004225d      760c           band #0x0:3,r4l
0x0004225f      e817           and #0x17:8,r0l
0x00042261      5017           mulxu r1h,r7
0x00042263      7010           bset #0x1:3,r0h
0x00042265      3010           mov.b r0h,@0x10:8
0x00042267      3010           mov.b r0h,@0x10:8
0x00042269      300a           mov.b r0h,@0xa:8
0x0004226b      d07a           xor #0x7a:8,r0h
0x0004226d      0100406e       sleep
0x00042271      3a5e           mov.b r2l,@0x5e:8
0x00042273      01640a1a       sleep
0x00042277      8068           add.b #0x68:8,r0h
0x00042279      4810           bvc @@0x10:8
0x0004227b      3010           mov.b r0h,@0x10:8
0x0004227d      3010           mov.b r0h,@0x10:8
0x0004227f      3010           mov.b r0h,@0x10:8
0x00042281      3001           mov.b r0h,@0x1:8
0x00042283      006f           nop
0x00042285      f000           mov.b #0x0:8,r0h
0x00042287      380c           mov.b r0l,@0xc:8
0x00042289      e917           and #0x17:8,r1l
0x0004228b      5117           divxu r1h,r7
0x0004228d      7110           bnot #0x1:3,r0h
0x0004228f      3110           mov.b r1h,@0x10:8
0x00042291      3101           mov.b r1h,@0x1:8
0x00042293      006f           nop
0x00042295      f100           mov.b #0x0:8,r1h
0x00042297      3c7a           mov.b r4l,@0x7a:8
0x00042299      1000           shll r0h
0x0004229b      400f           bra @@0xf:8
0x0004229d      ae0a           cmp.b #0xa:8,r6l
0x0004229f      900a           addx #0xa:8,r0h
0x000422a1      b101           subx #0x1:8,r1h
0x000422a3      0069           nop
0x000422a5      1101           shlr r1h
0x000422a7      006f           nop
0x000422a9      f000           mov.b #0x0:8,r0h
0x000422ab      247a           mov.b @0x7a:8,r4h
0x000422ad      0000           nop
0x000422af      0000           nop
0x000422b1      280a           mov.b @0xa:8,r0l
0x000422b3      f05e           mov.b #0x5e:8,r0h
0x000422b5      0164800f       sleep
0x000422b9      817a           add.b #0x7a:8,r1h
0x000422bb      0200           stc ccr,r0h
0x000422bd      406e           bra @@0x6e:8
0x000422bf      3a7a           mov.b r2l,@0x7a:8
0x000422c1      0000           nop
0x000422c3      0000           nop
0x000422c5      1c0a           cmp.b r0h,r2l
0x000422c7      f05e           mov.b #0x5e:8,r0h
0x000422c9      0160305e       sleep
0x000422cd      015d2e01       sleep
0x000422d1      006f           nop
0x000422d3      7100           bnot #0x0:3,r0h
0x000422d5      3c01           mov.b r4l,@0x1:8
0x000422d7      0078           nop
0x000422d9      106b           shal r3l
0x000422db      2100           mov.b @0x0:8,r1h
0x000422dd      4010           bra @@0x10:8
0x000422df      880a           add.b #0xa:8,r0l
0x000422e1      9001           addx #0x1:8,r0h
0x000422e3      006f           nop
0x000422e5      7100           bnot #0x0:3,r0h
0x000422e7      387a           mov.b r0l,@0x7a:8
0x000422e9      1100           shlr r0h
0x000422eb      400f           bra @@0xf:8
0x000422ed      ee01           and #0x1:8,r6l
0x000422ef      006f           nop
0x000422f1      7200           bclr #0x0:3,r0h
0x000422f3      3c0a           mov.b r4l,@0xa:8
0x000422f5      a101           cmp.b #0x1:8,r1h
0x000422f7      0069           nop
0x000422f9      9001           addx #0x1:8,r0h
0x000422fb      006f           nop
0x000422fd      7100           bnot #0x0:3,r0h
0x000422ff      2401           mov.b @0x1:8,r4h
0x00042301      0069           nop
0x00042303      901a           addx #0x1a:8,r0h
0x00042305      8068           add.b #0x68:8,r0h
0x00042307      4810           bvc @@0x10:8
0x00042309      3010           mov.b r0h,@0x10:8
0x0004230b      3010           mov.b r0h,@0x10:8
0x0004230d      3010           mov.b r0h,@0x10:8
0x0004230f      307a           mov.b r0h,@0x7a:8
0x00042311      1000           shll r0h
0x00042313      400f           bra @@0xf:8
0x00042315      ae01           cmp.b #0x1:8,r6l
0x00042317      006f           nop
0x00042319      7100           bnot #0x0:3,r0h
0x0004231b      3c0a           mov.b r4l,@0xa:8
0x0004231d      9001           addx #0x1:8,r0h
0x0004231f      0069           nop
0x00042321      007a           nop
0x00042323      2003           mov.b @0x3:8,r0h
0x00042325      ffff           mov.b #0xff:8,r7l
0x00042327      ff42           mov.b #0x42:8,r7l
0x00042329      045a           orc #0x5a:8,ccr
0x0004232b      0423           orc #0x23:8,ccr
0x0004232d      6e1a8068       mov.b @(0x8068:16,r1),r2l
0x00042331      4810           bvc @@0x10:8
0x00042333      3010           mov.b r0h,@0x10:8
0x00042335      3010           mov.b r0h,@0x10:8
0x00042337      3010           mov.b r0h,@0x10:8
0x00042339      3001           mov.b r0h,@0x1:8
0x0004233b      006f           nop
0x0004233d      f000           mov.b #0x0:8,r0h
0x0004233f      380c           mov.b r0l,@0xc:8
0x00042341      e917           and #0x17:8,r1l
0x00042343      5117           divxu r1h,r7
0x00042345      7110           bnot #0x1:3,r0h
0x00042347      3110           mov.b r1h,@0x10:8
0x00042349      317a           mov.b r1h,@0x7a:8
0x0004234b      1000           shll r0h
0x0004234d      400f           bra @@0xf:8
0x0004234f      ae0a           cmp.b #0xa:8,r6l
0x00042351      9001           addx #0x1:8,r0h
0x00042353      006f           nop
0x00042355      7200           bclr #0x0:3,r0h
0x00042357      387a           mov.b r0l,@0x7a:8
0x00042359      1200           rotxl r0h
0x0004235b      400f           bra @@0xf:8
0x0004235d      ee0a           and #0xa:8,r6l
0x0004235f      927a           addx #0x7a:8,r2h
0x00042361      0103ffff       sleep
0x00042365      ff01           mov.b #0x1:8,r7l
0x00042367      0069           nop
0x00042369      a101           cmp.b #0x1:8,r1h
0x0004236b      0069           nop
0x0004236d      811a           add.b #0x1a:8,r1h
0x0004236f      800c           add.b #0xc:8,r0h
0x00042371      e810           and #0x10:8,r0l
0x00042373      3001           mov.b r0h,@0x1:8
0x00042375      006f           nop
0x00042377      f000           mov.b #0x0:8,r0h
0x00042379      3c01           mov.b r4l,@0x1:8
0x0004237b      006f           nop
0x0004237d      7100           bnot #0x0:3,r0h
0x0004237f      3c78           mov.b r4l,@0x78:8
0x00042381      106b           shal r3l
0x00042383      2100           mov.b @0x0:8,r1h
0x00042385      406e           bra @@0x6e:8
0x00042387      1a01           dec r1h
0x00042389      006f           nop
0x0004238b      f000           mov.b #0x0:8,r0h
0x0004238d      247a           mov.b @0x7a:8,r4h
0x0004238f      0000           nop
0x00042391      0000           nop
0x00042393      280a           mov.b @0xa:8,r0l
0x00042395      f05e           mov.b #0x5e:8,r0h
0x00042397      0164fe0f       sleep
0x0004239b      817a           add.b #0x7a:8,r1h
0x0004239d      0200           stc ccr,r0h
0x0004239f      406e           bra @@0x6e:8
0x000423a1      3a7a           mov.b r2l,@0x7a:8
0x000423a3      0000           nop
0x000423a5      0000           nop
0x000423a7      1c0a           cmp.b r0h,r2l
0x000423a9      f05e           mov.b #0x5e:8,r0h
0x000423ab      0160305e       sleep
0x000423af      015d2e01       sleep
0x000423b3      006f           nop
0x000423b5      7100           bnot #0x0:3,r0h
0x000423b7      2478           mov.b @0x78:8,r4h
0x000423b9      106b           shal r3l
0x000423bb      a000           cmp.b #0x0:8,r0h
0x000423bd      4010           bra @@0x10:8
0x000423bf      0e0a           addx r0h,r2l
0x000423c1      066a           andc #0x6a:8,ccr
0x000423c3      2800           mov.b @0x0:8,r0l
0x000423c5      406e           bra @@0x6e:8
0x000423c7      351c           mov.b r5h,@0x1c:8
0x000423c9      8644           add.b #0x44:8,r6h
0x000423cb      045a           orc #0x5a:8,ccr
0x000423cd      0421           orc #0x21:8,ccr
0x000423cf      3e5a           mov.b r6l,@0x5a:8
0x000423d1      0428           orc #0x28:8,ccr
0x000423d3      e868           and #0x68:8,r0l
0x000423d5      68a8           mov.b r0l,@r2
0x000423d7      2046           mov.b @0x46:8,r0h
0x000423d9      045a           orc #0x5a:8,ccr
0x000423db      0424           orc #0x24:8,ccr
0x000423dd      0a68           inc r0l
0x000423df      68a8           mov.b r0l,@r2
0x000423e1      0447           orc #0x47:8,ccr
0x000423e3      045a           orc #0x5a:8,ccr
0x000423e5      0423           orc #0x23:8,ccr
0x000423e7      f46a           mov.b #0x6a:8,r4h
0x000423e9      2800           mov.b @0x0:8,r0l
0x000423eb      400f           bra @@0xf:8
0x000423ed      5b46           jmp @@0x46:8
0x000423ef      045a           orc #0x5a:8,ccr
0x000423f1      0424           orc #0x24:8,ccr
0x000423f3      0a68           inc r0l
0x000423f5      68a8           mov.b r0l,@r2
0x000423f7      0847           add.b r4h,r7h
0x000423f9      045a           orc #0x5a:8,ccr
0x000423fb      0428           orc #0x28:8,ccr
0x000423fd      e86a           and #0x6a:8,r0l
0x000423ff      2800           mov.b @0x0:8,r0l
0x00042401      400f           bra @@0xf:8
0x00042403      5b47           jmp @@0x47:8
0x00042405      045a           orc #0x5a:8,ccr
0x00042407      0428           orc #0x28:8,ccr
0x00042409      e87a           and #0x7a:8,r0l
0x0004240b      0600           andc #0x0:8,ccr
0x0004240d      400b           bra @@0xb:8
0x0004240f      246f           mov.b @0x6f:8,r4h
0x00042411      6101           bnot r0h,r1h
0x00042413      e40f           and #0xf:8,r4h
0x00042415      d05e           xor #0x5e:8,r0h
0x00042417      0164fe6f       sleep
0x0004241b      6101           bnot r0h,r1h
0x0004241d      e47a           and #0x7a:8,r4h
0x0004241f      0000           nop
0x00042421      0000           nop
0x00042423      080a           add.b r0h,r2l
0x00042425      d05e           xor #0x5e:8,r0h
0x00042427      0164fe6f       sleep
0x0004242b      6101           bnot r0h,r1h
0x0004242d      e47a           and #0x7a:8,r4h
0x0004242f      0000           nop
0x00042431      0000           nop
0x00042433      100a           shll r2l
0x00042435      d05e           xor #0x5e:8,r0h
0x00042437      0164fe6f       sleep
0x0004243b      6101           bnot r0h,r1h
0x0004243d      e67a           and #0x7a:8,r6h
0x0004243f      0000           nop
0x00042441      0000           nop
0x00042443      180a           sub.b r0h,r2l
0x00042445      d05e           xor #0x5e:8,r0h
0x00042447      0164fe18       sleep
0x0004244b      66             invalid
0x0004244c      5a0428da       jmp @0x28da:16
0x00042450      0c68           mov.b r6h,r0l
0x00042452      1750           neg r0h
0x00042454      1770           neg r0h
0x00042456      78             invalid
0x00042457      006a           nop
0x00042459      2e00           mov.b @0x0:8,r6l
0x0004245b      406e           bra @@0x6e:8
0x0004245d      360c           mov.b r6h,@0xc:8
0x0004245f      e917           and #0x17:8,r1l
0x00042461      5117           divxu r1h,r7
0x00042463      7110           bnot #0x1:3,r0h
0x00042465      3110           mov.b r1h,@0x10:8
0x00042467      3101           mov.b r1h,@0x1:8
0x00042469      006f           nop
0x0004246b      f100           mov.b #0x0:8,r1h
0x0004246d      3c0a           mov.b r4l,@0xa:8
0x0004246f      b101           subx #0x1:8,r1h
0x00042471      0069           nop
0x00042473      117a           shar r2l
0x00042475      0000           nop
0x00042477      0000           nop
0x00042479      280a           mov.b @0xa:8,r0l
0x0004247b      f05e           mov.b #0x5e:8,r0h
0x0004247d      01648001       sleep
0x00042481      006f           nop
0x00042483      7100           bnot #0x0:3,r0h
0x00042485      3c01           mov.b r4l,@0x1:8
0x00042487      0078           nop
0x00042489      106b           shal r3l
0x0004248b      2100           mov.b @0x0:8,r1h
0x0004248d      4010           bra @@0x10:8
0x0004248f      78             invalid
0x00042490      01006ff0       sleep
0x00042494      001c           nop
0x00042496      7a             invalid
0x00042497      0000           nop
0x00042499      0000           nop
0x0004249b      200a           mov.b @0xa:8,r0h
0x0004249d      f05e           mov.b #0x5e:8,r0h
0x0004249f      01648001       sleep
0x000424a3      006f           nop
0x000424a5      7100           bnot #0x0:3,r0h
0x000424a7      1c0f           cmp.b r0h,r7l
0x000424a9      827a           add.b #0x7a:8,r2h
0x000424ab      0000           nop
0x000424ad      406e           bra @@0x6e:8
0x000424af      625e           bclr r5h,r6l
0x000424b1      0159a4ae       sleep
0x000424b5      0346           ldc r6h,ccr
0x000424b7      045a           orc #0x5a:8,ccr
0x000424b9      0426           orc #0x26:8,ccr
0x000424bb      64             invalid
0x000424bc      6a280040       mov.b @0x40:16,r0l
0x000424c0      0f22           daa r2h
0x000424c2      a808           cmp.b #0x8:8,r0l
0x000424c4      4704           beq @@0x4:8
0x000424c6      5a042664       jmp @0x2664:16
0x000424ca      6a280040       mov.b @0x40:16,r0l
0x000424ce      0f5b           daa r3l
0x000424d0      4704           beq @@0x4:8
0x000424d2      5a042664       jmp @0x2664:16
0x000424d6      0ce9           mov.b r6l,r1l
0x000424d8      1751           neg r1h
0x000424da      1771           neg r1h
0x000424dc      01006ff1       sleep
0x000424e0      003c           nop
0x000424e2      1031           shal r1h
0x000424e4      78             invalid
0x000424e5      106b           shal r3l
0x000424e7      2100           mov.b @0x0:8,r1h
0x000424e9      406e           bra @@0x6e:8
0x000424eb      227a           mov.b @0x7a:8,r2h
0x000424ed      0000           nop
0x000424ef      0000           nop
0x000424f1      280a           mov.b @0xa:8,r0l
0x000424f3      f05e           mov.b #0x5e:8,r0h
0x000424f5      0164fe01       sleep
0x000424f9      006f           nop
0x000424fb      7100           bnot #0x0:3,r0h
0x000424fd      3c10           mov.b r4l,@0x10:8
0x000424ff      3110           mov.b r1h,@0x10:8
0x00042501      3110           mov.b r1h,@0x10:8
0x00042503      317a           mov.b r1h,@0x7a:8
0x00042505      1100           shlr r0h
0x00042507      4010           bra @@0x10:8
0x00042509      267a           mov.b @0x7a:8,r6h
0x0004250b      0200           stc ccr,r0h
0x0004250d      406e           bra @@0x6e:8
0x0004250f      6201           bclr r0h,r1h
0x00042511      006f           nop
0x00042513      f000           mov.b #0x0:8,r0h
0x00042515      1c7a           cmp.b r7h,r2l
0x00042517      0000           nop
0x00042519      0000           nop
0x0004251b      200a           mov.b @0xa:8,r0h
0x0004251d      f05e           mov.b #0x5e:8,r0h
0x0004251f      0160300f       sleep
0x00042523      8101           add.b #0x1:8,r1h
0x00042525      006f           nop
0x00042527      7000           bset #0x0:3,r0h
0x00042529      1c5e           cmp.b r5h,r6l
0x0004252b      015f140d       sleep
0x0004252f      0046           nop
0x00042531      045a           orc #0x5a:8,ccr
0x00042533      0425           orc #0x25:8,ccr
0x00042535      960c           addx #0xc:8,r6h
0x00042537      e817           and #0x17:8,r0l
0x00042539      5017           mulxu r1h,r7
0x0004253b      7001           bset #0x0:3,r1h
0x0004253d      006f           nop
0x0004253f      f000           mov.b #0x0:8,r0h
0x00042541      3c10           mov.b r4l,@0x10:8
0x00042543      3001           mov.b r0h,@0x1:8
0x00042545      006f           nop
0x00042547      7100           bnot #0x0:3,r0h
0x00042549      3c10           mov.b r4l,@0x10:8
0x0004254b      3110           mov.b r1h,@0x10:8
0x0004254d      3110           mov.b r1h,@0x10:8
0x0004254f      3101           mov.b r1h,@0x1:8
0x00042551      006f           nop
0x00042553      f000           mov.b #0x0:8,r0h
0x00042555      2c7a           mov.b @0x7a:8,r4l
0x00042557      0000           nop
0x00042559      4010           bra @@0x10:8
0x0004255b      260a           mov.b @0xa:8,r6h
0x0004255d      905e           addx #0x5e:8,r0h
0x0004255f      015d2e0d       sleep
0x00042563      017a0000       sleep
0x00042567      0000           nop
0x00042569      240a           mov.b @0xa:8,r4h
0x0004256b      f05e           mov.b #0x5e:8,r0h
0x0004256d      0164fe0f       sleep
0x00042571      817a           add.b #0x7a:8,r1h
0x00042573      0200           stc ccr,r0h
0x00042575      406e           bra @@0x6e:8
0x00042577      627a           bclr r7h,r2l
0x00042579      0000           nop
0x0004257b      0000           nop
0x0004257d      1c0a           cmp.b r0h,r2l
0x0004257f      f05e           mov.b #0x5e:8,r0h
0x00042581      0160305e       sleep
0x00042585      015d2e01       sleep
0x00042589      006f           nop
0x0004258b      7100           bnot #0x0:3,r0h
0x0004258d      2c78           mov.b @0x78:8,r4l
0x0004258f      106b           shal r3l
0x00042591      a000           cmp.b #0x0:8,r0h
0x00042593      406e           bra @@0x6e:8
0x00042595      226a           mov.b @0x6a:8,r2h
0x00042597      2800           mov.b @0x0:8,r0l
0x00042599      4010           bra @@0x10:8
0x0004259b      76a8           biand #0x2:3,r0l
0x0004259d      0146045a       sleep
0x000425a1      0426           orc #0x26:8,ccr
0x000425a3      64             invalid
0x000425a4      0ce9           mov.b r6l,r1l
0x000425a6      1751           neg r1h
0x000425a8      1771           neg r1h
0x000425aa      01006ff1       sleep
0x000425ae      003c           nop
0x000425b0      1031           shal r1h
0x000425b2      78             invalid
0x000425b3      106b           shal r3l
0x000425b5      2100           mov.b @0x0:8,r1h
0x000425b7      406e           bra @@0x6e:8
0x000425b9      2a7a           mov.b @0x7a:8,r2l
0x000425bb      0000           nop
0x000425bd      0000           nop
0x000425bf      280a           mov.b @0xa:8,r0l
0x000425c1      f05e           mov.b #0x5e:8,r0h
0x000425c3      0164fe01       sleep
0x000425c7      006f           nop
0x000425c9      7100           bnot #0x0:3,r0h
0x000425cb      3c10           mov.b r4l,@0x10:8
0x000425cd      3110           mov.b r1h,@0x10:8
0x000425cf      3110           mov.b r1h,@0x10:8
0x000425d1      317a           mov.b r1h,@0x7a:8
0x000425d3      1100           shlr r0h
0x000425d5      4010           bra @@0x10:8
0x000425d7      467a           bne @@0x7a:8
0x000425d9      0200           stc ccr,r0h
0x000425db      406e           bra @@0x6e:8
0x000425dd      6201           bclr r0h,r1h
0x000425df      006f           nop
0x000425e1      f000           mov.b #0x0:8,r0h
0x000425e3      1c7a           cmp.b r7h,r2l
0x000425e5      0000           nop
0x000425e7      0000           nop
0x000425e9      200a           mov.b @0xa:8,r0h
0x000425eb      f05e           mov.b #0x5e:8,r0h
0x000425ed      0160300f       sleep
0x000425f1      8101           add.b #0x1:8,r1h
0x000425f3      006f           nop
0x000425f5      7000           bset #0x0:3,r0h
0x000425f7      1c5e           cmp.b r5h,r6l
0x000425f9      015e9e0d       sleep
0x000425fd      0046           nop
0x000425ff      045a           orc #0x5a:8,ccr
0x00042601      0426           orc #0x26:8,ccr
0x00042603      64             invalid
0x00042604      0ce8           mov.b r6l,r0l
0x00042606      1750           neg r0h
0x00042608      1770           neg r0h
0x0004260a      01006ff0       sleep
0x0004260e      003c           nop
0x00042610      10             shal r0h
0x00042612      01006f71       sleep
0x00042616      003c           nop
0x00042618      1031           shal r1h
0x0004261a      1031           shal r1h
0x0004261c      1031           shal r1h
0x0004261e      01006ff0       sleep
0x00042622      002c           nop
0x00042624      7a             invalid
0x00042625      0000           nop
0x00042627      4010           bra @@0x10:8
0x00042629      460a           bne @@0xa:8
0x0004262b      905e           addx #0x5e:8,r0h
0x0004262d      015d2e0d       sleep
0x00042631      017a0000       sleep
0x00042635      0000           nop
0x00042637      240a           mov.b @0xa:8,r4h
0x00042639      f05e           mov.b #0x5e:8,r0h
0x0004263b      0164fe0f       sleep
0x0004263f      817a           add.b #0x7a:8,r1h
0x00042641      0200           stc ccr,r0h
0x00042643      406e           bra @@0x6e:8
0x00042645      627a           bclr r7h,r2l
0x00042647      0000           nop
0x00042649      0000           nop
0x0004264b      1c0a           cmp.b r0h,r2l
0x0004264d      f05e           mov.b #0x5e:8,r0h
0x0004264f      0160305e       sleep
0x00042653      015d2e01       sleep
0x00042657      006f           nop
0x00042659      7100           bnot #0x0:3,r0h
0x0004265b      2c78           mov.b @0x78:8,r4l
0x0004265d      106b           shal r3l
0x0004265f      a000           cmp.b #0x0:8,r0h
0x00042661      406e           bra @@0x6e:8
0x00042663      2a0c           mov.b @0xc:8,r2l
0x00042665      e917           and #0x17:8,r1l
0x00042667      5117           divxu r1h,r7
0x00042669      7101           bnot #0x0:3,r1h
0x0004266b      006f           nop
0x0004266d      f100           mov.b #0x0:8,r1h
0x0004266f      3c01           mov.b r4l,@0x1:8
0x00042671      006f           nop
0x00042673      f100           mov.b #0x0:8,r1h
0x00042675      2c01           mov.b @0x1:8,r4l
0x00042677      006f           nop
0x00042679      7000           bset #0x0:3,r0h
0x0004267b      2c78           mov.b @0x78:8,r4l
0x0004267d      006a           nop
0x0004267f      2900           mov.b @0x0:8,r1l
0x00042681      400f           bra @@0xf:8
0x00042683      6117           bnot r1h,r7h
0x00042685      517a           divxu r7h,r2
0x00042687      0000           nop
0x00042689      0000           nop
0x0004268b      240a           mov.b @0xa:8,r4h
0x0004268d      f05e           mov.b #0x5e:8,r0h
0x0004268f      0164fe0f       sleep
0x00042693      817a           add.b #0x7a:8,r1h
0x00042695      0200           stc ccr,r0h
0x00042697      04a5           orc #0xa5:8,ccr
0x00042699      107a           shal r2l
0x0004269b      0000           nop
0x0004269d      0000           nop
0x0004269f      1c0a           cmp.b r0h,r2l
0x000426a1      f05e           mov.b #0x5e:8,r0h
0x000426a3      0160300f       sleep
0x000426a7      817a           add.b #0x7a:8,r1h
0x000426a9      0200           stc ccr,r0h
0x000426ab      04a5           orc #0xa5:8,ccr
0x000426ad      187a           sub.b r7h,r2l
0x000426af      0000           nop
0x000426b1      0000           nop
0x000426b3      140a           or r0h,r2l
0x000426b5      f05e           mov.b #0x5e:8,r0h
0x000426b7      0159a401       sleep
0x000426bb      006f           nop
0x000426bd      7100           bnot #0x0:3,r0h
0x000426bf      3c10           mov.b r4l,@0x10:8
0x000426c1      3178           mov.b r1h,@0x78:8
0x000426c3      106b           shal r3l
0x000426c5      2100           mov.b @0x0:8,r1h
0x000426c7      406e           bra @@0x6e:8
0x000426c9      2201           mov.b @0x1:8,r2h
0x000426cb      006f           nop
0x000426cd      f000           mov.b #0x0:8,r0h
0x000426cf      087a           add.b r7h,r2l
0x000426d1      0000           nop
0x000426d3      0000           nop
0x000426d5      0c0a           mov.b r0h,r2l
0x000426d7      f05e           mov.b #0x5e:8,r0h
0x000426d9      0164fe01       sleep
0x000426dd      006f           nop
0x000426df      7100           bnot #0x0:3,r0h
0x000426e1      080f           add.b r0h,r7l
0x000426e3      820f           add.b #0xf:8,r2h
0x000426e5      f05e           mov.b #0x5e:8,r0h
0x000426e7      0159a47a       sleep
0x000426eb      0100406e       sleep
0x000426ef      3a5e           mov.b r2l,@0x5e:8
0x000426f1      01640a01       sleep
0x000426f5      006f           nop
0x000426f7      7100           bnot #0x0:3,r0h
0x000426f9      3c10           mov.b r4l,@0x10:8
0x000426fb      3110           mov.b r1h,@0x10:8
0x000426fd      3110           mov.b r1h,@0x10:8
0x000426ff      310a           mov.b r1h,@0xa:8
0x00042701      d17a           xor #0x7a:8,r1h
0x00042703      0000           nop
0x00042705      406e           bra @@0x6e:8
0x00042707      3a5e           mov.b r2l,@0x5e:8
0x00042709      015e9e0d       sleep
0x0004270d      0046           nop
0x0004270f      045a           orc #0x5a:8,ccr
0x00042711      04             orc #0x10:8,ccr
0x00042713      2c0c           mov.b @0xc:8,r4l
0x00042715      e817           and #0x17:8,r0l
0x00042717      5017           mulxu r1h,r7
0x00042719      7010           bset #0x1:3,r0h
0x0004271b      3010           mov.b r0h,@0x10:8
0x0004271d      3010           mov.b r0h,@0x10:8
0x0004271f      300a           mov.b r0h,@0xa:8
0x00042721      d07a           xor #0x7a:8,r0h
0x00042723      0100406e       sleep
0x00042727      3a5e           mov.b r2l,@0x5e:8
0x00042729      01640a1a       sleep
0x0004272d      8068           add.b #0x68:8,r0h
0x0004272f      4810           bvc @@0x10:8
0x00042731      3010           mov.b r0h,@0x10:8
0x00042733      3010           mov.b r0h,@0x10:8
0x00042735      3010           mov.b r0h,@0x10:8
0x00042737      3001           mov.b r0h,@0x1:8
0x00042739      006f           nop
0x0004273b      f000           mov.b #0x0:8,r0h
0x0004273d      380c           mov.b r0l,@0xc:8
0x0004273f      e917           and #0x17:8,r1l
0x00042741      5117           divxu r1h,r7
0x00042743      7110           bnot #0x1:3,r0h
0x00042745      3110           mov.b r1h,@0x10:8
0x00042747      3101           mov.b r1h,@0x1:8
0x00042749      006f           nop
0x0004274b      f100           mov.b #0x0:8,r1h
0x0004274d      3c7a           mov.b r4l,@0x7a:8
0x0004274f      1000           shll r0h
0x00042751      400f           bra @@0xf:8
0x00042753      ae0a           cmp.b #0xa:8,r6l
0x00042755      900a           addx #0xa:8,r0h
0x00042757      b101           subx #0x1:8,r1h
0x00042759      0069           nop
0x0004275b      1101           shlr r1h
0x0004275d      006f           nop
0x0004275f      f000           mov.b #0x0:8,r0h
0x00042761      247a           mov.b @0x7a:8,r4h
0x00042763      0000           nop
0x00042765      0000           nop
0x00042767      280a           mov.b @0xa:8,r0l
0x00042769      f05e           mov.b #0x5e:8,r0h
0x0004276b      0164800f       sleep
0x0004276f      817a           add.b #0x7a:8,r1h
0x00042771      0200           stc ccr,r0h
0x00042773      406e           bra @@0x6e:8
0x00042775      3a7a           mov.b r2l,@0x7a:8
0x00042777      0000           nop
0x00042779      0000           nop
0x0004277b      1c0a           cmp.b r0h,r2l
0x0004277d      f05e           mov.b #0x5e:8,r0h
0x0004277f      0160305e       sleep
0x00042783      015d2e01       sleep
0x00042787      006f           nop
0x00042789      7100           bnot #0x0:3,r0h
0x0004278b      3c01           mov.b r4l,@0x1:8
0x0004278d      0078           nop
0x0004278f      106b           shal r3l
0x00042791      2100           mov.b @0x0:8,r1h
0x00042793      4010           bra @@0x10:8
0x00042795      880a           add.b #0xa:8,r0l
0x00042797      9001           addx #0x1:8,r0h
0x00042799      006f           nop
0x0004279b      7100           bnot #0x0:3,r0h
0x0004279d      387a           mov.b r0l,@0x7a:8
0x0004279f      1100           shlr r0h
0x000427a1      400f           bra @@0xf:8
0x000427a3      ee01           and #0x1:8,r6l
0x000427a5      006f           nop
0x000427a7      7200           bclr #0x0:3,r0h
0x000427a9      3c0a           mov.b r4l,@0xa:8
0x000427ab      a101           cmp.b #0x1:8,r1h
0x000427ad      0069           nop
0x000427af      9001           addx #0x1:8,r0h
0x000427b1      006f           nop
0x000427b3      7100           bnot #0x0:3,r0h
0x000427b5      2401           mov.b @0x1:8,r4h
0x000427b7      0069           nop
0x000427b9      901a           addx #0x1a:8,r0h
0x000427bb      8068           add.b #0x68:8,r0h
0x000427bd      4810           bvc @@0x10:8
0x000427bf      3010           mov.b r0h,@0x10:8
0x000427c1      3010           mov.b r0h,@0x10:8
0x000427c3      3010           mov.b r0h,@0x10:8
0x000427c5      307a           mov.b r0h,@0x7a:8
0x000427c7      1000           shll r0h
0x000427c9      400f           bra @@0xf:8
0x000427cb      ae01           cmp.b #0x1:8,r6l
0x000427cd      006f           nop
0x000427cf      7100           bnot #0x0:3,r0h
0x000427d1      3c0a           mov.b r4l,@0xa:8
0x000427d3      9001           addx #0x1:8,r0h
0x000427d5      0069           nop
0x000427d7      007a           nop
0x000427d9      2003           mov.b @0x3:8,r0h
0x000427db      ffff           mov.b #0xff:8,r7l
0x000427dd      ff42           mov.b #0x42:8,r7l
0x000427df      045a           orc #0x5a:8,ccr
0x000427e1      0428           orc #0x28:8,ccr
0x000427e3      241a           mov.b @0x1a:8,r4h
0x000427e5      8068           add.b #0x68:8,r0h
0x000427e7      4810           bvc @@0x10:8
0x000427e9      3010           mov.b r0h,@0x10:8
0x000427eb      3010           mov.b r0h,@0x10:8
0x000427ed      3010           mov.b r0h,@0x10:8
0x000427ef      3001           mov.b r0h,@0x1:8
0x000427f1      006f           nop
0x000427f3      f000           mov.b #0x0:8,r0h
0x000427f5      380c           mov.b r0l,@0xc:8
0x000427f7      e917           and #0x17:8,r1l
0x000427f9      5117           divxu r1h,r7
0x000427fb      7110           bnot #0x1:3,r0h
0x000427fd      3110           mov.b r1h,@0x10:8
0x000427ff      317a           mov.b r1h,@0x7a:8
0x00042801      1000           shll r0h
0x00042803      400f           bra @@0xf:8
0x00042805      ae0a           cmp.b #0xa:8,r6l
0x00042807      9001           addx #0x1:8,r0h
0x00042809      006f           nop
0x0004280b      7200           bclr #0x0:3,r0h
0x0004280d      387a           mov.b r0l,@0x7a:8
0x0004280f      1200           rotxl r0h
0x00042811      400f           bra @@0xf:8
0x00042813      ee0a           and #0xa:8,r6l
0x00042815      927a           addx #0x7a:8,r2h
0x00042817      0103ffff       sleep
0x0004281b      ff01           mov.b #0x1:8,r7l
0x0004281d      0069           nop
0x0004281f      a101           cmp.b #0x1:8,r1h
0x00042821      0069           nop
0x00042823      810c           add.b #0xc:8,r1h
0x00042825      e817           and #0x17:8,r0l
0x00042827      5017           mulxu r1h,r7
0x00042829      7010           bset #0x1:3,r0h
0x0004282b      3001           mov.b r0h,@0x1:8
0x0004282d      006f           nop
0x0004282f      f000           mov.b #0x0:8,r0h
0x00042831      3c01           mov.b r4l,@0x1:8
0x00042833      006f           nop
0x00042835      7100           bnot #0x0:3,r0h
0x00042837      3c78           mov.b r4l,@0x78:8
0x00042839      106b           shal r3l
0x0004283b      2100           mov.b @0x0:8,r1h
0x0004283d      406e           bra @@0x6e:8
0x0004283f      1a01           dec r1h
0x00042841      006f           nop
0x00042843      f000           mov.b #0x0:8,r0h
0x00042845      247a           mov.b @0x7a:8,r4h
0x00042847      0000           nop
0x00042849      0000           nop
0x0004284b      280a           mov.b @0xa:8,r0l
0x0004284d      f05e           mov.b #0x5e:8,r0h
0x0004284f      0164fe0f       sleep
0x00042853      817a           add.b #0x7a:8,r1h
0x00042855      0200           stc ccr,r0h
0x00042857      406e           bra @@0x6e:8
0x00042859      3a7a           mov.b r2l,@0x7a:8
0x0004285b      0000           nop
0x0004285d      0000           nop
0x0004285f      1c0a           cmp.b r0h,r2l
0x00042861      f05e           mov.b #0x5e:8,r0h
0x00042863      0160305e       sleep
0x00042867      015d2e01       sleep
0x0004286b      006f           nop
0x0004286d      7100           bnot #0x0:3,r0h
0x0004286f      2478           mov.b @0x78:8,r4h
0x00042871      106b           shal r3l
0x00042873      a000           cmp.b #0x0:8,r0h
0x00042875      4010           bra @@0x10:8
0x00042877      0e6a           addx r6h,r2l
0x00042879      2800           mov.b @0x0:8,r0l
0x0004287b      4010           bra @@0x10:8
0x0004287d      66             invalid
0x0004287e      a801           cmp.b #0x1:8,r0l
0x00042880      4704           beq @@0x4:8
0x00042882      5a0428d8       jmp @0x28d8:16
0x00042886      1a80           dec r0h
0x00042888      0ce8           mov.b r6l,r0l
0x0004288a      1030           shal r0h
0x0004288c      01006ff0       sleep
0x00042890      003c           nop
0x00042892      01006f71       sleep
0x00042896      003c           nop
0x00042898      78             invalid
0x00042899      106b           shal r3l
0x0004289b      2100           mov.b @0x0:8,r1h
0x0004289d      406e           bra @@0x6e:8
0x0004289f      2a01           mov.b @0x1:8,r2l
0x000428a1      006f           nop
0x000428a3      f000           mov.b #0x0:8,r0h
0x000428a5      247a           mov.b @0x7a:8,r4h
0x000428a7      0000           nop
0x000428a9      0000           nop
0x000428ab      280a           mov.b @0xa:8,r0l
0x000428ad      f05e           mov.b #0x5e:8,r0h
0x000428af      0164fe0f       sleep
0x000428b3      817a           add.b #0x7a:8,r1h
0x000428b5      0200           stc ccr,r0h
0x000428b7      406e           bra @@0x6e:8
0x000428b9      3a7a           mov.b r2l,@0x7a:8
0x000428bb      0000           nop
0x000428bd      0000           nop
0x000428bf      1c0a           cmp.b r0h,r2l
0x000428c1      f05e           mov.b #0x5e:8,r0h
0x000428c3      0160305e       sleep
0x000428c7      015d2e01       sleep
0x000428cb      006f           nop
0x000428cd      7100           bnot #0x0:3,r0h
0x000428cf      2478           mov.b @0x78:8,r4h
0x000428d1      106b           shal r3l
0x000428d3      a000           cmp.b #0x0:8,r0h
0x000428d5      4010           bra @@0x10:8
0x000428d7      160a           and r0h,r2l
0x000428d9      066a           andc #0x6a:8,ccr
0x000428db      2800           mov.b @0x0:8,r0l
0x000428dd      406e           bra @@0x6e:8
0x000428df      351c           mov.b r5h,@0x1c:8
0x000428e1      8644           add.b #0x44:8,r6h
0x000428e3      045a           orc #0x5a:8,ccr
0x000428e5      0424           orc #0x24:8,ccr
0x000428e7      5018           mulxu r1h,r0
0x000428e9      ee0c           and #0xc:8,r6l
0x000428eb      e817           and #0x17:8,r0l
0x000428ed      5017           mulxu r1h,r7
0x000428ef      7010           bset #0x1:3,r0h
0x000428f1      3078           mov.b r0h,@0x78:8
0x000428f3      006b           nop
0x000428f5      2000           mov.b @0x0:8,r0h
0x000428f7      4010           bra @@0x10:8
0x000428f9      0e79           addx r7h,r1l
0x000428fb      203f           mov.b @0x3f:8,r0h
0x000428fd      ff42           mov.b #0x42:8,r7l
0x000428ff      045a           orc #0x5a:8,ccr
0x00042901      0429           orc #0x29:8,ccr
0x00042903      180c           sub.b r0h,r4l
0x00042905      e817           and #0x17:8,r0l
0x00042907      5017           mulxu r1h,r7
0x00042909      7010           bset #0x1:3,r0h
0x0004290b      3079           mov.b r0h,@0x79:8
0x0004290d      013fff78       sleep
0x00042911      006b           nop
0x00042913      a100           cmp.b #0x0:8,r1h
0x00042915      4010           bra @@0x10:8
0x00042917      0e0a           addx r0h,r2l
0x00042919      0eae           addx r2l,r6l
0x0004291b      0444           orc #0x44:8,ccr
0x0004291d      045a           orc #0x5a:8,ccr
0x0004291f      0428           orc #0x28:8,ccr
0x00042921      ea7a           and #0x7a:8,r2l
0x00042923      1700           not r0h
0x00042925      0000           nop
0x00042927      405e           bra @@0x5e:8
0x00042929      01643654       sleep
0x0004292d      705e           bset #0x5:3,r6l
0x0004292f      0164587a       sleep
0x00042933      3700           mov.b r7h,@0x0:8
0x00042935      0000           nop
0x00042937      287a           mov.b @0x7a:8,r0l
0x00042939      0400           orc #0x0:8,ccr
0x0004293b      4009           bra @@0x9:8
0x0004293d      c27a           or #0x7a:8,r2h
0x0004293f      0500           xorc #0x0:8,ccr
0x00042941      400f           bra @@0xf:8
0x00042943      557a           bsr .122
0x00042945      0600           andc #0x0:8,ccr
0x00042947      0000           nop
0x00042949      040a           orc #0xa:8,ccr
0x0004294b      f618           mov.b #0x18:8,r6h
0x0004294d      886a           add.b #0x6a:8,r0l
0x0004294f      a800           cmp.b #0x0:8,r0l
0x00042951      404e           bra @@0x4e:8
0x00042953      966a           addx #0x6a:8,r6h
0x00042955      2800           mov.b @0x0:8,r0l
0x00042957      400d           bra @@0xd:8
0x00042959      3c68           mov.b r4l,@0x68:8
0x0004295b      d818           xor #0x18:8,r0l
0x0004295d      bb40           subx #0x40:8,r3l
0x0004295f      460c           bne @@0xc:8
0x00042961      b817           subx #0x17:8,r0l
0x00042963      5017           mulxu r1h,r7
0x00042965      700f           bset #0x0:3,r7l
0x00042967      820a           add.b #0xa:8,r2h
0x00042969      e00f           and #0xf:8,r0h
0x0004296b      a178           cmp.b #0x78:8,r1h
0x0004296d      106a           shal r2l
0x0004296f      2900           mov.b @0x0:8,r1l
0x00042971      400d           bra @@0xd:8
0x00042973      3d68           mov.b r5l,@0x68:8
0x00042975      8968           add.b #0x68:8,r1l
0x00042977      08a8           add.b r2l,r0l
0x00042979      0946           add.w r4,r6
0x0004297b      0e0c           addx r0h,r4l
0x0004297d      b817           subx #0x17:8,r0l
0x0004297f      5017           mulxu r1h,r7
0x00042981      700a           bset #0x0:3,r2l
0x00042983      e0f9           and #0xf9:8,r0h
0x00042985      0468           orc #0x68:8,ccr
0x00042987      8940           add.b #0x40:8,r1l
0x00042989      1a0c           dec r4l
0x0004298b      b817           subx #0x17:8,r0l
0x0004298d      5017           mulxu r1h,r7
0x0004298f      700a           bset #0x0:3,r2l
0x00042991      e068           and #0x68:8,r0h
0x00042993      08a8           add.b r2l,r0l
0x00042995      0446           orc #0x46:8,ccr
0x00042997      0c0c           mov.b r0h,r4l
0x00042999      b817           subx #0x17:8,r0l
0x0004299b      5017           mulxu r1h,r7
0x0004299d      700a           bset #0x0:3,r2l
0x0004299f      e0f9           and #0xf9:8,r0h
0x000429a1      0568           xorc #0x68:8,ccr
0x000429a3      890a           add.b #0xa:8,r1l
0x000429a5      0b68           adds #1,r0
0x000429a7      58             invalid
0x000429a8      1c8b           cmp.b r0l,r3l
0x000429aa      45b4           bcs @@0xb4:8
0x000429ac      686b           mov.b @r6,r3l
0x000429ae      1753           neg r3h
0x000429b0      7900003a       mov.w #0x3a:16,r0
0x000429b4      52             invalid
0x000429b5      300a           mov.b r0h,@0xa:8
0x000429b7      c07a           or #0x7a:8,r0h
0x000429b9      1000           shll r0h
0x000429bb      0000           nop
0x000429bd      2868           mov.b @0x68:8,r0l
0x000429bf      08e8           add.b r6l,r0l
0x000429c1      0f0c           daa r4l
0x000429c3      8347           add.b #0x47:8,r3h
0x000429c5      4a1a           bpl @@0x1a:8
0x000429c7      800c           add.b #0xc:8,r0h
0x000429c9      3868           mov.b r0l,@0x68:8
0x000429cb      6978           mov.w @r7,r0
0x000429cd      006a           nop
0x000429cf      a900           cmp.b #0x0:8,r1l
0x000429d1      400f           bra @@0xf:8
0x000429d3      55f3           bsr .-13
0x000429d5      01402e0c       sleep
0x000429d9      3817           mov.b r0l,@0x17:8
0x000429db      5017           mulxu r1h,r7
0x000429dd      700a           bset #0x0:3,r2l
0x000429df      e068           and #0x68:8,r0h
0x000429e1      080c           add.b r0h,r4l
0x000429e3      8117           add.b #0x17:8,r1h
0x000429e5      5079           mulxu r7h,r1
0x000429e7      0800           add.b r0h,r0h
0x000429e9      3a52           mov.b r2l,@0x52:8
0x000429eb      800a           add.b #0xa:8,r0h
0x000429ed      c07a           or #0x7a:8,r0h
0x000429ef      1000           shll r0h
0x000429f1      0000           nop
0x000429f3      2868           mov.b @0x68:8,r0l
0x000429f5      08e8           add.b r6l,r0l
0x000429f7      0f17           daa r7h
0x000429f9      5017           mulxu r1h,r7
0x000429fb      7078           bset #0x7:3,r0l
0x000429fd      006a           nop
0x000429ff      a100           cmp.b #0x0:8,r1h
0x00042a01      400f           bra @@0xf:8
0x00042a03      550a           bsr .10
0x00042a05      0368           ldc r0l,ccr
0x00042a07      58             invalid
0x00042a08      1c83           cmp.b r0l,r3h
0x00042a0a      45cc           bcs @@0xcc:8
0x00042a0c      5a042b62       jmp @0x2b62:16
0x00042a10      1888           sub.b r0l,r0l
0x00042a12      6e             mov.b @(0x100:16,r1),r0h
0x00042a16      1833           sub.b r3h,r3h
0x00042a18      0c38           mov.b r3h,r0l
0x00042a1a      1750           neg r0h
0x00042a1c      1770           neg r0h
0x00042a1e      7a             invalid
0x00042a1f      01000000       sleep
0x00042a23      080a           add.b r0h,r2l
0x00042a25      f10a           mov.b #0xa:8,r1h
0x00042a27      8118           add.b #0x18:8,r1h
0x00042a29      8868           add.b #0x68:8,r0l
0x00042a2b      980a           addx #0xa:8,r0l
0x00042a2d      03a3           ldc r3h,ccr
0x00042a2f      0543           xorc #0x43:8,ccr
0x00042a31      e61a           and #0x1a:8,r6h
0x00042a33      8068           add.b #0x68:8,r0h
0x00042a35      687a           mov.b @r7,r2l
0x00042a37      01000000       sleep
0x00042a3b      080a           add.b r0h,r2l
0x00042a3d      f10a           mov.b #0xa:8,r1h
0x00042a3f      81f8           add.b #0xf8:8,r1h
0x00042a41      016898f3       sleep
0x00042a45      01401c0c       sleep
0x00042a49      3817           mov.b r0l,@0x17:8
0x00042a4b      5017           mulxu r1h,r7
0x00042a4d      700a           bset #0x0:3,r2l
0x00042a4f      e01a           and #0x1a:8,r0h
0x00042a51      9168           addx #0x68:8,r1h
0x00042a53      097a           add.w r7,r2
0x00042a55      0000           nop
0x00042a57      0000           nop
0x00042a59      080a           add.b r0h,r2l
0x00042a5b      f00a           mov.b #0xa:8,r0h
0x00042a5d      90f9           addx #0xf9:8,r0h
0x00042a5f      0168890a       sleep
0x00042a63      0368           ldc r0l,ccr
0x00042a65      58             invalid
0x00042a66      1c83           cmp.b r0l,r3h
0x00042a68      45de           bcs @@0xde:8
0x00042a6a      1753           neg r3h
0x00042a6c      7900003a       mov.w #0x3a:16,r0
0x00042a70      52             invalid
0x00042a71      300a           mov.b r0h,@0xa:8
0x00042a73      c07a           or #0x7a:8,r0h
0x00042a75      1000           shll r0h
0x00042a77      0000           nop
0x00042a79      2968           mov.b @0x68:8,r1l
0x00042a7b      030c           ldc r4l,ccr
0x00042a7d      38e8           mov.b r0l,@0xe8:8
0x00042a7f      010c8346       sleep
0x00042a83      7018           bset #0x1:3,r0l
0x00042a85      3368           mov.b r3h,@0x68:8
0x00042a87      58             invalid
0x00042a88      1750           neg r0h
0x00042a8a      79080006       mov.w #0x6:16,r0
0x00042a8e      52             invalid
0x00042a8f      800c           add.b #0xc:8,r0h
0x00042a91      3917           mov.b r1l,@0x17:8
0x00042a93      5117           divxu r1h,r7
0x00042a95      717a           bnot #0x7:3,r2l
0x00042a97      1000           shll r0h
0x00042a99      04a5           orc #0xa5:8,ccr
0x00042a9b      200a           mov.b @0xa:8,r0h
0x00042a9d      901b           addx #0x1b:8,r0h
0x00042a9f      901b           addx #0x1b:8,r0h
0x00042aa1      f01a           mov.b #0x1a:8,r0h
0x00042aa3      9168           addx #0x68:8,r1h
0x00042aa5      097a           add.w r7,r2
0x00042aa7      0000           nop
0x00042aa9      0000           nop
0x00042aab      080a           add.b r0h,r2l
0x00042aad      f00a           mov.b #0xa:8,r0h
0x00042aaf      9068           addx #0x68:8,r0h
0x00042ab1      08a8           add.b r2l,r0l
0x00042ab3      0146366e       sleep
0x00042ab7      78             invalid
0x00042ab8      0017           nop
0x00042aba      0a08           inc r0l
0x00042abc      6ef80017       mov.b r0l,@(0x17:16,r7)
0x00042ac0      1a08           dec r0l
0x00042ac2      1750           neg r0h
0x00042ac4      1770           neg r0h
0x00042ac6      6859           mov.b @r5,r1l
0x00042ac8      1751           neg r1h
0x00042aca      79090006       mov.w #0x6:16,r1
0x00042ace      52             invalid
0x00042acf      910c           addx #0xc:8,r1h
0x00042ad1      3a17           mov.b r2l,@0x17:8
0x00042ad3      52             invalid
0x00042ad4      1772           neg r2h
0x00042ad6      7a             invalid
0x00042ad7      1100           shlr r0h
0x00042ad9      04a5           orc #0xa5:8,ccr
0x00042adb      200a           mov.b @0xa:8,r0h
0x00042add      a11b           cmp.b #0x1b:8,r1h
0x00042adf      911b           addx #0x1b:8,r1h
0x00042ae1      f168           mov.b #0x68:8,r1h
0x00042ae3      1978           sub.w r7,r0
0x00042ae5      006a           nop
0x00042ae7      a900           cmp.b #0x0:8,r1l
0x00042ae9      400f           bra @@0xf:8
0x00042aeb      560a           rte
0x00042aed      03a3           ldc r3h,ccr
0x00042aef      0543           xorc #0x43:8,ccr
0x00042af1      9440           addx #0x40:8,r4h
0x00042af3      6e183368       mov.b @(0x3368:16,r1),r0l
0x00042af7      58             invalid
0x00042af8      1750           neg r0h
0x00042afa      79080006       mov.w #0x6:16,r0
0x00042afe      52             invalid
0x00042aff      800c           add.b #0xc:8,r0h
0x00042b01      3917           mov.b r1l,@0x17:8
0x00042b03      5117           divxu r1h,r7
0x00042b05      717a           bnot #0x7:3,r2l
0x00042b07      1000           shll r0h
0x00042b09      04a5           orc #0xa5:8,ccr
0x00042b0b      380a           mov.b r0l,@0xa:8
0x00042b0d      901b           addx #0x1b:8,r0h
0x00042b0f      901b           addx #0x1b:8,r0h
0x00042b11      f01a           mov.b #0x1a:8,r0h
0x00042b13      9168           addx #0x68:8,r1h
0x00042b15      09             add.w r1,r0
0x00042b17      0000           nop
0x00042b19      0000           nop
0x00042b1b      080a           add.b r0h,r2l
0x00042b1d      f00a           mov.b #0xa:8,r0h
0x00042b1f      9068           addx #0x68:8,r0h
0x00042b21      08a8           add.b r2l,r0l
0x00042b23      0146366e       sleep
0x00042b27      78             invalid
0x00042b28      0017           nop
0x00042b2a      0a08           inc r0l
0x00042b2c      6ef80017       mov.b r0l,@(0x17:16,r7)
0x00042b30      1a08           dec r0l
0x00042b32      1750           neg r0h
0x00042b34      1770           neg r0h
0x00042b36      6859           mov.b @r5,r1l
0x00042b38      1751           neg r1h
0x00042b3a      79090006       mov.w #0x6:16,r1
0x00042b3e      52             invalid
0x00042b3f      910c           addx #0xc:8,r1h
0x00042b41      3a17           mov.b r2l,@0x17:8
0x00042b43      52             invalid
0x00042b44      1772           neg r2h
0x00042b46      7a             invalid
0x00042b47      1100           shlr r0h
0x00042b49      04a5           orc #0xa5:8,ccr
0x00042b4b      380a           mov.b r0l,@0xa:8
0x00042b4d      a11b           cmp.b #0x1b:8,r1h
0x00042b4f      911b           addx #0x1b:8,r1h
0x00042b51      f168           mov.b #0x68:8,r1h
0x00042b53      1978           sub.w r7,r0
0x00042b55      006a           nop
0x00042b57      a900           cmp.b #0x0:8,r1l
0x00042b59      400f           bra @@0xf:8
0x00042b5b      560a           rte
0x00042b5d      03a3           ldc r3h,ccr
0x00042b5f      0543           xorc #0x43:8,ccr
0x00042b61      940c           addx #0xc:8,r4h
0x00042b63      b817           subx #0x17:8,r0l
0x00042b65      5079           mulxu r7h,r1
0x00042b67      0800           add.b r0h,r0h
0x00042b69      3a52           mov.b r2l,@0x52:8
0x00042b6b      800a           add.b #0xa:8,r0h
0x00042b6d      c07a           or #0x7a:8,r0h
0x00042b6f      1000           shll r0h
0x00042b71      0000           nop
0x00042b73      2a68           mov.b @0x68:8,r2l
0x00042b75      086a           add.b r6h,r2l
0x00042b77      a800           cmp.b #0x0:8,r0l
0x00042b79      400f           bra @@0xf:8
0x00042b7b      226a           mov.b @0x6a:8,r2h
0x00042b7d      2800           mov.b @0x0:8,r0l
0x00042b7f      4062           bra @@0x62:8
0x00042b81      f846           mov.b #0x46:8,r0l
0x00042b83      180c           sub.b r0h,r4l
0x00042b85      b817           subx #0x17:8,r0l
0x00042b87      5079           mulxu r7h,r1
0x00042b89      0800           add.b r0h,r0h
0x00042b8b      3a52           mov.b r2l,@0x52:8
0x00042b8d      800a           add.b #0xa:8,r0h
0x00042b8f      c07a           or #0x7a:8,r0h
0x00042b91      1000           shll r0h
0x00042b93      0000           nop
0x00042b95      3268           mov.b r2h,@0x68:8
0x00042b97      08e8           add.b r6l,r0l
0x00042b99      014002f8       sleep
0x00042b9d      016aa800       sleep
0x00042ba1      400f           bra @@0xf:8
0x00042ba3      6017           bset r1h,r7h
0x00042ba5      53             invalid
0x00042ba6      7900003a       mov.w #0x3a:16,r0
0x00042baa      52             invalid
0x00042bab      300a           mov.b r0h,@0xa:8
0x00042bad      c07a           or #0x7a:8,r0h
0x00042baf      1000           shll r0h
0x00042bb1      0000           nop
0x00042bb3      2968           mov.b @0x68:8,r1l
0x00042bb5      030c           ldc r4l,ccr
0x00042bb7      38e8           mov.b r0l,@0xe8:8
0x00042bb9      8012           add.b #0x12:8,r0h
0x00042bbb      88e8           add.b #0xe8:8,r0l
0x00042bbd      016aa800       sleep
0x00042bc1      400f           bra @@0xf:8
0x00042bc3      4c6a           bge @@0x6a:8
0x00042bc5      2800           mov.b @0x0:8,r0l
0x00042bc7      4062           bra @@0x62:8
0x00042bc9      f846           mov.b #0x46:8,r0l
0x00042bcb      0ae3           inc r3h
0x00042bcd      016aa300       sleep
0x00042bd1      400f           bra @@0xf:8
0x00042bd3      5b40           jmp @@0x40:8
0x00042bd5      08f8           add.b r7l,r0l
0x00042bd7      016aa800       sleep
0x00042bdb      400f           bra @@0xf:8
0x00042bdd      5b0c           jmp @@0xc:8
0x00042bdf      b817           subx #0x17:8,r0l
0x00042be1      5079           mulxu r7h,r1
0x00042be3      0800           add.b r0h,r0h
0x00042be5      3a52           mov.b r2l,@0x52:8
0x00042be7      800a           add.b #0xa:8,r0h
0x00042be9      c00f           or #0xf:8,r0h
0x00042beb      826e           add.b #0x6e:8,r2h
0x00042bed      0800           add.b r0h,r0h
0x00042bef      2ce8           mov.b @0xe8:8,r4l
0x00042bf1      036a           ldc r2l,ccr
0x00042bf3      a800           cmp.b #0x0:8,r0l
0x00042bf5      400f           bra @@0xf:8
0x00042bf7      5a0fa07a       jmp @0xa07a:16
0x00042bfb      1000           shll r0h
0x00042bfd      0000           nop
0x00042bff      2b7c           mov.b @0x7c:8,r3l
0x00042c01      0073           nop
0x00042c03      4047           bra @@0x47:8
0x00042c05      1e0c           subx r0h,r4l
0x00042c07      b817           subx #0x17:8,r0l
0x00042c09      5079           mulxu r7h,r1
0x00042c0b      0800           add.b r0h,r0h
0x00042c0d      3a52           mov.b r2l,@0x52:8
0x00042c0f      800a           add.b #0xa:8,r0h
0x00042c11      c07a           or #0x7a:8,r0h
0x00042c13      1000           shll r0h
0x00042c15      0000           nop
0x00042c17      2868           mov.b @0x68:8,r0l
0x00042c19      08e8           add.b r6l,r0l
0x00042c1b      f0f9           mov.b #0xf9:8,r0h
0x00042c1d      1018           shal r0l
0x00042c1f      0051           nop
0x00042c21      9040           addx #0x40:8,r0h
0x00042c23      0218           stc ccr,r0l
0x00042c25      886a           add.b #0x6a:8,r0l
0x00042c27      a800           cmp.b #0x0:8,r0l
0x00042c29      400f           bra @@0xf:8
0x00042c2b      5c             invalid
0x00042c2c      0cb8           mov.b r3l,r0l
0x00042c2e      1750           neg r0h
0x00042c30      7908003a       mov.w #0x3a:16,r0
0x00042c34      52             invalid
0x00042c35      800a           add.b #0xa:8,r0h
0x00042c37      c07a           or #0x7a:8,r0h
0x00042c39      1000           shll r0h
0x00042c3b      0000           nop
0x00042c3d      2b0f           mov.b @0xf:8,r3l
0x00042c3f      8268           add.b #0x68:8,r2h
0x00042c41      08e8           add.b r6l,r0l
0x00042c43      4012           bra @@0x12:8
0x00042c45      8812           add.b #0x12:8,r0l
0x00042c47      88e8           add.b #0xe8:8,r0l
0x00042c49      036a           ldc r2l,ccr
0x00042c4b      a800           cmp.b #0x0:8,r0l
0x00042c4d      400f           bra @@0xf:8
0x00042c4f      5d0f           jsr @r0
0x00042c51      a068           cmp.b #0x68:8,r0h
0x00042c53      08e8           add.b r6l,r0l
0x00042c55      016aa800       sleep
0x00042c59      400f           bra @@0xf:8
0x00042c5b      5e0fa068       jsr @0xa068:16
0x00042c5f      08e8           add.b r6l,r0l
0x00042c61      0411           orc #0x11:8,ccr
0x00042c63      0811           add.b r1h,r1h
0x00042c65      086a           add.b r6h,r2l
0x00042c67      a800           cmp.b #0x0:8,r0l
0x00042c69      400f           bra @@0xf:8
0x00042c6b      5f7a           jsr @@0x7a:8
0x00042c6d      0300           ldc r0h,ccr
0x00042c6f      400b           bra @@0xb:8
0x00042c71      240f           mov.b @0xf:8,r4h
0x00042c73      a068           cmp.b #0x68:8,r0h
0x00042c75      08e8           add.b r6l,r0l
0x00042c77      1147           shar r7h
0x00042c79      146f           or r6h,r7l
0x00042c7b      3001           mov.b r0h,@0x1:8
0x00042c7d      b017           subx #0x17:8,r0h
0x00042c7f      7001           bset #0x0:3,r1h
0x00042c81      006b           nop
0x00042c83      a000           cmp.b #0x0:8,r0h
0x00042c85      400f           bra @@0xf:8
0x00042c87      906f           addx #0x6f:8,r0h
0x00042c89      3301           mov.b r3h,@0x1:8
0x00042c8b      b240           subx #0x40:8,r2h
0x00042c8d      126f           rotl r7l
0x00042c8f      3001           mov.b r0h,@0x1:8
0x00042c91      ac17           cmp.b #0x17:8,r4l
0x00042c93      7001           bset #0x0:3,r1h
0x00042c95      006b           nop
0x00042c97      a000           cmp.b #0x0:8,r0h
0x00042c99      400f           bra @@0xf:8
0x00042c9b      906f           addx #0x6f:8,r0h
0x00042c9d      3301           mov.b r3h,@0x1:8
0x00042c9f      ae17           cmp.b #0x17:8,r6l
0x00042ca1      7301           btst #0x0:3,r1h
0x00042ca3      006b           nop
0x00042ca5      a300           cmp.b #0x0:8,r3h
0x00042ca7      400f           bra @@0xf:8
0x00042ca9      9418           addx #0x18:8,r4h
0x00042cab      bb0f           subx #0xf:8,r3l
0x00042cad      c27a           or #0x7a:8,r2h
0x00042caf      0000           nop
0x00042cb1      0001           nop
0x00042cb3      220a           mov.b @0xa:8,r2h
0x00042cb5      c001           or #0x1:8,r0h
0x00042cb7      006f           nop
0x00042cb9      f000           mov.b #0x0:8,r0h
0x00042cbb      1cab           cmp.b r2l,r3l
0x00042cbd      0146586a       sleep
0x00042cc1      2800           mov.b @0x0:8,r0l
0x00042cc3      400d           bra @@0xd:8
0x00042cc5      43a8           bls @@0xa8:8
0x00042cc7      01464e0c       sleep
0x00042ccb      b817           subx #0x17:8,r0l
0x00042ccd      5017           mulxu r1h,r7
0x00042ccf      700f           bset #0x0:3,r7l
0x00042cd1      a16e           cmp.b #0x6e:8,r1h
0x00042cd3      1900           sub.w r0,r0
0x00042cd5      3378           mov.b r3h,@0x78:8
0x00042cd7      006a           nop
0x00042cd9      a900           cmp.b #0x0:8,r1l
0x00042cdb      400f           bra @@0xf:8
0x00042cdd      4d0f           blt @@0xf:8
0x00042cdf      a17a           cmp.b #0x7a:8,r1h
0x00042ce1      1100           shlr r0h
0x00042ce3      0000           nop
0x00042ce5      3468           mov.b r4h,@0x68:8
0x00042ce7      1978           sub.w r7,r0
0x00042ce9      006a           nop
0x00042ceb      a900           cmp.b #0x0:8,r1l
0x00042ced      400f           bra @@0xf:8
0x00042cef      510f           divxu r0h,r7
0x00042cf1      a17a           cmp.b #0x7a:8,r1h
0x00042cf3      1100           shlr r0h
0x00042cf5      0000           nop
0x00042cf7      2d68           mov.b @0x68:8,r5l
0x00042cf9      1978           sub.w r7,r0
0x00042cfb      006a           nop
0x00042cfd      a900           cmp.b #0x0:8,r1l
0x00042cff      400f           bra @@0xf:8
0x00042d01      610f           bnot r0h,r7l
0x00042d03      a17a           cmp.b #0x7a:8,r1h
0x00042d05      1100           shlr r0h
0x00042d07      0000           nop
0x00042d09      3968           mov.b r1l,@0x68:8
0x00042d0b      1978           sub.w r7,r0
0x00042d0d      006a           nop
0x00042d0f      a900           cmp.b #0x0:8,r1l
0x00042d11      400f           bra @@0xf:8
0x00042d13      65             invalid
0x00042d14      5a042e         jmp @0x2e10:16
0x00042d18      0cbb           mov.b r3l,r3l
0x00042d1a      4668           bne @@0x68:8
0x00042d1c      6a280040       mov.b @0x40:16,r0l
0x00042d20      0e7a           addx r7h,r2l
0x00042d22      a801           cmp.b #0x1:8,r0l
0x00042d24      465e           bne @@0x5e:8
0x00042d26      0cb8           mov.b r3l,r0l
0x00042d28      1750           neg r0h
0x00042d2a      1770           neg r0h
0x00042d2c      01006f71       sleep
0x00042d30      001c           nop
0x00042d32      6e190033       mov.b @(0x33:16,r1),r1l
0x00042d36      78             invalid
0x00042d37      006a           nop
0x00042d39      a900           cmp.b #0x0:8,r1l
0x00042d3b      400f           bra @@0xf:8
0x00042d3d      4d01           blt @@0x1:8
0x00042d3f      006f           nop
0x00042d41      7100           bnot #0x0:3,r0h
0x00042d43      1c7a           cmp.b r7h,r2l
0x00042d45      1100           shlr r0h
0x00042d47      0000           nop
0x00042d49      3468           mov.b r4h,@0x68:8
0x00042d4b      1978           sub.w r7,r0
0x00042d4d      006a           nop
0x00042d4f      a900           cmp.b #0x0:8,r1l
0x00042d51      400f           bra @@0xf:8
0x00042d53      5101           divxu r0h,r1
0x00042d55      006f           nop
0x00042d57      7100           bnot #0x0:3,r0h
0x00042d59      1c7a           cmp.b r7h,r2l
0x00042d5b      1100           shlr r0h
0x00042d5d      0000           nop
0x00042d5f      2d68           mov.b @0x68:8,r5l
0x00042d61      1978           sub.w r7,r0
0x00042d63      006a           nop
0x00042d65      a900           cmp.b #0x0:8,r1l
0x00042d67      400f           bra @@0xf:8
0x00042d69      6101           bnot r0h,r1h
0x00042d6b      006f           nop
0x00042d6d      7100           bnot #0x0:3,r0h
0x00042d6f      1c7a           cmp.b r7h,r2l
0x00042d71      1100           shlr r0h
0x00042d73      0000           nop
0x00042d75      3968           mov.b r1l,@0x68:8
0x00042d77      1978           sub.w r7,r0
0x00042d79      006a           nop
0x00042d7b      a900           cmp.b #0x0:8,r1l
0x00042d7d      400f           bra @@0xf:8
0x00042d7f      65             invalid
0x00042d80      5a042e16       jmp @0x2e16:16
0x00042d84      0cb8           mov.b r3l,r0l
0x00042d86      1750           neg r0h
0x00042d88      1770           neg r0h
0x00042d8a      01006ff0       sleep
0x00042d8e      0024           nop
0x00042d90      010069f0       sleep
0x00042d94      01006f70       sleep
0x00042d98      0024           nop
0x00042d9a      7a             invalid
0x00042d9b      01000000       sleep
0x00042d9f      3a5e           mov.b r2l,@0x5e:8
0x00042da1      0163ea0a       sleep
0x00042da5      c07a           or #0x7a:8,r0h
0x00042da7      1000           shll r0h
0x00042da9      0000           nop
0x00042dab      3a01           mov.b r2l,@0x1:8
0x00042dad      006f           nop
0x00042daf      f000           mov.b #0x0:8,r0h
0x00042db1      186e           sub.b r6h,r6l
0x00042db3      0800           add.b r0h,r0h
0x00042db5      3301           mov.b r3h,@0x1:8
0x00042db7      0069           nop
0x00042db9      7178           bnot #0x7:3,r0l
0x00042dbb      106a           shal r2l
0x00042dbd      a800           cmp.b #0x0:8,r0l
0x00042dbf      400f           bra @@0xf:8
0x00042dc1      4d01           blt @@0x1:8
0x00042dc3      006f           nop
0x00042dc5      7000           bset #0x0:3,r0h
0x00042dc7      187a           sub.b r7h,r2l
0x00042dc9      1000           shll r0h
0x00042dcb      0000           nop
0x00042dcd      3401           mov.b r4h,@0x1:8
0x00042dcf      006f           nop
0x00042dd1      7100           bnot #0x0:3,r0h
0x00042dd3      2468           mov.b @0x68:8,r4h
0x00042dd5      0878           add.b r7h,r0l
0x00042dd7      106a           shal r2l
0x00042dd9      a800           cmp.b #0x0:8,r0l
0x00042ddb      400f           bra @@0xf:8
0x00042ddd      5101           divxu r0h,r1
0x00042ddf      006f           nop
0x00042de1      7000           bset #0x0:3,r0h
0x00042de3      187a           sub.b r7h,r2l
0x00042de5      1000           shll r0h
0x00042de7      0000           nop
0x00042de9      2d01           mov.b @0x1:8,r5l
0x00042deb      006f           nop
0x00042ded      7100           bnot #0x0:3,r0h
0x00042def      2468           mov.b @0x68:8,r4h
0x00042df1      0878           add.b r7h,r0l
0x00042df3      106a           shal r2l
0x00042df5      a800           cmp.b #0x0:8,r0l
0x00042df7      400f           bra @@0xf:8
0x00042df9      6101           bnot r0h,r1h
0x00042dfb      006f           nop
0x00042dfd      7000           bset #0x0:3,r0h
0x00042dff      187a           sub.b r7h,r2l
0x00042e01      1000           shll r0h
0x00042e03      0000           nop
0x00042e05      3901           mov.b r1l,@0x1:8
0x00042e07      006f           nop
0x00042e09      7100           bnot #0x0:3,r0h
0x00042e0b      2468           mov.b @0x68:8,r4h
0x00042e0d      0878           add.b r7h,r0l
0x00042e0f      106a           shal r2l
0x00042e11      a800           cmp.b #0x0:8,r0l
0x00042e13      400f           bra @@0xf:8
0x00042e15      65             invalid
0x00042e16      0a0b           inc r3l
0x00042e18      ab03           cmp.b #0x3:8,r3l
0x00042e1a      58             invalid
0x00042e1b      30fe           mov.b r0h,@0xfe:8
0x00042e1d      9e7a           addx #0x7a:8,r6l
0x00042e1f      1700           not r0h
0x00042e21      0000           nop
0x00042e23      285e           mov.b @0x5e:8,r0l
0x00042e25      01643654       sleep
0x00042e29      705e           bset #0x5:3,r6l
0x00042e2b      0164587a       sleep
0x00042e2f      3700           mov.b r7h,@0x0:8
0x00042e31      0000           nop
0x00042e33      507a           mulxu r7h,r2
0x00042e35      0300           ldc r0h,ccr
0x00042e37      4009           bra @@0x9:8
0x00042e39      c27a           or #0x7a:8,r2h
0x00042e3b      0400           orc #0x0:8,ccr
0x00042e3d      400f           bra @@0xf:8
0x00042e3f      5b7a           jmp @@0x7a:8
0x00042e41      0500           xorc #0x0:8,ccr
0x00042e43      400f           bra @@0xf:8
0x00042e45      3a6a           mov.b r2l,@0x6a:8
0x00042e47      2800           mov.b @0x0:8,r0l
0x00042e49      400f           bra @@0xf:8
0x00042e4b      5617           rte
0x00042e4d      5079           mulxu r7h,r1
0x00042e4f      0800           add.b r0h,r0h
0x00042e51      3a52           mov.b r2l,@0x52:8
0x00042e53      800a           add.b #0xa:8,r0h
0x00042e55      b07a           subx #0x7a:8,r0h
0x00042e57      1000           shll r0h
0x00042e59      0000           nop
0x00042e5b      1a68           dec r0l
0x00042e5d      086a           add.b r6h,r2l
0x00042e5f      a800           cmp.b #0x0:8,r0l
0x00042e61      400f           bra @@0xf:8
0x00042e63      3418           mov.b r4h,@0x18:8
0x00042e65      ee0c           and #0xc:8,r6l
0x00042e67      e817           and #0x17:8,r0l
0x00042e69      5017           mulxu r1h,r7
0x00042e6b      7078           bset #0x7:3,r0l
0x00042e6d      006a           nop
0x00042e6f      2800           mov.b @0x0:8,r0l
0x00042e71      4010           bra @@0x10:8
0x00042e73      676a           bst #0x6:3,r2l
0x00042e75      2900           mov.b @0x0:8,r1l
0x00042e77      400f           bra @@0xf:8
0x00042e79      341c           mov.b r4h,@0x1c:8
0x00042e7b      9847           addx #0x47:8,r0l
0x00042e7d      3c0c           mov.b r4l,@0xc:8
0x00042e7f      e817           and #0x17:8,r0l
0x00042e81      5017           mulxu r1h,r7
0x00042e83      706a           bset #0x6:3,r2l
0x00042e85      2900           mov.b @0x0:8,r1l
0x00042e87      400f           bra @@0xf:8
0x00042e89      3478           mov.b r4h,@0x78:8
0x00042e8b      006a           nop
0x00042e8d      a900           cmp.b #0x0:8,r1l
0x00042e8f      4010           bra @@0x10:8
0x00042e91      670c           bst #0x0:3,r4l
0x00042e93      e817           and #0x17:8,r0l
0x00042e95      5017           mulxu r1h,r7
0x00042e97      70f9           bset #0x7:3,r1l
0x00042e99      0e10           addx r1h,r0h
0x00042e9b      301a           mov.b r0h,@0x1a:8
0x00042e9d      094e           add.w r4,r6
0x00042e9f      fa10           mov.b #0x10:8,r2l
0x00042ea1      307a           mov.b r0h,@0x7a:8
0x00042ea3      1000           shll r0h
0x00042ea5      8000           add.b #0x0:8,r0h
0x00042ea7      0001           nop
0x00042ea9      006d           nop
0x00042eab      f00f           mov.b #0xf:8,r0h
0x00042ead      816a           add.b #0x6a:8,r1h
0x00042eaf      2800           mov.b @0x0:8,r0l
0x00042eb1      400f           bra @@0xf:8
0x00042eb3      345e           mov.b r4h,@0x5e:8
0x00042eb5      0371           ldc r1h,ccr
0x00042eb7      8a0b           add.b #0xb:8,r2l
0x00042eb9      970a           addx #0xa:8,r7h
0x00042ebb      0eae           addx r2l,r6l
0x00042ebd      0445           orc #0x45:8,ccr
0x00042ebf      a66a           cmp.b #0x6a:8,r6h
0x00042ec1      2800           mov.b @0x0:8,r0l
0x00042ec3      400f           bra @@0xf:8
0x00042ec5      5617           rte
0x00042ec7      5079           mulxu r7h,r1
0x00042ec9      0800           add.b r0h,r0h
0x00042ecb      3a52           mov.b r2l,@0x52:8
0x00042ecd      800a           add.b #0xa:8,r0h
0x00042ecf      b07a           subx #0x7a:8,r0h
0x00042ed1      1000           shll r0h
0x00042ed3      0000           nop
0x00042ed5      3268           mov.b r2h,@0x68:8
0x00042ed7      0e6a           addx r6h,r2l
0x00042ed9      2800           mov.b @0x0:8,r0l
0x00042edb      4062           bra @@0x62:8
0x00042edd      f8a8           mov.b #0xa8:8,r0l
0x00042edf      0346           ldc r6h,ccr
0x00042ee1      0418           orc #0x18:8,ccr
0x00042ee3      8840           add.b #0x40:8,r0l
0x00042ee5      0a0c           inc r4l
0x00042ee7      e8e8           and #0xe8:8,r0l
0x00042ee9      20f9           mov.b @0xf9:8,r0h
0x00042eeb      2018           mov.b @0x18:8,r0h
0x00042eed      0051           nop
0x00042eef      906a           addx #0x6a:8,r0h
0x00042ef1      a800           cmp.b #0x0:8,r0l
0x00042ef3      400f           bra @@0xf:8
0x00042ef5      4a6a           bpl @@0x6a:8
0x00042ef7      2800           mov.b @0x0:8,r0l
0x00042ef9      4062           bra @@0x62:8
0x00042efb      f8a8           mov.b #0xa8:8,r0l
0x00042efd      0347           ldc r7h,ccr
0x00042eff      04a8           orc #0xa8:8,ccr
0x00042f01      0746           ldc #0x46:8,ccr
0x00042f03      0a18           inc r0l
0x00042f05      886a           add.b #0x6a:8,r0l
0x00042f07      a800           cmp.b #0x0:8,r0l
0x00042f09      400f           bra @@0xf:8
0x00042f0b      4b40           bmi @@0x40:8
0x00042f0d      0eee           addx r6l,r6l
0x00042f0f      4012           bra @@0x12:8
0x00042f11      8e12           add.b #0x12:8,r6l
0x00042f13      8eee           add.b #0xee:8,r6l
0x00042f15      036a           ldc r2l,ccr
0x00042f17      ae             cmp.b #0x10:8,r6l
0x00042f19      400f           bra @@0xf:8
0x00042f1b      4b6a           bmi @@0x6a:8
0x00042f1d      2800           mov.b @0x0:8,r0l
0x00042f1f      400e           bra @@0xe:8
0x00042f21      7a             invalid
0x00042f22      58             invalid
0x00042f23      6004           bset r0h,r4h
0x00042f25      6218           bclr r1h,r0l
0x00042f27      ee01           and #0x1:8,r6l
0x00042f29      006f           nop
0x00042f2b      f300           mov.b #0x0:8,r3h
0x00042f2d      487a           bvc @@0x7a:8
0x00042f2f      0000           nop
0x00042f31      400f           bra @@0xf:8
0x00042f33      8801           add.b #0x1:8,r0l
0x00042f35      006f           nop
0x00042f37      f000           mov.b #0x0:8,r0h
0x00042f39      3cae           mov.b r4l,@0xae:8
0x00042f3b      01464c6a       sleep
0x00042f3f      2800           mov.b @0x0:8,r0l
0x00042f41      400d           bra @@0xd:8
0x00042f43      43a8           bls @@0xa8:8
0x00042f45      01464201       sleep
0x00042f49      006f           nop
0x00042f4b      7000           bset #0x0:3,r0h
0x00042f4d      486e           bvc @@0x6e:8
0x00042f4f      0800           add.b r0h,r0h
0x00042f51      3217           mov.b r2h,@0x17:8
0x00042f53      5017           mulxu r1h,r7
0x00042f55      1079           shal r1l
0x00042f57      6000           bset r0h,r0h
0x00042f59      0211           stc ccr,r1h
0x00042f5b      900c           addx #0xc:8,r0h
0x00042f5d      e917           and #0x17:8,r1l
0x00042f5f      5117           divxu r1h,r7
0x00042f61      7178           bnot #0x7:3,r0l
0x00042f63      106a           shal r2l
0x00042f65      a800           cmp.b #0x0:8,r0l
0x00042f67      400f           bra @@0xf:8
0x00042f69      3579           mov.b r5h,@0x79:8
0x00042f6b      01002e01       sleep
0x00042f6f      006f           nop
0x00042f71      7000           bset #0x0:3,r0h
0x00042f73      485e           bvc @@0x5e:8
0x00042f75      01236001       sleep
0x00042f79      006f           nop
0x00042f7b      f000           mov.b #0x0:8,r0h
0x00042f7d      4479           bcc @@0x79:8
0x00042f7f      01003501       sleep
0x00042f83      006f           nop
0x00042f85      7000           bset #0x0:3,r0h
0x00042f87      4840           bvc @@0x40:8
0x00042f89      6a0ce817       mov.b @0xe817:16,r4l
0x00042f8d      5017           mulxu r1h,r7
0x00042f8f      7001           bset #0x0:3,r1h
0x00042f91      006f           nop
0x00042f93      f000           mov.b #0x0:8,r0h
0x00042f95      4c01           bge @@0x1:8
0x00042f97      006f           nop
0x00042f99      f000           mov.b #0x0:8,r0h
0x00042f9b      2001           mov.b @0x1:8,r0h
0x00042f9d      006f           nop
0x00042f9f      7000           bset #0x0:3,r0h
0x00042fa1      4c7a           bge @@0x7a:8
0x00042fa3      01000000       sleep
0x00042fa7      3a5e           mov.b r2l,@0x5e:8
0x00042fa9      0163ea0a       sleep
0x00042fad      b07a           subx #0x7a:8,r0h
0x00042faf      1000           shll r0h
0x00042fb1      0000           nop
0x00042fb3      3a01           mov.b r2l,@0x1:8
0x00042fb5      006f           nop
0x00042fb7      f000           mov.b #0x0:8,r0h
0x00042fb9      406e           bra @@0x6e:8
0x00042fbb      0800           add.b r0h,r0h
0x00042fbd      3217           mov.b r2h,@0x17:8
0x00042fbf      5017           mulxu r1h,r7
0x00042fc1      1079           shal r1l
0x00042fc3      6000           bset r0h,r0h
0x00042fc5      0211           stc ccr,r1h
0x00042fc7      9001           addx #0x1:8,r0h
0x00042fc9      006f           nop
0x00042fcb      7100           bnot #0x0:3,r0h
0x00042fcd      2078           mov.b @0x78:8,r0h
0x00042fcf      106a           shal r2l
0x00042fd1      a800           cmp.b #0x0:8,r0l
0x00042fd3      400f           bra @@0xf:8
0x00042fd5      3579           mov.b r5h,@0x79:8
0x00042fd7      01002e01       sleep
0x00042fdb      006f           nop
0x00042fdd      7000           bset #0x0:3,r0h
0x00042fdf      405e           bra @@0x5e:8
0x00042fe1      01236001       sleep
0x00042fe5      006f           nop
0x00042fe7      f000           mov.b #0x0:8,r0h
0x00042fe9      4479           bcc @@0x79:8
0x00042feb      01003501       sleep
0x00042fef      006f           nop
0x00042ff1      7000           bset #0x0:3,r0h
0x00042ff3      405e           bra @@0x5e:8
0x00042ff5      01236001       sleep
0x00042ff9      006f           nop
0x00042ffb      f000           mov.b #0x0:8,r0h
0x00042ffd      4c0c           bge @@0xc:8
0x00042fff      e817           and #0x17:8,r0l
0x00043001      5017           mulxu r1h,r7
0x00043003      7078           bset #0x7:3,r0l
0x00043005      006a           nop
0x00043007      2900           mov.b @0x0:8,r1l
0x00043009      400f           bra @@0xf:8
0x0004300b      65             invalid
0x0004300c      476e           beq @@0x6e:8
0x0004300e      0ce8           mov.b r6l,r0l
0x00043010      1750           neg r0h
0x00043012      1770           neg r0h
0x00043014      78             invalid
0x00043015      006a           nop
0x00043017      2800           mov.b @0x0:8,r0l
0x00043019      400f           bra @@0xf:8
0x0004301b      65             invalid
0x0004301c      a801           cmp.b #0x1:8,r0l
0x0004301e      460a           bne @@0xa:8
0x00043020      0ce0           mov.b r6l,r0h
0x00043022      1888           sub.b r0l,r0l
0x00043024      5e039c6c       jsr @0x9c6c:16
0x00043028      4052           bra @@0x52:8
0x0004302a      0ce8           mov.b r6l,r0l
0x0004302c      1750           neg r0h
0x0004302e      1770           neg r0h
0x00043030      78             invalid
0x00043031      006a           nop
0x00043033      2800           mov.b @0x0:8,r0l
0x00043035      400f           bra @@0xf:8
0x00043037      65             invalid
0x00043038      a802           cmp.b #0x2:8,r0l
0x0004303a      460a           bne @@0xa:8
0x0004303c      0ce0           mov.b r6l,r0h
0x0004303e      f803           mov.b #0x3:8,r0l
0x00043040      5e039c6c       jsr @0x9c6c:16
0x00043044      4036           bra @@0x36:8
0x00043046      0ce8           mov.b r6l,r0l
0x00043048      1750           neg r0h
0x0004304a      1770           neg r0h
0x0004304c      78             invalid
0x0004304d      006a           nop
0x0004304f      2800           mov.b @0x0:8,r0l
0x00043051      400f           bra @@0xf:8
0x00043053      65             invalid
0x00043054      a803           cmp.b #0x3:8,r0l
0x00043056      460a           bne @@0xa:8
0x00043058      0ce0           mov.b r6l,r0h
0x0004305a      f801           mov.b #0x1:8,r0l
0x0004305c      5e039c6c       jsr @0x9c6c:16
0x00043060      401a           bra @@0x1a:8
0x00043062      0ce8           mov.b r6l,r0l
0x00043064      1750           neg r0h
0x00043066      1770           neg r0h
0x00043068      78             invalid
0x00043069      006a           nop
0x0004306b      2800           mov.b @0x0:8,r0l
0x0004306d      400f           bra @@0xf:8
0x0004306f      65             invalid
0x00043070      a804           cmp.b #0x4:8,r0l
0x00043072      4608           bne @@0x8:8
0x00043074      0ce0           mov.b r6l,r0h
0x00043076      f802           mov.b #0x2:8,r0l
0x00043078      5e039c6c       jsr @0x9c6c:16
0x0004307c      01006f70       sleep
0x00043080      0044           nop
0x00043082      4640           bne @@0x40:8
0x00043084      01006f70       sleep
0x00043088      004c           nop
0x0004308a      4638           bne @@0x38:8
0x0004308c      0ce8           mov.b r6l,r0l
0x0004308e      1750           neg r0h
0x00043090      1770           neg r0h
0x00043092      1030           shal r0h
0x00043094      1030           shal r0h
0x00043096      01006ff0       sleep
0x0004309a      0044           nop
0x0004309c      0ad0           inc r0h
0x0004309e      1a91           dec r1h
0x000430a0      6849           mov.b @r4,r1l
0x000430a2      1031           shal r1h
0x000430a4      1031           shal r1h
0x000430a6      1031           shal r1h
0x000430a8      1031           shal r1h
0x000430aa      7a             invalid
0x000430ab      1100           shlr r0h
0x000430ad      400f           bra @@0xf:8
0x000430af      ae01           cmp.b #0x1:8,r6l
0x000430b1      006f           nop
0x000430b3      7200           bclr #0x0:3,r0h
0x000430b5      440a           bcc @@0xa:8
0x000430b7      a101           cmp.b #0x1:8,r1h
0x000430b9      0069           nop
0x000430bb      1101           shlr r1h
0x000430bd      0069           nop
0x000430bf      815a           add.b #0x5a:8,r1h
0x000430c1      0432           orc #0x32:8,ccr
0x000430c3      7e01006f       biand #0x6:3,@0x1:8
0x000430c7      7000           bset #0x0:3,r0h
0x000430c9      4c58           bge @@0x58:8
0x000430cb      7001           bset #0x0:3,r1h
0x000430cd      4c0c           bge @@0xc:8
0x000430cf      e817           and #0x17:8,r0l
0x000430d1      5017           mulxu r1h,r7
0x000430d3      7078           bset #0x7:3,r0l
0x000430d5      006a           nop
0x000430d7      2900           mov.b @0x0:8,r1l
0x000430d9      404e           bra @@0x4e:8
0x000430db      5058           mulxu r5h,r0
0x000430dd      6000           bset r0h,r0h
0x000430df      920c           addx #0xc:8,r2h
0x000430e1      e817           and #0x17:8,r0l
0x000430e3      5017           mulxu r1h,r7
0x000430e5      7010           bset #0x1:3,r0h
0x000430e7      3010           mov.b r0h,@0x10:8
0x000430e9      3001           mov.b r0h,@0x1:8
0x000430eb      006f           nop
0x000430ed      f000           mov.b #0x0:8,r0h
0x000430ef      440a           bcc @@0xa:8
0x000430f1      d01a           xor #0x1a:8,r0h
0x000430f3      9168           addx #0x68:8,r1h
0x000430f5      4910           bvs @@0x10:8
0x000430f7      3110           mov.b r1h,@0x10:8
0x000430f9      3110           mov.b r1h,@0x10:8
0x000430fb      3110           mov.b r1h,@0x10:8
0x000430fd      3101           mov.b r1h,@0x1:8
0x000430ff      006f           nop
0x00043101      f100           mov.b #0x0:8,r1h
0x00043103      407a           bra @@0x7a:8
0x00043105      1100           shlr r0h
0x00043107      400f           bra @@0xf:8
0x00043109      ae01           cmp.b #0x1:8,r6l
0x0004310b      006f           nop
0x0004310d      7200           bclr #0x0:3,r0h
0x0004310f      440a           bcc @@0xa:8
0x00043111      a101           cmp.b #0x1:8,r1h
0x00043113      006f           nop
0x00043115      f100           mov.b #0x0:8,r1h
0x00043117      2001           mov.b @0x1:8,r0h
0x00043119      006b           nop
0x0004311b      2100           mov.b @0x0:8,r1h
0x0004311d      400f           bra @@0xf:8
0x0004311f      8401           add.b #0x1:8,r4h
0x00043121      006f           nop
0x00043123      f000           mov.b #0x0:8,r0h
0x00043125      147a           or r7h,r2l
0x00043127      0000           nop
0x00043129      0000           nop
0x0004312b      180a           sub.b r0h,r2l
0x0004312d      f05e           mov.b #0x5e:8,r0h
0x0004312f      015db401       sleep
0x00043133      006f           nop
0x00043135      7100           bnot #0x0:3,r0h
0x00043137      4c01           bge @@0x1:8
0x00043139      006f           nop
0x0004313b      f000           mov.b #0x0:8,r0h
0x0004313d      087a           add.b r7h,r2l
0x0004313f      0000           nop
0x00043141      0000           nop
0x00043143      0c0a           mov.b r0h,r2l
0x00043145      f05e           mov.b #0x5e:8,r0h
0x00043147      01648001       sleep
0x0004314b      006f           nop
0x0004314d      7100           bnot #0x0:3,r0h
0x0004314f      080f           add.b r0h,r7l
0x00043151      820f           add.b #0xf:8,r2h
0x00043153      f05e           mov.b #0x5e:8,r0h
0x00043155      0160305e       sleep
0x00043159      015d2e01       sleep
0x0004315d      006f           nop
0x0004315f      7100           bnot #0x0:3,r0h
0x00043161      407a           bra @@0x7a:8
0x00043163      1100           shlr r0h
0x00043165      400f           bra @@0xf:8
0x00043167      ee01           and #0x1:8,r6l
0x00043169      006f           nop
0x0004316b      7200           bclr #0x0:3,r0h
0x0004316d      445a           bcc @@0x5a:8
0x0004316f      0432           orc #0x32:8,ccr
0x00043171      020c           stc ccr,r4l
0x00043173      e817           and #0x17:8,r0l
0x00043175      5017           mulxu r1h,r7
0x00043177      7010           bset #0x1:3,r0h
0x00043179      3010           mov.b r0h,@0x10:8
0x0004317b      3001           mov.b r0h,@0x1:8
0x0004317d      006f           nop
0x0004317f      f000           mov.b #0x0:8,r0h
0x00043181      440a           bcc @@0xa:8
0x00043183      d01a           xor #0x1a:8,r0h
0x00043185      9168           addx #0x68:8,r1h
0x00043187      4910           bvs @@0x10:8
0x00043189      3110           mov.b r1h,@0x10:8
0x0004318b      3110           mov.b r1h,@0x10:8
0x0004318d      3110           mov.b r1h,@0x10:8
0x0004318f      3101           mov.b r1h,@0x1:8
0x00043191      006f           nop
0x00043193      f100           mov.b #0x0:8,r1h
0x00043195      407a           bra @@0x7a:8
0x00043197      1100           shlr r0h
0x00043199      400f           bra @@0xf:8
0x0004319b      ae01           cmp.b #0x1:8,r6l
0x0004319d      006f           nop
0x0004319f      7200           bclr #0x0:3,r0h
0x000431a1      440a           bcc @@0xa:8
0x000431a3      a101           cmp.b #0x1:8,r1h
0x000431a5      006f           nop
0x000431a7      7200           bclr #0x0:3,r0h
0x000431a9      3c01           mov.b r4l,@0x1:8
0x000431ab      006f           nop
0x000431ad      f100           mov.b #0x0:8,r1h
0x000431af      2001           mov.b @0x1:8,r0h
0x000431b1      0069           nop
0x000431b3      2101           mov.b @0x1:8,r1h
0x000431b5      006f           nop
0x000431b7      f000           mov.b #0x0:8,r0h
0x000431b9      147a           or r7h,r2l
0x000431bb      0000           nop
0x000431bd      0000           nop
0x000431bf      180a           sub.b r0h,r2l
0x000431c1      f05e           mov.b #0x5e:8,r0h
0x000431c3      015db401       sleep
0x000431c7      006f           nop
0x000431c9      7100           bnot #0x0:3,r0h
0x000431cb      4c01           bge @@0x1:8
0x000431cd      006f           nop
0x000431cf      f000           mov.b #0x0:8,r0h
0x000431d1      087a           add.b r7h,r2l
0x000431d3      0000           nop
0x000431d5      0000           nop
0x000431d7      0c0a           mov.b r0h,r2l
0x000431d9      f05e           mov.b #0x5e:8,r0h
0x000431db      01648001       sleep
0x000431df      006f           nop
0x000431e1      7100           bnot #0x0:3,r0h
0x000431e3      080f           add.b r0h,r7l
0x000431e5      820f           add.b #0xf:8,r2h
0x000431e7      f05e           mov.b #0x5e:8,r0h
0x000431e9      0160305e       sleep
0x000431ed      015d2e01       sleep
0x000431f1      006f           nop
0x000431f3      7100           bnot #0x0:3,r0h
0x000431f5      407a           bra @@0x7a:8
0x000431f7      1100           shlr r0h
0x000431f9      400f           bra @@0xf:8
0x000431fb      ee01           and #0x1:8,r6l
0x000431fd      006f           nop
0x000431ff      7200           bclr #0x0:3,r0h
0x00043201      440a           bcc @@0xa:8
0x00043203      a101           cmp.b #0x1:8,r1h
0x00043205      0069           nop
0x00043207      9001           addx #0x1:8,r0h
0x00043209      006f           nop
0x0004320b      7100           bnot #0x0:3,r0h
0x0004320d      2001           mov.b @0x1:8,r0h
0x0004320f      0069           nop
0x00043211      9001           addx #0x1:8,r0h
0x00043213      006f           nop
0x00043215      7100           bnot #0x0:3,r0h
0x00043217      1440           or r4h,r0h
0x00043219      600c           bset r0h,r4l
0x0004321b      e817           and #0x17:8,r0l
0x0004321d      5017           mulxu r1h,r7
0x0004321f      7010           bset #0x1:3,r0h
0x00043221      3010           mov.b r0h,@0x10:8
0x00043223      3001           mov.b r0h,@0x1:8
0x00043225      006f           nop
0x00043227      f000           mov.b #0x0:8,r0h
0x00043229      400a           bra @@0xa:8
0x0004322b      d01a           xor #0x1a:8,r0h
0x0004322d      9168           addx #0x68:8,r1h
0x0004322f      4910           bvs @@0x10:8
0x00043231      3110           mov.b r1h,@0x10:8
0x00043233      3110           mov.b r1h,@0x10:8
0x00043235      3110           mov.b r1h,@0x10:8
0x00043237      3101           mov.b r1h,@0x1:8
0x00043239      006f           nop
0x0004323b      f100           mov.b #0x0:8,r1h
0x0004323d      387a           mov.b r0l,@0x7a:8
0x0004323f      1100           shlr r0h
0x00043241      400f           bra @@0xf:8
0x00043243      ae01           cmp.b #0x1:8,r6l
0x00043245      006f           nop
0x00043247      7200           bclr #0x0:3,r0h
0x00043249      400a           bra @@0xa:8
0x0004324b      a101           cmp.b #0x1:8,r1h
0x0004324d      006f           nop
0x0004324f      7200           bclr #0x0:3,r0h
0x00043251      387a           mov.b r0l,@0x7a:8
0x00043253      1200           rotxl r0h
0x00043255      400f           bra @@0xf:8
0x00043257      ee01           and #0x1:8,r6l
0x00043259      006f           nop
0x0004325b      f000           mov.b #0x0:8,r0h
0x0004325d      2001           mov.b @0x1:8,r0h
0x0004325f      006f           nop
0x00043261      7000           bset #0x0:3,r0h
0x00043263      400a           bra @@0xa:8
0x00043265      8201           add.b #0x1:8,r2h
0x00043267      006f           nop
0x00043269      7000           bset #0x0:3,r0h
0x0004326b      4401           bcc @@0x1:8
0x0004326d      0069           nop
0x0004326f      a001           cmp.b #0x1:8,r0h
0x00043271      0069           nop
0x00043273      9001           addx #0x1:8,r0h
0x00043275      006f           nop
0x00043277      7100           bnot #0x0:3,r0h
0x00043279      2001           mov.b @0x1:8,r0h
0x0004327b      0069           nop
0x0004327d      900c           addx #0xc:8,r0h
0x0004327f      e817           and #0x17:8,r0l
0x00043281      5017           mulxu r1h,r7
0x00043283      7078           bset #0x7:3,r0l
0x00043285      006a           nop
0x00043287      2900           mov.b @0x0:8,r1l
0x00043289      400f           bra @@0xf:8
0x0004328b      65             invalid
0x0004328c      4634           bne @@0x34:8
0x0004328e      01006f70       sleep
0x00043292      004c           nop
0x00043294      462c           bne @@0x2c:8
0x00043296      0ce8           mov.b r6l,r0l
0x00043298      1750           neg r0h
0x0004329a      1770           neg r0h
0x0004329c      1030           shal r0h
0x0004329e      1a91           dec r1h
0x000432a0      6849           mov.b @r4,r1l
0x000432a2      7a             invalid
0x000432a3      1000           shll r0h
0x000432a5      04a5           orc #0xa5:8,ccr
0x000432a7      500a           mulxu r0h,r2
0x000432a9      9068           addx #0x68:8,r0h
0x000432ab      08a8           add.b r2l,r0l
0x000432ad      0246           stc ccr,r6h
0x000432af      0a0f           inc r7l
0x000432b1      d10c           xor #0xc:8,r1h
0x000432b3      e85e           and #0x5e:8,r0l
0x000432b5      03a0           ldc r0h,ccr
0x000432b7      0e40           addx r4h,r0h
0x000432b9      080f           add.b r0h,r7l
0x000432bb      d10c           xor #0xc:8,r1h
0x000432bd      e85e           and #0x5e:8,r0l
0x000432bf      039e           ldc r6l,ccr
0x000432c1      0c0c           mov.b r0h,r4l
0x000432c3      e817           and #0x17:8,r0l
0x000432c5      5017           mulxu r1h,r7
0x000432c7      7078           bset #0x7:3,r0l
0x000432c9      006a           nop
0x000432cb      2900           mov.b @0x0:8,r1l
0x000432cd      404e           bra @@0x4e:8
0x000432cf      5046           mulxu r4h,r6
0x000432d1      380c           mov.b r0l,@0xc:8
0x000432d3      e817           and #0x17:8,r0l
0x000432d5      5017           mulxu r1h,r7
0x000432d7      7010           bset #0x1:3,r0h
0x000432d9      3010           mov.b r0h,@0x10:8
0x000432db      3001           mov.b r0h,@0x1:8
0x000432dd      006f           nop
0x000432df      f000           mov.b #0x0:8,r0h
0x000432e1      4c01           bge @@0x1:8
0x000432e3      006f           nop
0x000432e5      7100           bnot #0x0:3,r0h
0x000432e7      4c0a           bge @@0xa:8
0x000432e9      d101           xor #0x1:8,r1h
0x000432eb      0069           nop
0x000432ed      1101           shlr r1h
0x000432ef      006f           nop
0x000432f1      f000           mov.b #0x0:8,r0h
0x000432f3      187a           sub.b r7h,r2l
0x000432f5      0000           nop
0x000432f7      0000           nop
0x000432f9      1c0a           cmp.b r0h,r2l
0x000432fb      f05e           mov.b #0x5e:8,r0h
0x000432fd      01648001       sleep
0x00043301      006b           nop
0x00043303      2100           mov.b @0x0:8,r1h
0x00043305      400f           bra @@0xf:8
0x00043307      8440           add.b #0x40:8,r4h
0x00043309      380c           mov.b r0l,@0xc:8
0x0004330b      e817           and #0x17:8,r0l
0x0004330d      5017           mulxu r1h,r7
0x0004330f      7010           bset #0x1:3,r0h
0x00043311      3010           mov.b r0h,@0x10:8
0x00043313      3001           mov.b r0h,@0x1:8
0x00043315      006f           nop
0x00043317      f000           mov.b #0x0:8,r0h
0x00043319      4c01           bge @@0x1:8
0x0004331b      006f           nop
0x0004331d      7100           bnot #0x0:3,r0h
0x0004331f      4c0a           bge @@0xa:8
0x00043321      d101           xor #0x1:8,r1h
0x00043323      0069           nop
0x00043325      1101           shlr r1h
0x00043327      006f           nop
0x00043329      f000           mov.b #0x0:8,r0h
0x0004332b      187a           sub.b r7h,r2l
0x0004332d      0000           nop
0x0004332f      0000           nop
0x00043331      1c0a           cmp.b r0h,r2l
0x00043333      f05e           mov.b #0x5e:8,r0h
0x00043335      01648001       sleep
0x00043339      006f           nop
0x0004333b      7100           bnot #0x0:3,r0h
0x0004333d      3c01           mov.b r4l,@0x1:8
0x0004333f      0069           nop
0x00043341      1101           shlr r1h
0x00043343      006f           nop
0x00043345      f000           mov.b #0x0:8,r0h
0x00043347      0c7a           mov.b r7h,r2l
0x00043349      0000           nop
0x0004334b      0000           nop
0x0004334d      100a           shll r2l
0x0004334f      f05e           mov.b #0x5e:8,r0h
0x00043351      015db401       sleep
0x00043355      006f           nop
0x00043357      7100           bnot #0x0:3,r0h
0x00043359      0c0f           mov.b r0h,r7l
0x0004335b      827a           add.b #0x7a:8,r2h
0x0004335d      0000           nop
0x0004335f      0000           nop
0x00043361      040a           orc #0xa:8,ccr
0x00043363      f05e           mov.b #0x5e:8,r0h
0x00043365      0159a45e       sleep
0x00043369      015d2e01       sleep
0x0004336d      006f           nop
0x0004336f      7100           bnot #0x0:3,r0h
0x00043371      1801           sub.b r0h,r1h
0x00043373      0078           nop
0x00043375      906b           addx #0x6b:8,r0h
0x00043377      a000           cmp.b #0x0:8,r0h
0x00043379      406e           bra @@0x6e:8
0x0004337b      760a           band #0x0:3,r2l
0x0004337d      0eae           addx r2l,r6l
0x0004337f      0358           ldc r0l,ccr
0x00043381      30fb           mov.b r0h,@0xfb:8
0x00043383      b65a           subx #0x5a:8,r6h
0x00043385      0439           orc #0x39:8,ccr
0x00043387      5e18ee7a       jsr @0xee7a:16
0x0004338b      0000           nop
0x0004338d      0001           nop
0x0004338f      220a           mov.b @0xa:8,r2h
0x00043391      b001           subx #0x1:8,r0h
0x00043393      006f           nop
0x00043395      f000           mov.b #0x0:8,r0h
0x00043397      487a           bvc @@0x7a:8
0x00043399      0000           nop
0x0004339b      400f           bra @@0xf:8
0x0004339d      8801           add.b #0x1:8,r0l
0x0004339f      006f           nop
0x000433a1      f000           mov.b #0x0:8,r0h
0x000433a3      440c           bcc @@0xc:8
0x000433a5      ee47           and #0x47:8,r6l
0x000433a7      06ae           andc #0xae:8,ccr
0x000433a9      0358           ldc r0l,ccr
0x000433ab      6003           bset r0h,r3h
0x000433ad      fa0c           mov.b #0xc:8,r2l
0x000433af      ee46           and #0x46:8,r6l
0x000433b1      4201           bhi @@0x1:8
0x000433b3      006f           nop
0x000433b5      7000           bset #0x0:3,r0h
0x000433b7      486e           bvc @@0x6e:8
0x000433b9      0800           add.b r0h,r0h
0x000433bb      3217           mov.b r2h,@0x17:8
0x000433bd      5017           mulxu r1h,r7
0x000433bf      1079           shal r1l
0x000433c1      6000           bset r0h,r0h
0x000433c3      0211           stc ccr,r1h
0x000433c5      900c           addx #0xc:8,r0h
0x000433c7      e917           and #0x17:8,r1l
0x000433c9      5117           divxu r1h,r7
0x000433cb      7178           bnot #0x7:3,r0l
0x000433cd      106a           shal r2l
0x000433cf      a800           cmp.b #0x0:8,r0l
0x000433d1      400f           bra @@0xf:8
0x000433d3      3579           mov.b r5h,@0x79:8
0x000433d5      01002e01       sleep
0x000433d9      006f           nop
0x000433db      7000           bset #0x0:3,r0h
0x000433dd      485e           bvc @@0x5e:8
0x000433df      01236001       sleep
0x000433e3      006f           nop
0x000433e5      f000           mov.b #0x0:8,r0h
0x000433e7      4079           bra @@0x79:8
0x000433e9      01003501       sleep
0x000433ed      006f           nop
0x000433ef      7000           bset #0x0:3,r0h
0x000433f1      4840           bvc @@0x40:8
0x000433f3      6a0ce817       mov.b @0xe817:16,r4l
0x000433f7      5017           mulxu r1h,r7
0x000433f9      7001           bset #0x0:3,r1h
0x000433fb      006f           nop
0x000433fd      f000           mov.b #0x0:8,r0h
0x000433ff      4c01           bge @@0x1:8
0x00043401      006f           nop
0x00043403      f000           mov.b #0x0:8,r0h
0x00043405      2001           mov.b @0x1:8,r0h
0x00043407      006f           nop
0x00043409      7000           bset #0x0:3,r0h
0x0004340b      4c7a           bge @@0x7a:8
0x0004340d      01000000       sleep
0x00043411      3a5e           mov.b r2l,@0x5e:8
0x00043413      0163ea0a       sleep
0x00043417      b07a           subx #0x7a:8,r0h
0x00043419      1000           shll r0h
0x0004341b      0000           nop
0x0004341d      3a01           mov.b r2l,@0x1:8
0x0004341f      006f           nop
0x00043421      f000           mov.b #0x0:8,r0h
0x00043423      3c6e           mov.b r4l,@0x6e:8
0x00043425      0800           add.b r0h,r0h
0x00043427      3217           mov.b r2h,@0x17:8
0x00043429      5017           mulxu r1h,r7
0x0004342b      1079           shal r1l
0x0004342d      6000           bset r0h,r0h
0x0004342f      0211           stc ccr,r1h
0x00043431      9001           addx #0x1:8,r0h
0x00043433      006f           nop
0x00043435      7100           bnot #0x0:3,r0h
0x00043437      2078           mov.b @0x78:8,r0h
0x00043439      106a           shal r2l
0x0004343b      a800           cmp.b #0x0:8,r0l
0x0004343d      400f           bra @@0xf:8
0x0004343f      3579           mov.b r5h,@0x79:8
0x00043441      01002e01       sleep
0x00043445      006f           nop
0x00043447      7000           bset #0x0:3,r0h
0x00043449      3c5e           mov.b r4l,@0x5e:8
0x0004344b      01236001       sleep
0x0004344f      006f           nop
0x00043451      f000           mov.b #0x0:8,r0h
0x00043453      4079           bra @@0x79:8
0x00043455      01003501       sleep
0x00043459      006f           nop
0x0004345b      7000           bset #0x0:3,r0h
0x0004345d      3c5e           mov.b r4l,@0x5e:8
0x0004345f      01236001       sleep
0x00043463      006f           nop
0x00043465      f000           mov.b #0x0:8,r0h
0x00043467      4c0c           bge @@0xc:8
0x00043469      e817           and #0x17:8,r0l
0x0004346b      5017           mulxu r1h,r7
0x0004346d      7078           bset #0x7:3,r0l
0x0004346f      006a           nop
0x00043471      2900           mov.b @0x0:8,r1l
0x00043473      400f           bra @@0xf:8
0x00043475      65             invalid
0x00043476      4720           beq @@0x20:8
0x00043478      0ce8           mov.b r6l,r0l
0x0004347a      1750           neg r0h
0x0004347c      1770           neg r0h
0x0004347e      78             invalid
0x0004347f      006a           nop
0x00043481      2800           mov.b @0x0:8,r0l
0x00043483      400f           bra @@0xf:8
0x00043485      65             invalid
0x00043486      a801           cmp.b #0x1:8,r0l
0x00043488      4606           bne @@0x6:8
0x0004348a      0ce0           mov.b r6l,r0h
0x0004348c      1888           sub.b r0l,r0l
0x0004348e      4004           bra @@0x4:8
0x00043490      0ce0           mov.b r6l,r0h
0x00043492      f803           mov.b #0x3:8,r0l
0x00043494      5e039c6c       jsr @0x9c6c:16
0x00043498      01006f70       sleep
0x0004349c      0040           nop
0x0004349e      4640           bne @@0x40:8
0x000434a0      01006f70       sleep
0x000434a4      004c           nop
0x000434a6      4638           bne @@0x38:8
0x000434a8      0ce8           mov.b r6l,r0l
0x000434aa      1750           neg r0h
0x000434ac      1770           neg r0h
0x000434ae      1030           shal r0h
0x000434b0      1030           shal r0h
0x000434b2      01006ff0       sleep
0x000434b6      0040           nop
0x000434b8      0ad0           inc r0h
0x000434ba      1a91           dec r1h
0x000434bc      6849           mov.b @r4,r1l
0x000434be      1031           shal r1h
0x000434c0      1031           shal r1h
0x000434c2      1031           shal r1h
0x000434c4      1031           shal r1h
0x000434c6      7a             invalid
0x000434c7      1100           shlr r0h
0x000434c9      400f           bra @@0xf:8
0x000434cb      ae01           cmp.b #0x1:8,r6l
0x000434cd      006f           nop
0x000434cf      7200           bclr #0x0:3,r0h
0x000434d1      400a           bra @@0xa:8
0x000434d3      a101           cmp.b #0x1:8,r1h
0x000434d5      0069           nop
0x000434d7      1101           shlr r1h
0x000434d9      0069           nop
0x000434db      815a           add.b #0x5a:8,r1h
0x000434dd      0435           orc #0x35:8,ccr
0x000434df      7001           bset #0x0:3,r1h
0x000434e1      006f           nop
0x000434e3      7000           bset #0x0:3,r0h
0x000434e5      4c47           bge @@0x47:8
0x000434e7      720c           bclr #0x0:3,r4l
0x000434e9      e817           and #0x17:8,r0l
0x000434eb      5017           mulxu r1h,r7
0x000434ed      7078           bset #0x7:3,r0l
0x000434ef      006a           nop
0x000434f1      2900           mov.b @0x0:8,r1l
0x000434f3      404e           bra @@0x4e:8
0x000434f5      5046           mulxu r4h,r6
0x000434f7      0a01           inc r1h
0x000434f9      006b           nop
0x000434fb      2100           mov.b @0x0:8,r1h
0x000434fd      400f           bra @@0xf:8
0x000434ff      8440           add.b #0x40:8,r4h
0x00043501      0a01           inc r1h
0x00043503      006f           nop
0x00043505      7100           bnot #0x0:3,r0h
0x00043507      4401           bcc @@0x1:8
0x00043509      0069           nop
0x0004350b      117a           shar r2l
0x0004350d      0000           nop
0x0004350f      0000           nop
0x00043511      1c0a           cmp.b r0h,r2l
0x00043513      f05e           mov.b #0x5e:8,r0h
0x00043515      015db401       sleep
0x00043519      006f           nop
0x0004351b      7100           bnot #0x0:3,r0h
0x0004351d      4c01           bge @@0x1:8
0x0004351f      006f           nop
0x00043521      f000           mov.b #0x0:8,r0h
0x00043523      107a           shal r2l
0x00043525      0000           nop
0x00043527      0000           nop
0x00043529      140a           or r0h,r2l
0x0004352b      f05e           mov.b #0x5e:8,r0h
0x0004352d      01648001       sleep
0x00043531      006f           nop
0x00043533      7100           bnot #0x0:3,r0h
0x00043535      100f           shll r7l
0x00043537      827a           add.b #0x7a:8,r2h
0x00043539      0000           nop
0x0004353b      0000           nop
0x0004353d      080a           add.b r0h,r2l
0x0004353f      f05e           mov.b #0x5e:8,r0h
0x00043541      0160305e       sleep
0x00043545      015d2e0c       sleep
0x00043549      e917           and #0x17:8,r1l
0x0004354b      5117           divxu r1h,r7
0x0004354d      7110           bnot #0x1:3,r0h
0x0004354f      3110           mov.b r1h,@0x10:8
0x00043551      310a           mov.b r1h,@0xa:8
0x00043553      d101           xor #0x1:8,r1h
0x00043555      0069           nop
0x00043557      9040           addx #0x40:8,r0h
0x00043559      160c           and r0h,r4l
0x0004355b      e817           and #0x17:8,r0l
0x0004355d      5017           mulxu r1h,r7
0x0004355f      7010           bset #0x1:3,r0h
0x00043561      3010           mov.b r0h,@0x10:8
0x00043563      300a           mov.b r0h,@0xa:8
0x00043565      d001           xor #0x1:8,r0h
0x00043567      006f           nop
0x00043569      7100           bnot #0x0:3,r0h
0x0004356b      4001           bra @@0x1:8
0x0004356d      0069           nop
0x0004356f      810c           add.b #0xc:8,r1h
0x00043571      ee58           and #0x58:8,r6l
0x00043573      6000           bset r0h,r0h
0x00043575      d80c           xor #0xc:8,r0l
0x00043577      e917           and #0x17:8,r1l
0x00043579      5117           divxu r1h,r7
0x0004357b      7110           bnot #0x1:3,r0h
0x0004357d      3110           mov.b r1h,@0x10:8
0x0004357f      3101           mov.b r1h,@0x1:8
0x00043581      006f           nop
0x00043583      f100           mov.b #0x0:8,r1h
0x00043585      400a           bra @@0xa:8
0x00043587      d101           xor #0x1:8,r1h
0x00043589      006f           nop
0x0004358b      f100           mov.b #0x0:8,r1h
0x0004358d      3001           mov.b r0h,@0x1:8
0x0004358f      0069           nop
0x00043591      1101           shlr r1h
0x00043593      006f           nop
0x00043595      f100           mov.b #0x0:8,r1h
0x00043597      387a           mov.b r0l,@0x7a:8
0x00043599      0000           nop
0x0004359b      0000           nop
0x0004359d      1c0a           cmp.b r0h,r2l
0x0004359f      f05e           mov.b #0x5e:8,r0h
0x000435a1      0164801a       sleep
0x000435a5      9168           addx #0x68:8,r1h
0x000435a7      4910           bvs @@0x10:8
0x000435a9      3110           mov.b r1h,@0x10:8
0x000435ab      3110           mov.b r1h,@0x10:8
0x000435ad      3110           mov.b r1h,@0x10:8
0x000435af      3101           mov.b r1h,@0x1:8
0x000435b1      006f           nop
0x000435b3      f100           mov.b #0x0:8,r1h
0x000435b5      347a           mov.b r4h,@0x7a:8
0x000435b7      1100           shlr r0h
0x000435b9      400f           bra @@0xf:8
0x000435bb      ee01           and #0x1:8,r6l
0x000435bd      006f           nop
0x000435bf      7200           bclr #0x0:3,r0h
0x000435c1      400a           bra @@0xa:8
0x000435c3      a101           cmp.b #0x1:8,r1h
0x000435c5      006f           nop
0x000435c7      f100           mov.b #0x0:8,r1h
0x000435c9      3c01           mov.b r4l,@0x1:8
0x000435cb      0069           nop
0x000435cd      1101           shlr r1h
0x000435cf      006f           nop
0x000435d1      f000           mov.b #0x0:8,r0h
0x000435d3      107a           shal r2l
0x000435d5      0000           nop
0x000435d7      0000           nop
0x000435d9      140a           or r0h,r2l
0x000435db      f05e           mov.b #0x5e:8,r0h
0x000435dd      01648001       sleep
0x000435e1      006f           nop
0x000435e3      7100           bnot #0x0:3,r0h
0x000435e5      100f           shll r7l
0x000435e7      827a           add.b #0x7a:8,r2h
0x000435e9      0000           nop
0x000435eb      0000           nop
0x000435ed      240a           mov.b @0xa:8,r4h
0x000435ef      f05e           mov.b #0x5e:8,r0h
0x000435f1      0159a401       sleep
0x000435f5      006f           nop
0x000435f7      7000           bset #0x0:3,r0h
0x000435f9      3c01           mov.b r4l,@0x1:8
0x000435fb      006f           nop
0x000435fd      7100           bnot #0x0:3,r0h
0x000435ff      3801           mov.b r0l,@0x1:8
0x00043601      0069           nop
0x00043603      8101           add.b #0x1:8,r1h
0x00043605      006f           nop
0x00043607      7000           bset #0x0:3,r0h
0x00043609      347a           mov.b r4h,@0x7a:8
0x0004360b      1000           shll r0h
0x0004360d      400f           bra @@0xf:8
0x0004360f      ae01           cmp.b #0x1:8,r6l
0x00043611      006f           nop
0x00043613      7200           bclr #0x0:3,r0h
0x00043615      400a           bra @@0xa:8
0x00043617      a001           cmp.b #0x1:8,r0h
0x00043619      0069           nop
0x0004361b      8101           add.b #0x1:8,r1h
0x0004361d      006f           nop
0x0004361f      7000           bset #0x0:3,r0h
0x00043621      3001           mov.b r0h,@0x1:8
0x00043623      006f           nop
0x00043625      f000           mov.b #0x0:8,r0h
0x00043627      2001           mov.b @0x1:8,r0h
0x00043629      006f           nop
0x0004362b      7100           bnot #0x0:3,r0h
0x0004362d      2001           mov.b @0x1:8,r0h
0x0004362f      0069           nop
0x00043631      1001           shll r1h
0x00043633      006f           nop
0x00043635      f100           mov.b #0x0:8,r1h
0x00043637      1c7a           cmp.b r7h,r2l
0x00043639      01000000       sleep
0x0004363d      035e           ldc r6l,ccr
0x0004363f      015cf201       sleep
0x00043643      006f           nop
0x00043645      7100           bnot #0x0:3,r0h
0x00043647      1c01           cmp.b r0h,r1h
0x00043649      0069           nop
0x0004364b      9040           addx #0x40:8,r0h
0x0004364d      58             invalid
0x0004364e      1a80           dec r0h
0x00043650      6848           mov.b @r4,r0l
0x00043652      1030           shal r0h
0x00043654      1030           shal r0h
0x00043656      1030           shal r0h
0x00043658      1030           shal r0h
0x0004365a      01006ff0       sleep
0x0004365e      003c           nop
0x00043660      0ce9           mov.b r6l,r1l
0x00043662      1751           neg r1h
0x00043664      1771           neg r1h
0x00043666      1031           shal r1h
0x00043668      1031           shal r1h
0x0004366a      01006ff1       sleep
0x0004366e      0040           nop
0x00043670      7a             invalid
0x00043671      1000           shll r0h
0x00043673      400f           bra @@0xf:8
0x00043675      ae0a           cmp.b #0xa:8,r6l
0x00043677      900a           addx #0xa:8,r0h
0x00043679      d101           xor #0x1:8,r1h
0x0004367b      006f           nop
0x0004367d      7200           bclr #0x0:3,r0h
0x0004367f      3c7a           mov.b r4l,@0x7a:8
0x00043681      1200           rotxl r0h
0x00043683      400f           bra @@0xf:8
0x00043685      ee01           and #0x1:8,r6l
0x00043687      006f           nop
0x00043689      f000           mov.b #0x0:8,r0h
0x0004368b      2001           mov.b @0x1:8,r0h
0x0004368d      006f           nop
0x0004368f      7000           bset #0x0:3,r0h
0x00043691      400a           bra @@0xa:8
0x00043693      8201           add.b #0x1:8,r2h
0x00043695      0069           nop
0x00043697      1101           shlr r1h
0x00043699      0069           nop
0x0004369b      a101           cmp.b #0x1:8,r1h
0x0004369d      006f           nop
0x0004369f      7000           bset #0x0:3,r0h
0x000436a1      2001           mov.b @0x1:8,r0h
0x000436a3      0069           nop
0x000436a5      810c           add.b #0xc:8,r1h
0x000436a7      e817           and #0x17:8,r0l
0x000436a9      5017           mulxu r1h,r7
0x000436ab      7078           bset #0x7:3,r0l
0x000436ad      006a           nop
0x000436af      2900           mov.b @0x0:8,r1l
0x000436b1      400f           bra @@0xf:8
0x000436b3      65             invalid
0x000436b4      4634           bne @@0x34:8
0x000436b6      01006f70       sleep
0x000436ba      004c           nop
0x000436bc      462c           bne @@0x2c:8
0x000436be      0ce8           mov.b r6l,r0l
0x000436c0      1750           neg r0h
0x000436c2      1770           neg r0h
0x000436c4      1030           shal r0h
0x000436c6      1a91           dec r1h
0x000436c8      6849           mov.b @r4,r1l
0x000436ca      7a             invalid
0x000436cb      1000           shll r0h
0x000436cd      04a5           orc #0xa5:8,ccr
0x000436cf      500a           mulxu r0h,r2
0x000436d1      9068           addx #0x68:8,r0h
0x000436d3      08a8           add.b r2l,r0l
0x000436d5      0246           stc ccr,r6h
0x000436d7      0a0f           inc r7l
0x000436d9      d10c           xor #0xc:8,r1h
0x000436db      e85e           and #0x5e:8,r0l
0x000436dd      03a0           ldc r0h,ccr
0x000436df      0e40           addx r4h,r0h
0x000436e1      080f           add.b r0h,r7l
0x000436e3      d10c           xor #0xc:8,r1h
0x000436e5      e85e           and #0x5e:8,r0l
0x000436e7      039e           ldc r6l,ccr
0x000436e9      0c0c           mov.b r0h,r4l
0x000436eb      e817           and #0x17:8,r0l
0x000436ed      5017           mulxu r1h,r7
0x000436ef      7078           bset #0x7:3,r0l
0x000436f1      006a           nop
0x000436f3      2900           mov.b @0x0:8,r1l
0x000436f5      404e           bra @@0x4e:8
0x000436f7      5046           mulxu r4h,r6
0x000436f9      380c           mov.b r0l,@0xc:8
0x000436fb      e817           and #0x17:8,r0l
0x000436fd      5017           mulxu r1h,r7
0x000436ff      7010           bset #0x1:3,r0h
0x00043701      3010           mov.b r0h,@0x10:8
0x00043703      3001           mov.b r0h,@0x1:8
0x00043705      006f           nop
0x00043707      f000           mov.b #0x0:8,r0h
0x00043709      4c01           bge @@0x1:8
0x0004370b      006f           nop
0x0004370d      7100           bnot #0x0:3,r0h
0x0004370f      4c0a           bge @@0xa:8
0x00043711      d101           xor #0x1:8,r1h
0x00043713      0069           nop
0x00043715      1101           shlr r1h
0x00043717      006f           nop
0x00043719      f000           mov.b #0x0:8,r0h
0x0004371b      187a           sub.b r7h,r2l
0x0004371d      0000           nop
0x0004371f      0000           nop
0x00043721      1c0a           cmp.b r0h,r2l
0x00043723      f05e           mov.b #0x5e:8,r0h
0x00043725      01648001       sleep
0x00043729      006b           nop
0x0004372b      2100           mov.b @0x0:8,r1h
0x0004372d      400f           bra @@0xf:8
0x0004372f      8440           add.b #0x40:8,r4h
0x00043731      380c           mov.b r0l,@0xc:8
0x00043733      e817           and #0x17:8,r0l
0x00043735      5017           mulxu r1h,r7
0x00043737      7010           bset #0x1:3,r0h
0x00043739      3010           mov.b r0h,@0x10:8
0x0004373b      3001           mov.b r0h,@0x1:8
0x0004373d      006f           nop
0x0004373f      f000           mov.b #0x0:8,r0h
0x00043741      4c01           bge @@0x1:8
0x00043743      006f           nop
0x00043745      7100           bnot #0x0:3,r0h
0x00043747      4c0a           bge @@0xa:8
0x00043749      d101           xor #0x1:8,r1h
0x0004374b      0069           nop
0x0004374d      1101           shlr r1h
0x0004374f      006f           nop
0x00043751      f000           mov.b #0x0:8,r0h
0x00043753      187a           sub.b r7h,r2l
0x00043755      0000           nop
0x00043757      0000           nop
0x00043759      1c0a           cmp.b r0h,r2l
0x0004375b      f05e           mov.b #0x5e:8,r0h
0x0004375d      01648001       sleep
0x00043761      006f           nop
0x00043763      7100           bnot #0x0:3,r0h
0x00043765      4401           bcc @@0x1:8
0x00043767      0069           nop
0x00043769      1101           shlr r1h
0x0004376b      006f           nop
0x0004376d      f000           mov.b #0x0:8,r0h
0x0004376f      0c7a           mov.b r7h,r2l
0x00043771      0000           nop
0x00043773      0000           nop
0x00043775      100a           shll r2l
0x00043777      f05e           mov.b #0x5e:8,r0h
0x00043779      015db401       sleep
0x0004377d      006f           nop
0x0004377f      7100           bnot #0x0:3,r0h
0x00043781      0c0f           mov.b r0h,r7l
0x00043783      827a           add.b #0x7a:8,r2h
0x00043785      0000           nop
0x00043787      0000           nop
0x00043789      040a           orc #0xa:8,ccr
0x0004378b      f05e           mov.b #0x5e:8,r0h
0x0004378d      0159a45e       sleep
0x00043791      015d2e01       sleep
0x00043795      006f           nop
0x00043797      7100           bnot #0x0:3,r0h
0x00043799      1801           sub.b r0h,r1h
0x0004379b      0078           nop
0x0004379d      906b           addx #0x6b:8,r0h
0x0004379f      a000           cmp.b #0x0:8,r0h
0x000437a1      406e           bra @@0x6e:8
0x000437a3      765a           band #0x5:3,r2l
0x000437a5      0439           orc #0x39:8,ccr
0x000437a7      560c           rte
0x000437a9      e817           and #0x17:8,r0l
0x000437ab      5017           mulxu r1h,r7
0x000437ad      7001           bset #0x0:3,r1h
0x000437af      006f           nop
0x000437b1      f000           mov.b #0x0:8,r0h
0x000437b3      3c10           mov.b r4l,@0x10:8
0x000437b5      3010           mov.b r0h,@0x10:8
0x000437b7      3001           mov.b r0h,@0x1:8
0x000437b9      006f           nop
0x000437bb      f000           mov.b #0x0:8,r0h
0x000437bd      4c0a           bge @@0xa:8
0x000437bf      d001           xor #0x1:8,r0h
0x000437c1      006f           nop
0x000437c3      f000           mov.b #0x0:8,r0h
0x000437c5      401a           bra @@0x1a:8
0x000437c7      9168           addx #0x68:8,r1h
0x000437c9      4910           bvs @@0x10:8
0x000437cb      3110           mov.b r1h,@0x10:8
0x000437cd      3110           mov.b r1h,@0x10:8
0x000437cf      3110           mov.b r1h,@0x10:8
0x000437d1      317a           mov.b r1h,@0x7a:8
0x000437d3      1100           shlr r0h
0x000437d5      400f           bra @@0xf:8
0x000437d7      ee01           and #0x1:8,r6l
0x000437d9      006f           nop
0x000437db      7200           bclr #0x0:3,r0h
0x000437dd      4c0a           bge @@0xa:8
0x000437df      a101           cmp.b #0x1:8,r1h
0x000437e1      0069           nop
0x000437e3      1101           shlr r1h
0x000437e5      006f           nop
0x000437e7      f000           mov.b #0x0:8,r0h
0x000437e9      187a           sub.b r7h,r2l
0x000437eb      0000           nop
0x000437ed      0000           nop
0x000437ef      1c0a           cmp.b r0h,r2l
0x000437f1      f05e           mov.b #0x5e:8,r0h
0x000437f3      0164800f       sleep
0x000437f7      817a           add.b #0x7a:8,r1h
0x000437f9      0200           stc ccr,r0h
0x000437fb      0000           nop
0x000437fd      240a           mov.b @0xa:8,r4h
0x000437ff      f27a           mov.b #0x7a:8,r2h
0x00043801      0000           nop
0x00043803      0000           nop
0x00043805      100a           shll r2l
0x00043807      f05e           mov.b #0x5e:8,r0h
0x00043809      0160305e       sleep
0x0004380d      015d2e01       sleep
0x00043811      006f           nop
0x00043813      7100           bnot #0x0:3,r0h
0x00043815      1801           sub.b r0h,r1h
0x00043817      0069           nop
0x00043819      901a           addx #0x1a:8,r0h
0x0004381b      8068           add.b #0x68:8,r0h
0x0004381d      4810           bvc @@0x10:8
0x0004381f      3010           mov.b r0h,@0x10:8
0x00043821      3010           mov.b r0h,@0x10:8
0x00043823      3010           mov.b r0h,@0x10:8
0x00043825      3001           mov.b r0h,@0x1:8
0x00043827      006f           nop
0x00043829      f000           mov.b #0x0:8,r0h
0x0004382b      387a           mov.b r0l,@0x7a:8
0x0004382d      1000           shll r0h
0x0004382f      400f           bra @@0xf:8
0x00043831      ae01           cmp.b #0x1:8,r6l
0x00043833      006f           nop
0x00043835      7100           bnot #0x0:3,r0h
0x00043837      4c0a           bge @@0xa:8
0x00043839      9001           addx #0x1:8,r0h
0x0004383b      006f           nop
0x0004383d      7100           bnot #0x0:3,r0h
0x0004383f      4001           bra @@0x1:8
0x00043841      006f           nop
0x00043843      7200           bclr #0x0:3,r0h
0x00043845      387a           mov.b r0l,@0x7a:8
0x00043847      1200           rotxl r0h
0x00043849      400f           bra @@0xf:8
0x0004384b      ee01           and #0x1:8,r6l
0x0004384d      006f           nop
0x0004384f      f000           mov.b #0x0:8,r0h
0x00043851      2001           mov.b @0x1:8,r0h
0x00043853      006f           nop
0x00043855      7000           bset #0x0:3,r0h
0x00043857      4c0a           bge @@0xa:8
0x00043859      8201           add.b #0x1:8,r2h
0x0004385b      0069           nop
0x0004385d      1101           shlr r1h
0x0004385f      0069           nop
0x00043861      a101           cmp.b #0x1:8,r1h
0x00043863      006f           nop
0x00043865      7000           bset #0x0:3,r0h
0x00043867      2001           mov.b @0x1:8,r0h
0x00043869      0069           nop
0x0004386b      8101           add.b #0x1:8,r1h
0x0004386d      006f           nop
0x0004386f      7000           bset #0x0:3,r0h
0x00043871      4001           bra @@0x1:8
0x00043873      006f           nop
0x00043875      f000           mov.b #0x0:8,r0h
0x00043877      2001           mov.b @0x1:8,r0h
0x00043879      006f           nop
0x0004387b      7100           bnot #0x0:3,r0h
0x0004387d      2001           mov.b @0x1:8,r0h
0x0004387f      0069           nop
0x00043881      1001           shll r1h
0x00043883      006f           nop
0x00043885      f100           mov.b #0x0:8,r1h
0x00043887      1c7a           cmp.b r7h,r2l
0x00043889      01000000       sleep
0x0004388d      035e           ldc r6l,ccr
0x0004388f      015cf201       sleep
0x00043893      006f           nop
0x00043895      7100           bnot #0x0:3,r0h
0x00043897      1c01           cmp.b r0h,r1h
0x00043899      0069           nop
0x0004389b      9001           addx #0x1:8,r0h
0x0004389d      006f           nop
0x0004389f      7000           bset #0x0:3,r0h
0x000438a1      3c78           mov.b r4l,@0x78:8
0x000438a3      006a           nop
0x000438a5      2900           mov.b @0x0:8,r1l
0x000438a7      404e           bra @@0x4e:8
0x000438a9      5046           mulxu r4h,r6
0x000438ab      380c           mov.b r0l,@0xc:8
0x000438ad      e817           and #0x17:8,r0l
0x000438af      5017           mulxu r1h,r7
0x000438b1      7010           bset #0x1:3,r0h
0x000438b3      3010           mov.b r0h,@0x10:8
0x000438b5      3001           mov.b r0h,@0x1:8
0x000438b7      006f           nop
0x000438b9      f000           mov.b #0x0:8,r0h
0x000438bb      4c01           bge @@0x1:8
0x000438bd      006f           nop
0x000438bf      7100           bnot #0x0:3,r0h
0x000438c1      4c0a           bge @@0xa:8
0x000438c3      d101           xor #0x1:8,r1h
0x000438c5      0069           nop
0x000438c7      1101           shlr r1h
0x000438c9      006f           nop
0x000438cb      f000           mov.b #0x0:8,r0h
0x000438cd      187a           sub.b r7h,r2l
0x000438cf      0000           nop
0x000438d1      0000           nop
0x000438d3      1c0a           cmp.b r0h,r2l
0x000438d5      f05e           mov.b #0x5e:8,r0h
0x000438d7      01648001       sleep
0x000438db      006b           nop
0x000438dd      2100           mov.b @0x0:8,r1h
0x000438df      400f           bra @@0xf:8
0x000438e1      8440           add.b #0x40:8,r4h
0x000438e3      380c           mov.b r0l,@0xc:8
0x000438e5      e817           and #0x17:8,r0l
0x000438e7      5017           mulxu r1h,r7
0x000438e9      7010           bset #0x1:3,r0h
0x000438eb      3010           mov.b r0h,@0x10:8
0x000438ed      3001           mov.b r0h,@0x1:8
0x000438ef      006f           nop
0x000438f1      f000           mov.b #0x0:8,r0h
0x000438f3      4c01           bge @@0x1:8
0x000438f5      006f           nop
0x000438f7      7100           bnot #0x0:3,r0h
0x000438f9      4c0a           bge @@0xa:8
0x000438fb      d101           xor #0x1:8,r1h
0x000438fd      0069           nop
0x000438ff      1101           shlr r1h
0x00043901      006f           nop
0x00043903      f000           mov.b #0x0:8,r0h
0x00043905      187a           sub.b r7h,r2l
0x00043907      0000           nop
0x00043909      0000           nop
0x0004390b      1c0a           cmp.b r0h,r2l
0x0004390d      f05e           mov.b #0x5e:8,r0h
0x0004390f      01648001       sleep
0x00043913      006f           nop
0x00043915      7100           bnot #0x0:3,r0h
0x00043917      4401           bcc @@0x1:8
0x00043919      0069           nop
0x0004391b      1101           shlr r1h
0x0004391d      006f           nop
0x0004391f      f000           mov.b #0x0:8,r0h
0x00043921      0c7a           mov.b r7h,r2l
0x00043923      0000           nop
0x00043925      0000           nop
0x00043927      100a           shll r2l
0x00043929      f05e           mov.b #0x5e:8,r0h
0x0004392b      015db401       sleep
0x0004392f      006f           nop
0x00043931      7100           bnot #0x0:3,r0h
0x00043933      0c0f           mov.b r0h,r7l
0x00043935      827a           add.b #0x7a:8,r2h
0x00043937      0000           nop
0x00043939      0000           nop
0x0004393b      040a           orc #0xa:8,ccr
0x0004393d      f05e           mov.b #0x5e:8,r0h
0x0004393f      0159a45e       sleep
0x00043943      015d2e01       sleep
0x00043947      006f           nop
0x00043949      7100           bnot #0x0:3,r0h
0x0004394b      1801           sub.b r0h,r1h
0x0004394d      0078           nop
0x0004394f      906b           addx #0x6b:8,r0h
0x00043951      a000           cmp.b #0x0:8,r0h
0x00043953      406e           bra @@0x6e:8
0x00043955      760a           band #0x0:3,r2l
0x00043957      0eae           addx r2l,r6l
0x00043959      0358           ldc r0l,ccr
0x0004395b      30fa           mov.b r0h,@0xfa:8
0x0004395d      466a           bne @@0x6a:8
0x0004395f      2800           mov.b @0x0:8,r0l
0x00043961      400f           bra @@0xf:8
0x00043963      60a8           bset r2l,r0l
0x00043965      01460a19       sleep
0x00043969      006b           nop
0x0004396b      a000           cmp.b #0x0:8,r0h
0x0004396d      400f           bra @@0xf:8
0x0004396f      2640           mov.b @0x40:8,r6h
0x00043971      5c             invalid
0x00043972      6a280040       mov.b @0x40:16,r0l
0x00043976      0773           ldc #0x73:8,ccr
0x00043978      471e           beq @@0x1e:8
0x0004397a      a801           cmp.b #0x1:8,r0l
0x0004397c      472a           beq @@0x2a:8
0x0004397e      a802           cmp.b #0x2:8,r0l
0x00043980      4740           beq @@0x40:8
0x00043982      a803           cmp.b #0x3:8,r0l
0x00043984      471a           beq @@0x1a:8
0x00043986      a804           cmp.b #0x4:8,r0l
0x00043988      4726           beq @@0x26:8
0x0004398a      a805           cmp.b #0x5:8,r0l
0x0004398c      4722           beq @@0x22:8
0x0004398e      a806           cmp.b #0x6:8,r0l
0x00043990      4706           beq @@0x6:8
0x00043992      a807           cmp.b #0x7:8,r0l
0x00043994      4702           beq @@0x2:8
0x00043996      4036           bra @@0x36:8
0x00043998      6b200040       mov.w @0x40:16,r0
0x0004399c      0b8a           adds #2,r2
0x0004399e      4028           bra @@0x28:8
0x000439a0      6b200040       mov.w @0x40:16,r0
0x000439a4      0b68           adds #1,r0
0x000439a6      4020           bra @@0x20:8
0x000439a8      6b200040       mov.w @0x40:16,r0
0x000439ac      0b24           adds #1,r4
0x000439ae      4018           bra @@0x18:8
0x000439b0      6b200040       mov.w @0x40:16,r0
0x000439b4      0b24           adds #1,r4
0x000439b6      1770           neg r0h
0x000439b8      01006ba0       sleep
0x000439bc      0040           nop
0x000439be      0f28           daa r0l
0x000439c0      400c           bra @@0xc:8
0x000439c2      6b200040       mov.w @0x40:16,r0
0x000439c6      0b46           adds #1,r6
0x000439c8      6ba00040       mov.w r0,@0x40:16
0x000439cc      0f26           daa r6h
0x000439ce      6a280040       mov.b @0x40:16,r0l
0x000439d2      0f56           daa r6h
0x000439d4      1750           neg r0h
0x000439d6      7908003a       mov.w #0x3a:16,r0
0x000439da      52             invalid
0x000439db      800a           add.b #0xa:8,r0h
0x000439dd      b079           subx #0x79:8,r0h
0x000439df      01000e5e       sleep
0x000439e3      01236001       sleep
0x000439e7      006f           nop
0x000439e9      f000           mov.b #0x0:8,r0h
0x000439eb      406a           bra @@0x6a:8
0x000439ed      2800           mov.b @0x0:8,r0l
0x000439ef      400f           bra @@0xf:8
0x000439f1      5617           rte
0x000439f3      5079           mulxu r7h,r1
0x000439f5      0800           add.b r0h,r0h
0x000439f7      3a52           mov.b r2l,@0x52:8
0x000439f9      800a           add.b #0xa:8,r0h
0x000439fb      b079           subx #0x79:8,r0h
0x000439fd      0100125e       sleep
0x00043a01      01236001       sleep
0x00043a05      006f           nop
0x00043a07      f000           mov.b #0x0:8,r0h
0x00043a09      486a           bvc @@0x6a:8
0x00043a0b      2800           mov.b @0x0:8,r0l
0x00043a0d      400f           bra @@0xf:8
0x00043a0f      5617           rte
0x00043a11      5079           mulxu r7h,r1
0x00043a13      0800           add.b r0h,r0h
0x00043a15      3a52           mov.b r2l,@0x52:8
0x00043a17      800a           add.b #0xa:8,r0h
0x00043a19      b079           subx #0x79:8,r0h
0x00043a1b      0100025e       sleep
0x00043a1f      01239879       sleep
0x00043a23      010fa017       sleep
0x00043a27      7153           bnot #0x5:3,r3h
0x00043a29      016aa900       sleep
0x00043a2d      400f           bra @@0xf:8
0x00043a2f      326a           mov.b r2h,@0x6a:8
0x00043a31      2800           mov.b @0x0:8,r0l
0x00043a33      400f           bra @@0xf:8
0x00043a35      5617           rte
0x00043a37      5079           mulxu r7h,r1
0x00043a39      0800           add.b r0h,r0h
0x00043a3b      3a52           mov.b r2l,@0x52:8
0x00043a3d      800a           add.b #0xa:8,r0h
0x00043a3f      b079           subx #0x79:8,r0h
0x00043a41      0100045e       sleep
0x00043a45      01239879       sleep
0x00043a49      010fa017       sleep
0x00043a4d      7153           bnot #0x5:3,r3h
0x00043a4f      016aa900       sleep
0x00043a53      400f           bra @@0xf:8
0x00043a55      337a           mov.b r3h,@0x7a:8
0x00043a57      0600           andc #0x0:8,ccr
0x00043a59      400d           bra @@0xd:8
0x00043a5b      3a01           mov.b r2l,@0x1:8
0x00043a5d      006f           nop
0x00043a5f      7000           bset #0x0:3,r0h
0x00043a61      407a           bra @@0x7a:8
0x00043a63      0100000f       sleep
0x00043a67      a05e           cmp.b #0x5e:8,r0h
0x00043a69      0163ea01       sleep
0x00043a6d      006f           nop
0x00043a6f      f000           mov.b #0x0:8,r0h
0x00043a71      4469           bcc @@0x69:8
0x00043a73      6117           bnot r1h,r7h
0x00043a75      7101           bnot #0x0:3,r1h
0x00043a77      006f           nop
0x00043a79      f100           mov.b #0x0:8,r1h
0x00043a7b      4c5e           bge @@0x5e:8
0x00043a7d      015cf26b       sleep
0x00043a81      a000           cmp.b #0x0:8,r0h
0x00043a83      400f           bra @@0xf:8
0x00043a85      2c1a           mov.b @0x1a:8,r4l
0x00043a87      806a           add.b #0x6a:8,r0h
0x00043a89      2800           mov.b @0x0:8,r0l
0x00043a8b      400f           bra @@0xf:8
0x00043a8d      3201           mov.b r2h,@0x1:8
0x00043a8f      006f           nop
0x00043a91      7100           bnot #0x0:3,r0h
0x00043a93      4c5e           bge @@0x5e:8
0x00043a95      0163ea0f       sleep
0x00043a99      8101           add.b #0x1:8,r1h
0x00043a9b      006f           nop
0x00043a9d      7000           bset #0x0:3,r0h
0x00043a9f      445e           bcc @@0x5e:8
0x00043aa1      015cf26b       sleep
0x00043aa5      a000           cmp.b #0x0:8,r0h
0x00043aa7      400f           bra @@0xf:8
0x00043aa9      2e01           mov.b @0x1:8,r6l
0x00043aab      006f           nop
0x00043aad      7000           bset #0x0:3,r0h
0x00043aaf      487a           bvc @@0x7a:8
0x00043ab1      0100000f       sleep
0x00043ab5      a05e           cmp.b #0x5e:8,r0h
0x00043ab7      0163ea1a       sleep
0x00043abb      916a           addx #0x6a:8,r1h
0x00043abd      2900           mov.b @0x0:8,r1l
0x00043abf      400f           bra @@0xf:8
0x00043ac1      3301           mov.b r3h,@0x1:8
0x00043ac3      006f           nop
0x00043ac5      f000           mov.b #0x0:8,r0h
0x00043ac7      2001           mov.b @0x1:8,r0h
0x00043ac9      006f           nop
0x00043acb      7000           bset #0x0:3,r0h
0x00043acd      4c5e           bge @@0x5e:8
0x00043acf      0163ea0f       sleep
0x00043ad3      8101           add.b #0x1:8,r1h
0x00043ad5      006f           nop
0x00043ad7      7000           bset #0x0:3,r0h
0x00043ad9      205e           mov.b @0x5e:8,r0h
0x00043adb      015cf26b       sleep
0x00043adf      a000           cmp.b #0x0:8,r0h
0x00043ae1      400f           bra @@0xf:8
0x00043ae3      306a           mov.b r0h,@0x6a:8
0x00043ae5      2800           mov.b @0x0:8,r0l
0x00043ae7      400f           bra @@0xf:8
0x00043ae9      5617           rte
0x00043aeb      5079           mulxu r7h,r1
0x00043aed      0800           add.b r0h,r0h
0x00043aef      3a52           mov.b r2l,@0x52:8
0x00043af1      800a           add.b #0xa:8,r0h
0x00043af3      b079           subx #0x79:8,r0h
0x00043af5      0100065e       sleep
0x00043af9      0123607a       sleep
0x00043afd      0100000f       sleep
0x00043b01      a05e           cmp.b #0x5e:8,r0h
0x00043b03      0163ea69       sleep
0x00043b07      6117           bnot r1h,r7h
0x00043b09      715e           bnot #0x5:3,r6l
0x00043b0b      015cf26b       sleep
0x00043b0f      2100           mov.b @0x0:8,r1h
0x00043b11      400e           bra @@0xe:8
0x00043b13      826b           add.b #0x6b:8,r2h
0x00043b15      2200           mov.b @0x0:8,r2h
0x00043b17      400f           bra @@0xf:8
0x00043b19      2c19           mov.b @0x19:8,r4l
0x00043b1b      2117           mov.b @0x17:8,r1h
0x00043b1d      711a           bnot #0x1:3,r2l
0x00043b1f      816b           add.b #0x6b:8,r1h
0x00043b21      2000           mov.b @0x0:8,r0h
0x00043b23      400c           bra @@0xc:8
0x00043b25      da6b           xor #0x6b:8,r2l
0x00043b27      2200           mov.b @0x0:8,r2h
0x00043b29      400c           bra @@0xc:8
0x00043b2b      dc09           xor #0x9:8,r4l
0x00043b2d      200b           mov.b @0xb:8,r0h
0x00043b2f      5017           mulxu r1h,r7
0x00043b31      700a           bset #0x0:3,r2l
0x00043b33      816b           add.b #0x6b:8,r1h
0x00043b35      2000           mov.b @0x0:8,r0h
0x00043b37      400e           bra @@0xe:8
0x00043b39      8409           add.b #0x9:8,r4h
0x00043b3b      016ba100       sleep
0x00043b3f      400f           bra @@0xf:8
0x00043b41      246a           mov.b @0x6a:8,r4h
0x00043b43      2800           mov.b @0x0:8,r0l
0x00043b45      4007           bra @@0x7:8
0x00043b47      73a8           btst #0x2:3,r0l
0x00043b49      0146346a       sleep
0x00043b4d      2800           mov.b @0x0:8,r0l
0x00043b4f      400f           bra @@0xf:8
0x00043b51      5617           rte
0x00043b53      5079           mulxu r7h,r1
0x00043b55      0800           add.b r0h,r0h
0x00043b57      3a52           mov.b r2l,@0x52:8
0x00043b59      800a           add.b #0xa:8,r0h
0x00043b5b      b079           subx #0x79:8,r0h
0x00043b5d      01000a5e       sleep
0x00043b61      0123607a       sleep
0x00043b65      0100000f       sleep
0x00043b69      a05e           cmp.b #0x5e:8,r0h
0x00043b6b      0163ea69       sleep
0x00043b6f      6117           bnot r1h,r7h
0x00043b71      715e           bnot #0x5:3,r6l
0x00043b73      015cf26b       sleep
0x00043b77      a000           cmp.b #0x0:8,r0h
0x00043b79      400f           bra @@0xf:8
0x00043b7b      265a           mov.b @0x5a:8,r6h
0x00043b7d      043c           orc #0x3c:8,ccr
0x00043b7f      e86a           and #0x6a:8,r0l
0x00043b81      2800           mov.b @0x0:8,r0l
0x00043b83      4007           bra @@0x7:8
0x00043b85      73a8           btst #0x2:3,r0l
0x00043b87      0447           orc #0x47:8,ccr
0x00043b89      06a8           andc #0xa8:8,ccr
0x00043b8b      0558           xorc #0x58:8,ccr
0x00043b8d      6000           bset r0h,r0h
0x00043b8f      9a6a           addx #0x6a:8,r2l
0x00043b91      2800           mov.b @0x0:8,r0l
0x00043b93      400f           bra @@0xf:8
0x00043b95      60a8           bset r2l,r0l
0x00043b97      01465a6a       sleep
0x00043b9b      2800           mov.b @0x0:8,r0l
0x00043b9d      400f           bra @@0xf:8
0x00043b9f      5617           rte
0x00043ba1      5079           mulxu r7h,r1
0x00043ba3      0800           add.b r0h,r0h
0x00043ba5      3a52           mov.b r2l,@0x52:8
0x00043ba7      800a           add.b #0xa:8,r0h
0x00043ba9      b079           subx #0x79:8,r0h
0x00043bab      01000a5e       sleep
0x00043baf      0123607a       sleep
0x00043bb3      0100000f       sleep
0x00043bb7      a05e           cmp.b #0x5e:8,r0h
0x00043bb9      0163ea69       sleep
0x00043bbd      6117           bnot r1h,r7h
0x00043bbf      715e           bnot #0x5:3,r6l
0x00043bc1      015cf201       sleep
0x00043bc5      006b           nop
0x00043bc7      a000           cmp.b #0x0:8,r0h
0x00043bc9      400f           bra @@0xf:8
0x00043bcb      287a           mov.b @0x7a:8,r0l
0x00043bcd      0100001d       sleep
0x00043bd1      7c5e015c       biand #0x5:3,@r5
0x00043bd5      f201           mov.b #0x1:8,r2h
0x00043bd7      006b           nop
0x00043bd9      a100           cmp.b #0x0:8,r1h
0x00043bdb      400f           bra @@0xf:8
0x00043bdd      286b           mov.b @0x6b:8,r0l
0x00043bdf      2000           mov.b @0x0:8,r0h
0x00043be1      400f           bra @@0xf:8
0x00043be3      2a7a           mov.b @0x7a:8,r2l
0x00043be5      0100400f       sleep
0x00043be9      2669           mov.b @0x69:8,r6h
0x00043beb      1209           rotxl r1l
0x00043bed      0269           stc ccr,r1l
0x00043bef      925a           addx #0x5a:8,r2h
0x00043bf1      043c           orc #0x3c:8,ccr
0x00043bf3      e86a           and #0x6a:8,r0l
0x00043bf5      2800           mov.b @0x0:8,r0l
0x00043bf7      400f           bra @@0xf:8
0x00043bf9      5617           rte
0x00043bfb      5079           mulxu r7h,r1
0x00043bfd      0800           add.b r0h,r0h
0x00043bff      3a52           mov.b r2l,@0x52:8
0x00043c01      800a           add.b #0xa:8,r0h
0x00043c03      b079           subx #0x79:8,r0h
0x00043c05      01000a5e       sleep
0x00043c09      0123607a       sleep
0x00043c0d      0100000f       sleep
0x00043c11      a05e           cmp.b #0x5e:8,r0h
0x00043c13      0163ea69       sleep
0x00043c17      6117           bnot r1h,r7h
0x00043c19      715e           bnot #0x5:3,r6l
0x00043c1b      015cf201       sleep
0x00043c1f      006b           nop
0x00043c21      a000           cmp.b #0x0:8,r0h
0x00043c23      400f           bra @@0xf:8
0x00043c25      285a           mov.b @0x5a:8,r0l
0x00043c27      043c           orc #0x3c:8,ccr
0x00043c29      e86a           and #0x6a:8,r0l
0x00043c2b      2800           mov.b @0x0:8,r0l
0x00043c2d      4007           bra @@0x7:8
0x00043c2f      73a8           btst #0x2:3,r0l
0x00043c31      0246           stc ccr,r6h
0x00043c33      7c6a2800       biand #0x0:3,@r6
0x00043c37      400f           bra @@0xf:8
0x00043c39      60a8           bset r2l,r0l
0x00043c3b      0146306a       sleep
0x00043c3f      2800           mov.b @0x0:8,r0l
0x00043c41      400f           bra @@0xf:8
0x00043c43      5617           rte
0x00043c45      5079           mulxu r7h,r1
0x00043c47      0800           add.b r0h,r0h
0x00043c49      3a52           mov.b r2l,@0x52:8
0x00043c4b      800a           add.b #0xa:8,r0h
0x00043c4d      b079           subx #0x79:8,r0h
0x00043c4f      01000a5e       sleep
0x00043c53      01236001       sleep
0x00043c57      006f           nop
0x00043c59      f000           mov.b #0x0:8,r0h
0x00043c5b      2c7a           mov.b @0x7a:8,r4l
0x00043c5d      0100001d       sleep
0x00043c61      7c5e015c       biand #0x5:3,@r5
0x00043c65      f201           mov.b #0x1:8,r2h
0x00043c67      006f           nop
0x00043c69      f100           mov.b #0x0:8,r1h
0x00043c6b      2c40           mov.b @0x40:8,r4l
0x00043c6d      306a           mov.b r0h,@0x6a:8
0x00043c6f      2800           mov.b @0x0:8,r0l
0x00043c71      400f           bra @@0xf:8
0x00043c73      5617           rte
0x00043c75      5079           mulxu r7h,r1
0x00043c77      0800           add.b r0h,r0h
0x00043c79      3a52           mov.b r2l,@0x52:8
0x00043c7b      800a           add.b #0xa:8,r0h
0x00043c7d      b079           subx #0x79:8,r0h
0x00043c7f      01000a5e       sleep
0x00043c83      01236001       sleep
0x00043c87      006f           nop
0x00043c89      f000           mov.b #0x0:8,r0h
0x00043c8b      2c7a           mov.b @0x7a:8,r4l
0x00043c8d      0000           nop
0x00043c8f      0000           nop
0x00043c91      2c0a           mov.b @0xa:8,r4l
0x00043c93      f07a           mov.b #0x7a:8,r0h
0x00043c95      0100406e       sleep
0x00043c99      865e           add.b #0x5e:8,r6h
0x00043c9b      034e           ldc r6l,ccr
0x00043c9d      486f           bvc @@0x6f:8
0x00043c9f      7000           bset #0x0:3,r0h
0x00043ca1      2e7a           mov.b @0x7a:8,r6l
0x00043ca3      0100400f       sleep
0x00043ca7      2669           mov.b @0x69:8,r6h
0x00043ca9      1209           rotxl r1l
0x00043cab      0269           stc ccr,r1l
0x00043cad      9240           addx #0x40:8,r2h
0x00043caf      386a           mov.b r0l,@0x6a:8
0x00043cb1      2800           mov.b @0x0:8,r0l
0x00043cb3      400f           bra @@0xf:8
0x00043cb5      5617           rte
0x00043cb7      5079           mulxu r7h,r1
0x00043cb9      0800           add.b r0h,r0h
0x00043cbb      3a52           mov.b r2l,@0x52:8
0x00043cbd      800a           add.b #0xa:8,r0h
0x00043cbf      b079           subx #0x79:8,r0h
0x00043cc1      01000a5e       sleep
0x00043cc5      0123607a       sleep
0x00043cc9      0100000f       sleep
0x00043ccd      a05e           cmp.b #0x5e:8,r0h
0x00043ccf      0163ea69       sleep
0x00043cd3      6117           bnot r1h,r7h
0x00043cd5      715e           bnot #0x5:3,r6l
0x00043cd7      015cf20d       sleep
0x00043cdb      017a0000       sleep
0x00043cdf      400f           bra @@0xf:8
0x00043ce1      2669           mov.b @0x69:8,r6h
0x00043ce3      0209           stc ccr,r1l
0x00043ce5      1269           rotl r1l
0x00043ce7      8255           add.b #0x55:8,r2h
0x00043ce9      0e55           addx r5h,r5h
0x00043ceb      3e7a           mov.b r6l,@0x7a:8
0x00043ced      1700           not r0h
0x00043cef      0000           nop
0x00043cf1      505e           mulxu r5h,r6
0x00043cf3      01643654       sleep
0x00043cf7      707a           bset #0x7:3,r2l
0x00043cf9      0100400f       sleep
0x00043cfd      4c68           bge @@0x68:8
0x00043cff      18a8           sub.b r2l,r0l
0x00043d01      0146246a       sleep
0x00043d05      2800           mov.b @0x0:8,r0l
0x00043d07      400f           bra @@0xf:8
0x00043d09      32a8           mov.b r2h,@0xa8:8
0x00043d0b      01470aa8       sleep
0x00043d0f      0247           stc ccr,r7h
0x00043d11      06a8           andc #0xa8:8,ccr
0x00043d13      0347           ldc r7h,ccr
0x00043d15      0840           add.b r4h,r0h
0x00043d17      0cf8           mov.b r7l,r0l
0x00043d19      0268           stc ccr,r0l
0x00043d1b      9854           addx #0x54:8,r0l
0x00043d1d      70f8           bset #0x7:3,r0l
0x00043d1f      0468           orc #0x68:8,ccr
0x00043d21      9854           addx #0x54:8,r0l
0x00043d23      70f8           bset #0x7:3,r0l
0x00043d25      0868           add.b r6h,r0l
0x00043d27      9854           addx #0x54:8,r0l
0x00043d29      705e           bset #0x5:3,r6l
0x00043d2b      0164587a       sleep
0x00043d2f      0400           orc #0x0:8,ccr
0x00043d31      400f           bra @@0xf:8
0x00043d33      557a           bsr .122
0x00043d35      0500           xorc #0x0:8,ccr
0x00043d37      400f           bra @@0xf:8
0x00043d39      5618           rte
0x00043d3b      ee40           and #0x40:8,r6l
0x00043d3d      440c           bcc @@0xc:8
0x00043d3f      e817           and #0x17:8,r0l
0x00043d41      5017           mulxu r1h,r7
0x00043d43      700a           bset #0x0:3,r2l
0x00043d45      d068           xor #0x68:8,r0h
0x00043d47      0946           add.w r4,r6
0x00043d49      0e0c           addx r0h,r4l
0x00043d4b      e817           and #0x17:8,r0l
0x00043d4d      5017           mulxu r1h,r7
0x00043d4f      700a           bset #0x0:3,r2l
0x00043d51      d0f9           xor #0xf9:8,r0h
0x00043d53      01688940       sleep
0x00043d57      280c           mov.b @0xc:8,r0l
0x00043d59      e817           and #0x17:8,r0l
0x00043d5b      5017           mulxu r1h,r7
0x00043d5d      700a           bset #0x0:3,r2l
0x00043d5f      d068           xor #0x68:8,r0h
0x00043d61      08a8           add.b r2l,r0l
0x00043d63      0546           xorc #0x46:8,ccr
0x00043d65      0c0c           mov.b r0h,r4l
0x00043d67      e817           and #0x17:8,r0l
0x00043d69      5017           mulxu r1h,r7
0x00043d6b      700a           bset #0x0:3,r2l
0x00043d6d      d018           xor #0x18:8,r0h
0x00043d6f      9940           addx #0x40:8,r1l
0x00043d71      0c0c           mov.b r0h,r4l
0x00043d73      e817           and #0x17:8,r0l
0x00043d75      5017           mulxu r1h,r7
0x00043d77      700a           bset #0x0:3,r2l
0x00043d79      d068           xor #0x68:8,r0h
0x00043d7b      0989           add.w r8,r1
0x00043d7d      ff68           mov.b #0x68:8,r7l
0x00043d7f      890a           add.b #0xa:8,r1l
0x00043d81      0e68           addx r6h,r0l
0x00043d83      481c           bvc @@0x1c:8
0x00043d85      8e45           add.b #0x45:8,r6l
0x00043d87      b66a           subx #0x6a:8,r6h
0x00043d89      2800           mov.b @0x0:8,r0l
0x00043d8b      400e           bra @@0xe:8
0x00043d8d      7a             invalid
0x00043d8e      a801           cmp.b #0x1:8,r0l
0x00043d90      464a           bne @@0x4a:8
0x00043d92      6a280040       mov.b @0x40:16,r0l
0x00043d96      0f22           daa r2h
0x00043d98      a801           cmp.b #0x1:8,r0l
0x00043d9a      4640           bne @@0x40:8
0x00043d9c      6848           mov.b @r4,r0l
0x00043d9e      8802           add.b #0x2:8,r0l
0x00043da0      6aa80040       mov.b r0l,@0x40:16
0x00043da4      6e357a06       mov.b @(0x7a06:16,r3),r5h
0x00043da8      0040           nop
0x00043daa      6e366858       mov.b @(0x6858:16,r3),r6h
0x00043dae      a803           cmp.b #0x3:8,r0l
0x00043db0      4714           beq @@0x14:8
0x00043db2      1888           sub.b r0l,r0l
0x00043db4      68e8           mov.b r0l,@r6
0x00043db6      f801           mov.b #0x1:8,r0l
0x00043db8      6ee80001       mov.b r0l,@(0x1:16,r6)
0x00043dbc      f802           mov.b #0x2:8,r0l
0x00043dbe      6ee80002       mov.b r0l,@(0x2:16,r6)
0x00043dc2      f803           mov.b #0x3:8,r0l
0x00043dc4      4012           bra @@0x12:8
0x00043dc6      f803           mov.b #0x3:8,r0l
0x00043dc8      68e8           mov.b r0l,@r6
0x00043dca      1888           sub.b r0l,r0l
0x00043dcc      6ee80001       mov.b r0l,@(0x1:16,r6)
0x00043dd0      f801           mov.b #0x1:8,r0l
0x00043dd2      6ee80002       mov.b r0l,@(0x2:16,r6)
0x00043dd6      f802           mov.b #0x2:8,r0l
0x00043dd8      6ee80003       mov.b r0l,@(0x3:16,r6)
0x00043ddc      5e016436       jsr @0x6436:16
0x00043de0      5470           rts
0x00043de2      5e016458       jsr @0x6458:16
0x00043de6      7a             invalid
0x00043de7      3700           mov.b r7h,@0x0:8
0x00043de9      0000           nop
0x00043deb      d27a           xor #0x7a:8,r2h
0x00043ded      0300           ldc r0h,ccr
0x00043def      400b           bra @@0xb:8
0x00043df1      247a           mov.b @0x7a:8,r4h
0x00043df3      0400           orc #0x0:8,ccr
0x00043df5      400f           bra @@0xf:8
0x00043df7      5b7a           jmp @@0x7a:8
0x00043df9      0500           xorc #0x0:8,ccr
0x00043dfb      400f           bra @@0xf:8
0x00043dfd      3a6a           mov.b r2l,@0x6a:8
0x00043dff      2800           mov.b @0x0:8,r0l
0x00043e01      400f           bra @@0xf:8
0x00043e03      5617           rte
0x00043e05      5079           mulxu r7h,r1
0x00043e07      0800           add.b r0h,r0h
0x00043e09      3a52           mov.b r2l,@0x52:8
0x00043e0b      8078           add.b #0x78:8,r0h
0x00043e0d      006a           nop
0x00043e0f      2800           mov.b @0x0:8,r0l
0x00043e11      4009           bra @@0x9:8
0x00043e13      dc6a           xor #0x6a:8,r4l
0x00043e15      a800           cmp.b #0x0:8,r0l
0x00043e17      400f           bra @@0xf:8
0x00043e19      3418           mov.b r4h,@0x18:8
0x00043e1b      ee0c           and #0xc:8,r6l
0x00043e1d      e817           and #0x17:8,r0l
0x00043e1f      5017           mulxu r1h,r7
0x00043e21      7078           bset #0x7:3,r0l
0x00043e23      006a           nop
0x00043e25      2800           mov.b @0x0:8,r0l
0x00043e27      4010           bra @@0x10:8
0x00043e29      676a           bst #0x6:3,r2l
0x00043e2b      2900           mov.b @0x0:8,r1l
0x00043e2d      400f           bra @@0xf:8
0x00043e2f      341c           mov.b r4h,@0x1c:8
0x00043e31      9847           addx #0x47:8,r0l
0x00043e33      3c0c           mov.b r4l,@0xc:8
0x00043e35      e817           and #0x17:8,r0l
0x00043e37      5017           mulxu r1h,r7
0x00043e39      706a           bset #0x6:3,r2l
0x00043e3b      2900           mov.b @0x0:8,r1l
0x00043e3d      400f           bra @@0xf:8
0x00043e3f      3478           mov.b r4h,@0x78:8
0x00043e41      006a           nop
0x00043e43      a900           cmp.b #0x0:8,r1l
0x00043e45      4010           bra @@0x10:8
0x00043e47      670c           bst #0x0:3,r4l
0x00043e49      e817           and #0x17:8,r0l
0x00043e4b      5017           mulxu r1h,r7
0x00043e4d      70f9           bset #0x7:3,r1l
0x00043e4f      0e10           addx r1h,r0h
0x00043e51      301a           mov.b r0h,@0x1a:8
0x00043e53      094e           add.w r4,r6
0x00043e55      fa10           mov.b #0x10:8,r2l
0x00043e57      307a           mov.b r0h,@0x7a:8
0x00043e59      1000           shll r0h
0x00043e5b      8000           add.b #0x0:8,r0h
0x00043e5d      0001           nop
0x00043e5f      006d           nop
0x00043e61      f00f           mov.b #0xf:8,r0h
0x00043e63      816a           add.b #0x6a:8,r1h
0x00043e65      2800           mov.b @0x0:8,r0l
0x00043e67      400f           bra @@0xf:8
0x00043e69      345e           mov.b r4h,@0x5e:8
0x00043e6b      0371           ldc r1h,ccr
0x00043e6d      8a0b           add.b #0xb:8,r2l
0x00043e6f      970a           addx #0xa:8,r7h
0x00043e71      0eae           addx r2l,r6l
0x00043e73      0445           orc #0x45:8,ccr
0x00043e75      a66a           cmp.b #0x6a:8,r6h
0x00043e77      2800           mov.b @0x0:8,r0l
0x00043e79      400f           bra @@0xf:8
0x00043e7b      5617           rte
0x00043e7d      5079           mulxu r7h,r1
0x00043e7f      0800           add.b r0h,r0h
0x00043e81      3a52           mov.b r2l,@0x52:8
0x00043e83      8078           add.b #0x78:8,r0h
0x00043e85      006a           nop
0x00043e87      2e00           mov.b @0x0:8,r6l
0x00043e89      4009           bra @@0x9:8
0x00043e8b      f40c           mov.b #0xc:8,r4h
0x00043e8d      e8e8           and #0xe8:8,r0l
0x00043e8f      20f9           mov.b @0xf9:8,r0h
0x00043e91      2018           mov.b @0x18:8,r0h
0x00043e93      0051           nop
0x00043e95      906a           addx #0x6a:8,r0h
0x00043e97      a800           cmp.b #0x0:8,r0l
0x00043e99      400f           bra @@0xf:8
0x00043e9b      4aee           bpl @@0xee:8
0x00043e9d      4012           bra @@0x12:8
0x00043e9f      8e12           add.b #0x12:8,r6l
0x00043ea1      8eee           add.b #0xee:8,r6l
0x00043ea3      036a           ldc r2l,ccr
0x00043ea5      ae00           cmp.b #0x0:8,r6l
0x00043ea7      400f           bra @@0xf:8
0x00043ea9      4b19           bmi @@0x19:8
0x00043eab      ee68           and #0x68:8,r6l
0x00043ead      48a8           bvc @@0xa8:8
0x00043eaf      01464418       sleep
0x00043eb3      ee0c           and #0xc:8,r6l
0x00043eb5      e817           and #0x17:8,r0l
0x00043eb7      5017           mulxu r1h,r7
0x00043eb9      7010           bset #0x1:3,r0h
0x00043ebb      3078           mov.b r0h,@0x78:8
0x00043ebd      006b           nop
0x00043ebf      2000           mov.b @0x0:8,r0h
0x00043ec1      4010           bra @@0x10:8
0x00043ec3      1e1d           subx r1h,r5l
0x00043ec5      0e44           addx r4h,r4h
0x00043ec7      100c           shll r4l
0x00043ec9      e817           and #0x17:8,r0l
0x00043ecb      5017           mulxu r1h,r7
0x00043ecd      7010           bset #0x1:3,r0h
0x00043ecf      3078           mov.b r0h,@0x78:8
0x00043ed1      006b           nop
0x00043ed3      2e00           mov.b @0x0:8,r6l
0x00043ed5      4010           bra @@0x10:8
0x00043ed7      1e0a           subx r0h,r2l
0x00043ed9      0eae           addx r2l,r6l
0x00043edb      0243           stc ccr,r3h
0x00043edd      d618           xor #0x18:8,r6h
0x00043edf      ee0c           and #0xc:8,r6l
0x00043ee1      e817           and #0x17:8,r0l
0x00043ee3      5017           mulxu r1h,r7
0x00043ee5      7010           bset #0x1:3,r0h
0x00043ee7      3078           mov.b r0h,@0x78:8
0x00043ee9      006b           nop
0x00043eeb      ae00           cmp.b #0x0:8,r6l
0x00043eed      4010           bra @@0x10:8
0x00043eef      1e0a           subx r0h,r2l
0x00043ef1      0eae           addx r2l,r6l
0x00043ef3      0243           stc ccr,r3h
0x00043ef5      ea18           and #0x18:8,r2l
0x00043ef7      886e           add.b #0x6e:8,r0l
0x00043ef9      f800           mov.b #0x0:8,r0l
0x00043efb      cd7a           or #0x7a:8,r5l
0x00043efd      0000           nop
0x00043eff      4009           bra @@0x9:8
0x00043f01      c201           or #0x1:8,r2h
0x00043f03      006f           nop
0x00043f05      f000           mov.b #0x0:8,r0h
0x00043f07      c07a           or #0x7a:8,r0h
0x00043f09      0000           nop
0x00043f0b      400f           bra @@0xf:8
0x00043f0d      ce01           or #0x1:8,r6l
0x00043f0f      006f           nop
0x00043f11      f000           mov.b #0x0:8,r0h
0x00043f13      bc7a           subx #0x7a:8,r4l
0x00043f15      0000           nop
0x00043f17      400f           bra @@0xf:8
0x00043f19      ae01           cmp.b #0x1:8,r6l
0x00043f1b      006f           nop
0x00043f1d      f000           mov.b #0x0:8,r0h
0x00043f1f      c47a           or #0x7a:8,r4h
0x00043f21      0000           nop
0x00043f23      400f           bra @@0xf:8
0x00043f25      ee01           and #0x1:8,r6l
0x00043f27      006f           nop
0x00043f29      f000           mov.b #0x0:8,r0h
0x00043f2b      c87a           or #0x7a:8,r0l
0x00043f2d      0600           andc #0x0:8,ccr
0x00043f2f      0000           nop
0x00043f31      0401           orc #0x1:8,ccr
0x00043f33      006f           nop
0x00043f35      7000           bset #0x0:3,r0h
0x00043f37      bc0a           subx #0xa:8,r4l
0x00043f39      e001           and #0x1:8,r0h
0x00043f3b      006f           nop
0x00043f3d      f000           mov.b #0x0:8,r0h
0x00043f3f      5001           mulxu r0h,r1
0x00043f41      006f           nop
0x00043f43      7100           bnot #0x0:3,r0h
0x00043f45      c40a           or #0xa:8,r4h
0x00043f47      e101           and #0x1:8,r1h
0x00043f49      006f           nop
0x00043f4b      f100           mov.b #0x0:8,r1h
0x00043f4d      4c01           bge @@0x1:8
0x00043f4f      006f           nop
0x00043f51      7200           bclr #0x0:3,r0h
0x00043f53      c80a           or #0xa:8,r0l
0x00043f55      e201           and #0x1:8,r2h
0x00043f57      006f           nop
0x00043f59      f200           mov.b #0x0:8,r2h
0x00043f5b      987a           addx #0x7a:8,r0l
0x00043f5d      0000           nop
0x00043f5f      4010           bra @@0x10:8
0x00043f61      78             invalid
0x00043f62      0ae0           inc r0h
0x00043f64      01006ff0       sleep
0x00043f68      00b4           nop
0x00043f6a      7a             invalid
0x00043f6b      0000           nop
0x00043f6d      4010           bra @@0x10:8
0x00043f6f      880a           add.b #0xa:8,r0l
0x00043f71      e001           and #0x1:8,r0h
0x00043f73      006f           nop
0x00043f75      f000           mov.b #0x0:8,r0h
0x00043f77      b801           subx #0x1:8,r0l
0x00043f79      006f           nop
0x00043f7b      7000           bset #0x0:3,r0h
0x00043f7d      bc0b           subx #0xb:8,r4l
0x00043f7f      900b           addx #0xb:8,r0h
0x00043f81      9001           addx #0x1:8,r0h
0x00043f83      006f           nop
0x00043f85      f000           mov.b #0x0:8,r0h
0x00043f87      8c01           add.b #0x1:8,r4l
0x00043f89      006f           nop
0x00043f8b      7000           bset #0x0:3,r0h
0x00043f8d      c40b           or #0xb:8,r4h
0x00043f8f      900b           addx #0xb:8,r0h
0x00043f91      9001           addx #0x1:8,r0h
0x00043f93      006f           nop
0x00043f95      f000           mov.b #0x0:8,r0h
0x00043f97      6001           bset r0h,r1h
0x00043f99      006f           nop
0x00043f9b      7000           bset #0x0:3,r0h
0x00043f9d      c80b           or #0xb:8,r0l
0x00043f9f      900b           addx #0xb:8,r0h
0x00043fa1      9001           addx #0x1:8,r0h
0x00043fa3      006f           nop
0x00043fa5      f000           mov.b #0x0:8,r0h
0x00043fa7      947a           addx #0x7a:8,r4h
0x00043fa9      0000           nop
0x00043fab      4010           bra @@0x10:8
0x00043fad      8001           add.b #0x1:8,r0h
0x00043faf      006f           nop
0x00043fb1      f000           mov.b #0x0:8,r0h
0x00043fb3      9c7a           addx #0x7a:8,r4l
0x00043fb5      0000           nop
0x00043fb7      4010           bra @@0x10:8
0x00043fb9      9001           addx #0x1:8,r0h
0x00043fbb      006f           nop
0x00043fbd      f000           mov.b #0x0:8,r0h
0x00043fbf      a001           cmp.b #0x1:8,r0h
0x00043fc1      006f           nop
0x00043fc3      7000           bset #0x0:3,r0h
0x00043fc5      bc7a           subx #0x7a:8,r4l
0x00043fc7      1000           shll r0h
0x00043fc9      0000           nop
0x00043fcb      0c01           mov.b r0h,r1h
0x00043fcd      006f           nop
0x00043fcf      f000           mov.b #0x0:8,r0h
0x00043fd1      8801           add.b #0x1:8,r0l
0x00043fd3      006f           nop
0x00043fd5      7000           bset #0x0:3,r0h
0x00043fd7      c47a           or #0x7a:8,r4h
0x00043fd9      1000           shll r0h
0x00043fdb      0000           nop
0x00043fdd      0c01           mov.b r0h,r1h
0x00043fdf      006f           nop
0x00043fe1      f000           mov.b #0x0:8,r0h
0x00043fe3      9001           addx #0x1:8,r0h
0x00043fe5      006f           nop
0x00043fe7      7000           bset #0x0:3,r0h
0x00043fe9      c87a           or #0x7a:8,r0l
0x00043feb      1000           shll r0h
0x00043fed      0000           nop
0x00043fef      0c01           mov.b r0h,r1h
0x00043ff1      006f           nop
0x00043ff3      f000           mov.b #0x0:8,r0h
0x00043ff5      487a           bvc @@0x7a:8
0x00043ff7      0000           nop
0x00043ff9      4010           bra @@0x10:8
0x00043ffb      8401           add.b #0x1:8,r4h
0x00043ffd      006f           nop
0x00043fff      f000           mov.b #0x0:8,r0h
0x00044001      a87a           cmp.b #0x7a:8,r0l
0x00044003      0000           nop
0x00044005      4010           bra @@0x10:8
0x00044007      9401           addx #0x1:8,r4h
0x00044009      006f           nop
0x0004400b      f000           mov.b #0x0:8,r0h
0x0004400d      ac7a           cmp.b #0x7a:8,r4l
0x0004400f      0000           nop
0x00044011      400f           bra @@0xf:8
0x00044013      de01           xor #0x1:8,r6l
0x00044015      006f           nop
0x00044017      f000           mov.b #0x0:8,r0h
0x00044019      547a           rts
0x0004401b      0000           nop
0x0004401d      400f           bra @@0xf:8
0x0004401f      be01           subx #0x1:8,r6l
0x00044021      006f           nop
0x00044023      f000           mov.b #0x0:8,r0h
0x00044025      58             invalid
0x00044026      7a             invalid
0x00044027      0000           nop
0x00044029      400f           bra @@0xf:8
0x0004402b      fe01           mov.b #0x1:8,r6l
0x0004402d      006f           nop
0x0004402f      f000           mov.b #0x0:8,r0h
0x00044031      5c             invalid
0x00044032      01006f70       sleep
0x00044036      0050           nop
0x00044038      7a             invalid
0x00044039      1000           shll r0h
0x0004403b      0000           nop
0x0004403d      1001           shll r1h
0x0004403f      006f           nop
0x00044041      f000           mov.b #0x0:8,r0h
0x00044043      64             invalid
0x00044044      7a             invalid
0x00044045      1100           shlr r0h
0x00044047      0000           nop
0x00044049      1001           shll r1h
0x0004404b      006f           nop
0x0004404d      f100           mov.b #0x0:8,r1h
0x0004404f      687a           mov.b @r7,r2l
0x00044051      1200           rotxl r0h
0x00044053      0000           nop
0x00044055      1001           shll r1h
0x00044057      006f           nop
0x00044059      f200           mov.b #0x0:8,r2h
0x0004405b      6c01           mov.b @r0+,r1h
0x0004405d      006f           nop
0x0004405f      7000           bset #0x0:3,r0h
0x00044061      8c7a           add.b #0x7a:8,r4l
0x00044063      1000           shll r0h
0x00044065      0000           nop
0x00044067      1001           shll r1h
0x00044069      006f           nop
0x0004406b      f000           mov.b #0x0:8,r0h
0x0004406d      7001           bset #0x0:3,r1h
0x0004406f      006f           nop
0x00044071      7000           bset #0x0:3,r0h
0x00044073      607a           bset r7h,r2l
0x00044075      1000           shll r0h
0x00044077      0000           nop
0x00044079      1001           shll r1h
0x0004407b      006f           nop
0x0004407d      f000           mov.b #0x0:8,r0h
0x0004407f      7401           bor #0x0:3,r1h
0x00044081      006f           nop
0x00044083      7000           bset #0x0:3,r0h
0x00044085      947a           addx #0x7a:8,r4h
0x00044087      1000           shll r0h
0x00044089      0000           nop
0x0004408b      1001           shll r1h
0x0004408d      006f           nop
0x0004408f      f000           mov.b #0x0:8,r0h
0x00044091      78             invalid
0x00044092      01006f70       sleep
0x00044096      0088           nop
0x00044098      7a             invalid
0x00044099      1000           shll r0h
0x0004409b      0000           nop
0x0004409d      1001           shll r1h
0x0004409f      006f           nop
0x000440a1      f000           mov.b #0x0:8,r0h
0x000440a3      7c01006f       biand #0x6:3,@r0
0x000440a7      7000           bset #0x0:3,r0h
0x000440a9      907a           addx #0x7a:8,r0h
0x000440ab      1000           shll r0h
0x000440ad      0000           nop
0x000440af      1001           shll r1h
0x000440b1      006f           nop
0x000440b3      f000           mov.b #0x0:8,r0h
0x000440b5      8001           add.b #0x1:8,r0h
0x000440b7      006f           nop
0x000440b9      7000           bset #0x0:3,r0h
0x000440bb      487a           bvc @@0x7a:8
0x000440bd      1000           shll r0h
0x000440bf      0000           nop
0x000440c1      1001           shll r1h
0x000440c3      006f           nop
0x000440c5      f000           mov.b #0x0:8,r0h
0x000440c7      847a           add.b #0x7a:8,r4h
0x000440c9      1600           and r0h,r0h
0x000440cb      400f           bra @@0xf:8
0x000440cd      8401           add.b #0x1:8,r4h
0x000440cf      006f           nop
0x000440d1      f600           mov.b #0x0:8,r6h
0x000440d3      b05a           subx #0x5a:8,r0h
0x000440d5      044a           orc #0x4a:8,ccr
0x000440d7      6a1a806e       mov.b @0x806e:16,r2l
0x000440db      78             invalid
0x000440dc      00cd           nop
0x000440de      78             invalid
0x000440df      006a           nop
0x000440e1      2e00           mov.b @0x0:8,r6l
0x000440e3      400f           bra @@0xf:8
0x000440e5      5646           rte
0x000440e7      04fe           orc #0xfe:8,ccr
0x000440e9      01400aae       sleep
0x000440ed      0546           xorc #0x46:8,ccr
0x000440ef      0418           orc #0x18:8,ccr
0x000440f1      ee40           and #0x40:8,r6l
0x000440f3      028e           stc ccr,r6l
0x000440f5      ffae           mov.b #0xae:8,r7l
0x000440f7      0146386a       sleep
0x000440fb      2800           mov.b @0x0:8,r0l
0x000440fd      400d           bra @@0xd:8
0x000440ff      43a8           bls @@0xa8:8
0x00044101      01462e01       sleep
0x00044105      006f           nop
0x00044107      7000           bset #0x0:3,r0h
0x00044109      c06e           or #0x6e:8,r0h
0x0004410b      0800           add.b r0h,r0h
0x0004410d      3217           mov.b r2h,@0x17:8
0x0004410f      5017           mulxu r1h,r7
0x00044111      1079           shal r1l
0x00044113      6000           bset r0h,r0h
0x00044115      0211           stc ccr,r1h
0x00044117      900c           addx #0xc:8,r0h
0x00044119      e917           and #0x17:8,r1l
0x0004411b      5117           divxu r1h,r7
0x0004411d      7178           bnot #0x7:3,r0l
0x0004411f      106a           shal r2l
0x00044121      a800           cmp.b #0x0:8,r0l
0x00044123      400f           bra @@0xf:8
0x00044125      3579           mov.b r5h,@0x79:8
0x00044127      01002e01       sleep
0x0004412b      006f           nop
0x0004412d      7000           bset #0x0:3,r0h
0x0004412f      c040           or #0x40:8,r0h
0x00044131      540c           rts
0x00044133      e817           and #0x17:8,r0l
0x00044135      5017           mulxu r1h,r7
0x00044137      7001           bset #0x0:3,r1h
0x00044139      006f           nop
0x0004413b      f000           mov.b #0x0:8,r0h
0x0004413d      ce01           or #0x1:8,r6l
0x0004413f      006f           nop
0x00044141      f000           mov.b #0x0:8,r0h
0x00044143      3401           mov.b r4h,@0x1:8
0x00044145      006f           nop
0x00044147      7000           bset #0x0:3,r0h
0x00044149      ce7a           or #0x7a:8,r6l
0x0004414b      01000000       sleep
0x0004414f      3a5e           mov.b r2l,@0x5e:8
0x00044151      0163ea7a       sleep
0x00044155      1000           shll r0h
0x00044157      4009           bra @@0x9:8
0x00044159      fc01           mov.b #0x1:8,r4l
0x0004415b      006f           nop
0x0004415d      f000           mov.b #0x0:8,r0h
0x0004415f      a46e           cmp.b #0x6e:8,r4h
0x00044161      0800           add.b r0h,r0h
0x00044163      3217           mov.b r2h,@0x17:8
0x00044165      5017           mulxu r1h,r7
0x00044167      1079           shal r1l
0x00044169      6000           bset r0h,r0h
0x0004416b      0211           stc ccr,r1h
0x0004416d      9001           addx #0x1:8,r0h
0x0004416f      006f           nop
0x00044171      7100           bnot #0x0:3,r0h
0x00044173      3478           mov.b r4h,@0x78:8
0x00044175      106a           shal r2l
0x00044177      a800           cmp.b #0x0:8,r0l
0x00044179      400f           bra @@0xf:8
0x0004417b      3579           mov.b r5h,@0x79:8
0x0004417d      01002e01       sleep
0x00044181      006f           nop
0x00044183      7000           bset #0x0:3,r0h
0x00044185      a45e           cmp.b #0x5e:8,r4h
0x00044187      01236001       sleep
0x0004418b      006f           nop
0x0004418d      f000           mov.b #0x0:8,r0h
0x0004418f      ce6a           or #0x6a:8,r6l
0x00044191      2800           mov.b @0x0:8,r0l
0x00044193      4007           bra @@0x7:8
0x00044195      73a8           btst #0x2:3,r0l
0x00044197      0258           stc ccr,r0l
0x00044199      6006           bset r0h,r6h
0x0004419b      0e01           addx r0h,r1h
0x0004419d      006f           nop
0x0004419f      7000           bset #0x0:3,r0h
0x000441a1      ce58           or #0x58:8,r6l
0x000441a3      6005           bset r0h,r5h
0x000441a5      1c68           cmp.b r6h,r0l
0x000441a7      4858           bvc @@0x58:8
0x000441a9      6002           bset r0h,r2h
0x000441ab      9e0c           addx #0xc:8,r6l
0x000441ad      e847           and #0x47:8,r0l
0x000441af      16a8           and r2l,r0l
0x000441b1      01587000       sleep
0x000441b5      aca8           cmp.b #0xa8:8,r4l
0x000441b7      0258           stc ccr,r0l
0x000441b9      7001           bset #0x0:3,r1h
0x000441bb      46a8           bne @@0xa8:8
0x000441bd      0358           ldc r0l,ccr
0x000441bf      7001           bset #0x0:3,r1h
0x000441c1      e45a           and #0x5a:8,r4h
0x000441c3      0446           orc #0x46:8,ccr
0x000441c5      f001           mov.b #0x1:8,r0h
0x000441c7      006b           nop
0x000441c9      2100           mov.b @0x0:8,r1h
0x000441cb      4010           bra @@0x10:8
0x000441cd      78             invalid
0x000441ce      7a             invalid
0x000441cf      0000           nop
0x000441d1      0000           nop
0x000441d3      300a           mov.b r0h,@0xa:8
0x000441d5      f05e           mov.b #0x5e:8,r0h
0x000441d7      0164806f       sleep
0x000441db      3101           mov.b r1h,@0x1:8
0x000441dd      c001           or #0x1:8,r0h
0x000441df      006f           nop
0x000441e1      f000           mov.b #0x0:8,r0h
0x000441e3      247a           mov.b @0x7a:8,r4h
0x000441e5      0000           nop
0x000441e7      0000           nop
0x000441e9      280a           mov.b @0xa:8,r0l
0x000441eb      f05e           mov.b #0x5e:8,r0h
0x000441ed      0164fe7a       sleep
0x000441f1      010004a5       sleep
0x000441f5      78             invalid
0x000441f6      0f82           daa r2h
0x000441f8      7a             invalid
0x000441f9      0000           nop
0x000441fb      0000           nop
0x000441fd      1c0a           cmp.b r0h,r2l
0x000441ff      f05e           mov.b #0x5e:8,r0h
0x00044201      0159a401       sleep
0x00044205      006f           nop
0x00044207      7100           bnot #0x0:3,r0h
0x00044209      240f           mov.b @0xf:8,r4h
0x0004420b      827a           add.b #0x7a:8,r2h
0x0004420d      0000           nop
0x0004420f      0000           nop
0x00044211      140a           or r0h,r2l
0x00044213      f05e           mov.b #0x5e:8,r0h
0x00044215      01603001       sleep
0x00044219      006b           nop
0x0004421b      2100           mov.b @0x0:8,r1h
0x0004421d      4010           bra @@0x10:8
0x0004421f      8801           add.b #0x1:8,r0l
0x00044221      006f           nop
0x00044223      f000           mov.b #0x0:8,r0h
0x00044225      087a           add.b r7h,r2l
0x00044227      0000           nop
0x00044229      0000           nop
0x0004422b      0c0a           mov.b r0h,r2l
0x0004422d      f05e           mov.b #0x5e:8,r0h
0x0004422f      015f3401       sleep
0x00044233      006f           nop
0x00044235      7100           bnot #0x0:3,r0h
0x00044237      080f           add.b r0h,r7l
0x00044239      820f           add.b #0xf:8,r2h
0x0004423b      f05e           mov.b #0x5e:8,r0h
0x0004423d      0155185e       sleep
0x00044241      015d2e01       sleep
0x00044245      006f           nop
0x00044247      7100           bnot #0x0:3,r0h
0x00044249      c801           or #0x1:8,r0l
0x0004424b      0069           nop
0x0004424d      9001           addx #0x1:8,r0h
0x0004424f      006f           nop
0x00044251      7100           bnot #0x0:3,r0h
0x00044253      c401           or #0x1:8,r4h
0x00044255      0069           nop
0x00044257      9001           addx #0x1:8,r0h
0x00044259      006f           nop
0x0004425b      7100           bnot #0x0:3,r0h
0x0004425d      bc5a           subx #0x5a:8,r4l
0x0004425f      0443           orc #0x43:8,ccr
0x00044261      9e01           addx #0x1:8,r6l
0x00044263      006f           nop
0x00044265      7100           bnot #0x0:3,r0h
0x00044267      b401           subx #0x1:8,r4h
0x00044269      0069           nop
0x0004426b      117a           shar r2l
0x0004426d      0000           nop
0x0004426f      0000           nop
0x00044271      300a           mov.b r0h,@0xa:8
0x00044273      f05e           mov.b #0x5e:8,r0h
0x00044275      0164806f       sleep
0x00044279      3101           mov.b r1h,@0x1:8
0x0004427b      c201           or #0x1:8,r2h
0x0004427d      006f           nop
0x0004427f      f000           mov.b #0x0:8,r0h
0x00044281      247a           mov.b @0x7a:8,r4h
0x00044283      0000           nop
0x00044285      0000           nop
0x00044287      280a           mov.b @0xa:8,r0l
0x00044289      f05e           mov.b #0x5e:8,r0h
0x0004428b      0164fe7a       sleep
0x0004428f      010004a5       sleep
0x00044293      78             invalid
0x00044294      0f82           daa r2h
0x00044296      7a             invalid
0x00044297      0000           nop
0x00044299      0000           nop
0x0004429b      1c0a           cmp.b r0h,r2l
0x0004429d      f05e           mov.b #0x5e:8,r0h
0x0004429f      0159a401       sleep
0x000442a3      006f           nop
0x000442a5      7100           bnot #0x0:3,r0h
0x000442a7      240f           mov.b @0xf:8,r4h
0x000442a9      827a           add.b #0x7a:8,r2h
0x000442ab      0000           nop
0x000442ad      0000           nop
0x000442af      140a           or r0h,r2l
0x000442b1      f05e           mov.b #0x5e:8,r0h
0x000442b3      01603001       sleep
0x000442b7      006f           nop
0x000442b9      7100           bnot #0x0:3,r0h
0x000442bb      b801           subx #0x1:8,r0l
0x000442bd      0069           nop
0x000442bf      1101           shlr r1h
0x000442c1      006f           nop
0x000442c3      f000           mov.b #0x0:8,r0h
0x000442c5      087a           add.b r7h,r2l
0x000442c7      0000           nop
0x000442c9      0000           nop
0x000442cb      0c0a           mov.b r0h,r2l
0x000442cd      f05e           mov.b #0x5e:8,r0h
0x000442cf      015f3401       sleep
0x000442d3      006f           nop
0x000442d5      7100           bnot #0x0:3,r0h
0x000442d7      080f           add.b r0h,r7l
0x000442d9      820f           add.b #0xf:8,r2h
0x000442db      f05e           mov.b #0x5e:8,r0h
0x000442dd      0155185e       sleep
0x000442e1      015d2e01       sleep
0x000442e5      006f           nop
0x000442e7      7100           bnot #0x0:3,r0h
0x000442e9      9801           addx #0x1:8,r0l
0x000442eb      0069           nop
0x000442ed      9001           addx #0x1:8,r0h
0x000442ef      006f           nop
0x000442f1      7100           bnot #0x0:3,r0h
0x000442f3      4c01           bge @@0x1:8
0x000442f5      0069           nop
0x000442f7      9001           addx #0x1:8,r0h
0x000442f9      006f           nop
0x000442fb      7100           bnot #0x0:3,r0h
0x000442fd      505a           mulxu r5h,r2
0x000442ff      0443           orc #0x43:8,ccr
0x00044301      9e01           addx #0x1:8,r6l
0x00044303      006f           nop
0x00044305      7100           bnot #0x0:3,r0h
0x00044307      9c01           addx #0x1:8,r4l
0x00044309      0069           nop
0x0004430b      117a           shar r2l
0x0004430d      0000           nop
0x0004430f      0000           nop
0x00044311      300a           mov.b r0h,@0xa:8
0x00044313      f05e           mov.b #0x5e:8,r0h
0x00044315      0164806f       sleep
0x00044319      3101           mov.b r1h,@0x1:8
0x0004431b      c401           or #0x1:8,r4h
0x0004431d      006f           nop
0x0004431f      f000           mov.b #0x0:8,r0h
0x00044321      247a           mov.b @0x7a:8,r4h
0x00044323      0000           nop
0x00044325      0000           nop
0x00044327      280a           mov.b @0xa:8,r0l
0x00044329      f05e           mov.b #0x5e:8,r0h
0x0004432b      0164fe7a       sleep
0x0004432f      010004a5       sleep
0x00044333      78             invalid
0x00044334      0f82           daa r2h
0x00044336      7a             invalid
0x00044337      0000           nop
0x00044339      0000           nop
0x0004433b      1c0a           cmp.b r0h,r2l
0x0004433d      f05e           mov.b #0x5e:8,r0h
0x0004433f      0159a401       sleep
0x00044343      006f           nop
0x00044345      7100           bnot #0x0:3,r0h
0x00044347      240f           mov.b @0xf:8,r4h
0x00044349      827a           add.b #0x7a:8,r2h
0x0004434b      0000           nop
0x0004434d      0000           nop
0x0004434f      140a           or r0h,r2l
0x00044351      f05e           mov.b #0x5e:8,r0h
0x00044353      01603001       sleep
0x00044357      006f           nop
0x00044359      7100           bnot #0x0:3,r0h
0x0004435b      a001           cmp.b #0x1:8,r0h
0x0004435d      0069           nop
0x0004435f      1101           shlr r1h
0x00044361      006f           nop
0x00044363      f000           mov.b #0x0:8,r0h
0x00044365      087a           add.b r7h,r2l
0x00044367      0000           nop
0x00044369      0000           nop
0x0004436b      0c0a           mov.b r0h,r2l
0x0004436d      f05e           mov.b #0x5e:8,r0h
0x0004436f      015f3401       sleep
0x00044373      006f           nop
0x00044375      7100           bnot #0x0:3,r0h
0x00044377      080f           add.b r0h,r7l
0x00044379      820f           add.b #0xf:8,r2h
0x0004437b      f05e           mov.b #0x5e:8,r0h
0x0004437d      0155185e       sleep
0x00044381      015d2e01       sleep
0x00044385      006f           nop
0x00044387      7100           bnot #0x0:3,r0h
0x00044389      9401           addx #0x1:8,r4h
0x0004438b      0069           nop
0x0004438d      9001           addx #0x1:8,r0h
0x0004438f      006f           nop
0x00044391      7100           bnot #0x0:3,r0h
0x00044393      6001           bset r0h,r1h
0x00044395      0069           nop
0x00044397      9001           addx #0x1:8,r0h
0x00044399      006f           nop
0x0004439b      7100           bnot #0x0:3,r0h
0x0004439d      8c01           add.b #0x1:8,r4l
0x0004439f      0069           nop
0x000443a1      905a           addx #0x5a:8,r0h
0x000443a3      0446           orc #0x46:8,ccr
0x000443a5      f001           mov.b #0x1:8,r0h
0x000443a7      006f           nop
0x000443a9      7100           bnot #0x0:3,r0h
0x000443ab      a801           cmp.b #0x1:8,r0l
0x000443ad      0069           nop
0x000443af      117a           shar r2l
0x000443b1      0000           nop
0x000443b3      0000           nop
0x000443b5      300a           mov.b r0h,@0xa:8
0x000443b7      f05e           mov.b #0x5e:8,r0h
0x000443b9      0164806f       sleep
0x000443bd      3101           mov.b r1h,@0x1:8
0x000443bf      c601           or #0x1:8,r6h
0x000443c1      006f           nop
0x000443c3      f000           mov.b #0x0:8,r0h
0x000443c5      247a           mov.b @0x7a:8,r4h
0x000443c7      0000           nop
0x000443c9      0000           nop
0x000443cb      280a           mov.b @0xa:8,r0l
0x000443cd      f05e           mov.b #0x5e:8,r0h
0x000443cf      0164fe7a       sleep
0x000443d3      010004a5       sleep
0x000443d7      78             invalid
0x000443d8      0f82           daa r2h
0x000443da      7a             invalid
0x000443db      0000           nop
0x000443dd      0000           nop
0x000443df      1c0a           cmp.b r0h,r2l
0x000443e1      f05e           mov.b #0x5e:8,r0h
0x000443e3      0159a401       sleep
0x000443e7      006f           nop
0x000443e9      7100           bnot #0x0:3,r0h
0x000443eb      240f           mov.b @0xf:8,r4h
0x000443ed      827a           add.b #0x7a:8,r2h
0x000443ef      0000           nop
0x000443f1      0000           nop
0x000443f3      140a           or r0h,r2l
0x000443f5      f05e           mov.b #0x5e:8,r0h
0x000443f7      01603001       sleep
0x000443fb      006f           nop
0x000443fd      7100           bnot #0x0:3,r0h
0x000443ff      ac01           cmp.b #0x1:8,r4l
0x00044401      0069           nop
0x00044403      1101           shlr r1h
0x00044405      006f           nop
0x00044407      f000           mov.b #0x0:8,r0h
0x00044409      087a           add.b r7h,r2l
0x0004440b      0000           nop
0x0004440d      0000           nop
0x0004440f      0c0a           mov.b r0h,r2l
0x00044411      f05e           mov.b #0x5e:8,r0h
0x00044413      015f3401       sleep
0x00044417      006f           nop
0x00044419      7100           bnot #0x0:3,r0h
0x0004441b      080f           add.b r0h,r7l
0x0004441d      820f           add.b #0xf:8,r2h
0x0004441f      f05e           mov.b #0x5e:8,r0h
0x00044421      0155185e       sleep
0x00044425      015d2e01       sleep
0x00044429      006f           nop
0x0004442b      7100           bnot #0x0:3,r0h
0x0004442d      4801           bvc @@0x1:8
0x0004442f      0069           nop
0x00044431      9001           addx #0x1:8,r0h
0x00044433      006f           nop
0x00044435      7100           bnot #0x0:3,r0h
0x00044437      9001           addx #0x1:8,r0h
0x00044439      0069           nop
0x0004443b      9001           addx #0x1:8,r0h
0x0004443d      006f           nop
0x0004443f      7100           bnot #0x0:3,r0h
0x00044441      8801           add.b #0x1:8,r0l
0x00044443      0069           nop
0x00044445      905a           addx #0x5a:8,r0h
0x00044447      0446           orc #0x46:8,ccr
0x00044449      f00c           mov.b #0xc:8,r0h
0x0004444b      e847           and #0x47:8,r0l
0x0004444d      16a8           and r2l,r0l
0x0004444f      01587000       sleep
0x00044453      88a8           add.b #0xa8:8,r0l
0x00044455      0258           stc ccr,r0l
0x00044457      7000           bset #0x0:3,r0h
0x00044459      fea8           mov.b #0xa8:8,r6l
0x0004445b      0358           ldc r0l,ccr
0x0004445d      7001           bset #0x0:3,r1h
0x0004445f      745a           bor #0x5:3,r2l
0x00044461      0446           orc #0x46:8,ccr
0x00044463      7401           bor #0x0:3,r1h
0x00044465      006b           nop
0x00044467      2100           mov.b @0x0:8,r1h
0x00044469      4010           bra @@0x10:8
0x0004446b      78             invalid
0x0004446c      7a             invalid
0x0004446d      0000           nop
0x0004446f      0000           nop
0x00044471      300a           mov.b r0h,@0xa:8
0x00044473      f05e           mov.b #0x5e:8,r0h
0x00044475      0164800f       sleep
0x00044479      817a           add.b #0x7a:8,r1h
0x0004447b      0200           stc ccr,r0h
0x0004447d      04a5           orc #0xa5:8,ccr
0x0004447f      807a           add.b #0x7a:8,r0h
0x00044481      0000           nop
0x00044483      0000           nop
0x00044485      280a           mov.b @0xa:8,r0l
0x00044487      f05e           mov.b #0x5e:8,r0h
0x00044489      01603001       sleep
0x0004448d      006b           nop
0x0004448f      2100           mov.b @0x0:8,r1h
0x00044491      4010           bra @@0x10:8
0x00044493      8801           add.b #0x1:8,r0l
0x00044495      006f           nop
0x00044497      f000           mov.b #0x0:8,r0h
0x00044499      1c7a           cmp.b r7h,r2l
0x0004449b      0000           nop
0x0004449d      0000           nop
0x0004449f      200a           mov.b @0xa:8,r0h
0x000444a1      f05e           mov.b #0x5e:8,r0h
0x000444a3      015f3401       sleep
0x000444a7      006f           nop
0x000444a9      7100           bnot #0x0:3,r0h
0x000444ab      1c0f           cmp.b r0h,r7l
0x000444ad      827a           add.b #0x7a:8,r2h
0x000444af      0000           nop
0x000444b1      0000           nop
0x000444b3      140a           or r0h,r2l
0x000444b5      f05e           mov.b #0x5e:8,r0h
0x000444b7      0155185e       sleep
0x000444bb      015d2e01       sleep
0x000444bf      006f           nop
0x000444c1      7100           bnot #0x0:3,r0h
0x000444c3      5c             invalid
0x000444c4      01006990       sleep
0x000444c8      01006f71       sleep
0x000444cc      0058           nop
0x000444ce      01006990       sleep
0x000444d2      01006f71       sleep
0x000444d6      0054           nop
0x000444d8      5a044670       jmp @0x4670:16
0x000444dc      01006f71       sleep
0x000444e0      00b4           nop
0x000444e2      01006911       sleep
0x000444e6      7a             invalid
0x000444e7      0000           nop
0x000444e9      0000           nop
0x000444eb      300a           mov.b r0h,@0xa:8
0x000444ed      f05e           mov.b #0x5e:8,r0h
0x000444ef      0164800f       sleep
0x000444f3      817a           add.b #0x7a:8,r1h
0x000444f5      0200           stc ccr,r0h
0x000444f7      04a5           orc #0xa5:8,ccr
0x000444f9      887a           add.b #0x7a:8,r0l
0x000444fb      0000           nop
0x000444fd      0000           nop
0x000444ff      280a           mov.b @0xa:8,r0l
0x00044501      f05e           mov.b #0x5e:8,r0h
0x00044503      01603001       sleep
0x00044507      006f           nop
0x00044509      7100           bnot #0x0:3,r0h
0x0004450b      b801           subx #0x1:8,r0l
0x0004450d      0069           nop
0x0004450f      1101           shlr r1h
0x00044511      006f           nop
0x00044513      f000           mov.b #0x0:8,r0h
0x00044515      1c7a           cmp.b r7h,r2l
0x00044517      0000           nop
0x00044519      0000           nop
0x0004451b      200a           mov.b @0xa:8,r0h
0x0004451d      f05e           mov.b #0x5e:8,r0h
0x0004451f      015f3401       sleep
0x00044523      006f           nop
0x00044525      7100           bnot #0x0:3,r0h
0x00044527      1c0f           cmp.b r0h,r7l
0x00044529      827a           add.b #0x7a:8,r2h
0x0004452b      0000           nop
0x0004452d      0000           nop
0x0004452f      140a           or r0h,r2l
0x00044531      f05e           mov.b #0x5e:8,r0h
0x00044533      0155185e       sleep
0x00044537      015d2e01       sleep
0x0004453b      006f           nop
0x0004453d      7100           bnot #0x0:3,r0h
0x0004453f      6c01           mov.b @r0+,r1h
0x00044541      0069           nop
0x00044543      9001           addx #0x1:8,r0h
0x00044545      006f           nop
0x00044547      7100           bnot #0x0:3,r0h
0x00044549      6801           mov.b @r0,r1h
0x0004454b      0069           nop
0x0004454d      9001           addx #0x1:8,r0h
0x0004454f      006f           nop
0x00044551      7100           bnot #0x0:3,r0h
0x00044553      64             invalid
0x00044554      5a044670       jmp @0x4670:16
0x00044558      01006f71       sleep
0x0004455c      009c           nop
0x0004455e      01006911       sleep
0x00044562      7a             invalid
0x00044563      0000           nop
0x00044565      0000           nop
0x00044567      300a           mov.b r0h,@0xa:8
0x00044569      f05e           mov.b #0x5e:8,r0h
0x0004456b      0164800f       sleep
0x0004456f      817a           add.b #0x7a:8,r1h
0x00044571      0200           stc ccr,r0h
0x00044573      04a5           orc #0xa5:8,ccr
0x00044575      907a           addx #0x7a:8,r0h
0x00044577      0000           nop
0x00044579      0000           nop
0x0004457b      280a           mov.b @0xa:8,r0l
0x0004457d      f05e           mov.b #0x5e:8,r0h
0x0004457f      01603001       sleep
0x00044583      006f           nop
0x00044585      7100           bnot #0x0:3,r0h
0x00044587      a001           cmp.b #0x1:8,r0h
0x00044589      0069           nop
0x0004458b      1101           shlr r1h
0x0004458d      006f           nop
0x0004458f      f000           mov.b #0x0:8,r0h
0x00044591      1c7a           cmp.b r7h,r2l
0x00044593      0000           nop
0x00044595      0000           nop
0x00044597      200a           mov.b @0xa:8,r0h
0x00044599      f05e           mov.b #0x5e:8,r0h
0x0004459b      015f3401       sleep
0x0004459f      006f           nop
0x000445a1      7100           bnot #0x0:3,r0h
0x000445a3      1c0f           cmp.b r0h,r7l
0x000445a5      827a           add.b #0x7a:8,r2h
0x000445a7      0000           nop
0x000445a9      0000           nop
0x000445ab      140a           or r0h,r2l
0x000445ad      f05e           mov.b #0x5e:8,r0h
0x000445af      0155185e       sleep
0x000445b3      015d2e01       sleep
0x000445b7      006f           nop
0x000445b9      7100           bnot #0x0:3,r0h
0x000445bb      78             invalid
0x000445bc      01006990       sleep
0x000445c0      01006f71       sleep
0x000445c4      0074           nop
0x000445c6      01006990       sleep
0x000445ca      01006f71       sleep
0x000445ce      0070           nop
0x000445d0      5a044670       jmp @0x4670:16
0x000445d4      01006f71       sleep
0x000445d8      00a8           nop
0x000445da      01006911       sleep
0x000445de      7a             invalid
0x000445df      0000           nop
0x000445e1      0000           nop
0x000445e3      300a           mov.b r0h,@0xa:8
0x000445e5      f05e           mov.b #0x5e:8,r0h
0x000445e7      0164806f       sleep
0x000445eb      3101           mov.b r1h,@0x1:8
0x000445ed      ca01           or #0x1:8,r2l
0x000445ef      006f           nop
0x000445f1      f000           mov.b #0x0:8,r0h
0x000445f3      247a           mov.b @0x7a:8,r4h
0x000445f5      0000           nop
0x000445f7      0000           nop
0x000445f9      280a           mov.b @0xa:8,r0l
0x000445fb      f05e           mov.b #0x5e:8,r0h
0x000445fd      0164fe7a       sleep
0x00044601      010004a5       sleep
0x00044605      78             invalid
0x00044606      0f82           daa r2h
0x00044608      7a             invalid
0x00044609      0000           nop
0x0004460b      0000           nop
0x0004460d      1c0a           cmp.b r0h,r2l
0x0004460f      f05e           mov.b #0x5e:8,r0h
0x00044611      0159a401       sleep
0x00044615      006f           nop
0x00044617      7100           bnot #0x0:3,r0h
0x00044619      240f           mov.b @0xf:8,r4h
0x0004461b      827a           add.b #0x7a:8,r2h
0x0004461d      0000           nop
0x0004461f      0000           nop
0x00044621      140a           or r0h,r2l
0x00044623      f05e           mov.b #0x5e:8,r0h
0x00044625      01603001       sleep
0x00044629      006f           nop
0x0004462b      7100           bnot #0x0:3,r0h
0x0004462d      ac01           cmp.b #0x1:8,r4l
0x0004462f      0069           nop
0x00044631      1101           shlr r1h
0x00044633      006f           nop
0x00044635      f000           mov.b #0x0:8,r0h
0x00044637      087a           add.b r7h,r2l
0x00044639      0000           nop
0x0004463b      0000           nop
0x0004463d      0c0a           mov.b r0h,r2l
0x0004463f      f05e           mov.b #0x5e:8,r0h
0x00044641      015f3401       sleep
0x00044645      006f           nop
0x00044647      7100           bnot #0x0:3,r0h
0x00044649      080f           add.b r0h,r7l
0x0004464b      820f           add.b #0xf:8,r2h
0x0004464d      f05e           mov.b #0x5e:8,r0h
0x0004464f      0155185e       sleep
0x00044653      015d2e01       sleep
0x00044657      006f           nop
0x00044659      7100           bnot #0x0:3,r0h
0x0004465b      8401           add.b #0x1:8,r4h
0x0004465d      0069           nop
0x0004465f      9001           addx #0x1:8,r0h
0x00044661      006f           nop
0x00044663      7100           bnot #0x0:3,r0h
0x00044665      8001           add.b #0x1:8,r0h
0x00044667      0069           nop
0x00044669      9001           addx #0x1:8,r0h
0x0004466b      006f           nop
0x0004466d      7100           bnot #0x0:3,r0h
0x0004466f      7c010069       biand #0x6:3,@r0
0x00044673      900c           addx #0xc:8,r0h
0x00044675      e817           and #0x17:8,r0l
0x00044677      5017           mulxu r1h,r7
0x00044679      7001           bset #0x0:3,r1h
0x0004467b      006f           nop
0x0004467d      f000           mov.b #0x0:8,r0h
0x0004467f      a410           cmp.b #0x10:8,r4h
0x00044681      3010           mov.b r0h,@0x10:8
0x00044683      3001           mov.b r0h,@0x1:8
0x00044685      006f           nop
0x00044687      f000           mov.b #0x0:8,r0h
0x00044689      ce0a           or #0xa:8,r6l
0x0004468b      d01a           xor #0x1a:8,r0h
0x0004468d      9168           addx #0x68:8,r1h
0x0004468f      4910           bvs @@0x10:8
0x00044691      3110           mov.b r1h,@0x10:8
0x00044693      3110           mov.b r1h,@0x10:8
0x00044695      3110           mov.b r1h,@0x10:8
0x00044697      317a           mov.b r1h,@0x7a:8
0x00044699      1100           shlr r0h
0x0004469b      400f           bra @@0xf:8
0x0004469d      ce01           or #0x1:8,r6l
0x0004469f      006f           nop
0x000446a1      7200           bclr #0x0:3,r0h
0x000446a3      ce0a           or #0xa:8,r6l
0x000446a5      a101           cmp.b #0x1:8,r1h
0x000446a7      0069           nop
0x000446a9      1101           shlr r1h
0x000446ab      0069           nop
0x000446ad      8101           add.b #0x1:8,r1h
0x000446af      006f           nop
0x000446b1      7000           bset #0x0:3,r0h
0x000446b3      a410           cmp.b #0x10:8,r4h
0x000446b5      3019           mov.b r0h,@0x19:8
0x000446b7      1178           shar r0l
0x000446b9      006b           nop
0x000446bb      a100           cmp.b #0x0:8,r1h
0x000446bd      4010           bra @@0x10:8
0x000446bf      1640           and r4h,r0h
0x000446c1      2e0c           mov.b @0xc:8,r6l
0x000446c3      e817           and #0x17:8,r0l
0x000446c5      5017           mulxu r1h,r7
0x000446c7      7010           bset #0x1:3,r0h
0x000446c9      3010           mov.b r0h,@0x10:8
0x000446cb      301a           mov.b r0h,@0x1a:8
0x000446cd      9168           addx #0x68:8,r1h
0x000446cf      4910           bvs @@0x10:8
0x000446d1      3110           mov.b r1h,@0x10:8
0x000446d3      3110           mov.b r1h,@0x10:8
0x000446d5      3110           mov.b r1h,@0x10:8
0x000446d7      317a           mov.b r1h,@0x7a:8
0x000446d9      1100           shlr r0h
0x000446db      400f           bra @@0xf:8
0x000446dd      ae0a           cmp.b #0xa:8,r6l
0x000446df      810a           add.b #0xa:8,r1h
0x000446e1      d001           xor #0x1:8,r0h
0x000446e3      006f           nop
0x000446e5      7200           bclr #0x0:3,r0h
0x000446e7      ce01           or #0x1:8,r6l
0x000446e9      0069           nop
0x000446eb      8201           add.b #0x1:8,r2h
0x000446ed      0069           nop
0x000446ef      920c           addx #0xc:8,r2h
0x000446f1      e817           and #0x17:8,r0l
0x000446f3      5017           mulxu r1h,r7
0x000446f5      7078           bset #0x7:3,r0l
0x000446f7      006a           nop
0x000446f9      2900           mov.b @0x0:8,r1l
0x000446fb      404e           bra @@0x4e:8
0x000446fd      5046           mulxu r4h,r6
0x000446ff      361a           mov.b r6h,@0x1a:8
0x00044701      800c           add.b #0xc:8,r0h
0x00044703      e810           and #0x10:8,r0l
0x00044705      3010           mov.b r0h,@0x10:8
0x00044707      3001           mov.b r0h,@0x1:8
0x00044709      006f           nop
0x0004470b      f000           mov.b #0x0:8,r0h
0x0004470d      ce01           or #0x1:8,r6l
0x0004470f      006f           nop
0x00044711      7100           bnot #0x0:3,r0h
0x00044713      ce0a           or #0xa:8,r6l
0x00044715      d101           xor #0x1:8,r1h
0x00044717      0069           nop
0x00044719      1101           shlr r1h
0x0004471b      006f           nop
0x0004471d      f000           mov.b #0x0:8,r0h
0x0004471f      2c7a           mov.b @0x7a:8,r4l
0x00044721      0000           nop
0x00044723      0000           nop
0x00044725      300a           mov.b r0h,@0xa:8
0x00044727      f05e           mov.b #0x5e:8,r0h
0x00044729      01648001       sleep
0x0004472d      006b           nop
0x0004472f      2100           mov.b @0x0:8,r1h
0x00044731      400f           bra @@0xf:8
0x00044733      8440           add.b #0x40:8,r4h
0x00044735      361a           mov.b r6h,@0x1a:8
0x00044737      800c           add.b #0xc:8,r0h
0x00044739      e810           and #0x10:8,r0l
0x0004473b      3010           mov.b r0h,@0x10:8
0x0004473d      3001           mov.b r0h,@0x1:8
0x0004473f      006f           nop
0x00044741      f000           mov.b #0x0:8,r0h
0x00044743      ce01           or #0x1:8,r6l
0x00044745      006f           nop
0x00044747      7100           bnot #0x0:3,r0h
0x00044749      ce0a           or #0xa:8,r6l
0x0004474b      d101           xor #0x1:8,r1h
0x0004474d      0069           nop
0x0004474f      1101           shlr r1h
0x00044751      006f           nop
0x00044753      f000           mov.b #0x0:8,r0h
0x00044755      2c7a           mov.b @0x7a:8,r4l
0x00044757      0000           nop
0x00044759      0000           nop
0x0004475b      300a           mov.b r0h,@0xa:8
0x0004475d      f05e           mov.b #0x5e:8,r0h
0x0004475f      01648001       sleep
0x00044763      006f           nop
0x00044765      7100           bnot #0x0:3,r0h
0x00044767      b001           subx #0x1:8,r0h
0x00044769      0069           nop
0x0004476b      1101           shlr r1h
0x0004476d      006f           nop
0x0004476f      f000           mov.b #0x0:8,r0h
0x00044771      207a           mov.b @0x7a:8,r0h
0x00044773      0000           nop
0x00044775      0000           nop
0x00044777      240a           mov.b @0xa:8,r4h
0x00044779      f05e           mov.b #0x5e:8,r0h
0x0004477b      015db401       sleep
0x0004477f      006f           nop
0x00044781      7100           bnot #0x0:3,r0h
0x00044783      200f           mov.b @0xf:8,r0h
0x00044785      827a           add.b #0x7a:8,r2h
0x00044787      0000           nop
0x00044789      0000           nop
0x0004478b      180a           sub.b r0h,r2l
0x0004478d      f05e           mov.b #0x5e:8,r0h
0x0004478f      0159a45e       sleep
0x00044793      015d2e01       sleep
0x00044797      006f           nop
0x00044799      7100           bnot #0x0:3,r0h
0x0004479b      2c01           mov.b @0x1:8,r4l
0x0004479d      0078           nop
0x0004479f      906b           addx #0x6b:8,r0h
0x000447a1      a000           cmp.b #0x0:8,r0h
0x000447a3      406e           bra @@0x6e:8
0x000447a5      765a           band #0x5:3,r2l
0x000447a7      044a           orc #0x4a:8,ccr
0x000447a9      606a           bset r6h,r2l
0x000447ab      2800           mov.b @0x0:8,r0l
0x000447ad      4007           bra @@0x7:8
0x000447af      73a8           btst #0x2:3,r0l
0x000447b1      01470aa8       sleep
0x000447b5      0447           orc #0x47:8,ccr
0x000447b7      06a8           andc #0xa8:8,ccr
0x000447b9      0558           xorc #0x58:8,ccr
0x000447bb      6001           bset r0h,r1h
0x000447bd      b401           subx #0x1:8,r4h
0x000447bf      006f           nop
0x000447c1      7000           bset #0x0:3,r0h
0x000447c3      ce58           or #0x58:8,r6l
0x000447c5      6001           bset r0h,r1h
0x000447c7      7a             invalid
0x000447c8      6848           mov.b @r4,r0l
0x000447ca      58             invalid
0x000447cb      6000           bset r0h,r0h
0x000447cd      aa0c           cmp.b #0xc:8,r2l
0x000447cf      e817           and #0x17:8,r0l
0x000447d1      5017           mulxu r1h,r7
0x000447d3      7001           bset #0x0:3,r1h
0x000447d5      006f           nop
0x000447d7      f000           mov.b #0x0:8,r0h
0x000447d9      a410           cmp.b #0x10:8,r4h
0x000447db      3010           mov.b r0h,@0x10:8
0x000447dd      3001           mov.b r0h,@0x1:8
0x000447df      006f           nop
0x000447e1      f000           mov.b #0x0:8,r0h
0x000447e3      ce1a           or #0x1a:8,r6l
0x000447e5      9168           addx #0x68:8,r1h
0x000447e7      4910           bvs @@0x10:8
0x000447e9      3110           mov.b r1h,@0x10:8
0x000447eb      3110           mov.b r1h,@0x10:8
0x000447ed      3110           mov.b r1h,@0x10:8
0x000447ef      317a           mov.b r1h,@0x7a:8
0x000447f1      1100           shlr r0h
0x000447f3      400f           bra @@0xf:8
0x000447f5      ae0a           cmp.b #0xa:8,r6l
0x000447f7      8101           add.b #0x1:8,r1h
0x000447f9      006f           nop
0x000447fb      7200           bclr #0x0:3,r0h
0x000447fd      a410           cmp.b #0x10:8,r4h
0x000447ff      3210           mov.b r2h,@0x10:8
0x00044801      3210           mov.b r2h,@0x10:8
0x00044803      3201           mov.b r2h,@0x1:8
0x00044805      006f           nop
0x00044807      f100           mov.b #0x0:8,r1h
0x00044809      3401           mov.b r4h,@0x1:8
0x0004480b      0078           nop
0x0004480d      206b           mov.b @0x6b:8,r0h
0x0004480f      2100           mov.b @0x0:8,r1h
0x00044811      04a5           orc #0xa5:8,ccr
0x00044813      58             invalid
0x00044814      7a             invalid
0x00044815      0000           nop
0x00044817      0000           nop
0x00044819      2c0a           mov.b @0xa:8,r4l
0x0004481b      f05e           mov.b #0x5e:8,r0h
0x0004481d      0164807a       sleep
0x00044821      010004a5       sleep
0x00044825      78             invalid
0x00044826      0f82           daa r2h
0x00044828      7a             invalid
0x00044829      0000           nop
0x0004482b      0000           nop
0x0004482d      240a           mov.b @0xa:8,r4h
0x0004482f      f05e           mov.b #0x5e:8,r0h
0x00044831      0159a401       sleep
0x00044835      006f           nop
0x00044837      7100           bnot #0x0:3,r0h
0x00044839      ce01           or #0x1:8,r6l
0x0004483b      0078           nop
0x0004483d      106b           shal r3l
0x0004483f      2100           mov.b @0x0:8,r1h
0x00044841      4010           bra @@0x10:8
0x00044843      78             invalid
0x00044844      01006ff0       sleep
0x00044848      0018           nop
0x0004484a      7a             invalid
0x0004484b      0000           nop
0x0004484d      0000           nop
0x0004484f      1c0a           cmp.b r0h,r2l
0x00044851      f05e           mov.b #0x5e:8,r0h
0x00044853      01648001       sleep
0x00044857      006f           nop
0x00044859      7100           bnot #0x0:3,r0h
0x0004485b      180f           sub.b r0h,r7l
0x0004485d      827a           add.b #0x7a:8,r2h
0x0004485f      0000           nop
0x00044861      0000           nop
0x00044863      100a           shll r2l
0x00044865      f05e           mov.b #0x5e:8,r0h
0x00044867      0160305e       sleep
0x0004486b      015d2e01       sleep
0x0004486f      006f           nop
0x00044871      7100           bnot #0x0:3,r0h
0x00044873      ce5a           or #0x5a:8,r6l
0x00044875      0449           orc #0x49:8,ccr
0x00044877      1e0c           subx r0h,r4l
0x00044879      e817           and #0x17:8,r0l
0x0004487b      5017           mulxu r1h,r7
0x0004487d      7001           bset #0x0:3,r1h
0x0004487f      006f           nop
0x00044881      f000           mov.b #0x0:8,r0h
0x00044883      a410           cmp.b #0x10:8,r4h
0x00044885      3010           mov.b r0h,@0x10:8
0x00044887      3001           mov.b r0h,@0x1:8
0x00044889      006f           nop
0x0004488b      f000           mov.b #0x0:8,r0h
0x0004488d      ce1a           or #0x1a:8,r6l
0x0004488f      9168           addx #0x68:8,r1h
0x00044891      4910           bvs @@0x10:8
0x00044893      3110           mov.b r1h,@0x10:8
0x00044895      3110           mov.b r1h,@0x10:8
0x00044897      3110           mov.b r1h,@0x10:8
0x00044899      317a           mov.b r1h,@0x7a:8
0x0004489b      1100           shlr r0h
0x0004489d      400f           bra @@0xf:8
0x0004489f      ae0a           cmp.b #0xa:8,r6l
0x000448a1      8101           add.b #0x1:8,r1h
0x000448a3      006f           nop
0x000448a5      7200           bclr #0x0:3,r0h
0x000448a7      a410           cmp.b #0x10:8,r4h
0x000448a9      3210           mov.b r2h,@0x10:8
0x000448ab      3210           mov.b r2h,@0x10:8
0x000448ad      3201           mov.b r2h,@0x1:8
0x000448af      006f           nop
0x000448b1      f100           mov.b #0x0:8,r1h
0x000448b3      3401           mov.b r4h,@0x1:8
0x000448b5      0078           nop
0x000448b7      206b           mov.b @0x6b:8,r0h
0x000448b9      2100           mov.b @0x0:8,r1h
0x000448bb      04a5           orc #0xa5:8,ccr
0x000448bd      5c             invalid
0x000448be      7a             invalid
0x000448bf      0000           nop
0x000448c1      0000           nop
0x000448c3      2c0a           mov.b @0xa:8,r4l
0x000448c5      f05e           mov.b #0x5e:8,r0h
0x000448c7      0164807a       sleep
0x000448cb      010004a5       sleep
0x000448cf      78             invalid
0x000448d0      0f82           daa r2h
0x000448d2      7a             invalid
0x000448d3      0000           nop
0x000448d5      0000           nop
0x000448d7      240a           mov.b @0xa:8,r4h
0x000448d9      f05e           mov.b #0x5e:8,r0h
0x000448db      0159a401       sleep
0x000448df      006f           nop
0x000448e1      7100           bnot #0x0:3,r0h
0x000448e3      ce01           or #0x1:8,r6l
0x000448e5      0078           nop
0x000448e7      106b           shal r3l
0x000448e9      2100           mov.b @0x0:8,r1h
0x000448eb      4010           bra @@0x10:8
0x000448ed      78             invalid
0x000448ee      01006ff0       sleep
0x000448f2      0018           nop
0x000448f4      7a             invalid
0x000448f5      0000           nop
0x000448f7      0000           nop
0x000448f9      1c0a           cmp.b r0h,r2l
0x000448fb      f05e           mov.b #0x5e:8,r0h
0x000448fd      01648001       sleep
0x00044901      006f           nop
0x00044903      7100           bnot #0x0:3,r0h
0x00044905      180f           sub.b r0h,r7l
0x00044907      827a           add.b #0x7a:8,r2h
0x00044909      0000           nop
0x0004490b      0000           nop
0x0004490d      100a           shll r2l
0x0004490f      f05e           mov.b #0x5e:8,r0h
0x00044911      0160305e       sleep
0x00044915      015d2e01       sleep
0x00044919      006f           nop
0x0004491b      7100           bnot #0x0:3,r0h
0x0004491d      ce0a           or #0xa:8,r6l
0x0004491f      d101           xor #0x1:8,r1h
0x00044921      0069           nop
0x00044923      9001           addx #0x1:8,r0h
0x00044925      006f           nop
0x00044927      7100           bnot #0x0:3,r0h
0x00044929      3401           mov.b r4h,@0x1:8
0x0004492b      0069           nop
0x0004492d      900c           addx #0xc:8,r0h
0x0004492f      e817           and #0x17:8,r0l
0x00044931      5017           mulxu r1h,r7
0x00044933      7010           bset #0x1:3,r0h
0x00044935      3019           mov.b r0h,@0x19:8
0x00044937      1178           shar r0l
0x00044939      006b           nop
0x0004493b      a100           cmp.b #0x0:8,r1h
0x0004493d      4010           bra @@0x10:8
0x0004493f      1640           and r4h,r0h
0x00044941      680c           mov.b @r0,r4l
0x00044943      e817           and #0x17:8,r0l
0x00044945      5017           mulxu r1h,r7
0x00044947      7010           bset #0x1:3,r0h
0x00044949      3010           mov.b r0h,@0x10:8
0x0004494b      301a           mov.b r0h,@0x1a:8
0x0004494d      9168           addx #0x68:8,r1h
0x0004494f      4910           bvs @@0x10:8
0x00044951      3110           mov.b r1h,@0x10:8
0x00044953      3110           mov.b r1h,@0x10:8
0x00044955      3110           mov.b r1h,@0x10:8
0x00044957      317a           mov.b r1h,@0x7a:8
0x00044959      1100           shlr r0h
0x0004495b      400f           bra @@0xf:8
0x0004495d      ae0a           cmp.b #0xa:8,r6l
0x0004495f      810a           add.b #0xa:8,r1h
0x00044961      d001           xor #0x1:8,r0h
0x00044963      006f           nop
0x00044965      7200           bclr #0x0:3,r0h
0x00044967      ce01           or #0x1:8,r6l
0x00044969      0069           nop
0x0004496b      8201           add.b #0x1:8,r2h
0x0004496d      0069           nop
0x0004496f      9240           addx #0x40:8,r2h
0x00044971      385e           mov.b r0l,@0x5e:8
0x00044973      0395           ldc r5h,ccr
0x00044975      420c           bhi @@0xc:8
0x00044977      e817           and #0x17:8,r0l
0x00044979      5017           mulxu r1h,r7
0x0004497b      7010           bset #0x1:3,r0h
0x0004497d      3010           mov.b r0h,@0x10:8
0x0004497f      3001           mov.b r0h,@0x1:8
0x00044981      006f           nop
0x00044983      f000           mov.b #0x0:8,r0h
0x00044985      ce0a           or #0xa:8,r6l
0x00044987      d01a           xor #0x1a:8,r0h
0x00044989      9168           addx #0x68:8,r1h
0x0004498b      4910           bvs @@0x10:8
0x0004498d      3110           mov.b r1h,@0x10:8
0x0004498f      3110           mov.b r1h,@0x10:8
0x00044991      3110           mov.b r1h,@0x10:8
0x00044993      317a           mov.b r1h,@0x7a:8
0x00044995      1100           shlr r0h
0x00044997      400f           bra @@0xf:8
0x00044999      ce01           or #0x1:8,r6l
0x0004499b      006f           nop
0x0004499d      7200           bclr #0x0:3,r0h
0x0004499f      ce0a           or #0xa:8,r6l
0x000449a1      a101           cmp.b #0x1:8,r1h
0x000449a3      0069           nop
0x000449a5      1101           shlr r1h
0x000449a7      0069           nop
0x000449a9      810c           add.b #0xc:8,r1h
0x000449ab      e817           and #0x17:8,r0l
0x000449ad      5017           mulxu r1h,r7
0x000449af      7078           bset #0x7:3,r0l
0x000449b1      006a           nop
0x000449b3      2900           mov.b @0x0:8,r1l
0x000449b5      404e           bra @@0x4e:8
0x000449b7      5046           mulxu r4h,r6
0x000449b9      361a           mov.b r6h,@0x1a:8
0x000449bb      800c           add.b #0xc:8,r0h
0x000449bd      e810           and #0x10:8,r0l
0x000449bf      3010           mov.b r0h,@0x10:8
0x000449c1      3001           mov.b r0h,@0x1:8
0x000449c3      006f           nop
0x000449c5      f000           mov.b #0x0:8,r0h
0x000449c7      ce01           or #0x1:8,r6l
0x000449c9      006f           nop
0x000449cb      7100           bnot #0x0:3,r0h
0x000449cd      ce0a           or #0xa:8,r6l
0x000449cf      d101           xor #0x1:8,r1h
0x000449d1      0069           nop
0x000449d3      1101           shlr r1h
0x000449d5      006f           nop
0x000449d7      f000           mov.b #0x0:8,r0h
0x000449d9      2c7a           mov.b @0x7a:8,r4l
0x000449db      0000           nop
0x000449dd      0000           nop
0x000449df      300a           mov.b r0h,@0xa:8
0x000449e1      f05e           mov.b #0x5e:8,r0h
0x000449e3      01648001       sleep
0x000449e7      006b           nop
0x000449e9      2100           mov.b @0x0:8,r1h
0x000449eb      400f           bra @@0xf:8
0x000449ed      8440           add.b #0x40:8,r4h
0x000449ef      361a           mov.b r6h,@0x1a:8
0x000449f1      800c           add.b #0xc:8,r0h
0x000449f3      e810           and #0x10:8,r0l
0x000449f5      3010           mov.b r0h,@0x10:8
0x000449f7      3001           mov.b r0h,@0x1:8
0x000449f9      006f           nop
0x000449fb      f000           mov.b #0x0:8,r0h
0x000449fd      ce01           or #0x1:8,r6l
0x000449ff      006f           nop
0x00044a01      7100           bnot #0x0:3,r0h
0x00044a03      ce0a           or #0xa:8,r6l
0x00044a05      d101           xor #0x1:8,r1h
0x00044a07      0069           nop
0x00044a09      1101           shlr r1h
0x00044a0b      006f           nop
0x00044a0d      f000           mov.b #0x0:8,r0h
0x00044a0f      2c7a           mov.b @0x7a:8,r4l
0x00044a11      0000           nop
0x00044a13      0000           nop
0x00044a15      300a           mov.b r0h,@0xa:8
0x00044a17      f05e           mov.b #0x5e:8,r0h
0x00044a19      01648001       sleep
0x00044a1d      006f           nop
0x00044a1f      7100           bnot #0x0:3,r0h
0x00044a21      b001           subx #0x1:8,r0h
0x00044a23      0069           nop
0x00044a25      1101           shlr r1h
0x00044a27      006f           nop
0x00044a29      f000           mov.b #0x0:8,r0h
0x00044a2b      207a           mov.b @0x7a:8,r0h
0x00044a2d      0000           nop
0x00044a2f      0000           nop
0x00044a31      240a           mov.b @0xa:8,r4h
0x00044a33      f05e           mov.b #0x5e:8,r0h
0x00044a35      015db401       sleep
0x00044a39      006f           nop
0x00044a3b      7100           bnot #0x0:3,r0h
0x00044a3d      200f           mov.b @0xf:8,r0h
0x00044a3f      827a           add.b #0x7a:8,r2h
0x00044a41      0000           nop
0x00044a43      0000           nop
0x00044a45      180a           sub.b r0h,r2l
0x00044a47      f05e           mov.b #0x5e:8,r0h
0x00044a49      0159a45e       sleep
0x00044a4d      015d2e01       sleep
0x00044a51      006f           nop
0x00044a53      7100           bnot #0x0:3,r0h
0x00044a55      2c01           mov.b @0x1:8,r4l
0x00044a57      0078           nop
0x00044a59      906b           addx #0x6b:8,r0h
0x00044a5b      a000           cmp.b #0x0:8,r0h
0x00044a5d      406e           bra @@0x6e:8
0x00044a5f      766e           band #0x6:3,r6l
0x00044a61      78             invalid
0x00044a62      00cd           nop
0x00044a64      0a08           inc r0l
0x00044a66      6ef800cd       mov.b r0l,@(0xcd:16,r7)
0x00044a6a      6e7800cd       mov.b @(0xcd:16,r7),r0l
0x00044a6e      6a290040       mov.b @0x40:16,r1l
0x00044a72      0f55           daa r5h
0x00044a74      1c98           cmp.b r1l,r0l
0x00044a76      58             invalid
0x00044a77      50f6           mulxu r7l,r6
0x00044a79      5e6a2800       jsr @0x2800:16
0x00044a7d      400f           bra @@0xf:8
0x00044a7f      5617           rte
0x00044a81      5079           mulxu r7h,r1
0x00044a83      0800           add.b r0h,r0h
0x00044a85      3a52           mov.b r2l,@0x52:8
0x00044a87      8079           add.b #0x79:8,r0h
0x00044a89      0100027a       sleep
0x00044a8d      1000           shll r0h
0x00044a8f      4009           bra @@0x9:8
0x00044a91      c25e           or #0x5e:8,r2h
0x00044a93      01239879       sleep
0x00044a97      010fa017       sleep
0x00044a9b      7153           bnot #0x5:3,r3h
0x00044a9d      016aa900       sleep
0x00044aa1      400f           bra @@0xf:8
0x00044aa3      326a           mov.b r2h,@0x6a:8
0x00044aa5      2800           mov.b @0x0:8,r0l
0x00044aa7      400f           bra @@0xf:8
0x00044aa9      5617           rte
0x00044aab      5079           mulxu r7h,r1
0x00044aad      0800           add.b r0h,r0h
0x00044aaf      3a52           mov.b r2l,@0x52:8
0x00044ab1      8079           add.b #0x79:8,r0h
0x00044ab3      0100047a       sleep
0x00044ab7      1000           shll r0h
0x00044ab9      4009           bra @@0x9:8
0x00044abb      c25e           or #0x5e:8,r2h
0x00044abd      01239879       sleep
0x00044ac1      010fa017       sleep
0x00044ac5      7153           bnot #0x5:3,r3h
0x00044ac7      016aa900       sleep
0x00044acb      400f           bra @@0xf:8
0x00044acd      336a           mov.b r3h,@0x6a:8
0x00044acf      a900           cmp.b #0x0:8,r1l
0x00044ad1      4052           bra @@0x52:8
0x00044ad3      807a           add.b #0x7a:8,r0h
0x00044ad5      0600           andc #0x0:8,ccr
0x00044ad7      400f           bra @@0xf:8
0x00044ad9      266a           mov.b @0x6a:8,r6h
0x00044adb      2800           mov.b @0x0:8,r0l
0x00044add      4007           bra @@0x7:8
0x00044adf      73a8           btst #0x2:3,r0l
0x00044ae1      0258           stc ccr,r0l
0x00044ae3      6001           bset r0h,r1h
0x00044ae5      746f           bor #0x6:3,r7l
0x00044ae7      3000           mov.b r0h,@0x0:8
0x00044ae9      2269           mov.b @0x69:8,r2h
0x00044aeb      e06a           and #0x6a:8,r0h
0x00044aed      2800           mov.b @0x0:8,r0l
0x00044aef      400f           bra @@0xf:8
0x00044af1      5617           rte
0x00044af3      5079           mulxu r7h,r1
0x00044af5      0800           add.b r0h,r0h
0x00044af7      3a52           mov.b r2l,@0x52:8
0x00044af9      8079           add.b #0x79:8,r0h
0x00044afb      01000e7a       sleep
0x00044aff      1000           shll r0h
0x00044b01      4009           bra @@0x9:8
0x00044b03      c25e           or #0x5e:8,r2h
0x00044b05      0123600f       sleep
0x00044b09      867a           add.b #0x7a:8,r6h
0x00044b0b      0000           nop
0x00044b0d      0011           nop
0x00044b0f      65             invalid
0x00044b10      01006ff0       sleep
0x00044b14      00ce           nop
0x00044b16      6a2800         mov.b @0x10:16,r0l
0x00044b1a      0f56           daa r6h
0x00044b1c      1750           neg r0h
0x00044b1e      7908003a       mov.w #0x3a:16,r0
0x00044b22      52             invalid
0x00044b23      8079           add.b #0x79:8,r0h
0x00044b25      01000a7a       sleep
0x00044b29      1000           shll r0h
0x00044b2b      4009           bra @@0x9:8
0x00044b2d      c25e           or #0x5e:8,r2h
0x00044b2f      01236001       sleep
0x00044b33      006f           nop
0x00044b35      f000           mov.b #0x0:8,r0h
0x00044b37      406a           bra @@0x6a:8
0x00044b39      2800           mov.b @0x0:8,r0l
0x00044b3b      400f           bra @@0xf:8
0x00044b3d      5617           rte
0x00044b3f      5079           mulxu r7h,r1
0x00044b41      0800           add.b r0h,r0h
0x00044b43      3a52           mov.b r2l,@0x52:8
0x00044b45      8079           add.b #0x79:8,r0h
0x00044b47      0100127a       sleep
0x00044b4b      1000           shll r0h
0x00044b4d      4009           bra @@0x9:8
0x00044b4f      c25e           or #0x5e:8,r2h
0x00044b51      01236001       sleep
0x00044b55      006f           nop
0x00044b57      f000           mov.b #0x0:8,r0h
0x00044b59      447a           bcc @@0x7a:8
0x00044b5b      0100000f       sleep
0x00044b5f      a05e           cmp.b #0x5e:8,r0h
0x00044b61      0163ea6b       sleep
0x00044b65      2100           mov.b @0x0:8,r1h
0x00044b67      400d           bra @@0xd:8
0x00044b69      3a17           mov.b r2l,@0x17:8
0x00044b6b      711a           bnot #0x1:3,r2l
0x00044b6d      a26a           cmp.b #0x6a:8,r2h
0x00044b6f      2a00           mov.b @0x0:8,r2l
0x00044b71      400f           bra @@0xf:8
0x00044b73      3301           mov.b r3h,@0x1:8
0x00044b75      006f           nop
0x00044b77      f000           mov.b #0x0:8,r0h
0x00044b79      340f           mov.b r4h,@0xf:8
0x00044b7b      a05e           cmp.b #0x5e:8,r0h
0x00044b7d      0163ea0f       sleep
0x00044b81      8101           add.b #0x1:8,r1h
0x00044b83      006f           nop
0x00044b85      7000           bset #0x0:3,r0h
0x00044b87      345e           mov.b r4h,@0x5e:8
0x00044b89      015cf201       sleep
0x00044b8d      006b           nop
0x00044b8f      a000           cmp.b #0x0:8,r0h
0x00044b91      406e           bra @@0x6e:8
0x00044b93      7201           bclr #0x0:3,r1h
0x00044b95      006f           nop
0x00044b97      7000           bset #0x0:3,r0h
0x00044b99      4001           bra @@0x1:8
0x00044b9b      006f           nop
0x00044b9d      7100           bnot #0x0:3,r0h
0x00044b9f      440a           bcc @@0xa:8
0x00044ba1      901b           addx #0x1b:8,r0h
0x00044ba3      7001           bset #0x0:3,r1h
0x00044ba5      006f           nop
0x00044ba7      f000           mov.b #0x0:8,r0h
0x00044ba9      3c7a           mov.b r4l,@0x7a:8
0x00044bab      0000           nop
0x00044bad      0000           nop
0x00044baf      380a           mov.b r0l,@0xa:8
0x00044bb1      f001           mov.b #0x1:8,r0h
0x00044bb3      006d           nop
0x00044bb5      f07a           mov.b #0x7a:8,r0h
0x00044bb7      0000           nop
0x00044bb9      0000           nop
0x00044bbb      440a           bcc @@0xa:8
0x00044bbd      f07a           mov.b #0x7a:8,r0h
0x00044bbf      0100406e       sleep
0x00044bc3      865c           add.b #0x5c:8,r6h
0x00044bc5      0002           nop
0x00044bc7      060b           andc #0xb:8,ccr
0x00044bc9      9701           addx #0x1:8,r7h
0x00044bcb      006f           nop
0x00044bcd      7000           bset #0x0:3,r0h
0x00044bcf      4047           bra @@0x47:8
0x00044bd1      0c7a           mov.b r7h,r2l
0x00044bd3      0000           nop
0x00044bd5      406e           bra @@0x6e:8
0x00044bd7      8668           add.b #0x68:8,r6h
0x00044bd9      090a           add.w r0,r2
0x00044bdb      0968           add.w r6,r0
0x00044bdd      896a           add.b #0x6a:8,r1l
0x00044bdf      2800           mov.b @0x0:8,r0l
0x00044be1      406e           bra @@0x6e:8
0x00044be3      866a           add.b #0x6a:8,r6h
0x00044be5      2900           mov.b @0x0:8,r1l
0x00044be7      4007           bra @@0x7:8
0x00044be9      901c           addx #0x1c:8,r0h
0x00044beb      9843           addx #0x43:8,r0l
0x00044bed      0c6a           mov.b r6h,r2l
0x00044bef      2800           mov.b @0x0:8,r0l
0x00044bf1      4007           bra @@0x7:8
0x00044bf3      906a           addx #0x6a:8,r0h
0x00044bf5      a800           cmp.b #0x0:8,r0l
0x00044bf7      406e           bra @@0x6e:8
0x00044bf9      867a           add.b #0x7a:8,r6h
0x00044bfb      0000           nop
0x00044bfd      0000           nop
0x00044bff      380a           mov.b r0l,@0xa:8
0x00044c01      f001           mov.b #0x1:8,r0h
0x00044c03      006d           nop
0x00044c05      f07a           mov.b #0x7a:8,r0h
0x00044c07      0000           nop
0x00044c09      0000           nop
0x00044c0b      400a           bra @@0xa:8
0x00044c0d      f07a           mov.b #0x7a:8,r0h
0x00044c0f      0100406e       sleep
0x00044c13      875c           add.b #0x5c:8,r7h
0x00044c15      0001           nop
0x00044c17      b60b           subx #0xb:8,r6h
0x00044c19      97             addx #0x0:8,r7h
0x00044c1b      006f           nop
0x00044c1d      7000           bset #0x0:3,r0h
0x00044c1f      381b           mov.b r0l,@0x1b:8
0x00044c21      7001           bset #0x0:3,r1h
0x00044c23      006f           nop
0x00044c25      7100           bnot #0x0:3,r0h
0x00044c27      3c1f           mov.b r4l,@0x1f:8
0x00044c29      8147           add.b #0x47:8,r1h
0x00044c2b      0c7a           mov.b r7h,r2l
0x00044c2d      0000           nop
0x00044c2f      406e           bra @@0x6e:8
0x00044c31      8768           add.b #0x68:8,r7h
0x00044c33      091a           add.w r1,r2
0x00044c35      0968           add.w r6,r0
0x00044c37      896a           add.b #0x6a:8,r1l
0x00044c39      2800           mov.b @0x0:8,r0l
0x00044c3b      406e           bra @@0x6e:8
0x00044c3d      876a           add.b #0x6a:8,r7h
0x00044c3f      2900           mov.b @0x0:8,r1l
0x00044c41      4007           bra @@0x7:8
0x00044c43      901c           addx #0x1c:8,r0h
0x00044c45      9858           addx #0x58:8,r0l
0x00044c47      3000           mov.b r0h,@0x0:8
0x00044c49      c06a           or #0x6a:8,r0h
0x00044c4b      2800           mov.b @0x0:8,r0l
0x00044c4d      4007           bra @@0x7:8
0x00044c4f      906a           addx #0x6a:8,r0h
0x00044c51      a800           cmp.b #0x0:8,r0l
0x00044c53      406e           bra @@0x6e:8
0x00044c55      875a           add.b #0x5a:8,r7h
0x00044c57      044d           orc #0x4d:8,ccr
0x00044c59      0a6a           inc r2l
0x00044c5b      2800           mov.b @0x0:8,r0l
0x00044c5d      4007           bra @@0x7:8
0x00044c5f      7347           btst #0x4:3,r7h
0x00044c61      1aa8           dec r0l
0x00044c63      01475ea8       sleep
0x00044c67      0347           ldc r7h,ccr
0x00044c69      18a8           sub.b r2l,r0l
0x00044c6b      0447           orc #0x47:8,ccr
0x00044c6d      1aa8           dec r0l
0x00044c6f      0547           xorc #0x47:8,ccr
0x00044c71      16a8           and r2l,r0l
0x00044c73      0647           andc #0x47:8,ccr
0x00044c75      06a8           andc #0xa8:8,ccr
0x00044c77      0747           ldc #0x47:8,ccr
0x00044c79      0240           stc ccr,r0h
0x00044c7b      4e6f           bgt @@0x6f:8
0x00044c7d      3000           mov.b r0h,@0x0:8
0x00044c7f      66             invalid
0x00044c80      4046           bra @@0x46:8
0x00044c82      6f300044       mov.w @(0x44:16,r3),r0
0x00044c86      4040           bra @@0x40:8
0x00044c88      6a280040       mov.b @0x40:16,r0l
0x00044c8c      0f56           daa r6h
0x00044c8e      1750           neg r0h
0x00044c90      7908003a       mov.w #0x3a:16,r0
0x00044c94      52             invalid
0x00044c95      8079           add.b #0x79:8,r0h
0x00044c97      01000a7a       sleep
0x00044c9b      1000           shll r0h
0x00044c9d      4009           bra @@0x9:8
0x00044c9f      c25e           or #0x5e:8,r2h
0x00044ca1      0123607a       sleep
0x00044ca5      0100000f       sleep
0x00044ca9      a05e           cmp.b #0x5e:8,r0h
0x00044cab      0163ea6b       sleep
0x00044caf      2100           mov.b @0x0:8,r1h
0x00044cb1      400d           bra @@0xd:8
0x00044cb3      3a17           mov.b r2l,@0x17:8
0x00044cb5      715e           bnot #0x5:3,r6l
0x00044cb7      015cf201       sleep
0x00044cbb      006b           nop
0x00044cbd      a000           cmp.b #0x0:8,r0h
0x00044cbf      400f           bra @@0xf:8
0x00044cc1      2840           mov.b @0x40:8,r0l
0x00044cc3      066f           andc #0x6f:8,ccr
0x00044cc5      3000           mov.b r0h,@0x0:8
0x00044cc7      d669           xor #0x69:8,r6h
0x00044cc9      e06a           and #0x6a:8,r0h
0x00044ccb      2800           mov.b @0x0:8,r0l
0x00044ccd      400f           bra @@0xf:8
0x00044ccf      5617           rte
0x00044cd1      5079           mulxu r7h,r1
0x00044cd3      0800           add.b r0h,r0h
0x00044cd5      3a52           mov.b r2l,@0x52:8
0x00044cd7      8079           add.b #0x79:8,r0h
0x00044cd9      01000e7a       sleep
0x00044cdd      1000           shll r0h
0x00044cdf      4009           bra @@0x9:8
0x00044ce1      c25e           or #0x5e:8,r2h
0x00044ce3      0123600f       sleep
0x00044ce7      866a           add.b #0x6a:8,r6h
0x00044ce9      2800           mov.b @0x0:8,r0l
0x00044ceb      400f           bra @@0xf:8
0x00044ced      5617           rte
0x00044cef      5079           mulxu r7h,r1
0x00044cf1      0800           add.b r0h,r0h
0x00044cf3      3a52           mov.b r2l,@0x52:8
0x00044cf5      8079           add.b #0x79:8,r0h
0x00044cf7      0100127a       sleep
0x00044cfb      1000           shll r0h
0x00044cfd      4009           bra @@0x9:8
0x00044cff      c25e           or #0x5e:8,r2h
0x00044d01      01236001       sleep
0x00044d05      006f           nop
0x00044d07      f000           mov.b #0x0:8,r0h
0x00044d09      ce0f           or #0xf:8,r6l
0x00044d0b      e07a           and #0x7a:8,r0h
0x00044d0d      0100000f       sleep
0x00044d11      a05e           cmp.b #0x5e:8,r0h
0x00044d13      0163ea01       sleep
0x00044d17      006f           nop
0x00044d19      f000           mov.b #0x0:8,r0h
0x00044d1b      c86b           or #0x6b:8,r0l
0x00044d1d      2100           mov.b @0x0:8,r1h
0x00044d1f      400d           bra @@0xd:8
0x00044d21      3a17           mov.b r2l,@0x17:8
0x00044d23      7101           bnot #0x0:3,r1h
0x00044d25      006f           nop
0x00044d27      f100           mov.b #0x0:8,r1h
0x00044d29      445e           bcc @@0x5e:8
0x00044d2b      015cf26b       sleep
0x00044d2f      a000           cmp.b #0x0:8,r0h
0x00044d31      400f           bra @@0xf:8
0x00044d33      2c1a           mov.b @0x1a:8,r4l
0x00044d35      806a           add.b #0x6a:8,r0h
0x00044d37      2800           mov.b @0x0:8,r0l
0x00044d39      400f           bra @@0xf:8
0x00044d3b      3201           mov.b r2h,@0x1:8
0x00044d3d      006f           nop
0x00044d3f      7100           bnot #0x0:3,r0h
0x00044d41      445e           bcc @@0x5e:8
0x00044d43      0163ea0f       sleep
0x00044d47      8101           add.b #0x1:8,r1h
0x00044d49      006f           nop
0x00044d4b      7000           bset #0x0:3,r0h
0x00044d4d      c85e           or #0x5e:8,r0l
0x00044d4f      015cf26b       sleep
0x00044d53      a000           cmp.b #0x0:8,r0h
0x00044d55      400f           bra @@0xf:8
0x00044d57      2e01           mov.b @0x1:8,r6l
0x00044d59      006f           nop
0x00044d5b      7000           bset #0x0:3,r0h
0x00044d5d      ce7a           or #0x7a:8,r6l
0x00044d5f      0100000f       sleep
0x00044d63      a05e           cmp.b #0x5e:8,r0h
0x00044d65      0163ea1a       sleep
0x00044d69      916a           addx #0x6a:8,r1h
0x00044d6b      2900           mov.b @0x0:8,r1l
0x00044d6d      400f           bra @@0xf:8
0x00044d6f      3301           mov.b r3h,@0x1:8
0x00044d71      006f           nop
0x00044d73      f000           mov.b #0x0:8,r0h
0x00044d75      3401           mov.b r4h,@0x1:8
0x00044d77      006f           nop
0x00044d79      7000           bset #0x0:3,r0h
0x00044d7b      445e           bcc @@0x5e:8
0x00044d7d      0163ea0f       sleep
0x00044d81      8101           add.b #0x1:8,r1h
0x00044d83      006f           nop
0x00044d85      7000           bset #0x0:3,r0h
0x00044d87      345e           mov.b r4h,@0x5e:8
0x00044d89      015cf26b       sleep
0x00044d8d      a000           cmp.b #0x0:8,r0h
0x00044d8f      400f           bra @@0xf:8
0x00044d91      306f           mov.b r0h,@0x6f:8
0x00044d93      3001           mov.b r0h,@0x1:8
0x00044d95      b66f           subx #0x6f:8,r6h
0x00044d97      3101           mov.b r1h,@0x1:8
0x00044d99      b809           subx #0x9:8,r0l
0x00044d9b      106b           shal r3l
0x00044d9d      2100           mov.b @0x0:8,r1h
0x00044d9f      400e           bra @@0xe:8
0x00044da1      8409           add.b #0x9:8,r4h
0x00044da3      100b           shll r3l
0x00044da5      506b           mulxu r6h,r3
0x00044da7      a000           cmp.b #0x0:8,r0h
0x00044da9      400f           bra @@0xf:8
0x00044dab      246a           mov.b @0x6a:8,r4h
0x00044dad      2800           mov.b @0x0:8,r0l
0x00044daf      400f           bra @@0xf:8
0x00044db1      4ca8           bge @@0xa8:8
0x00044db3      014608f8       sleep
0x00044db7      106a           shal r2l
0x00044db9      a800           cmp.b #0x0:8,r0l
0x00044dbb      400f           bra @@0xf:8
0x00044dbd      4c5c           bge @@0x5c:8
0x00044dbf      00ef           nop
0x00044dc1      687a           mov.b @r7,r2l
0x00044dc3      1700           not r0h
0x00044dc5      0000           nop
0x00044dc7      d25e           xor #0x5e:8,r2h
0x00044dc9      01643654       sleep
0x00044dcd      705e           bset #0x5:3,r6l
0x00044dcf      0164580f       sleep
0x00044dd3      830f           add.b #0xf:8,r3h
0x00044dd5      9401           addx #0x1:8,r4h
0x00044dd7      006f           nop
0x00044dd9      7600           band #0x0:3,r0h
0x00044ddb      181a           sub.b r1h,r2l
0x00044ddd      d56a           xor #0x6a:8,r5h
0x00044ddf      2d00           mov.b @0x0:8,r5l
0x00044de1      400f           bra @@0xf:8
0x00044de3      337a           mov.b r3h,@0x7a:8
0x00044de5      0000           nop
0x00044de7      0011           nop
0x00044de9      65             invalid
0x00044dea      0fd1           daa r1h
0x00044dec      5e015cf2       jsr @0x5cf2:16
0x00044df0      0fd1           daa r1h
0x00044df2      5e0163ea       jsr @0x63ea:16
0x00044df6      010069e0       sleep
0x00044dfa      01006930       sleep
0x00044dfe      7a             invalid
0x00044dff      0100000f       sleep
0x00044e03      a05e           cmp.b #0x5e:8,r0h
0x00044e05      0163ea6b       sleep
0x00044e09      2100           mov.b @0x0:8,r1h
0x00044e0b      400d           bra @@0xd:8
0x00044e0d      3a17           mov.b r2l,@0x17:8
0x00044e0f      715e           bnot #0x5:3,r6l
0x00044e11      015cf20f       sleep
0x00044e15      8501           add.b #0x1:8,r5h
0x00044e17      0069           nop
0x00044e19      600f           bset r0h,r7l
0x00044e1b      820a           add.b #0xa:8,r2h
0x00044e1d      d00f           xor #0xf:8,r0h
0x00044e1f      a15e           cmp.b #0x5e:8,r1h
0x00044e21      015cf268       sleep
0x00044e25      c817           or #0x17:8,r0l
0x00044e27      501b           mulxu r1h,r3
0x00044e29      5017           mulxu r1h,r7
0x00044e2b      f001           mov.b #0x1:8,r0h
0x00044e2d      0069           nop
0x00044e2f      615e           bnot r5h,r6l
0x00044e31      0163ea1a       sleep
0x00044e35      8501           add.b #0x1:8,r5h
0x00044e37      0069           nop
0x00044e39      b55e           subx #0x5e:8,r5h
0x00044e3b      01643654       sleep
0x00044e3f      705e           bset #0x5:3,r6l
0x00044e41      0164581b       sleep
0x00044e45      971b           addx #0x1b:8,r7h
0x00044e47      877a           add.b #0x7a:8,r7h
0x00044e49      0300           ldc r0h,ccr
0x00044e4b      400f           bra @@0xf:8
0x00044e4d      307a           mov.b r0h,@0x7a:8
0x00044e4f      0400           orc #0x0:8,ccr
0x00044e51      400f           bra @@0xf:8
0x00044e53      327a           mov.b r2h,@0x7a:8
0x00044e55      0500           xorc #0x0:8,ccr
0x00044e57      400f           bra @@0xf:8
0x00044e59      337a           mov.b r3h,@0x7a:8
0x00044e5b      0600           andc #0x0:8,ccr
0x00044e5d      400b           bra @@0xb:8
0x00044e5f      24f8           mov.b @0xf8:8,r4h
0x00044e61      0e6a           addx r6h,r2l
0x00044e63      a800           cmp.b #0x0:8,r0l
0x00044e65      400f           bra @@0xf:8
0x00044e67      34f8           mov.b r4h,@0xf8:8
0x00044e69      016aa800       sleep
0x00044e6d      400f           bra @@0xf:8
0x00044e6f      4a6a           bpl @@0x6a:8
0x00044e71      a800           cmp.b #0x0:8,r0l
0x00044e73      400f           bra @@0xf:8
0x00044e75      4b6e           bmi @@0x6e:8
0x00044e77      6801           mov.b @r0,r1h
0x00044e79      df68           xor #0x68:8,r7l
0x00044e7b      c86e           or #0x6e:8,r0l
0x00044e7d      6801           mov.b @r0,r1h
0x00044e7f      df68           xor #0x68:8,r7l
0x00044e81      d86a           xor #0x6a:8,r0l
0x00044e83      2800           mov.b @0x0:8,r0l
0x00044e85      400f           bra @@0xf:8
0x00044e87      4c47           bge @@0x47:8
0x00044e89      08f8           add.b r7l,r0l
0x00044e8b      086a           add.b r6h,r2l
0x00044e8d      a800           cmp.b #0x0:8,r0l
0x00044e8f      400f           bra @@0xf:8
0x00044e91      4cf8           bge @@0xf8:8
0x00044e93      026a           stc ccr,r2l
0x00044e95      a800           cmp.b #0x0:8,r0l
0x00044e97      400f           bra @@0xf:8
0x00044e99      5a18880c       jmp @0x880c:16
0x00044e9d      8a1a           add.b #0x1a:8,r2l
0x00044e9f      800c           add.b #0xc:8,r0h
0x00044ea1      a8f9           cmp.b #0xf9:8,r0l
0x00044ea3      0178006a       sleep
0x00044ea7      a900           cmp.b #0x0:8,r1l
0x00044ea9      400f           bra @@0xf:8
0x00044eab      350a           mov.b r5h,@0xa:8
0x00044ead      080c           add.b r0h,r4l
0x00044eaf      8aa8           add.b #0xa8:8,r2l
0x00044eb1      0343           ldc r3h,ccr
0x00044eb3      ea6a           and #0x6a:8,r2l
0x00044eb5      2800           mov.b @0x0:8,r0l
0x00044eb7      4007           bra @@0x7:8
0x00044eb9      7358           btst #0x5:3,r0l
0x00044ebb      7003           bset #0x0:3,r3h
0x00044ebd      3ea8           mov.b r6l,@0xa8:8
0x00044ebf      01472aa8       sleep
0x00044ec3      0258           stc ccr,r0l
0x00044ec5      7001           bset #0x0:3,r1h
0x00044ec7      a8a8           cmp.b #0xa8:8,r0l
0x00044ec9      0358           ldc r0l,ccr
0x00044ecb      7002           bset #0x0:3,r2h
0x00044ecd      7ea80447       biand #0x4:3,@0xa8:8
0x00044ed1      1aa8           dec r0l
0x00044ed3      0547           xorc #0x47:8,ccr
0x00044ed5      16a8           and r2l,r0l
0x00044ed7      0658           andc #0x58:8,ccr
0x00044ed9      7003           bset #0x0:3,r3h
0x00044edb      20a8           mov.b @0xa8:8,r0h
0x00044edd      0758           ldc #0x58:8,ccr
0x00044edf      7003           bset #0x0:3,r3h
0x00044ee1      1aa8           dec r0l
0x00044ee3      ff58           mov.b #0x58:8,r7l
0x00044ee5      7003           bset #0x0:3,r3h
0x00044ee7      145a           or r5h,r2l
0x00044ee9      0452           orc #0x52:8,ccr
0x00044eeb      a86a           cmp.b #0x6a:8,r0l
0x00044eed      2800           mov.b @0x0:8,r0l
0x00044eef      400f           bra @@0xf:8
0x00044ef1      5ba8           jmp @@0xa8:8
0x00044ef3      01586000       sleep
0x00044ef7      bc6f           subx #0x6f:8,r4l
0x00044ef9      6001           bset r0h,r1h
0x00044efb      b66f           subx #0x6f:8,r6h
0x00044efd      6101           bnot r0h,r1h
0x00044eff      b809           subx #0x9:8,r0l
0x00044f01      106f           shal r7l
0x00044f03      6100           bnot r0h,r0h
0x00044f05      0809           add.b r0h,r1l
0x00044f07      100b           shll r3l
0x00044f09      506b           mulxu r6h,r3
0x00044f0b      a000           cmp.b #0x0:8,r0h
0x00044f0d      400f           bra @@0xf:8
0x00044f0f      246a           mov.b @0x6a:8,r4h
0x00044f11      2800           mov.b @0x0:8,r0l
0x00044f13      4007           bra @@0x7:8
0x00044f15      73a8           btst #0x2:3,r0l
0x00044f17      01463a6a       sleep
0x00044f1b      2800           mov.b @0x0:8,r0l
0x00044f1d      400f           bra @@0xf:8
0x00044f1f      5617           rte
0x00044f21      5079           mulxu r7h,r1
0x00044f23      0800           add.b r0h,r0h
0x00044f25      3a52           mov.b r2l,@0x52:8
0x00044f27      8079           add.b #0x79:8,r0h
0x00044f29      01000a7a       sleep
0x00044f2d      1000           shll r0h
0x00044f2f      4009           bra @@0x9:8
0x00044f31      c25e           or #0x5e:8,r2h
0x00044f33      0123607a       sleep
0x00044f37      0100000f       sleep
0x00044f3b      a05e           cmp.b #0x5e:8,r0h
0x00044f3d      0163ea6b       sleep
0x00044f41      2100           mov.b @0x0:8,r1h
0x00044f43      400d           bra @@0xd:8
0x00044f45      3a17           mov.b r2l,@0x17:8
0x00044f47      715e           bnot #0x5:3,r6l
0x00044f49      015cf26b       sleep
0x00044f4d      a000           cmp.b #0x0:8,r0h
0x00044f4f      400f           bra @@0xf:8
0x00044f51      2640           mov.b @0x40:8,r6h
0x00044f53      3a6a           mov.b r2l,@0x6a:8
0x00044f55      2800           mov.b @0x0:8,r0l
0x00044f57      400f           bra @@0xf:8
0x00044f59      5617           rte
0x00044f5b      5079           mulxu r7h,r1
0x00044f5d      0800           add.b r0h,r0h
0x00044f5f      3a52           mov.b r2l,@0x52:8
0x00044f61      8079           add.b #0x79:8,r0h
0x00044f63      01000a7a       sleep
0x00044f67      1000           shll r0h
0x00044f69      4009           bra @@0x9:8
0x00044f6b      c25e           or #0x5e:8,r2h
0x00044f6d      0123607a       sleep
0x00044f71      0100000f       sleep
0x00044f75      a05e           cmp.b #0x5e:8,r0h
0x00044f77      0163ea6b       sleep
0x00044f7b      2100           mov.b @0x0:8,r1h
0x00044f7d      400d           bra @@0xd:8
0x00044f7f      3a17           mov.b r2l,@0x17:8
0x00044f81      715e           bnot #0x5:3,r6l
0x00044f83      015cf201       sleep
0x00044f87      006b           nop
0x00044f89      a000           cmp.b #0x0:8,r0h
0x00044f8b      400f           bra @@0xf:8
0x00044f8d      286f           mov.b @0x6f:8,r0l
0x00044f8f      6000           bset r0h,r0h
0x00044f91      0c6b           mov.b r6h,r3l
0x00044f93      a000           cmp.b #0x0:8,r0h
0x00044f95      400f           bra @@0xf:8
0x00044f97      2c6f           mov.b @0x6f:8,r4l
0x00044f99      6000           bset r0h,r0h
0x00044f9b      0c17           mov.b r1h,r7h
0x00044f9d      701a           bset #0x1:3,r2l
0x00044f9f      9168           addx #0x68:8,r1h
0x00044fa1      495e           bvs @@0x5e:8
0x00044fa3      015cf26b       sleep
0x00044fa7      a000           cmp.b #0x0:8,r0h
0x00044fa9      400f           bra @@0xf:8
0x00044fab      2e6f           mov.b @0x6f:8,r6l
0x00044fad      6000           bset r0h,r0h
0x00044faf      0e5a           addx r5h,r2l
0x00044fb1      0451           orc #0x51:8,ccr
0x00044fb3      ec6f           and #0x6f:8,r4l
0x00044fb5      6001           bset r0h,r1h
0x00044fb7      b66f           subx #0x6f:8,r6h
0x00044fb9      6101           bnot r0h,r1h
0x00044fbb      b809           subx #0x9:8,r0l
0x00044fbd      106f           shal r7l
0x00044fbf      6100           bnot r0h,r0h
0x00044fc1      1009           shll r1l
0x00044fc3      100b           shll r3l
0x00044fc5      506b           mulxu r6h,r3
0x00044fc7      a000           cmp.b #0x0:8,r0h
0x00044fc9      400f           bra @@0xf:8
0x00044fcb      246a           mov.b @0x6a:8,r4h
0x00044fcd      2800           mov.b @0x0:8,r0l
0x00044fcf      4007           bra @@0x7:8
0x00044fd1      73a8           btst #0x2:3,r0l
0x00044fd3      01463a6a       sleep
0x00044fd7      2800           mov.b @0x0:8,r0l
0x00044fd9      400f           bra @@0xf:8
0x00044fdb      5617           rte
0x00044fdd      5079           mulxu r7h,r1
0x00044fdf      0800           add.b r0h,r0h
0x00044fe1      3a52           mov.b r2l,@0x52:8
0x00044fe3      8079           add.b #0x79:8,r0h
0x00044fe5      01000a7a       sleep
0x00044fe9      1000           shll r0h
0x00044feb      4009           bra @@0x9:8
0x00044fed      c25e           or #0x5e:8,r2h
0x00044fef      0123607a       sleep
0x00044ff3      0100000f       sleep
0x00044ff7      a05e           cmp.b #0x5e:8,r0h
0x00044ff9      0163ea6b       sleep
0x00044ffd      2100           mov.b @0x0:8,r1h
0x00044fff      400d           bra @@0xd:8
0x00045001      3a17           mov.b r2l,@0x17:8
0x00045003      715e           bnot #0x5:3,r6l
0x00045005      015cf26b       sleep
0x00045009      a000           cmp.b #0x0:8,r0h
0x0004500b      400f           bra @@0xf:8
0x0004500d      2640           mov.b @0x40:8,r6h
0x0004500f      3a6a           mov.b r2l,@0x6a:8
0x00045011      2800           mov.b @0x0:8,r0l
0x00045013      400f           bra @@0xf:8
0x00045015      5617           rte
0x00045017      5079           mulxu r7h,r1
0x00045019      0800           add.b r0h,r0h
0x0004501b      3a52           mov.b r2l,@0x52:8
0x0004501d      8079           add.b #0x79:8,r0h
0x0004501f      01000a7a       sleep
0x00045023      1000           shll r0h
0x00045025      4009           bra @@0x9:8
0x00045027      c25e           or #0x5e:8,r2h
0x00045029      0123607a       sleep
0x0004502d      0100000f       sleep
0x00045031      a05e           cmp.b #0x5e:8,r0h
0x00045033      0163ea6b       sleep
0x00045037      2100           mov.b @0x0:8,r1h
0x00045039      400d           bra @@0xd:8
0x0004503b      3a17           mov.b r2l,@0x17:8
0x0004503d      715e           bnot #0x5:3,r6l
0x0004503f      015cf201       sleep
0x00045043      006b           nop
0x00045045      a000           cmp.b #0x0:8,r0h
0x00045047      400f           bra @@0xf:8
0x00045049      286f           mov.b @0x6f:8,r0l
0x0004504b      6000           bset r0h,r0h
0x0004504d      146b           or r6h,r3l
0x0004504f      a000           cmp.b #0x0:8,r0h
0x00045051      400f           bra @@0xf:8
0x00045053      2c6f           mov.b @0x6f:8,r4l
0x00045055      6000           bset r0h,r0h
0x00045057      1417           or r1h,r7h
0x00045059      701a           bset #0x1:3,r2l
0x0004505b      9168           addx #0x68:8,r1h
0x0004505d      495e           bvs @@0x5e:8
0x0004505f      015cf26b       sleep
0x00045063      a000           cmp.b #0x0:8,r0h
0x00045065      400f           bra @@0xf:8
0x00045067      2e6f           mov.b @0x6f:8,r6l
0x00045069      6000           bset r0h,r0h
0x0004506b      165a           and r5h,r2l
0x0004506d      0451           orc #0x51:8,ccr
0x0004506f      ec6a           and #0x6a:8,r4l
0x00045071      2800           mov.b @0x0:8,r0l
0x00045073      400f           bra @@0xf:8
0x00045075      5ba8           jmp @@0xa8:8
0x00045077      01464c6f       sleep
0x0004507b      6001           bset r0h,r1h
0x0004507d      b66f           subx #0x6f:8,r6h
0x0004507f      6101           bnot r0h,r1h
0x00045081      b809           subx #0x9:8,r0l
0x00045083      106f           shal r7l
0x00045085      6100           bnot r0h,r0h
0x00045087      2a09           mov.b @0x9:8,r2l
0x00045089      100b           shll r3l
0x0004508b      506b           mulxu r6h,r3
0x0004508d      a000           cmp.b #0x0:8,r0h
0x0004508f      400f           bra @@0xf:8
0x00045091      246f           mov.b @0x6f:8,r4h
0x00045093      6000           bset r0h,r0h
0x00045095      66             invalid
0x00045096      6f61002c       mov.w @(0x2c:16,r6),r1
0x0004509a      0910           add.w r1,r0
0x0004509c      6ba00040       mov.w r0,@0x40:16
0x000450a0      0f26           daa r6h
0x000450a2      6f60002e       mov.w @(0x2e:16,r6),r0
0x000450a6      6ba00040       mov.w r0,@0x40:16
0x000450aa      0f2c           daa r4l
0x000450ac      6f60002e       mov.w @(0x2e:16,r6),r0
0x000450b0      1770           neg r0h
0x000450b2      1a91           dec r1h
0x000450b4      6849           mov.b @r4,r1l
0x000450b6      5e015cf2       jsr @0x5cf2:16
0x000450ba      6ba00040       mov.w r0,@0x40:16
0x000450be      0f2e           daa r6l
0x000450c0      6f600030       mov.w @(0x30:16,r6),r0
0x000450c4      404a           bra @@0x4a:8
0x000450c6      6f6001b6       mov.w @(0x1b6:16,r6),r0
0x000450ca      6f6101b8       mov.w @(0x1b8:16,r6),r1
0x000450ce      0910           add.w r1,r0
0x000450d0      6f610032       mov.w @(0x32:16,r6),r1
0x000450d4      0910           add.w r1,r0
0x000450d6      0b50           adds #1,r0
0x000450d8      6ba00040       mov.w r0,@0x40:16
0x000450dc      0f24           daa r4h
0x000450de      6f600066       mov.w @(0x66:16,r6),r0
0x000450e2      6f610034       mov.w @(0x34:16,r6),r1
0x000450e6      0910           add.w r1,r0
0x000450e8      6ba00040       mov.w r0,@0x40:16
0x000450ec      0f26           daa r6h
0x000450ee      6f600036       mov.w @(0x36:16,r6),r0
0x000450f2      6ba00040       mov.w r0,@0x40:16
0x000450f6      0f2c           daa r4l
0x000450f8      6f600036       mov.w @(0x36:16,r6),r0
0x000450fc      1770           neg r0h
0x000450fe      1a91           dec r1h
0x00045100      6849           mov.b @r4,r1l
0x00045102      5e015cf2       jsr @0x5cf2:16
0x00045106      6ba00040       mov.w r0,@0x40:16
0x0004510a      0f2e           daa r6l
0x0004510c      6f600038       mov.w @(0x38:16,r6),r0
0x00045110      1770           neg r0h
0x00045112      1a91           dec r1h
0x00045114      6859           mov.b @r5,r1l
0x00045116      5e015cf2       jsr @0x5cf2:16
0x0004511a      69             mov.w @r0,r0
0x0004511c      6a280040       mov.b @0x40:16,r0l
0x00045120      0f56           daa r6h
0x00045122      1750           neg r0h
0x00045124      7908003a       mov.w #0x3a:16,r0
0x00045128      52             invalid
0x00045129      8079           add.b #0x79:8,r0h
0x0004512b      01000a7a       sleep
0x0004512f      1000           shll r0h
0x00045131      4009           bra @@0x9:8
0x00045133      c25e           or #0x5e:8,r2h
0x00045135      01236001       sleep
0x00045139      0069           nop
0x0004513b      f00f           mov.b #0xf:8,r0h
0x0004513d      f07a           mov.b #0x7a:8,r0h
0x0004513f      0100406e       sleep
0x00045143      865e           add.b #0x5e:8,r6h
0x00045145      034e           ldc r6l,ccr
0x00045147      485a           bvc @@0x5a:8
0x00045149      0452           orc #0x52:8,ccr
0x0004514b      a86a           cmp.b #0x6a:8,r0l
0x0004514d      2800           mov.b @0x0:8,r0l
0x0004514f      400f           bra @@0xf:8
0x00045151      5ba8           jmp @@0xa8:8
0x00045153      01464c6f       sleep
0x00045157      6001           bset r0h,r1h
0x00045159      b66f           subx #0x6f:8,r6h
0x0004515b      6101           bnot r0h,r1h
0x0004515d      b809           subx #0x9:8,r0l
0x0004515f      106f           shal r7l
0x00045161      6100           bnot r0h,r0h
0x00045163      4c09           bge @@0x9:8
0x00045165      100b           shll r3l
0x00045167      506b           mulxu r6h,r3
0x00045169      a000           cmp.b #0x0:8,r0h
0x0004516b      400f           bra @@0xf:8
0x0004516d      246f           mov.b @0x6f:8,r4h
0x0004516f      6000           bset r0h,r0h
0x00045171      446f           bcc @@0x6f:8
0x00045173      6100           bnot r0h,r0h
0x00045175      4e09           bgt @@0x9:8
0x00045177      106b           shal r3l
0x00045179      a000           cmp.b #0x0:8,r0h
0x0004517b      400f           bra @@0xf:8
0x0004517d      266f           mov.b @0x6f:8,r6h
0x0004517f      6000           bset r0h,r0h
0x00045181      506b           mulxu r6h,r3
0x00045183      a000           cmp.b #0x0:8,r0h
0x00045185      400f           bra @@0xf:8
0x00045187      2c6f           mov.b @0x6f:8,r4l
0x00045189      6000           bset r0h,r0h
0x0004518b      5017           mulxu r1h,r7
0x0004518d      701a           bset #0x1:3,r2l
0x0004518f      9168           addx #0x68:8,r1h
0x00045191      495e           bvs @@0x5e:8
0x00045193      015cf26b       sleep
0x00045197      a000           cmp.b #0x0:8,r0h
0x00045199      400f           bra @@0xf:8
0x0004519b      2e6f           mov.b @0x6f:8,r6l
0x0004519d      6000           bset r0h,r0h
0x0004519f      52             invalid
0x000451a0      404a           bra @@0x4a:8
0x000451a2      6f6001b6       mov.w @(0x1b6:16,r6),r0
0x000451a6      6f6101b8       mov.w @(0x1b8:16,r6),r1
0x000451aa      0910           add.w r1,r0
0x000451ac      6f610054       mov.w @(0x54:16,r6),r1
0x000451b0      0910           add.w r1,r0
0x000451b2      0b50           adds #1,r0
0x000451b4      6ba00040       mov.w r0,@0x40:16
0x000451b8      0f24           daa r4h
0x000451ba      6f600044       mov.w @(0x44:16,r6),r0
0x000451be      6f610056       mov.w @(0x56:16,r6),r1
0x000451c2      0910           add.w r1,r0
0x000451c4      6ba00040       mov.w r0,@0x40:16
0x000451c8      0f26           daa r6h
0x000451ca      6f600058       mov.w @(0x58:16,r6),r0
0x000451ce      6ba00040       mov.w r0,@0x40:16
0x000451d2      0f2c           daa r4l
0x000451d4      6f600058       mov.w @(0x58:16,r6),r0
0x000451d8      1770           neg r0h
0x000451da      1a91           dec r1h
0x000451dc      6849           mov.b @r4,r1l
0x000451de      5e015cf2       jsr @0x5cf2:16
0x000451e2      6ba00040       mov.w r0,@0x40:16
0x000451e6      0f2e           daa r6l
0x000451e8      6f60005a       mov.w @(0x5a:16,r6),r0
0x000451ec      1770           neg r0h
0x000451ee      1a91           dec r1h
0x000451f0      6859           mov.b @r5,r1l
0x000451f2      5e015cf2       jsr @0x5cf2:16
0x000451f6      69b0           mov.w r0,@r3
0x000451f8      5a0452a8       jmp @0x52a8:16
0x000451fc      6a280040       mov.b @0x40:16,r0l
0x00045200      0f5b           daa r3l
0x00045202      a801           cmp.b #0x1:8,r0l
0x00045204      464c           bne @@0x4c:8
0x00045206      6f6001b6       mov.w @(0x1b6:16,r6),r0
0x0004520a      6f6101b8       mov.w @(0x1b8:16,r6),r1
0x0004520e      0910           add.w r1,r0
0x00045210      6f61006e       mov.w @(0x6e:16,r6),r1
0x00045214      0910           add.w r1,r0
0x00045216      0b50           adds #1,r0
0x00045218      6ba00040       mov.w r0,@0x40:16
0x0004521c      0f24           daa r4h
0x0004521e      6f600066       mov.w @(0x66:16,r6),r0
0x00045222      6f610070       mov.w @(0x70:16,r6),r1
0x00045226      0910           add.w r1,r0
0x00045228      6ba00040       mov.w r0,@0x40:16
0x0004522c      0f26           daa r6h
0x0004522e      6f600072       mov.w @(0x72:16,r6),r0
0x00045232      6ba00040       mov.w r0,@0x40:16
0x00045236      0f2c           daa r4l
0x00045238      6f600072       mov.w @(0x72:16,r6),r0
0x0004523c      1770           neg r0h
0x0004523e      1a91           dec r1h
0x00045240      6849           mov.b @r4,r1l
0x00045242      5e015cf2       jsr @0x5cf2:16
0x00045246      6ba00040       mov.w r0,@0x40:16
0x0004524a      0f2e           daa r6l
0x0004524c      6f600074       mov.w @(0x74:16,r6),r0
0x00045250      404a           bra @@0x4a:8
0x00045252      6f6001b6       mov.w @(0x1b6:16,r6),r0
0x00045256      6f6101b8       mov.w @(0x1b8:16,r6),r1
0x0004525a      0910           add.w r1,r0
0x0004525c      6f610076       mov.w @(0x76:16,r6),r1
0x00045260      0910           add.w r1,r0
0x00045262      0b50           adds #1,r0
0x00045264      6ba00040       mov.w r0,@0x40:16
0x00045268      0f24           daa r4h
0x0004526a      6f600066       mov.w @(0x66:16,r6),r0
0x0004526e      6f610078       mov.w @(0x78:16,r6),r1
0x00045272      0910           add.w r1,r0
0x00045274      6ba00040       mov.w r0,@0x40:16
0x00045278      0f26           daa r6h
0x0004527a      6f60007a       mov.w @(0x7a:16,r6),r0
0x0004527e      6ba00040       mov.w r0,@0x40:16
0x00045282      0f2c           daa r4l
0x00045284      6f60007a       mov.w @(0x7a:16,r6),r0
0x00045288      1770           neg r0h
0x0004528a      1a91           dec r1h
0x0004528c      6849           mov.b @r4,r1l
0x0004528e      5e015cf2       jsr @0x5cf2:16
0x00045292      6ba00040       mov.w r0,@0x40:16
0x00045296      0f2e           daa r6l
0x00045298      6f60007c       mov.w @(0x7c:16,r6),r0
0x0004529c      1770           neg r0h
0x0004529e      1a91           dec r1h
0x000452a0      6859           mov.b @r5,r1l
0x000452a2      5e015cf2       jsr @0x5cf2:16
0x000452a6      69b0           mov.w r0,@r3
0x000452a8      0b87           adds #2,r7
0x000452aa      0b97           adds #2,r7
0x000452ac      5e016436       jsr @0x6436:16
0x000452b0      5470           rts
0x000452b2      5e016458       jsr @0x6458:16
0x000452b6      f804           mov.b #0x4:8,r0l
0x000452b8      6aa80040       mov.b r0l,@0x40:16
0x000452bc      0f55           daa r5h
0x000452be      7a             invalid
0x000452bf      0600           andc #0x0:8,ccr
0x000452c1      400f           bra @@0xf:8
0x000452c3      56f8           rte
0x000452c5      0368           ldc r0l,ccr
0x000452c7      e80f           and #0xf:8,r0l
0x000452c9      e40b           and #0xb:8,r4h
0x000452cb      7418           bor #0x1:3,r0l
0x000452cd      8868           add.b #0x68:8,r0l
0x000452cf      c80f           or #0xf:8,r0l
0x000452d1      e00b           and #0xb:8,r0h
0x000452d3      f0f9           mov.b #0xf9:8,r0h
0x000452d5      0168890f       sleep
0x000452d9      e30b           and #0xb:8,r3h
0x000452db      830b           add.b #0xb:8,r3h
0x000452dd      73f9           btst #0x7:3,r1l
0x000452df      0268           stc ccr,r0l
0x000452e1      b96a           subx #0x6a:8,r1l
0x000452e3      2900           mov.b @0x0:8,r1l
0x000452e5      400f           bra @@0xf:8
0x000452e7      556a           bsr .106
0x000452e9      a900           cmp.b #0x0:8,r1l
0x000452eb      406e           bra @@0x6e:8
0x000452ed      357a           mov.b r5h,@0x7a:8
0x000452ef      0100406e       sleep
0x000452f3      3668           mov.b r6h,@0x68:8
0x000452f5      6e689e68       mov.b @(0x9e68:16,r6),r0l
0x000452f9      4c6e           bge @@0x6e:8
0x000452fb      9c00           addx #0x0:8,r4l
0x000452fd      0168086e       sleep
0x00045301      9800           addx #0x0:8,r0l
0x00045303      0268           stc ccr,r0l
0x00045305      3b6e           mov.b r3l,@0x6e:8
0x00045307      9b00           addx #0x0:8,r3l
0x00045309      035e           ldc r6l,ccr
0x0004530b      01643654       sleep
0x0004530f      705e           bset #0x5:3,r6l
0x00045311      016458f8       sleep
0x00045315      046a           orc #0x6a:8,ccr
0x00045317      a800           cmp.b #0x0:8,r0l
0x00045319      400f           bra @@0xf:8
0x0004531b      55             bsr .0
0x0004531d      0600           andc #0x0:8,ccr
0x0004531f      400f           bra @@0xf:8
0x00045321      56f8           rte
0x00045323      0368           ldc r0l,ccr
0x00045325      e80f           and #0xf:8,r0l
0x00045327      e40b           and #0xb:8,r4h
0x00045329      7418           bor #0x1:3,r0l
0x0004532b      8868           add.b #0x68:8,r0l
0x0004532d      c80f           or #0xf:8,r0l
0x0004532f      e00b           and #0xb:8,r0h
0x00045331      f0f9           mov.b #0xf9:8,r0h
0x00045333      0168890f       sleep
0x00045337      e30b           and #0xb:8,r3h
0x00045339      830b           add.b #0xb:8,r3h
0x0004533b      73f9           btst #0x7:3,r1l
0x0004533d      0268           stc ccr,r0l
0x0004533f      b96a           subx #0x6a:8,r1l
0x00045341      2900           mov.b @0x0:8,r1l
0x00045343      400f           bra @@0xf:8
0x00045345      556a           bsr .106
0x00045347      a900           cmp.b #0x0:8,r1l
0x00045349      406e           bra @@0x6e:8
0x0004534b      357a           mov.b r5h,@0x7a:8
0x0004534d      0100406e       sleep
0x00045351      3668           mov.b r6h,@0x68:8
0x00045353      6e689e68       mov.b @(0x9e68:16,r6),r0l
0x00045357      4c6e           bge @@0x6e:8
0x00045359      9c00           addx #0x0:8,r4l
0x0004535b      0168086e       sleep
0x0004535f      9800           addx #0x0:8,r0l
0x00045361      0268           stc ccr,r0l
0x00045363      3b6e           mov.b r3l,@0x6e:8
0x00045365      9b00           addx #0x0:8,r3l
0x00045367      035e           ldc r6l,ccr
0x00045369      01643654       sleep
0x0004536d      7055           bset #0x5:3,r5h
0x0004536f      a018           cmp.b #0x18:8,r0h
0x00045371      9917           addx #0x17:8,r1l
0x00045373      5117           divxu r1h,r7
0x00045375      71f8           bnot #0x7:3,r0l
0x00045377      ff78           mov.b #0x78:8,r7l
0x00045379      106a           shal r2l
0x0004537b      a800           cmp.b #0x0:8,r0l
0x0004537d      400f           bra @@0xf:8
0x0004537f      610a           bnot r0h,r2l
0x00045381      09a9           add.w r10,r1
0x00045383      0343           ldc r3h,ccr
0x00045385      ec18           and #0x18:8,r4l
0x00045387      886a           add.b #0x6a:8,r0l
0x00045389      a800           cmp.b #0x0:8,r0l
0x0004538b      4010           bra @@0x10:8
0x0004538d      66             invalid
0x0004538e      5470           rts
0x00045390      5e016458       jsr @0x6458:16
0x00045394      7a             invalid
0x00045395      0500           xorc #0x0:8,ccr
0x00045397      400f           bra @@0xf:8
0x00045399      615c           bnot r5h,r4l
0x0004539b      00ff           nop
0x0004539d      1418           or r1h,r0l
0x0004539f      ee17           and #0x17:8,r6l
0x000453a1      5617           rte
0x000453a3      760f           band #0x0:3,r7l
0x000453a5      d00a           xor #0xa:8,r0h
0x000453a7      e0f9           and #0xf9:8,r0h
0x000453a9      ff68           mov.b #0x68:8,r7l
0x000453ab      890a           add.b #0xa:8,r1l
0x000453ad      0eae           addx r2l,r6l
0x000453af      0243           stc ccr,r3h
0x000453b1      ee6a           and #0x6a:8,r6l
0x000453b3      2800           mov.b @0x0:8,r0l
0x000453b5      400d           bra @@0xd:8
0x000453b7      056e           xorc #0x6e:8,ccr
0x000453b9      d800           xor #0x0:8,r0l
0x000453bb      03f8           ldc r0l,ccr
0x000453bd      016aa800       sleep
0x000453c1      4010           bra @@0x10:8
0x000453c3      66             invalid
0x000453c4      5e016436       jsr @0x6436:16
0x000453c8      5470           rts
0x000453ca      5516           bsr .22
0x000453cc      1888           sub.b r0l,r0l
0x000453ce      6aa80040       mov.b r0l,@0x40:16
0x000453d2      1066           shal r6h
0x000453d4      5470           rts
0x000453d6      550a           bsr .10
0x000453d8      1888           sub.b r0l,r0l
0x000453da      6aa80040       mov.b r0l,@0x40:16
0x000453de      1066           shal r6h
0x000453e0      5470           rts
0x000453e2      01006df5       sleep
0x000453e6      5c             invalid
0x000453e7      00e9           nop
0x000453e9      406a           bra @@0x6a:8
0x000453eb      2800           mov.b @0x0:8,r0l
0x000453ed      400f           bra @@0xf:8
0x000453ef      556a           bsr .106
0x000453f1      a800           cmp.b #0x0:8,r0l
0x000453f3      406e           bra @@0x6e:8
0x000453f5      357a           mov.b r5h,@0x7a:8
0x000453f7      0500           xorc #0x0:8,ccr
0x000453f9      400f           bra @@0xf:8
0x000453fb      567a           rte
0x000453fd      0100406e       sleep
0x00045401      3668           mov.b r6h,@0x68:8
0x00045403      58             invalid
0x00045404      6898           mov.b r0l,@r1
0x00045406      6e580001       mov.b @(0x1:16,r5),r0l
0x0004540a      6e980001       mov.b r0l,@(0x1:16,r1)
0x0004540e      6e580002       mov.b @(0x2:16,r5),r0l
0x00045412      6e980002       mov.b r0l,@(0x2:16,r1)
0x00045416      6e5d0003       mov.b @(0x3:16,r5),r5l
0x0004541a      6e9d00         mov.b r5l,@(0x0:16,r1)
0x0004541e      01006d75       sleep
0x00045422      5470           rts
0x00045424      5e016458       jsr @0x6458:16
0x00045428      7a             invalid
0x00045429      3700           mov.b r7h,@0x0:8
0x0004542b      0000           nop
0x0004542d      207a           mov.b @0x7a:8,r0h
0x0004542f      0300           ldc r0h,ccr
0x00045431      4074           bra @@0x74:8
0x00045433      d07a           xor #0x7a:8,r0h
0x00045435      0400           orc #0x0:8,ccr
0x00045437      4074           bra @@0x74:8
0x00045439      cc7a           or #0x7a:8,r4l
0x0004543b      0500           xorc #0x0:8,ccr
0x0004543d      4074           bra @@0x74:8
0x0004543f      d47a           xor #0x7a:8,r4h
0x00045441      0600           andc #0x0:8,ccr
0x00045443      400b           bra @@0xb:8
0x00045445      2401           mov.b @0x1:8,r4h
0x00045447      006b           nop
0x00045449      2000           mov.b @0x0:8,r0h
0x0004544b      4007           bra @@0x7:8
0x0004544d      7e7a0100       biand #0x0:3,@0x7a:8
0x00045451      000f           nop
0x00045453      a05e           cmp.b #0x5e:8,r0h
0x00045455      0163ea6b       sleep
0x00045459      2100           mov.b @0x0:8,r1h
0x0004545b      400d           bra @@0xd:8
0x0004545d      3a17           mov.b r2l,@0x17:8
0x0004545f      7101           bnot #0x0:3,r1h
0x00045461      006f           nop
0x00045463      f100           mov.b #0x0:8,r1h
0x00045465      105e           shal r6l
0x00045467      015ccc0d       sleep
0x0004546b      0a01           inc r1h
0x0004546d      006b           nop
0x0004546f      2000           mov.b @0x0:8,r0h
0x00045471      4007           bra @@0x7:8
0x00045473      827a           add.b #0x7a:8,r2h
0x00045475      0100000f       sleep
0x00045479      a05e           cmp.b #0x5e:8,r0h
0x0004547b      0163ea01       sleep
0x0004547f      006f           nop
0x00045481      7100           bnot #0x0:3,r0h
0x00045483      105e           shal r6l
0x00045485      015ccc01       sleep
0x00045489      006f           nop
0x0004548b      f000           mov.b #0x0:8,r0h
0x0004548d      180d           sub.b r0h,r5l
0x0004548f      0201           stc ccr,r1h
0x00045491      006f           nop
0x00045493      7000           bset #0x0:3,r0h
0x00045495      1801           sub.b r0h,r1h
0x00045497      006f           nop
0x00045499      f000           mov.b #0x0:8,r0h
0x0004549b      1401           or r0h,r1h
0x0004549d      006f           nop
0x0004549f      7000           bset #0x0:3,r0h
0x000454a1      1801           sub.b r0h,r1h
0x000454a3      006f           nop
0x000454a5      f000           mov.b #0x0:8,r0h
0x000454a7      0c01           mov.b r0h,r1h
0x000454a9      006b           nop
0x000454ab      2000           mov.b @0x0:8,r0h
0x000454ad      4007           bra @@0x7:8
0x000454af      8201           add.b #0x1:8,r2h
0x000454b1      006f           nop
0x000454b3      f000           mov.b #0x0:8,r0h
0x000454b5      086a           add.b r6h,r2l
0x000454b7      2800           mov.b @0x0:8,r0l
0x000454b9      4007           bra @@0x7:8
0x000454bb      73a8           btst #0x2:3,r0l
0x000454bd      0246           stc ccr,r6h
0x000454bf      0c6b           mov.b r6h,r3l
0x000454c1      2000           mov.b @0x0:8,r0h
0x000454c3      400d           bra @@0xd:8
0x000454c5      3a79           mov.b r2l,@0x79:8
0x000454c7      080b           add.b r0h,r3l
0x000454c9      6340           btst r4h,r0h
0x000454cb      0a6b           inc r3l
0x000454cd      2000           mov.b @0x0:8,r0h
0x000454cf      400d           bra @@0xd:8
0x000454d1      3a79           mov.b r2l,@0x79:8
0x000454d3      080f           add.b r0h,r7l
0x000454d5      6952           mov.w @r5,r2
0x000454d7      807a           add.b #0x7a:8,r0h
0x000454d9      0100000f       sleep
0x000454dd      a05e           cmp.b #0x5e:8,r0h
0x000454df      015cf20d       sleep
0x000454e3      a119           cmp.b #0x19:8,r1h
0x000454e5      100d           shll r5l
0x000454e7      0a6a           inc r2l
0x000454e9      2800           mov.b @0x0:8,r0l
0x000454eb      4007           bra @@0x7:8
0x000454ed      7358           btst #0x5:3,r0l
0x000454ef      7008           bset #0x0:3,r0l
0x000454f1      58             invalid
0x000454f2      a801           cmp.b #0x1:8,r0l
0x000454f4      472a           beq @@0x2a:8
0x000454f6      a802           cmp.b #0x2:8,r0l
0x000454f8      58             invalid
0x000454f9      7003           bset #0x0:3,r3h
0x000454fb      50a8           mulxu r2l,r0
0x000454fd      0358           ldc r0l,ccr
0x000454ff      7005           bset #0x0:3,r5h
0x00045501      e0a8           and #0xa8:8,r0h
0x00045503      0447           orc #0x47:8,ccr
0x00045505      1aa8           dec r0l
0x00045507      0547           xorc #0x47:8,ccr
0x00045509      16a8           and r2l,r0l
0x0004550b      0658           andc #0x58:8,ccr
0x0004550d      7008           bset #0x0:3,r0l
0x0004550f      3aa8           mov.b r2l,@0xa8:8
0x00045511      0758           ldc #0x58:8,ccr
0x00045513      7008           bset #0x0:3,r0l
0x00045515      34a8           mov.b r4h,@0xa8:8
0x00045517      ff58           mov.b #0x58:8,r7l
0x00045519      7008           bset #0x0:3,r0l
0x0004551b      2e5a           mov.b @0x5a:8,r6l
0x0004551d      04             orc #0x0:8,ccr
0x0004551f      b47a           subx #0x7a:8,r4h
0x00045521      0000           nop
0x00045523      0000           nop
0x00045525      070a           ldc #0xa:8,ccr
0x00045527      f001           mov.b #0x1:8,r0h
0x00045529      006d           nop
0x0004552b      f07a           mov.b #0x7a:8,r0h
0x0004552d      0000           nop
0x0004552f      0000           nop
0x00045531      080a           add.b r0h,r2l
0x00045533      f001           mov.b #0x1:8,r0h
0x00045535      006d           nop
0x00045537      f07a           mov.b #0x7a:8,r0h
0x00045539      01000000       sleep
0x0004553d      0a0a           inc r2l
0x0004553f      f17a           mov.b #0x7a:8,r1h
0x00045541      0000           nop
0x00045543      0000           nop
0x00045545      140a           or r0h,r2l
0x00045547      f05e           mov.b #0x5e:8,r0h
0x00045549      0329           ldc r1l,ccr
0x0004554b      3c0b           mov.b r4l,@0xb:8
0x0004554d      970b           addx #0xb:8,r7h
0x0004554f      976b           addx #0x6b:8,r7h
0x00045551      2000           mov.b @0x0:8,r0h
0x00045553      4007           bra @@0x7:8
0x00045555      78             invalid
0x00045556      58             invalid
0x00045557      600a           bset r0h,r2l
0x00045559      e46e           and #0x6e:8,r4h
0x0004555b      7000           bset #0x0:3,r0h
0x0004555d      076f           ldc #0x6f:8,ccr
0x0004555f      7100           bnot #0x0:3,r0h
0x00045561      046f           orc #0x6f:8,ccr
0x00045563      78             invalid
0x00045564      0002           nop
0x00045566      f811           mov.b #0x11:8,r0l
0x00045568      5e030322       jsr @0x322:16
0x0004556c      5e0308e6       jsr @0x8e6:16
0x00045570      6a280040       mov.b @0x40:16,r0l
0x00045574      52             invalid
0x00045575      9aa8           addx #0xa8:8,r2l
0x00045577      0146666b       sleep
0x0004557b      2000           mov.b @0x0:8,r0h
0x0004557d      4058           bra @@0x58:8
0x0004557f      fc6b           mov.b #0x6b:8,r4l
0x00045581      a000           cmp.b #0x0:8,r0h
0x00045583      4052           bra @@0x52:8
0x00045585      8c0b           add.b #0xb:8,r4l
0x00045587      d011           xor #0x11:8,r0h
0x00045589      1011           shal r1h
0x0004558b      1011           shal r1h
0x0004558d      106a           shal r2l
0x0004558f      a800           cmp.b #0x0:8,r0l
0x00045591      400e           bra @@0xe:8
0x00045593      946a           addx #0x6a:8,r4h
0x00045595      a800           cmp.b #0x0:8,r0l
0x00045597      4007           bra @@0x7:8
0x00045599      90a8           addx #0xa8:8,r0h
0x0004559b      2945           mov.b @0x45:8,r1l
0x0004559d      0af8           inc r0l
0x0004559f      286a           mov.b @0x6a:8,r0l
0x000455a1      a800           cmp.b #0x0:8,r0l
0x000455a3      4007           bra @@0x7:8
0x000455a5      9040           addx #0x40:8,r0h
0x000455a7      106a           shal r2l
0x000455a9      2800           mov.b @0x0:8,r0l
0x000455ab      4007           bra @@0x7:8
0x000455ad      9046           addx #0x46:8,r0h
0x000455af      08f8           add.b r7l,r0l
0x000455b1      016aa800       sleep
0x000455b5      4007           bra @@0x7:8
0x000455b7      901a           addx #0x1a:8,r0h
0x000455b9      806a           add.b #0x6a:8,r0h
0x000455bb      2800           mov.b @0x0:8,r0l
0x000455bd      4007           bra @@0x7:8
0x000455bf      9010           addx #0x10:8,r0h
0x000455c1      3010           mov.b r0h,@0x10:8
0x000455c3      3001           mov.b r0h,@0x1:8
0x000455c5      0078           nop
0x000455c7      006b           nop
0x000455c9      2000           mov.b @0x0:8,r0h
0x000455cb      4050           bra @@0x50:8
0x000455cd      9801           addx #0x1:8,r0l
0x000455cf      006b           nop
0x000455d1      a000           cmp.b #0x0:8,r0h
0x000455d3      4052           bra @@0x52:8
0x000455d5      7c7a0000       biand #0x0:3,@r7
0x000455d9      4007           bra @@0x7:8
0x000455db      7c7d0070       biand #0x7:3,@r7
0x000455df      406f           bra @@0x6f:8
0x000455e1      7000           bset #0x0:3,r0h
0x000455e3      0e0d           addx r0h,r5l
0x000455e5      0201           stc ccr,r1h
0x000455e7      006f           nop
0x000455e9      7000           bset #0x0:3,r0h
0x000455eb      147a           or r7h,r2l
0x000455ed      01000017       sleep
0x000455f1      475e           beq @@0x5e:8
0x000455f3      015cf26a       sleep
0x000455f7      a800           cmp.b #0x0:8,r0l
0x000455f9      4076           bra @@0x76:8
0x000455fb      290d           mov.b @0xd:8,r1l
0x000455fd      206f           mov.b @0x6f:8,r0h
0x000455ff      6100           bnot r0h,r0h
0x00045601      201d           mov.b @0x1d:8,r0h
0x00045603      1044           shal r4h
0x00045605      3069           mov.b r0h,@0x69:8
0x00045607      606f           bset r6h,r7l
0x00045609      6100           bnot r0h,r0h
0x0004560b      2009           mov.b @0x9:8,r0h
0x0004560d      106b           shal r3l
0x0004560f      a000           cmp.b #0x0:8,r0h
0x00045611      4074           bra @@0x74:8
0x00045613      ca6f           or #0x6f:8,r2l
0x00045615      6000           bset r0h,r0h
0x00045617      1869           sub.b r6h,r1l
0x00045619      c06f           or #0x6f:8,r0h
0x0004561b      6000           bset r0h,r0h
0x0004561d      1810           sub.b r1h,r0h
0x0004561f      106f           shal r7l
0x00045621      c000           or #0x0:8,r0h
0x00045623      0279           stc ccr,r1l
0x00045625      0000           nop
0x00045627      4669           bne @@0x69:8
0x00045629      b079           subx #0x79:8,r0h
0x0004562b      0000           nop
0x0004562d      8c6f           add.b #0x6f:8,r4l
0x0004562f      b000           subx #0x0:8,r0h
0x00045631      025a           stc ccr,r2l
0x00045633      0457           orc #0x57:8,ccr
0x00045635      346f           mov.b r4h,@0x6f:8
0x00045637      6000           bset r0h,r0h
0x00045639      186f           sub.b r6h,r7l
0x0004563b      6100           bnot r0h,r0h
0x0004563d      2009           mov.b @0x9:8,r0h
0x0004563f      100d           shll r5l
0x00045641      211d           mov.b @0x1d:8,r1h
0x00045643      01442e0d       sleep
0x00045647      2069           mov.b @0x69:8,r0h
0x00045649      6109           bnot r0h,r1l
0x0004564b      106b           shal r3l
0x0004564d      a000           cmp.b #0x0:8,r0h
0x0004564f      4074           bra @@0x74:8
0x00045651      ca6f           or #0x6f:8,r2l
0x00045653      6000           bset r0h,r0h
0x00045655      1869           sub.b r6h,r1l
0x00045657      c06f           or #0x6f:8,r0h
0x00045659      6000           bset r0h,r0h
0x0004565b      1810           sub.b r1h,r0h
0x0004565d      106f           shal r7l
0x0004565f      c000           or #0x0:8,r0h
0x00045661      0279           stc ccr,r1l
0x00045663      0000           nop
0x00045665      4669           bne @@0x69:8
0x00045667      b079           subx #0x79:8,r0h
0x00045669      0000           nop
0x0004566b      8c6f           add.b #0x6f:8,r4l
0x0004566d      b000           subx #0x0:8,r0h
0x0004566f      025a           stc ccr,r2l
0x00045671      0457           orc #0x57:8,ccr
0x00045673      346f           mov.b r4h,@0x6f:8
0x00045675      6000           bset r0h,r0h
0x00045677      0269           stc ccr,r1l
0x00045679      6119           bnot r1h,r1l
0x0004567b      106f           shal r7l
0x0004567d      6100           bnot r0h,r0h
0x0004567f      2019           mov.b @0x19:8,r0h
0x00045681      100d           shll r5l
0x00045683      211d           mov.b @0x1d:8,r1h
0x00045685      01433c69       sleep
0x00045689      606f           bset r6h,r7l
0x0004568b      6100           bnot r0h,r0h
0x0004568d      0209           stc ccr,r1l
0x0004568f      1069           shal r1l
0x00045691      6119           bnot r1h,r1l
0x00045693      106f           shal r7l
0x00045695      6100           bnot r0h,r0h
0x00045697      2019           mov.b @0x19:8,r0h
0x00045699      106b           shal r3l
0x0004569b      a000           cmp.b #0x0:8,r0h
0x0004569d      4074           bra @@0x74:8
0x0004569f      ca6f           or #0x6f:8,r2l
0x000456a1      6000           bset r0h,r0h
0x000456a3      1817           sub.b r1h,r7h
0x000456a5      9069           addx #0x69:8,r0h
0x000456a7      c06f           or #0x6f:8,r0h
0x000456a9      6000           bset r0h,r0h
0x000456ab      1810           sub.b r1h,r0h
0x000456ad      1017           shal r7h
0x000456af      906f           addx #0x6f:8,r0h
0x000456b1      c000           or #0x0:8,r0h
0x000456b3      0279           stc ccr,r1l
0x000456b5      00ff           nop
0x000456b7      ba69           subx #0x69:8,r2l
0x000456b9      b079           subx #0x79:8,r0h
0x000456bb      00ff           nop
0x000456bd      746f           bor #0x6:3,r7l
0x000456bf      b000           subx #0x0:8,r0h
0x000456c1      0240           stc ccr,r0h
0x000456c3      706f           bset #0x6:3,r7l
0x000456c5      6000           bset r0h,r0h
0x000456c7      0269           stc ccr,r1l
0x000456c9      6119           bnot r1h,r1l
0x000456cb      106f           shal r7l
0x000456cd      6100           bnot r0h,r0h
0x000456cf      1819           sub.b r1h,r1l
0x000456d1      106f           shal r7l
0x000456d3      6100           bnot r0h,r0h
0x000456d5      2019           mov.b @0x19:8,r0h
0x000456d7      100d           shll r5l
0x000456d9      211d           mov.b @0x1d:8,r1h
0x000456db      01432c0d       sleep
0x000456df      2069           mov.b @0x69:8,r0h
0x000456e1      6109           bnot r0h,r1l
0x000456e3      106b           shal r3l
0x000456e5      a000           cmp.b #0x0:8,r0h
0x000456e7      4074           bra @@0x74:8
0x000456e9      ca6f           or #0x6f:8,r2l
0x000456eb      6000           bset r0h,r0h
0x000456ed      1817           sub.b r1h,r7h
0x000456ef      9069           addx #0x69:8,r0h
0x000456f1      c06f           or #0x6f:8,r0h
0x000456f3      6000           bset r0h,r0h
0x000456f5      1810           sub.b r1h,r0h
0x000456f7      1017           shal r7h
0x000456f9      906f           addx #0x6f:8,r0h
0x000456fb      c000           or #0x0:8,r0h
0x000456fd      0279           stc ccr,r1l
0x000456ff      00ff           nop
0x00045701      ba69           subx #0x69:8,r2l
0x00045703      b079           subx #0x79:8,r0h
0x00045705      00ff           nop
0x00045707      7440           bor #0x4:3,r0h
0x00045709      260d           mov.b @0xd:8,r6h
0x0004570b      2069           mov.b @0x69:8,r0h
0x0004570d      6109           bnot r0h,r1l
0x0004570f      106b           shal r3l
0x00045711      a000           cmp.b #0x0:8,r0h
0x00045713      4074           bra @@0x74:8
0x00045715      ca6f           or #0x6f:8,r2l
0x00045717      6000           bset r0h,r0h
0x00045719      1869           sub.b r6h,r1l
0x0004571b      c06f           or #0x6f:8,r0h
0x0004571d      6000           bset r0h,r0h
0x0004571f      1817           sub.b r1h,r7h
0x00045721      906f           addx #0x6f:8,r0h
0x00045723      c000           or #0x0:8,r0h
0x00045725      0279           stc ccr,r1l
0x00045727      0000           nop
0x00045729      4669           bne @@0x69:8
0x0004572b      b079           subx #0x79:8,r0h
0x0004572d      00ff           nop
0x0004572f      ba6f           subx #0x6f:8,r2l
0x00045731      b000           subx #0x0:8,r0h
0x00045733      026f           stc ccr,r7l
0x00045735      6000           bset r0h,r0h
0x00045737      1a11           dec r1h
0x00045739      106f           shal r7l
0x0004573b      6100           bnot r0h,r0h
0x0004573d      1e09           subx r0h,r1l
0x0004573f      100d           shll r5l
0x00045741      a11d           cmp.b #0x1d:8,r1h
0x00045743      0144266f       sleep
0x00045747      6000           bset r0h,r0h
0x00045749      1a11           dec r1h
0x0004574b      106f           shal r7l
0x0004574d      6100           bnot r0h,r0h
0x0004574f      1e09           subx r0h,r1l
0x00045751      106b           shal r3l
0x00045753      a000           cmp.b #0x0:8,r0h
0x00045755      4052           bra @@0x52:8
0x00045757      a26f           cmp.b #0x6f:8,r2h
0x00045759      6000           bset r0h,r0h
0x0004575b      1c69           cmp.b r6h,r1l
0x0004575d      d06f           xor #0x6f:8,r0h
0x0004575f      6000           bset r0h,r0h
0x00045761      1c10           cmp.b r1h,r0h
0x00045763      106f           shal r7l
0x00045765      d000           xor #0x0:8,r0h
0x00045767      025a           stc ccr,r2l
0x00045769      0458           orc #0x58:8,ccr
0x0004576b      346f           mov.b r4h,@0x6f:8
0x0004576d      6000           bset r0h,r0h
0x0004576f      1a11           dec r1h
0x00045771      106f           shal r7l
0x00045773      6100           bnot r0h,r0h
0x00045775      1c09           cmp.b r0h,r1l
0x00045777      106f           shal r7l
0x00045779      6100           bnot r0h,r0h
0x0004577b      1e09           subx r0h,r1l
0x0004577d      100d           shll r5l
0x0004577f      a11d           cmp.b #0x1d:8,r1h
0x00045781      01441a6b       sleep
0x00045785      aa00           cmp.b #0x0:8,r2l
0x00045787      4052           bra @@0x52:8
0x00045789      a26f           cmp.b #0x6f:8,r2h
0x0004578b      6000           bset r0h,r0h
0x0004578d      1c69           cmp.b r6h,r1l
0x0004578f      d06f           xor #0x6f:8,r0h
0x00045791      6000           bset r0h,r0h
0x00045793      1c10           cmp.b r1h,r0h
0x00045795      106f           shal r7l
0x00045797      d000           xor #0x0:8,r0h
0x00045799      025a           stc ccr,r2l
0x0004579b      0458           orc #0x58:8,ccr
0x0004579d      346f           mov.b r4h,@0x6f:8
0x0004579f      6000           bset r0h,r0h
0x000457a1      1a11           dec r1h
0x000457a3      106f           shal r7l
0x000457a5      6100           bnot r0h,r0h
0x000457a7      0619           andc #0x19:8,ccr
0x000457a9      016f6000       sleep
0x000457ad      1e19           subx r1h,r1l
0x000457af      011b510d       sleep
0x000457b3      a01d           cmp.b #0x1d:8,r0h
0x000457b5      1043           shal r3h
0x000457b7      306f           mov.b r0h,@0x6f:8
0x000457b9      6000           bset r0h,r0h
0x000457bb      1a11           dec r1h
0x000457bd      106f           shal r7l
0x000457bf      6100           bnot r0h,r0h
0x000457c1      0619           andc #0x19:8,ccr
0x000457c3      016f6000       sleep
0x000457c7      1e19           subx r1h,r1l
0x000457c9      011b516b       sleep
0x000457cd      a100           cmp.b #0x0:8,r1h
0x000457cf      4052           bra @@0x52:8
0x000457d1      a26f           cmp.b #0x6f:8,r2h
0x000457d3      6000           bset r0h,r0h
0x000457d5      1c17           cmp.b r1h,r7h
0x000457d7      9069           addx #0x69:8,r0h
0x000457d9      d06f           xor #0x6f:8,r0h
0x000457db      6000           bset r0h,r0h
0x000457dd      1c10           cmp.b r1h,r0h
0x000457df      1017           shal r7h
0x000457e1      906f           addx #0x6f:8,r0h
0x000457e3      d000           xor #0x0:8,r0h
0x000457e5      0240           stc ccr,r0h
0x000457e7      4c6f           bge @@0x6f:8
0x000457e9      6000           bset r0h,r0h
0x000457eb      1a11           dec r1h
0x000457ed      106f           shal r7l
0x000457ef      6100           bnot r0h,r0h
0x000457f1      0619           andc #0x19:8,ccr
0x000457f3      016f6000       sleep
0x000457f7      1c19           cmp.b r1h,r1l
0x000457f9      016f6000       sleep
0x000457fd      1e19           subx r1h,r1l
0x000457ff      011b510d       sleep
0x00045803      a01d           cmp.b #0x1d:8,r0h
0x00045805      1043           shal r3h
0x00045807      166b           and r6h,r3l
0x00045809      aa00           cmp.b #0x0:8,r2l
0x0004580b      4052           bra @@0x52:8
0x0004580d      a26f           cmp.b #0x6f:8,r2h
0x0004580f      6000           bset r0h,r0h
0x00045811      1c17           cmp.b r1h,r7h
0x00045813      9069           addx #0x69:8,r0h
0x00045815      d06f           xor #0x6f:8,r0h
0x00045817      6000           bset r0h,r0h
0x00045819      1c10           cmp.b r1h,r0h
0x0004581b      1040           shal r0h
0x0004581d      106b           shal r3l
0x0004581f      aa00           cmp.b #0x0:8,r2l
0x00045821      4052           bra @@0x52:8
0x00045823      a26f           cmp.b #0x6f:8,r2h
0x00045825      6000           bset r0h,r0h
0x00045827      1c69           cmp.b r6h,r1l
0x00045829      d06f           xor #0x6f:8,r0h
0x0004582b      6000           bset r0h,r0h
0x0004582d      1c17           cmp.b r1h,r7h
0x0004582f      906f           addx #0x6f:8,r0h
0x00045831      d000           xor #0x0:8,r0h
0x00045833      0201           stc ccr,r1h
0x00045835      006b           nop
0x00045837      2000           mov.b @0x0:8,r0h
0x00045839      4052           bra @@0x52:8
0x0004583b      ca01           or #0x1:8,r2l
0x0004583d      006b           nop
0x0004583f      a000           cmp.b #0x0:8,r0h
0x00045841      4076           bra @@0x76:8
0x00045843      2a6f           mov.b @0x6f:8,r2l
0x00045845      6000           bset r0h,r0h
0x00045847      1a5a           dec r2l
0x00045849      045f           orc #0x5f:8,ccr
0x0004584b      ae7a           cmp.b #0x7a:8,r6l
0x0004584d      01000000       sleep
0x00045851      010af17a       sleep
0x00045855      0000           nop
0x00045857      0000           nop
0x00045859      080a           add.b r0h,r2l
0x0004585b      f05e           mov.b #0x5e:8,r0h
0x0004585d      034e           ldc r6l,ccr
0x0004585f      486e           bvc @@0x6e:8
0x00045861      78             invalid
0x00045862      0001           nop
0x00045864      5e034df6       jsr @0x4df6:16
0x00045868      01006f70       sleep
0x0004586c      0014           nop
0x0004586e      7a             invalid
0x0004586f      01000011       sleep
0x00045873      65             invalid
0x00045874      5e015cf2       jsr @0x5cf2:16
0x00045878      6aa80040       mov.b r0l,@0x40:16
0x0004587c      7629           band #0x2:3,r1l
0x0004587e      6f70000a       mov.w @(0xa:16,r7),r0
0x00045882      0d02           mov.w r0,r2
0x00045884      6f610042       mov.w @(0x42:16,r6),r1
0x00045888      1d10           cmp.w r1,r0
