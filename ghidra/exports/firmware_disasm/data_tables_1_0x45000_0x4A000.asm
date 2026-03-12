; === data_tables_1 (0x045000 - 0x04A000) ===
; Size: 20480 bytes
; NOTE: r2 h8300 is 16-bit only. 32-bit H8/300H ops may show as invalid.
; Use Ghidra H8/300H SLEIGH for authoritative disassembly.

0x00045000      0d3a           mov.w r3,r2
0x00045002      1771           neg r1h
0x00045004      5e015cf2       jsr @0x5cf2:16
0x00045008      6ba00040       mov.w r0,@0x40:16
0x0004500c      0f26           daa r6h
0x0004500e      403a           bra @@0x3a:8
0x00045010      6a280040       mov.b @0x40:16,r0l
0x00045014      0f56           daa r6h
0x00045016      1750           neg r0h
0x00045018      7908003a       mov.w #0x3a:16,r0
0x0004501c      52             invalid
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
0x0004511a      69b0           mov.w r0,@r3
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
0x000452fd      016808         sleep
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
0x0004531b      557a           bsr .122
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
0x0004541a      6e9d0003       mov.b r5l,@(0x3:16,r1)
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
0x0004551d      045f           orc #0x5f:8,ccr
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
0x000457ff      011b           sleep
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
0x0004588a      4432           bcc @@0x32:8
0x0004588c      6f610022       mov.w @(0x22:16,r6),r1
0x00045890      6f620042       mov.w @(0x42:16,r6),r2
0x00045894      0921           add.w r2,r1
0x00045896      6ba10040       mov.w r1,@0x40:16
0x0004589a      74ca           bior #0x4:3,r2l
0x0004589c      6f61003a       mov.w @(0x3a:16,r6),r1
0x000458a0      69c1           mov.w r1,@r4
0x000458a2      6f61003a       mov.w @(0x3a:16,r6),r1
0x000458a6      1011           shal r1h
0x000458a8      6fc10002       mov.w r1,@(0x2:16,r4)
0x000458ac      79010046       mov.w #0x46:16,r1
0x000458b0      69b1           mov.w r1,@r3
0x000458b2      7901008c       mov.w #0x8c:16,r1
0x000458b6      6fb10002       mov.w r1,@(0x2:16,r3)
0x000458ba      5a0459ca       jmp @0x59ca:16
0x000458be      6f60003a       mov.w @(0x3a:16,r6),r0
0x000458c2      6f610042       mov.w @(0x42:16,r6),r1
0x000458c6      0910           add.w r1,r0
0x000458c8      0d21           mov.w r2,r1
0x000458ca      1d01           cmp.w r0,r1
0x000458cc      4430           bcc @@0x30:8
0x000458ce      0d20           mov.w r2,r0
0x000458d0      6f610022       mov.w @(0x22:16,r6),r1
0x000458d4      0910           add.w r1,r0
0x000458d6      6ba00040       mov.w r0,@0x40:16
0x000458da      74ca           bior #0x4:3,r2l
0x000458dc      6f60003a       mov.w @(0x3a:16,r6),r0
0x000458e0      69c0           mov.w r0,@r4
0x000458e2      6f60003a       mov.w @(0x3a:16,r6),r0
0x000458e6      1010           shal r0h
0x000458e8      6fc00002       mov.w r0,@(0x2:16,r4)
0x000458ec      79000046       mov.w #0x46:16,r0
0x000458f0      69b0           mov.w r0,@r3
0x000458f2      7900008c       mov.w #0x8c:16,r0
0x000458f6      6fb00002       mov.w r0,@(0x2:16,r3)
0x000458fa      5a0459ca       jmp @0x59ca:16
0x000458fe      6f600024       mov.w @(0x24:16,r6),r0
0x00045902      6f             mov.w @(0x100:16,r1),r0
0x00045906      1910           sub.w r1,r0
0x00045908      6f610042       mov.w @(0x42:16,r6),r1
0x0004590c      1910           sub.w r1,r0
0x0004590e      0d21           mov.w r2,r1
0x00045910      1d01           cmp.w r0,r1
0x00045912      4340           bls @@0x40:8
0x00045914      6f600022       mov.w @(0x22:16,r6),r0
0x00045918      6f610024       mov.w @(0x24:16,r6),r1
0x0004591c      0910           add.w r1,r0
0x0004591e      6f610022       mov.w @(0x22:16,r6),r1
0x00045922      1910           sub.w r1,r0
0x00045924      6f610042       mov.w @(0x42:16,r6),r1
0x00045928      1910           sub.w r1,r0
0x0004592a      6ba00040       mov.w r0,@0x40:16
0x0004592e      74ca           bior #0x4:3,r2l
0x00045930      6f60003a       mov.w @(0x3a:16,r6),r0
0x00045934      1790           neg r0h
0x00045936      69c0           mov.w r0,@r4
0x00045938      6f60003a       mov.w @(0x3a:16,r6),r0
0x0004593c      1010           shal r0h
0x0004593e      1790           neg r0h
0x00045940      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045944      7900ffba       mov.w #0xffba:16,r0
0x00045948      69b0           mov.w r0,@r3
0x0004594a      7900ff74       mov.w #0xff74:16,r0
0x0004594e      6fb00002       mov.w r0,@(0x2:16,r3)
0x00045952      4076           bra @@0x76:8
0x00045954      6f600024       mov.w @(0x24:16,r6),r0
0x00045958      6f610022       mov.w @(0x22:16,r6),r1
0x0004595c      1910           sub.w r1,r0
0x0004595e      6f61003a       mov.w @(0x3a:16,r6),r1
0x00045962      1910           sub.w r1,r0
0x00045964      6f610042       mov.w @(0x42:16,r6),r1
0x00045968      1910           sub.w r1,r0
0x0004596a      0d21           mov.w r2,r1
0x0004596c      1d01           cmp.w r0,r1
0x0004596e      432e           bls @@0x2e:8
0x00045970      0d20           mov.w r2,r0
0x00045972      6f610022       mov.w @(0x22:16,r6),r1
0x00045976      0910           add.w r1,r0
0x00045978      6ba00040       mov.w r0,@0x40:16
0x0004597c      74ca           bior #0x4:3,r2l
0x0004597e      6f60003a       mov.w @(0x3a:16,r6),r0
0x00045982      1790           neg r0h
0x00045984      69c0           mov.w r0,@r4
0x00045986      6f60003a       mov.w @(0x3a:16,r6),r0
0x0004598a      1010           shal r0h
0x0004598c      1790           neg r0h
0x0004598e      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045992      7900ffba       mov.w #0xffba:16,r0
0x00045996      69b0           mov.w r0,@r3
0x00045998      7900ff74       mov.w #0xff74:16,r0
0x0004599c      4028           bra @@0x28:8
0x0004599e      0d20           mov.w r2,r0
0x000459a0      6f610022       mov.w @(0x22:16,r6),r1
0x000459a4      0910           add.w r1,r0
0x000459a6      6ba00040       mov.w r0,@0x40:16
0x000459aa      74ca           bior #0x4:3,r2l
0x000459ac      6f60003a       mov.w @(0x3a:16,r6),r0
0x000459b0      69c0           mov.w r0,@r4
0x000459b2      6f60003a       mov.w @(0x3a:16,r6),r0
0x000459b6      1790           neg r0h
0x000459b8      6fc00002       mov.w r0,@(0x2:16,r4)
0x000459bc      79000046       mov.w #0x46:16,r0
0x000459c0      69b0           mov.w r0,@r3
0x000459c2      7900ffba       mov.w #0xffba:16,r0
0x000459c6      6fb00002       mov.w r0,@(0x2:16,r3)
0x000459ca      6f60003c       mov.w @(0x3c:16,r6),r0
0x000459ce      1110           shar r0h
0x000459d0      6f610040       mov.w @(0x40:16,r6),r1
0x000459d4      0910           add.w r1,r0
0x000459d6      0da1           mov.w r10,r1
0x000459d8      1d01           cmp.w r0,r1
0x000459da      4426           bcc @@0x26:8
0x000459dc      6f60003c       mov.w @(0x3c:16,r6),r0
0x000459e0      1110           shar r0h
0x000459e2      6f610040       mov.w @(0x40:16,r6),r1
0x000459e6      0910           add.w r1,r0
0x000459e8      6ba00040       mov.w r0,@0x40:16
0x000459ec      52             invalid
0x000459ed      a26f           cmp.b #0x6f:8,r2h
0x000459ef      6000           bset r0h,r0h
0x000459f1      3e69           mov.b r6l,@0x69:8
0x000459f3      d06f           xor #0x6f:8,r0h
0x000459f5      6000           bset r0h,r0h
0x000459f7      3e10           mov.b r6l,@0x10:8
0x000459f9      106f           shal r7l
0x000459fb      d000           xor #0x0:8,r0h
0x000459fd      025a           stc ccr,r2l
0x000459ff      045a           orc #0x5a:8,ccr
0x00045a01      ca6f           or #0x6f:8,r2l
0x00045a03      6000           bset r0h,r0h
0x00045a05      3c             mov.b r4l,@0x10:8
0x00045a07      106f           shal r7l
0x00045a09      6100           bnot r0h,r0h
0x00045a0b      3e09           mov.b r6l,@0x9:8
0x00045a0d      106f           shal r7l
0x00045a0f      6100           bnot r0h,r0h
0x00045a11      4009           bra @@0x9:8
0x00045a13      100d           shll r5l
0x00045a15      a11d           cmp.b #0x1d:8,r1h
0x00045a17      01441a6b       sleep
0x00045a1b      aa00           cmp.b #0x0:8,r2l
0x00045a1d      4052           bra @@0x52:8
0x00045a1f      a26f           cmp.b #0x6f:8,r2h
0x00045a21      6000           bset r0h,r0h
0x00045a23      3e69           mov.b r6l,@0x69:8
0x00045a25      d06f           xor #0x6f:8,r0h
0x00045a27      6000           bset r0h,r0h
0x00045a29      3e10           mov.b r6l,@0x10:8
0x00045a2b      106f           shal r7l
0x00045a2d      d000           xor #0x0:8,r0h
0x00045a2f      025a           stc ccr,r2l
0x00045a31      045a           orc #0x5a:8,ccr
0x00045a33      ca6f           or #0x6f:8,r2l
0x00045a35      6000           bset r0h,r0h
0x00045a37      3c11           mov.b r4l,@0x11:8
0x00045a39      106f           shal r7l
0x00045a3b      6100           bnot r0h,r0h
0x00045a3d      2819           mov.b @0x19:8,r0l
0x00045a3f      016f6000       sleep
0x00045a43      4019           bra @@0x19:8
0x00045a45      011b510d       sleep
0x00045a49      a01d           cmp.b #0x1d:8,r0h
0x00045a4b      1043           shal r3h
0x00045a4d      306f           mov.b r0h,@0x6f:8
0x00045a4f      6000           bset r0h,r0h
0x00045a51      3c11           mov.b r4l,@0x11:8
0x00045a53      106f           shal r7l
0x00045a55      6100           bnot r0h,r0h
0x00045a57      2819           mov.b @0x19:8,r0l
0x00045a59      016f6000       sleep
0x00045a5d      4019           bra @@0x19:8
0x00045a5f      011b516b       sleep
0x00045a63      a100           cmp.b #0x0:8,r1h
0x00045a65      4052           bra @@0x52:8
0x00045a67      a26f           cmp.b #0x6f:8,r2h
0x00045a69      6000           bset r0h,r0h
0x00045a6b      3e17           mov.b r6l,@0x17:8
0x00045a6d      9069           addx #0x69:8,r0h
0x00045a6f      d06f           xor #0x6f:8,r0h
0x00045a71      6000           bset r0h,r0h
0x00045a73      3e10           mov.b r6l,@0x10:8
0x00045a75      1017           shal r7h
0x00045a77      906f           addx #0x6f:8,r0h
0x00045a79      d000           xor #0x0:8,r0h
0x00045a7b      0240           stc ccr,r0h
0x00045a7d      4c6f           bge @@0x6f:8
0x00045a7f      6000           bset r0h,r0h
0x00045a81      3c11           mov.b r4l,@0x11:8
0x00045a83      106f           shal r7l
0x00045a85      6100           bnot r0h,r0h
0x00045a87      2819           mov.b @0x19:8,r0l
0x00045a89      016f6000       sleep
0x00045a8d      3e19           mov.b r6l,@0x19:8
0x00045a8f      016f6000       sleep
0x00045a93      4019           bra @@0x19:8
0x00045a95      011b510d       sleep
0x00045a99      a01d           cmp.b #0x1d:8,r0h
0x00045a9b      1043           shal r3h
0x00045a9d      166b           and r6h,r3l
0x00045a9f      aa00           cmp.b #0x0:8,r2l
0x00045aa1      4052           bra @@0x52:8
0x00045aa3      a26f           cmp.b #0x6f:8,r2h
0x00045aa5      6000           bset r0h,r0h
0x00045aa7      3e17           mov.b r6l,@0x17:8
0x00045aa9      9069           addx #0x69:8,r0h
0x00045aab      d06f           xor #0x6f:8,r0h
0x00045aad      6000           bset r0h,r0h
0x00045aaf      3e10           mov.b r6l,@0x10:8
0x00045ab1      1040           shal r0h
0x00045ab3      106b           shal r3l
0x00045ab5      aa00           cmp.b #0x0:8,r2l
0x00045ab7      4052           bra @@0x52:8
0x00045ab9      a26f           cmp.b #0x6f:8,r2h
0x00045abb      6000           bset r0h,r0h
0x00045abd      3e69           mov.b r6l,@0x69:8
0x00045abf      d06f           xor #0x6f:8,r0h
0x00045ac1      6000           bset r0h,r0h
0x00045ac3      3e17           mov.b r6l,@0x17:8
0x00045ac5      906f           addx #0x6f:8,r0h
0x00045ac7      d000           xor #0x0:8,r0h
0x00045ac9      0201           stc ccr,r1h
0x00045acb      006b           nop
0x00045acd      2000           mov.b @0x0:8,r0h
0x00045acf      4052           bra @@0x52:8
0x00045ad1      ca01           or #0x1:8,r2l
0x00045ad3      006b           nop
0x00045ad5      a000           cmp.b #0x0:8,r0h
0x00045ad7      4076           bra @@0x76:8
0x00045ad9      2a6f           mov.b @0x6f:8,r2l
0x00045adb      6000           bset r0h,r0h
0x00045add      3c5a           mov.b r4l,@0x5a:8
0x00045adf      045f           orc #0x5f:8,ccr
0x00045ae1      ae18           cmp.b #0x18:8,r6l
0x00045ae3      886a           add.b #0x6a:8,r0l
0x00045ae5      a800           cmp.b #0x0:8,r0l
0x00045ae7      4076           bra @@0x76:8
0x00045ae9      290d           mov.b @0xd:8,r1l
0x00045aeb      206f           mov.b @0x6f:8,r0h
0x00045aed      6100           bnot r0h,r0h
0x00045aef      64             invalid
0x00045af0      1d10           cmp.w r1,r0
0x00045af2      4432           bcc @@0x32:8
0x00045af4      6f600044       mov.w @(0x44:16,r6),r0
0x00045af8      6f610064       mov.w @(0x64:16,r6),r1
0x00045afc      0910           add.w r1,r0
0x00045afe      6ba00040       mov.w r0,@0x40:16
0x00045b02      74ca           bior #0x4:3,r2l
0x00045b04      6f6000         mov.w @(0x10:16,r6),r0
0x00045b08      69c0           mov.w r0,@r4
0x00045b0a      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045b0e      1010           shal r0h
0x00045b10      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045b14      79000046       mov.w #0x46:16,r0
0x00045b18      69b0           mov.w r0,@r3
0x00045b1a      7900008c       mov.w #0x8c:16,r0
0x00045b1e      6fb00002       mov.w r0,@(0x2:16,r3)
0x00045b22      5a045c32       jmp @0x5c32:16
0x00045b26      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045b2a      6f610064       mov.w @(0x64:16,r6),r1
0x00045b2e      0910           add.w r1,r0
0x00045b30      0d21           mov.w r2,r1
0x00045b32      1d01           cmp.w r0,r1
0x00045b34      4430           bcc @@0x30:8
0x00045b36      0d20           mov.w r2,r0
0x00045b38      6f610044       mov.w @(0x44:16,r6),r1
0x00045b3c      0910           add.w r1,r0
0x00045b3e      6ba00040       mov.w r0,@0x40:16
0x00045b42      74ca           bior #0x4:3,r2l
0x00045b44      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045b48      69c0           mov.w r0,@r4
0x00045b4a      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045b4e      1010           shal r0h
0x00045b50      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045b54      79000046       mov.w #0x46:16,r0
0x00045b58      69b0           mov.w r0,@r3
0x00045b5a      7900008c       mov.w #0x8c:16,r0
0x00045b5e      6fb00002       mov.w r0,@(0x2:16,r3)
0x00045b62      5a045c32       jmp @0x5c32:16
0x00045b66      6f600046       mov.w @(0x46:16,r6),r0
0x00045b6a      6f610044       mov.w @(0x44:16,r6),r1
0x00045b6e      1910           sub.w r1,r0
0x00045b70      6f610064       mov.w @(0x64:16,r6),r1
0x00045b74      1910           sub.w r1,r0
0x00045b76      0d21           mov.w r2,r1
0x00045b78      1d01           cmp.w r0,r1
0x00045b7a      4340           bls @@0x40:8
0x00045b7c      6f600044       mov.w @(0x44:16,r6),r0
0x00045b80      6f610046       mov.w @(0x46:16,r6),r1
0x00045b84      0910           add.w r1,r0
0x00045b86      6f610044       mov.w @(0x44:16,r6),r1
0x00045b8a      1910           sub.w r1,r0
0x00045b8c      6f610064       mov.w @(0x64:16,r6),r1
0x00045b90      1910           sub.w r1,r0
0x00045b92      6ba00040       mov.w r0,@0x40:16
0x00045b96      74ca           bior #0x4:3,r2l
0x00045b98      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045b9c      1790           neg r0h
0x00045b9e      69c0           mov.w r0,@r4
0x00045ba0      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045ba4      1010           shal r0h
0x00045ba6      1790           neg r0h
0x00045ba8      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045bac      7900ffba       mov.w #0xffba:16,r0
0x00045bb0      69b0           mov.w r0,@r3
0x00045bb2      7900ff74       mov.w #0xff74:16,r0
0x00045bb6      6fb00002       mov.w r0,@(0x2:16,r3)
0x00045bba      4076           bra @@0x76:8
0x00045bbc      6f600046       mov.w @(0x46:16,r6),r0
0x00045bc0      6f610044       mov.w @(0x44:16,r6),r1
0x00045bc4      1910           sub.w r1,r0
0x00045bc6      6f61005c       mov.w @(0x5c:16,r6),r1
0x00045bca      1910           sub.w r1,r0
0x00045bcc      6f610064       mov.w @(0x64:16,r6),r1
0x00045bd0      1910           sub.w r1,r0
0x00045bd2      0d21           mov.w r2,r1
0x00045bd4      1d01           cmp.w r0,r1
0x00045bd6      432e           bls @@0x2e:8
0x00045bd8      0d20           mov.w r2,r0
0x00045bda      6f610044       mov.w @(0x44:16,r6),r1
0x00045bde      0910           add.w r1,r0
0x00045be0      6ba00040       mov.w r0,@0x40:16
0x00045be4      74ca           bior #0x4:3,r2l
0x00045be6      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045bea      1790           neg r0h
0x00045bec      69c0           mov.w r0,@r4
0x00045bee      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045bf2      1010           shal r0h
0x00045bf4      1790           neg r0h
0x00045bf6      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045bfa      7900ffba       mov.w #0xffba:16,r0
0x00045bfe      69b0           mov.w r0,@r3
0x00045c00      7900ff74       mov.w #0xff74:16,r0
0x00045c04      4028           bra @@0x28:8
0x00045c06      0d20           mov.w r2,r0
0x00045c08      6f610044       mov.w @(0x44:16,r6),r1
0x00045c0c      0910           add.w r1,r0
0x00045c0e      6ba00040       mov.w r0,@0x40:16
0x00045c12      74ca           bior #0x4:3,r2l
0x00045c14      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045c18      69c0           mov.w r0,@r4
0x00045c1a      6f60005c       mov.w @(0x5c:16,r6),r0
0x00045c1e      1790           neg r0h
0x00045c20      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045c24      79000046       mov.w #0x46:16,r0
0x00045c28      69b0           mov.w r0,@r3
0x00045c2a      7900ffba       mov.w #0xffba:16,r0
0x00045c2e      6fb00002       mov.w r0,@(0x2:16,r3)
0x00045c32      6f60005e       mov.w @(0x5e:16,r6),r0
0x00045c36      1110           shar r0h
0x00045c38      6f610062       mov.w @(0x62:16,r6),r1
0x00045c3c      0910           add.w r1,r0
0x00045c3e      0da1           mov.w r10,r1
0x00045c40      1d01           cmp.w r0,r1
0x00045c42      4426           bcc @@0x26:8
0x00045c44      6f60005e       mov.w @(0x5e:16,r6),r0
0x00045c48      1110           shar r0h
0x00045c4a      6f610062       mov.w @(0x62:16,r6),r1
0x00045c4e      0910           add.w r1,r0
0x00045c50      6ba00040       mov.w r0,@0x40:16
0x00045c54      52             invalid
0x00045c55      a26f           cmp.b #0x6f:8,r2h
0x00045c57      6000           bset r0h,r0h
0x00045c59      6069           bset r6h,r1l
0x00045c5b      d06f           xor #0x6f:8,r0h
0x00045c5d      6000           bset r0h,r0h
0x00045c5f      6010           bset r1h,r0h
0x00045c61      106f           shal r7l
0x00045c63      d000           xor #0x0:8,r0h
0x00045c65      025a           stc ccr,r2l
0x00045c67      045d           orc #0x5d:8,ccr
0x00045c69      326f           mov.b r2h,@0x6f:8
0x00045c6b      6000           bset r0h,r0h
0x00045c6d      5e11106f       jsr @0x106f:16
0x00045c71      6100           bnot r0h,r0h
0x00045c73      6009           bset r0h,r1l
0x00045c75      106f           shal r7l
0x00045c77      6100           bnot r0h,r0h
0x00045c79      6209           bclr r0h,r1l
0x00045c7b      100d           shll r5l
0x00045c7d      a11d           cmp.b #0x1d:8,r1h
0x00045c7f      01441a6b       sleep
0x00045c83      aa00           cmp.b #0x0:8,r2l
0x00045c85      4052           bra @@0x52:8
0x00045c87      a26f           cmp.b #0x6f:8,r2h
0x00045c89      6000           bset r0h,r0h
0x00045c8b      6069           bset r6h,r1l
0x00045c8d      d06f           xor #0x6f:8,r0h
0x00045c8f      6000           bset r0h,r0h
0x00045c91      6010           bset r1h,r0h
0x00045c93      106f           shal r7l
0x00045c95      d000           xor #0x0:8,r0h
0x00045c97      025a           stc ccr,r2l
0x00045c99      045d           orc #0x5d:8,ccr
0x00045c9b      326f           mov.b r2h,@0x6f:8
0x00045c9d      6000           bset r0h,r0h
0x00045c9f      5e11106f       jsr @0x106f:16
0x00045ca3      6100           bnot r0h,r0h
0x00045ca5      4a19           bpl @@0x19:8
0x00045ca7      016f6000       sleep
0x00045cab      6219           bclr r1h,r1l
0x00045cad      011b510d       sleep
0x00045cb1      a01d           cmp.b #0x1d:8,r0h
0x00045cb3      1043           shal r3h
0x00045cb5      306f           mov.b r0h,@0x6f:8
0x00045cb7      6000           bset r0h,r0h
0x00045cb9      5e11106f       jsr @0x106f:16
0x00045cbd      6100           bnot r0h,r0h
0x00045cbf      4a19           bpl @@0x19:8
0x00045cc1      016f6000       sleep
0x00045cc5      6219           bclr r1h,r1l
0x00045cc7      011b516b       sleep
0x00045ccb      a100           cmp.b #0x0:8,r1h
0x00045ccd      4052           bra @@0x52:8
0x00045ccf      a26f           cmp.b #0x6f:8,r2h
0x00045cd1      6000           bset r0h,r0h
0x00045cd3      6017           bset r1h,r7h
0x00045cd5      9069           addx #0x69:8,r0h
0x00045cd7      d06f           xor #0x6f:8,r0h
0x00045cd9      6000           bset r0h,r0h
0x00045cdb      6010           bset r1h,r0h
0x00045cdd      1017           shal r7h
0x00045cdf      906f           addx #0x6f:8,r0h
0x00045ce1      d000           xor #0x0:8,r0h
0x00045ce3      0240           stc ccr,r0h
0x00045ce5      4c6f           bge @@0x6f:8
0x00045ce7      6000           bset r0h,r0h
0x00045ce9      5e11106f       jsr @0x106f:16
0x00045ced      6100           bnot r0h,r0h
0x00045cef      4a19           bpl @@0x19:8
0x00045cf1      016f6000       sleep
0x00045cf5      6019           bset r1h,r1l
0x00045cf7      016f6000       sleep
0x00045cfb      6219           bclr r1h,r1l
0x00045cfd      011b510d       sleep
0x00045d01      a01d           cmp.b #0x1d:8,r0h
0x00045d03      1043           shal r3h
0x00045d05      166b           and r6h,r3l
0x00045d07      aa             cmp.b #0x10:8,r2l
0x00045d09      4052           bra @@0x52:8
0x00045d0b      a26f           cmp.b #0x6f:8,r2h
0x00045d0d      6000           bset r0h,r0h
0x00045d0f      6017           bset r1h,r7h
0x00045d11      9069           addx #0x69:8,r0h
0x00045d13      d06f           xor #0x6f:8,r0h
0x00045d15      6000           bset r0h,r0h
0x00045d17      6010           bset r1h,r0h
0x00045d19      1040           shal r0h
0x00045d1b      106b           shal r3l
0x00045d1d      aa00           cmp.b #0x0:8,r2l
0x00045d1f      4052           bra @@0x52:8
0x00045d21      a26f           cmp.b #0x6f:8,r2h
0x00045d23      6000           bset r0h,r0h
0x00045d25      6069           bset r6h,r1l
0x00045d27      d06f           xor #0x6f:8,r0h
0x00045d29      6000           bset r0h,r0h
0x00045d2b      6017           bset r1h,r7h
0x00045d2d      906f           addx #0x6f:8,r0h
0x00045d2f      d000           xor #0x0:8,r0h
0x00045d31      0201           stc ccr,r1h
0x00045d33      006b           nop
0x00045d35      2000           mov.b @0x0:8,r0h
0x00045d37      4052           bra @@0x52:8
0x00045d39      ca01           or #0x1:8,r2l
0x00045d3b      006b           nop
0x00045d3d      a000           cmp.b #0x0:8,r0h
0x00045d3f      4076           bra @@0x76:8
0x00045d41      2a6f           mov.b @0x6f:8,r2l
0x00045d43      6000           bset r0h,r0h
0x00045d45      5e5a045f       jsr @0x45f:16
0x00045d49      ae18           cmp.b #0x18:8,r6l
0x00045d4b      886a           add.b #0x6a:8,r0l
0x00045d4d      a800           cmp.b #0x0:8,r0l
0x00045d4f      4076           bra @@0x76:8
0x00045d51      290d           mov.b @0xd:8,r1l
0x00045d53      206f           mov.b @0x6f:8,r0h
0x00045d55      6100           bnot r0h,r0h
0x00045d57      861d           add.b #0x1d:8,r6h
0x00045d59      1044           shal r4h
0x00045d5b      326f           mov.b r2h,@0x6f:8
0x00045d5d      6000           bset r0h,r0h
0x00045d5f      66             invalid
0x00045d60      6f610086       mov.w @(0x86:16,r6),r1
0x00045d64      0910           add.w r1,r0
0x00045d66      6ba00040       mov.w r0,@0x40:16
0x00045d6a      74ca           bior #0x4:3,r2l
0x00045d6c      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045d70      69c0           mov.w r0,@r4
0x00045d72      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045d76      1010           shal r0h
0x00045d78      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045d7c      79000046       mov.w #0x46:16,r0
0x00045d80      69b0           mov.w r0,@r3
0x00045d82      7900008c       mov.w #0x8c:16,r0
0x00045d86      6fb00002       mov.w r0,@(0x2:16,r3)
0x00045d8a      5a045e9a       jmp @0x5e9a:16
0x00045d8e      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045d92      6f610086       mov.w @(0x86:16,r6),r1
0x00045d96      0910           add.w r1,r0
0x00045d98      0d21           mov.w r2,r1
0x00045d9a      1d01           cmp.w r0,r1
0x00045d9c      4430           bcc @@0x30:8
0x00045d9e      0d20           mov.w r2,r0
0x00045da0      6f610066       mov.w @(0x66:16,r6),r1
0x00045da4      0910           add.w r1,r0
0x00045da6      6ba00040       mov.w r0,@0x40:16
0x00045daa      74ca           bior #0x4:3,r2l
0x00045dac      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045db0      69c0           mov.w r0,@r4
0x00045db2      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045db6      1010           shal r0h
0x00045db8      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045dbc      79000046       mov.w #0x46:16,r0
0x00045dc0      69b0           mov.w r0,@r3
0x00045dc2      7900008c       mov.w #0x8c:16,r0
0x00045dc6      6fb00002       mov.w r0,@(0x2:16,r3)
0x00045dca      5a045e9a       jmp @0x5e9a:16
0x00045dce      6f600068       mov.w @(0x68:16,r6),r0
0x00045dd2      6f610066       mov.w @(0x66:16,r6),r1
0x00045dd6      1910           sub.w r1,r0
0x00045dd8      6f610086       mov.w @(0x86:16,r6),r1
0x00045ddc      1910           sub.w r1,r0
0x00045dde      0d21           mov.w r2,r1
0x00045de0      1d01           cmp.w r0,r1
0x00045de2      4340           bls @@0x40:8
0x00045de4      6f600066       mov.w @(0x66:16,r6),r0
0x00045de8      6f610068       mov.w @(0x68:16,r6),r1
0x00045dec      0910           add.w r1,r0
0x00045dee      6f610066       mov.w @(0x66:16,r6),r1
0x00045df2      1910           sub.w r1,r0
0x00045df4      6f610086       mov.w @(0x86:16,r6),r1
0x00045df8      1910           sub.w r1,r0
0x00045dfa      6ba00040       mov.w r0,@0x40:16
0x00045dfe      74ca           bior #0x4:3,r2l
0x00045e00      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045e04      1790           neg r0h
0x00045e06      69c0           mov.w r0,@r4
0x00045e08      6f             mov.w @(0x100:16,r1),r0
0x00045e0c      1010           shal r0h
0x00045e0e      1790           neg r0h
0x00045e10      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045e14      7900ffba       mov.w #0xffba:16,r0
0x00045e18      69b0           mov.w r0,@r3
0x00045e1a      7900ff74       mov.w #0xff74:16,r0
0x00045e1e      6fb00002       mov.w r0,@(0x2:16,r3)
0x00045e22      4076           bra @@0x76:8
0x00045e24      6f600068       mov.w @(0x68:16,r6),r0
0x00045e28      6f610066       mov.w @(0x66:16,r6),r1
0x00045e2c      1910           sub.w r1,r0
0x00045e2e      6f61007e       mov.w @(0x7e:16,r6),r1
0x00045e32      1910           sub.w r1,r0
0x00045e34      6f610086       mov.w @(0x86:16,r6),r1
0x00045e38      1910           sub.w r1,r0
0x00045e3a      0d21           mov.w r2,r1
0x00045e3c      1d01           cmp.w r0,r1
0x00045e3e      432e           bls @@0x2e:8
0x00045e40      0d20           mov.w r2,r0
0x00045e42      6f610066       mov.w @(0x66:16,r6),r1
0x00045e46      0910           add.w r1,r0
0x00045e48      6ba00040       mov.w r0,@0x40:16
0x00045e4c      74ca           bior #0x4:3,r2l
0x00045e4e      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045e52      1790           neg r0h
0x00045e54      69c0           mov.w r0,@r4
0x00045e56      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045e5a      1010           shal r0h
0x00045e5c      1790           neg r0h
0x00045e5e      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045e62      7900ffba       mov.w #0xffba:16,r0
0x00045e66      69b0           mov.w r0,@r3
0x00045e68      7900ff74       mov.w #0xff74:16,r0
0x00045e6c      4028           bra @@0x28:8
0x00045e6e      0d20           mov.w r2,r0
0x00045e70      6f610066       mov.w @(0x66:16,r6),r1
0x00045e74      0910           add.w r1,r0
0x00045e76      6ba00040       mov.w r0,@0x40:16
0x00045e7a      74ca           bior #0x4:3,r2l
0x00045e7c      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045e80      69c0           mov.w r0,@r4
0x00045e82      6f60007e       mov.w @(0x7e:16,r6),r0
0x00045e86      1790           neg r0h
0x00045e88      6fc00002       mov.w r0,@(0x2:16,r4)
0x00045e8c      79000046       mov.w #0x46:16,r0
0x00045e90      69b0           mov.w r0,@r3
0x00045e92      7900ffba       mov.w #0xffba:16,r0
0x00045e96      6fb00002       mov.w r0,@(0x2:16,r3)
0x00045e9a      6f600080       mov.w @(0x80:16,r6),r0
0x00045e9e      1110           shar r0h
0x00045ea0      6f610084       mov.w @(0x84:16,r6),r1
0x00045ea4      0910           add.w r1,r0
0x00045ea6      0da1           mov.w r10,r1
0x00045ea8      1d01           cmp.w r0,r1
0x00045eaa      4426           bcc @@0x26:8
0x00045eac      6f600080       mov.w @(0x80:16,r6),r0
0x00045eb0      1110           shar r0h
0x00045eb2      6f610084       mov.w @(0x84:16,r6),r1
0x00045eb6      0910           add.w r1,r0
0x00045eb8      6ba00040       mov.w r0,@0x40:16
0x00045ebc      52             invalid
0x00045ebd      a26f           cmp.b #0x6f:8,r2h
0x00045ebf      6000           bset r0h,r0h
0x00045ec1      8269           add.b #0x69:8,r2h
0x00045ec3      d06f           xor #0x6f:8,r0h
0x00045ec5      6000           bset r0h,r0h
0x00045ec7      8210           add.b #0x10:8,r2h
0x00045ec9      106f           shal r7l
0x00045ecb      d000           xor #0x0:8,r0h
0x00045ecd      025a           stc ccr,r2l
0x00045ecf      045f           orc #0x5f:8,ccr
0x00045ed1      9a6f           addx #0x6f:8,r2l
0x00045ed3      6000           bset r0h,r0h
0x00045ed5      8011           add.b #0x11:8,r0h
0x00045ed7      106f           shal r7l
0x00045ed9      6100           bnot r0h,r0h
0x00045edb      8209           add.b #0x9:8,r2h
0x00045edd      106f           shal r7l
0x00045edf      6100           bnot r0h,r0h
0x00045ee1      8409           add.b #0x9:8,r4h
0x00045ee3      100d           shll r5l
0x00045ee5      a11d           cmp.b #0x1d:8,r1h
0x00045ee7      01441a6b       sleep
0x00045eeb      aa00           cmp.b #0x0:8,r2l
0x00045eed      4052           bra @@0x52:8
0x00045eef      a26f           cmp.b #0x6f:8,r2h
0x00045ef1      6000           bset r0h,r0h
0x00045ef3      8269           add.b #0x69:8,r2h
0x00045ef5      d06f           xor #0x6f:8,r0h
0x00045ef7      6000           bset r0h,r0h
0x00045ef9      8210           add.b #0x10:8,r2h
0x00045efb      106f           shal r7l
0x00045efd      d000           xor #0x0:8,r0h
0x00045eff      025a           stc ccr,r2l
0x00045f01      045f           orc #0x5f:8,ccr
0x00045f03      9a6f           addx #0x6f:8,r2l
0x00045f05      6000           bset r0h,r0h
0x00045f07      8011           add.b #0x11:8,r0h
0x00045f09      106f           shal r7l
0x00045f0b      61             bnot r1h,r0h
0x00045f0d      6c19           mov.b @r1+,r1l
0x00045f0f      016f6000       sleep
0x00045f13      8419           add.b #0x19:8,r4h
0x00045f15      011b510d       sleep
0x00045f19      a01d           cmp.b #0x1d:8,r0h
0x00045f1b      1043           shal r3h
0x00045f1d      306f           mov.b r0h,@0x6f:8
0x00045f1f      6000           bset r0h,r0h
0x00045f21      8011           add.b #0x11:8,r0h
0x00045f23      106f           shal r7l
0x00045f25      6100           bnot r0h,r0h
0x00045f27      6c19           mov.b @r1+,r1l
0x00045f29      016f6000       sleep
0x00045f2d      8419           add.b #0x19:8,r4h
0x00045f2f      011b516b       sleep
0x00045f33      a100           cmp.b #0x0:8,r1h
0x00045f35      4052           bra @@0x52:8
0x00045f37      a26f           cmp.b #0x6f:8,r2h
0x00045f39      6000           bset r0h,r0h
0x00045f3b      8217           add.b #0x17:8,r2h
0x00045f3d      9069           addx #0x69:8,r0h
0x00045f3f      d06f           xor #0x6f:8,r0h
0x00045f41      6000           bset r0h,r0h
0x00045f43      8210           add.b #0x10:8,r2h
0x00045f45      1017           shal r7h
0x00045f47      906f           addx #0x6f:8,r0h
0x00045f49      d000           xor #0x0:8,r0h
0x00045f4b      0240           stc ccr,r0h
0x00045f4d      4c6f           bge @@0x6f:8
0x00045f4f      6000           bset r0h,r0h
0x00045f51      8011           add.b #0x11:8,r0h
0x00045f53      106f           shal r7l
0x00045f55      6100           bnot r0h,r0h
0x00045f57      6c19           mov.b @r1+,r1l
0x00045f59      016f6000       sleep
0x00045f5d      8219           add.b #0x19:8,r2h
0x00045f5f      016f6000       sleep
0x00045f63      8419           add.b #0x19:8,r4h
0x00045f65      011b510d       sleep
0x00045f69      a01d           cmp.b #0x1d:8,r0h
0x00045f6b      1043           shal r3h
0x00045f6d      166b           and r6h,r3l
0x00045f6f      aa00           cmp.b #0x0:8,r2l
0x00045f71      4052           bra @@0x52:8
0x00045f73      a26f           cmp.b #0x6f:8,r2h
0x00045f75      6000           bset r0h,r0h
0x00045f77      8217           add.b #0x17:8,r2h
0x00045f79      9069           addx #0x69:8,r0h
0x00045f7b      d06f           xor #0x6f:8,r0h
0x00045f7d      6000           bset r0h,r0h
0x00045f7f      8210           add.b #0x10:8,r2h
0x00045f81      1040           shal r0h
0x00045f83      106b           shal r3l
0x00045f85      aa00           cmp.b #0x0:8,r2l
0x00045f87      4052           bra @@0x52:8
0x00045f89      a26f           cmp.b #0x6f:8,r2h
0x00045f8b      6000           bset r0h,r0h
0x00045f8d      8269           add.b #0x69:8,r2h
0x00045f8f      d06f           xor #0x6f:8,r0h
0x00045f91      6000           bset r0h,r0h
0x00045f93      8217           add.b #0x17:8,r2h
0x00045f95      906f           addx #0x6f:8,r0h
0x00045f97      d000           xor #0x0:8,r0h
0x00045f99      0201           stc ccr,r1h
0x00045f9b      006b           nop
0x00045f9d      2000           mov.b @0x0:8,r0h
0x00045f9f      4052           bra @@0x52:8
0x00045fa1      ca01           or #0x1:8,r2l
0x00045fa3      006b           nop
0x00045fa5      a000           cmp.b #0x0:8,r0h
0x00045fa7      4076           bra @@0x76:8
0x00045fa9      2a6f           mov.b @0x6f:8,r2l
0x00045fab      6000           bset r0h,r0h
0x00045fad      806b           add.b #0x6b:8,r0h
0x00045faf      a000           cmp.b #0x0:8,r0h
0x00045fb1      4052           bra @@0x52:8
0x00045fb3      a46b           cmp.b #0x6b:8,r4h
0x00045fb5      2000           mov.b @0x0:8,r0h
0x00045fb7      4052           bra @@0x52:8
0x00045fb9      a411           cmp.b #0x11:8,r4h
0x00045fbb      106b           shal r3l
0x00045fbd      2100           mov.b @0x0:8,r1h
0x00045fbf      4052           bra @@0x52:8
0x00045fc1      a219           cmp.b #0x19:8,r2h
0x00045fc3      016ba100       sleep
0x00045fc7      4074           bra @@0x74:8
0x00045fc9      d86b           xor #0x6b:8,r0l
0x00045fcb      2000           mov.b @0x0:8,r0h
0x00045fcd      4052           bra @@0x52:8
0x00045fcf      a417           cmp.b #0x17:8,r4h
0x00045fd1      f079           mov.b #0x79:8,r0h
0x00045fd3      01000201       sleep
0x00045fd7      d053           xor #0x53:8,r0h
0x00045fd9      1069           shal r1l
0x00045fdb      5119           divxu r1h,r1
0x00045fdd      016b2000       sleep
0x00045fe1      4052           bra @@0x52:8
0x00045fe3      a209           cmp.b #0x9:8,r2h
0x00045fe5      016ba100       sleep
0x00045fe9      4074           bra @@0x74:8
0x00045feb      da6b           xor #0x6b:8,r2l
0x00045fed      2000           mov.b @0x0:8,r0h
0x00045fef      4052           bra @@0x52:8
0x00045ff1      a417           cmp.b #0x17:8,r4h
0x00045ff3      f079           mov.b #0x79:8,r0h
0x00045ff5      01000201       sleep
0x00045ff9      d053           xor #0x53:8,r0h
0x00045ffb      106f           shal r7l
0x00045ffd      5100           divxu r0h,r0
0x00045fff      0219           stc ccr,r1l
0x00046001      016b2000       sleep
0x00046005      4052           bra @@0x52:8
0x00046007      a209           cmp.b #0x9:8,r2h
0x00046009      016ba100       sleep
0x0004600d      4074           bra @@0x74:8
0x0004600f      dc6b           xor #0x6b:8,r4l
0x00046011      2000           mov.b @0x0:8,r0h
0x00046013      4074           bra @@0x74:8
0x00046015      ca6b           or #0x6b:8,r2l
0x00046017      a000           cmp.b #0x0:8,r0h
0x00046019      4074           bra @@0x74:8
0x0004601b      de6b           xor #0x6b:8,r6l
0x0004601d      2000           mov.b @0x0:8,r0h
0x0004601f      4074           bra @@0x74:8
0x00046021      ca69           or #0x69:8,r2l
0x00046023      4109           brn @@0x9:8
0x00046025      106b           shal r3l
0x00046027      a000           cmp.b #0x0:8,r0h
0x00046029      4074           bra @@0x74:8
0x0004602b      e06b           and #0x6b:8,r0h
0x0004602d      2000           mov.b @0x0:8,r0h
0x0004602f      4074           bra @@0x74:8
0x00046031      ca6f           or #0x6f:8,r2l
0x00046033      4100           brn @@0x0:8
0x00046035      0209           stc ccr,r1l
0x00046037      106b           shal r3l
0x00046039      a000           cmp.b #0x0:8,r0h
0x0004603b      4074           bra @@0x74:8
0x0004603d      e27a           and #0x7a:8,r2h
0x0004603f      1700           not r0h
0x00046041      0000           nop
0x00046043      205e           mov.b @0x5e:8,r0h
0x00046045      01643654       sleep
0x00046049      706d           bset #0x6:3,r5l
0x0004604b      f60c           mov.b #0xc:8,r6h
0x0004604d      860c           add.b #0xc:8,r6h
0x0004604f      0e79           addx r7h,r1l
0x00046051      005a           nop
0x00046053      006b           nop
0x00046055      80ff           add.b #0xff:8,r0h
0x00046057      a81a           cmp.b #0x1a:8,r0l
0x00046059      806a           add.b #0x6a:8,r0h
0x0004605b      2800           mov.b @0x0:8,r0l
0x0004605d      404e           bra @@0x4e:8
0x0004605f      9710           addx #0x10:8,r7h
0x00046061      3010           mov.b r0h,@0x10:8
0x00046063      301a           mov.b r0h,@0x1a:8
0x00046065      910c           addx #0xc:8,r1h
0x00046067      e910           and #0x10:8,r1l
0x00046069      3178           mov.b r1h,@0x78:8
0x0004606b      106b           shal r3l
0x0004606d      2100           mov.b @0x0:8,r1h
0x0004606f      4074           bra @@0x74:8
0x00046071      d817           xor #0x17:8,r0l
0x00046073      7110           bnot #0x1:3,r0h
0x00046075      3101           mov.b r1h,@0x1:8
0x00046077      0078           nop
0x00046079      006b           nop
0x0004607b      2000           mov.b @0x0:8,r0h
0x0004607d      404e           bra @@0x4e:8
0x0004607f      a20a           cmp.b #0xa:8,r2h
0x00046081      9001           addx #0x1:8,r0h
0x00046083      006b           nop
0x00046085      a000           cmp.b #0x0:8,r0h
0x00046087      407b           bra @@0x7b:8
0x00046089      6ea60146       mov.b r6h,@(0x146:16,r2)
0x0004608d      065e           andc #0x5e:8,ccr
0x0004608f      0492           orc #0x92:8,ccr
0x00046091      8a40           add.b #0x40:8,r2l
0x00046093      045e           orc #0x5e:8,ccr
0x00046095      0492           orc #0x92:8,ccr
0x00046097      8e6d           add.b #0x6d:8,r6l
0x00046099      7654           band #0x5:3,r4h
0x0004609b      705e           bset #0x5:3,r6l
0x0004609d      0164587a       sleep
0x000460a1      3700           mov.b r7h,@0x0:8
0x000460a3      0000           nop
0x000460a5      547a           rts
0x000460a7      0300           ldc r0h,ccr
0x000460a9      4074           bra @@0x74:8
0x000460ab      de7a           xor #0x7a:8,r6l
0x000460ad      0400           orc #0x0:8,ccr
0x000460af      4052           bra @@0x52:8
0x000460b1      a67a           cmp.b #0x7a:8,r6h
0x000460b3      0500           xorc #0x0:8,ccr
0x000460b5      4076           bra @@0x76:8
0x000460b7      267a           mov.b @0x7a:8,r6h
0x000460b9      0600           andc #0x0:8,ccr
0x000460bb      4007           bra @@0x7:8
0x000460bd      7318           btst #0x1:3,r0l
0x000460bf      8840           add.b #0x40:8,r0l
0x000460c1      1c1a           cmp.b r1h,r2l
0x000460c3      800c           add.b #0xc:8,r0h
0x000460c5      a87a           cmp.b #0x7a:8,r0l
0x000460c7      01000000       sleep
0x000460cb      200a           mov.b @0xa:8,r0h
0x000460cd      f10a           mov.b #0xa:8,r1h
0x000460cf      8178           add.b #0x78:8,r1h
0x000460d1      006a           nop
0x000460d3      2800           mov.b @0x0:8,r0l
0x000460d5      404e           bra @@0x4e:8
0x000460d7      5068           mulxu r6h,r0
0x000460d9      980c           addx #0xc:8,r0l
0x000460db      a80a           cmp.b #0xa:8,r0l
0x000460dd      080c           add.b r0h,r4l
0x000460df      8aa8           add.b #0xa8:8,r2l
0x000460e1      0445           orc #0x45:8,ccr
0x000460e3      de68           xor #0x68:8,r6l
0x000460e5      68a8           mov.b r0l,@r2
0x000460e7      01471268       sleep
0x000460eb      68a8           mov.b r0l,@r2
0x000460ed      0247           stc ccr,r7h
0x000460ef      0c68           mov.b r6h,r0l
0x000460f1      68a8           mov.b r0l,@r2
0x000460f3      0447           orc #0x47:8,ccr
0x000460f5      0668           andc #0x68:8,ccr
0x000460f7      68a8           mov.b r0l,@r2
0x000460f9      0546           xorc #0x46:8,ccr
0x000460fb      6e6a2800       mov.b @(0x2800:16,r6),r2l
0x000460ff      400e           bra @@0xe:8
0x00046101      92a8           addx #0xa8:8,r2h
0x00046103      0646           andc #0x46:8,ccr
0x00046105      1e68           subx r6h,r0l
0x00046107      68a8           mov.b r0l,@r2
0x00046109      01470c68       sleep
0x0004610d      68a8           mov.b r0l,@r2
0x0004610f      0447           orc #0x47:8,ccr
0x00046111      0668           andc #0x68:8,ccr
0x00046113      68a8           mov.b r0l,@r2
0x00046115      0546           xorc #0x46:8,ccr
0x00046117      0679           andc #0x79:8,ccr
0x00046119      0003           nop
0x0004611b      0040           nop
0x0004611d      4279           bhi @@0x79:8
0x0004611f      0004           nop
0x00046121      0040           nop
0x00046123      3c6a           mov.b r4l,@0x6a:8
0x00046125      2800           mov.b @0x0:8,r0l
0x00046127      400e           bra @@0xe:8
0x00046129      92a8           addx #0xa8:8,r2h
0x0004612b      01470e79       sleep
0x0004612f      0090           nop
0x00046131      006b           nop
0x00046133      a000           cmp.b #0x0:8,r0h
0x00046135      4007           bra @@0x7:8
0x00046137      7a             invalid
0x00046138      5a046826       jmp @0x6826:16
0x0004613c      6a280040       mov.b @0x40:16,r0l
0x00046140      0790           ldc #0x90:8,ccr
0x00046142      4626           bne @@0x26:8
0x00046144      6868           mov.b @r6,r0l
0x00046146      a801           cmp.b #0x1:8,r0l
0x00046148      470c           beq @@0xc:8
0x0004614a      6868           mov.b @r6,r0l
0x0004614c      a804           cmp.b #0x4:8,r0l
0x0004614e      4706           beq @@0x6:8
0x00046150      6868           mov.b @r6,r0l
0x00046152      a805           cmp.b #0x5:8,r0l
0x00046154      4606           bne @@0x6:8
0x00046156      79000300       mov.w #0x300:16,r0
0x0004615a      4004           bra @@0x4:8
0x0004615c      79000400       mov.w #0x400:16,r0
0x00046160      6ba00040       mov.w r0,@0x40:16
0x00046164      0778           ldc #0x78:8,ccr
0x00046166      5a046826       jmp @0x6826:16
0x0004616a      7a             invalid
0x0004616b      0000           nop
0x0004616d      407d           bra @@0x7d:8
0x0004616f      0a68           inc r0l
0x00046171      090a           add.w r0,r2
0x00046173      0968           add.w r6,r0
0x00046175      8918           add.b #0x18:8,r1l
0x00046177      880c           add.b #0xc:8,r0l
0x00046179      8a40           add.b #0x40:8,r2l
0x0004617b      2e1a           mov.b @0x1a:8,r6l
0x0004617d      800c           add.b #0xc:8,r0h
0x0004617f      a810           cmp.b #0x10:8,r0l
0x00046181      3010           mov.b r0h,@0x10:8
0x00046183      3001           mov.b r0h,@0x1:8
0x00046185      006f           nop
0x00046187      f000           mov.b #0x0:8,r0h
0x00046189      4a01           bpl @@0x1:8
0x0004618b      006f           nop
0x0004618d      7100           bnot #0x0:3,r0h
0x0004618f      4a01           bpl @@0x1:8
0x00046191      0078           nop
0x00046193      106b           shal r3l
0x00046195      2100           mov.b @0x0:8,r1h
0x00046197      4010           bra @@0x10:8
0x00046199      78             invalid
0x0004619a      01007880       sleep
0x0004619e      6ba10040       mov.w r1,@0x40:16
0x000461a2      52             invalid
0x000461a3      b60c           subx #0xc:8,r6h
0x000461a5      a90a           cmp.b #0xa:8,r1l
0x000461a7      090c           add.w r0,r4
0x000461a9      9a0c           addx #0xc:8,r2l
0x000461ab      a8a8           cmp.b #0xa8:8,r0l
0x000461ad      0445           orc #0x45:8,ccr
0x000461af      ccf8           or #0xf8:8,r4l
0x000461b1      016aa800       sleep
0x000461b5      404e           bra @@0x4e:8
0x000461b7      7d             invalid
0x000461b8      5e037d18       jsr @0x7d18:16
0x000461bc      1888           sub.b r0l,r0l
0x000461be      6aa80040       mov.b r0l,@0x40:16
0x000461c2      4e7d           bgt @@0x7d:8
0x000461c4      5c             invalid
0x000461c5      00f2           nop
0x000461c7      5c             invalid
0x000461c8      6b200040       mov.w @0x40:16,r0
0x000461cc      0778           ldc #0x78:8,ccr
0x000461ce      58             invalid
0x000461cf      6006           bset r0h,r6h
0x000461d1      5468           rts
0x000461d3      68a8           mov.b r0l,@r2
0x000461d5      0247           stc ccr,r7h
0x000461d7      1268           rotl r0l
0x000461d9      68a8           mov.b r0l,@r2
0x000461db      01470c68       sleep
0x000461df      68a8           mov.b r0l,@r2
0x000461e1      0447           orc #0x47:8,ccr
0x000461e3      0668           andc #0x68:8,ccr
0x000461e5      68a8           mov.b r0l,@r2
0x000461e7      0546           xorc #0x46:8,ccr
0x000461e9      1218           rotl r0l
0x000461eb      887e           add.b #0x7e:8,r0l
0x000461ed      d277           xor #0x77:8,r2h
0x000461ef      1067           shal r7h
0x000461f1      086a           add.b r6h,r2l
0x000461f3      a800           cmp.b #0x0:8,r0l
0x000461f5      4053           bra @@0x53:8
0x000461f7      037f           ldc r7l,ccr
0x000461f9      d270           xor #0x70:8,r2h
0x000461fb      105e           shal r6l
0x000461fd      0492           orc #0x92:8,ccr
0x000461ff      9219           addx #0x19:8,r2h
0x00046201      0040           nop
0x00046203      120d           rotxl r5l
0x00046205      9017           addx #0x17:8,r0h
0x00046207      f0f9           mov.b #0xf9:8,r0h
0x00046209      0178006a       sleep
0x0004620d      a900           cmp.b #0x0:8,r1l
0x0004620f      400f           bra @@0xf:8
0x00046211      350d           mov.b r5h,@0xd:8
0x00046213      900b           addx #0xb:8,r0h
0x00046215      500d           mulxu r0h,r5
0x00046217      0979           add.w r7,r1
0x00046219      2000           mov.b @0x0:8,r0h
0x0004621b      034f           ldc r7l,ccr
0x0004621d      e65e           and #0x5e:8,r6h
0x0004621f      0358           ldc r0l,ccr
0x00046221      086b           add.b r6h,r3l
0x00046223      2000           mov.b @0x0:8,r0h
0x00046225      400c           bra @@0xc:8
0x00046227      026f           stc ccr,r7l
0x00046229      f000           mov.b #0x0:8,r0h
0x0004622b      2419           mov.b @0x19:8,r4h
0x0004622d      006b           nop
0x0004622f      a000           cmp.b #0x0:8,r0h
0x00046231      4007           bra @@0x7:8
0x00046233      7a             invalid
0x00046234      79000930       mov.w #0x930:16,r0
0x00046238      6ba00040       mov.w r0,@0x40:16
0x0004623c      0778           ldc #0x78:8,ccr
0x0004623e      1888           sub.b r0l,r0l
0x00046240      6aa80040       mov.b r0l,@0x40:16
0x00046244      7628           band #0x2:3,r0l
0x00046246      6b200040       mov.w @0x40:16,r0
0x0004624a      0776           ldc #0x76:8,ccr
0x0004624c      7370           btst #0x7:3,r0h
0x0004624e      58             invalid
0x0004624f      6005           bset r0h,r5h
0x00046251      6a18886a       mov.b @0x886a:16,r0l
0x00046255      a800           cmp.b #0x0:8,r0l
0x00046257      4076           bra @@0x76:8
0x00046259      27f8           mov.b @0xf8:8,r7h
0x0004625b      0268           stc ccr,r0l
0x0004625d      d8f8           xor #0xf8:8,r0l
0x0004625f      01f901fa       sleep
0x00046263      0119886d       sleep
0x00046267      f21a           mov.b #0x1a:8,r2h
0x00046269      a26a           cmp.b #0x6a:8,r2h
0x0004626b      2a00           mov.b @0x0:8,r2l
0x0004626d      4076           bra @@0x76:8
0x0004626f      2810           mov.b @0x10:8,r0l
0x00046271      320a           mov.b r2h,@0xa:8
0x00046273      b20d           subx #0xd:8,r2h
0x00046275      890c           add.b #0xc:8,r1l
0x00046277      910c           addx #0xc:8,r1h
0x00046279      8969           add.b #0x69:8,r1l
0x0004627b      286f           mov.b @0x6f:8,r0l
0x0004627d      7000           bset #0x0:3,r0h
0x0004627f      265c           mov.b @0x5c:8,r6h
0x00046281      000f           nop
0x00046283      600b           bset r0h,r3l
0x00046285      8701           add.b #0x1:8,r7h
0x00046287      006b           nop
0x00046289      2000           mov.b @0x0:8,r0h
0x0004628b      4052           bra @@0x52:8
0x0004628d      c601           or #0x1:8,r6h
0x0004628f      006b           nop
0x00046291      a000           cmp.b #0x0:8,r0h
0x00046293      407b           bra @@0x7b:8
0x00046295      6a1a8068       mov.b @0x8068:16,r2l
0x00046299      58             invalid
0x0004629a      01006ff0       sleep
0x0004629e      0034           nop
0x000462a0      1030           shal r0h
0x000462a2      1030           shal r0h
0x000462a4      0ac0           inc r0h
0x000462a6      01006ff0       sleep
0x000462aa      001c           nop
0x000462ac      01006f70       sleep
0x000462b0      0034           nop
0x000462b2      7a             invalid
0x000462b3      01000000       sleep
0x000462b7      0c5e           mov.b r5h,r6l
0x000462b9      0163ea1a       sleep
0x000462bd      916a           addx #0x6a:8,r1h
0x000462bf      2900           mov.b @0x0:8,r1l
0x000462c1      4076           bra @@0x76:8
0x000462c3      2710           mov.b @0x10:8,r7h
0x000462c5      3110           mov.b r1h,@0x10:8
0x000462c7      317a           mov.b r1h,@0x7a:8
0x000462c9      1000           shll r0h
0x000462cb      407b           bra @@0x7b:8
0x000462cd      f20a           mov.b #0xa:8,r2h
0x000462cf      9001           addx #0x1:8,r0h
0x000462d1      0069           nop
0x000462d3      0001           nop
0x000462d5      006f           nop
0x000462d7      7100           bnot #0x0:3,r0h
0x000462d9      1c01           cmp.b r0h,r1h
0x000462db      0069           nop
0x000462dd      900f           addx #0xf:8,r0h
0x000462df      c05e           or #0x5e:8,r0h
0x000462e1      039c           ldc r4l,ccr
0x000462e3      8a1a           add.b #0x1a:8,r2l
0x000462e5      8068           add.b #0x68:8,r0h
0x000462e7      58             invalid
0x000462e8      78             invalid
0x000462e9      006a           nop
0x000462eb      2900           mov.b @0x0:8,r1l
0x000462ed      404e           bra @@0x4e:8
0x000462ef      5046           mulxu r4h,r6
0x000462f1      361a           mov.b r6h,@0x1a:8
0x000462f3      8068           add.b #0x68:8,r0h
0x000462f5      58             invalid
0x000462f6      1030           shal r0h
0x000462f8      1030           shal r0h
0x000462fa      01006ff0       sleep
0x000462fe      0034           nop
0x00046300      01006f71       sleep
0x00046304      0034           nop
0x00046306      0ac1           inc r1h
0x00046308      01006911       sleep
0x0004630c      01             sleep
0x00046310      0014           nop
0x00046312      7a             invalid
0x00046313      0000           nop
0x00046315      0000           nop
0x00046317      180a           sub.b r0h,r2l
0x00046319      f05e           mov.b #0x5e:8,r0h
0x0004631b      01648001       sleep
0x0004631f      006b           nop
0x00046321      2100           mov.b @0x0:8,r1h
0x00046323      400f           bra @@0xf:8
0x00046325      8440           add.b #0x40:8,r4h
0x00046327      341a           mov.b r4h,@0x1a:8
0x00046329      8068           add.b #0x68:8,r0h
0x0004632b      58             invalid
0x0004632c      1030           shal r0h
0x0004632e      1030           shal r0h
0x00046330      01006ff0       sleep
0x00046334      0034           nop
0x00046336      01006f71       sleep
0x0004633a      0034           nop
0x0004633c      0ac1           inc r1h
0x0004633e      01006911       sleep
0x00046342      01006ff0       sleep
0x00046346      0014           nop
0x00046348      7a             invalid
0x00046349      0000           nop
0x0004634b      0000           nop
0x0004634d      180a           sub.b r0h,r2l
0x0004634f      f05e           mov.b #0x5e:8,r0h
0x00046351      01648001       sleep
0x00046355      006b           nop
0x00046357      2100           mov.b @0x0:8,r1h
0x00046359      400f           bra @@0xf:8
0x0004635b      8801           add.b #0x1:8,r0l
0x0004635d      006f           nop
0x0004635f      f000           mov.b #0x0:8,r0h
0x00046361      087a           add.b r7h,r2l
0x00046363      0000           nop
0x00046365      0000           nop
0x00046367      0c0a           mov.b r0h,r2l
0x00046369      f05e           mov.b #0x5e:8,r0h
0x0004636b      015db401       sleep
0x0004636f      006f           nop
0x00046371      7100           bnot #0x0:3,r0h
0x00046373      080f           add.b r0h,r7l
0x00046375      820f           add.b #0xf:8,r2h
0x00046377      f05e           mov.b #0x5e:8,r0h
0x00046379      0159a45e       sleep
0x0004637d      015d2e01       sleep
0x00046381      006f           nop
0x00046383      7100           bnot #0x0:3,r0h
0x00046385      1401           or r0h,r1h
0x00046387      0078           nop
0x00046389      906b           addx #0x6b:8,r0h
0x0004638b      a000           cmp.b #0x0:8,r0h
0x0004638d      4052           bra @@0x52:8
0x0004638f      b6f8           subx #0xf8:8,r6h
0x00046391      017a0100       sleep
0x00046395      0000           nop
0x00046397      240a           mov.b @0xa:8,r4h
0x00046399      f15c           mov.b #0x5c:8,r1h
0x0004639b      0005           nop
0x0004639d      c8a8           or #0xa8:8,r0l
0x0004639f      01586001       sleep
0x000463a3      8a01           add.b #0x1:8,r2l
0x000463a5      006b           nop
0x000463a7      2000           mov.b @0x0:8,r0h
0x000463a9      4076           bra @@0x76:8
0x000463ab      2e01           mov.b @0x1:8,r6l
0x000463ad      006b           nop
0x000463af      a000           cmp.b #0x0:8,r0h
0x000463b1      407b           bra @@0x7b:8
0x000463b3      6a6f7000       mov.b @0x7000:16,r7l
0x000463b7      245c           mov.b @0x5c:8,r4h
0x000463b9      000d           nop
0x000463bb      c8a8           or #0xa8:8,r0l
0x000463bd      01587003       sleep
0x000463c1      faf8           mov.b #0xf8:8,r2l
0x000463c3      0368           ldc r0l,ccr
0x000463c5      d8f8           xor #0xf8:8,r0l
0x000463c7      01f901fa       sleep
0x000463cb      0119886d       sleep
0x000463cf      f21a           mov.b #0x1a:8,r2h
0x000463d1      a26a           cmp.b #0x6a:8,r2h
0x000463d3      2a00           mov.b @0x0:8,r2l
0x000463d5      4076           bra @@0x76:8
0x000463d7      2810           mov.b @0x10:8,r0l
0x000463d9      320a           mov.b r2h,@0xa:8
0x000463db      b20d           subx #0xd:8,r2h
0x000463dd      890c           add.b #0xc:8,r1l
0x000463df      910c           addx #0xc:8,r1h
0x000463e1      8969           add.b #0x69:8,r1l
0x000463e3      286f           mov.b @0x6f:8,r0l
0x000463e5      7000           bset #0x0:3,r0h
0x000463e7      265c           mov.b @0x5c:8,r6h
0x000463e9      000d           nop
0x000463eb      f80b           mov.b #0xb:8,r0l
0x000463ed      8701           add.b #0x1:8,r7h
0x000463ef      006b           nop
0x000463f1      2000           mov.b @0x0:8,r0h
0x000463f3      4052           bra @@0x52:8
0x000463f5      c601           or #0x1:8,r6h
0x000463f7      006b           nop
0x000463f9      a000           cmp.b #0x0:8,r0h
0x000463fb      407b           bra @@0x7b:8
0x000463fd      6a1a8068       mov.b @0x8068:16,r2l
0x00046401      58             invalid
0x00046402      01006ff0       sleep
0x00046406      003c           nop
0x00046408      1030           shal r0h
0x0004640a      1030           shal r0h
0x0004640c      0ac0           inc r0h
0x0004640e      0100           sleep
0x00046412      001c           nop
0x00046414      01006f70       sleep
0x00046418      003c           nop
0x0004641a      7a             invalid
0x0004641b      01000000       sleep
0x0004641f      0c5e           mov.b r5h,r6l
0x00046421      0163ea1a       sleep
0x00046425      916a           addx #0x6a:8,r1h
0x00046427      2900           mov.b @0x0:8,r1l
0x00046429      4076           bra @@0x76:8
0x0004642b      2710           mov.b @0x10:8,r7h
0x0004642d      3110           mov.b r1h,@0x10:8
0x0004642f      317a           mov.b r1h,@0x7a:8
0x00046431      1000           shll r0h
0x00046433      407b           bra @@0x7b:8
0x00046435      f20a           mov.b #0xa:8,r2h
0x00046437      9001           addx #0x1:8,r0h
0x00046439      0069           nop
0x0004643b      0001           nop
0x0004643d      006f           nop
0x0004643f      7100           bnot #0x0:3,r0h
0x00046441      1c01           cmp.b r0h,r1h
0x00046443      0069           nop
0x00046445      900f           addx #0xf:8,r0h
0x00046447      c05e           or #0x5e:8,r0h
0x00046449      039c           ldc r4l,ccr
0x0004644b      8a1a           add.b #0x1a:8,r2l
0x0004644d      8068           add.b #0x68:8,r0h
0x0004644f      58             invalid
0x00046450      78             invalid
0x00046451      006a           nop
0x00046453      2900           mov.b @0x0:8,r1l
0x00046455      404e           bra @@0x4e:8
0x00046457      5046           mulxu r4h,r6
0x00046459      361a           mov.b r6h,@0x1a:8
0x0004645b      8068           add.b #0x68:8,r0h
0x0004645d      58             invalid
0x0004645e      1030           shal r0h
0x00046460      1030           shal r0h
0x00046462      01006ff0       sleep
0x00046466      003c           nop
0x00046468      01006f71       sleep
0x0004646c      003c           nop
0x0004646e      0ac1           inc r1h
0x00046470      01006911       sleep
0x00046474      01006ff0       sleep
0x00046478      0014           nop
0x0004647a      7a             invalid
0x0004647b      0000           nop
0x0004647d      0000           nop
0x0004647f      180a           sub.b r0h,r2l
0x00046481      f05e           mov.b #0x5e:8,r0h
0x00046483      01648001       sleep
0x00046487      006b           nop
0x00046489      2100           mov.b @0x0:8,r1h
0x0004648b      400f           bra @@0xf:8
0x0004648d      8440           add.b #0x40:8,r4h
0x0004648f      341a           mov.b r4h,@0x1a:8
0x00046491      8068           add.b #0x68:8,r0h
0x00046493      58             invalid
0x00046494      1030           shal r0h
0x00046496      1030           shal r0h
0x00046498      01006ff0       sleep
0x0004649c      0044           nop
0x0004649e      01006f71       sleep
0x000464a2      0044           nop
0x000464a4      0ac1           inc r1h
0x000464a6      01006911       sleep
0x000464aa      01006ff0       sleep
0x000464ae      0014           nop
0x000464b0      7a             invalid
0x000464b1      0000           nop
0x000464b3      0000           nop
0x000464b5      180a           sub.b r0h,r2l
0x000464b7      f05e           mov.b #0x5e:8,r0h
0x000464b9      01648001       sleep
0x000464bd      006b           nop
0x000464bf      2100           mov.b @0x0:8,r1h
0x000464c1      400f           bra @@0xf:8
0x000464c3      8801           add.b #0x1:8,r0l
0x000464c5      006f           nop
0x000464c7      f000           mov.b #0x0:8,r0h
0x000464c9      087a           add.b r7h,r2l
0x000464cb      0000           nop
0x000464cd      0000           nop
0x000464cf      0c0a           mov.b r0h,r2l
0x000464d1      f05e           mov.b #0x5e:8,r0h
0x000464d3      015db401       sleep
0x000464d7      006f           nop
0x000464d9      7100           bnot #0x0:3,r0h
0x000464db      080f           add.b r0h,r7l
0x000464dd      820f           add.b #0xf:8,r2h
0x000464df      f05e           mov.b #0x5e:8,r0h
0x000464e1      0159a45e       sleep
0x000464e5      015d2e01       sleep
0x000464e9      006f           nop
0x000464eb      7100           bnot #0x0:3,r0h
0x000464ed      1401           or r0h,r1h
0x000464ef      0078           nop
0x000464f1      906b           addx #0x6b:8,r0h
0x000464f3      a000           cmp.b #0x0:8,r0h
0x000464f5      4052           bra @@0x52:8
0x000464f7      b6f8           subx #0xf8:8,r6h
0x000464f9      017a0100       sleep
0x000464fd      0000           nop
0x000464ff      240a           mov.b @0xa:8,r4h
0x00046501      f15c           mov.b #0x5c:8,r1h
0x00046503      0004           nop
0x00046505      60a8           bset r2l,r0l
0x00046507      01586002       sleep
0x0004650b      9801           addx #0x1:8,r0l
0x0004650d      006b           nop
0x0004650f      2000           mov.b @0x0:8,r0h
0x00046511      40             bra @@0x10:8
0x00046513      2e01           mov.b @0x1:8,r6l
0x00046515      006b           nop
0x00046517      a000           cmp.b #0x0:8,r0h
0x00046519      407b           bra @@0x7b:8
0x0004651b      6a6f7000       mov.b @0x7000:16,r7l
0x0004651f      245c           mov.b @0x5c:8,r4h
0x00046521      000c           nop
0x00046523      60a8           bset r2l,r0l
0x00046525      01587002       sleep
0x00046529      925a           addx #0x5a:8,r2h
0x0004652b      0466           orc #0x66:8,ccr
0x0004652d      986b           addx #0x6b:8,r0l
0x0004652f      2000           mov.b @0x0:8,r0h
0x00046531      4007           bra @@0x7:8
0x00046533      7673           band #0x7:3,r3h
0x00046535      7058           bset #0x5:3,r0l
0x00046537      6002           bset r0h,r2h
0x00046539      82f8           add.b #0xf8:8,r2h
0x0004653b      0368           ldc r0l,ccr
0x0004653d      d8f8           xor #0xf8:8,r0l
0x0004653f      01f901fa       sleep
0x00046543      0119886d       sleep
0x00046547      f21a           mov.b #0x1a:8,r2h
0x00046549      a26a           cmp.b #0x6a:8,r2h
0x0004654b      2a00           mov.b @0x0:8,r2l
0x0004654d      4076           bra @@0x76:8
0x0004654f      2810           mov.b @0x10:8,r0l
0x00046551      320a           mov.b r2h,@0xa:8
0x00046553      b20d           subx #0xd:8,r2h
0x00046555      890c           add.b #0xc:8,r1l
0x00046557      910c           addx #0xc:8,r1h
0x00046559      8969           add.b #0x69:8,r1l
0x0004655b      286f           mov.b @0x6f:8,r0l
0x0004655d      7000           bset #0x0:3,r0h
0x0004655f      265c           mov.b @0x5c:8,r6h
0x00046561      000c           nop
0x00046563      800b           add.b #0xb:8,r0h
0x00046565      8701           add.b #0x1:8,r7h
0x00046567      006b           nop
0x00046569      2000           mov.b @0x0:8,r0h
0x0004656b      4052           bra @@0x52:8
0x0004656d      c601           or #0x1:8,r6h
0x0004656f      006b           nop
0x00046571      a000           cmp.b #0x0:8,r0h
0x00046573      407b           bra @@0x7b:8
0x00046575      6a1a8068       mov.b @0x8068:16,r2l
0x00046579      58             invalid
0x0004657a      0f82           daa r2h
0x0004657c      1030           shal r0h
0x0004657e      1030           shal r0h
0x00046580      0ac0           inc r0h
0x00046582      01006ff0       sleep
0x00046586      001c           nop
0x00046588      0fa0           daa r0h
0x0004658a      7a             invalid
0x0004658b      01000000       sleep
0x0004658f      0c5e           mov.b r5h,r6l
0x00046591      0163ea1a       sleep
0x00046595      916a           addx #0x6a:8,r1h
0x00046597      2900           mov.b @0x0:8,r1l
0x00046599      4076           bra @@0x76:8
0x0004659b      2710           mov.b @0x10:8,r7h
0x0004659d      3110           mov.b r1h,@0x10:8
0x0004659f      317a           mov.b r1h,@0x7a:8
0x000465a1      1000           shll r0h
0x000465a3      407b           bra @@0x7b:8
0x000465a5      f20a           mov.b #0xa:8,r2h
0x000465a7      9001           addx #0x1:8,r0h
0x000465a9      0069           nop
0x000465ab      0001           nop
0x000465ad      006f           nop
0x000465af      7100           bnot #0x0:3,r0h
0x000465b1      1c01           cmp.b r0h,r1h
0x000465b3      0069           nop
0x000465b5      900f           addx #0xf:8,r0h
0x000465b7      c05e           or #0x5e:8,r0h
0x000465b9      039c           ldc r4l,ccr
0x000465bb      8a1a           add.b #0x1a:8,r2l
0x000465bd      8068           add.b #0x68:8,r0h
0x000465bf      58             invalid
0x000465c0      78             invalid
0x000465c1      006a           nop
0x000465c3      2900           mov.b @0x0:8,r1l
0x000465c5      404e           bra @@0x4e:8
0x000465c7      5046           mulxu r4h,r6
0x000465c9      361a           mov.b r6h,@0x1a:8
0x000465cb      8068           add.b #0x68:8,r0h
0x000465cd      58             invalid
0x000465ce      1030           shal r0h
0x000465d0      1030           shal r0h
0x000465d2      01006ff0       sleep
0x000465d6      002e           nop
0x000465d8      01006f71       sleep
0x000465dc      002e           nop
0x000465de      0ac1           inc r1h
0x000465e0      01006911       sleep
0x000465e4      01006ff0       sleep
0x000465e8      0014           nop
0x000465ea      7a             invalid
0x000465eb      0000           nop
0x000465ed      0000           nop
0x000465ef      180a           sub.b r0h,r2l
0x000465f1      f05e           mov.b #0x5e:8,r0h
0x000465f3      01648001       sleep
0x000465f7      006b           nop
0x000465f9      2100           mov.b @0x0:8,r1h
0x000465fb      400f           bra @@0xf:8
0x000465fd      8440           add.b #0x40:8,r4h
0x000465ff      341a           mov.b r4h,@0x1a:8
0x00046601      8068           add.b #0x68:8,r0h
0x00046603      58             invalid
0x00046604      1030           shal r0h
0x00046606      1030           shal r0h
0x00046608      01006ff0       sleep
0x0004660c      003c           nop
0x0004660e      01006f71       sleep
0x00046612      00             nop
0x00046614      0ac1           inc r1h
0x00046616      01006911       sleep
0x0004661a      01006ff0       sleep
0x0004661e      0014           nop
0x00046620      7a             invalid
0x00046621      0000           nop
0x00046623      0000           nop
0x00046625      180a           sub.b r0h,r2l
0x00046627      f05e           mov.b #0x5e:8,r0h
0x00046629      01648001       sleep
0x0004662d      006b           nop
0x0004662f      2100           mov.b @0x0:8,r1h
0x00046631      400f           bra @@0xf:8
0x00046633      8801           add.b #0x1:8,r0l
0x00046635      006f           nop
0x00046637      f000           mov.b #0x0:8,r0h
0x00046639      087a           add.b r7h,r2l
0x0004663b      0000           nop
0x0004663d      0000           nop
0x0004663f      0c0a           mov.b r0h,r2l
0x00046641      f05e           mov.b #0x5e:8,r0h
0x00046643      015db401       sleep
0x00046647      006f           nop
0x00046649      7100           bnot #0x0:3,r0h
0x0004664b      080f           add.b r0h,r7l
0x0004664d      820f           add.b #0xf:8,r2h
0x0004664f      f05e           mov.b #0x5e:8,r0h
0x00046651      0159a45e       sleep
0x00046655      015d2e01       sleep
0x00046659      006f           nop
0x0004665b      7100           bnot #0x0:3,r0h
0x0004665d      1401           or r0h,r1h
0x0004665f      0078           nop
0x00046661      906b           addx #0x6b:8,r0h
0x00046663      a000           cmp.b #0x0:8,r0h
0x00046665      4052           bra @@0x52:8
0x00046667      b6f8           subx #0xf8:8,r6h
0x00046669      017a0100       sleep
0x0004666d      0000           nop
0x0004666f      240a           mov.b @0xa:8,r4h
0x00046671      f15c           mov.b #0x5c:8,r1h
0x00046673      0002           nop
0x00046675      f0a8           mov.b #0xa8:8,r0h
0x00046677      01464601       sleep
0x0004667b      006b           nop
0x0004667d      2000           mov.b @0x0:8,r0h
0x0004667f      4076           bra @@0x76:8
0x00046681      2e01           mov.b @0x1:8,r6l
0x00046683      006b           nop
0x00046685      a000           cmp.b #0x0:8,r0h
0x00046687      407b           bra @@0x7b:8
0x00046689      6a6f7000       mov.b @0x7000:16,r7l
0x0004668d      245c           mov.b @0x5c:8,r4h
0x0004668f      000a           nop
0x00046691      f2a8           mov.b #0xa8:8,r2h
0x00046693      01587001       sleep
0x00046697      246b           mov.b @0x6b:8,r4h
0x00046699      2000           mov.b @0x0:8,r0h
0x0004669b      4074           bra @@0x74:8
0x0004669d      ca6b           or #0x6b:8,r2l
0x0004669f      2100           mov.b @0x0:8,r1h
0x000466a1      4074           bra @@0x74:8
0x000466a3      d009           xor #0x9:8,r0h
0x000466a5      106f           shal r7l
0x000466a7      b000           subx #0x0:8,r0h
0x000466a9      026b           stc ccr,r3l
0x000466ab      2000           mov.b @0x0:8,r0h
0x000466ad      4074           bra @@0x74:8
0x000466af      ca6b           or #0x6b:8,r2l
0x000466b1      2100           mov.b @0x0:8,r1h
0x000466b3      4074           bra @@0x74:8
0x000466b5      d209           xor #0x9:8,r2h
0x000466b7      106f           shal r7l
0x000466b9      b000           subx #0x0:8,r0h
0x000466bb      045a           orc #0x5a:8,ccr
0x000466bd      0467           orc #0x67:8,ccr
0x000466bf      a418           cmp.b #0x18:8,r4h
0x000466c1      886e           add.b #0x6e:8,r0l
0x000466c3      f800           mov.b #0x0:8,r0l
0x000466c5      416b           brn @@0x6b:8
0x000466c7      2000           mov.b @0x0:8,r0h
0x000466c9      4007           bra @@0x7:8
0x000466cb      7673           band #0x7:3,r3h
0x000466cd      7058           bset #0x5:3,r0l
0x000466cf      6000           bset r0h,r0h
0x000466d1      ea6b           and #0x6b:8,r2l
0x000466d3      2000           mov.b @0x0:8,r0h
0x000466d5      400c           bra @@0xc:8
0x000466d7      046f           orc #0x6f:8,ccr
0x000466d9      f000           mov.b #0x0:8,r0h
0x000466db      24f8           mov.b @0xf8:8,r4h
0x000466dd      016ef800       sleep
0x000466e1      49f9           bvs @@0xf9:8
0x000466e3      036e           ldc r6l,ccr
0x000466e5      f900           mov.b #0x0:8,r1l
0x000466e7      48fa           bvc @@0xfa:8
0x000466e9      026e           stc ccr,r6l
0x000466eb      fa00           mov.b #0x0:8,r2l
0x000466ed      4f19           ble @@0x19:8
0x000466ef      886d           add.b #0x6d:8,r0l
0x000466f1      f21a           mov.b #0x1a:8,r2h
0x000466f3      a26a           cmp.b #0x6a:8,r2h
0x000466f5      2a00           mov.b @0x0:8,r2l
0x000466f7      4076           bra @@0x76:8
0x000466f9      2810           mov.b @0x10:8,r0l
0x000466fb      320a           mov.b r2h,@0xa:8
0x000466fd      b20d           subx #0xd:8,r2h
0x000466ff      890c           add.b #0xc:8,r1l
0x00046701      910c           addx #0xc:8,r1h
0x00046703      8969           add.b #0x69:8,r1l
0x00046705      286f           mov.b @0x6f:8,r0l
0x00046707      7000           bset #0x0:3,r0h
0x00046709      265c           mov.b @0x5c:8,r6h
0x0004670b      000a           nop
0x0004670d      d60b           xor #0xb:8,r6h
0x0004670f      876b           add.b #0x6b:8,r7h
0x00046711      2000           mov.b @0x0:8,r0h
0x00046713      40             bra @@0x10:8
0x00046715      7673           band #0x7:3,r3h
0x00046717      7058           bset #0x5:3,r0l
0x00046719      6000           bset r0h,r0h
0x0004671b      a018           cmp.b #0x18:8,r0h
0x0004671d      886a           add.b #0x6a:8,r0l
0x0004671f      a800           cmp.b #0x0:8,r0l
0x00046721      4076           bra @@0x76:8
0x00046723      276e           mov.b @0x6e:8,r7h
0x00046725      78             invalid
0x00046726      004f           nop
0x00046728      6df0           push r0
0x0004672a      1a80           dec r0h
0x0004672c      6a280040       mov.b @0x40:16,r0l
0x00046730      7628           band #0x2:3,r0l
0x00046732      1030           shal r0h
0x00046734      0ab0           inc r0h
0x00046736      6e71004b       mov.b @(0x4b:16,r7),r1h
0x0004673a      6e79004a       mov.b @(0x4a:16,r7),r1l
0x0004673e      6900           mov.w @r0,r0
0x00046740      5c             invalid
0x00046741      0013           nop
0x00046743      b00b           subx #0xb:8,r0h
0x00046745      876b           add.b #0x6b:8,r7h
0x00046747      2000           mov.b @0x0:8,r0h
0x00046749      4007           bra @@0x7:8
0x0004674b      7673           band #0x7:3,r3h
0x0004674d      7046           bset #0x4:3,r6h
0x0004674f      6c7a           mov.b @r7+,r2l
0x00046751      01000000       sleep
0x00046755      240a           mov.b @0xa:8,r4h
0x00046757      f16e           mov.b #0x6e:8,r1h
0x00046759      78             invalid
0x0004675a      0041           nop
0x0004675c      5c             invalid
0x0004675d      0002           nop
0x0004675f      06a8           andc #0xa8:8,ccr
0x00046761      01464001       sleep
0x00046765      006b           nop
0x00046767      2000           mov.b @0x0:8,r0h
0x00046769      4076           bra @@0x76:8
0x0004676b      2e01           mov.b @0x1:8,r6l
0x0004676d      006b           nop
0x0004676f      a000           cmp.b #0x0:8,r0h
0x00046771      407b           bra @@0x7b:8
0x00046773      6a6f7000       mov.b @0x7000:16,r7l
0x00046777      245c           mov.b @0x5c:8,r4h
0x00046779      000a           nop
0x0004677b      08a8           add.b r2l,r0l
0x0004677d      01473c6b       sleep
0x00046781      2000           mov.b @0x0:8,r0h
0x00046783      4074           bra @@0x74:8
0x00046785      ca6b           or #0x6b:8,r2l
0x00046787      2100           mov.b @0x0:8,r1h
0x00046789      4074           bra @@0x74:8
0x0004678b      d009           xor #0x9:8,r0h
0x0004678d      106f           shal r7l
0x0004678f      b000           subx #0x0:8,r0h
0x00046791      026b           stc ccr,r3l
0x00046793      2000           mov.b @0x0:8,r0h
0x00046795      4074           bra @@0x74:8
0x00046797      ca6b           or #0x6b:8,r2l
0x00046799      2100           mov.b @0x0:8,r1h
0x0004679b      4074           bra @@0x74:8
0x0004679d      d209           xor #0x9:8,r2h
0x0004679f      106f           shal r7l
0x000467a1      b000           subx #0x0:8,r0h
0x000467a3      047a           orc #0x7a:8,ccr
0x000467a5      0000           nop
0x000467a7      4076           bra @@0x76:8
0x000467a9      2868           mov.b @0x68:8,r0l
0x000467ab      090a           add.w r0,r2
0x000467ad      0968           add.w r6,r0
0x000467af      896a           add.b #0x6a:8,r1l
0x000467b1      2800           mov.b @0x0:8,r0l
0x000467b3      4076           bra @@0x76:8
0x000467b5      28a8           mov.b @0xa8:8,r0l
0x000467b7      0358           ldc r0l,ccr
0x000467b9      50fa           mulxu r7l,r2
0x000467bb      8a6b           add.b #0x6b:8,r2l
0x000467bd      2000           mov.b @0x0:8,r0h
0x000467bf      4007           bra @@0x7:8
0x000467c1      78             invalid
0x000467c2      4604           bne @@0x4:8
0x000467c4      f801           mov.b #0x1:8,r0l
0x000467c6      4002           bra @@0x2:8
0x000467c8      1888           sub.b r0l,r0l
0x000467ca      6aa80040       mov.b r0l,@0x40:16
0x000467ce      0e97           addx r1l,r7h
0x000467d0      6868           mov.b @r6,r0l
0x000467d2      a806           cmp.b #0x6:8,r0l
0x000467d4      470a           beq @@0xa:8
0x000467d6      f801           mov.b #0x1:8,r0l
0x000467d8      6aa80040       mov.b r0l,@0x40:16
0x000467dc      0e98           addx r1l,r0l
0x000467de      4008           bra @@0x8:8
0x000467e0      1888           sub.b r0l,r0l
0x000467e2      6aa80040       mov.b r0l,@0x40:16
0x000467e6      0e96           addx r1l,r6h
0x000467e8      f801           mov.b #0x1:8,r0l
0x000467ea      6aa80040       mov.b r0l,@0x40:16
0x000467ee      0e99           addx r1l,r1l
0x000467f0      6b200040       mov.w @0x40:16,r0
0x000467f4      0776           ldc #0x76:8,ccr
0x000467f6      7370           btst #0x7:3,r0h
0x000467f8      4708           beq @@0x8:8
0x000467fa      1900           sub.w r0,r0
0x000467fc      6ba00040       mov.w r0,@0x40:16
0x00046800      0778           ldc #0x78:8,ccr
0x00046802      6868           mov.b @r6,r0l
0x00046804      a802           cmp.b #0x2:8,r0l
0x00046806      4712           beq @@0x12:8
0x00046808      6868           mov.b @r6,r0l
0x0004680a      a801           cmp.b #0x1:8,r0l
0x0004680c      470c           beq @@0xc:8
0x0004680e      6868           mov.b @r6,r0l
0x00046810      a804           cmp.b #0x4:8,r0l
0x00046812      4706           beq @@0x6:8
0x00046814      68             mov.b @r1,r0h
0x00046816      a805           cmp.b #0x5:8,r0l
0x00046818      460c           bne @@0xc:8
0x0004681a      6a280040       mov.b @0x40:16,r0l
0x0004681e      53             invalid
0x0004681f      0377           ldc r7h,ccr
0x00046821      087f           add.b r7h,r7l
0x00046823      d267           xor #0x67:8,r2h
0x00046825      106b           shal r3l
0x00046827      2000           mov.b @0x0:8,r0h
0x00046829      4007           bra @@0x7:8
0x0004682b      78             invalid
0x0004682c      474e           beq @@0x4e:8
0x0004682e      01006b20       sleep
0x00046832      0040           nop
0x00046834      077e           ldc #0x7e:8,ccr
0x00046836      7a             invalid
0x00046837      0100000f       sleep
0x0004683b      a05e           cmp.b #0x5e:8,r0h
0x0004683d      0163ea6b       sleep
0x00046841      2100           mov.b @0x0:8,r1h
0x00046843      400d           bra @@0xd:8
0x00046845      3a17           mov.b r2l,@0x17:8
0x00046847      7101           bnot #0x0:3,r1h
0x00046849      006f           nop
0x0004684b      f100           mov.b #0x0:8,r1h
0x0004684d      3c5e           mov.b r4l,@0x5e:8
0x0004684f      015ccc6b       sleep
0x00046853      a000           cmp.b #0x0:8,r0h
0x00046855      4052           bra @@0x52:8
0x00046857      a201           cmp.b #0x1:8,r2h
0x00046859      006b           nop
0x0004685b      2000           mov.b @0x0:8,r0h
0x0004685d      4007           bra @@0x7:8
0x0004685f      827a           add.b #0x7a:8,r2h
0x00046861      0100000f       sleep
0x00046865      a05e           cmp.b #0x5e:8,r0h
0x00046867      0163ea01       sleep
0x0004686b      006f           nop
0x0004686d      7100           bnot #0x0:3,r0h
0x0004686f      3c5e           mov.b r4l,@0x5e:8
0x00046871      015ccc01       sleep
0x00046875      006b           nop
0x00046877      a000           cmp.b #0x0:8,r0h
0x00046879      4052           bra @@0x52:8
0x0004687b      9e6b           addx #0x6b:8,r6l
0x0004687d      2000           mov.b @0x0:8,r0h
0x0004687f      4007           bra @@0x7:8
0x00046881      7673           band #0x7:3,r3h
0x00046883      7046           bset #0x4:3,r6h
0x00046885      086b           add.b r6h,r3l
0x00046887      2000           mov.b @0x0:8,r0h
0x00046889      4007           bra @@0x7:8
0x0004688b      78             invalid
0x0004688c      470e           beq @@0xe:8
0x0004688e      6b200040       mov.w @0x40:16,r0
0x00046892      52             invalid
0x00046893      9c5e           addx #0x5e:8,r4l
0x00046895      02e2           stc ccr,r2h
0x00046897      f45a           mov.b #0x5a:8,r4h
0x00046899      0469           orc #0x69:8,ccr
0x0004689b      3668           mov.b r6h,@0x68:8
0x0004689d      58             invalid
0x0004689e      4616           bne @@0x16:8
0x000468a0      6b200040       mov.w @0x40:16,r0
0x000468a4      52             invalid
0x000468a5      9c6b           addx #0x6b:8,r4l
0x000468a7      2100           mov.b @0x0:8,r1h
0x000468a9      400c           bra @@0xc:8
0x000468ab      1209           rotxl r1l
0x000468ad      106b           shal r3l
0x000468af      a000           cmp.b #0x0:8,r0h
0x000468b1      4074           bra @@0x74:8
0x000468b3      c840           or #0x40:8,r0l
0x000468b5      52             invalid
0x000468b6      6858           mov.b @r5,r0l
0x000468b8      a801           cmp.b #0x1:8,r0l
0x000468ba      4616           bne @@0x16:8
0x000468bc      6b200040       mov.w @0x40:16,r0
0x000468c0      52             invalid
0x000468c1      9c6b           addx #0x6b:8,r4l
0x000468c3      2100           mov.b @0x0:8,r1h
0x000468c5      400c           bra @@0xc:8
0x000468c7      1409           or r0h,r1l
0x000468c9      106b           shal r3l
0x000468cb      a000           cmp.b #0x0:8,r0h
0x000468cd      4074           bra @@0x74:8
0x000468cf      c840           or #0x40:8,r0l
0x000468d1      3668           mov.b r6h,@0x68:8
0x000468d3      58             invalid
0x000468d4      a802           cmp.b #0x2:8,r0l
0x000468d6      4616           bne @@0x16:8
0x000468d8      6b200040       mov.w @0x40:16,r0
0x000468dc      52             invalid
0x000468dd      9c6b           addx #0x6b:8,r4l
0x000468df      2100           mov.b @0x0:8,r1h
0x000468e1      400c           bra @@0xc:8
0x000468e3      1609           and r0h,r1l
0x000468e5      106b           shal r3l
0x000468e7      a000           cmp.b #0x0:8,r0h
0x000468e9      4074           bra @@0x74:8
0x000468eb      c840           or #0x40:8,r0l
0x000468ed      1a68           dec r0l
0x000468ef      58             invalid
0x000468f0      a803           cmp.b #0x3:8,r0l
0x000468f2      4614           bne @@0x14:8
0x000468f4      6b200040       mov.w @0x40:16,r0
0x000468f8      52             invalid
0x000468f9      9c6b           addx #0x6b:8,r4l
0x000468fb      2100           mov.b @0x0:8,r1h
0x000468fd      400c           bra @@0xc:8
0x000468ff      1809           sub.b r0h,r1l
0x00046901      106b           shal r3l
0x00046903      a000           cmp.b #0x0:8,r0h
0x00046905      4074           bra @@0x74:8
0x00046907      c86b           or #0x6b:8,r0l
0x00046909      2000           mov.b @0x0:8,r0h
0x0004690b      4074           bra @@0x74:8
0x0004690d      c879           or #0x79:8,r0l
0x0004690f      2080           mov.b @0x80:8,r0h
0x00046911      0045           nop
0x00046913      0c6b           mov.b r6h,r3l
0x00046915      20             mov.b @0x10:8,r0h
0x00046917      4052           bra @@0x52:8
0x00046919      9c6b           addx #0x6b:8,r4l
0x0004691b      a000           cmp.b #0x0:8,r0h
0x0004691d      4074           bra @@0x74:8
0x0004691f      c86b           or #0x6b:8,r0l
0x00046921      2000           mov.b @0x0:8,r0h
0x00046923      4074           bra @@0x74:8
0x00046925      c85e           or #0x5e:8,r0l
0x00046927      02e2           stc ccr,r2h
0x00046929      f46b           mov.b #0x6b:8,r4h
0x0004692b      2000           mov.b @0x0:8,r0h
0x0004692d      4074           bra @@0x74:8
0x0004692f      c86b           or #0x6b:8,r0l
0x00046931      a000           cmp.b #0x0:8,r0h
0x00046933      4052           bra @@0x52:8
0x00046935      9c18           addx #0x18:8,r4l
0x00046937      8840           add.b #0x40:8,r0l
0x00046939      1a1a           dec r2l
0x0004693b      800c           add.b #0xc:8,r0h
0x0004693d      a87a           cmp.b #0x7a:8,r0l
0x0004693f      01000000       sleep
0x00046943      200a           mov.b @0xa:8,r0h
0x00046945      f10a           mov.b #0xa:8,r1h
0x00046947      810c           add.b #0xc:8,r1h
0x00046949      a068           cmp.b #0x68:8,r0h
0x0004694b      185e           sub.b r5h,r6l
0x0004694d      039c           ldc r4l,ccr
0x0004694f      6c0c           mov.b @r0+,r4l
0x00046951      a80a           cmp.b #0xa:8,r0l
0x00046953      080c           add.b r0h,r4l
0x00046955      8aa8           add.b #0xa8:8,r2l
0x00046957      0445           orc #0x45:8,ccr
0x00046959      e07a           and #0x7a:8,r0h
0x0004695b      1700           not r0h
0x0004695d      0000           nop
0x0004695f      545e           rts
0x00046961      01643654       sleep
0x00046965      705e           bset #0x5:3,r6l
0x00046967      0164587a       sleep
0x0004696b      3700           mov.b r7h,@0x0:8
0x0004696d      0000           nop
0x0004696f      1a7a           dec r2l
0x00046971      0300           ldc r0h,ccr
0x00046973      4052           bra @@0x52:8
0x00046975      9e7a           addx #0x7a:8,r6l
0x00046977      0400           orc #0x0:8,ccr
0x00046979      4076           bra @@0x76:8
0x0004697b      367a           mov.b r6h,@0x7a:8
0x0004697d      0600           andc #0x0:8,ccr
0x0004697f      400b           bra @@0xb:8
0x00046981      246e           mov.b @0x6e:8,r4h
0x00046983      f800           mov.b #0x0:8,r0l
0x00046985      0901           add.w r0,r1
0x00046987      006f           nop
0x00046989      f100           mov.b #0x0:8,r1h
0x0004698b      0a6f           inc r7l
0x0004698d      6d00           mov.w @r0+,r0
0x0004698f      de6a           xor #0x6a:8,r6l
0x00046991      2a00           mov.b @0x0:8,r2l
0x00046993      4076           bra @@0x76:8
0x00046995      266a           mov.b @0x6a:8,r6h
0x00046997      aa00           cmp.b #0x0:8,r2l
0x00046999      404e           bra @@0x4e:8
0x0004699b      976a           addx #0x6a:8,r7h
0x0004699d      2a00           mov.b @0x0:8,r2l
0x0004699f      4076           bra @@0x76:8
0x000469a1      266a           mov.b @0x6a:8,r6h
0x000469a3      aa00           cmp.b #0x0:8,r2l
0x000469a5      400f           bra @@0xf:8
0x000469a7      561a           rte
0x000469a9      a201           cmp.b #0x1:8,r2h
0x000469ab      006b           nop
0x000469ad      a200           cmp.b #0x0:8,r2h
0x000469af      4076           bra @@0x76:8
0x000469b1      2e7a           mov.b @0x7a:8,r6l
0x000469b3      02ff           stc ccr,r7l
0x000469b5      ffff           mov.b #0xff:8,r7l
0x000469b7      ff01           mov.b #0x1:8,r7l
0x000469b9      006b           nop
0x000469bb      a200           cmp.b #0x0:8,r2h
0x000469bd      4076           bra @@0x76:8
0x000469bf      3219           mov.b r2h,@0x19:8
0x000469c1      5519           bsr .25
0x000469c3      226b           mov.b @0x6b:8,r2h
0x000469c5      a200           cmp.b #0x0:8,r2h
0x000469c7      407c           bra @@0x7c:8
0x000469c9      a679           cmp.b #0x79:8,r6h
0x000469cb      02ff           stc ccr,r7l
0x000469cd      ff6b           mov.b #0x6b:8,r7l
0x000469cf      a200           cmp.b #0x0:8,r2h
0x000469d1      407c           bra @@0x7c:8
0x000469d3      a86b           cmp.b #0x6b:8,r0l
0x000469d5      2200           mov.b @0x0:8,r2h
0x000469d7      4007           bra @@0x7:8
0x000469d9      7673           band #0x7:3,r3h
0x000469db      7258           bclr #0x5:3,r0l
0x000469dd      6007           bset r0h,r7h
0x000469df      96f9           addx #0xf9:8,r6h
0x000469e1      0119880d       sleep
0x000469e5      d05e           xor #0x5e:8,r0h
0x000469e7      02e3           stc ccr,r3h
0x000469e9      265e           mov.b @0x5e:8,r6h
0x000469eb      02e2           stc ccr,r2h
0x000469ed      aaa8           cmp.b #0xa8:8,r2l
0x000469ef      01471c6b       sleep
0x000469f3      2000           mov.b @0x0:8,r0h
0x000469f5      4007           bra @@0x7:8
0x000469f7      78             invalid
0x000469f8      79200120       mov.w #0x120:16,r0
0x000469fc      470c           beq @@0xc:8
0x000469fe      6b200040       mov.w @0x40:16,r0
0x00046a02      0778           ldc #0x78:8,ccr
0x00046a04      79200121       mov.w #0x121:16,r0
0x00046a08      46d6           bne @@0xd6:8
0x00046a0a      5a047176       jmp @0x7176:16
0x00046a0e      1a80           dec r0h
0x00046a10      6a280040       mov.b @0x40:16,r0l
0x00046a14      7626           band #0x2:3,r6h
0x00046a16      10             shal r0h
0x00046a18      1030           shal r0h
0x00046a1a      7a             invalid
0x00046a1b      1000           shll r0h
0x00046a1d      4052           bra @@0x52:8
0x00046a1f      b601           subx #0x1:8,r6h
0x00046a21      006f           nop
0x00046a23      f000           mov.b #0x0:8,r0h
0x00046a25      1601           and r0h,r1h
0x00046a27      006f           nop
0x00046a29      7100           bnot #0x0:3,r0h
0x00046a2b      1601           and r0h,r1h
0x00046a2d      0069           nop
0x00046a2f      117a           shar r2l
0x00046a31      6101           bnot r0h,r1h
0x00046a33      ffff           mov.b #0xff:8,r7l
0x00046a35      ff01           mov.b #0x1:8,r7l
0x00046a37      0069           nop
0x00046a39      815a           add.b #0x5a:8,r1h
0x00046a3b      046b           orc #0x6b:8,ccr
0x00046a3d      166b           and r6h,r3l
0x00046a3f      2000           mov.b @0x0:8,r0h
0x00046a41      4007           bra @@0x7:8
0x00046a43      7673           band #0x7:3,r3h
0x00046a45      7047           bset #0x4:3,r7h
0x00046a47      085e           add.b r5h,r6l
0x00046a49      02e2           stc ccr,r2h
0x00046a4b      52             invalid
0x00046a4c      5a047176       jmp @0x7176:16
0x00046a50      7a             invalid
0x00046a51      01004052       sleep
0x00046a55      b60d           subx #0xd:8,r6h
0x00046a57      d05e           xor #0x5e:8,r0h
0x00046a59      0361           ldc r1h,ccr
0x00046a5b      026a           stc ccr,r2l
0x00046a5d      2000           mov.b @0x0:8,r0h
0x00046a5f      4076           bra @@0x76:8
0x00046a61      2718           mov.b @0x18:8,r7h
0x00046a63      885c           add.b #0x5c:8,r0l
0x00046a65      00f5           nop
0x00046a67      e20d           and #0xd:8,r2h
0x00046a69      d017           xor #0x17:8,r0h
0x00046a6b      7010           bset #0x1:3,r0h
0x00046a6d      3010           mov.b r0h,@0x10:8
0x00046a6f      300a           mov.b r0h,@0xa:8
0x00046a71      c001           or #0x1:8,r0h
0x00046a73      006b           nop
0x00046a75      2100           mov.b @0x0:8,r1h
0x00046a77      4052           bra @@0x52:8
0x00046a79      c601           or #0x1:8,r6h
0x00046a7b      0069           nop
0x00046a7d      8101           add.b #0x1:8,r1h
0x00046a7f      006b           nop
0x00046a81      2000           mov.b @0x0:8,r0h
0x00046a83      4052           bra @@0x52:8
0x00046a85      c601           or #0x1:8,r6h
0x00046a87      006b           nop
0x00046a89      2100           mov.b @0x0:8,r1h
0x00046a8b      4076           bra @@0x76:8
0x00046a8d      2e1f           mov.b @0x1f:8,r6l
0x00046a8f      9043           addx #0x43:8,r0h
0x00046a91      1e01           subx r0h,r1h
0x00046a93      006b           nop
0x00046a95      2000           mov.b @0x0:8,r0h
0x00046a97      4052           bra @@0x52:8
0x00046a99      c601           or #0x1:8,r6h
0x00046a9b      006b           nop
0x00046a9d      a000           cmp.b #0x0:8,r0h
0x00046a9f      4076           bra @@0x76:8
0x00046aa1      2e6b           mov.b @0x6b:8,r6l
0x00046aa3      2000           mov.b @0x0:8,r0h
0x00046aa5      404e           bra @@0x4e:8
0x00046aa7      58             invalid
0x00046aa8      6ba00040       mov.w r0,@0x40:16
0x00046aac      7624           band #0x2:3,r4h
0x00046aae      0dd5           mov.w r13,r5
0x00046ab0      01006b20       sleep
0x00046ab4      0040           nop
0x00046ab6      52             invalid
0x00046ab7      c601           or #0x1:8,r6h
0x00046ab9      006b           nop
0x00046abb      2100           mov.b @0x0:8,r1h
0x00046abd      4076           bra @@0x76:8
0x00046abf      321f           mov.b r2h,@0x1f:8
0x00046ac1      9044           addx #0x44:8,r0h
0x00046ac3      1001           shll r1h
0x00046ac5      006b           nop
0x00046ac7      2000           mov.b @0x0:8,r0h
0x00046ac9      4052           bra @@0x52:8
0x00046acb      c601           or #0x1:8,r6h
0x00046acd      006b           nop
0x00046acf      a000           cmp.b #0x0:8,r0h
0x00046ad1      4076           bra @@0x76:8
0x00046ad3      326b           mov.b r2h,@0x6b:8
0x00046ad5      2000           mov.b @0x0:8,r0h
0x00046ad7      404e           bra @@0x4e:8
0x00046ad9      58             invalid
0x00046ada      6b210040       mov.w @0x40:16,r1
0x00046ade      7ca61d10       biand #0x1:3,@r10
0x00046ae2      430c           bls @@0xc:8
0x00046ae4      6b200040       mov.w @0x40:16,r0
0x00046ae8      4e58           bgt @@0x58:8
0x00046aea      6ba00040       mov.w r0,@0x40:16
0x00046aee      7ca66b20       biand #0x2:3,@r10
0x00046af2      0040           nop
0x00046af4      4e58           bgt @@0x58:8
0x00046af6      6b210040       mov.w @0x40:16,r1
0x00046afa      7ca81d10       biand #0x1:3,@r10
0x00046afe      440c           bcc @@0xc:8
0x00046b00      6b200040       mov.w @0x40:16,r0
0x00046b04      4e58           bgt @@0x58:8
0x00046b06      6ba00040       mov.w r0,@0x40:16
0x00046b0a      7ca86f60       biand #0x6:3,@r10
0x00046b0e      01f4090d       sleep
0x00046b12      5e02e2aa       jsr @0xe2aa:16
0x00046b16      6f60           mov.w @(0x1001:16,r6),r0
0x00046b1a      1d0d           cmp.w r0,r5
0x00046b1c      58             invalid
0x00046b1d      30ff           mov.b r0h,@0xff:8
0x00046b1f      1e5e           subx r5h,r6l
0x00046b21      02e2           stc ccr,r2h
0x00046b23      52             invalid
0x00046b24      6f6d01f4       mov.w @(0x1f4:16,r6),r5
0x00046b28      101d           shal r5l
0x00046b2a      6f6000de       mov.w @(0xde:16,r6),r0
0x00046b2e      09d0           add.w r13,r0
0x00046b30      1d05           cmp.w r0,r5
0x00046b32      58             invalid
0x00046b33      5004           mulxu r0h,r4
0x00046b35      4c6f           bge @@0x6f:8
0x00046b37      6000           bset r0h,r0h
0x00046b39      e219           and #0x19:8,r2h
0x00046b3b      d01d           xor #0x1d:8,r0h
0x00046b3d      0558           xorc #0x58:8,ccr
0x00046b3f      2004           mov.b @0x4:8,r0h
0x00046b41      406f           bra @@0x6f:8
0x00046b43      6001           bset r0h,r1h
0x00046b45      f409           mov.b #0x9:8,r4h
0x00046b47      5017           mulxu r1h,r7
0x00046b49      7010           bset #0x1:3,r0h
0x00046b4b      3010           mov.b r0h,@0x10:8
0x00046b4d      300a           mov.b r0h,@0xa:8
0x00046b4f      c00d           or #0xd:8,r0h
0x00046b51      516f           divxu r6h,r7
0x00046b53      6201           bclr r0h,r1h
0x00046b55      f419           mov.b #0x19:8,r4h
0x00046b57      2117           mov.b @0x17:8,r1h
0x00046b59      7110           bnot #0x1:3,r0h
0x00046b5b      3110           mov.b r1h,@0x10:8
0x00046b5d      310a           mov.b r1h,@0xa:8
0x00046b5f      c101           or #0x1:8,r1h
0x00046b61      0069           nop
0x00046b63      0001           nop
0x00046b65      0069           nop
0x00046b67      111f           shar r7l
0x00046b69      9058           addx #0x58:8,r0h
0x00046b6b      7004           bset #0x0:3,r4h
0x00046b6d      146f           or r6h,r7l
0x00046b6f      6001           bset r0h,r1h
0x00046b71      f409           mov.b #0x9:8,r4h
0x00046b73      5017           mulxu r1h,r7
0x00046b75      7010           bset #0x1:3,r0h
0x00046b77      3010           mov.b r0h,@0x10:8
0x00046b79      300a           mov.b r0h,@0xa:8
0x00046b7b      c00d           or #0xd:8,r0h
0x00046b7d      516f           divxu r6h,r7
0x00046b7f      6201           bclr r0h,r1h
0x00046b81      f419           mov.b #0x19:8,r4h
0x00046b83      2117           mov.b @0x17:8,r1h
0x00046b85      7110           bnot #0x1:3,r0h
0x00046b87      3110           mov.b r1h,@0x10:8
0x00046b89      310a           mov.b r1h,@0xa:8
0x00046b8b      c101           or #0x1:8,r1h
0x00046b8d      0069           nop
0x00046b8f      0001           nop
0x00046b91      0069           nop
0x00046b93      111f           shar r7l
0x00046b95      9058           addx #0x58:8,r0h
0x00046b97      4001           bra @@0x1:8
0x00046b99      fa0d           mov.b #0xd:8,r2l
0x00046b9b      516f           divxu r6h,r7
0x00046b9d      6201           bclr r0h,r1h
0x00046b9f      f419           mov.b #0x19:8,r4h
0x00046ba1      2117           mov.b @0x17:8,r1h
0x00046ba3      7110           bnot #0x1:3,r0h
0x00046ba5      3110           mov.b r1h,@0x10:8
0x00046ba7      310a           mov.b r1h,@0xa:8
0x00046ba9      c101           or #0x1:8,r1h
0x00046bab      0069           nop
0x00046bad      105e           shal r6l
0x00046baf      0164be6f       sleep
0x00046bb3      6101           bnot r0h,r1h
0x00046bb5      f409           mov.b #0x9:8,r4h
0x00046bb7      5117           divxu r1h,r7
0x00046bb9      7110           bnot #0x1:3,r0h
0x00046bbb      3110           mov.b r1h,@0x10:8
0x00046bbd      310a           mov.b r1h,@0xa:8
0x00046bbf      c101           or #0x1:8,r1h
0x00046bc1      006f           nop
0x00046bc3      f000           mov.b #0x0:8,r0h
0x00046bc5      0401           orc #0x1:8,ccr
0x00046bc7      0069           nop
0x00046bc9      105e           shal r6l
0x00046bcb      0164be0f       sleep
0x00046bcf      8101           add.b #0x1:8,r1h
0x00046bd1      006f           nop
0x00046bd3      7000           bset #0x0:3,r0h
0x00046bd5      045e           orc #0x5e:8,ccr
0x00046bd7      015b9a01       sleep
0x00046bdb      006f           nop
0x00046bdd      f000           mov.b #0x0:8,r0h
0x00046bdf      0e7a           addx r7h,r2l
0x00046be1      013f8000       sleep
0x00046be5      005e           nop
0x00046be7      015f240d       sleep
0x00046beb      0047           nop
0x00046bed      0e7a           addx r7h,r2l
0x00046bef      003f           nop
0x00046bf1      8000           add.b #0x0:8,r0h
0x00046bf3      0001           nop
0x00046bf5      006f           nop
0x00046bf7      7100           bnot #0x0:3,r0h
0x00046bf9      0e40           addx r4h,r0h
0x00046bfb      0c01           mov.b r0h,r1h
0x00046bfd      006f           nop
0x00046bff      7000           bset #0x0:3,r0h
0x00046c01      0e7a           addx r7h,r2l
0x00046c03      013f8000       sleep
0x00046c07      005e           nop
0x00046c09      01572801       sleep
0x00046c0d      006f           nop
0x00046c0f      f000           mov.b #0x0:8,r0h
0x00046c11      0e0d           addx r0h,r5l
0x00046c13      516f           divxu r6h,r7
0x00046c15      6201           bclr r0h,r1h
0x00046c17      f419           mov.b #0x19:8,r4h
0x00046c19      21             mov.b @0x10:8,r1h
0x00046c1b      7110           bnot #0x1:3,r0h
0x00046c1d      3110           mov.b r1h,@0x10:8
0x00046c1f      310a           mov.b r1h,@0xa:8
0x00046c21      c101           or #0x1:8,r1h
0x00046c23      0069           nop
0x00046c25      105e           shal r6l
0x00046c27      0164be6f       sleep
0x00046c2b      6101           bnot r0h,r1h
0x00046c2d      f410           mov.b #0x10:8,r4h
0x00046c2f      110d           shlr r5l
0x00046c31      52             invalid
0x00046c32      1912           sub.w r1,r2
0x00046c34      1772           neg r2h
0x00046c36      1032           shal r2h
0x00046c38      1032           shal r2h
0x00046c3a      0ac2           inc r2h
0x00046c3c      01006ff0       sleep
0x00046c40      0004           nop
0x00046c42      01006920       sleep
0x00046c46      5e0164be       jsr @0x64be:16
0x00046c4a      01006f71       sleep
0x00046c4e      0004           nop
0x00046c50      5e015732       jsr @0x5732:16
0x00046c54      7a             invalid
0x00046c55      01400000       sleep
0x00046c59      005e           nop
0x00046c5b      015b9a6f       sleep
0x00046c5f      6101           bnot r0h,r1h
0x00046c61      f409           mov.b #0x9:8,r4h
0x00046c63      5117           divxu r1h,r7
0x00046c65      7110           bnot #0x1:3,r0h
0x00046c67      3110           mov.b r1h,@0x10:8
0x00046c69      310a           mov.b r1h,@0xa:8
0x00046c6b      c101           or #0x1:8,r1h
0x00046c6d      0069           nop
0x00046c6f      f001           mov.b #0x1:8,r0h
0x00046c71      0069           nop
0x00046c73      105e           shal r6l
0x00046c75      0164be0f       sleep
0x00046c79      8101           add.b #0x1:8,r1h
0x00046c7b      0069           nop
0x00046c7d      705e           bset #0x5:3,r6l
0x00046c7f      015b9a01       sleep
0x00046c83      006f           nop
0x00046c85      f000           mov.b #0x0:8,r0h
0x00046c87      127a           rotl r2l
0x00046c89      013f8000       sleep
0x00046c8d      005e           nop
0x00046c8f      015f240d       sleep
0x00046c93      0047           nop
0x00046c95      0e7a           addx r7h,r2l
0x00046c97      003f           nop
0x00046c99      8000           add.b #0x0:8,r0h
0x00046c9b      0001           nop
0x00046c9d      006f           nop
0x00046c9f      7100           bnot #0x0:3,r0h
0x00046ca1      1240           rotl r0h
0x00046ca3      0c01           mov.b r0h,r1h
0x00046ca5      006f           nop
0x00046ca7      7000           bset #0x0:3,r0h
0x00046ca9      127a           rotl r2l
0x00046cab      013f8000       sleep
0x00046caf      005e           nop
0x00046cb1      01572801       sleep
0x00046cb5      006f           nop
0x00046cb7      f000           mov.b #0x0:8,r0h
0x00046cb9      126f           rotl r7l
0x00046cbb      6101           bnot r0h,r1h
0x00046cbd      f410           mov.b #0x10:8,r4h
0x00046cbf      110d           shlr r5l
0x00046cc1      52             invalid
0x00046cc2      1912           sub.w r1,r2
0x00046cc4      1772           neg r2h
0x00046cc6      1032           shal r2h
0x00046cc8      1032           shal r2h
0x00046cca      0ac2           inc r2h
0x00046ccc      01006920       sleep
0x00046cd0      5e0164be       jsr @0x64be:16
0x00046cd4      6f6101f4       mov.w @(0x1f4:16,r6),r1
0x00046cd8      0951           add.w r5,r1
0x00046cda      1771           neg r1h
0x00046cdc      1031           shal r1h
0x00046cde      1031           shal r1h
0x00046ce0      0ac1           inc r1h
0x00046ce2      01006ff0       sleep
0x00046ce6      0004           nop
0x00046ce8      01006910       sleep
0x00046cec      5e0164be       jsr @0x64be:16
0x00046cf0      0f81           daa r1h
0x00046cf2      01006f70       sleep
0x00046cf6      0004           nop
0x00046cf8      5e015b9a       jsr @0x5b9a:16
0x00046cfc      01006ff0       sleep
0x00046d00      0016           nop
0x00046d02      7a             invalid
0x00046d03      013f8000       sleep
0x00046d07      005e           nop
0x00046d09      015f240d       sleep
0x00046d0d      0047           nop
0x00046d0f      0e7a           addx r7h,r2l
0x00046d11      003f           nop
0x00046d13      8000           add.b #0x0:8,r0h
0x00046d15      0001           nop
0x00046d17      006f           nop
0x00046d19      7100           bnot #0x0:3,r0h
0x00046d1b      1640           and r4h,r0h
0x00046d1d      0c01           mov.b r0h,r1h
0x00046d1f      006f           nop
0x00046d21      7000           bset #0x0:3,r0h
0x00046d23      167a           and r7h,r2l
0x00046d25      013f8000       sleep
0x00046d29      005e           nop
0x00046d2b      01572801       sleep
0x00046d2f      006f           nop
0x00046d31      f000           mov.b #0x0:8,r0h
0x00046d33      1601           and r0h,r1h
0x00046d35      006f           nop
0x00046d37      7000           bset #0x0:3,r0h
0x00046d39      1201           rotxl r1h
0x00046d3b      006f           nop
0x00046d3d      7100           bnot #0x0:3,r0h
0x00046d3f      0e5e           addx r5h,r6l
0x00046d41      015f240d       sleep
0x00046d45      0047           nop
0x00046d47      1a01           dec r1h
0x00046d49      006f           nop
0x00046d4b      7000           bset #0x0:3,r0h
0x00046d4d      1201           rotxl r1h
0x00046d4f      006f           nop
0x00046d51      7100           bnot #0x0:3,r0h
0x00046d53      165e           and r5h,r6l
0x00046d55      015f240d       sleep
0x00046d59      0047           nop
0x00046d5b      061b           andc #0x1b:8,ccr
0x00046d5d      555a           bsr .90
0x00046d5f      046f           orc #0x6f:8,ccr
0x00046d61      8201           add.b #0x1:8,r2h
0x00046d63      006f           nop
0x00046d65      7000           bset #0x0:3,r0h
0x00046d67      1601           and r0h,r1h
0x00046d69      006f           nop
0x00046d6b      7100           bnot #0x0:3,r0h
0x00046d6d      0e5e           addx r5h,r6l
0x00046d6f      015f240d       sleep
0x00046d73      0058           nop
0x00046d75      7002           bset #0x0:3,r2h
0x00046d77      0a01           inc r1h
0x00046d79      006f           nop
0x00046d7b      7000           bset #0x0:3,r0h
0x00046d7d      1601           and r0h,r1h
0x00046d7f      006f           nop
0x00046d81      7100           bnot #0x0:3,r0h
0x00046d83      125e           rotl r6l
0x00046d85      015f240d       sleep
0x00046d89      0058           nop
0x00046d8b      7001           bset #0x0:3,r1h
0x00046d8d      f41b           mov.b #0x1b:8,r4h
0x00046d8f      d55a           xor #0x5a:8,r5h
0x00046d91      046f           orc #0x6f:8,ccr
0x00046d93      826f           add.b #0x6f:8,r2h
0x00046d95      6101           bnot r0h,r1h
0x00046d97      f409           mov.b #0x9:8,r4h
0x00046d99      5117           divxu r1h,r7
0x00046d9b      7110           bnot #0x1:3,r0h
0x00046d9d      3110           mov.b r1h,@0x10:8
0x00046d9f      310a           mov.b r1h,@0xa:8
0x00046da1      c101           or #0x1:8,r1h
0x00046da3      0069           nop
0x00046da5      105e           shal r6l
0x00046da7      0164be0d       sleep
0x00046dab      516f           divxu r6h,r7
0x00046dad      6201           bclr r0h,r1h
0x00046daf      f419           mov.b #0x19:8,r4h
0x00046db1      2117           mov.b @0x17:8,r1h
0x00046db3      7110           bnot #0x1:3,r0h
0x00046db5      3110           mov.b r1h,@0x10:8
0x00046db7      310a           mov.b r1h,@0xa:8
0x00046db9      c101           or #0x1:8,r1h
0x00046dbb      006f           nop
0x00046dbd      f000           mov.b #0x0:8,r0h
0x00046dbf      0401           orc #0x1:8,ccr
0x00046dc1      0069           nop
0x00046dc3      105e           shal r6l
0x00046dc5      0164be0f       sleep
0x00046dc9      8101           add.b #0x1:8,r1h
0x00046dcb      006f           nop
0x00046dcd      7000           bset #0x0:3,r0h
0x00046dcf      045e           orc #0x5e:8,ccr
0x00046dd1      015b9a01       sleep
0x00046dd5      006f           nop
0x00046dd7      f000           mov.b #0x0:8,r0h
0x00046dd9      0e7a           addx r7h,r2l
0x00046ddb      013f8000       sleep
0x00046ddf      005e           nop
0x00046de1      015f240d       sleep
0x00046de5      0047           nop
0x00046de7      0e7a           addx r7h,r2l
0x00046de9      003f           nop
0x00046deb      8000           add.b #0x0:8,r0h
0x00046ded      0001           nop
0x00046def      006f           nop
0x00046df1      7100           bnot #0x0:3,r0h
0x00046df3      0e40           addx r4h,r0h
0x00046df5      0c01           mov.b r0h,r1h
0x00046df7      006f           nop
0x00046df9      7000           bset #0x0:3,r0h
0x00046dfb      0e7a           addx r7h,r2l
0x00046dfd      013f8000       sleep
0x00046e01      005e           nop
0x00046e03      01572801       sleep
0x00046e07      006f           nop
0x00046e09      f000           mov.b #0x0:8,r0h
0x00046e0b      0e6f           addx r6h,r7l
0x00046e0d      6101           bnot r0h,r1h
0x00046e0f      f409           mov.b #0x9:8,r4h
0x00046e11      5117           divxu r1h,r7
0x00046e13      7110           bnot #0x1:3,r0h
0x00046e15      3110           mov.b r1h,@0x10:8
0x00046e17      310a           mov.b r1h,@0xa:8
0x00046e19      c101           or #0x1:8,r1h
0x00046e1b      0069           nop
0x00046e1d      105e           shal r6l
0x00046e1f      0164be6f       sleep
0x00046e23      6101           bnot r0h,r1h
0x00046e25      f410           mov.b #0x10:8,r4h
0x00046e27      1109           shlr r1l
0x00046e29      5117           divxu r1h,r7
0x00046e2b      7110           bnot #0x1:3,r0h
0x00046e2d      3110           mov.b r1h,@0x10:8
0x00046e2f      310a           mov.b r1h,@0xa:8
0x00046e31      c101           or #0x1:8,r1h
0x00046e33      006f           nop
0x00046e35      f000           mov.b #0x0:8,r0h
0x00046e37      0401           orc #0x1:8,ccr
0x00046e39      0069           nop
0x00046e3b      105e           shal r6l
0x00046e3d      0164be01       sleep
0x00046e41      006f           nop
0x00046e43      7100           bnot #0x0:3,r0h
0x00046e45      045e           orc #0x5e:8,ccr
0x00046e47      0157327a       sleep
0x00046e4b      01400000       sleep
0x00046e4f      005e           nop
0x00046e51      015b9a0d       sleep
0x00046e55      516f           divxu r6h,r7
0x00046e57      6201           bclr r0h,r1h
0x00046e59      f419           mov.b #0x19:8,r4h
0x00046e5b      2117           mov.b @0x17:8,r1h
0x00046e5d      7110           bnot #0x1:3,r0h
0x00046e5f      3110           mov.b r1h,@0x10:8
0x00046e61      310a           mov.b r1h,@0xa:8
0x00046e63      c101           or #0x1:8,r1h
0x00046e65      0069           nop
0x00046e67      f001           mov.b #0x1:8,r0h
0x00046e69      0069           nop
0x00046e6b      105e           shal r6l
0x00046e6d      0164be0f       sleep
0x00046e71      8101           add.b #0x1:8,r1h
0x00046e73      0069           nop
0x00046e75      705e           bset #0x5:3,r6l
0x00046e77      015b9a01       sleep
0x00046e7b      006f           nop
0x00046e7d      f000           mov.b #0x0:8,r0h
0x00046e7f      167a           and r7h,r2l
0x00046e81      013f8000       sleep
0x00046e85      005e           nop
0x00046e87      015f240d       sleep
0x00046e8b      0047           nop
0x00046e8d      0e7a           addx r7h,r2l
0x00046e8f      003f           nop
0x00046e91      8000           add.b #0x0:8,r0h
0x00046e93      0001           nop
0x00046e95      006f           nop
0x00046e97      7100           bnot #0x0:3,r0h
0x00046e99      1640           and r4h,r0h
0x00046e9b      0c01           mov.b r0h,r1h
0x00046e9d      006f           nop
0x00046e9f      7000           bset #0x0:3,r0h
0x00046ea1      167a           and r7h,r2l
0x00046ea3      013f8000       sleep
0x00046ea7      005e           nop
0x00046ea9      01572801       sleep
0x00046ead      006f           nop
0x00046eaf      f000           mov.b #0x0:8,r0h
0x00046eb1      166f           and r6h,r7l
0x00046eb3      6101           bnot r0h,r1h
0x00046eb5      f410           mov.b #0x10:8,r4h
0x00046eb7      1109           shlr r1l
0x00046eb9      5117           divxu r1h,r7
0x00046ebb      7110           bnot #0x1:3,r0h
0x00046ebd      3110           mov.b r1h,@0x10:8
0x00046ebf      310a           mov.b r1h,@0xa:8
0x00046ec1      c101           or #0x1:8,r1h
0x00046ec3      0069           nop
0x00046ec5      105e           shal r6l
0x00046ec7      0164be0d       sleep
0x00046ecb      516f           divxu r6h,r7
0x00046ecd      6201           bclr r0h,r1h
0x00046ecf      f419           mov.b #0x19:8,r4h
0x00046ed1      2117           mov.b @0x17:8,r1h
0x00046ed3      7110           bnot #0x1:3,r0h
0x00046ed5      3110           mov.b r1h,@0x10:8
0x00046ed7      310a           mov.b r1h,@0xa:8
0x00046ed9      c101           or #0x1:8,r1h
0x00046edb      006f           nop
0x00046edd      f000           mov.b #0x0:8,r0h
0x00046edf      0401           orc #0x1:8,ccr
0x00046ee1      0069           nop
0x00046ee3      105e           shal r6l
0x00046ee5      0164be0f       sleep
0x00046ee9      8101           add.b #0x1:8,r1h
0x00046eeb      006f           nop
0x00046eed      7000           bset #0x0:3,r0h
0x00046eef      045e           orc #0x5e:8,ccr
0x00046ef1      015b9a01       sleep
0x00046ef5      006f           nop
0x00046ef7      f000           mov.b #0x0:8,r0h
0x00046ef9      127a           rotl r2l
0x00046efb      013f8000       sleep
0x00046eff      005e           nop
0x00046f01      015f240d       sleep
0x00046f05      0047           nop
0x00046f07      0e7a           addx r7h,r2l
0x00046f09      003f           nop
0x00046f0b      8000           add.b #0x0:8,r0h
0x00046f0d      0001           nop
0x00046f0f      006f           nop
0x00046f11      7100           bnot #0x0:3,r0h
0x00046f13      1240           rotl r0h
0x00046f15      0c01           mov.b r0h,r1h
0x00046f17      006f           nop
0x00046f19      7000           bset #0x0:3,r0h
0x00046f1b      127a           rotl r2l
0x00046f1d      013f8000       sleep
0x00046f21      005e           nop
0x00046f23      01572801       sleep
0x00046f27      006f           nop
0x00046f29      f000           mov.b #0x0:8,r0h
0x00046f2b      1201           rotxl r1h
0x00046f2d      006f           nop
0x00046f2f      7000           bset #0x0:3,r0h
0x00046f31      1601           and r0h,r1h
0x00046f33      006f           nop
0x00046f35      7100           bnot #0x0:3,r0h
0x00046f37      0e5e           addx r5h,r6l
0x00046f39      015f240d       sleep
0x00046f3d      0047           nop
0x00046f3f      1801           sub.b r0h,r1h
0x00046f41      006f           nop
0x00046f43      7000           bset #0x0:3,r0h
0x00046f45      1601           and r0h,r1h
0x00046f47      006f           nop
0x00046f49      7100           bnot #0x0:3,r0h
0x00046f4b      125e           rotl r6l
0x00046f4d      015f240d       sleep
0x00046f51      0047           nop
0x00046f53      040b           orc #0xb:8,ccr
0x00046f55      5540           bsr .64
0x00046f57      2a01           mov.b @0x1:8,r2l
0x00046f59      006f           nop
0x00046f5b      7000           bset #0x0:3,r0h
0x00046f5d      1201           rotxl r1h
0x00046f5f      006f           nop
0x00046f61      7100           bnot #0x0:3,r0h
0x00046f63      0e5e           addx r5h,r6l
0x00046f65      015f240d       sleep
0x00046f69      0047           nop
0x00046f6b      1601           and r0h,r1h
0x00046f6d      006f           nop
0x00046f6f      7000           bset #0x0:3,r0h
0x00046f71      1201           rotxl r1h
0x00046f73      006f           nop
0x00046f75      7100           bnot #0x0:3,r0h
0x00046f77      165e           and r5h,r6l
0x00046f79      015f240d       sleep
0x00046f7d      0047           nop
0x00046f7f      020b           stc ccr,r3l
0x00046f81      d518           xor #0x18:8,r5h
0x00046f83      886a           add.b #0x6a:8,r0l
0x00046f85      a800           cmp.b #0x0:8,r0l
0x00046f87      2001           mov.b @0x1:8,r0h
0x00046f89      c1f8           or #0xf8:8,r1h
0x00046f8b      806a           add.b #0x6a:8,r0h
0x00046f8d      a800           cmp.b #0x0:8,r0l
0x00046f8f      2000           mov.b @0x0:8,r0h
0x00046f91      016a2900       sleep
0x00046f95      4076           bra @@0x76:8
0x00046f97      266b           mov.b @0x6b:8,r6h
0x00046f99      2000           mov.b @0x0:8,r0h
0x00046f9b      4076           bra @@0x76:8
0x00046f9d      245c           mov.b @0x5c:8,r4h
0x00046f9f      000e           nop
0x00046fa1      2201           mov.b @0x1:8,r2h
0x00046fa3      006b           nop
0x00046fa5      a000           cmp.b #0x0:8,r0h
0x00046fa7      4076           bra @@0x76:8
0x00046fa9      2a01           mov.b @0x1:8,r2l
0x00046fab      006b           nop
0x00046fad      2000           mov.b @0x0:8,r0h
0x00046faf      4076           bra @@0x76:8
0x00046fb1      327a           mov.b r2h,@0x7a:8
0x00046fb3      01000000       sleep
0x00046fb7      ff5e           mov.b #0x5e:8,r7l
0x00046fb9      0163ea01       sleep
0x00046fbd      006b           nop
0x00046fbf      2100           mov.b @0x0:8,r1h
0x00046fc1      4076           bra @@0x76:8
0x00046fc3      2e5e           mov.b @0x5e:8,r6l
0x00046fc5      015cf26f       sleep
0x00046fc9      6101           bnot r0h,r1h
0x00046fcb      f017           mov.b #0x17:8,r0h
0x00046fcd      711f           bnot #0x1:3,r7l
0x00046fcf      9058           addx #0x58:8,r0h
0x00046fd1      4001           bra @@0x1:8
0x00046fd3      4201           bhi @@0x1:8
0x00046fd5      006b           nop
0x00046fd7      2000           mov.b @0x0:8,r0h
0x00046fd9      4076           bra @@0x76:8
0x00046fdb      2e01           mov.b @0x1:8,r6l
0x00046fdd      006b           nop
0x00046fdf      2100           mov.b @0x0:8,r1h
0x00046fe1      4076           bra @@0x76:8
0x00046fe3      2a1f           mov.b @0x1f:8,r2l
0x00046fe5      9058           addx #0x58:8,r0h
0x00046fe7      3001           mov.b r0h,@0x1:8
0x00046fe9      2c0d           mov.b @0xd:8,r4l
0x00046feb      5558           bsr .88
0x00046fed      7001           bset #0x0:3,r1h
0x00046fef      266f           mov.b @0x6f:8,r6h
0x00046ff1      6100           bnot r0h,r0h
0x00046ff3      e21d           and #0x1d:8,r2h
0x00046ff5      1558           xor r5h,r0l
0x00046ff7      7001           bset #0x0:3,r1h
0x00046ff9      1c01           cmp.b r0h,r1h
0x00046ffb      006f           nop
0x00046ffd      7100           bnot #0x0:3,r0h
0x00046fff      0a69           inc r1l
0x00047001      956b           addx #0x6b:8,r5h
0x00047003      a500           cmp.b #0x0:8,r5h
0x00047005      407c           bra @@0x7c:8
0x00047007      a419           cmp.b #0x19:8,r4h
0x00047009      006b           nop
0x0004700b      a000           cmp.b #0x0:8,r0h
0x0004700d      4007           bra @@0x7:8
0x0004700f      78             invalid
0x00047010      7a             invalid
0x00047011      0500           xorc #0x0:8,ccr
0x00047013      4052           bra @@0x52:8
0x00047015      a26b           cmp.b #0x6b:8,r2h
0x00047017      2100           mov.b @0x0:8,r1h
0x00047019      4052           bra @@0x52:8
0x0004701b      a411           cmp.b #0x11:8,r4h
0x0004701d      111a           shar r2l
0x0004701f      806a           add.b #0x6a:8,r0h
0x00047021      2800           mov.b @0x0:8,r0l
0x00047023      4076           bra @@0x76:8
0x00047025      2710           mov.b @0x10:8,r7h
0x00047027      3078           mov.b r0h,@0x78:8
0x00047029      006b           nop
0x0004702b      2200           mov.b @0x0:8,r2h
0x0004702d      4074           bra @@0x74:8
0x0004702f      d809           xor #0x9:8,r0l
0x00047031      1279           rotl r1l
0x00047033      0a0f           inc r7l
0x00047035      a052           cmp.b #0x52:8,r0h
0x00047037      a26b           cmp.b #0x6b:8,r2h
0x00047039      2100           mov.b @0x0:8,r1h
0x0004703b      400d           bra @@0xd:8
0x0004703d      3a17           mov.b r2l,@0x17:8
0x0004703f      710f           bnot #0x0:3,r7l
0x00047041      a05e           cmp.b #0x5e:8,r0h
0x00047043      015cf269       sleep
0x00047047      d06a           xor #0x6a:8,r0h
0x00047049      2800           mov.b @0x0:8,r0l
0x0004704b      4007           bra @@0x7:8
0x0004704d      73a8           btst #0x2:3,r0l
0x0004704f      0246           stc ccr,r6h
0x00047051      0c6b           mov.b r6h,r3l
0x00047053      2000           mov.b @0x0:8,r0h
0x00047055      400e           bra @@0xe:8
0x00047057      8469           add.b #0x69:8,r4h
0x00047059      5119           divxu r1h,r1
0x0004705b      0169d16b       sleep
0x0004705f      2000           mov.b @0x0:8,r0h
0x00047061      4074           bra @@0x74:8
0x00047063      ca17           or #0x17:8,r2l
0x00047065      7001           bset #0x0:3,r1h
0x00047067      0069           nop
0x00047069      b07a           subx #0x7a:8,r0h
0x0004706b      0500           xorc #0x0:8,ccr
0x0004706d      4052           bra @@0x52:8
0x0004706f      d46a           xor #0x6a:8,r4h
0x00047071      2800           mov.b @0x0:8,r0l
0x00047073      4007           bra @@0x7:8
0x00047075      73a8           btst #0x2:3,r0l
0x00047077      0246           stc ccr,r6h
0x00047079      2869           mov.b @0x69:8,r0l
0x0004707b      556f           bsr .111
0x0004707d      6000           bset r0h,r0h
0x0004707f      2219           mov.b @0x19:8,r2h
0x00047081      0517           xorc #0x17:8,ccr
0x00047083      7501           bxor #0x0:3,r1h
0x00047085      0069           nop
0x00047087      b56a           subx #0x6a:8,r5h
0x00047089      2800           mov.b @0x0:8,r0l
0x0004708b      4076           bra @@0x76:8
0x0004708d      2917           mov.b @0x17:8,r1l
0x0004708f      5079           mulxu r7h,r1
0x00047091      0811           add.b r1h,r1h
0x00047093      65             invalid
0x00047094      52             invalid
0x00047095      8001           add.b #0x1:8,r0h
0x00047097      0069           nop
0x00047099      310a           mov.b r1h,@0xa:8
0x0004709b      8101           add.b #0x1:8,r1h
0x0004709d      0069           nop
0x0004709f      b140           subx #0x40:8,r1h
0x000470a1      52             invalid
0x000470a2      6a280040       mov.b @0x40:16,r0l
0x000470a6      0773           ldc #0x73:8,ccr
0x000470a8      471a           beq @@0x1a:8
0x000470aa      a801           cmp.b #0x1:8,r0l
0x000470ac      472e           beq @@0x2e:8
0x000470ae      a803           cmp.b #0x3:8,r0l
0x000470b0      471a           beq @@0x1a:8
0x000470b2      a804           cmp.b #0x4:8,r0l
0x000470b4      4726           beq @@0x26:8
0x000470b6      a805           cmp.b #0x5:8,r0l
0x000470b8      4722           beq @@0x22:8
0x000470ba      a806           cmp.b #0x6:8,r0l
0x000470bc      4706           beq @@0x6:8
0x000470be      a807           cmp.b #0x7:8,r0l
0x000470c0      4702           beq @@0x2:8
0x000470c2      4030           bra @@0x30:8
0x000470c4      6955           mov.w @r5,r5
0x000470c6      6f600066       mov.w @(0x66:16,r6),r0
0x000470ca      4006           bra @@0x6:8
0x000470cc      6955           mov.w @r5,r5
0x000470ce      6f600044       mov.w @(0x44:16,r6),r0
0x000470d2      1905           sub.w r0,r5
0x000470d4      1775           neg r5h
0x000470d6      010069b5       sleep
0x000470da      4018           bra @@0x18:8
0x000470dc      6a280040       mov.b @0x40:16,r0l
0x000470e0      7629           band #0x2:3,r1l
0x000470e2      1750           neg r0h
0x000470e4      79081747       mov.w #0x1747:16,r0
0x000470e8      52             invalid
0x000470e9      8001           add.b #0x1:8,r0h
0x000470eb      0069           nop
0x000470ed      310a           mov.b r1h,@0xa:8
0x000470ef      8101           add.b #0x1:8,r1h
0x000470f1      0069           nop
0x000470f3      b101           subx #0x1:8,r1h
0x000470f5      0069           nop
0x000470f7      307a           mov.b r0h,@0x7a:8
0x000470f9      0100000f       sleep
0x000470fd      a05e           cmp.b #0x5e:8,r0h
0x000470ff      0163ea6b       sleep
0x00047103      2100           mov.b @0x0:8,r1h
0x00047105      400d           bra @@0xd:8
0x00047107      3a17           mov.b r2l,@0x17:8
0x00047109      715e           bnot #0x5:3,r6l
0x0004710b      015cf201       sleep
0x0004710f      0069           nop
0x00047111      b0f8           subx #0xf8:8,r0h
0x00047113      0140626e       sleep
0x00047117      78             invalid
0x00047118      0009           nop
0x0004711a      a8             cmp.b #0x10:8,r0l
0x0004711c      4758           beq @@0x58:8
0x0004711e      01006b20       sleep
0x00047122      0040           nop
0x00047124      7632           band #0x3:3,r2h
0x00047126      7a             invalid
0x00047127      01000000       sleep
0x0004712b      ff5e           mov.b #0x5e:8,r7l
0x0004712d      0163ea01       sleep
0x00047131      006b           nop
0x00047133      2100           mov.b @0x0:8,r1h
0x00047135      4076           bra @@0x76:8
0x00047137      2e5e           mov.b @0x5e:8,r6l
0x00047139      015cf26f       sleep
0x0004713d      6101           bnot r0h,r1h
0x0004713f      f017           mov.b #0x17:8,r0h
0x00047141      711f           bnot #0x1:3,r7l
0x00047143      9044           addx #0x44:8,r0h
0x00047145      2601           mov.b @0x1:8,r6h
0x00047147      006b           nop
0x00047149      2000           mov.b @0x0:8,r0h
0x0004714b      4076           bra @@0x76:8
0x0004714d      2e01           mov.b @0x1:8,r6l
0x0004714f      006b           nop
0x00047151      2100           mov.b @0x0:8,r1h
0x00047153      4076           bra @@0x76:8
0x00047155      2a1f           mov.b @0x1f:8,r2l
0x00047157      9043           addx #0x43:8,r0h
0x00047159      120d           rotxl r5l
0x0004715b      5547           bsr .71
0x0004715d      086f           add.b r6h,r7l
0x0004715f      6100           bnot r0h,r0h
0x00047161      e21d           and #0x1d:8,r2h
0x00047163      1546           xor r4h,r6h
0x00047165      0679           andc #0x79:8,ccr
0x00047167      0009           nop
0x00047169      2040           mov.b @0x40:8,r0h
0x0004716b      0479           orc #0x79:8,ccr
0x0004716d      0009           nop
0x0004716f      306b           mov.b r0h,@0x6b:8
0x00047171      a000           cmp.b #0x0:8,r0h
0x00047173      4007           bra @@0x7:8
0x00047175      78             invalid
0x00047176      1888           sub.b r0l,r0l
0x00047178      7a             invalid
0x00047179      1700           not r0h
0x0004717b      0000           nop
0x0004717d      1a5e           dec r6l
0x0004717f      01643654       sleep
0x00047183      706d           bset #0x6:3,r5l
0x00047185      f60d           mov.b #0xd:8,r6h
0x00047187      065e           andc #0x5e:8,ccr
0x00047189      02e2           stc ccr,r2h
0x0004718b      f418           mov.b #0x18:8,r4h
0x0004718d      886a           add.b #0x6a:8,r0l
0x0004718f      a800           cmp.b #0x0:8,r0l
0x00047191      407c           bra @@0x7c:8
0x00047193      a27a           cmp.b #0x7a:8,r2h
0x00047195      0000           nop
0x00047197      0000           nop
0x00047199      64             invalid
0x0004719a      5e01233a       jsr @0x233a:16
0x0004719e      0d60           mov.w r6,r0
0x000471a0      5e02e2f4       jsr @0xe2f4:16
0x000471a4      1888           sub.b r0l,r0l
0x000471a6      6aa80040       mov.b r0l,@0x40:16
0x000471aa      7ca27a00       biand #0x0:3,@r10
0x000471ae      0000           nop
0x000471b0      0064           nop
0x000471b2      5e01233a       jsr @0x233a:16
0x000471b6      6b200040       mov.w @0x40:16,r0
0x000471ba      7ca66b21       biand #0x2:3,@r10
0x000471be      0040           nop
0x000471c0      7ca81910       biand #0x1:3,@r10
0x000471c4      79200780       mov.w #0x780:16,r0
0x000471c8      440a           bcc @@0xa:8
0x000471ca      6ba60040       mov.w r6,@0x40:16
0x000471ce      52             invalid
0x000471cf      9cf8           addx #0xf8:8,r4l
0x000471d1      01400c79       sleep
0x000471d5      0009           nop
0x000471d7      406b           bra @@0x6b:8
0x000471d9      a000           cmp.b #0x0:8,r0h
0x000471db      4007           bra @@0x7:8
0x000471dd      78             invalid
0x000471de      1888           sub.b r0l,r0l
0x000471e0      6d76           pop r6
0x000471e2      5470           rts
0x000471e4      5e016458       jsr @0x6458:16
0x000471e8      7a             invalid
0x000471e9      3700           mov.b r7h,@0x0:8
0x000471eb      0000           nop
0x000471ed      64             invalid
0x000471ee      7a             invalid
0x000471ef      0400           orc #0x0:8,ccr
0x000471f1      400f           bra @@0xf:8
0x000471f3      567a           rte
0x000471f5      0500           xorc #0x0:8,ccr
0x000471f7      407c           bra @@0x7c:8
0x000471f9      52             invalid
0x000471fa      0d0e           mov.w r0,r6
0x000471fc      0d86           mov.w r8,r6
0x000471fe      6ef90055       mov.b r1l,@(0x55:16,r7)
0x00047202      6ef10054       mov.b r1h,@(0x54:16,r7)
0x00047206      6ff9003a       mov.w r1,@(0x3a:16,r7)
0x0004720a      6ff60060       mov.w r6,@(0x60:16,r7)
0x0004720e      0de0           mov.w r14,r0
0x00047210      5e02e2f4       jsr @0xe2f4:16
0x00047214      6e78007d       mov.b @(0x7d:16,r7),r0l
0x00047218      a803           cmp.b #0x3:8,r0l
0x0004721a      4612           bne @@0x12:8
0x0004721c      1888           sub.b r0l,r0l
0x0004721e      68c8           mov.b r0l,@r4
0x00047220      f802           mov.b #0x2:8,r0l
0x00047222      6ec80001       mov.b r0l,@(0x1:16,r4)
0x00047226      f801           mov.b #0x1:8,r0l
0x00047228      6ec80002       mov.b r0l,@(0x2:16,r4)
0x0004722c      401c           bra @@0x1c:8
0x0004722e      6e78007d       mov.b @(0x7d:16,r7),r0l
0x00047232      a802           cmp.b #0x2:8,r0l
0x00047234      460c           bne @@0xc:8
0x00047236      1888           sub.b r0l,r0l
0x00047238      68c8           mov.b r0l,@r4
0x0004723a      f801           mov.b #0x1:8,r0l
0x0004723c      6ec80001       mov.b r0l,@(0x1:16,r4)
0x00047240      4008           bra @@0x8:8
0x00047242      6a280040       mov.b @0x40:16,r0l
0x00047246      7626           band #0x2:3,r6h
0x00047248      68c8           mov.b r0l,@r4
0x0004724a      18ee           sub.b r6l,r6l
0x0004724c      5a047ade       jmp @0x7ade:16
0x00047250      6b200040       mov.w @0x40:16,r0
0x00047254      0776           ldc #0x76:8,ccr
0x00047256      7370           btst #0x7:3,r0h
0x00047258      58             invalid
0x00047259      6008           bset r0h,r0l
0x0004725b      8c6f           add.b #0x6f:8,r4l
0x0004725d      7000           bset #0x0:3,r0h
0x0004725f      606b           bset r6h,r3l
0x00047261      2100           mov.b @0x0:8,r1h
0x00047263      4052           bra @@0x52:8
0x00047265      d41d           xor #0x1d:8,r4h
0x00047267      1047           shal r7h
0x00047269      2218           mov.b @0x18:8,r2h
0x0004726b      886d           add.b #0x6d:8,r0l
0x0004726d      f06b           mov.b #0x6b:8,r0h
0x0004726f      2100           mov.b @0x0:8,r1h
0x00047271      400c           bra @@0xc:8
0x00047273      c879           or #0x79:8,r0l
0x00047275      0903           add.w r0,r3
0x00047277      e852           and #0x52:8,r0l
0x00047279      916f           addx #0x6f:8,r1h
0x0004727b      7000           bset #0x0:3,r0h
0x0004727d      625e           bclr r5h,r6l
0x0004727f      02d7           stc ccr,r7h
0x00047281      ae0b           cmp.b #0xb:8,r6l
0x00047283      875e           add.b #0x5e:8,r7h
0x00047285      02d5           stc ccr,r5h
0x00047287      980c           addx #0xc:8,r0l
0x00047289      8847           add.b #0x47:8,r0l
0x0004728b      de18           xor #0x18:8,r6l
0x0004728d      66             invalid
0x0004728e      403c           bra @@0x3c:8
0x00047290      0c60           mov.b r6h,r0h
0x00047292      1888           sub.b r0l,r0l
0x00047294      5e039c6c       jsr @0x9c6c:16
0x00047298      0c6b           mov.b r6h,r3l
0x0004729a      1753           neg r3h
0x0004729c      1773           neg r3h
0x0004729e      1033           shal r3h
0x000472a0      1033           shal r3h
0x000472a2      01007830       sleep
0x000472a6      6b200040       mov.w @0x40:16,r0
0x000472aa      1078           shal r0l
0x000472ac      01007830       sleep
0x000472b0      6b210040       mov.w @0x40:16,r1
0x000472b4      1088           shal r0l
0x000472b6      0a90           inc r0h
0x000472b8      0fd1           daa r1h
0x000472ba      0ab1           inc r1h
0x000472bc      01006990       sleep
0x000472c0      010078b0       sleep
0x000472c4      6ba00040       mov.w r0,@0x40:16
0x000472c8      7c620a06       biand #0x0:3,@r6
0x000472cc      a604           cmp.b #0x4:8,r6h
0x000472ce      45c0           bcs @@0xc0:8
0x000472d0      7a             invalid
0x000472d1      0100407c       sleep
0x000472d5      626e           bclr r6h,r6l
0x000472d7      78             invalid
0x000472d8      007d           nop
0x000472da      5e035e4a       jsr @0x5e4a:16
0x000472de      1888           sub.b r0l,r0l
0x000472e0      5a0476f0       jmp @0x76f0:16
0x000472e4      1a80           dec r0h
0x000472e6      6e78005f       mov.b @(0x5f:16,r7),r0l
0x000472ea      0ac0           inc r0h
0x000472ec      6806           mov.b @r0,r6h
0x000472ee      790e0001       mov.w #0x1:16,r6
0x000472f2      0c6b           mov.b r6h,r3l
0x000472f4      1753           neg r3h
0x000472f6      1773           neg r3h
0x000472f8      1033           shal r3h
0x000472fa      1033           shal r3h
0x000472fc      6b200040       mov.w @0x40:16,r0
0x00047300      0e88           addx r0l,r0l
0x00047302      1770           neg r0h
0x00047304      1030           shal r0h
0x00047306      01007830       sleep
0x0004730a      6b230040       mov.w @0x40:16,r3
0x0004730e      4ea2           bgt @@0xa2:8
0x00047310      0a83           inc r3h
0x00047312      1900           sub.w r0,r0
0x00047314      400e           bra @@0xe:8
0x00047316      6930           mov.w @r3,r0
0x00047318      1de0           cmp.w r14,r0
0x0004731a      4302           bls @@0x2:8
0x0004731c      693e           mov.w @r3,r6
0x0004731e      0bf3           adds #2,r3
0x00047320      0d90           mov.w r9,r0
0x00047322      0b50           adds #1,r0
0x00047324      0d09           mov.w r0,r1
0x00047326      6b210040       mov.w @0x40:16,r1
0x0004732a      0e86           addx r0l,r6h
0x0004732c      1d10           cmp.w r1,r0
0x0004732e      45e6           bcs @@0xe6:8
0x00047330      79005a00       mov.w #0x5a00:16,r0
0x00047334      6b80ffa8       mov.w r0,@0xffa8:16
0x00047338      0ce8           mov.b r6l,r0l
0x0004733a      1750           neg r0h
0x0004733c      1770           neg r0h
0x0004733e      01006ff0       sleep
0x00047342      003c           nop
0x00047344      f906           mov.b #0x6:8,r1l
0x00047346      1030           shal r0h
0x00047348      1a09           dec r1l
0x0004734a      4efa           bgt @@0xfa:8
0x0004734c      0c69           mov.b r6h,r1l
0x0004734e      1751           neg r1h
0x00047350      1771           neg r1h
0x00047352      01006ff1       sleep
0x00047356      0040           nop
0x00047358      1031           shal r1h
0x0004735a      1031           shal r1h
0x0004735c      1031           shal r1h
0x0004735e      1031           shal r1h
0x00047360      7a             invalid
0x00047361      1000           shll r0h
0x00047363      4075           bra @@0x75:8
0x00047365      440a           bcc @@0xa:8
0x00047367      907a           addx #0x7a:8,r0h
0x00047369      1000           shll r0h
0x0004736b      0000           nop
0x0004736d      0c0d           mov.b r0h,r5l
0x0004736f      e117           and #0x17:8,r1h
0x00047371      7101           bnot #0x0:3,r1h
0x00047373      0069           nop
0x00047375      8101           add.b #0x1:8,r1h
0x00047377      006f           nop
0x00047379      7300           btst #0x0:3,r0h
0x0004737b      4010           bra @@0x10:8
0x0004737d      3310           mov.b r3h,@0x10:8
0x0004737f      3301           mov.b r3h,@0x1:8
0x00047381      006f           nop
0x00047383      7000           bset #0x0:3,r0h
0x00047385      3c10           mov.b r4l,@0x10:8
0x00047387      3010           mov.b r0h,@0x10:8
0x00047389      3010           mov.b r0h,@0x10:8
0x0004738b      3010           mov.b r0h,@0x10:8
0x0004738d      307a           mov.b r0h,@0x7a:8
0x0004738f      1000           shll r0h
0x00047391      407b           bra @@0x7b:8
0x00047393      720a           bclr #0x0:3,r2l
0x00047395      b001           subx #0x1:8,r0h
0x00047397      0078           nop
0x00047399      306b           mov.b r0h,@0x6b:8
0x0004739b      2100           mov.b @0x0:8,r1h
0x0004739d      4010           bra @@0x10:8
0x0004739f      78             invalid
0x000473a0      01006ff0       sleep
0x000473a4      0028           nop
0x000473a6      7a             invalid
0x000473a7      0000           nop
0x000473a9      0000           nop
0x000473ab      2c0a           mov.b @0xa:8,r4l
0x000473ad      f05e           mov.b #0x5e:8,r0h
0x000473af      0164800d       sleep
0x000473b3      e101           and #0x1:8,r1h
0x000473b5      006f           nop
0x000473b7      f000           mov.b #0x0:8,r0h
0x000473b9      1c7a           cmp.b r7h,r2l
0x000473bb      0000           nop
0x000473bd      0000           nop
0x000473bf      200a           mov.b @0xa:8,r0h
0x000473c1      f05e           mov.b #0x5e:8,r0h
0x000473c3      0164fe7a       sleep
0x000473c7      010004a6       sleep
0x000473cb      0c0f           mov.b r0h,r7l
0x000473cd      827a           add.b #0x7a:8,r2h
0x000473cf      0000           nop
0x000473d1      0000           nop
0x000473d3      140a           or r0h,r2l
0x000473d5      f05e           mov.b #0x5e:8,r0h
0x000473d7      0159a401       sleep
0x000473db      006f           nop
0x000473dd      7100           bnot #0x0:3,r0h
0x000473df      1c0f           cmp.b r0h,r7l
0x000473e1      827a           add.b #0x7a:8,r2h
0x000473e3      0000           nop
0x000473e5      0000           nop
0x000473e7      0c0a           mov.b r0h,r2l
0x000473e9      f05e           mov.b #0x5e:8,r0h
0x000473eb      0160305e       sleep
0x000473ef      015d2e01       sleep
0x000473f3      0078           nop
0x000473f5      306b           mov.b r0h,@0x6b:8
0x000473f7      2100           mov.b @0x0:8,r1h
0x000473f9      4010           bra @@0x10:8
0x000473fb      880a           add.b #0xa:8,r0l
0x000473fd      9001           addx #0x1:8,r0h
0x000473ff      006f           nop
0x00047401      7100           bnot #0x0:3,r0h
0x00047403      2801           mov.b @0x1:8,r0l
0x00047405      0069           nop
0x00047407      906b           addx #0x6b:8,r0h
0x00047409      2000           mov.b @0x0:8,r0h
0x0004740b      4052           bra @@0x52:8
0x0004740d      a41b           cmp.b #0x1b:8,r4h
0x0004740f      506f           mulxu r6h,r7
0x00047411      f000           mov.b #0x0:8,r0h
0x00047413      4618           bne @@0x18:8
0x00047415      885a           add.b #0x5a:8,r0l
0x00047417      0476           orc #0x76:8,ccr
0x00047419      e079           and #0x79:8,r0h
0x0004741b      0e             addx r1h,r0h
0x0004741d      010c6b17       sleep
0x00047421      53             invalid
0x00047422      1773           neg r3h
0x00047424      1033           shal r3h
0x00047426      1033           shal r3h
0x00047428      1a80           dec r0h
0x0004742a      6e780063       mov.b @(0x63:16,r7),r0l
0x0004742e      1030           shal r0h
0x00047430      78             invalid
0x00047431      006b           nop
0x00047433      2000           mov.b @0x0:8,r0h
0x00047435      4074           bra @@0x74:8
0x00047437      d817           xor #0x17:8,r0l
0x00047439      7010           bset #0x1:3,r0h
0x0004743b      3001           mov.b r0h,@0x1:8
0x0004743d      0078           nop
0x0004743f      306b           mov.b r0h,@0x6b:8
0x00047441      2300           mov.b @0x0:8,r3h
0x00047443      404e           bra @@0x4e:8
0x00047445      a20a           cmp.b #0xa:8,r2h
0x00047447      831a           add.b #0x1a:8,r3h
0x00047449      8001           add.b #0x1:8,r0h
0x0004744b      006f           nop
0x0004744d      f000           mov.b #0x0:8,r0h
0x0004744f      5a190040       jmp @0x40:16
0x00047453      2069           mov.b @0x69:8,r0h
0x00047455      301d           mov.b r0h,@0x1d:8
0x00047457      e043           and #0x43:8,r0h
0x00047459      0269           stc ccr,r1l
0x0004745b      3e69           mov.b r6l,@0x69:8
0x0004745d      3017           mov.b r0h,@0x17:8
0x0004745f      7001           bset #0x0:3,r1h
0x00047461      006f           nop
0x00047463      7100           bnot #0x0:3,r0h
0x00047465      5a0a8101       jmp @0x8101:16
0x00047469      006f           nop
0x0004746b      f100           mov.b #0x0:8,r1h
0x0004746d      5a0bf30d       jmp @0xf30d:16
0x00047471      200b           mov.b @0xb:8,r0h
0x00047473      500d           mulxu r0h,r5
0x00047475      026f           stc ccr,r7l
0x00047477      7100           bnot #0x0:3,r0h
0x00047479      461d           bne @@0x1d:8
0x0004747b      1045           shal r5h
0x0004747d      d679           xor #0x79:8,r6h
0x0004747f      005a           nop
0x00047481      006b           nop
0x00047483      80ff           add.b #0xff:8,r0h
0x00047485      a86b           cmp.b #0x6b:8,r0l
0x00047487      2100           mov.b @0x0:8,r1h
0x00047489      4052           bra @@0x52:8
0x0004748b      a417           cmp.b #0x17:8,r4h
0x0004748d      7101           bnot #0x0:3,r1h
0x0004748f      006f           nop
0x00047491      7000           bset #0x0:3,r0h
0x00047493      5a5e015c       jmp @0x15c:16
0x00047497      f201           mov.b #0x1:8,r2h
0x00047499      006f           nop
0x0004749b      f000           mov.b #0x0:8,r0h
0x0004749d      5a0ceb17       jmp @0xeb17:16
0x000474a1      53             invalid
0x000474a2      1773           neg r3h
0x000474a4      0fb0           daa r0h
0x000474a6      7a             invalid
0x000474a7      01000000       sleep
0x000474ab      185e           sub.b r5h,r6l
0x000474ad      0163ea0c       sleep
0x000474b1      6917           mov.w @r1,r7
0x000474b3      5117           divxu r1h,r7
0x000474b5      7101           bnot #0x0:3,r1h
0x000474b7      006f           nop
0x000474b9      f100           mov.b #0x0:8,r1h
0x000474bb      5601           rte
0x000474bd      006f           nop
0x000474bf      f000           mov.b #0x0:8,r0h
0x000474c1      307a           mov.b r0h,@0x7a:8
0x000474c3      0000           nop
0x000474c5      0000           nop
0x000474c7      065e           andc #0x5e:8,ccr
0x000474c9      0163ea01       sleep
0x000474cd      006f           nop
0x000474cf      7100           bnot #0x0:3,r0h
0x000474d1      307a           mov.b r0h,@0x7a:8
0x000474d3      1100           shlr r0h
0x000474d5      4075           bra @@0x75:8
0x000474d7      f40a           mov.b #0xa:8,r4h
0x000474d9      811a           add.b #0x1a:8,r1h
0x000474db      806e           add.b #0x6e:8,r0h
0x000474dd      78             invalid
0x000474de      0063           nop
0x000474e0      01006ff0       sleep
0x000474e4      0050           nop
0x000474e6      1030           shal r0h
0x000474e8      0a81           inc r1h
0x000474ea      6f70005c       mov.w @(0x5c:16,r7),r0
0x000474ee      6990           mov.w r0,@r1
0x000474f0      01006f70       sleep
0x000474f4      0050           nop
0x000474f6      1030           shal r0h
0x000474f8      1030           shal r0h
0x000474fa      01006ff0       sleep
0x000474fe      004c           nop
0x00047500      0fb1           daa r1h
0x00047502      fa06           mov.b #0x6:8,r2l
0x00047504      1031           shal r1h
0x00047506      1a0a           dec r2l
0x00047508      4efa           bgt @@0xfa:8
0x0004750a      01006f72       sleep
0x0004750e      0056           nop
0x00047510      1032           shal r2h
0x00047512      1032           shal r2h
0x00047514      1032           shal r2h
0x00047516      1032           shal r2h
0x00047518      7a             invalid
0x00047519      1100           shlr r0h
0x0004751b      4075           bra @@0x75:8
0x0004751d      440a           bcc @@0xa:8
0x0004751f      a10a           cmp.b #0xa:8,r1h
0x00047521      810d           add.b #0xd:8,r1h
0x00047523      e017           and #0x17:8,r0h
0x00047525      7001           bset #0x0:3,r1h
0x00047527      0069           nop
0x00047529      9001           addx #0x1:8,r0h
0x0004752b      006f           nop
0x0004752d      7000           bset #0x0:3,r0h
0x0004752f      567a           rte
0x00047531      01000000       sleep
0x00047535      0c5e           mov.b r5h,r6l
0x00047537      0163ea01       sleep
0x0004753b      006f           nop
0x0004753d      f000           mov.b #0x0:8,r0h
0x0004753f      300f           mov.b r0h,@0xf:8
0x00047541      b07a           subx #0x7a:8,r0h
0x00047543      01000000       sleep
0x00047547      305e           mov.b r0h,@0x5e:8
0x00047549      0163ea7a       sleep
0x0004754d      1000           shll r0h
0x0004754f      407b           bra @@0x7b:8
0x00047551      9201           addx #0x1:8,r2h
0x00047553      006f           nop
0x00047555      7100           bnot #0x0:3,r0h
0x00047557      300a           mov.b r0h,@0xa:8
0x00047559      9001           addx #0x1:8,r0h
0x0004755b      006f           nop
0x0004755d      7100           bnot #0x0:3,r0h
0x0004755f      4c0a           bge @@0xa:8
0x00047561      9001           addx #0x1:8,r0h
0x00047563      006f           nop
0x00047565      f000           mov.b #0x0:8,r0h
0x00047567      5001           mulxu r0h,r1
0x00047569      006f           nop
0x0004756b      7100           bnot #0x0:3,r0h
0x0004756d      5610           rte
0x0004756f      3110           mov.b r1h,@0x10:8
0x00047571      3101           mov.b r1h,@0x1:8
0x00047573      006f           nop
0x00047575      f100           mov.b #0x0:8,r1h
0x00047577      5a010078       jmp @0x78:16
0x0004757b      106b           shal r3l
0x0004757d      2100           mov.b @0x0:8,r1h
0x0004757f      4010           bra @@0x10:8
0x00047581      78             invalid
0x00047582      01006ff0       sleep
0x00047586      0024           nop
0x00047588      7a             invalid
0x00047589      0000           nop
0x0004758b      0000           nop
0x0004758d      280a           mov.b @0xa:8,r0l
0x0004758f      f05e           mov.b #0x5e:8,r0h
0x00047591      0164800d       sleep
0x00047595      e101           and #0x1:8,r1h
0x00047597      006f           nop
0x00047599      f000           mov.b #0x0:8,r0h
0x0004759b      187a           sub.b r7h,r2l
0x0004759d      0000           nop
0x0004759f      0000           nop
0x000475a1      1c0a           cmp.b r0h,r2l
0x000475a3      f05e           mov.b #0x5e:8,r0h
0x000475a5      0164fe7a       sleep
0x000475a9      010004a6       sleep
0x000475ad      140f           or r0h,r7l
0x000475af      827a           add.b #0x7a:8,r2h
0x000475b1      0000           nop
0x000475b3      0000           nop
0x000475b5      100a           shll r2l
0x000475b7      f05e           mov.b #0x5e:8,r0h
0x000475b9      0159a401       sleep
0x000475bd      006f           nop
0x000475bf      7100           bnot #0x0:3,r0h
0x000475c1      180f           sub.b r0h,r7l
0x000475c3      827a           add.b #0x7a:8,r2h
0x000475c5      0000           nop
0x000475c7      0000           nop
0x000475c9      080a           add.b r0h,r2l
0x000475cb      f05e           mov.b #0x5e:8,r0h
0x000475cd      0160300f       sleep
0x000475d1      817a           add.b #0x7a:8,r1h
0x000475d3      0200           stc ccr,r0h
0x000475d5      04a6           orc #0xa6:8,ccr
0x000475d7      1c0f           cmp.b r0h,r7l
0x000475d9      f05e           mov.b #0x5e:8,r0h
0x000475db      0160305e       sleep
0x000475df      015d2e01       sleep
0x000475e3      006f           nop
0x000475e5      7100           bnot #0x0:3,r0h
0x000475e7      5a010078       jmp @0x78:16
0x000475eb      106b           shal r3l
0x000475ed      2100           mov.b @0x0:8,r1h
0x000475ef      4010           bra @@0x10:8
0x000475f1      880a           add.b #0xa:8,r0l
0x000475f3      9001           addx #0x1:8,r0h
0x000475f5      006f           nop
0x000475f7      7100           bnot #0x0:3,r0h
0x000475f9      2401           mov.b @0x1:8,r4h
0x000475fb      0069           nop
0x000475fd      9010           addx #0x10:8,r0h
0x000475ff      3310           mov.b r3h,@0x10:8
0x00047601      3310           mov.b r3h,@0x10:8
0x00047603      3310           mov.b r3h,@0x10:8
0x00047605      337a           mov.b r3h,@0x7a:8
0x00047607      1300           rotxr r0h
0x00047609      407b           bra @@0x7b:8
0x0004760b      7201           bclr #0x0:3,r1h
0x0004760d      006f           nop
0x0004760f      7000           bset #0x0:3,r0h
0x00047611      5a0a8301       jmp @0x8301:16
0x00047615      006f           nop
0x00047617      7000           bset #0x0:3,r0h
0x00047619      5001           mulxu r0h,r1
0x0004761b      0069           nop
0x0004761d      3301           mov.b r3h,@0x1:8
0x0004761f      0069           nop
0x00047621      001f           nop
0x00047623      8342           add.b #0x42:8,r3h
0x00047625      6e0ce817       mov.b @(0xe817:16,r0),r4l
0x00047629      5017           mulxu r1h,r7
0x0004762b      7001           bset #0x0:3,r1h
0x0004762d      006f           nop
0x0004762f      f000           mov.b #0x0:8,r0h
0x00047631      5a7a0100       jmp @0x100:16
0x00047635      0000           nop
0x00047637      305e           mov.b r0h,@0x5e:8
0x00047639      0163ea0c       sleep
0x0004763d      6b175317       mov.w @0x5317:16,r7
0x00047641      7301           btst #0x0:3,r1h
0x00047643      006f           nop
0x00047645      f000           mov.b #0x0:8,r0h
0x00047647      300f           mov.b r0h,@0xf:8
0x00047649      b07a           subx #0x7a:8,r0h
0x0004764b      01000000       sleep
0x0004764f      0c5e           mov.b r5h,r6l
0x00047651      0163ea01       sleep
0x00047655      006f           nop
0x00047657      7100           bnot #0x0:3,r0h
0x00047659      307a           mov.b r0h,@0x7a:8
0x0004765b      1100           shlr r0h
0x0004765d      407b           bra @@0x7b:8
0x0004765f      f20a           mov.b #0xa:8,r2h
0x00047661      811a           add.b #0x1a:8,r1h
0x00047663      806e           add.b #0x6e:8,r0h
0x00047665      78             invalid
0x00047666      0063           nop
0x00047668      1030           shal r0h
0x0004766a      1030           shal r0h
0x0004766c      0a81           inc r1h
0x0004766e      01006f70       sleep
0x00047672      005a           nop
0x00047674      1030           shal r0h
0x00047676      1030           shal r0h
0x00047678      1030           shal r0h
0x0004767a      1030           shal r0h
0x0004767c      0fb2           daa r2h
0x0004767e      1032           shal r2h
0x00047680      1032           shal r2h
0x00047682      7a             invalid
0x00047683      1000           shll r0h
0x00047685      407b           bra @@0x7b:8
0x00047687      720a           bclr #0x0:3,r2l
0x00047689      a001           cmp.b #0x1:8,r0h
0x0004768b      0069           nop
0x0004768d      0001           nop
0x0004768f      0069           nop
0x00047691      9040           addx #0x40:8,r0h
0x00047693      460c           bne @@0xc:8
0x00047695      e817           and #0x17:8,r0l
0x00047697      5079           mulxu r7h,r1
0x00047699      0800           add.b r0h,r0h
0x0004769b      3052           mov.b r0h,@0x52:8
0x0004769d      8001           add.b #0x1:8,r0h
0x0004769f      006f           nop
0x000476a1      f000           mov.b #0x0:8,r0h
0x000476a3      560c           rte
0x000476a5      6b175379       mov.w @0x5379:16,r7
0x000476a9      0b00           adds #1,r0
0x000476ab      0c52           mov.b r5h,r2h
0x000476ad      b37a           subx #0x7a:8,r3h
0x000476af      1000           shll r0h
0x000476b1      407b           bra @@0x7b:8
0x000476b3      f20a           mov.b #0xa:8,r2h
0x000476b5      b01a           subx #0x1a:8,r0h
0x000476b7      916e           addx #0x6e:8,r1h
0x000476b9      79006310       mov.w #0x6310:16,r0
0x000476bd      3110           mov.b r1h,@0x10:8
0x000476bf      310a           mov.b r1h,@0xa:8
0x000476c1      9001           addx #0x1:8,r0h
0x000476c3      006f           nop
0x000476c5      7200           bclr #0x0:3,r0h
0x000476c7      567a           rte
0x000476c9      1200           rotxl r0h
0x000476cb      407b           bra @@0x7b:8
0x000476cd      920a           addx #0xa:8,r2h
0x000476cf      b20a           subx #0xa:8,r2h
0x000476d1      9201           addx #0x1:8,r2h
0x000476d3      0069           nop
0x000476d5      2201           mov.b @0x1:8,r2h
0x000476d7      0069           nop
0x000476d9      826e           add.b #0x6e:8,r2h
0x000476db      78             invalid
0x000476dc      0063           nop
0x000476de      0a08           inc r0l
0x000476e0      6ef80063       mov.b r0l,@(0x63:16,r7)
0x000476e4      a803           cmp.b #0x3:8,r0l
0x000476e6      58             invalid
0x000476e7      50fd           mulxu r7l,r5
0x000476e9      306e           mov.b r0h,@0x6e:8
0x000476eb      78             invalid
0x000476ec      005f           nop
0x000476ee      0a08           inc r0l
0x000476f0      6ef8005f       mov.b r0l,@(0x5f:16,r7)
0x000476f4      6e79007d       mov.b @(0x7d:16,r7),r1l
0x000476f8      1c98           cmp.b r1l,r0l
0x000476fa      58             invalid
0x000476fb      50fb           mulxu r7l,r3
0x000476fd      e618           and #0x18:8,r6h
0x000476ff      335a           mov.b r3h,@0x5a:8
0x00047701      047a           orc #0x7a:8,ccr
0x00047703      be0c           subx #0xc:8,r6l
0x00047705      3817           mov.b r0l,@0x17:8
0x00047707      5017           mulxu r1h,r7
0x00047709      700a           bset #0x0:3,r2l
0x0004770b      c068           or #0x68:8,r0h
0x0004770d      066e           andc #0x6e:8,ccr
0x0004770f      78             invalid
0x00047710      0054           nop
0x00047712      a801           cmp.b #0x1:8,r0l
0x00047714      58             invalid
0x00047715      7001           bset #0x0:3,r1h
0x00047717      d618           xor #0x18:8,r6h
0x00047719      bb5a           subx #0x5a:8,r3l
0x0004771b      0478           orc #0x78:8,ccr
0x0004771d      e40c           and #0xc:8,r4h
0x0004771f      6817           mov.b @r1,r7h
0x00047721      5017           mulxu r1h,r7
0x00047723      7001           bset #0x0:3,r1h
0x00047725      006f           nop
0x00047727      f000           mov.b #0x0:8,r0h
0x00047729      5010           mulxu r1h,r0
0x0004772b      3010           mov.b r0h,@0x10:8
0x0004772d      300a           mov.b r0h,@0xa:8
0x0004772f      d001           xor #0x1:8,r0h
0x00047731      006f           nop
0x00047733      f000           mov.b #0x0:8,r0h
0x00047735      3001           mov.b r0h,@0x1:8
0x00047737      006f           nop
0x00047739      7000           bset #0x0:3,r0h
0x0004773b      507a           mulxu r7h,r2
0x0004773d      01000000       sleep
0x00047741      0c5e           mov.b r5h,r6l
0x00047743      0163ea0c       sleep
0x00047747      e917           and #0x17:8,r1l
0x00047749      5179           divxu r7h,r1
0x0004774b      0900           add.w r0,r0
0x0004774d      3052           mov.b r0h,@0x52:8
0x0004774f      917a           addx #0x7a:8,r1h
0x00047751      1100           shlr r0h
0x00047753      407b           bra @@0x7b:8
0x00047755      f20a           mov.b #0xa:8,r2h
0x00047757      810c           add.b #0xc:8,r1h
0x00047759      b817           subx #0x17:8,r0l
0x0004775b      5017           mulxu r1h,r7
0x0004775d      7010           bset #0x1:3,r0h
0x0004775f      3010           mov.b r0h,@0x10:8
0x00047761      300a           mov.b r0h,@0xa:8
0x00047763      8101           add.b #0x1:8,r1h
0x00047765      0069           nop
0x00047767      1101           shlr r1h
0x00047769      006f           nop
0x0004776b      7000           bset #0x0:3,r0h
0x0004776d      3001           mov.b r0h,@0x1:8
0x0004776f      0069           nop
0x00047771      8101           add.b #0x1:8,r1h
0x00047773      006f           nop
0x00047775      7000           bset #0x0:3,r0h
0x00047777      5078           mulxu r7h,r0
0x00047779      006a           nop
0x0004777b      2900           mov.b @0x0:8,r1l
0x0004777d      404e           bra @@0x4e:8
0x0004777f      5046           mulxu r4h,r6
0x00047781      380c           mov.b r0l,@0xc:8
0x00047783      6817           mov.b @r1,r7h
0x00047785      5017           mulxu r1h,r7
0x00047787      7010           bset #0x1:3,r0h
0x00047789      3010           mov.b r0h,@0x10:8
0x0004778b      3001           mov.b r0h,@0x1:8
0x0004778d      006f           nop
0x0004778f      f000           mov.b #0x0:8,r0h
0x00047791      3401           mov.b r4h,@0x1:8
0x00047793      006f           nop
0x00047795      7100           bnot #0x0:3,r0h
0x00047797      340a           mov.b r4h,@0xa:8
0x00047799      d101           xor #0x1:8,r1h
0x0004779b      0069           nop
0x0004779d      1101           shlr r1h
0x0004779f      006f           nop
0x000477a1      f000           mov.b #0x0:8,r0h
0x000477a3      287a           mov.b @0x7a:8,r0l
0x000477a5      0000           nop
0x000477a7      0000           nop
0x000477a9      2c0a           mov.b @0xa:8,r4l
0x000477ab      f05e           mov.b #0x5e:8,r0h
0x000477ad      01648001       sleep
0x000477b1      006b           nop
0x000477b3      2100           mov.b @0x0:8,r1h
0x000477b5      400f           bra @@0xf:8
0x000477b7      8440           add.b #0x40:8,r4h
0x000477b9      360c           mov.b r6h,@0xc:8
0x000477bb      6817           mov.b @r1,r7h
0x000477bd      5017           mulxu r1h,r7
0x000477bf      7010           bset #0x1:3,r0h
0x000477c1      3010           mov.b r0h,@0x10:8
0x000477c3      3001           mov.b r0h,@0x1:8
0x000477c5      006f           nop
0x000477c7      f000           mov.b #0x0:8,r0h
0x000477c9      3401           mov.b r4h,@0x1:8
0x000477cb      006f           nop
0x000477cd      7100           bnot #0x0:3,r0h
0x000477cf      340a           mov.b r4h,@0xa:8
0x000477d1      d101           xor #0x1:8,r1h
0x000477d3      0069           nop
0x000477d5      1101           shlr r1h
0x000477d7      006f           nop
0x000477d9      f000           mov.b #0x0:8,r0h
0x000477db      287a           mov.b @0x7a:8,r0l
0x000477dd      0000           nop
0x000477df      0000           nop
0x000477e1      2c0a           mov.b @0xa:8,r4l
0x000477e3      f05e           mov.b #0x5e:8,r0h
0x000477e5      01648001       sleep
0x000477e9      006b           nop
0x000477eb      2100           mov.b @0x0:8,r1h
0x000477ed      400f           bra @@0xf:8
0x000477ef      8801           add.b #0x1:8,r0l
0x000477f1      006f           nop
0x000477f3      f000           mov.b #0x0:8,r0h
0x000477f5      1c7a           cmp.b r7h,r2l
0x000477f7      0000           nop
0x000477f9      0000           nop
0x000477fb      200a           mov.b @0xa:8,r0h
0x000477fd      f05e           mov.b #0x5e:8,r0h
0x000477ff      015db401       sleep
0x00047803      006f           nop
0x00047805      7100           bnot #0x0:3,r0h
0x00047807      1c0f           cmp.b r0h,r7l
0x00047809      827a           add.b #0x7a:8,r2h
0x0004780b      0000           nop
0x0004780d      0000           nop
0x0004780f      140a           or r0h,r2l
0x00047811      f05e           mov.b #0x5e:8,r0h
0x00047813      0159a45e       sleep
0x00047817      015d2e01       sleep
0x0004781b      006f           nop
0x0004781d      7100           bnot #0x0:3,r0h
0x0004781f      2801           mov.b @0x1:8,r0l
0x00047821      0078           nop
0x00047823      906b           addx #0x6b:8,r0h
0x00047825      a000           cmp.b #0x0:8,r0h
0x00047827      407c           bra @@0x7c:8
0x00047829      627a           bclr r7h,r2l
0x0004782b      0100407c       sleep
0x0004782f      626e           bclr r6h,r6l
0x00047831      78             invalid
0x00047832      007d           nop
0x00047834      5e035e4a       jsr @0x5e4a:16
0x00047838      6aa60040       mov.b r6h,@0x40:16
0x0004783c      4e97           bgt @@0x97:8
0x0004783e      0cb0           mov.b r3l,r0h
0x00047840      1888           sub.b r0l,r0l
0x00047842      5c             invalid
0x00047843      00e8           nop
0x00047845      040c           orc #0xc:8,ccr
0x00047847      e817           and #0x17:8,r0l
0x00047849      5017           mulxu r1h,r7
0x0004784b      7001           bset #0x0:3,r1h
0x0004784d      006f           nop
0x0004784f      f000           mov.b #0x0:8,r0h
0x00047851      507a           mulxu r7h,r2
0x00047853      01000000       sleep
0x00047857      305e           mov.b r0h,@0x5e:8
0x00047859      0163ea0c       sleep
0x0004785d      6917           mov.w @r1,r7
0x0004785f      5117           divxu r1h,r7
0x00047861      710f           bnot #0x0:3,r7l
0x00047863      9201           addx #0x1:8,r2h
0x00047865      006f           nop
0x00047867      f000           mov.b #0x0:8,r0h
0x00047869      307a           mov.b r0h,@0x7a:8
0x0004786b      0000           nop
0x0004786d      0000           nop
0x0004786f      0c5e           mov.b r5h,r6l
0x00047871      0163ea01       sleep
0x00047875      006f           nop
0x00047877      7100           bnot #0x0:3,r0h
0x00047879      307a           mov.b r0h,@0x7a:8
0x0004787b      1100           shlr r0h
0x0004787d      4074           bra @@0x74:8
0x0004787f      e40a           and #0xa:8,r4h
0x00047881      810c           add.b #0xc:8,r1h
0x00047883      b817           subx #0x17:8,r0l
0x00047885      5017           mulxu r1h,r7
0x00047887      7001           bset #0x0:3,r1h
0x00047889      006f           nop
0x0004788b      f000           mov.b #0x0:8,r0h
0x0004788d      5a103010       jmp @0x3010:16
0x00047891      300a           mov.b r0h,@0xa:8
0x00047893      8101           add.b #0x1:8,r1h
0x00047895      006b           nop
0x00047897      2000           mov.b @0x0:8,r0h
0x00047899      4052           bra @@0x52:8
0x0004789b      c601           or #0x1:8,r6h
0x0004789d      0069           nop
0x0004789f      900f           addx #0xf:8,r0h
0x000478a1      a07a           cmp.b #0x7a:8,r0h
0x000478a3      01000000       sleep
0x000478a7      065e           andc #0x5e:8,ccr
0x000478a9      0163ea01       sleep
0x000478ad      006f           nop
0x000478af      f000           mov.b #0x0:8,r0h
0x000478b1      3001           mov.b r0h,@0x1:8
0x000478b3      006f           nop
0x000478b5      7000           bset #0x0:3,r0h
0x000478b7      507a           mulxu r7h,r2
0x000478b9      01000000       sleep
0x000478bd      185e           sub.b r5h,r6l
0x000478bf      0163ea7a       sleep
0x000478c3      1000           shll r0h
0x000478c5      4075           bra @@0x75:8
0x000478c7      c401           or #0x1:8,r4h
0x000478c9      006f           nop
0x000478cb      7100           bnot #0x0:3,r0h
0x000478cd      300a           mov.b r0h,@0xa:8
0x000478cf      9001           addx #0x1:8,r0h
0x000478d1      006f           nop
0x000478d3      7100           bnot #0x0:3,r0h
0x000478d5      5a10310a       jmp @0x310a:16
0x000478d9      906b           addx #0x6b:8,r0h
0x000478db      2100           mov.b @0x0:8,r1h
0x000478dd      404e           bra @@0x4e:8
0x000478df      58             invalid
0x000478e0      6981           mov.w r1,@r0
0x000478e2      0a0b           inc r3l
0x000478e4      ab03           cmp.b #0x3:8,r3l
0x000478e6      58             invalid
0x000478e7      50fe           mulxu r7l,r6
0x000478e9      345a           mov.b r4h,@0x5a:8
0x000478eb      047a           orc #0x7a:8,ccr
0x000478ed      bc6a           subx #0x6a:8,r4l
0x000478ef      2b00           mov.b @0x0:8,r3l
0x000478f1      4076           bra @@0x76:8
0x000478f3      270c           mov.b @0xc:8,r7h
0x000478f5      6817           mov.b @r1,r7h
0x000478f7      5017           mulxu r1h,r7
0x000478f9      7001           bset #0x0:3,r1h
0x000478fb      006f           nop
0x000478fd      f000           mov.b #0x0:8,r0h
0x000478ff      5010           mulxu r1h,r0
0x00047901      3010           mov.b r0h,@0x10:8
0x00047903      300a           mov.b r0h,@0xa:8
0x00047905      d001           xor #0x1:8,r0h
0x00047907      006f           nop
0x00047909      f000           mov.b #0x0:8,r0h
0x0004790b      3001           mov.b r0h,@0x1:8
0x0004790d      006f           nop
0x0004790f      7000           bset #0x0:3,r0h
0x00047911      507a           mulxu r7h,r2
0x00047913      01000000       sleep
0x00047917      0c5e           mov.b r5h,r6l
0x00047919      0163ea0c       sleep
0x0004791d      e917           and #0x17:8,r1l
0x0004791f      5179           divxu r7h,r1
0x00047921      0900           add.w r0,r0
0x00047923      3052           mov.b r0h,@0x52:8
0x00047925      917a           addx #0x7a:8,r1h
0x00047927      1100           shlr r0h
0x00047929      407b           bra @@0x7b:8
0x0004792b      f20a           mov.b #0xa:8,r2h
0x0004792d      810c           add.b #0xc:8,r1h
0x0004792f      b817           subx #0x17:8,r0l
0x00047931      5017           mulxu r1h,r7
0x00047933      7010           bset #0x1:3,r0h
0x00047935      3010           mov.b r0h,@0x10:8
0x00047937      300a           mov.b r0h,@0xa:8
0x00047939      8101           add.b #0x1:8,r1h
0x0004793b      0069           nop
0x0004793d      1101           shlr r1h
0x0004793f      006f           nop
0x00047941      7000           bset #0x0:3,r0h
0x00047943      3001           mov.b r0h,@0x1:8
0x00047945      0069           nop
0x00047947      8101           add.b #0x1:8,r1h
0x00047949      006f           nop
0x0004794b      7000           bset #0x0:3,r0h
0x0004794d      5078           mulxu r7h,r0
0x0004794f      006a           nop
0x00047951      2900           mov.b @0x0:8,r1l
0x00047953      404e           bra @@0x4e:8
0x00047955      5046           mulxu r4h,r6
0x00047957      380c           mov.b r0l,@0xc:8
0x00047959      6817           mov.b @r1,r7h
0x0004795b      5017           mulxu r1h,r7
0x0004795d      7010           bset #0x1:3,r0h
0x0004795f      3010           mov.b r0h,@0x10:8
0x00047961      3001           mov.b r0h,@0x1:8
0x00047963      006f           nop
0x00047965      f000           mov.b #0x0:8,r0h
0x00047967      3401           mov.b r4h,@0x1:8
0x00047969      006f           nop
0x0004796b      7100           bnot #0x0:3,r0h
0x0004796d      340a           mov.b r4h,@0xa:8
0x0004796f      d101           xor #0x1:8,r1h
0x00047971      0069           nop
0x00047973      1101           shlr r1h
0x00047975      006f           nop
0x00047977      f000           mov.b #0x0:8,r0h
0x00047979      287a           mov.b @0x7a:8,r0l
0x0004797b      0000           nop
0x0004797d      0000           nop
0x0004797f      2c0a           mov.b @0xa:8,r4l
0x00047981      f05e           mov.b #0x5e:8,r0h
0x00047983      01648001       sleep
0x00047987      006b           nop
0x00047989      2100           mov.b @0x0:8,r1h
0x0004798b      400f           bra @@0xf:8
0x0004798d      8440           add.b #0x40:8,r4h
0x0004798f      360c           mov.b r6h,@0xc:8
0x00047991      6817           mov.b @r1,r7h
0x00047993      5017           mulxu r1h,r7
0x00047995      7010           bset #0x1:3,r0h
0x00047997      3010           mov.b r0h,@0x10:8
0x00047999      3001           mov.b r0h,@0x1:8
0x0004799b      006f           nop
0x0004799d      f000           mov.b #0x0:8,r0h
0x0004799f      3401           mov.b r4h,@0x1:8
0x000479a1      006f           nop
0x000479a3      7100           bnot #0x0:3,r0h
0x000479a5      340a           mov.b r4h,@0xa:8
0x000479a7      d101           xor #0x1:8,r1h
0x000479a9      0069           nop
0x000479ab      1101           shlr r1h
0x000479ad      006f           nop
0x000479af      f000           mov.b #0x0:8,r0h
0x000479b1      287a           mov.b @0x7a:8,r0l
0x000479b3      0000           nop
0x000479b5      0000           nop
0x000479b7      2c0a           mov.b @0xa:8,r4l
0x000479b9      f05e           mov.b #0x5e:8,r0h
0x000479bb      01648001       sleep
0x000479bf      006b           nop
0x000479c1      2100           mov.b @0x0:8,r1h
0x000479c3      400f           bra @@0xf:8
0x000479c5      8801           add.b #0x1:8,r0l
0x000479c7      006f           nop
0x000479c9      f000           mov.b #0x0:8,r0h
0x000479cb      1c7a           cmp.b r7h,r2l
0x000479cd      0000           nop
0x000479cf      0000           nop
0x000479d1      200a           mov.b @0xa:8,r0h
0x000479d3      f05e           mov.b #0x5e:8,r0h
0x000479d5      015db401       sleep
0x000479d9      006f           nop
0x000479db      7100           bnot #0x0:3,r0h
0x000479dd      1c0f           cmp.b r0h,r7l
0x000479df      827a           add.b #0x7a:8,r2h
0x000479e1      0000           nop
0x000479e3      0000           nop
0x000479e5      140a           or r0h,r2l
0x000479e7      f05e           mov.b #0x5e:8,r0h
0x000479e9      0159a45e       sleep
0x000479ed      015d2e01       sleep
0x000479f1      006f           nop
0x000479f3      7100           bnot #0x0:3,r0h
0x000479f5      2801           mov.b @0x1:8,r0l
0x000479f7      0078           nop
0x000479f9      906b           addx #0x6b:8,r0h
0x000479fb      a000           cmp.b #0x0:8,r0h
0x000479fd      407c           bra @@0x7c:8
0x000479ff      627a           bclr r7h,r2l
0x00047a01      0100407c       sleep
0x00047a05      626e           bclr r6h,r6l
0x00047a07      78             invalid
0x00047a08      007d           nop
0x00047a0a      5e035e4a       jsr @0x5e4a:16
0x00047a0e      6aa60040       mov.b r6h,@0x40:16
0x00047a12      4e97           bgt @@0x97:8
0x00047a14      0cb0           mov.b r3l,r0h
0x00047a16      1888           sub.b r0l,r0l
0x00047a18      5c             invalid
0x00047a19      00e6           nop
0x00047a1b      2e0c           mov.b @0xc:8,r6l
0x00047a1d      e817           and #0x17:8,r0l
0x00047a1f      5017           mulxu r1h,r7
0x00047a21      7001           bset #0x0:3,r1h
0x00047a23      006f           nop
0x00047a25      f000           mov.b #0x0:8,r0h
0x00047a27      407a           bra @@0x7a:8
0x00047a29      01000000       sleep
0x00047a2d      305e           mov.b r0h,@0x5e:8
0x00047a2f      0163ea1a       sleep
0x00047a33      910c           addx #0xc:8,r1h
0x00047a35      6901           mov.w @r0,r1
0x00047a37      006f           nop
0x00047a39      f100           mov.b #0x0:8,r1h
0x00047a3b      3c01           mov.b r4l,@0x1:8
0x00047a3d      006f           nop
0x00047a3f      f000           mov.b #0x0:8,r0h
0x00047a41      307a           mov.b r0h,@0x7a:8
0x00047a43      0000           nop
0x00047a45      0000           nop
0x00047a47      0c5e           mov.b r5h,r6l
0x00047a49      0163ea01       sleep
0x00047a4d      006f           nop
0x00047a4f      7100           bnot #0x0:3,r0h
0x00047a51      307a           mov.b r0h,@0x7a:8
0x00047a53      1100           shlr r0h
0x00047a55      4074           bra @@0x74:8
0x00047a57      e40a           and #0xa:8,r4h
0x00047a59      811a           add.b #0x1a:8,r1h
0x00047a5b      800c           add.b #0xc:8,r0h
0x00047a5d      b801           subx #0x1:8,r0l
0x00047a5f      006f           nop
0x00047a61      f000           mov.b #0x0:8,r0h
0x00047a63      5a103010       jmp @0x3010:16
0x00047a67      300a           mov.b r0h,@0xa:8
0x00047a69      8101           add.b #0x1:8,r1h
0x00047a6b      006b           nop
0x00047a6d      2000           mov.b @0x0:8,r0h
0x00047a6f      4052           bra @@0x52:8
0x00047a71      c601           or #0x1:8,r6h
0x00047a73      0069           nop
0x00047a75      9001           addx #0x1:8,r0h
0x00047a77      006f           nop
0x00047a79      7000           bset #0x0:3,r0h
0x00047a7b      3c7a           mov.b r4l,@0x7a:8
0x00047a7d      01000000       sleep
0x00047a81      065e           andc #0x5e:8,ccr
0x00047a83      0163ea01       sleep
0x00047a87      006f           nop
0x00047a89      f000           mov.b #0x0:8,r0h
0x00047a8b      3001           mov.b r0h,@0x1:8
0x00047a8d      006f           nop
0x00047a8f      7000           bset #0x0:3,r0h
0x00047a91      407a           bra @@0x7a:8
0x00047a93      01000000       sleep
0x00047a97      185e           sub.b r5h,r6l
0x00047a99      0163ea7a       sleep
0x00047a9d      1000           shll r0h
0x00047a9f      4075           bra @@0x75:8
0x00047aa1      c401           or #0x1:8,r4h
0x00047aa3      006f           nop
0x00047aa5      7100           bnot #0x0:3,r0h
0x00047aa7      300a           mov.b r0h,@0xa:8
0x00047aa9      9001           addx #0x1:8,r0h
0x00047aab      006f           nop
0x00047aad      7100           bnot #0x0:3,r0h
0x00047aaf      5a10310a       jmp @0x310a:16
0x00047ab3      906b           addx #0x6b:8,r0h
0x00047ab5      2100           mov.b @0x0:8,r1h
0x00047ab7      404e           bra @@0x4e:8
0x00047ab9      58             invalid
0x00047aba      6981           mov.w r1,@r0
0x00047abc      0a03           inc r3h
0x00047abe      6e78007d       mov.b @(0x7d:16,r7),r0l
0x00047ac2      1c83           cmp.b r0l,r3h
0x00047ac4      58             invalid
0x00047ac5      50fc           mulxu r7l,r4
0x00047ac7      3c6f           mov.b r4l,@0x6f:8
0x00047ac9      7000           bset #0x0:3,r0h
0x00047acb      606f           bset r6h,r7l
0x00047acd      7100           bnot #0x0:3,r0h
0x00047acf      3a09           mov.b r2l,@0x9:8
0x00047ad1      106f           shal r7l
0x00047ad3      f000           mov.b #0x0:8,r0h
0x00047ad5      600f           bset r0h,r7l
0x00047ad7      d05e           xor #0x5e:8,r0h
0x00047ad9      039c           ldc r4l,ccr
0x00047adb      8a0a           add.b #0xa:8,r2l
0x00047add      0e6e           addx r6h,r6l
0x00047adf      78             invalid
0x00047ae0      0055           nop
0x00047ae2      1c8e           cmp.b r0l,r6l
0x00047ae4      58             invalid
0x00047ae5      50f7           mulxu r7l,r7
0x00047ae7      687a           mov.b @r7,r2l
0x00047ae9      1700           not r0h
0x00047aeb      0000           nop
0x00047aed      64             invalid
0x00047aee      5e016436       jsr @0x6436:16
0x00047af2      5470           rts
0x00047af4      5e016458       jsr @0x6458:16
0x00047af8      7a             invalid
0x00047af9      3700           mov.b r7h,@0x0:8
0x00047afb      0000           nop
0x00047afd      3a7a           mov.b r2l,@0x7a:8
0x00047aff      0500           xorc #0x0:8,ccr
0x00047b01      4076           bra @@0x76:8
0x00047b03      276f           mov.b @0x6f:8,r7h
0x00047b05      f000           mov.b #0x0:8,r0h
0x00047b07      1c6e           cmp.b r6h,r6l
0x00047b09      f900           mov.b #0x0:8,r1l
0x00047b0b      1f6e           das r6l
0x00047b0d      f100           mov.b #0x0:8,r1h
0x00047b0f      1e79           subx r7h,r1l
0x00047b11      02ff           stc ccr,r7l
0x00047b13      ff6f           mov.b #0x6f:8,r7l
0x00047b15      f200           mov.b #0x0:8,r2h
0x00047b17      36fa           mov.b r6h,@0xfa:8
0x00047b19      ff6a           mov.b #0x6a:8,r7l
0x00047b1b      aa00           cmp.b #0x0:8,r2l
0x00047b1d      4076           bra @@0x76:8
0x00047b1f      2618           mov.b @0x18:8,r6h
0x00047b21      aa6e           cmp.b #0x6e:8,r2l
0x00047b23      fa00           mov.b #0x0:8,r2l
0x00047b25      395a           mov.b r1l,@0x5a:8
0x00047b27      047c           orc #0x7c:8,ccr
0x00047b29      5a18886e       jmp @0x886e:16
0x00047b2d      f800           mov.b #0x0:8,r0l
0x00047b2f      386e           mov.b r0l,@0x6e:8
0x00047b31      78             invalid
0x00047b32      0039           nop
0x00047b34      1750           neg r0h
0x00047b36      0d06           mov.w r0,r6
0x00047b38      79080018       mov.w #0x18:16,r0
0x00047b3c      52             invalid
0x00047b3d      800f           add.b #0xf:8,r0h
0x00047b3f      830d           add.b #0xd:8,r3h
0x00047b41      6079           bset r7h,r1l
0x00047b43      0800           add.b r0h,r0h
0x00047b45      3052           mov.b r0h,@0x52:8
0x00047b47      807a           add.b #0x7a:8,r0h
0x00047b49      1000           shll r0h
0x00047b4b      4074           bra @@0x74:8
0x00047b4d      e401           and #0x1:8,r4h
0x00047b4f      006f           nop
0x00047b51      f000           mov.b #0x0:8,r0h
0x00047b53      205a           mov.b @0x5a:8,r0h
0x00047b55      047c           orc #0x7c:8,ccr
0x00047b57      421a           bhi @@0x1a:8
0x00047b59      806e           add.b #0x6e:8,r0h
0x00047b5b      78             invalid
0x00047b5c      0038           nop
0x00047b5e      78             invalid
0x00047b5f      006a           nop
0x00047b61      2600           mov.b @0x0:8,r6h
0x00047b63      400f           bra @@0xf:8
0x00047b65      5618           rte
0x00047b67      ee0c           and #0xc:8,r6l
0x00047b69      6817           mov.b @r1,r7h
0x00047b6b      500d           mulxu r0h,r5
0x00047b6d      0e79           addx r7h,r1l
0x00047b6f      0800           add.b r0h,r0h
0x00047b71      0652           andc #0x52:8,ccr
0x00047b73      800f           add.b #0xf:8,r0h
0x00047b75      840d           add.b #0xd:8,r4h
0x00047b77      e079           and #0x79:8,r0h
0x00047b79      0800           add.b r0h,r0h
0x00047b7b      0c52           mov.b r5h,r2h
0x00047b7d      8001           add.b #0x1:8,r0h
0x00047b7f      006f           nop
0x00047b81      7100           bnot #0x0:3,r0h
0x00047b83      200a           mov.b @0xa:8,r0h
0x00047b85      8101           add.b #0x1:8,r1h
0x00047b87      006f           nop
0x00047b89      f100           mov.b #0x0:8,r1h
0x00047b8b      2e5a           mov.b @0x5a:8,r6l
0x00047b8d      047c           orc #0x7c:8,ccr
0x00047b8f      2e7a           mov.b @0x7a:8,r6l
0x00047b91      0000           nop
0x00047b93      4075           bra @@0x75:8
0x00047b95      c40a           or #0xa:8,r4h
0x00047b97      b00a           subx #0xa:8,r0h
0x00047b99      c00c           or #0xc:8,r0h
0x00047b9b      e917           and #0x17:8,r1l
0x00047b9d      510d           divxu r0h,r5
0x00047b9f      1e68           subx r6h,r0l
0x00047ba1      5a175209       jmp @0x5209:16
0x00047ba5      1217           rotl r7h
0x00047ba7      f210           mov.b #0x10:8,r2h
0x00047ba9      320a           mov.b r2h,@0xa:8
0x00047bab      a069           cmp.b #0x69:8,r0h
0x00047bad      006b           nop
0x00047baf      a000           cmp.b #0x0:8,r0h
0x00047bb1      4076           bra @@0x76:8
0x00047bb3      240c           mov.b @0xc:8,r4h
0x00047bb5      695c           mov.w @r5,r4
0x00047bb7      0002           nop
0x00047bb9      0a0f           inc r7l
0x00047bbb      827a           add.b #0x7a:8,r2h
0x00047bbd      0000           nop
0x00047bbf      4075           bra @@0x75:8
0x00047bc1      f40a           mov.b #0xa:8,r4h
0x00047bc3      b00a           subx #0xa:8,r0h
0x00047bc5      c068           or #0x68:8,r0h
0x00047bc7      5917           jmp @r1
0x00047bc9      5109           divxu r0h,r1
0x00047bcb      1e0d           subx r0h,r5l
0x00047bcd      e117           and #0x17:8,r1h
0x00047bcf      f110           mov.b #0x10:8,r1h
0x00047bd1      310a           mov.b r1h,@0xa:8
0x00047bd3      9069           addx #0x69:8,r0h
0x00047bd5      0e6f           addx r6h,r7l
0x00047bd7      7000           bset #0x0:3,r0h
0x00047bd9      361d           mov.b r6h,@0x1d:8
0x00047bdb      0e44           addx r4h,r4h
0x00047bdd      426f           bhi @@0x6f:8
0x00047bdf      fe00           mov.b #0x0:8,r6l
0x00047be1      3668           mov.b r6h,@0x68:8
0x00047be3      58             invalid
0x00047be4      1750           neg r0h
0x00047be6      0ce9           mov.b r6l,r1l
0x00047be8      1751           neg r1h
0x00047bea      0910           add.w r1,r0
0x00047bec      17f0           neg r0h
0x00047bee      1030           shal r0h
0x00047bf0      1030           shal r0h
0x00047bf2      01006f71       sleep
0x00047bf6      002e           nop
0x00047bf8      0a81           inc r1h
0x00047bfa      01006910       sleep
0x00047bfe      01006ff0       sleep
0x00047c02      0024           nop
0x00047c04      6e780039       mov.b @(0x39:16,r7),r0l
0x00047c08      6ef8002d       mov.b r0l,@(0x2d:16,r7)
0x00047c0c      6858           mov.b @r5,r0l
0x00047c0e      08e8           add.b r6l,r0l
0x00047c10      6ef8002c       mov.b r0l,@(0x2c:16,r7)
0x00047c14      01006ff2       sleep
0x00047c18      0028           nop
0x00047c1a      6aa600         mov.b r6h,@0x10:16
0x00047c1e      7626           band #0x2:3,r6h
0x00047c20      6b200040       mov.w @0x40:16,r0
0x00047c24      0776           ldc #0x76:8,ccr
0x00047c26      7370           btst #0x7:3,r0h
0x00047c28      58             invalid
0x00047c29      6001           bset r0h,r1h
0x00047c2b      8c0a           add.b #0xa:8,r4l
0x00047c2d      0e6e           addx r6h,r6l
0x00047c2f      78             invalid
0x00047c30      001f           nop
0x00047c32      1c8e           cmp.b r0l,r6l
0x00047c34      58             invalid
0x00047c35      50ff           mulxu r7l,r7
0x00047c37      58             invalid
0x00047c38      6e780038       mov.b @(0x38:16,r7),r0l
0x00047c3c      0a08           inc r0l
0x00047c3e      6ef80038       mov.b r0l,@(0x38:16,r7)
0x00047c42      6e780038       mov.b @(0x38:16,r7),r0l
0x00047c46      6e790053       mov.b @(0x53:16,r7),r1l
0x00047c4a      1c98           cmp.b r1l,r0l
0x00047c4c      58             invalid
0x00047c4d      50ff           mulxu r7l,r7
0x00047c4f      086e           add.b r6h,r6l
0x00047c51      78             invalid
0x00047c52      0039           nop
0x00047c54      0a08           inc r0l
0x00047c56      6ef80039       mov.b r0l,@(0x39:16,r7)
0x00047c5a      6e780039       mov.b @(0x39:16,r7),r0l
0x00047c5e      6e79001e       mov.b @(0x1e:16,r7),r1l
0x00047c62      1c98           cmp.b r1l,r0l
0x00047c64      58             invalid
0x00047c65      50fe           mulxu r7l,r6
0x00047c67      c26a           or #0x6a:8,r2h
0x00047c69      2800           mov.b @0x0:8,r0l
0x00047c6b      4076           bra @@0x76:8
0x00047c6d      26a8           mov.b @0xa8:8,r6h
0x00047c6f      ff58           mov.b #0x58:8,r7l
0x00047c71      7001           bset #0x0:3,r1h
0x00047c73      446e           bcc @@0x6e:8
0x00047c75      78             invalid
0x00047c76      002c           nop
0x00047c78      68d8           mov.b r0l,@r5
0x00047c7a      01006f70       sleep
0x00047c7e      0024           nop
0x00047c80      01006ba0       sleep
0x00047c84      0040           nop
0x00047c86      7b6a0100       eepmov
0x00047c8a      6f700028       mov.w @(0x28:16,r7),r0
0x00047c8e      01006ba0       sleep
0x00047c92      0040           nop
0x00047c94      762a           band #0x2:3,r2l
0x00047c96      7a             invalid
0x00047c97      0600           andc #0x0:8,ccr
0x00047c99      4052           bra @@0x52:8
0x00047c9b      a61a           cmp.b #0x1a:8,r6h
0x00047c9d      c46a           or #0x6a:8,r4h
0x00047c9f      2c00           mov.b @0x0:8,r4l
0x00047ca1      4076           bra @@0x76:8
0x00047ca3      260f           mov.b @0xf:8,r6h
0x00047ca5      c010           or #0x10:8,r0h
0x00047ca7      3010           mov.b r0h,@0x10:8
0x00047ca9      300a           mov.b r0h,@0xa:8
0x00047cab      e001           and #0x1:8,r0h
0x00047cad      006f           nop
0x00047caf      f000           mov.b #0x0:8,r0h
0x00047cb1      180f           sub.b r0h,r7l
0x00047cb3      c07a           or #0x7a:8,r0h
0x00047cb5      01000000       sleep
0x00047cb9      0c5e           mov.b r5h,r6l
0x00047cbb      0163ea6e       sleep
0x00047cbf      79002d17       mov.w #0x2d17:16,r0
0x00047cc3      5179           divxu r7h,r1
0x00047cc5      0900           add.w r0,r0
0x00047cc7      3052           mov.b r0h,@0x52:8
0x00047cc9      917a           addx #0x7a:8,r1h
0x00047ccb      1100           shlr r0h
0x00047ccd      407b           bra @@0x7b:8
0x00047ccf      f20a           mov.b #0xa:8,r2h
0x00047cd1      811a           add.b #0x1a:8,r1h
0x00047cd3      806e           add.b #0x6e:8,r0h
0x00047cd5      78             invalid
0x00047cd6      002c           nop
0x00047cd8      1030           shal r0h
0x00047cda      1030           shal r0h
0x00047cdc      0a81           inc r1h
0x00047cde      01006911       sleep
0x00047ce2      01006f70       sleep
0x00047ce6      0018           nop
0x00047ce8      01006981       sleep
0x00047cec      0fe0           daa r0h
0x00047cee      5e039c8a       jsr @0x9c8a:16
0x00047cf2      1a80           dec r0h
0x00047cf4      6a280040       mov.b @0x40:16,r0l
0x00047cf8      7626           band #0x2:3,r6h
0x00047cfa      78             invalid
0x00047cfb      006a           nop
0x00047cfd      2900           mov.b @0x0:8,r1l
0x00047cff      404e           bra @@0x4e:8
0x00047d01      5046           mulxu r4h,r6
0x00047d03      281a           mov.b @0x1a:8,r0l
0x00047d05      c46a           or #0x6a:8,r4h
0x00047d07      2c00           mov.b @0x0:8,r4l
0x00047d09      4076           bra @@0x76:8
0x00047d0b      2610           mov.b @0x10:8,r6h
0x00047d0d      3410           mov.b r4h,@0x10:8
0x00047d0f      340a           mov.b r4h,@0xa:8
0x00047d11      c601           or #0x1:8,r6h
0x00047d13      0069           nop
0x00047d15      617a           bnot r7h,r2l
0x00047d17      0000           nop
0x00047d19      0000           nop
0x00047d1b      140a           or r0h,r2l
0x00047d1d      f0             mov.b #0x10:8,r0h
0x00047d1f      01648001       sleep
0x00047d23      006b           nop
0x00047d25      2100           mov.b @0x0:8,r1h
0x00047d27      400f           bra @@0xf:8
0x00047d29      8440           add.b #0x40:8,r4h
0x00047d2b      261a           mov.b @0x1a:8,r6h
0x00047d2d      c46a           or #0x6a:8,r4h
0x00047d2f      2c00           mov.b @0x0:8,r4l
0x00047d31      4076           bra @@0x76:8
0x00047d33      2610           mov.b @0x10:8,r6h
0x00047d35      3410           mov.b r4h,@0x10:8
0x00047d37      340a           mov.b r4h,@0xa:8
0x00047d39      c601           or #0x1:8,r6h
0x00047d3b      0069           nop
0x00047d3d      617a           bnot r7h,r2l
0x00047d3f      0000           nop
0x00047d41      0000           nop
0x00047d43      140a           or r0h,r2l
0x00047d45      f05e           mov.b #0x5e:8,r0h
0x00047d47      01648001       sleep
0x00047d4b      006b           nop
0x00047d4d      2100           mov.b @0x0:8,r1h
0x00047d4f      400f           bra @@0xf:8
0x00047d51      8801           add.b #0x1:8,r0l
0x00047d53      006f           nop
0x00047d55      f000           mov.b #0x0:8,r0h
0x00047d57      087a           add.b r7h,r2l
0x00047d59      0000           nop
0x00047d5b      0000           nop
0x00047d5d      0c0a           mov.b r0h,r2l
0x00047d5f      f05e           mov.b #0x5e:8,r0h
0x00047d61      015db401       sleep
0x00047d65      006f           nop
0x00047d67      7100           bnot #0x0:3,r0h
0x00047d69      080f           add.b r0h,r7l
0x00047d6b      820f           add.b #0xf:8,r2h
0x00047d6d      f05e           mov.b #0x5e:8,r0h
0x00047d6f      0159a45e       sleep
0x00047d73      015d2e01       sleep
0x00047d77      0078           nop
0x00047d79      c06b           or #0x6b:8,r0h
0x00047d7b      a000           cmp.b #0x0:8,r0h
0x00047d7d      4052           bra @@0x52:8
0x00047d7f      b66e           subx #0x6e:8,r6h
0x00047d81      78             invalid
0x00047d82      002d           nop
0x00047d84      f0c8           mov.b #0xc8:8,r0h
0x00047d86      5000           mulxu r0h,r0
0x00047d88      6f76001c       mov.w @(0x1c:16,r7),r6
0x00047d8c      1906           sub.w r0,r6
0x00047d8e      6b200040       mov.w @0x40:16,r0
0x00047d92      52             invalid
0x00047d93      d41d           xor #0x1d:8,r4h
0x00047d95      0647           andc #0x47:8,ccr
0x00047d97      2018           mov.b @0x18:8,r0h
0x00047d99      886d           add.b #0x6d:8,r0l
0x00047d9b      f06b           mov.b #0x6b:8,r0h
0x00047d9d      2100           mov.b @0x0:8,r1h
0x00047d9f      400c           bra @@0xc:8
0x00047da1      c879           or #0x79:8,r0l
0x00047da3      0903           add.w r0,r3
0x00047da5      e852           and #0x52:8,r0l
0x00047da7      910d           addx #0xd:8,r1h
0x00047da9      605e           bset r5h,r6l
0x00047dab      02d7           stc ccr,r7h
0x00047dad      ae0b           cmp.b #0xb:8,r6l
0x00047daf      875e           add.b #0x5e:8,r7h
0x00047db1      02d5           stc ccr,r5h
0x00047db3      980c           addx #0xc:8,r0l
0x00047db5      8847           add.b #0x47:8,r0l
0x00047db7      e07a           and #0x7a:8,r0h
0x00047db9      1700           not r0h
0x00047dbb      0000           nop
0x00047dbd      3a5e           mov.b r2l,@0x5e:8
0x00047dbf      01643654       sleep
0x00047dc3      705e           bset #0x5:3,r6l
0x00047dc5      0164587a       sleep
0x00047dc9      3700           mov.b r7h,@0x0:8
0x00047dcb      0000           nop
0x00047dcd      240d           mov.b @0xd:8,r4h
0x00047dcf      090c           add.w r0,r4
0x00047dd1      9c7a           addx #0x7a:8,r4l
0x00047dd3      0600           andc #0x0:8,ccr
0x00047dd5      04a5           orc #0xa5:8,ccr
0x00047dd7      9840           addx #0x40:8,r0l
0x00047dd9      0c69           mov.b r6h,r1l
0x00047ddb      601d           bset r1h,r5l
0x00047ddd      9043           addx #0x43:8,r0h
0x00047ddf      0e7a           addx r7h,r2l
0x00047de1      1600           and r0h,r0h
0x00047de3      0000           nop
0x00047de5      0a69           inc r1l
0x00047de7      6079           bset r7h,r1l
0x00047de9      20ff           mov.b @0xff:8,r0h
0x00047deb      ff46           mov.b #0x46:8,r7l
0x00047ded      ec01           and #0x1:8,r4l
0x00047def      006b           nop
0x00047df1      2100           mov.b @0x0:8,r1h
0x00047df3      4052           bra @@0x52:8
0x00047df5      ca7a           or #0x7a:8,r2l
0x00047df7      0000           nop
0x00047df9      0000           nop
0x00047dfb      1c0a           cmp.b r0h,r2l
0x00047dfd      f05e           mov.b #0x5e:8,r0h
0x00047dff      0164800f       sleep
0x00047e03      817a           add.b #0x7a:8,r1h
0x00047e05      0200           stc ccr,r0h
0x00047e07      0000           nop
0x00047e09      020a           stc ccr,r2l
0x00047e0b      e27a           and #0x7a:8,r2h
0x00047e0d      0000           nop
0x00047e0f      0000           nop
0x00047e11      140a           or r0h,r2l
0x00047e13      f05e           mov.b #0x5e:8,r0h
0x00047e15      01603017       sleep
0x00047e19      5417           rts
0x00047e1b      7410           bor #0x1:3,r0h
0x00047e1d      3410           mov.b r4h,@0x10:8
0x00047e1f      3401           mov.b r4h,@0x1:8
0x00047e21      0078           nop
0x00047e23      406b           bra @@0x6b:8
0x00047e25      2100           mov.b @0x0:8,r1h
0x00047e27      04a5           orc #0xa5:8,ccr
0x00047e29      fc01           mov.b #0x1:8,r4l
0x00047e2b      006f           nop
0x00047e2d      f000           mov.b #0x0:8,r0h
0x00047e2f      087a           add.b r7h,r2l
0x00047e31      0000           nop
0x00047e33      0000           nop
0x00047e35      0c0a           mov.b r0h,r2l
0x00047e37      f05e           mov.b #0x5e:8,r0h
0x00047e39      01648001       sleep
0x00047e3d      006f           nop
0x00047e3f      7100           bnot #0x0:3,r0h
0x00047e41      080f           add.b r0h,r7l
0x00047e43      820f           add.b #0xf:8,r2h
0x00047e45      f05e           mov.b #0x5e:8,r0h
0x00047e47      0155185e       sleep
0x00047e4b      015d2e0f       sleep
0x00047e4f      867a           add.b #0x7a:8,r6h
0x00047e51      1700           not r0h
0x00047e53      0000           nop
0x00047e55      245e           mov.b @0x5e:8,r4h
0x00047e57      01643654       sleep
0x00047e5b      705e           bset #0x5:3,r6l
0x00047e5d      0164587a       sleep
0x00047e61      0300           ldc r0h,ccr
0x00047e63      407c           bra @@0x7c:8
0x00047e65      aa7a           cmp.b #0x7a:8,r2l
0x00047e67      0400           orc #0x0:8,ccr
0x00047e69      407c           bra @@0x7c:8
0x00047e6b      b37a           subx #0x7a:8,r3h
0x00047e6d      0500           xorc #0x0:8,ccr
0x00047e6f      407c           bra @@0x7c:8
0x00047e71      b27a           subx #0x7a:8,r2h
0x00047e73      0600           andc #0x0:8,ccr
0x00047e75      407c           bra @@0x7c:8
0x00047e77      aef8           cmp.b #0xf8:8,r6l
0x00047e79      016aa800       sleep
0x00047e7d      400e           bra @@0xe:8
0x00047e7f      926a           addx #0x6a:8,r2h
0x00047e81      2800           mov.b @0x0:8,r0l
0x00047e83      407c           bra @@0x7c:8
0x00047e85      b646           subx #0x46:8,r6h
0x00047e87      08f8           add.b r7l,r0l
0x00047e89      016aa800       sleep
0x00047e8d      407c           bra @@0x7c:8
0x00047e8f      b65c           subx #0x5c:8,r6h
0x00047e91      0001           nop
0x00047e93      4e6a           bgt @@0x6a:8
0x00047e95      2800           mov.b @0x0:8,r0l
0x00047e97      407c           bra @@0x7c:8
0x00047e99      b6a8           subx #0xa8:8,r6h
0x00047e9b      0458           orc #0x58:8,ccr
0x00047e9d      6001           bset r0h,r1h
0x00047e9f      3c18           mov.b r4l,@0x18:8
0x00047ea1      886a           add.b #0x6a:8,r0l
0x00047ea3      a800           cmp.b #0x0:8,r0l
0x00047ea5      407c           bra @@0x7c:8
0x00047ea7      b66a           subx #0x6a:8,r6h
0x00047ea9      2800           mov.b @0x0:8,r0l
0x00047eab      407c           bra @@0x7c:8
0x00047ead      b547           subx #0x47:8,r5h
0x00047eaf      0a6a           inc r2l
0x00047eb1      2800           mov.b @0x0:8,r0l
0x00047eb3      4062           bra @@0x62:8
0x00047eb5      f8a8           mov.b #0xa8:8,r0l
0x00047eb7      0146206a       sleep
0x00047ebb      2800           mov.b @0x0:8,r0l
0x00047ebd      2000           mov.b @0x0:8,r0h
0x00047ebf      4173           brn @@0x73:8
0x00047ec1      0847           add.b r4h,r7h
0x00047ec3      0c7a           mov.b r7h,r2l
0x00047ec5      0000           nop
0x00047ec7      4062           bra @@0x62:8
0x00047ec9      f87d           mov.b #0x7d:8,r0l
0x00047ecb      0072           nop
0x00047ecd      2040           mov.b @0x40:8,r0h
0x00047ecf      0a7a           inc r2l
0x00047ed1      0000           nop
0x00047ed3      4062           bra @@0x62:8
0x00047ed5      f87d           mov.b #0x7d:8,r0l
0x00047ed7      0070           nop
0x00047ed9      207a           mov.b @0x7a:8,r0h
0x00047edb      0000           nop
0x00047edd      04a7           orc #0xa7:8,ccr
0x00047edf      8c40           add.b #0x40:8,r4l
0x00047ee1      1a01           dec r1h
0x00047ee3      0069           nop
0x00047ee5      3068           mov.b r0h,@0x68:8
0x00047ee7      086a           add.b r6h,r2l
0x00047ee9      2900           mov.b @0x0:8,r1l
0x00047eeb      4062           bra @@0x62:8
0x00047eed      f81c           mov.b #0x1c:8,r0l
0x00047eef      9847           addx #0x47:8,r0l
0x00047ef1      1201           rotxl r1h
0x00047ef3      0069           nop
0x00047ef5      307a           mov.b r0h,@0x7a:8
0x00047ef7      1000           shll r0h
0x00047ef9      0000           nop
0x00047efb      0a01           inc r1h
0x00047efd      0069           nop
0x00047eff      b068           subx #0x68:8,r0h
0x00047f01      0946           add.w r4,r6
0x00047f03      de01           xor #0x1:8,r6l
0x00047f05      0069           nop
0x00047f07      3068           mov.b r0h,@0x68:8
0x00047f09      0958           add.w r5,r0
0x00047f0b      7000           bset #0x0:3,r0h
0x00047f0d      c6f8           or #0xf8:8,r6h
0x00047f0f      0168d818       sleep
0x00047f13      8868           add.b #0x68:8,r0l
0x00047f15      c801           or #0x1:8,r0l
0x00047f17      0069           nop
0x00047f19      3001           mov.b r0h,@0x1:8
0x00047f1b      006f           nop
0x00047f1d      0000           nop
0x00047f1f      0640           andc #0x40:8,ccr
0x00047f21      2801           mov.b @0x1:8,r0l
0x00047f23      0069           nop
0x00047f25      6068           bset r6h,r0l
0x00047f27      0868           add.b r6h,r0l
0x00047f29      591c           jmp @r1
0x00047f2b      9846           addx #0x46:8,r0l
0x00047f2d      1201           rotxl r1h
0x00047f2f      0069           nop
0x00047f31      606e           bset r6h,r6l
0x00047f33      0800           add.b r0h,r0h
0x00047f35      016a2900       sleep
0x00047f39      407c           bra @@0x7c:8
0x00047f3b      b31c           subx #0x1c:8,r3h
0x00047f3d      9847           addx #0x47:8,r0l
0x00047f3f      1201           rotxl r1h
0x00047f41      0069           nop
0x00047f43      607a           bset r7h,r2l
0x00047f45      1000           shll r0h
0x00047f47      0000           nop
0x00047f49      0a01           inc r1h
0x00047f4b      0069           nop
0x00047f4d      e068           and #0x68:8,r0h
0x00047f4f      0946           add.w r4,r6
0x00047f51      d001           xor #0x1:8,r0h
0x00047f53      0069           nop
0x00047f55      6068           bset r6h,r0l
0x00047f57      0947           add.w r4,r7
0x00047f59      0c01           mov.b r0h,r1h
0x00047f5b      0069           nop
0x00047f5d      3001           mov.b r0h,@0x1:8
0x00047f5f      006f           nop
0x00047f61      0000           nop
0x00047f63      025d           stc ccr,r5l
0x00047f65      006a           nop
0x00047f67      2800           mov.b @0x0:8,r0l
0x00047f69      407c           bra @@0x7c:8
0x00047f6b      b5a8           subx #0xa8:8,r5h
0x00047f6d      01475a55       sleep
0x00047f71      706a           bset #0x6:3,r2l
0x00047f73      2800           mov.b @0x0:8,r0l
0x00047f75      407c           bra @@0x7c:8
0x00047f77      b6a8           subx #0xa8:8,r6h
0x00047f79      0446           orc #0x46:8,ccr
0x00047f7b      2068           mov.b @0x68:8,r0h
0x00047f7d      58             invalid
0x00047f7e      0a08           inc r0l
0x00047f80      68d8           mov.b r0l,@r5
0x00047f82      1888           sub.b r0l,r0l
0x00047f84      68c8           mov.b r0l,@r4
0x00047f86      01006960       sleep
0x00047f8a      6859           mov.b @r5,r1l
0x00047f8c      6e080002       mov.b @(0x2:16,r0),r0l
0x00047f90      1c89           cmp.b r0l,r1l
0x00047f92      4382           bls @@0x82:8
0x00047f94      f801           mov.b #0x1:8,r0l
0x00047f96      68d8           mov.b r0l,@r5
0x00047f98      5a047f16       jmp @0x7f16:16
0x00047f9c      6a280040       mov.b @0x40:16,r0l
0x00047fa0      7cb7a804       biand #0x0:3,@r11
0x00047fa4      461e           bne @@0x1e:8
0x00047fa6      6848           mov.b @r4,r0l
0x00047fa8      0a08           inc r0l
0x00047faa      68c8           mov.b r0l,@r4
0x00047fac      01006960       sleep
0x00047fb0      6849           mov.b @r4,r1l
0x00047fb2      6e080003       mov.b @(0x3:16,r0),r0l
0x00047fb6      1c89           cmp.b r0l,r1l
0x00047fb8      58             invalid
0x00047fb9      30ff           mov.b r0h,@0xff:8
0x00047fbb      5a188868       jmp @0x8868:16
0x00047fbf      c85a           or #0x5a:8,r0l
0x00047fc1      047f           orc #0x7f:8,ccr
0x00047fc3      165e           and r5h,r6l
0x00047fc5      0109e240       sleep
0x00047fc9      a66a           cmp.b #0x6a:8,r6h
0x00047fcb      2800           mov.b @0x0:8,r0l
0x00047fcd      407c           bra @@0x7c:8
0x00047fcf      b5a8           subx #0xa8:8,r5h
0x00047fd1      0147085e       sleep
0x00047fd5      0109e25a       sleep
0x00047fd9      047e           orc #0x7e:8,ccr
0x00047fdb      da5e           xor #0x5e:8,r2l
0x00047fdd      01643654       sleep
0x00047fe1      705e           bset #0x5:3,r6l
0x00047fe3      01645819       sleep
0x00047fe7      990d           addx #0xd:8,r1l
0x00047fe9      9946           addx #0x46:8,r1l
0x00047feb      167a           and r7h,r2l
0x00047fed      0500           xorc #0x0:8,ccr
0x00047fef      407c           bra @@0x7c:8
0x00047ff1      b67a           subx #0x7a:8,r6h
0x00047ff3      0400           orc #0x0:8,ccr
0x00047ff5      2000           mov.b @0x0:8,r0h
0x00047ff7      41f9           brn @@0xf9:8
0x00047ff9      027a           stc ccr,r2l
0x00047ffb      0300           ldc r0h,ccr
0x00047ffd      407c           bra @@0x7c:8
0x00047fff      b840           subx #0x40:8,r0l
0x00048001      147a           or r7h,r2l
0x00048003      0500           xorc #0x0:8,ccr
0x00048005      407c           bra @@0x7c:8
0x00048007      b77a           subx #0x7a:8,r7h
0x00048009      0400           orc #0x0:8,ccr
0x0004800b      2000           mov.b @0x0:8,r0h
0x0004800d      41f9           brn @@0xf9:8
0x0004800f      017a0300       sleep
0x00048013      407c           bra @@0x7c:8
0x00048015      bc68           subx #0x68:8,r4l
0x00048017      58             invalid
0x00048018      475e           beq @@0x5e:8
0x0004801a      a801           cmp.b #0x1:8,r0l
0x0004801c      4710           beq @@0x10:8
0x0004801e      a8             cmp.b #0x10:8,r0l
0x00048020      4724           beq @@0x24:8
0x00048022      a803           cmp.b #0x3:8,r0l
0x00048024      4748           beq @@0x48:8
0x00048026      a804           cmp.b #0x4:8,r0l
0x00048028      474e           beq @@0x4e:8
0x0004802a      404c           bra @@0x4c:8
0x0004802c      404a           bra @@0x4a:8
0x0004802e      684c           mov.b @r4,r4l
0x00048030      169c           and r1l,r4l
0x00048032      1c9c           cmp.b r1l,r4l
0x00048034      4642           bne @@0x42:8
0x00048036      01006b20       sleep
0x0004803a      0040           nop
0x0004803c      076e           ldc #0x6e:8,ccr
0x0004803e      010069b0       sleep
0x00048042      f802           mov.b #0x2:8,r0l
0x00048044      4024           bra @@0x24:8
0x00048046      684c           mov.b @r4,r4l
0x00048048      169c           and r1l,r4l
0x0004804a      1c9c           cmp.b r1l,r4l
0x0004804c      461a           bne @@0x1a:8
0x0004804e      01006b20       sleep
0x00048052      0040           nop
0x00048054      076e           ldc #0x6e:8,ccr
0x00048056      01006933       sleep
0x0004805a      1ab0           dec r0h
0x0004805c      7a             invalid
0x0004805d      2000           mov.b @0x0:8,r0h
0x0004805f      0000           nop
0x00048061      0945           add.w r4,r5
0x00048063      14f8           or r7l,r0l
0x00048065      0340           ldc r0h,ccr
0x00048067      02f8           stc ccr,r0l
0x00048069      0168d840       sleep
0x0004806d      0a68           inc r0l
0x0004806f      4c16           bge @@0x16:8
0x00048071      9c46           addx #0x46:8,r4l
0x00048073      04f8           orc #0xf8:8,ccr
0x00048075      0468           orc #0x68:8,ccr
0x00048077      d80b           xor #0xb:8,r0l
0x00048079      5979           jmp @r7
0x0004807b      2900           mov.b @0x0:8,r1l
0x0004807d      0258           stc ccr,r0l
0x0004807f      d0ff           xor #0xff:8,r0h
0x00048081      66             invalid
0x00048082      5e016436       jsr @0x6436:16
0x00048086      5470           rts
0x00048088      6df2           push r2
0x0004808a      1888           sub.b r0l,r0l
0x0004808c      6aa80040       mov.b r0l,@0x40:16
0x00048090      7cb50100       biand #0x0:3,@r11
0x00048094      6b200040       mov.w @0x40:16,r0
0x00048098      7cae6e09       biand #0x0:3,@r10
0x0004809c      0004           nop
0x0004809e      7a             invalid
0x0004809f      0000           nop
0x000480a1      407c           bra @@0x7c:8
0x000480a3      b479           subx #0x79:8,r4h
0x000480a5      0200           stc ccr,r0h
0x000480a7      035e           ldc r6l,ccr
0x000480a9      0158e07a       sleep
0x000480ad      0000           nop
0x000480af      407c           bra @@0x7c:8
0x000480b1      b47d           subx #0x7d:8,r4h
0x000480b3      0072           nop
0x000480b5      406a           bra @@0x6a:8
0x000480b7      2800           mov.b @0x0:8,r0l
0x000480b9      407c           bra @@0x7c:8
0x000480bb      b4e8           subx #0xe8:8,r4h
0x000480bd      f0c8           mov.b #0xc8:8,r0h
0x000480bf      0f6a           daa r2l
0x000480c1      a800           cmp.b #0x0:8,r0l
0x000480c3      407c           bra @@0x7c:8
0x000480c5      b46a           subx #0x6a:8,r4h
0x000480c7      a800           cmp.b #0x0:8,r0l
0x000480c9      2000           mov.b @0x0:8,r0h
0x000480cb      426a           bhi @@0x6a:8
0x000480cd      2800           mov.b @0x0:8,r0l
0x000480cf      407c           bra @@0x7c:8
0x000480d1      b2a8           subx #0xa8:8,r2h
0x000480d3      0647           andc #0x47:8,ccr
0x000480d5      227a           mov.b @0x7a:8,r2h
0x000480d7      01004007       sleep
0x000480db      7c691079       biand #0x7:3,@r6
0x000480df      60ff           bset r7l,r7l
0x000480e1      0079           nop
0x000480e3      4000           bra @@0x0:8
0x000480e5      f169           mov.b #0x69:8,r1h
0x000480e7      9019           addx #0x19:8,r0h
0x000480e9      006b           nop
0x000480eb      a000           cmp.b #0x0:8,r0h
0x000480ed      4007           bra @@0x7:8
0x000480ef      78             invalid
0x000480f0      f80f           mov.b #0xf:8,r0l
0x000480f2      6aa80040       mov.b r0l,@0x40:16
0x000480f6      62f9           bclr r7l,r1l
0x000480f8      01006b20       sleep
0x000480fc      0040           nop
0x000480fe      7cae0100       biand #0x0:3,@r10
0x00048102      6f000006       mov.w @(0x6:16,r0),r0
0x00048106      5d00           jsr @r0
0x00048108      7a             invalid
0x00048109      0000           nop
0x0004810b      407c           bra @@0x7c:8
0x0004810d      b47d           subx #0x7d:8,r4h
0x0004810f      0070           nop
0x00048111      406a           bra @@0x6a:8
0x00048113      2800           mov.b @0x0:8,r0l
0x00048115      4062           bra @@0x62:8
0x00048117      f96a           mov.b #0x6a:8,r1l
0x00048119      2000           mov.b @0x0:8,r0h
0x0004811b      407c           bra @@0x7c:8
0x0004811d      b4e0           subx #0xe0:8,r4h
0x0004811f      f0             mov.b #0x10:8,r0h
0x00048121      0f14           daa r4h
0x00048123      806a           add.b #0x6a:8,r0h
0x00048125      a000           cmp.b #0x0:8,r0h
0x00048127      407c           bra @@0x7c:8
0x00048129      b46a           subx #0x6a:8,r4h
0x0004812b      2800           mov.b @0x0:8,r0l
0x0004812d      407c           bra @@0x7c:8
0x0004812f      b46a           subx #0x6a:8,r4h
0x00048131      a800           cmp.b #0x0:8,r0l
0x00048133      2000           mov.b @0x0:8,r0h
0x00048135      42f8           bhi @@0xf8:8
0x00048137      016aa800       sleep
0x0004813b      407c           bra @@0x7c:8
0x0004813d      b618           subx #0x18:8,r6h
0x0004813f      886a           add.b #0x6a:8,r0l
0x00048141      a800           cmp.b #0x0:8,r0l
0x00048143      407c           bra @@0x7c:8
0x00048145      b76d           subx #0x6d:8,r7h
0x00048147      7254           bclr #0x5:3,r4h
0x00048149      705e           bset #0x5:3,r6l
0x0004814b      0386           ldc r6h,ccr
0x0004814d      386a           mov.b r0l,@0x6a:8
0x0004814f      2800           mov.b @0x0:8,r0l
0x00048151      4062           bra @@0x62:8
0x00048153      f96a           mov.b #0x6a:8,r1l
0x00048155      a800           cmp.b #0x0:8,r0l
0x00048157      407c           bra @@0x7c:8
0x00048159      c054           or #0x54:8,r0h
0x0004815b      706d           bset #0x6:3,r5l
0x0004815d      f25e           mov.b #0x5e:8,r2h
0x0004815f      03a2           ldc r2h,ccr
0x00048161      106a           shal r2l
0x00048163      2800           mov.b @0x0:8,r0l
0x00048165      407c           bra @@0x7c:8
0x00048167      c07a           or #0x7a:8,r0h
0x00048169      01004062       sleep
0x0004816d      f968           mov.b #0x68:8,r1l
0x0004816f      1a16           dec r6h
0x00048171      8a68           add.b #0x68:8,r2l
0x00048173      9a6d           addx #0x6d:8,r2l
0x00048175      7254           bclr #0x5:3,r4h
0x00048177      705e           bset #0x5:3,r6l
0x00048179      0164587a       sleep
0x0004817d      3700           mov.b r7h,@0x0:8
0x0004817f      0000           nop
0x00048181      347a           mov.b r4h,@0x7a:8
0x00048183      0400           orc #0x0:8,ccr
0x00048185      4062           bra @@0x62:8
0x00048187      f97a           mov.b #0x7a:8,r1l
0x00048189      0600           andc #0x0:8,ccr
0x0004818b      404e           bra @@0x4e:8
0x0004818d      977a           addx #0x7a:8,r7h
0x0004818f      0500           xorc #0x0:8,ccr
0x00048191      407c           bra @@0x7c:8
0x00048193      c07c           or #0x7c:8,r0h
0x00048195      5073           mulxu r7h,r3
0x00048197      1046           shal r6h
0x00048199      2668           mov.b @0x68:8,r6h
0x0004819b      58             invalid
0x0004819c      460a           bne @@0xa:8
0x0004819e      6848           mov.b @r4,r0l
0x000481a0      e807           and #0x7:8,r0l
0x000481a2      68c8           mov.b r0l,@r4
0x000481a4      5a0483c0       jmp @0x83c0:16
0x000481a8      7c507330       biand #0x3:3,@r5
0x000481ac      4704           beq @@0x4:8
0x000481ae      18dd           sub.b r5l,r5l
0x000481b0      4010           bra @@0x10:8
0x000481b2      7c507320       biand #0x2:3,@r5
0x000481b6      4704           beq @@0x4:8
0x000481b8      fd01           mov.b #0x1:8,r5l
0x000481ba      4006           bra @@0x6:8
0x000481bc      fd03           mov.b #0x3:8,r5l
0x000481be      4002           bra @@0x2:8
0x000481c0      fd02           mov.b #0x2:8,r5l
0x000481c2      68ed           mov.b r5l,@r6
0x000481c4      5e03572c       jsr @0x572c:16
0x000481c8      f801           mov.b #0x1:8,r0l
0x000481ca      6aa80040       mov.b r0l,@0x40:16
0x000481ce      4ea0           bgt @@0xa0:8
0x000481d0      1a80           dec r0h
0x000481d2      6868           mov.b @r6,r0l
0x000481d4      0f82           daa r2h
0x000481d6      1030           shal r0h
0x000481d8      1030           shal r0h
0x000481da      01007800       sleep
0x000481de      6b200040       mov.w @0x40:16,r0
0x000481e2      1078           shal r0l
0x000481e4      7a             invalid
0x000481e5      01000000       sleep
0x000481e9      295e           mov.b @0x5e:8,r1l
0x000481eb      0163ea7a       sleep
0x000481ef      01000000       sleep
0x000481f3      64             invalid
0x000481f4      5e015cf2       jsr @0x5cf2:16
0x000481f8      01006ba0       sleep
0x000481fc      0040           nop
0x000481fe      4e98           bgt @@0x98:8
0x00048200      6b200040       mov.w @0x40:16,r0
0x00048204      0e88           addx r0l,r0l
0x00048206      6ba00040       mov.w r0,@0x40:16
0x0004820a      0e8c           addx r0l,r4l
0x0004820c      6b200040       mov.w @0x40:16,r0
0x00048210      0e86           addx r0l,r6h
0x00048212      6ba00040       mov.w r0,@0x40:16
0x00048216      0e8a           addx r0l,r2l
0x00048218      7a             invalid
0x00048219      0300           ldc r0h,ccr
0x0004821b      036a           ldc r2l,ccr
0x0004821d      4a0f           bpl @@0xf:8
0x0004821f      a078           cmp.b #0x78:8,r0h
0x00048221      006a           nop
0x00048223      2000           mov.b @0x0:8,r0h
0x00048225      404e           bra @@0x4e:8
0x00048227      4818           bvc @@0x18:8
0x00048229      885d           add.b #0x5d:8,r0l
0x0004822b      301a           mov.b r0h,@0x1a:8
0x0004822d      8068           add.b #0x68:8,r0h
0x0004822f      6878           mov.b @r7,r0l
0x00048231      006a           nop
0x00048233      2000           mov.b @0x0:8,r0h
0x00048235      404e           bra @@0x4e:8
0x00048237      4cf8           bge @@0xf8:8
0x00048239      015d301a       sleep
0x0004823d      8068           add.b #0x68:8,r0h
0x0004823f      6810           mov.b @r1,r0h
0x00048241      3010           mov.b r0h,@0x10:8
0x00048243      3001           mov.b r0h,@0x1:8
0x00048245      0078           nop
0x00048247      006b           nop
0x00048249      2000           mov.b @0x0:8,r0h
0x0004824b      04a4           orc #0xa4:8,ccr
0x0004824d      1c18           cmp.b r1h,r0l
0x0004824f      9968           addx #0x68:8,r1l
0x00048251      895e           add.b #0x5e:8,r1l
0x00048253      03bf           ldc r7l,ccr
0x00048255      366b           mov.b r6h,@0x6b:8
0x00048257      2100           mov.b @0x0:8,r1h
0x00048259      404e           bra @@0x4e:8
0x0004825b      58             invalid
0x0004825c      7a             invalid
0x0004825d      0000           nop
0x0004825f      0000           nop
0x00048261      280a           mov.b @0xa:8,r0l
0x00048263      f05e           mov.b #0x5e:8,r0h
0x00048265      0164fe68       sleep
0x00048269      ed1a           and #0x1a:8,r5l
0x0004826b      d568           xor #0x68:8,r5h
0x0004826d      6d0f           mov.w @r0+,r7
0x0004826f      d010           xor #0x10:8,r0h
0x00048271      3010           mov.b r0h,@0x10:8
0x00048273      3001           mov.b r0h,@0x1:8
0x00048275      0078           nop
0x00048277      006b           nop
0x00048279      2000           mov.b @0x0:8,r0h
0x0004827b      4010           bra @@0x10:8
0x0004827d      78             invalid
0x0004827e      7a             invalid
0x0004827f      01000000       sleep
0x00048283      295e           mov.b @0x5e:8,r1l
0x00048285      0163ea7a       sleep
0x00048289      01000000       sleep
0x0004828d      64             invalid
0x0004828e      5e015cf2       jsr @0x5cf2:16
0x00048292      01006ba0       sleep
0x00048296      0040           nop
0x00048298      4e98           bgt @@0x98:8
0x0004829a      78             invalid
0x0004829b      506a           mulxu r6h,r2
0x0004829d      2000           mov.b @0x0:8,r0h
0x0004829f      404e           bra @@0x4e:8
0x000482a1      4818           bvc @@0x18:8
0x000482a3      885d           add.b #0x5d:8,r0l
0x000482a5      301a           mov.b r0h,@0x1a:8
0x000482a7      8068           add.b #0x68:8,r0h
0x000482a9      6878           mov.b @r7,r0l
0x000482ab      006a           nop
0x000482ad      2000           mov.b @0x0:8,r0h
0x000482af      404e           bra @@0x4e:8
0x000482b1      4cf8           bge @@0xf8:8
0x000482b3      015d301a       sleep
0x000482b7      8068           add.b #0x68:8,r0h
0x000482b9      6810           mov.b @r1,r0h
0x000482bb      3010           mov.b r0h,@0x10:8
0x000482bd      3001           mov.b r0h,@0x1:8
0x000482bf      0078           nop
0x000482c1      006b           nop
0x000482c3      2000           mov.b @0x0:8,r0h
0x000482c5      04a4           orc #0xa4:8,ccr
0x000482c7      1cf9           cmp.b r7l,r1l
0x000482c9      0368           ldc r0l,ccr
0x000482cb      895e           add.b #0x5e:8,r1l
0x000482cd      03bf           ldc r7l,ccr
0x000482cf      366b           mov.b r6h,@0x6b:8
0x000482d1      2100           mov.b @0x0:8,r1h
0x000482d3      404e           bra @@0x4e:8
0x000482d5      58             invalid
0x000482d6      0ff0           daa r0h
0x000482d8      5e0164fe       jsr @0x64fe:16
0x000482dc      0f81           daa r1h
0x000482de      7a             invalid
0x000482df      0200           stc ccr,r0h
0x000482e1      0000           nop
0x000482e3      280a           mov.b @0xa:8,r0l
0x000482e5      f27a           mov.b #0x7a:8,r2h
0x000482e7      0000           nop
0x000482e9      0000           nop
0x000482eb      200a           mov.b @0xa:8,r0h
0x000482ed      f05e           mov.b #0x5e:8,r0h
0x000482ef      0159a47a       sleep
0x000482f3      0000           nop
0x000482f5      04a8           orc #0xa8:8,ccr
0x000482f7      ac7a           cmp.b #0x7a:8,r4l
0x000482f9      01000000       sleep
0x000482fd      180a           sub.b r0h,r2l
0x000482ff      f15e           mov.b #0x5e:8,r1h
0x00048301      01640a7a       sleep
0x00048305      01000000       sleep
0x00048309      180a           sub.b r0h,r2l
0x0004830b      f17a           mov.b #0x7a:8,r1h
0x0004830d      0200           stc ccr,r0h
0x0004830f      04a8           orc #0xa8:8,ccr
0x00048311      b47a           subx #0x7a:8,r4h
0x00048313      0000           nop
0x00048315      0000           nop
0x00048317      100a           shll r2l
0x00048319      f05e           mov.b #0x5e:8,r0h
0x0004831b      0159a47a       sleep
0x0004831f      0100           sleep
0x00048323      180a           sub.b r0h,r2l
0x00048325      f17a           mov.b #0x7a:8,r1h
0x00048327      0200           stc ccr,r0h
0x00048329      04a8           orc #0xa8:8,ccr
0x0004832b      b47a           subx #0x7a:8,r4h
0x0004832d      0000           nop
0x0004832f      0000           nop
0x00048331      080a           add.b r0h,r2l
0x00048333      f05e           mov.b #0x5e:8,r0h
0x00048335      0159a47a       sleep
0x00048339      0000           nop
0x0004833b      0000           nop
0x0004833d      200a           mov.b @0xa:8,r0h
0x0004833f      f07a           mov.b #0x7a:8,r0h
0x00048341      01000000       sleep
0x00048345      180a           sub.b r0h,r2l
0x00048347      f15e           mov.b #0x5e:8,r1h
0x00048349      015e8e0d       sleep
0x0004834d      0047           nop
0x0004834f      2e7a           mov.b @0x7a:8,r6l
0x00048351      01000000       sleep
0x00048355      200a           mov.b @0xa:8,r0h
0x00048357      f17a           mov.b #0x7a:8,r1h
0x00048359      0200           stc ccr,r0h
0x0004835b      0000           nop
0x0004835d      180a           sub.b r0h,r2l
0x0004835f      f20f           mov.b #0xf:8,r2h
0x00048361      f05e           mov.b #0x5e:8,r0h
0x00048363      0154e87a       sleep
0x00048367      01000000       sleep
0x0004836b      100a           shll r2l
0x0004836d      f15e           mov.b #0x5e:8,r1h
0x0004836f      015e9e0d       sleep
0x00048373      0047           nop
0x00048375      3468           mov.b r4h,@0x68:8
0x00048377      48e8           bvc @@0xe8:8
0x00048379      0768           ldc #0x68:8,ccr
0x0004837b      c840           or #0x40:8,r0l
0x0004837d      2c7a           mov.b @0x7a:8,r4l
0x0004837f      01000000       sleep
0x00048383      180a           sub.b r0h,r2l
0x00048385      f17a           mov.b #0x7a:8,r1h
0x00048387      0200           stc ccr,r0h
0x00048389      0000           nop
0x0004838b      200a           mov.b @0xa:8,r0h
0x0004838d      f20f           mov.b #0xf:8,r2h
0x0004838f      f05e           mov.b #0x5e:8,r0h
0x00048391      0154e87a       sleep
0x00048395      01000000       sleep
0x00048399      080a           add.b r0h,r2l
0x0004839b      f15e           mov.b #0x5e:8,r1h
0x0004839d      015e9e0d       sleep
0x000483a1      0047           nop
0x000483a3      0668           andc #0x68:8,ccr
0x000483a5      48e8           bvc @@0xe8:8
0x000483a7      0768           ldc #0x68:8,ccr
0x000483a9      c81a           or #0x1a:8,r0l
0x000483ab      8068           add.b #0x68:8,r0h
0x000483ad      6810           mov.b @r1,r0h
0x000483af      3010           mov.b r0h,@0x10:8
0x000483b1      3001           mov.b r0h,@0x1:8
0x000483b3      0078           nop
0x000483b5      006b           nop
0x000483b7      2000           mov.b @0x0:8,r0h
0x000483b9      04a4           orc #0xa4:8,ccr
0x000483bb      1c18           cmp.b r1h,r0l
0x000483bd      9968           addx #0x68:8,r1l
0x000483bf      897a           add.b #0x7a:8,r1l
0x000483c1      1700           not r0h
0x000483c3      0000           nop
0x000483c5      345e           mov.b r4h,@0x5e:8
0x000483c7      01643654       sleep
0x000483cb      705e           bset #0x5:3,r6l
0x000483cd      0164581b       sleep
0x000483d1      971b           addx #0x1b:8,r7h
0x000483d3      977a           addx #0x7a:8,r7h
0x000483d5      0400           orc #0x0:8,ccr
0x000483d7      404e           bra @@0x4e:8
0x000483d9      977a           addx #0x7a:8,r7h
0x000483db      0600           andc #0x0:8,ccr
0x000483dd      4062           bra @@0x62:8
0x000483df      f97a           mov.b #0x7a:8,r1l
0x000483e1      0500           xorc #0x0:8,ccr
0x000483e3      407c           bra @@0x7c:8
0x000483e5      c07c           or #0x7c:8,r0h
0x000483e7      5073           mulxu r7h,r3
0x000483e9      1046           shal r6h
0x000483eb      2668           mov.b @0x68:8,r6h
0x000483ed      58             invalid
0x000483ee      460a           bne @@0xa:8
0x000483f0      6868           mov.b @r6,r0l
0x000483f2      e807           and #0x7:8,r0l
0x000483f4      68e8           mov.b r0l,@r6
0x000483f6      5a04852e       jmp @0x852e:16
0x000483fa      7c507330       biand #0x3:3,@r5
0x000483fe      4704           beq @@0x4:8
0x00048400      18dd           sub.b r5l,r5l
0x00048402      4010           bra @@0x10:8
0x00048404      7c507320       biand #0x2:3,@r5
0x00048408      4704           beq @@0x4:8
0x0004840a      fd01           mov.b #0x1:8,r5l
0x0004840c      4006           bra @@0x6:8
0x0004840e      fd03           mov.b #0x3:8,r5l
0x00048410      4002           bra @@0x2:8
0x00048412      fd02           mov.b #0x2:8,r5l
0x00048414      68cd           mov.b r5l,@r4
0x00048416      5e03572c       jsr @0x572c:16
0x0004841a      f801           mov.b #0x1:8,r0l
0x0004841c      6aa80040       mov.b r0l,@0x40:16
0x00048420      4ea0           bgt @@0xa0:8
0x00048422      6b             mov.w @0x100:16,r0
0x00048426      0e88           addx r0l,r0l
0x00048428      6ba00040       mov.w r0,@0x40:16
0x0004842c      0e8c           addx r0l,r4l
0x0004842e      6b200040       mov.w @0x40:16,r0
0x00048432      0e86           addx r0l,r6h
0x00048434      6ba00040       mov.w r0,@0x40:16
0x00048438      0e8a           addx r0l,r2l
0x0004843a      1ad5           dec r5h
0x0004843c      684d           mov.b @r4,r5l
0x0004843e      0fd0           daa r0h
0x00048440      1030           shal r0h
0x00048442      1030           shal r0h
0x00048444      01007800       sleep
0x00048448      6b200040       mov.w @0x40:16,r0
0x0004844c      1078           shal r0l
0x0004844e      01006ba0       sleep
0x00048452      0040           nop
0x00048454      4e98           bgt @@0x98:8
0x00048456      78             invalid
0x00048457      506a           mulxu r6h,r2
0x00048459      2000           mov.b @0x0:8,r0h
0x0004845b      404e           bra @@0x4e:8
0x0004845d      4818           bvc @@0x18:8
0x0004845f      885e           add.b #0x5e:8,r0l
0x00048461      036a           ldc r2l,ccr
0x00048463      4a1a           bpl @@0x1a:8
0x00048465      8068           add.b #0x68:8,r0h
0x00048467      4878           bvc @@0x78:8
0x00048469      006a           nop
0x0004846b      2000           mov.b @0x0:8,r0h
0x0004846d      404e           bra @@0x4e:8
0x0004846f      4cf8           bge @@0xf8:8
0x00048471      015e036a       sleep
0x00048475      4a5e           bpl @@0x5e:8
0x00048477      03bf           ldc r7l,ccr
0x00048479      366b           mov.b r6h,@0x6b:8
0x0004847b      2000           mov.b @0x0:8,r0h
0x0004847d      404e           bra @@0x4e:8
0x0004847f      58             invalid
0x00048480      1770           neg r0h
0x00048482      010069f0       sleep
0x00048486      7a             invalid
0x00048487      0300           ldc r0h,ccr
0x00048489      0000           nop
0x0004848b      031a           ldc r2l,ccr
0x0004848d      8068           add.b #0x68:8,r0h
0x0004848f      4810           bvc @@0x10:8
0x00048491      3010           mov.b r0h,@0x10:8
0x00048493      3001           mov.b r0h,@0x1:8
0x00048495      0078           nop
0x00048497      006b           nop
0x00048499      2000           mov.b @0x0:8,r0h
0x0004849b      4010           bra @@0x10:8
0x0004849d      78             invalid
0x0004849e      0fb1           daa r1h
0x000484a0      5e0163ea       jsr @0x63ea:16
0x000484a4      1130           shar r0h
0x000484a6      1130           shar r0h
0x000484a8      01006ba0       sleep
0x000484ac      0040           nop
0x000484ae      4e98           bgt @@0x98:8
0x000484b0      5e03bf36       jsr @0xbf36:16
0x000484b4      01006970       sleep
0x000484b8      0fb1           daa r1h
0x000484ba      5e0163ea       jsr @0x63ea:16
0x000484be      1130           shar r0h
0x000484c0      1130           shar r0h
0x000484c2      0f85           daa r5h
0x000484c4      7a             invalid
0x000484c5      01000000       sleep
0x000484c9      0a5e           inc r6l
0x000484cb      015cf20f       sleep
0x000484cf      826b           add.b #0x6b:8,r2h
0x000484d1      2000           mov.b @0x0:8,r0h
0x000484d3      404e           bra @@0x4e:8
0x000484d5      58             invalid
0x000484d6      1770           neg r0h
0x000484d8      1fd0           das r0h
0x000484da      4524           bcs @@0x24:8
0x000484dc      6b200040       mov.w @0x40:16,r0
0x000484e0      4e58           bgt @@0x58:8
0x000484e2      1770           neg r0h
0x000484e4      1ad0           dec r0h
0x000484e6      0fa1           daa r1h
0x000484e8      1f90           das r0h
0x000484ea      4336           bls @@0x36:8
0x000484ec      1a80           dec r0h
0x000484ee      6848           mov.b @r4,r0l
0x000484f0      78             invalid
0x000484f1      006a           nop
0x000484f3      2800           mov.b @0x0:8,r0l
0x000484f5      04a8           orc #0xa8:8,ccr
0x000484f7      a468           cmp.b #0x68:8,r4h
0x000484f9      6916           mov.w @r1,r6
0x000484fb      8968           add.b #0x68:8,r1l
0x000484fd      e940           and #0x40:8,r1l
0x000484ff      226b           mov.b @0x6b:8,r2h
0x00048501      2000           mov.b @0x0:8,r0h
0x00048503      404e           bra @@0x4e:8
0x00048505      58             invalid
0x00048506      1770           neg r0h
0x00048508      1a85           dec r5h
0x0004850a      0fa0           daa r0h
0x0004850c      1f85           das r5h
0x0004850e      4312           bls @@0x12:8
0x00048510      1a80           dec r0h
0x00048512      6848           mov.b @r4,r0l
0x00048514      78             invalid
0x00048515      006a           nop
0x00048517      2800           mov.b @0x0:8,r0l
0x00048519      04a8           orc #0xa8:8,ccr
0x0004851b      a468           cmp.b #0x68:8,r4h
0x0004851d      6916           mov.w @r1,r6
0x0004851f      8968           add.b #0x68:8,r1l
0x00048521      e91b           and #0x1b:8,r1l
0x00048523      737a           btst #0x7:3,r2l
0x00048525      23             mov.b @0x10:8,r3h
0x00048527      0000           nop
0x00048529      015840ff       sleep
0x0004852d      5e0b970b       jsr @0x970b:16
0x00048531      975e           addx #0x5e:8,r7h
0x00048533      01643654       sleep
0x00048537      7019           bset #0x1:3,r1l
0x00048539      006b           nop
0x0004853b      a000           cmp.b #0x0:8,r0h
0x0004853d      4007           bra @@0x7:8
0x0004853f      78             invalid
0x00048540      7a             invalid
0x00048541      01004007       sleep
0x00048545      7c691079       biand #0x7:3,@r6
0x00048549      60ff           bset r7l,r7l
0x0004854b      0070           nop
0x0004854d      0869           add.b r6h,r1l
0x0004854f      90f8           addx #0xf8:8,r0h
0x00048551      016aa800       sleep
0x00048555      407c           bra @@0x7c:8
0x00048557      b554           subx #0x54:8,r5h
0x00048559      705e           bset #0x5:3,r6l
0x0004855b      01645818       sleep
0x0004855f      886a           add.b #0x6a:8,r0l
0x00048561      a800           cmp.b #0x0:8,r0l
0x00048563      407c           bra @@0x7c:8
0x00048565      b57a           subx #0x7a:8,r5h
0x00048567      0500           xorc #0x0:8,ccr
0x00048569      407c           bra @@0x7c:8
0x0004856b      ae01           cmp.b #0x1:8,r6l
0x0004856d      0069           nop
0x0004856f      506e           mulxu r6h,r6
0x00048571      0900           add.w r0,r0
0x00048573      047a           orc #0x7a:8,ccr
0x00048575      0000           nop
0x00048577      407c           bra @@0x7c:8
0x00048579      b479           subx #0x79:8,r4h
0x0004857b      0200           stc ccr,r0h
0x0004857d      035e           ldc r6l,ccr
0x0004857f      0158e001       sleep
0x00048583      0069           nop
0x00048585      506e           mulxu r6h,r6
0x00048587      0900           add.w r0,r0
0x00048589      057a           xorc #0x7a:8,ccr
0x0004858b      0000           nop
0x0004858d      407c           bra @@0x7c:8
0x0004858f      b479           subx #0x79:8,r4h
0x00048591      0203           stc ccr,r3h
0x00048593      025e           stc ccr,r6l
0x00048595      0158e06a       sleep
0x00048599      2800           mov.b @0x0:8,r0l
0x0004859b      407c           bra @@0x7c:8
0x0004859d      b4e8           subx #0xe8:8,r4h
0x0004859f      f8c8           mov.b #0xc8:8,r0l
0x000485a1      076a           ldc #0x6a:8,ccr
0x000485a3      a800           cmp.b #0x0:8,r0l
0x000485a5      407c           bra @@0x7c:8
0x000485a7      b46a           subx #0x6a:8,r4h
0x000485a9      a800           cmp.b #0x0:8,r0l
0x000485ab      2000           mov.b @0x0:8,r0h
0x000485ad      427a           bhi @@0x7a:8
0x000485af      01004007       sleep
0x000485b3      7c691079       biand #0x7:3,@r6
0x000485b7      60ff           bset r7l,r7l
0x000485b9      0079           nop
0x000485bb      4000           bra @@0x0:8
0x000485bd      f169           mov.b #0x69:8,r1h
0x000485bf      9019           addx #0x19:8,r0h
0x000485c1      006b           nop
0x000485c3      a000           cmp.b #0x0:8,r0h
0x000485c5      4007           bra @@0x7:8
0x000485c7      78             invalid
0x000485c8      f807           mov.b #0x7:8,r0l
0x000485ca      6aa80040       mov.b r0l,@0x40:16
0x000485ce      62f9           bclr r7l,r1l
0x000485d0      01006950       sleep
0x000485d4      01006f00       sleep
0x000485d8      0006           nop
0x000485da      5d00           jsr @r0
0x000485dc      6a280040       mov.b @0x40:16,r0l
0x000485e0      62f9           bclr r7l,r1l
0x000485e2      6a200040       mov.b @0x40:16,r0h
0x000485e6      7cb4e0f8       biand #0x7:3,@r11
0x000485ea      e807           and #0x7:8,r0l
0x000485ec      1480           or r0l,r0h
0x000485ee      6aa00040       mov.b r0h,@0x40:16
0x000485f2      7cb46a28       biand #0x2:3,@r11
0x000485f6      0040           nop
0x000485f8      7cb46aa8       biand #0x2:3,@r11
0x000485fc      0020           nop
0x000485fe      0042           nop
0x00048600      f801           mov.b #0x1:8,r0l
0x00048602      6aa80040       mov.b r0l,@0x40:16
0x00048606      7cb66aa8       biand #0x2:3,@r11
0x0004860a      0040           nop
0x0004860c      7cb75e01       biand #0x0:3,@r11
0x00048610      64             invalid
0x00048611      3654           mov.b r6h,@0x54:8
0x00048613      705e           bset #0x5:3,r6l
0x00048615      0164587a       sleep
0x00048619      0600           andc #0x0:8,ccr
0x0004861b      04a7           orc #0xa7:8,ccr
0x0004861d      aa40           cmp.b #0x40:8,r2l
0x0004861f      2068           mov.b @0x68:8,r0h
0x00048621      686a           mov.b @r6,r2l
0x00048623      2900           mov.b @0x0:8,r1l
0x00048625      407c           bra @@0x7c:8
0x00048627      b21c           subx #0x1c:8,r2h
0x00048629      9846           addx #0x46:8,r0l
0x0004862b      0e6e           addx r6h,r6l
0x0004862d      6800           mov.b @r0,r0h
0x0004862f      016a2900       sleep
0x00048633      407c           bra @@0x7c:8
0x00048635      b31c           subx #0x1c:8,r3h
0x00048637      9847           addx #0x47:8,r0l
0x00048639      0a7a           inc r2l
0x0004863b      1600           and r0h,r0h
0x0004863d      0000           nop
0x0004863f      0a68           inc r0l
0x00048641      6846           mov.b @r4,r6h
0x00048643      dc68           xor #0x68:8,r4l
0x00048645      6858           mov.b @r5,r0l
0x00048647      7000           bset #0x0:3,r0h
0x00048649      a86e           cmp.b #0x6e:8,r0l
0x0004864b      6800           mov.b @r0,r0h
0x0004864d      02a8           stc ccr,r0l
0x0004864f      ff47           mov.b #0x47:8,r7l
0x00048651      0e6e           addx r6h,r6l
0x00048653      6800           mov.b @r0,r0h
0x00048655      0220           stc ccr,r0h
0x00048657      d3e0           xor #0xe0:8,r3h
0x00048659      c0e8           or #0xe8:8,r0h
0x0004865b      3f14           mov.b r7l,@0x14:8
0x0004865d      8030           add.b #0x30:8,r0h
0x0004865f      d36e           xor #0x6e:8,r3h
0x00048661      6800           mov.b @r0,r0h
0x00048663      04a8           orc #0xa8:8,ccr
0x00048665      ff47           mov.b #0x47:8,r7l
0x00048667      0a6e           inc r6l
0x00048669      6800           mov.b @r0,r0h
0x0004866b      0477           orc #0x77:8,ccr
0x0004866d      087f           add.b r7h,r7l
0x0004866f      d267           xor #0x67:8,r2h
0x00048671      006e           nop
0x00048673      6800           mov.b @r0,r0h
0x00048675      03a8           ldc r0l,ccr
0x00048677      ff47           mov.b #0x47:8,r7l
0x00048679      0e6e           addx r6h,r6l
0x0004867b      6800           mov.b @r0,r0h
0x0004867d      0320           ldc r0h,ccr
0x0004867f      d6e0           xor #0xe0:8,r6h
0x00048681      fce8           mov.b #0xe8:8,r4l
0x00048683      0314           ldc r4h,ccr
0x00048685      8030           add.b #0x30:8,r0h
0x00048687      d66e           xor #0x6e:8,r6h
0x00048689      6800           mov.b @r0,r0h
0x0004868b      05a8           xorc #0xa8:8,ccr
0x0004868d      ff47           mov.b #0x47:8,r7l
0x0004868f      127a           rotl r2l
0x00048691      0000           nop
0x00048693      ffff           mov.b #0xff:8,r7l
0x00048695      d66e           xor #0x6e:8,r6h
0x00048697      6900           mov.w @r0,r0
0x00048699      0579           xorc #0x79:8,ccr
0x0004869b      0200           stc ccr,r0h
0x0004869d      045e           orc #0x5e:8,ccr
0x0004869f      0158e06e       sleep
0x000486a3      6800           mov.b @r0,r0h
0x000486a5      06a8           andc #0xa8:8,ccr
0x000486a7      ff47           mov.b #0x47:8,r7l
0x000486a9      127a           rotl r2l
0x000486ab      0000           nop
0x000486ad      ffff           mov.b #0xff:8,r7l
0x000486af      d36e           xor #0x6e:8,r3h
0x000486b1      6900           mov.w @r0,r0
0x000486b3      0679           andc #0x79:8,ccr
0x000486b5      0200           stc ccr,r0h
0x000486b7      025e           stc ccr,r6l
0x000486b9      0158e06e       sleep
0x000486bd      6800           mov.b @r0,r0h
0x000486bf      07a8           ldc #0xa8:8,ccr
0x000486c1      ff47           mov.b #0x47:8,r7l
0x000486c3      0a6e           inc r6l
0x000486c5      6800           mov.b @r0,r0h
0x000486c7      076a           ldc #0x6a:8,ccr
0x000486c9      a800           cmp.b #0x0:8,r0l
0x000486cb      2004           mov.b @0x4:8,r0h
0x000486cd      036e           ldc r6l,ccr
0x000486cf      6800           mov.b @r0,r0h
0x000486d1      08a8           add.b r2l,r0l
0x000486d3      ff47           mov.b #0x47:8,r7l
0x000486d5      0a6e           inc r6l
0x000486d7      6800           mov.b @r0,r0h
0x000486d9      0877           add.b r7h,r7h
0x000486db      087f           add.b r7h,r7l
0x000486dd      d767           xor #0x67:8,r7h
0x000486df      006e           nop
0x000486e1      6800           mov.b @r0,r0h
0x000486e3      09a8           add.w r10,r0
0x000486e5      ff47           mov.b #0x47:8,r7l
0x000486e7      0a6e           inc r6l
0x000486e9      6e000977       mov.b @(0x977:16,r0),r0h
0x000486ed      0e7f           addx r7h,r7l
0x000486ef      d267           xor #0x67:8,r2h
0x000486f1      105e           shal r6l
0x000486f3      01643654       sleep
0x000486f7      707a           bset #0x7:3,r2l
0x000486f9      0000           nop
0x000486fb      4062           bra @@0x62:8
0x000486fd      f97e           mov.b #0x7e:8,r1l
0x000486ff      ce77           or #0x77:8,r6l
0x00048701      007d           nop
0x00048703      0067           nop
0x00048705      207e           mov.b @0x7e:8,r0h
0x00048707      ce77           or #0x77:8,r6l
0x00048709      107d           shal r5l
0x0004870b      0067           nop
0x0004870d      107a           shal r2l
0x0004870f      0000           nop
0x00048711      4062           bra @@0x62:8
0x00048713      f97e           mov.b #0x7e:8,r1l
0x00048715      ce77           or #0x77:8,r6l
0x00048717      207d           mov.b @0x7d:8,r0h
0x00048719      0067           nop
0x0004871b      0054           nop
0x0004871d      707a           bset #0x7:3,r2l
0x0004871f      0000           nop
0x00048721      4062           bra @@0x62:8
0x00048723      f97e           mov.b #0x7e:8,r1l
0x00048725      ce77           or #0x77:8,r6l
0x00048727      307d           mov.b r0h,@0x7d:8
0x00048729      0067           nop
0x0004872b      207e           mov.b @0x7e:8,r0h
0x0004872d      ce77           or #0x77:8,r6l
0x0004872f      407d           bra @@0x7d:8
0x00048731      0067           nop
0x00048733      107a           shal r2l
0x00048735      0000           nop
0x00048737      4062           bra @@0x62:8
0x00048739      f97e           mov.b #0x7e:8,r1l
0x0004873b      ce77           or #0x77:8,r6l
0x0004873d      507d           mulxu r7h,r5
0x0004873f      0067           nop
0x00048741      0054           nop
0x00048743      707a           bset #0x7:3,r2l
0x00048745      0000           nop
0x00048747      4062           bra @@0x62:8
0x00048749      f97e           mov.b #0x7e:8,r1l
0x0004874b      cf77           or #0x77:8,r7l
0x0004874d      307d           mov.b r0h,@0x7d:8
0x0004874f      0067           nop
0x00048751      207e           mov.b @0x7e:8,r0h
0x00048753      d277           xor #0x77:8,r2h
0x00048755      307d           mov.b r0h,@0x7d:8
0x00048757      0067           nop
0x00048759      107a           shal r2l
0x0004875b      0000           nop
0x0004875d      4062           bra @@0x62:8
0x0004875f      f97e           mov.b #0x7e:8,r1l
0x00048761      d777           xor #0x77:8,r7h
0x00048763      307d           mov.b r0h,@0x7d:8
0x00048765      0067           nop
0x00048767      0054           nop
0x00048769      707a           bset #0x7:3,r2l
0x0004876b      0000           nop
0x0004876d      4062           bra @@0x62:8
0x0004876f      f97e           mov.b #0x7e:8,r1l
0x00048771      d777           xor #0x77:8,r7h
0x00048773      407d           bra @@0x7d:8
0x00048775      0067           nop
0x00048777      207e           mov.b @0x7e:8,r0h
0x00048779      d777           xor #0x77:8,r7h
0x0004877b      507d           mulxu r7h,r5
0x0004877d      0067           nop
0x0004877f      107a           shal r2l
0x00048781      0000           nop
0x00048783      4062           bra @@0x62:8
0x00048785      f97e           mov.b #0x7e:8,r1l
0x00048787      d777           xor #0x77:8,r7h
0x00048789      707d           bset #0x7:3,r5l
0x0004878b      0067           nop
0x0004878d      0054           nop
0x0004878f      707a           bset #0x7:3,r2l
0x00048791      0000           nop
0x00048793      4062           bra @@0x62:8
0x00048795      f97e           mov.b #0x7e:8,r1l
0x00048797      cf77           or #0x77:8,r7l
0x00048799      007d           nop
0x0004879b      0067           nop
0x0004879d      207e           mov.b @0x7e:8,r0h
0x0004879f      d277           xor #0x77:8,r2h
0x000487a1      207d           mov.b @0x7d:8,r0h
0x000487a3      0067           nop
0x000487a5      107a           shal r2l
0x000487a7      0000           nop
0x000487a9      4062           bra @@0x62:8
0x000487ab      f97e           mov.b #0x7e:8,r1l
0x000487ad      ce77           or #0x77:8,r6l
0x000487af      607d           bset r7h,r5l
0x000487b1      0067           nop
0x000487b3      0054           nop
0x000487b5      707a           bset #0x7:3,r2l
0x000487b7      0000           nop
0x000487b9      4062           bra @@0x62:8
0x000487bb      f97e           mov.b #0x7e:8,r1l
0x000487bd      d777           xor #0x77:8,r7h
0x000487bf      207d           mov.b @0x7d:8,r0h
0x000487c1      0067           nop
0x000487c3      207e           mov.b @0x7e:8,r0h
0x000487c5      ce77           or #0x77:8,r6l
0x000487c7      707d           bset #0x7:3,r5l
0x000487c9      0067           nop
0x000487cb      107a           shal r2l
0x000487cd      0000           nop
0x000487cf      4062           bra @@0x62:8
0x000487d1      f97e           mov.b #0x7e:8,r1l
0x000487d3      d777           xor #0x77:8,r7h
0x000487d5      607d           bset r7h,r5l
0x000487d7      0067           nop
0x000487d9      0054           nop
0x000487db      705e           bset #0x5:3,r6l
0x000487dd      01645801       sleep
0x000487e1      006b           nop
0x000487e3      2000           mov.b @0x0:8,r0h
0x000487e5      407c           bra @@0x7c:8
0x000487e7      ae6e           cmp.b #0x6e:8,r6l
0x000487e9      0900           add.w r0,r0
0x000487eb      047a           orc #0x7a:8,ccr
0x000487ed      0000           nop
0x000487ef      407c           bra @@0x7c:8
0x000487f1      b479           subx #0x79:8,r4h
0x000487f3      0200           stc ccr,r0h
0x000487f5      035e           ldc r6l,ccr
0x000487f7      0158e07a       sleep
0x000487fb      0000           nop
0x000487fd      407c           bra @@0x7c:8
0x000487ff      b47d           subx #0x7d:8,r4h
0x00048801      0072           nop
0x00048803      406a           bra @@0x6a:8
0x00048805      2800           mov.b @0x0:8,r0l
0x00048807      407c           bra @@0x7c:8
0x00048809      b4e8           subx #0xe8:8,r4h
0x0004880b      f1c8           mov.b #0xc8:8,r1h
0x0004880d      0e6a           addx r6h,r2l
0x0004880f      a800           cmp.b #0x0:8,r0l
0x00048811      407c           bra @@0x7c:8
0x00048813      b47a           subx #0x7a:8,r4h
0x00048815      0000           nop
0x00048817      407c           bra @@0x7c:8
0x00048819      b47d           subx #0x7d:8,r4h
0x0004881b      0072           nop
0x0004881d      006a           nop
0x0004881f      2800           mov.b @0x0:8,r0l
0x00048821      407c           bra @@0x7c:8
0x00048823      b46a           subx #0x6a:8,r4h
0x00048825      a800           cmp.b #0x0:8,r0l
0x00048827      2000           mov.b @0x0:8,r0h
0x00048829      427a           bhi @@0x7a:8
0x0004882b      0600           andc #0x0:8,ccr
0x0004882d      4007           bra @@0x7:8
0x0004882f      7c696079       bset #0x7:3,@r6
0x00048833      60ff           bset r7l,r7l
0x00048835      0079           nop
0x00048837      4000           bra @@0x0:8
0x00048839      f169           mov.b #0x69:8,r1h
0x0004883b      e019           and #0x19:8,r0h
0x0004883d      006b           nop
0x0004883f      a000           cmp.b #0x0:8,r0h
0x00048841      4007           bra @@0x7:8
0x00048843      78             invalid
0x00048844      7a             invalid
0x00048845      0100404e       sleep
0x00048849      48f8           bvc @@0xf8:8
0x0004884b      d568           xor #0x68:8,r5h
0x0004884d      986e           addx #0x6e:8,r0l
0x0004884f      9800           addx #0x0:8,r0l
0x00048851      01f8d56e       sleep
0x00048855      9800           addx #0x0:8,r0l
0x00048857      026e           stc ccr,r6l
0x00048859      9800           addx #0x0:8,r0l
0x0004885b      037a           ldc r2l,ccr
0x0004885d      0100404e       sleep
0x00048861      4c18           bge @@0x18:8
0x00048863      8868           add.b #0x68:8,r0l
0x00048865      986e           addx #0x6e:8,r0l
0x00048867      9800           addx #0x0:8,r0l
0x00048869      0118886e       sleep
0x0004886d      9800           addx #0x0:8,r0l
0x0004886f      026e           stc ccr,r6l
0x00048871      9800           addx #0x0:8,r0l
0x00048873      035e           ldc r6l,ccr
0x00048875      0386           ldc r6h,ccr
0x00048877      387a           mov.b r0l,@0x7a:8
0x00048879      0000           nop
0x0004887b      407c           bra @@0x7c:8
0x0004887d      b47d           subx #0x7d:8,r4h
0x0004887f      0070           nop
0x00048881      406a           bra @@0x6a:8
0x00048883      2800           mov.b @0x0:8,r0l
0x00048885      407c           bra @@0x7c:8
0x00048887      b46a           subx #0x6a:8,r4h
0x00048889      a800           cmp.b #0x0:8,r0l
0x0004888b      2000           mov.b @0x0:8,r0h
0x0004888d      4219           bhi @@0x19:8
0x0004888f      006b           nop
0x00048891      a000           cmp.b #0x0:8,r0h
0x00048893      4007           bra @@0x7:8
0x00048895      78             invalid
0x00048896      6960           mov.w @r6,r0
0x00048898      7960ff00       mov.w #0xff00:16,r0
0x0004889c      7008           bset #0x0:3,r0l
0x0004889e      69e0           mov.w r0,@r6
0x000488a0      f801           mov.b #0x1:8,r0l
0x000488a2      6aa80040       mov.b r0l,@0x40:16
0x000488a6      7cb56aa8       biand #0x2:3,@r11
0x000488aa      0040           nop
0x000488ac      7cb61888       biand #0x0:3,@r11
0x000488b0      6aa80040       mov.b r0l,@0x40:16
0x000488b4      7cb75e01       biand #0x0:3,@r11
0x000488b8      64             invalid
0x000488b9      3654           mov.b r6h,@0x54:8
0x000488bb      705e           bset #0x5:3,r6l
0x000488bd      0164587a       sleep
0x000488c1      0600           andc #0x0:8,ccr
0x000488c3      4007           bra @@0x7:8
0x000488c5      7c01006b       biand #0x6:3,@r0
0x000488c9      2000           mov.b @0x0:8,r0h
0x000488cb      407c           bra @@0x7c:8
0x000488cd      ae6e           cmp.b #0x6e:8,r6l
0x000488cf      0900           add.w r0,r0
0x000488d1      047a           orc #0x7a:8,ccr
0x000488d3      0000           nop
0x000488d5      407c           bra @@0x7c:8
0x000488d7      b479           subx #0x79:8,r4h
0x000488d9      0200           stc ccr,r0h
0x000488db      035e           ldc r6l,ccr
0x000488dd      0158e07a       sleep
0x000488e1      0000           nop
0x000488e3      407c           bra @@0x7c:8
0x000488e5      b47d           subx #0x7d:8,r4h
0x000488e7      0072           nop
0x000488e9      406a           bra @@0x6a:8
0x000488eb      2800           mov.b @0x0:8,r0l
0x000488ed      407c           bra @@0x7c:8
0x000488ef      b4e8           subx #0xe8:8,r4h
0x000488f1      f1c8           mov.b #0xc8:8,r1h
0x000488f3      0e6a           addx r6h,r2l
0x000488f5      a800           cmp.b #0x0:8,r0l
0x000488f7      407c           bra @@0x7c:8
0x000488f9      b47a           subx #0x7a:8,r4h
0x000488fb      0000           nop
0x000488fd      407c           bra @@0x7c:8
0x000488ff      b47d           subx #0x7d:8,r4h
0x00048901      0070           nop
0x00048903      006a           nop
0x00048905      2800           mov.b @0x0:8,r0l
0x00048907      407c           bra @@0x7c:8
0x00048909      b46a           subx #0x6a:8,r4h
0x0004890b      a800           cmp.b #0x0:8,r0l
0x0004890d      2000           mov.b @0x0:8,r0h
0x0004890f      4269           bhi @@0x69:8
0x00048911      6079           bset r7h,r1l
0x00048913      60ff           bset r7l,r7l
0x00048915      0079           nop
0x00048917      4000           bra @@0x0:8
0x00048919      f169           mov.b #0x69:8,r1h
0x0004891b      e019           and #0x19:8,r0h
0x0004891d      006b           nop
0x0004891f      a000           cmp.b #0x0:8,r0h
0x00048921      4007           bra @@0x7:8
0x00048923      78             invalid
0x00048924      6a2800         mov.b @0x10:16,r0l
0x00048928      7cb5460e       biand #0x0:3,@r11
0x0004892c      6a280040       mov.b @0x40:16,r0l
0x00048930      7cb2a801       biand #0x0:3,@r11
0x00048934      4604           bne @@0x4:8
0x00048936      5e037d18       jsr @0x7d18:16
0x0004893a      5e038638       jsr @0x8638:16
0x0004893e      7a             invalid
0x0004893f      0000           nop
0x00048941      407c           bra @@0x7c:8
0x00048943      b47d           subx #0x7d:8,r4h
0x00048945      0070           nop
0x00048947      406a           bra @@0x6a:8
0x00048949      2800           mov.b @0x0:8,r0l
0x0004894b      407c           bra @@0x7c:8
0x0004894d      b46a           subx #0x6a:8,r4h
0x0004894f      a800           cmp.b #0x0:8,r0l
0x00048951      2000           mov.b @0x0:8,r0h
0x00048953      4219           bhi @@0x19:8
0x00048955      006b           nop
0x00048957      a000           cmp.b #0x0:8,r0h
0x00048959      4007           bra @@0x7:8
0x0004895b      78             invalid
0x0004895c      6960           mov.w @r6,r0
0x0004895e      7960ff00       mov.w #0xff00:16,r0
0x00048962      7008           bset #0x0:3,r0l
0x00048964      69e0           mov.w r0,@r6
0x00048966      f801           mov.b #0x1:8,r0l
0x00048968      6aa80040       mov.b r0l,@0x40:16
0x0004896c      7cb56aa8       biand #0x2:3,@r11
0x00048970      0040           nop
0x00048972      7cb61888       biand #0x0:3,@r11
0x00048976      6aa80040       mov.b r0l,@0x40:16
0x0004897a      7cb75e01       biand #0x0:3,@r11
0x0004897e      64             invalid
0x0004897f      3654           mov.b r6h,@0x54:8
0x00048981      7054           bset #0x5:3,r4h
0x00048983      705a           bset #0x5:3,r2l
0x00048985      fffe           mov.b #0xfe:8,r7l
0x00048987      0001           nop
0x00048989      006d           nop
0x0004898b      f001           mov.b #0x1:8,r0h
0x0004898d      006d           nop
0x0004898f      f101           mov.b #0x1:8,r1h
0x00048991      006d           nop
0x00048993      f27a           mov.b #0x7a:8,r2h
0x00048995      0000           nop
0x00048997      0489           orc #0x89:8,ccr
0x00048999      bc7a           subx #0x7a:8,r4l
0x0004899b      0100fffe       sleep
0x0004899f      006d           nop
0x000489a1      0269           stc ccr,r1l
0x000489a3      920b           addx #0xb:8,r2h
0x000489a5      f17a           mov.b #0x7a:8,r1h
0x000489a7      2000           mov.b @0x0:8,r0h
0x000489a9      0489           orc #0x89:8,ccr
0x000489ab      f845           mov.b #0x45:8,r0l
0x000489ad      f201           mov.b #0x1:8,r2h
0x000489af      006d           nop
0x000489b1      7201           bclr #0x0:3,r1h
0x000489b3      006d           nop
0x000489b5      7101           bnot #0x0:3,r1h
0x000489b7      006d           nop
0x000489b9      7054           bset #0x5:3,r4h
0x000489bb      7001           bset #0x0:3,r1h
0x000489bd      006d           nop
0x000489bf      f301           mov.b #0x1:8,r3h
0x000489c1      006d           nop
0x000489c3      f401           mov.b #0x1:8,r4h
0x000489c5      006d           nop
0x000489c7      f501           mov.b #0x1:8,r5h
0x000489c9      006b           nop
0x000489cb      2400           mov.b @0x0:8,r4h
0x000489cd      404e           bra @@0x4e:8
0x000489cf      b26b           subx #0x6b:8,r2h
0x000489d1      2300           mov.b @0x0:8,r3h
0x000489d3      400e           bra @@0xe:8
0x000489d5      8a1a           add.b #0x1a:8,r2l
0x000489d7      8019           add.b #0x19:8,r0h
0x000489d9      dd6d           xor #0x6d:8,r5l
0x000489db      450a           bcs @@0xa:8
0x000489dd      d01b           xor #0x1b:8,r0h
0x000489df      53             invalid
0x000489e0      46f8           bne @@0xf8:8
0x000489e2      01006ba0       sleep
0x000489e6      0040           nop
0x000489e8      4e5a           bgt @@0x5a:8
0x000489ea      01006d75       sleep
0x000489ee      01006d74       sleep
0x000489f2      01006d73       sleep
0x000489f6      5470           rts
0x000489f8      5afffe00       jmp @0xfe00:16
0x000489fc      01006df0       sleep
0x00048a00      01006df1       sleep
0x00048a04      01006df2       sleep
0x00048a08      7a             invalid
0x00048a09      0000           nop
0x00048a0b      048a           orc #0x8a:8,ccr
0x00048a0d      307a           mov.b r0h,@0x7a:8
0x00048a0f      0100fffe       sleep
0x00048a13      006d           nop
0x00048a15      0269           stc ccr,r1l
0x00048a17      920b           addx #0xb:8,r2h
0x00048a19      f17a           mov.b #0x7a:8,r1h
0x00048a1b      2000           mov.b @0x0:8,r0h
0x00048a1d      048a           orc #0x8a:8,ccr
0x00048a1f      7645           band #0x4:3,r5h
0x00048a21      f201           mov.b #0x1:8,r2h
0x00048a23      006d           nop
0x00048a25      7201           bclr #0x0:3,r1h
0x00048a27      00             nop
0x00048a29      7101           bnot #0x0:3,r1h
0x00048a2b      006d           nop
0x00048a2d      7054           bset #0x5:3,r4h
0x00048a2f      7001           bset #0x0:3,r1h
0x00048a31      006d           nop
0x00048a33      f301           mov.b #0x1:8,r3h
0x00048a35      006d           nop
0x00048a37      f401           mov.b #0x1:8,r4h
0x00048a39      006d           nop
0x00048a3b      f501           mov.b #0x1:8,r5h
0x00048a3d      006b           nop
0x00048a3f      2400           mov.b @0x0:8,r4h
0x00048a41      404e           bra @@0x4e:8
0x00048a43      b26b           subx #0x6b:8,r2h
0x00048a45      2300           mov.b @0x0:8,r3h
0x00048a47      400e           bra @@0xe:8
0x00048a49      8a0d           add.b #0xd:8,r2l
0x00048a4b      311a           mov.b r1h,@0x1a:8
0x00048a4d      8019           add.b #0x19:8,r0h
0x00048a4f      dd6d           xor #0x6d:8,r5l
0x00048a51      450a           bcs @@0xa:8
0x00048a53      d01b           xor #0x1b:8,r0h
0x00048a55      53             invalid
0x00048a56      46f8           bne @@0xf8:8
0x00048a58      53             invalid
0x00048a59      106b           shal r3l
0x00048a5b      2300           mov.b @0x0:8,r3h
0x00048a5d      404e           bra @@0x4e:8
0x00048a5f      58             invalid
0x00048a60      0903           add.w r0,r3
0x00048a62      6ba30040       mov.w r3,@0x40:16
0x00048a66      4e58           bgt @@0x58:8
0x00048a68      01006d75       sleep
0x00048a6c      01006d74       sleep
0x00048a70      01006d73       sleep
0x00048a74      5470           rts
0x00048a76      5afffe00       jmp @0xfe00:16
0x00048a7a      01006df0       sleep
0x00048a7e      01006df1       sleep
0x00048a82      01006df2       sleep
0x00048a86      7a             invalid
0x00048a87      0000           nop
0x00048a89      048a           orc #0x8a:8,ccr
0x00048a8b      ae7a           cmp.b #0x7a:8,r6l
0x00048a8d      0100fffe       sleep
0x00048a91      006d           nop
0x00048a93      0269           stc ccr,r1l
0x00048a95      920b           addx #0xb:8,r2h
0x00048a97      f17a           mov.b #0x7a:8,r1h
0x00048a99      2000           mov.b @0x0:8,r0h
0x00048a9b      048a           orc #0x8a:8,ccr
0x00048a9d      fe45           mov.b #0x45:8,r6l
0x00048a9f      f201           mov.b #0x1:8,r2h
0x00048aa1      006d           nop
0x00048aa3      7201           bclr #0x0:3,r1h
0x00048aa5      006d           nop
0x00048aa7      7101           bnot #0x0:3,r1h
0x00048aa9      006d           nop
0x00048aab      7054           bset #0x5:3,r4h
0x00048aad      7001           bset #0x0:3,r1h
0x00048aaf      006d           nop
0x00048ab1      f301           mov.b #0x1:8,r3h
0x00048ab3      006d           nop
0x00048ab5      f401           mov.b #0x1:8,r4h
0x00048ab7      006d           nop
0x00048ab9      f501           mov.b #0x1:8,r5h
0x00048abb      006b           nop
0x00048abd      2000           mov.b @0x0:8,r0h
0x00048abf      404e           bra @@0x4e:8
0x00048ac1      b26b           subx #0x6b:8,r2h
0x00048ac3      2300           mov.b @0x0:8,r3h
0x00048ac5      400e           bra @@0xe:8
0x00048ac7      8a0d           add.b #0xd:8,r2l
0x00048ac9      3b79           mov.b r3l,@0x79:8
0x00048acb      01ffff0d       sleep
0x00048acf      1d1a           cmp.w r1,r2
0x00048ad1      9119           addx #0x19:8,r1h
0x00048ad3      cc6d           or #0x6d:8,r4l
0x00048ad5      041d           orc #0x1d:8,ccr
0x00048ad7      d444           xor #0x44:8,r4h
0x00048ad9      020d           stc ccr,r5l
0x00048adb      4d0a           blt @@0xa:8
0x00048add      c11b           or #0x1b:8,r1h
0x00048adf      53             invalid
0x00048ae0      46f2           bne @@0xf2:8
0x00048ae2      53             invalid
0x00048ae3      b16b           subx #0x6b:8,r1h
0x00048ae5      a100           cmp.b #0x0:8,r1h
0x00048ae7      404e           bra @@0x4e:8
0x00048ae9      58             invalid
0x00048aea      6bad0040       mov.w r5,@0x40:16
0x00048aee      4e54           bgt @@0x54:8
0x00048af0      01006d75       sleep
0x00048af4      01006d74       sleep
0x00048af8      01006d73       sleep
0x00048afc      5470           rts
0x00048afe      01006df3       sleep
0x00048b02      01006df4       sleep
0x00048b06      01006df5       sleep
0x00048b0a      1a80           dec r0h
0x00048b0c      6a280040       mov.b @0x40:16,r0l
0x00048b10      4e97           bgt @@0x97:8
0x00048b12      1008           shll r0l
0x00048b14      79011000       mov.w #0x1000:16,r1
0x00048b18      52             invalid
0x00048b19      017a1100       sleep
0x00048b1d      8300           add.b #0x0:8,r3h
0x00048b1f      006b           nop
0x00048b21      2000           mov.b @0x0:8,r0h
0x00048b23      400e           bra @@0xe:8
0x00048b25      8c10           add.b #0x10:8,r4l
0x00048b27      100a           shll r2l
0x00048b29      816a           add.b #0x6a:8,r1h
0x00048b2b      2b00           mov.b @0x0:8,r3l
0x00048b2d      404e           bra @@0x4e:8
0x00048b2f      7317           btst #0x1:3,r7h
0x00048b31      53             invalid
0x00048b32      0d3b           mov.w r3,r3
0x00048b34      7a             invalid
0x00048b35      0000           nop
0x00048b37      4010           bra @@0x10:8
0x00048b39      a001           cmp.b #0x1:8,r0h
0x00048b3b      006b           nop
0x00048b3d      2500           mov.b @0x0:8,r5h
0x00048b3f      404e           bra @@0x4e:8
0x00048b41      626b           bclr r6h,r3l
0x00048b43      2300           mov.b @0x0:8,r3h
0x00048b45      400e           bra @@0xe:8
0x00048b47      8a01           add.b #0x1:8,r2l
0x00048b49      006d           nop
0x00048b4b      041a           orc #0x1a:8,ccr
0x00048b4d      d453           xor #0x53:8,r4h
0x00048b4f      b469           subx #0x69:8,r4h
0x00048b51      940b           addx #0xb:8,r4h
0x00048b53      f11b           mov.b #0x1b:8,r1h
0x00048b55      53             invalid
0x00048b56      46f0           bne @@0xf0:8
0x00048b58      01006d75       sleep
0x00048b5c      01006d74       sleep
0x00048b60      01006d73       sleep
0x00048b64      5470           rts
0x00048b66      01006df4       sleep
0x00048b6a      01006df5       sleep
0x00048b6e      01006df6       sleep
0x00048b72      01006b25       sleep
0x00048b76      0040           nop
0x00048b78      4eb2           bgt @@0xb2:8
0x00048b7a      7a             invalid
0x00048b7b      0600           andc #0x0:8,ccr
0x00048b7d      4010           bra @@0x10:8
0x00048b7f      a06b           cmp.b #0x6b:8,r0h
0x00048b81      2400           mov.b @0x0:8,r4h
0x00048b83      400e           bra @@0xe:8
0x00048b85      8a19           add.b #0x19:8,r2l
0x00048b87      886d           add.b #0x6d:8,r0l
0x00048b89      5001           mulxu r0h,r1
0x00048b8b      0069           nop
0x00048b8d      e00b           and #0xb:8,r0h
0x00048b8f      f60b           mov.b #0xb:8,r6h
0x00048b91      f61b           mov.b #0x1b:8,r6h
0x00048b93      5446           rts
0x00048b95      f201           mov.b #0x1:8,r2h
0x00048b97      006d           nop
0x00048b99      7601           band #0x0:3,r1h
0x00048b9b      006d           nop
0x00048b9d      7501           bxor #0x0:3,r1h
0x00048b9f      006d           nop
0x00048ba1      7454           bor #0x5:3,r4h
0x00048ba3      7001           bset #0x0:3,r1h
0x00048ba5      006d           nop
0x00048ba7      f401           mov.b #0x1:8,r4h
0x00048ba9      006d           nop
0x00048bab      f501           mov.b #0x1:8,r5h
0x00048bad      006d           nop
0x00048baf      f601           mov.b #0x1:8,r6h
0x00048bb1      006b           nop
0x00048bb3      2500           mov.b @0x0:8,r5h
0x00048bb5      404e           bra @@0x4e:8
0x00048bb7      b27a           subx #0x7a:8,r2h
0x00048bb9      0600           andc #0x0:8,ccr
0x00048bbb      4010           bra @@0x10:8
0x00048bbd      a06b           cmp.b #0x6b:8,r0h
0x00048bbf      2400           mov.b @0x0:8,r4h
0x00048bc1      400e           bra @@0xe:8
0x00048bc3      8a19           add.b #0x19:8,r2l
0x00048bc5      886d           add.b #0x6d:8,r0l
0x00048bc7      5001           mulxu r0h,r1
0x00048bc9      0069           nop
0x00048bcb      e00b           and #0xb:8,r0h
0x00048bcd      f60b           mov.b #0xb:8,r6h
0x00048bcf      f61b           mov.b #0x1b:8,r6h
0x00048bd1      5446           rts
0x00048bd3      f201           mov.b #0x1:8,r2h
0x00048bd5      006d           nop
0x00048bd7      7601           band #0x0:3,r1h
0x00048bd9      006d           nop
0x00048bdb      7501           bxor #0x0:3,r1h
0x00048bdd      006d           nop
0x00048bdf      7454           bor #0x5:3,r4h
0x00048be1      705a           bset #0x5:3,r2l
0x00048be3      fffe           mov.b #0xfe:8,r7l
0x00048be5      aa5a           cmp.b #0x5a:8,r2l
0x00048be7      fffe           mov.b #0xfe:8,r7l
0x00048be9      005a           nop
0x00048beb      fffe           mov.b #0xfe:8,r7l
0x00048bed      64             invalid
0x00048bee      01006df0       sleep
0x00048bf2      01006df1       sleep
0x00048bf6      01006df2       sleep
0x00048bfa      7a             invalid
0x00048bfb      0000           nop
0x00048bfd      048c           orc #0x8c:8,ccr
0x00048bff      227a           mov.b @0x7a:8,r2h
0x00048c01      0100fffe       sleep
0x00048c05      006d           nop
0x00048c07      0269           stc ccr,r1l
0x00048c09      920b           addx #0xb:8,r2h
0x00048c0b      f17a           mov.b #0x7a:8,r1h
0x00048c0d      2000           mov.b @0x0:8,r0h
0x00048c0f      048d           orc #0x8d:8,ccr
0x00048c11      1045           shal r5h
0x00048c13      f201           mov.b #0x1:8,r2h
0x00048c15      006d           nop
0x00048c17      7201           bclr #0x0:3,r1h
0x00048c19      006d           nop
0x00048c1b      7101           bnot #0x0:3,r1h
0x00048c1d      006d           nop
0x00048c1f      7054           bset #0x5:3,r4h
0x00048c21      7001           bset #0x0:3,r1h
0x00048c23      006d           nop
0x00048c25      f301           mov.b #0x1:8,r3h
0x00048c27      006d           nop
0x00048c29      f401           mov.b #0x1:8,r4h
0x00048c2b      006d           nop
0x00048c2d      f57a           mov.b #0x7a:8,r5h
0x00048c2f      0000           nop
0x00048c31      4010           bra @@0x10:8
0x00048c33      a07a           cmp.b #0x7a:8,r0h
0x00048c35      0500           xorc #0x0:8,ccr
0x00048c37      4010           bra @@0x10:8
0x00048c39      a06a           cmp.b #0x6a:8,r0h
0x00048c3b      2b00           mov.b @0x0:8,r3l
0x00048c3d      404e           bra @@0x4e:8
0x00048c3f      7317           btst #0x1:3,r7h
0x00048c41      53             invalid
0x00048c42      6b2b0040       mov.w @0x40:16,r3
0x00048c46      0e8a           addx r0l,r2l
0x00048c48      19cc           sub.w r12,r4
0x00048c4a      7904ffff       mov.w #0xffff:16,r4
0x00048c4e      01006901       sleep
0x00048c52      53             invalid
0x00048c53      3169           mov.b r1h,@0x69:8
0x00048c55      d10b           xor #0xb:8,r1h
0x00048c57      f00b           mov.b #0xb:8,r0h
0x00048c59      f00b           mov.b #0xb:8,r0h
0x00048c5b      f51d           mov.b #0x1d:8,r5h
0x00048c5d      1c44           cmp.b r4h,r4h
0x00048c5f      020d           stc ccr,r5l
0x00048c61      1c1d           cmp.b r1h,r5l
0x00048c63      4144           brn @@0x44:8
0x00048c65      020d           stc ccr,r5l
0x00048c67      141b           or r1h,r3l
0x00048c69      5b46           jmp @@0x46:8
0x00048c6b      e26b           and #0x6b:8,r2h
0x00048c6d      ac00           cmp.b #0x0:8,r4l
0x00048c6f      404e           bra @@0x4e:8
0x00048c71      566b           rte
0x00048c73      a400           cmp.b #0x0:8,r4h
0x00048c75      404e           bra @@0x4e:8
0x00048c77      5401           rts
0x00048c79      006d           nop
0x00048c7b      7501           bxor #0x0:3,r1h
0x00048c7d      006d           nop
0x00048c7f      7401           bor #0x0:3,r1h
0x00048c81      006d           nop
0x00048c83      7354           btst #0x5:3,r4h
0x00048c85      7001           bset #0x0:3,r1h
0x00048c87      006d           nop
0x00048c89      f301           mov.b #0x1:8,r3h
0x00048c8b      006d           nop
0x00048c8d      f401           mov.b #0x1:8,r4h
0x00048c8f      006b           nop
0x00048c91      2000           mov.b @0x0:8,r0h
0x00048c93      404e           bra @@0x4e:8
0x00048c95      b26b           subx #0x6b:8,r2h
0x00048c97      2b00           mov.b @0x0:8,r3l
0x00048c99      400e           bra @@0xe:8
0x00048c9b      8a19           add.b #0x19:8,r2l
0x00048c9d      cc79           or #0x79:8,r4l
0x00048c9f      04ff           orc #0xff:8,ccr
0x00048ca1      ff69           mov.b #0x69:8,r7l
0x00048ca3      010bf01d       sleep
0x00048ca7      1c44           cmp.b r4h,r4h
0x00048ca9      020d           stc ccr,r5l
0x00048cab      1c1d           cmp.b r1h,r5l
0x00048cad      4144           brn @@0x44:8
0x00048caf      020d           stc ccr,r5l
0x00048cb1      141b           or r1h,r3l
0x00048cb3      5b46           jmp @@0x46:8
0x00048cb5      ec6b           and #0x6b:8,r4l
0x00048cb7      ac00           cmp.b #0x0:8,r4l
0x00048cb9      404e           bra @@0x4e:8
0x00048cbb      566b           rte
0x00048cbd      a400           cmp.b #0x0:8,r4h
0x00048cbf      404e           bra @@0x4e:8
0x00048cc1      5401           rts
0x00048cc3      006d           nop
0x00048cc5      7401           bor #0x0:3,r1h
0x00048cc7      006d           nop
0x00048cc9      7354           btst #0x5:3,r4h
0x00048ccb      7001           bset #0x0:3,r1h
0x00048ccd      006d           nop
0x00048ccf      f301           mov.b #0x1:8,r3h
0x00048cd1      006d           nop
0x00048cd3      f401           mov.b #0x1:8,r4h
0x00048cd5      006d           nop
0x00048cd7      f501           mov.b #0x1:8,r5h
0x00048cd9      006b           nop
0x00048cdb      2000           mov.b @0x0:8,r0h
0x00048cdd      404e           bra @@0x4e:8
0x00048cdf      b27a           subx #0x7a:8,r2h
0x00048ce1      01004010       sleep
0x00048ce5      a06b           cmp.b #0x6b:8,r0h
0x00048ce7      2300           mov.b @0x0:8,r3h
0x00048ce9      400e           bra @@0xe:8
0x00048ceb      8a6d           add.b #0x6d:8,r2l
0x00048ced      0419           orc #0x19:8,ccr
0x00048cef      cc01           or #0x1:8,r4l
0x00048cf1      0069           nop
0x00048cf3      150a           xor r0h,r2l
0x00048cf5      d401           xor #0x1:8,r4h
0x00048cf7      0069           nop
0x00048cf9      940b           addx #0xb:8,r4h
0x00048cfb      f10b           mov.b #0xb:8,r1h
0x00048cfd      f11b           mov.b #0x1b:8,r1h
0x00048cff      53             invalid
0x00048d00      46ea           bne @@0xea:8
0x00048d02      01006d75       sleep
0x00048d06      01006d74       sleep
0x00048d0a      01006d73       sleep
0x00048d0e      5470           rts
0x00048d10      5afffe00       jmp @0xfe00:16
0x00048d14      5afffe44       jmp @0xfe44:16
0x00048d18      5afffe86       jmp @0xfe86:16
0x00048d1c      01006df0       sleep
0x00048d20      01006df1       sleep
0x00048d24      01006df2       sleep
0x00048d28      7a             invalid
0x00048d29      0000           nop
0x00048d2b      048d           orc #0x8d:8,ccr
0x00048d2d      507a           mulxu r7h,r2
0x00048d2f      0100fffe       sleep
0x00048d33      006d           nop
0x00048d35      0269           stc ccr,r1l
0x00048d37      920b           addx #0xb:8,r2h
0x00048d39      f17a           mov.b #0x7a:8,r1h
0x00048d3b      2000           mov.b @0x0:8,r0h
0x00048d3d      048e           orc #0x8e:8,ccr
0x00048d3f      3e45           mov.b r6l,@0x45:8
0x00048d41      f201           mov.b #0x1:8,r2h
0x00048d43      006d           nop
0x00048d45      7201           bclr #0x0:3,r1h
0x00048d47      006d           nop
0x00048d49      7101           bnot #0x0:3,r1h
0x00048d4b      006d           nop
0x00048d4d      7054           bset #0x5:3,r4h
0x00048d4f      7001           bset #0x0:3,r1h
0x00048d51      006d           nop
0x00048d53      f301           mov.b #0x1:8,r3h
0x00048d55      006d           nop
0x00048d57      f401           mov.b #0x1:8,r4h
0x00048d59      006d           nop
0x00048d5b      f501           mov.b #0x1:8,r5h
0x00048d5d      006b           nop
0x00048d5f      2000           mov.b @0x0:8,r0h
0x00048d61      404e           bra @@0x4e:8
0x00048d63      b27a           subx #0x7a:8,r2h
0x00048d65      01004010       sleep
0x00048d69      a06b           cmp.b #0x6b:8,r0h
0x00048d6b      2300           mov.b @0x0:8,r3h
0x00048d6d      400e           bra @@0xe:8
0x00048d6f      8a6d           add.b #0x6d:8,r2l
0x00048d71      0419           orc #0x19:8,ccr
0x00048d73      cc01           or #0x1:8,r4l
0x00048d75      0069           nop
0x00048d77      150a           xor r0h,r2l
0x00048d79      d401           xor #0x1:8,r4h
0x00048d7b      0069           nop
0x00048d7d      940b           addx #0xb:8,r4h
0x00048d7f      f10b           mov.b #0xb:8,r1h
0x00048d81      f11b           mov.b #0x1b:8,r1h
0x00048d83      53             invalid
0x00048d84      46ea           bne @@0xea:8
0x00048d86      01006d75       sleep
0x00048d8a      01006d74       sleep
0x00048d8e      01006d73       sleep
0x00048d92      5470           rts
0x00048d94      01006df3       sleep
0x00048d98      01006df4       sleep
0x00048d9c      01006df5       sleep
0x00048da0      7a             invalid
0x00048da1      0000           nop
0x00048da3      4010           bra @@0x10:8
0x00048da5      a06b           cmp.b #0x6b:8,r0h
0x00048da7      2300           mov.b @0x0:8,r3h
0x00048da9      400e           bra @@0xe:8
0x00048dab      8a7a           add.b #0x7a:8,r2l
0x00048dad      05ff           xorc #0xff:8,ccr
0x00048daf      ffff           mov.b #0xff:8,r7l
0x00048db1      ff01           mov.b #0x1:8,r7l
0x00048db3      006d           nop
0x00048db5      041f           orc #0x1f:8,ccr
0x00048db7      d444           xor #0x44:8,r4h
0x00048db9      020f           stc ccr,r7l
0x00048dbb      c51b           or #0x1b:8,r5h
0x00048dbd      53             invalid
0x00048dbe      46f2           bne @@0xf2:8
0x00048dc0      01006ba5       sleep
0x00048dc4      0040           nop
0x00048dc6      4e62           bgt @@0x62:8
0x00048dc8      01006d75       sleep
0x00048dcc      01006d74       sleep
0x00048dd0      01006d73       sleep
0x00048dd4      5470           rts
0x00048dd6      01006df2       sleep
0x00048dda      01006df3       sleep
0x00048dde      01006df4       sleep
0x00048de2      01006df5       sleep
0x00048de6      7a             invalid
0x00048de7      0000           nop
0x00048de9      4010           bra @@0x10:8
0x00048deb      a06b           cmp.b #0x6b:8,r0h
0x00048ded      2300           mov.b @0x0:8,r3h
0x00048def      400e           bra @@0xe:8
0x00048df1      8a0d           add.b #0xd:8,r2l
0x00048df3      3b7a           mov.b r3l,@0x7a:8
0x00048df5      05ff           xorc #0xff:8,ccr
0x00048df7      ffff           mov.b #0xff:8,r7l
0x00048df9      ff1a           mov.b #0x1a:8,r7l
0x00048dfb      a21a           cmp.b #0x1a:8,r2h
0x00048dfd      9101           addx #0x1:8,r1h
0x00048dff      006d           nop
0x00048e01      040a           orc #0xa:8,ccr
0x00048e03      c11f           or #0x1f:8,r1h
0x00048e05      d444           xor #0x44:8,r4h
0x00048e07      020f           stc ccr,r7l
0x00048e09      c51f           or #0x1f:8,r5h
0x00048e0b      a445           cmp.b #0x45:8,r4h
0x00048e0d      020f           stc ccr,r7l
0x00048e0f      c21b           or #0x1b:8,r2h
0x00048e11      53             invalid
0x00048e12      46ea           bne @@0xea:8
0x00048e14      01006ba1       sleep
0x00048e18      0040           nop
0x00048e1a      4e5e           bgt @@0x5e:8
0x00048e1c      01006ba2       sleep
0x00048e20      0040           nop
0x00048e22      4e66           bgt @@0x66:8
0x00048e24      01006ba5       sleep
0x00048e28      00             nop
0x00048e2a      4e62           bgt @@0x62:8
0x00048e2c      01006d75       sleep
0x00048e30      01006d74       sleep
0x00048e34      01006d73       sleep
0x00048e38      01006d72       sleep
0x00048e3c      5470           rts
0x00048e3e      01006df3       sleep
0x00048e42      01006df4       sleep
0x00048e46      7a             invalid
0x00048e47      0000           nop
0x00048e49      4010           bra @@0x10:8
0x00048e4b      a06b           cmp.b #0x6b:8,r0h
0x00048e4d      2300           mov.b @0x0:8,r3h
0x00048e4f      400e           bra @@0xe:8
0x00048e51      8a1a           add.b #0x1a:8,r2l
0x00048e53      9101           addx #0x1:8,r1h
0x00048e55      0069           nop
0x00048e57      0201           stc ccr,r1h
0x00048e59      006d           nop
0x00048e5b      0401           orc #0x1:8,ccr
0x00048e5d      006d           nop
0x00048e5f      f41f           mov.b #0x1f:8,r4h
0x00048e61      a458           cmp.b #0x58:8,r4h
0x00048e63      4000           bra @@0x0:8
0x00048e65      0e1a           addx r1h,r2l
0x00048e67      c21f           or #0x1f:8,r2h
0x00048e69      a158           cmp.b #0x58:8,r1h
0x00048e6b      4000           bra @@0x0:8
0x00048e6d      100f           shll r7l
0x00048e6f      a158           cmp.b #0x58:8,r1h
0x00048e71      0000           nop
0x00048e73      0a1a           inc r2l
0x00048e75      a41f           cmp.b #0x1f:8,r4h
0x00048e77      c158           or #0x58:8,r1h
0x00048e79      4000           bra @@0x0:8
0x00048e7b      020f           stc ccr,r7l
0x00048e7d      c101           or #0x1:8,r1h
0x00048e7f      006d           nop
0x00048e81      721b           bclr #0x1:3,r3l
0x00048e83      53             invalid
0x00048e84      46d2           bne @@0xd2:8
0x00048e86      01006ba1       sleep
0x00048e8a      0040           nop
0x00048e8c      4e6e           bgt @@0x6e:8
0x00048e8e      01006d74       sleep
0x00048e92      01006d73       sleep
0x00048e96      5470           rts
0x00048e98      01006df3       sleep
0x00048e9c      01006df4       sleep
0x00048ea0      7a             invalid
0x00048ea1      0000           nop
0x00048ea3      4010           bra @@0x10:8
0x00048ea5      a06b           cmp.b #0x6b:8,r0h
0x00048ea7      2100           mov.b @0x0:8,r1h
0x00048ea9      400e           bra @@0xe:8
0x00048eab      9010           addx #0x10:8,r0h
0x00048ead      1119           shar r1l
0x00048eaf      990a           addx #0xa:8,r1l
0x00048eb1      906b           addx #0x6b:8,r0h
0x00048eb3      2b00           mov.b @0x0:8,r3l
0x00048eb5      400e           bra @@0xe:8
0x00048eb7      8e19           add.b #0x19:8,r6l
0x00048eb9      cc79           or #0x79:8,r4l
0x00048ebb      04ff           orc #0xff:8,ccr
0x00048ebd      ff69           mov.b #0x69:8,r7l
0x00048ebf      010bf01d       sleep
0x00048ec3      1c44           cmp.b r4h,r4h
0x00048ec5      020d           stc ccr,r5l
0x00048ec7      1c1d           cmp.b r1h,r5l
0x00048ec9      4144           brn @@0x44:8
0x00048ecb      020d           stc ccr,r5l
0x00048ecd      141b           or r1h,r3l
0x00048ecf      5b46           jmp @@0x46:8
0x00048ed1      ec6b           and #0x6b:8,r4l
0x00048ed3      ac00           cmp.b #0x0:8,r4l
0x00048ed5      404e           bra @@0x4e:8
0x00048ed7      846b           add.b #0x6b:8,r4h
0x00048ed9      a400           cmp.b #0x0:8,r4h
0x00048edb      404e           bra @@0x4e:8
0x00048edd      8201           add.b #0x1:8,r2h
0x00048edf      006d           nop
0x00048ee1      7401           bor #0x0:3,r1h
0x00048ee3      006d           nop
0x00048ee5      7354           btst #0x5:3,r4h
0x00048ee7      705a           bset #0x5:3,r2l
0x00048ee9      fffe           mov.b #0xfe:8,r7l
0x00048eeb      005a           nop
0x00048eed      fffe           mov.b #0xfe:8,r7l
0x00048eef      5e01006d       jsr @0x6d:16
0x00048ef3      f001           mov.b #0x1:8,r0h
0x00048ef5      006d           nop
0x00048ef7      f101           mov.b #0x1:8,r1h
0x00048ef9      006d           nop
0x00048efb      f27a           mov.b #0x7a:8,r2h
0x00048efd      0000           nop
0x00048eff      048f           orc #0x8f:8,ccr
0x00048f01      247a           mov.b @0x7a:8,r4h
0x00048f03      0100fffe       sleep
0x00048f07      006d           nop
0x00048f09      0269           stc ccr,r1l
0x00048f0b      920b           addx #0xb:8,r2h
0x00048f0d      f17a           mov.b #0x7a:8,r1h
0x00048f0f      2000           mov.b @0x0:8,r0h
0x00048f11      048f           orc #0x8f:8,ccr
0x00048f13      ae45           cmp.b #0x45:8,r6l
0x00048f15      f201           mov.b #0x1:8,r2h
0x00048f17      006d           nop
0x00048f19      7201           bclr #0x0:3,r1h
0x00048f1b      006d           nop
0x00048f1d      7101           bnot #0x0:3,r1h
0x00048f1f      006d           nop
0x00048f21      7054           bset #0x5:3,r4h
0x00048f23      7001           bset #0x0:3,r1h
0x00048f25      006d           nop
0x00048f27      f301           mov.b #0x1:8,r3h
0x00048f29      00             nop
0x00048f2b      f401           mov.b #0x1:8,r4h
0x00048f2d      006d           nop
0x00048f2f      f501           mov.b #0x1:8,r5h
0x00048f31      006b           nop
0x00048f33      2000           mov.b @0x0:8,r0h
0x00048f35      404e           bra @@0x4e:8
0x00048f37      b26b           subx #0x6b:8,r2h
0x00048f39      2300           mov.b @0x0:8,r3h
0x00048f3b      400e           bra @@0xe:8
0x00048f3d      8a0d           add.b #0xd:8,r2l
0x00048f3f      3b19           mov.b r3l,@0x19:8
0x00048f41      dd79           xor #0x79:8,r5l
0x00048f43      05ff           xorc #0xff:8,ccr
0x00048f45      ff1a           mov.b #0x1a:8,r7l
0x00048f47      9119           addx #0x19:8,r1h
0x00048f49      cc6d           or #0x6d:8,r4l
0x00048f4b      041d           orc #0x1d:8,ccr
0x00048f4d      4d44           blt @@0x44:8
0x00048f4f      040d           orc #0xd:8,ccr
0x00048f51      4d40           blt @@0x40:8
0x00048f53      061d           andc #0x1d:8,ccr
0x00048f55      5444           rts
0x00048f57      020d           stc ccr,r5l
0x00048f59      450a           bcs @@0xa:8
0x00048f5b      c11b           or #0x1b:8,r1h
0x00048f5d      53             invalid
0x00048f5e      46ea           bne @@0xea:8
0x00048f60      53             invalid
0x00048f61      b16b           subx #0x6b:8,r1h
0x00048f63      a100           cmp.b #0x0:8,r1h
0x00048f65      404e           bra @@0x4e:8
0x00048f67      58             invalid
0x00048f68      6bad0040       mov.w r5,@0x40:16
0x00048f6c      4e56           bgt @@0x56:8
0x00048f6e      6ba50040       mov.w r5,@0x40:16
0x00048f72      4e54           bgt @@0x54:8
0x00048f74      01006d75       sleep
0x00048f78      01006d74       sleep
0x00048f7c      01006d73       sleep
0x00048f80      5470           rts
0x00048f82      01006df3       sleep
0x00048f86      01006b20       sleep
0x00048f8a      0040           nop
0x00048f8c      4eb2           bgt @@0xb2:8
0x00048f8e      6b230040       mov.w @0x40:16,r3
0x00048f92      0e8a           addx r0l,r2l
0x00048f94      19bb           sub.w r11,r3
0x00048f96      6d01           mov.w @r0+,r1
0x00048f98      1d1b           cmp.w r1,r3
0x00048f9a      4402           bcc @@0x2:8
0x00048f9c      0d1b           mov.w r1,r3
0x00048f9e      1b53           subs #1,r3
0x00048fa0      46f4           bne @@0xf4:8
0x00048fa2      6bab0040       mov.w r3,@0x40:16
0x00048fa6      4e56           bgt @@0x56:8
0x00048fa8      01006d73       sleep
0x00048fac      5470           rts
0x00048fae      5afffe00       jmp @0xfe00:16
0x00048fb2      01006df0       sleep
0x00048fb6      01006df1       sleep
0x00048fba      01006df2       sleep
0x00048fbe      7a             invalid
0x00048fbf      0000           nop
0x00048fc1      048f           orc #0x8f:8,ccr
0x00048fc3      e67a           and #0x7a:8,r6h
0x00048fc5      0100fffe       sleep
0x00048fc9      006d           nop
0x00048fcb      0269           stc ccr,r1l
0x00048fcd      920b           addx #0xb:8,r2h
0x00048fcf      f17a           mov.b #0x7a:8,r1h
0x00048fd1      2000           mov.b @0x0:8,r0h
0x00048fd3      0490           orc #0x90:8,ccr
0x00048fd5      4245           bhi @@0x45:8
0x00048fd7      f201           mov.b #0x1:8,r2h
0x00048fd9      006d           nop
0x00048fdb      7201           bclr #0x0:3,r1h
0x00048fdd      006d           nop
0x00048fdf      7101           bnot #0x0:3,r1h
0x00048fe1      006d           nop
0x00048fe3      7054           bset #0x5:3,r4h
0x00048fe5      7001           bset #0x0:3,r1h
0x00048fe7      006d           nop
0x00048fe9      f301           mov.b #0x1:8,r3h
0x00048feb      006d           nop
0x00048fed      f401           mov.b #0x1:8,r4h
0x00048fef      006d           nop
0x00048ff1      f501           mov.b #0x1:8,r5h
0x00048ff3      006b           nop
0x00048ff5      2000           mov.b @0x0:8,r0h
0x00048ff7      404e           bra @@0x4e:8
0x00048ff9      b26b           subx #0x6b:8,r2h
0x00048ffb      2100           mov.b @0x0:8,r1h
0x00048ffd      400e           bra @@0xe:8
0x00048fff      8a79           add.b #0x79:8,r2l
0x00049001      3101           mov.b r1h,@0x1:8
0x00049003      f479           mov.b #0x79:8,r4h
0x00049005      61ff           bnot r7l,r7l
0x00049007      fe17           mov.b #0x17:8,r6l
0x00049009      710a           bnot #0x0:3,r2l
0x0004900b      9019           addx #0x19:8,r0h
0x0004900d      dd1a           xor #0x1a:8,r5l
0x0004900f      9179           addx #0x79:8,r1h
0x00049011      0301           ldc r1h,ccr
0x00049013      f40d           mov.b #0xd:8,r4h
0x00049015      3b19           mov.b r3l,@0x19:8
0x00049017      cc6d           or #0x6d:8,r4l
0x00049019      041d           orc #0x1d:8,ccr
0x0004901b      4d44           blt @@0x44:8
0x0004901d      020d           stc ccr,r5l
0x0004901f      4d0a           blt @@0xa:8
0x00049021      c11b           or #0x1b:8,r1h
0x00049023      53             invalid
0x00049024      46f2           bne @@0xf2:8
0x00049026      53             invalid
0x00049027      b16b           subx #0x6b:8,r1h
0x00049029      a100           cmp.b #0x0:8,r1h
0x0004902b      404e           bra @@0x4e:8
0x0004902d      58             invalid
0x0004902e      6bad0040       mov.w r5,@0x40:16
0x00049032      4e56           bgt @@0x56:8
0x00049034      01006d75       sleep
0x00049038      01006d74       sleep
0x0004903c      01006d73       sleep
0x00049040      5470           rts
0x00049042      01006df3       sleep
0x00049046      01006df4       sleep
0x0004904a      01006df5       sleep
0x0004904e      1a80           dec r0h
0x00049050      6a280040       mov.b @0x40:16,r0l
0x00049054      4e97           bgt @@0x97:8
0x00049056      1008           shll r0l
0x00049058      79011000       mov.w #0x1000:16,r1
0x0004905c      52             invalid
0x0004905d      016a2800       sleep
0x00049061      404e           bra @@0x4e:8
0x00049063      75a8           bixor #0x2:3,r0l
0x00049065      01586000       sleep
0x00049069      0a7a           inc r2l
0x0004906b      1100           shlr r0h
0x0004906d      8200           add.b #0x0:8,r2h
0x0004906f      0058           nop
0x00049071      0000           nop
0x00049073      067a           andc #0x7a:8,ccr
0x00049075      1100           shlr r0h
0x00049077      8280           add.b #0x80:8,r2h
0x00049079      006b           nop
0x0004907b      2000           mov.b @0x0:8,r0h
0x0004907d      400e           bra @@0xe:8
0x0004907f      8c10           add.b #0x10:8,r4l
0x00049081      100a           shll r2l
0x00049083      817a           add.b #0x7a:8,r1h
0x00049085      0000           nop
0x00049087      4010           bra @@0x10:8
0x00049089      a06b           cmp.b #0x6b:8,r0h
0x0004908b      2300           mov.b @0x0:8,r3h
0x0004908d      400e           bra @@0xe:8
0x0004908f      8a6b           add.b #0x6b:8,r2l
0x00049091      2b00           mov.b @0x0:8,r3l
0x00049093      406e           bra @@0x6e:8
0x00049095      146d           or r6h,r5l
0x00049097      0c58           mov.b r5h,r0l
0x00049099      6000           bset r0h,r0h
0x0004909b      0479           orc #0x79:8,ccr
0x0004909d      0c00           mov.b r0h,r0h
0x0004909f      011dcb58       sleep
0x000490a3      5000           mulxu r0h,r0
0x000490a5      2c6a           mov.b @0x6a:8,r4l
0x000490a7      2c00           mov.b @0x0:8,r4l
0x000490a9      404e           bra @@0x4e:8
0x000490ab      9717           addx #0x17:8,r7h
0x000490ad      540d           rts
0x000490af      450b           bcs @@0xb:8
0x000490b1      5479           rts
0x000490b3      4408           bcc @@0x8:8
0x000490b5      606b           bset r6h,r3l
0x000490b7      a400           cmp.b #0x0:8,r4h
0x000490b9      4007           bra @@0x7:8
0x000490bb      78             invalid
0x000490bc      1775           neg r5h
0x000490be      78             invalid
0x000490bf      506a           mulxu r6h,r2
0x000490c1      2c00           mov.b @0x0:8,r4l
0x000490c3      04a8           orc #0xa8:8,ccr
0x000490c5      a47a           cmp.b #0x7a:8,r4h
0x000490c7      0500           xorc #0x0:8,ccr
0x000490c9      4062           bra @@0x62:8
0x000490cb      f968           mov.b #0x68:8,r1l
0x000490cd      5416           rts
0x000490cf      c468           or #0x68:8,r4h
0x000490d1      d401           xor #0x1:8,r4h
0x000490d3      006b           nop
0x000490d5      2500           mov.b @0x0:8,r5h
0x000490d7      404e           bra @@0x4e:8
0x000490d9      6a793c00       mov.b @0x3c00:16,r1l
0x000490dd      1453           or r5h,r3h
0x000490df      c579           or #0x79:8,r5h
0x000490e1      353f           mov.b r5h,@0x3f:8
0x000490e3      ff69           mov.b #0x69:8,r7l
0x000490e5      950b           addx #0xb:8,r5h
0x000490e7      f11b           mov.b #0x1b:8,r1h
0x000490e9      53             invalid
0x000490ea      4704           beq @@0x4:8
0x000490ec      5a049096       jmp @0x9096:16
0x000490f0      01006d75       sleep
0x000490f4      01006d74       sleep
0x000490f8      01006d73       sleep
0x000490fc      5470           rts
0x000490fe      01006df3       sleep
0x00049102      01006df4       sleep
0x00049106      01006df5       sleep
0x0004910a      01006df6       sleep
0x0004910e      1a80           dec r0h
0x00049110      6a280040       mov.b @0x40:16,r0l
0x00049114      4e97           bgt @@0x97:8
0x00049116      1008           shll r0l
0x00049118      79011000       mov.w #0x1000:16,r1
0x0004911c      52             invalid
0x0004911d      016a2800       sleep
0x00049121      404e           bra @@0x4e:8
0x00049123      75a8           bixor #0x2:3,r0l
0x00049125      01586000       sleep
0x00049129      0a7a           inc r2l
0x0004912b      1100           shlr r0h
0x0004912d      8200           add.b #0x0:8,r2h
0x0004912f      0058           nop
0x00049131      0000           nop
0x00049133      067a           andc #0x7a:8,ccr
0x00049135      1100           shlr r0h
0x00049137      8280           add.b #0x80:8,r2h
0x00049139      006b           nop
0x0004913b      2000           mov.b @0x0:8,r0h
0x0004913d      400e           bra @@0xe:8
0x0004913f      8c6b           add.b #0x6b:8,r4l
0x00049141      2600           mov.b @0x0:8,r6h
0x00049143      400e           bra @@0xe:8
0x00049145      9009           addx #0x9:8,r0h
0x00049147      6010           bset r1h,r0h
0x00049149      100a           shll r2l
0x0004914b      817a           add.b #0x7a:8,r1h
0x0004914d      0000           nop
0x0004914f      4010           bra @@0x10:8
0x00049151      a01a           cmp.b #0x1a:8,r0h
0x00049153      e66b           and #0x6b:8,r6h
0x00049155      2600           mov.b @0x0:8,r6h
0x00049157      400e           bra @@0xe:8
0x00049159      9010           addx #0x10:8,r0h
0x0004915b      160a           and r0h,r2l
0x0004915d      e06b           and #0x6b:8,r0h
0x0004915f      2300           mov.b @0x0:8,r3h
0x00049161      400e           bra @@0xe:8
0x00049163      8a6b           add.b #0x6b:8,r2l
0x00049165      2600           mov.b @0x0:8,r6h
0x00049167      400e           bra @@0xe:8
0x00049169      9019           addx #0x19:8,r0h
0x0004916b      636b           btst r6h,r3l
0x0004916d      2b00           mov.b @0x0:8,r3l
0x0004916f      406e           bra @@0x6e:8
0x00049171      146b           or r6h,r3l
0x00049173      2600           mov.b @0x0:8,r6h
0x00049175      400e           bra @@0xe:8
0x00049177      8e6d           add.b #0x6d:8,r6l
0x00049179      0c58           mov.b r5h,r0l
0x0004917b      6000           bset r0h,r0h
0x0004917d      0479           orc #0x79:8,ccr
0x0004917f      0c00           mov.b r0h,r0h
0x00049181      01792600       sleep
0x00049185      0058           nop
0x00049187      7000           bset #0x0:3,r0h
0x00049189      341b           mov.b r4h,@0x1b:8
0x0004918b      561d           rte
0x0004918d      cb58           or #0x58:8,r3l
0x0004918f      5000           mulxu r0h,r0
0x00049191      2c6a           mov.b @0x6a:8,r4l
0x00049193      2c00           mov.b @0x0:8,r4l
0x00049195      404e           bra @@0x4e:8
0x00049197      9717           addx #0x17:8,r7h
0x00049199      540d           rts
0x0004919b      450b           bcs @@0xb:8
0x0004919d      5479           rts
0x0004919f      4408           bcc @@0x8:8
0x000491a1      606b           bset r6h,r3l
0x000491a3      a400           cmp.b #0x0:8,r4h
0x000491a5      4007           bra @@0x7:8
0x000491a7      78             invalid
0x000491a8      1775           neg r5h
0x000491aa      78             invalid
0x000491ab      506a           mulxu r6h,r2
0x000491ad      2c00           mov.b @0x0:8,r4l
0x000491af      04a8           orc #0xa8:8,ccr
0x000491b1      a47a           cmp.b #0x7a:8,r4h
0x000491b3      0500           xorc #0x0:8,ccr
0x000491b5      4062           bra @@0x62:8
0x000491b7      f968           mov.b #0x68:8,r1l
0x000491b9      5416           rts
0x000491bb      c468           or #0x68:8,r4h
0x000491bd      d401           xor #0x1:8,r4h
0x000491bf      006b           nop
0x000491c1      2500           mov.b @0x0:8,r5h
0x000491c3      404e           bra @@0x4e:8
0x000491c5      6a793c00       mov.b @0x3c00:16,r1l
0x000491c9      1453           or r5h,r3h
0x000491cb      c579           or #0x79:8,r5h
0x000491cd      353f           mov.b r5h,@0x3f:8
0x000491cf      ff79           mov.b #0x79:8,r7l
0x000491d1      253f           mov.b @0x3f:8,r5h
0x000491d3      ff58           mov.b #0x58:8,r7l
0x000491d5      5000           mulxu r0h,r0
0x000491d7      020d           stc ccr,r5l
0x000491d9      e569           and #0x69:8,r5h
0x000491db      950d           addx #0xd:8,r5h
0x000491dd      5e0bf11b       jsr @0xf11b:16
0x000491e1      53             invalid
0x000491e2      4704           beq @@0x4:8
0x000491e4      5a049178       jmp @0x9178:16
0x000491e8      1a80           dec r0h
0x000491ea      6a280040       mov.b @0x40:16,r0l
0x000491ee      4e97           bgt @@0x97:8
0x000491f0      1008           shll r0l
0x000491f2      79011000       mov.w #0x1000:16,r1
0x000491f6      52             invalid
0x000491f7      016a2800       sleep
0x000491fb      404e           bra @@0x4e:8
0x000491fd      75a8           bixor #0x2:3,r0l
0x000491ff      01586000       sleep
0x00049203      0a7a           inc r2l
0x00049205      1100           shlr r0h
0x00049207      8200           add.b #0x0:8,r2h
0x00049209      0058           nop
0x0004920b      0000           nop
0x0004920d      067a           andc #0x7a:8,ccr
0x0004920f      1100           shlr r0h
0x00049211      8280           add.b #0x80:8,r2h
0x00049213      006b           nop
0x00049215      2000           mov.b @0x0:8,r0h
0x00049217      400e           bra @@0xe:8
0x00049219      8c6b           add.b #0x6b:8,r4l
0x0004921b      2600           mov.b @0x0:8,r6h
0x0004921d      400e           bra @@0xe:8
0x0004921f      9009           addx #0x9:8,r0h
0x00049221      601b           bset r1h,r3l
0x00049223      5010           mulxu r1h,r0
0x00049225      100a           shll r2l
0x00049227      817a           add.b #0x7a:8,r1h
0x00049229      0000           nop
0x0004922b      4010           bra @@0x10:8
0x0004922d      a01a           cmp.b #0x1a:8,r0h
0x0004922f      e66b           and #0x6b:8,r6h
0x00049231      2600           mov.b @0x0:8,r6h
0x00049233      400e           bra @@0xe:8
0x00049235      901b           addx #0x1b:8,r0h
0x00049237      5610           rte
0x00049239      160a           and r0h,r2l
0x0004923b      e06b           and #0x6b:8,r0h
0x0004923d      2300           mov.b @0x0:8,r3h
0x0004923f      400e           bra @@0xe:8
0x00049241      9069           addx #0x69:8,r0h
0x00049243      0c58           mov.b r5h,r0l
0x00049245      6000           bset r0h,r0h
0x00049247      0479           orc #0x79:8,ccr
0x00049249      0c00           mov.b r0h,r0h
0x0004924b      0101006b       sleep
0x0004924f      2500           mov.b @0x0:8,r5h
0x00049251      404e           bra @@0x4e:8
0x00049253      6a793c00       mov.b @0x3c00:16,r1l
0x00049257      1453           or r5h,r3h
0x00049259      c579           or #0x79:8,r5h
0x0004925b      353f           mov.b r5h,@0x3f:8
0x0004925d      ff79           mov.b #0x79:8,r7l
0x0004925f      253f           mov.b @0x3f:8,r5h
0x00049261      ff58           mov.b #0x58:8,r7l
0x00049263      5000           mulxu r0h,r0
0x00049265      020d           stc ccr,r5l
0x00049267      e569           and #0x69:8,r5h
0x00049269      950d           addx #0xd:8,r5h
0x0004926b      5e1bf11b       jsr @0xf11b:16
0x0004926f      f01b           mov.b #0x1b:8,r0h
0x00049271      53             invalid
0x00049272      4704           beq @@0x4:8
0x00049274      5a049242       jmp @0x9242:16
0x00049278      01006d76       sleep
0x0004927c      01006d75       sleep
0x00049280      01006d74       sleep
0x00049284      01006d73       sleep
0x00049288      5470           rts
0x0004928a      5afffe00       jmp @0xfe00:16
0x0004928e      5afffe7e       jmp @0xfe7e:16
0x00049292      01006df0       sleep
0x00049296      01006df1       sleep
0x0004929a      01006df2       sleep
0x0004929e      7a             invalid
0x0004929f      0000           nop
0x000492a1      0492           orc #0x92:8,ccr
0x000492a3      c67a           or #0x7a:8,r6h
0x000492a5      0100fffe       sleep
0x000492a9      006d           nop
0x000492ab      0269           stc ccr,r1l
0x000492ad      920b           addx #0xb:8,r2h
0x000492af      f17a           mov.b #0x7a:8,r1h
0x000492b1      2000           mov.b @0x0:8,r0h
0x000492b3      0493           orc #0x93:8,ccr
0x000492b5      a045           cmp.b #0x45:8,r0h
0x000492b7      f201           mov.b #0x1:8,r2h
0x000492b9      006d           nop
0x000492bb      7201           bclr #0x0:3,r1h
0x000492bd      006d           nop
0x000492bf      7101           bnot #0x0:3,r1h
0x000492c1      006d           nop
0x000492c3      7054           bset #0x5:3,r4h
0x000492c5      7001           bset #0x0:3,r1h
0x000492c7      006d           nop
0x000492c9      f301           mov.b #0x1:8,r3h
0x000492cb      006d           nop
0x000492cd      f401           mov.b #0x1:8,r4h
0x000492cf      006b           nop
0x000492d1      2000           mov.b @0x0:8,r0h
0x000492d3      407b           bra @@0x7b:8
0x000492d5      6e6b2300       mov.b @(0x2300:16,r6),r3l
0x000492d9      4052           bra @@0x52:8
0x000492db      a41b           cmp.b #0x1b:8,r4h
0x000492dd      53             invalid
0x000492de      1a91           dec r1h
0x000492e0      6d04           mov.w @r0+,r4
0x000492e2      79240fff       mov.w #0xfff:16,r4
0x000492e6      461a           bne @@0x1a:8
0x000492e8      1a91           dec r1h
0x000492ea      6a2c0040       mov.b @0x40:16,r4l
0x000492ee      4e97           bgt @@0x97:8
0x000492f0      1754           neg r4h
0x000492f2      0b54           adds #1,r4
0x000492f4      79440910       mov.w #0x910:16,r4
0x000492f8      6ba40040       mov.w r4,@0x40:16
0x000492fc      0778           ldc #0x78:8,ccr
0x000492fe      58             invalid
0x000492ff      0000           nop
0x00049301      3069           mov.b r0h,@0x69:8
0x00049303      0c19           mov.b r1h,r1l
0x00049305      c458           or #0x58:8,r4h
0x00049307      4000           bra @@0x0:8
0x00049309      0217           stc ccr,r7h
0x0004930b      9417           addx #0x17:8,r4h
0x0004930d      740a           bor #0x0:3,r2l
0x0004930f      c11b           or #0x1b:8,r1h
0x00049311      53             invalid
0x00049312      46cc           bne @@0xcc:8
0x00049314      6904           mov.w @r0,r4
0x00049316      79240fff       mov.w #0xfff:16,r4
0x0004931a      4616           bne @@0x16:8
0x0004931c      1a91           dec r1h
0x0004931e      6a2c0040       mov.b @0x40:16,r4l
0x00049322      4e97           bgt @@0x97:8
0x00049324      1754           neg r4h
0x00049326      0b54           adds #1,r4
0x00049328      794409         mov.w #0x910:16,r4
0x0004932c      6ba40040       mov.w r4,@0x40:16
0x00049330      0778           ldc #0x78:8,ccr
0x00049332      01006ba1       sleep
0x00049336      0040           nop
0x00049338      52             invalid
0x00049339      c601           or #0x1:8,r6h
0x0004933b      006d           nop
0x0004933d      7401           bor #0x0:3,r1h
0x0004933f      006d           nop
0x00049341      7354           btst #0x5:3,r4h
0x00049343      7001           bset #0x0:3,r1h
0x00049345      006d           nop
0x00049347      f201           mov.b #0x1:8,r2h
0x00049349      006d           nop
0x0004934b      f301           mov.b #0x1:8,r3h
0x0004934d      006d           nop
0x0004934f      f401           mov.b #0x1:8,r4h
0x00049351      006b           nop
0x00049353      2000           mov.b @0x0:8,r0h
0x00049355      407b           bra @@0x7b:8
0x00049357      6e6b2300       mov.b @(0x2300:16,r6),r3l
0x0004935b      4052           bra @@0x52:8
0x0004935d      a41b           cmp.b #0x1b:8,r4h
0x0004935f      53             invalid
0x00049360      1a91           dec r1h
0x00049362      1aa2           dec r2h
0x00049364      1ac4           dec r4h
0x00049366      6d04           mov.w @r0+,r4
0x00049368      0ac2           inc r2h
0x0004936a      690b           mov.w @r0,r3
0x0004936c      19b4           sub.w r11,r4
0x0004936e      58             invalid
0x0004936f      4000           bra @@0x0:8
0x00049371      0217           stc ccr,r7h
0x00049373      9417           addx #0x17:8,r4h
0x00049375      740a           bor #0x0:3,r2l
0x00049377      c11b           or #0x1b:8,r1h
0x00049379      53             invalid
0x0004937a      46ea           bne @@0xea:8
0x0004937c      01006ba1       sleep
0x00049380      0040           nop
0x00049382      52             invalid
0x00049383      c66b           or #0x6b:8,r6h
0x00049385      2300           mov.b @0x0:8,r3h
0x00049387      4052           bra @@0x52:8
0x00049389      a453           cmp.b #0x53:8,r4h
0x0004938b      326b           mov.b r2h,@0x6b:8
0x0004938d      a200           cmp.b #0x0:8,r2h
0x0004938f      404e           bra @@0x4e:8
0x00049391      58             invalid
0x00049392      01006d74       sleep
0x00049396      01006d73       sleep
0x0004939a      01006d72       sleep
0x0004939e      5470           rts
0x000493a0      5afffe00       jmp @0xfe00:16
0x000493a4      01006df0       sleep
0x000493a8      01006df1       sleep
0x000493ac      01006df2       sleep
0x000493b0      7a             invalid
0x000493b1      0000           nop
0x000493b3      0493           orc #0x93:8,ccr
0x000493b5      d87a           xor #0x7a:8,r0l
0x000493b7      0100fffe       sleep
0x000493bb      006d           nop
0x000493bd      0269           stc ccr,r1l
0x000493bf      920b           addx #0xb:8,r2h
0x000493c1      f17a           mov.b #0x7a:8,r1h
0x000493c3      2000           mov.b @0x0:8,r0h
0x000493c5      0494           orc #0x94:8,ccr
0x000493c7      2445           mov.b @0x45:8,r4h
0x000493c9      f201           mov.b #0x1:8,r2h
0x000493cb      006d           nop
0x000493cd      7201           bclr #0x0:3,r1h
0x000493cf      006d           nop
0x000493d1      7101           bnot #0x0:3,r1h
0x000493d3      006d           nop
0x000493d5      7054           bset #0x5:3,r4h
0x000493d7      7001           bset #0x0:3,r1h
0x000493d9      006d           nop
0x000493db      f401           mov.b #0x1:8,r4h
0x000493dd      006d           nop
0x000493df      f501           mov.b #0x1:8,r5h
0x000493e1      006d           nop
0x000493e3      f601           mov.b #0x1:8,r6h
0x000493e5      006b           nop
0x000493e7      2600           mov.b @0x0:8,r6h
0x000493e9      404e           bra @@0x4e:8
0x000493eb      b201           subx #0x1:8,r2h
0x000493ed      006b           nop
0x000493ef      2500           mov.b @0x0:8,r5h
0x000493f1      4074           bra @@0x74:8
0x000493f3      b06b           subx #0x6b:8,r0h
0x000493f5      2400           mov.b @0x0:8,r4h
0x000493f7      4074           bra @@0x74:8
0x000493f9      b60d           subx #0xd:8,r6h
0x000493fb      4c19           bge @@0x19:8
0x000493fd      8819           add.b #0x19:8,r0l
0x000493ff      4469           bcc @@0x69:8
0x00049401      5069           mulxu r6h,r1
0x00049403      e00b           and #0xb:8,r0h
0x00049405      f66a           mov.b #0x6a:8,r6h
0x00049407      2c00           mov.b @0x0:8,r4l
0x00049409      4074           bra @@0x74:8
0x0004940b      b40b           subx #0xb:8,r4h
0x0004940d      f51b           mov.b #0x1b:8,r5h
0x0004940f      5446           rts
0x00049411      fa1b           mov.b #0x1b:8,r2l
0x00049413      5c             invalid
0x00049414      46ea           bne @@0xea:8
0x00049416      01006d76       sleep
0x0004941a      01006d75       sleep
0x0004941e      01006d74       sleep
0x00049422      5470           rts
0x00049424      5afffe00       jmp @0xfe00:16
0x00049428      01006df0       sleep
0x0004942c      01006df1       sleep
0x00049430      01006df2       sleep
0x00049434      7a             invalid
0x00049435      0000           nop
0x00049437      0494           orc #0x94:8,ccr
0x00049439      5c             invalid
0x0004943a      7a             invalid
0x0004943b      0100fffe       sleep
0x0004943f      006d           nop
0x00049441      0269           stc ccr,r1l
0x00049443      920b           addx #0xb:8,r2h
0x00049445      f17a           mov.b #0x7a:8,r1h
0x00049447      2000           mov.b @0x0:8,r0h
0x00049449      0494           orc #0x94:8,ccr
0x0004944b      ac45           cmp.b #0x45:8,r4l
0x0004944d      f201           mov.b #0x1:8,r2h
0x0004944f      006d           nop
0x00049451      7201           bclr #0x0:3,r1h
0x00049453      006d           nop
0x00049455      7101           bnot #0x0:3,r1h
0x00049457      006d           nop
0x00049459      7054           bset #0x5:3,r4h
0x0004945b      7001           bset #0x0:3,r1h
0x0004945d      006d           nop
0x0004945f      f301           mov.b #0x1:8,r3h
0x00049461      006d           nop
0x00049463      f401           mov.b #0x1:8,r4h
0x00049465      006b           nop
0x00049467      2000           mov.b @0x0:8,r0h
0x00049469      404e           bra @@0x4e:8
0x0004946b      b26b           subx #0x6b:8,r2h
0x0004946d      2300           mov.b @0x0:8,r3h
0x0004946f      400e           bra @@0xe:8
0x00049471      860d           add.b #0xd:8,r6h
0x00049473      3b1a           mov.b r3l,@0x1a:8
0x00049475      9119           addx #0x19:8,r1h
0x00049477      cc6a           or #0x6a:8,r4l
0x00049479      2400           mov.b @0x0:8,r4h
0x0004947b      400f           bra @@0xf:8
0x0004947d      5aa40158       jmp @0x158:16
0x00049481      6000           bset r0h,r0h
0x00049483      0e69           addx r6h,r1l
0x00049485      040a           orc #0xa:8,ccr
0x00049487      c11b           or #0x1b:8,r1h
0x00049489      53             invalid
0x0004948a      470e           beq @@0xe:8
0x0004948c      0bf0           adds #2,r0
0x0004948e      0bf0           adds #2,r0
0x00049490      40f2           bra @@0xf2:8
0x00049492      6d04           mov.w @r0+,r4
0x00049494      0ac1           inc r1h
0x00049496      1b53           subs #1,r3
0x00049498      46f8           bne @@0xf8:8
0x0004949a      53             invalid
0x0004949b      b16b           subx #0x6b:8,r1h
0x0004949d      a100           cmp.b #0x0:8,r1h
0x0004949f      404e           bra @@0x4e:8
0x000494a1      58             invalid
0x000494a2      01006d74       sleep
0x000494a6      01006d73       sleep
0x000494aa      5470           rts
0x000494ac      5afffe00       jmp @0xfe00:16
0x000494b0      01006df0       sleep
0x000494b4      01006df1       sleep
0x000494b8      01006df2       sleep
0x000494bc      7a             invalid
0x000494bd      0000           nop
0x000494bf      0494           orc #0x94:8,ccr
0x000494c1      e47a           and #0x7a:8,r4h
0x000494c3      0100fffe       sleep
0x000494c7      006d           nop
0x000494c9      0269           stc ccr,r1l
0x000494cb      920b           addx #0xb:8,r2h
0x000494cd      f17a           mov.b #0x7a:8,r1h
0x000494cf      2000           mov.b @0x0:8,r0h
0x000494d1      0495           orc #0x95:8,ccr
0x000494d3      6245           bclr r4h,r5h
0x000494d5      f201           mov.b #0x1:8,r2h
0x000494d7      006d           nop
0x000494d9      7201           bclr #0x0:3,r1h
0x000494db      006d           nop
0x000494dd      7101           bnot #0x0:3,r1h
0x000494df      006d           nop
0x000494e1      7054           bset #0x5:3,r4h
0x000494e3      7001           bset #0x0:3,r1h
0x000494e5      006d           nop
0x000494e7      f201           mov.b #0x1:8,r2h
0x000494e9      006d           nop
0x000494eb      f301           mov.b #0x1:8,r3h
0x000494ed      006d           nop
0x000494ef      f401           mov.b #0x1:8,r4h
0x000494f1      006d           nop
0x000494f3      f501           mov.b #0x1:8,r5h
0x000494f5      006b           nop
0x000494f7      2000           mov.b @0x0:8,r0h
0x000494f9      404e           bra @@0x4e:8
0x000494fb      b26b           subx #0x6b:8,r2h
0x000494fd      2300           mov.b @0x0:8,r3h
0x000494ff      400e           bra @@0xe:8
0x00049501      8a6a           add.b #0x6a:8,r2l
0x00049503      2200           mov.b @0x0:8,r2h
0x00049505      400f           bra @@0xf:8
0x00049507      5a6a2a00       jmp @0x2a00:16
0x0004950b      400f           bra @@0xf:8
0x0004950d      5b0d           jmp @@0xd:8
0x0004950f      3b19           mov.b r3l,@0x19:8
0x00049511      ddaa           xor #0xaa:8,r5l
0x00049513      0046           nop
0x00049515      0479           orc #0x79:8,ccr
0x00049517      0dff           mov.w r15,r7
0x00049519      ff1a           mov.b #0x1a:8,r7l
0x0004951b      9119           addx #0x19:8,r1h
0x0004951d      cc18           or #0x18:8,r4l
0x0004951f      446c           bcc @@0x6c:8
0x00049521      0ca2           mov.b r2l,r2h
0x00049523      0146040b       sleep
0x00049527      700b           bset #0x0:3,r3l
0x00049529      70aa           bset #0x2:3,r2l
0x0004952b      00             nop
0x0004952d      081d           add.b r1h,r5l
0x0004952f      4d45           blt @@0x45:8
0x00049531      0a0d           inc r5l
0x00049533      4d40           blt @@0x40:8
0x00049535      061d           andc #0x1d:8,ccr
0x00049537      4d44           blt @@0x44:8
0x00049539      020d           stc ccr,r5l
0x0004953b      4d0a           blt @@0xa:8
0x0004953d      c11b           or #0x1b:8,r1h
0x0004953f      53             invalid
0x00049540      46de           bne @@0xde:8
0x00049542      53             invalid
0x00049543      b16b           subx #0x6b:8,r1h
0x00049545      a100           cmp.b #0x0:8,r1h
0x00049547      404e           bra @@0x4e:8
0x00049549      58             invalid
0x0004954a      6bad0040       mov.w r5,@0x40:16
0x0004954e      4e56           bgt @@0x56:8
0x00049550      01006d75       sleep
0x00049554      01006d74       sleep
0x00049558      01006d73       sleep
0x0004955c      01006d72       sleep
0x00049560      5470           rts
0x00049562      5afffe00       jmp @0xfe00:16
0x00049566      01006df0       sleep
0x0004956a      01006df1       sleep
0x0004956e      01006df2       sleep
0x00049572      7a             invalid
0x00049573      0000           nop
0x00049575      0495           orc #0x95:8,ccr
0x00049577      9a7a           addx #0x7a:8,r2l
0x00049579      0100fffe       sleep
0x0004957d      006d           nop
0x0004957f      0269           stc ccr,r1l
0x00049581      920b           addx #0xb:8,r2h
0x00049583      f17a           mov.b #0x7a:8,r1h
0x00049585      2000           mov.b @0x0:8,r0h
0x00049587      0495           orc #0x95:8,ccr
0x00049589      f845           mov.b #0x45:8,r0l
0x0004958b      f201           mov.b #0x1:8,r2h
0x0004958d      006d           nop
0x0004958f      7201           bclr #0x0:3,r1h
0x00049591      006d           nop
0x00049593      7101           bnot #0x0:3,r1h
0x00049595      006d           nop
0x00049597      7054           bset #0x5:3,r4h
0x00049599      7001           bset #0x0:3,r1h
0x0004959b      006d           nop
0x0004959d      f301           mov.b #0x1:8,r3h
0x0004959f      006d           nop
0x000495a1      f401           mov.b #0x1:8,r4h
0x000495a3      006d           nop
0x000495a5      f501           mov.b #0x1:8,r5h
0x000495a7      006d           nop
0x000495a9      f601           mov.b #0x1:8,r6h
0x000495ab      006b           nop
0x000495ad      2400           mov.b @0x0:8,r4h
0x000495af      4074           bra @@0x74:8
0x000495b1      ba01           subx #0x1:8,r2l
0x000495b3      006b           nop
0x000495b5      2500           mov.b @0x0:8,r5h
0x000495b7      4074           bra @@0x74:8
0x000495b9      be6b           subx #0x6b:8,r6l
0x000495bb      2300           mov.b @0x0:8,r3h
0x000495bd      4074           bra @@0x74:8
0x000495bf      c67a           or #0x7a:8,r6h
0x000495c1      0200           stc ccr,r0h
0x000495c3      003f           nop
0x000495c5      ff7a           mov.b #0x7a:8,r7l
0x000495c7      0600           andc #0x0:8,ccr
0x000495c9      0000           nop
0x000495cb      146d           or r6h,r5l
0x000495cd      5047           mulxu r4h,r7
0x000495cf      0a0f           inc r7l
0x000495d1      a153           cmp.b #0x53:8,r1h
0x000495d3      010b510f       sleep
0x000495d7      e053           and #0x53:8,r0h
0x000495d9      1069           shal r1l
0x000495db      4109           brn @@0x9:8
0x000495dd      1069           shal r1l
0x000495df      c00b           or #0xb:8,r0h
0x000495e1      f41b           mov.b #0x1b:8,r4h
0x000495e3      53             invalid
0x000495e4      46e6           bne @@0xe6:8
0x000495e6      01006d76       sleep
0x000495ea      01006d75       sleep
0x000495ee      01006d74       sleep
0x000495f2      01006d73       sleep
0x000495f6      5470           rts
0x000495f8      01006df0       sleep
0x000495fc      01006df1       sleep
0x00049600      7a             invalid
0x00049601      0000           nop
0x00049603      ffff           mov.b #0xff:8,r7l
0x00049605      eff9           and #0xf9:8,r7l
0x00049607      4968           bvs @@0x68:8
0x00049609      895e           add.b #0x5e:8,r1l
0x0004960b      0496           orc #0x96:8,ccr
0x0004960d      d601           xor #0x1:8,r6h
0x0004960f      006b           nop
0x00049611      2000           mov.b @0x0:8,r0h
0x00049613      0200           stc ccr,r0h
0x00049615      0801           add.b r0h,r1h
0x00049617      006b           nop
0x00049619      80fd           add.b #0xfd:8,r0h
0x0004961b      445e           bcc @@0x5e:8
0x0004961d      0497           orc #0x97:8,ccr
0x0004961f      0a01           inc r1h
0x00049621      006b           nop
0x00049623      2000           mov.b @0x0:8,r0h
0x00049625      0200           stc ccr,r0h
0x00049627      047a           orc #0x7a:8,ccr
0x00049629      1000           shll r0h
0x0004962b      0000           nop
0x0004962d      7f             invalid
0x0004962e      1130           shar r0h
0x00049630      1130           shar r0h
0x00049632      1130           shar r0h
0x00049634      1130           shar r0h
0x00049636      1130           shar r0h
0x00049638      1130           shar r0h
0x0004963a      1130           shar r0h
0x0004963c      1030           shal r0h
0x0004963e      1030           shal r0h
0x00049640      1030           shal r0h
0x00049642      1030           shal r0h
0x00049644      1030           shal r0h
0x00049646      1030           shal r0h
0x00049648      1030           shal r0h
0x0004964a      0f82           daa r2h
0x0004964c      f880           mov.b #0x80:8,r0l
0x0004964e      6aa80040       mov.b r0l,@0x40:16
0x00049652      0ddc           mov.w r13,r4
0x00049654      01006b21       sleep
0x00049658      0002           nop
0x0004965a      000c           nop
0x0004965c      0fa5           daa r5h
0x0004965e      7a             invalid
0x0004965f      0600           andc #0x0:8,ccr
0x00049661      400d           bra @@0xd:8
0x00049663      ddfc           xor #0xfc:8,r5l
0x00049665      807b           add.b #0x7b:8,r0h
0x00049667      5c             invalid
0x00049668      598f           jmp @r0
0x0004966a      0fd2           daa r2h
0x0004966c      7a             invalid
0x0004966d      0000           nop
0x0004966f      400d           bra @@0xd:8
0x00049671      dd01           xor #0x1:8,r5l
0x00049673      006b           nop
0x00049675      80fd           add.b #0xfd:8,r0h
0x00049677      405e           bra @@0x5e:8
0x00049679      0497           orc #0x97:8,ccr
0x0004967b      0e01           addx r0h,r1h
0x0004967d      006b           nop
0x0004967f      00fd           nop
0x00049681      441f           bcc @@0x1f:8
0x00049683      9045           addx #0x45:8,r0h
0x00049685      d67a           xor #0x7a:8,r6h
0x00049687      0100400d       sleep
0x0004968b      ddf8           xor #0xf8:8,r5l
0x0004968d      0068           nop
0x0004968f      980b           addx #0xb:8,r0l
0x00049691      716a           bnot #0x6:3,r2l
0x00049693      2800           mov.b @0x0:8,r0l
0x00049695      0040           nop
0x00049697      0168987a       sleep
0x0004969b      0000           nop
0x0004969d      0040           nop
0x0004969f      0001           nop
0x000496a1      006b           nop
0x000496a3      80fd           add.b #0xfd:8,r0h
0x000496a5      445c           bcc @@0x5c:8
0x000496a7      0000           nop
0x000496a9      607a           bset r7h,r2l
0x000496ab      0000           nop
0x000496ad      400d           bra @@0xd:8
0x000496af      dd01           xor #0x1:8,r5l
0x000496b1      006b           nop
0x000496b3      80fd           add.b #0xfd:8,r0h
0x000496b5      40f8           bra @@0xf8:8
0x000496b7      026a           stc ccr,r2l
0x000496b9      a800           cmp.b #0x0:8,r0l
0x000496bb      400d           bra @@0xd:8
0x000496bd      dc5c           xor #0x5c:8,r4l
0x000496bf      0000           nop
0x000496c1      4c7a           bge @@0x7a:8
0x000496c3      0000           nop
0x000496c5      ffff           mov.b #0xff:8,r7l
0x000496c7      eef9           and #0xf9:8,r6l
0x000496c9      f168           mov.b #0x68:8,r1h
0x000496cb      8901           add.b #0x1:8,r1l
0x000496cd      006d           nop
0x000496cf      7101           bnot #0x0:3,r1h
0x000496d1      006d           nop
0x000496d3      7054           bset #0x5:3,r4h
0x000496d5      7001           bset #0x0:3,r1h
0x000496d7      006d           nop
0x000496d9      f001           mov.b #0x1:8,r0h
0x000496db      006d           nop
0x000496dd      f101           mov.b #0x1:8,r1h
0x000496df      006d           nop
0x000496e1      f27a           mov.b #0x7a:8,r2h
0x000496e3      0000           nop
0x000496e5      0497           orc #0x97:8,ccr
0x000496e7      127a           rotl r2l
0x000496e9      01004010       sleep
0x000496ed      a06d           cmp.b #0x6d:8,r0h
0x000496ef      0269           stc ccr,r1l
0x000496f1      920b           addx #0xb:8,r2h
0x000496f3      f17a           mov.b #0x7a:8,r1h
0x000496f5      2000           mov.b @0x0:8,r0h
0x000496f7      0498           orc #0x98:8,ccr
0x000496f9      3445           mov.b r4h,@0x45:8
0x000496fb      f201           mov.b #0x1:8,r2h
0x000496fd      006d           nop
0x000496ff      7201           bclr #0x0:3,r1h
0x00049701      006d           nop
0x00049703      7101           bnot #0x0:3,r1h
0x00049705      006d           nop
0x00049707      7054           bset #0x5:3,r4h
0x00049709      705a           bset #0x5:3,r2l
0x0004970b      4010           bra @@0x10:8
0x0004970d      a05a           cmp.b #0x5a:8,r0h
0x0004970f      4011           bra @@0x11:8
0x00049711      2801           mov.b @0x1:8,r0l
0x00049713      006d           nop
0x00049715      f001           mov.b #0x1:8,r0h
0x00049717      006d           nop
0x00049719      f101           mov.b #0x1:8,r1h
0x0004971b      006d           nop
0x0004971d      f201           mov.b #0x1:8,r2h
0x0004971f      006d           nop
0x00049721      f301           mov.b #0x1:8,r3h
0x00049723      006d           nop
0x00049725      f401           mov.b #0x1:8,r4h
0x00049727      006d           nop
0x00049729      f501           mov.b #0x1:8,r5h
0x0004972b      006d           nop
0x0004972d      f67a           mov.b #0x7a:8,r6h
0x0004972f      0000           nop
0x00049731      00aa           nop
0x00049733      aaf9           cmp.b #0xf9:8,r2l
0x00049735      aa68           cmp.b #0x68:8,r2l
0x00049737      897a           add.b #0x7a:8,r1l
0x00049739      0000           nop
0x0004973b      0055           nop
0x0004973d      55f9           bsr .-7
0x0004973f      5568           bsr .104
0x00049741      897a           add.b #0x7a:8,r1l
0x00049743      0000           nop
0x00049745      00aa           nop
0x00049747      aaf9           cmp.b #0xf9:8,r2l
0x00049749      8068           add.b #0x68:8,r0h
0x0004974b      897a           add.b #0x7a:8,r1l
0x0004974d      0000           nop
0x0004974f      00aa           nop
0x00049751      aaf9           cmp.b #0xf9:8,r2l
0x00049753      aa68           cmp.b #0x68:8,r2l
0x00049755      897a           add.b #0x7a:8,r1l
0x00049757      0000           nop
0x00049759      0055           nop
0x0004975b      55f9           bsr .-7
0x0004975d      5568           bsr .104
0x0004975f      8901           add.b #0x1:8,r1l
0x00049761      006b           nop
0x00049763      06fd           andc #0xfd:8,ccr
0x00049765      44f9           bcc @@0xf9:8
0x00049767      3068           mov.b r0h,@0x68:8
0x00049769      e968           and #0x68:8,r1l
0x0004976b      69e9           mov.w r1,@r6
0x0004976d      8058           add.b #0x58:8,r0h
0x0004976f      6000           bset r0h,r0h
0x00049771      0a79           inc r1l
0x00049773      005a           nop
0x00049775      006b           nop
0x00049777      80ff           add.b #0xff:8,r0h
0x00049779      a840           cmp.b #0x40:8,r0l
0x0004977b      ee01           and #0x1:8,r6l
0x0004977d      006d           nop
0x0004977f      7601           band #0x0:3,r1h
0x00049781      006d           nop
0x00049783      7501           bxor #0x0:3,r1h
0x00049785      006d           nop
0x00049787      7401           bor #0x0:3,r1h
0x00049789      006d           nop
0x0004978b      7301           btst #0x0:3,r1h
0x0004978d      006d           nop
0x0004978f      7201           bclr #0x0:3,r1h
0x00049791      006d           nop
0x00049793      7101           bnot #0x0:3,r1h
0x00049795      006d           nop
0x00049797      7054           bset #0x5:3,r4h
0x00049799      7001           bset #0x0:3,r1h
0x0004979b      006d           nop
0x0004979d      f001           mov.b #0x1:8,r0h
0x0004979f      006d           nop
0x000497a1      f101           mov.b #0x1:8,r1h
0x000497a3      006d           nop
0x000497a5      f201           mov.b #0x1:8,r2h
0x000497a7      006d           nop
0x000497a9      f301           mov.b #0x1:8,r3h
0x000497ab      006d           nop
0x000497ad      f401           mov.b #0x1:8,r4h
0x000497af      006d           nop
0x000497b1      f501           mov.b #0x1:8,r5h
0x000497b3      006d           nop
0x000497b5      f601           mov.b #0x1:8,r6h
0x000497b7      006b           nop
0x000497b9      05fd           xorc #0xfd:8,ccr
0x000497bb      4001           bra @@0x1:8
0x000497bd      006b           nop
0x000497bf      06fd           andc #0xfd:8,ccr
0x000497c1      446a           bcc @@0x6a:8
0x000497c3      2c00           mov.b @0x0:8,r4l
0x000497c5      400d           bra @@0xd:8
0x000497c7      dc68           xor #0x68:8,r4l
0x000497c9      5b7a           jmp @@0x7a:8
0x000497cb      0000           nop
0x000497cd      00aa           nop
0x000497cf      aaf9           cmp.b #0xf9:8,r2l
0x000497d1      aa68           cmp.b #0x68:8,r2l
0x000497d3      897a           add.b #0x7a:8,r1l
0x000497d5      0000           nop
0x000497d7      0055           nop
0x000497d9      55f9           bsr .-7
0x000497db      5568           bsr .104
0x000497dd      897a           add.b #0x7a:8,r1l
0x000497df      0000           nop
0x000497e1      00aa           nop
0x000497e3      aaf9           cmp.b #0xf9:8,r2l
0x000497e5      a068           cmp.b #0x68:8,r0h
0x000497e7      8968           add.b #0x68:8,r1l
0x000497e9      eb68           and #0x68:8,r3l
0x000497eb      58             invalid
0x000497ec      e880           and #0x80:8,r0l
0x000497ee      6869           mov.b @r6,r1l
0x000497f0      e980           and #0x80:8,r1l
0x000497f2      1c89           cmp.b r0l,r1l
0x000497f4      58             invalid
0x000497f5      7000           bset #0x0:3,r0h
0x000497f7      0a79           inc r1l
0x000497f9      005a           nop
0x000497fb      006b           nop
0x000497fd      80ff           add.b #0xff:8,r0h
0x000497ff      a840           cmp.b #0x40:8,r0l
0x00049801      e80b           and #0xb:8,r0l
0x00049803      750b           bxor #0x0:3,r3l
0x00049805      761a           band #0x1:3,r2l
0x00049807      0c46           mov.b r4h,r6h
0x00049809      be01           subx #0x1:8,r6l
0x0004980b      006b           nop
0x0004980d      85fd           add.b #0xfd:8,r5h
0x0004980f      4001           bra @@0x1:8
0x00049811      006b           nop
0x00049813      86fd           add.b #0xfd:8,r6h
0x00049815      4401           bcc @@0x1:8
0x00049817      006d           nop
0x00049819      7601           band #0x0:3,r1h
0x0004981b      006d           nop
0x0004981d      7501           bxor #0x0:3,r1h
0x0004981f      006d           nop
0x00049821      7401           bor #0x0:3,r1h
0x00049823      006d           nop
0x00049825      7301           btst #0x0:3,r1h
0x00049827      006d           nop
0x00049829      7201           bclr #0x0:3,r1h
0x0004982b      006d           nop
0x0004982d      7101           bnot #0x0:3,r1h
0x0004982f      006d           nop
0x00049831      7054           bset #0x5:3,r4h
0x00049833      7000           bset #0x0:3,r0h
0x00049835      0007           nop
0x00049837      d400           xor #0x0:8,r4h
0x00049839      0215           stc ccr,r5h
0x0004983b      c201           or #0x1:8,r2h
0x0004983d      0003           nop
0x0004983f      0007           nop
0x00049841      ff00           mov.b #0x0:8,r7l
0x00049843      0218           stc ccr,r0l
0x00049845      66             invalid
0x00049846      0300           ldc r0h,ccr
0x00049848      1200           rotxl r0h
0x0004984a      07ff           ldc #0xff:8,ccr
0x0004984c      0002           nop
0x0004984e      5e180300       jsr @0x300:16
0x00049852      1500           xor r0h,r0h
0x00049854      0014           nop
0x00049856      0002           nop
0x00049858      194a           sub.w r4,r2
0x0004985a      0200           stc ccr,r0h
0x0004985c      1600           and r0h,r0h
0x0004985e      07cc           ldc #0xcc:8,ccr
0x00049860      0002           nop
0x00049862      1e3e           subx r3h,r6l
0x00049864      01001700       sleep
0x00049868      07fc           ldc #0xfc:8,ccr
0x0004986a      0002           nop
0x0004986c      1ea0           subx r2l,r0h
0x0004986e      01001a00       sleep
0x00049872      07d4           ldc #0xd4:8,ccr
0x00049874      0002           nop
0x00049876      1f1c           das r4l
0x00049878      0300           ldc r0h,ccr
0x0004987a      1b00           subs #1,r0
0x0004987c      0014           nop
0x0004987e      0002           nop
0x00049880      20b8           mov.b @0xb8:8,r0h
0x00049882      0000           nop
0x00049884      1c00           cmp.b r0h,r0h
0x00049886      0014           nop
0x00049888      0002           nop
0x0004988a      3856           mov.b r0l,@0x56:8
0x0004988c      0300           ldc r0h,ccr
0x0004988e      1d00           cmp.w r0,r0
0x00049890      0016           nop
0x00049892      0002           nop
0x00049894      3d32           mov.b r5l,@0x32:8
0x00049896      0200           stc ccr,r0h
0x00049898      2400           mov.b @0x0:8,r4h
0x0004989a      0014           nop
0x0004989c      0002           nop
0x0004989e      6e380200       mov.b @(0x200:16,r3),r0l
0x000498a2      2500           mov.b @0x0:8,r5h
0x000498a4      0254           stc ccr,r4h
0x000498a6      0002           nop
0x000498a8      72f6           bclr #0x7:3,r6h
0x000498aa      0300           ldc r0h,ccr
0x000498ac      2800           mov.b @0x0:8,r0l
0x000498ae      0054           nop
0x000498b0      0002           nop
0x000498b2      3f10           mov.b r7l,@0x10:8
0x000498b4      0300           ldc r0h,ccr
0x000498b6      2a00           mov.b @0x0:8,r2l
0x000498b8      0014           nop
0x000498ba      0002           nop
0x000498bc      5506           bsr .6
0x000498be      0200           stc ccr,r0h
0x000498c0      3b00           mov.b r3l,@0x0:8
0x000498c2      0014           nop
0x000498c4      0002           nop
0x000498c6      837c           add.b #0x7c:8,r3h
0x000498c8      0200           stc ccr,r0h
0x000498ca      3c00           mov.b r4l,@0x0:8
0x000498cc      0014           nop
0x000498ce      0002           nop
0x000498d0      8884           add.b #0x84:8,r0l
0x000498d2      0300           ldc r0h,ccr
0x000498d4      c000           or #0x0:8,r0h
0x000498d6      0754           ldc #0x54:8,ccr
0x000498d8      0002           nop
0x000498da      8ab4           add.b #0xb4:8,r2l
0x000498dc      0100c100       sleep
0x000498e0      0014           nop
0x000498e2      0002           nop
0x000498e4      8b08           add.b #0x8:8,r3l
0x000498e6      0100d000       sleep
0x000498ea      07ff           ldc #0xff:8,ccr
0x000498ec      0001           nop
0x000498ee      3748           mov.b r7h,@0x48:8
0x000498f0      0100e000       sleep
0x000498f4      0014           nop
0x000498f6      0002           nop
0x000498f8      8e16           add.b #0x16:8,r6l
0x000498fa      0200           stc ccr,r0h
0x000498fc      e100           and #0x0:8,r1h
0x000498fe      0014           nop
0x00049900      0002           nop
0x00049902      95ea           addx #0xea:8,r5h
0x00049904      0300           ldc r0h,ccr
0x00049906      0000           nop
0x00049908      0000           nop
0x0004990a      0000           nop
0x0004990c      0000           nop
0x0004990e      01000920       sleep
0x00049912      0005           nop
0x00049914      0930           add.w r3,r0
0x00049916      0006           nop
0x00049918      0940           add.w r4,r0
0x0004991a      0077           nop
0x0004991c      2000           mov.b @0x0:8,r0h
0x0004991e      000a           nop
0x00049920      3000           mov.b r0h,@0x0:8
0x00049922      0071           nop
0x00049924      1000           shll r0h
0x00049926      000b           nop
0x00049928      8000           add.b #0x0:8,r0h
0x0004992a      000c           nop
0x0004992c      40             bra @@0x0:8
0x0004992e      000e           nop
0x00049930      9000           addx #0x0:8,r0h
0x00049932      000f           nop
0x00049934      7000           bset #0x0:3,r0h
0x00049936      000f           nop
0x00049938      0320           ldc r0h,ccr
0x0004993a      007e           nop
0x0004993c      0340           ldc r0h,ccr
0x0004993e      0082           nop
0x00049940      0350           ldc r0h,ccr
0x00049942      0083           nop
0x00049944      1100           shlr r0h
0x00049946      0078           nop
0x00049948      0600           andc #0x0:8,ccr
0x0004994a      0010           nop
0x0004994c      0601           andc #0x1:8,ccr
0x0004994e      0011           nop
0x00049950      0602           andc #0x2:8,ccr
0x00049952      0012           nop
0x00049954      0603           andc #0x3:8,ccr
0x00049956      0013           nop
0x00049958      0604           andc #0x4:8,ccr
0x0004995a      0014           nop
0x0004995c      0830           add.b r3h,r0h
0x0004995e      0015           nop
0x00049960      0831           add.b r3h,r1h
0x00049962      0016           nop
0x00049964      0832           add.b r3h,r2h
0x00049966      0017           nop
0x00049968      0833           add.b r3h,r3h
0x0004996a      0018           nop
0x0004996c      0834           add.b r3h,r4h
0x0004996e      0019           nop
0x00049970      0910           add.w r1,r0
0x00049972      001a           nop
0x00049974      0911           add.w r1,r1
0x00049976      001b           nop
0x00049978      0912           add.w r1,r2
0x0004997a      001c           nop
0x0004997c      0913           add.w r1,r3
0x0004997e      001d           nop
0x00049980      0914           add.w r1,r4
0x00049982      001e           nop
0x00049984      0f10           daa r0h
0x00049986      0020           nop
0x00049988      0f20           daa r0h
0x0004998a      0021           nop
0x0004998c      0800           add.b r0h,r0h
0x0004998e      0022           nop
0x00049990      0810           add.b r1h,r0h
0x00049992      0022           nop
0x00049994      0820           add.b r2h,r0h
0x00049996      0022           nop
0x00049998      0850           add.b r5h,r0h
0x0004999a      0023           nop
0x0004999c      0851           add.b r5h,r1h
0x0004999e      0024           nop
0x000499a0      0852           add.b r5h,r2h
0x000499a2      0025           nop
0x000499a4      0853           add.b r5h,r3h
0x000499a6      0026           nop
0x000499a8      0854           add.b r5h,r4h
0x000499aa      0027           nop
0x000499ac      0f30           daa r0h
0x000499ae      0028           nop
0x000499b0      01200029       sleep
0x000499b4      0121002a       sleep
0x000499b8      0440           orc #0x40:8,ccr
0x000499ba      002b           nop
0x000499bc      0450           orc #0x50:8,ccr
0x000499be      007f           nop
0x000499c0      0430           orc #0x30:8,ccr
0x000499c2      002c           nop
0x000499c4      0f40           daa r0h
0x000499c6      002d           nop
0x000499c8      0f50           daa r0h
0x000499ca      002e           nop
0x000499cc      0f60           daa r0h
0x000499ce      002f           nop
0x000499d0      0400           orc #0x0:8,ccr
0x000499d2      0030           nop
0x000499d4      0300           ldc r0h,ccr
0x000499d6      0030           nop
0x000499d8      0310           ldc r0h,ccr
0x000499da      0084           nop
0x000499dc      0502           xorc #0x2:8,ccr
0x000499de      0030           nop
0x000499e0      0500           xorc #0x0:8,ccr
0x000499e2      0031           nop
0x000499e4      0501           xorc #0x1:8,ccr
0x000499e6      0032           nop
0x000499e8      0330           ldc r0h,ccr
0x000499ea      007b           nop
0x000499ec      0860           add.b r6h,r0h
0x000499ee      0033           nop
0x000499f0      0861           add.b r6h,r1h
0x000499f2      0034           nop
0x000499f4      0862           add.b r6h,r2h
0x000499f6      0035           nop
0x000499f8      0863           add.b r6h,r3h
0x000499fa      0036           nop
0x000499fc      0864           add.b r6h,r4h
0x000499fe      0037           nop
0x00049a00      0870           add.b r7h,r0h
0x00049a02      0038           nop
0x00049a04      0871           add.b r7h,r1h
0x00049a06      0039           nop
0x00049a08      0872           add.b r7h,r2h
0x00049a0a      003a           nop
0x00049a0c      0873           add.b r7h,r3h
0x00049a0e      003b           nop
0x00049a10      0874           add.b r7h,r4h
0x00049a12      003c           nop
0x00049a14      0610           andc #0x10:8,ccr
0x00049a16      003d           nop
0x00049a18      0611           andc #0x11:8,ccr
0x00049a1a      003e           nop
0x00049a1c      0612           andc #0x12:8,ccr
0x00049a1e      003f           nop
0x00049a20      0613           andc #0x13:8,ccr
0x00049a22      0040           nop
0x00049a24      0614           andc #0x14:8,ccr
0x00049a26      0041           nop
0x00049a28      0840           add.b r4h,r0h
0x00049a2a      0042           nop
0x00049a2c      0841           add.b r4h,r1h
0x00049a2e      0043           nop
0x00049a30      0842           add.b r4h,r2h
0x00049a32      0044           nop
0x00049a34      0843           add.b r4h,r3h
0x00049a36      0045           nop
0x00049a38      0844           add.b r4h,r4h
0x00049a3a      0046           nop
0x00049a3c      0880           add.b r0l,r0h
0x00049a3e      0047           nop
0x00049a40      0881           add.b r0l,r1h
0x00049a42      0048           nop
0x00049a44      0882           add.b r0l,r2h
0x00049a46      0049           nop
0x00049a48      0883           add.b r0l,r3h
0x00049a4a      004a           nop
0x00049a4c      0884           add.b r0l,r4h
0x00049a4e      004b           nop
0x00049a50      0110004c       sleep
0x00049a54      0380           ldc r0h,ccr
0x00049a56      0073           nop
0x00049a58      0390           ldc r0h,ccr
0x00049a5a      0074           nop
0x00049a5c      0200           stc ccr,r0h
0x00049a5e      0080           nop
0x00049a60      0891           add.b r1l,r1h
0x00049a62      0085           nop
0x00049a64      0892           add.b r1l,r2h
0x00049a66      0086           nop
0x00049a68      0893           add.b r1l,r3h
0x00049a6a      0087           nop
0x00049a6c      0894           add.b r1l,r4h
0x00049a6e      0088           nop
0x00049a70      08a1           add.b r2l,r1h
0x00049a72      0089           nop
0x00049a74      08a2           add.b r2l,r2h
0x00049a76      008a           nop
0x00049a78      08a3           add.b r2l,r3h
0x00049a7a      008b           nop
0x00049a7c      08a4           add.b r2l,r4h
0x00049a7e      008c           nop
0x00049a80      08b1           add.b r3l,r1h
0x00049a82      008d           nop
0x00049a84      08b2           add.b r3l,r2h
0x00049a86      008e           nop
0x00049a88      08b3           add.b r3l,r3h
0x00049a8a      008f           nop
0x00049a8c      08b4           add.b r3l,r4h
0x00049a8e      0090           nop
0x00049a90      1200           rotxl r0h
0x00049a92      0091           nop
0x00049a94      0000           nop
0x00049a96      0000           nop
0x00049a98      0080           nop
0x00049a9a      0000           nop
0x00049a9c      0080           nop
0x00049a9e      8000           add.b #0x0:8,r0h
0x00049aa0      0081           nop
0x00049aa2      0000           nop
0x00049aa4      0081           nop
0x00049aa6      8000           add.b #0x0:8,r0h
0x00049aa8      0082           nop
0x00049aaa      0000           nop
0x00049aac      0082           nop
0x00049aae      2000           mov.b @0x0:8,r0h
0x00049ab0      0082           nop
0x00049ab2      4000           bra @@0x0:8
0x00049ab4      0082           nop
0x00049ab6      6000           bset r0h,r0h
0x00049ab8      0082           nop
0x00049aba      8000           add.b #0x0:8,r0h
0x00049abc      0082           nop
0x00049abe      a000           cmp.b #0x0:8,r0h
0x00049ac0      0082           nop
0x00049ac2      c000           or #0x0:8,r0h
0x00049ac4      0082           nop
0x00049ac6      e000           and #0x0:8,r0h
0x00049ac8      0083           nop
0x00049aca      0000           nop
0x00049acc      0083           nop
0x00049ace      2000           mov.b @0x0:8,r0h
0x00049ad0      0083           nop
0x00049ad2      4000           bra @@0x0:8
0x00049ad4      0083           nop
0x00049ad6      6000           bset r0h,r0h
0x00049ad8      0010           nop
0x00049ada      0000           nop
0x00049adc      0000           nop
0x00049ade      0000           nop
0x00049ae0      0000           nop
0x00049ae2      0000           nop
0x00049ae4      0301           ldc r1h,ccr
0x00049ae6      0000           nop
0x00049ae8      8000           add.b #0x0:8,r0h
0x00049aea      0000           nop
0x00049aec      0000           nop
0x00049aee      0000           nop
0x00049af0      8101           add.b #0x1:8,r1h
0x00049af2      0000           nop
0x00049af4      0008           nop
0x00049af6      0000           nop
0x00049af8      0000           nop
0x00049afa      0c00           mov.b r0h,r0h
0x00049afc      8401           add.b #0x1:8,r4h
0x00049afe      0000           nop
0x00049b00      0006           nop
0x00049b02      0000           nop
0x00049b04      0000           nop
0x00049b06      1000           shll r0h
0x00049b08      8700           add.b #0x0:8,r7h
0x00049b0a      0000           nop
0x00049b0c      0018           nop
0x00049b0e      0040           nop
0x00049b10      0d45           mov.w r4,r5
0x00049b12      0800           add.b r0h,r0h
0x00049b14      8803           add.b #0x3:8,r0l
0x00049b16      0000           nop
0x00049b18      0284           stc ccr,r4h
0x00049b1a      0000           nop
0x00049b1c      0000           nop
0x00049b1e      2000           mov.b @0x0:8,r0h
0x00049b20      8e10           add.b #0x10:8,r6l
0x00049b22      0000           nop
0x00049b24      0000           nop
0x00049b26      0000           nop
0x00049b28      0000           nop
0x00049b2a      0000           nop
0x00049b2c      8f30           add.b #0x30:8,r7l
0x00049b2e      0000           nop
0x00049b30      01440000       sleep
0x00049b34      0000           nop
0x00049b36      0000           nop
0x00049b38      8a03           add.b #0x3:8,r2l
0x00049b3a      0000           nop
0x00049b3c      000e           nop
0x00049b3e      0000           nop
0x00049b40      0000           nop
0x00049b42      2000           mov.b @0x0:8,r0h
0x00049b44      8c03           add.b #0x3:8,r4l
0x00049b46      0000           nop
0x00049b48      000a           nop
0x00049b4a      0000           nop
0x00049b4c      0000           nop
0x00049b4e      2000           mov.b @0x0:8,r0h
0x00049b50      8d30           add.b #0x30:8,r5l
0x00049b52      0000           nop
0x00049b54      0000           nop
0x00049b56      0000           nop
0x00049b58      0000           nop
0x00049b5a      0000           nop
0x00049b5c      9003           addx #0x3:8,r0h
0x00049b5e      0000           nop
0x00049b60      0036           nop
0x00049b62      0000           nop
0x00049b64      0000           nop
0x00049b66      0000           nop
0x00049b68      9203           addx #0x3:8,r2h
0x00049b6a      0000           nop
0x00049b6c      000a           nop
0x00049b6e      0000           nop
0x00049b70      0000           nop
0x00049b72      0000           nop
0x00049b74      9301           addx #0x1:8,r3h
0x00049b76      0000           nop
0x00049b78      000c           nop
0x00049b7a      0000           nop
0x00049b7c      0000           nop
0x00049b7e      0000           nop
0x00049b80      e030           and #0x30:8,r0h
0x00049b82      0000           nop
0x00049b84      0406           orc #0x6:8,ccr
0x00049b86      0000           nop
0x00049b88      0000           nop
0x00049b8a      0000           nop
0x00049b8c      ff00           mov.b #0x0:8,r7l
0x00049b8e      0000           nop
0x00049b90      0000           nop
0x00049b92      0000           nop
0x00049b94      0000           nop
0x00049b96      0000           nop
0x00049b98      0301           ldc r1h,ccr
0x00049b9a      0000           nop
0x00049b9c      8000           add.b #0x0:8,r0h
0x00049b9e      0000           nop
0x00049ba0      0000           nop
0x00049ba2      8401           add.b #0x1:8,r4h
0x00049ba4      0000           nop
0x00049ba6      0000           nop
0x00049ba8      0000           nop
0x00049baa      0000           nop
0x00049bac      8501           add.b #0x1:8,r5h
0x00049bae      0000           nop
0x00049bb0      0000           nop
0x00049bb2      0000           nop
0x00049bb4      0000           nop
0x00049bb6      8803           add.b #0x3:8,r0l
0x00049bb8      0000           nop
0x00049bba      0284           stc ccr,r4h
0x00049bbc      0000           nop
0x00049bbe      0000           nop
0x00049bc0      8f30           add.b #0x30:8,r7l
0x00049bc2      0000           nop
0x00049bc4      01440000       sleep
0x00049bc8      0000           nop
0x00049bca      9203           addx #0x3:8,r2h
0x00049bcc      0000           nop
0x00049bce      0004           nop
0x00049bd0      0000           nop
0x00049bd2      0000           nop
0x00049bd4      e030           and #0x30:8,r0h
0x00049bd6      0000           nop
0x00049bd8      0400           orc #0x0:8,ccr
0x00049bda      0000           nop
0x00049bdc      0000           nop
0x00049bde      ff00           mov.b #0x0:8,r7l
0x00049be0      0000           nop
0x00049be2      0000           nop
0x00049be4      0000           nop
0x00049be6      0000           nop
0x00049be8      4197           brn @@0x97:8
0x00049bea      d784           xor #0x84:8,r7h
0x00049bec      0000           nop
0x00049bee      0000           nop
0x00049bf0      4010           bra @@0x10:8
0x00049bf2      0000           nop
0x00049bf4      0000           nop
0x00049bf6      0000           nop
0x00049bf8      4115           brn @@0x15:8
0x00049bfa      5c             invalid
0x00049bfb      c000           or #0x0:8,r0h
0x00049bfd      0000           nop
0x00049bff      0040           nop
0x00049c01      affe           cmp.b #0xfe:8,r7l
0x00049c03      0000           nop
0x00049c05      0000           nop
0x00049c07      003f           nop
0x00049c09      f2fc           mov.b #0xfc:8,r2h
0x00049c0b      5d77           jsr @r7
0x00049c0d      f389           mov.b #0x89:8,r3h
0x00049c0f      9b3f           addx #0x3f:8,r3l
0x00049c11      f35f           mov.b #0x5f:8,r3h
0x00049c13      86e3           add.b #0xe3:8,r6h
0x00049c15      6329           btst r2h,r1l
0x00049c17      073f           ldc #0x3f:8,ccr
0x00049c19      f425           mov.b #0x25:8,r4h
0x00049c1b      c935           or #0x35:8,r1l
0x00049c1d      d853           xor #0x53:8,r0l
0x00049c1f      2100           mov.b @0x0:8,r1h
0x00049c21      0000           nop
0x00049c23      0260           stc ccr,r0h
0x00049c25      ba01           subx #0x1:8,r2l
0x00049c27      0000           nop
0x00049c29      0261           stc ccr,r1h
0x00049c2b      78             invalid
0x00049c2c      1000           shll r0h
0x00049c2e      0002           nop
0x00049c30      6178           bnot r7h,r0l
0x00049c32      4000           bra @@0x0:8
0x00049c34      0002           nop
0x00049c36      6178           bnot r7h,r0l
0x00049c38      4100           brn @@0x0:8
0x00049c3a      0002           nop
0x00049c3c      6178           bnot r7h,r0l
0x00049c3e      5000           mulxu r0h,r0
0x00049c40      0002           nop
0x00049c42      6178           bnot r7h,r0l
0x00049c44      5100           divxu r0h,r0
0x00049c46      0002           nop
0x00049c48      6178           bnot r7h,r0l
0x00049c4a      52             invalid
0x00049c4b      0000           nop
0x00049c4d      0261           stc ccr,r1h
0x00049c4f      78             invalid
0x00049c50      6000           bset r0h,r0h
0x00049c52      0002           nop
0x00049c54      6178           bnot r7h,r0l
0x00049c56      6100           bnot r0h,r0h
0x00049c58      0002           nop
0x00049c5a      6178           bnot r7h,r0l
0x00049c5c      c100           or #0x0:8,r1h
0x00049c5e      0002           nop
0x00049c60      625e           bclr r5h,r6l
0x00049c62      d100           xor #0x0:8,r1h
0x00049c64      0002           nop
0x00049c66      6794           bist #0x1:3,r4h
0x00049c68      e100           and #0x0:8,r1h
0x00049c6a      0002           nop
0x00049c6c      685c           mov.b @r5,r4l
0x00049c6e      f000           mov.b #0x0:8,r0h
0x00049c70      0002           nop
0x00049c72      69f0           mov.w r0,@r7
0x00049c74      f800           mov.b #0x0:8,r0l
0x00049c76      0002           nop
0x00049c78      6c70           mov.b @r7+,r0h
0x00049c7a      fa00           mov.b #0x0:8,r2l
0x00049c7c      0002           nop
0x00049c7e      6d86           mov.w r6,@-r0
0x00049c80      fb00           mov.b #0x0:8,r3l
0x00049c82      0002           nop
0x00049c84      6dd6           mov.w r6,@-r5
0x00049c86      fc00           mov.b #0x0:8,r4l
0x00049c88      0002           nop
0x00049c8a      6daa           mov.w r2,@-r2
0x00049c8c      ff00           mov.b #0x0:8,r7l
0x00049c8e      0000           nop
0x00049c90      0000           nop
0x00049c92      4600           bne @@0x0:8
0x00049c94      0002           nop
0x00049c96      6178           bnot r7h,r0l
0x00049c98      ff00           mov.b #0x0:8,r7l
0x00049c9a      0000           nop
0x00049c9c      0000           nop
0x00049c9e      0000           nop
0x00049ca0      0000           nop
0x00049ca2      0000           nop
0x00049ca4      0000           nop
0x00049ca6      0000           nop
0x00049ca8      0000           nop
0x00049caa      0000           nop
0x00049cac      0000           nop
0x00049cae      0000           nop
0x00049cb0      4300           bls @@0x0:8
0x00049cb2      0002           nop
0x00049cb4      6178           bnot r7h,r0l
0x00049cb6      4400           bcc @@0x0:8
0x00049cb8      0002           nop
0x00049cba      6178           bnot r7h,r0l
0x00049cbc      e200           and #0x0:8,r2h
0x00049cbe      0002           nop
0x00049cc0      6cc6           mov.b r6h,@-r4
0x00049cc2      ff00           mov.b #0x0:8,r7l
0x00049cc4      0000           nop
0x00049cc6      0000           nop
0x00049cc8      0000           nop
0x00049cca      0000           nop
0x00049ccc      0000           nop
0x00049cce      4500           bcs @@0x0:8
0x00049cd0      0002           nop
0x00049cd2      6178           bnot r7h,r0l
0x00049cd4      f100           mov.b #0x0:8,r1h
0x00049cd6      0002           nop
0x00049cd8      6c1c           mov.b @r1+,r4l
0x00049cda      ff00           mov.b #0x0:8,r7l
0x00049cdc      0000           nop
0x00049cde      0000           nop
0x00049ce0      0000           nop
0x00049ce2      0000           nop
0x00049ce4      0000           nop
0x00049ce6      0000           nop
0x00049ce8      0000           nop
0x00049cea      0000           nop
0x00049cec      4600           bne @@0x0:8
0x00049cee      0002           nop
0x00049cf0      6178           bnot r7h,r0l
0x00049cf2      e200           and #0x0:8,r2h
0x00049cf4      0002           nop
0x00049cf6      6cc6           mov.b r6h,@-r4
0x00049cf8      ff00           mov.b #0x0:8,r7l
0x00049cfa      0000           nop
0x00049cfc      0000           nop
0x00049cfe      0000           nop
0x00049d00      0000           nop
0x00049d02      0000           nop
0x00049d04      0000           nop
0x00049d06      0000           nop
0x00049d08      0000           nop
0x00049d0a      4700           beq @@0x0:8
0x00049d0c      0002           nop
0x00049d0e      6178           bnot r7h,r0l
0x00049d10      e200           and #0x0:8,r2h
0x00049d12      0002           nop
0x00049d14      6cc6           mov.b r6h,@-r4
0x00049d16      ff00           mov.b #0x0:8,r7l
0x00049d18      0000           nop
0x00049d1a      0000           nop
0x00049d1c      0000           nop
0x00049d1e      0000           nop
0x00049d20      0000           nop
0x00049d22      0000           nop
0x00049d24      0000           nop
0x00049d26      0000           nop
0x00049d28      1000           shll r0h
0x00049d2a      0002           nop
0x00049d2c      6178           bnot r7h,r0l
0x00049d2e      ff00           mov.b #0x0:8,r7l
0x00049d30      0000           nop
0x00049d32      0000           nop
0x00049d34      0000           nop
0x00049d36      0000           nop
0x00049d38      0000           nop
0x00049d3a      0000           nop
0x00049d3c      0000           nop
0x00049d3e      0000           nop
0x00049d40      0000           nop
0x00049d42      0000           nop
0x00049d44      0000           nop
0x00049d46      0001           nop
0x00049d48      4041           bra @@0x41:8
0x00049d4a      4650           bne @@0x50:8
0x00049d4c      5160           divxu r6h,r0
0x00049d4e      61c1           bnot r4l,r1h
0x00049d50      d1e1           xor #0xe1:8,r1h
0x00049d52      f0f8           mov.b #0xf8:8,r0h
0x00049d54      fbfc           mov.b #0xfc:8,r3l
0x00049d56      ff00           mov.b #0x0:8,r7l
0x00049d58      0000           nop
0x00049d5a      0000           nop
0x00049d5c      01404143       sleep
0x00049d60      5051           mulxu r5h,r1
0x00049d62      6061           bset r6h,r1h
0x00049d64      c1d1           or #0xd1:8,r1h
0x00049d66      e1f0           and #0xf0:8,r1h
0x00049d68      e2f8           and #0xf8:8,r2h
0x00049d6a      fbfc           mov.b #0xfc:8,r3l
0x00049d6c      ff00           mov.b #0x0:8,r7l
0x00049d6e      0000           nop
0x00049d70      0001           nop
0x00049d72      4041           bra @@0x41:8
0x00049d74      4550           bcs @@0x50:8
0x00049d76      5160           divxu r6h,r0
0x00049d78      61c1           bnot r4l,r1h
0x00049d7a      d1e1           xor #0xe1:8,r1h
0x00049d7c      f0f1           mov.b #0xf1:8,r0h
0x00049d7e      f8fb           mov.b #0xfb:8,r0l
0x00049d80      fcff           mov.b #0xff:8,r4l
0x00049d82      0000           nop
0x00049d84      0000           nop
0x00049d86      01404146       sleep
0x00049d8a      5051           mulxu r5h,r1
0x00049d8c      6061           bset r6h,r1h
0x00049d8e      c1d1           or #0xd1:8,r1h
0x00049d90      e1f0           and #0xf0:8,r1h
0x00049d92      f8e2           mov.b #0xe2:8,r0l
0x00049d94      fbfc           mov.b #0xfc:8,r3l
0x00049d96      ff00           mov.b #0x0:8,r7l
0x00049d98      0000           nop
0x00049d9a      0001           nop
0x00049d9c      4041           bra @@0x41:8
0x00049d9e      4750           beq @@0x50:8
0x00049da0      5160           divxu r6h,r0
0x00049da2      61c1           bnot r4l,r1h
0x00049da4      d1e1           xor #0xe1:8,r1h
0x00049da6      f0f8           mov.b #0xf8:8,r0h
0x00049da8      e2fb           and #0xfb:8,r2h
0x00049daa      fcff           mov.b #0xff:8,r4l
0x00049dac      0000           nop
0x00049dae      0000           nop
0x00049db0      01404150       sleep
0x00049db4      5160           divxu r6h,r0
0x00049db6      61c1           bnot r4l,r1h
0x00049db8      d1e1           xor #0xe1:8,r1h
0x00049dba      f0f8           mov.b #0xf8:8,r0h
0x00049dbc      fbfc           mov.b #0xfc:8,r3l
0x00049dbe      ff00           mov.b #0x0:8,r7l
0x00049dc0      0000           nop
0x00049dc2      0000           nop
0x00049dc4      0001           nop
0x00049dc6      4041           bra @@0x41:8
0x00049dc8      5051           mulxu r5h,r1
0x00049dca      6061           bset r6h,r1h
0x00049dcc      c1d1           or #0xd1:8,r1h
0x00049dce      e1f0           and #0xf0:8,r1h
0x00049dd0      f8fa           mov.b #0xfa:8,r0l
0x00049dd2      fbfc           mov.b #0xfc:8,r3l
0x00049dd4      ff00           mov.b #0x0:8,r7l
0x00049dd6      0000           nop
0x00049dd8      0000           nop
0x00049dda      01404150       sleep
0x00049dde      5160           divxu r6h,r0
0x00049de0      61c1           bnot r4l,r1h
0x00049de2      d1e1           xor #0xe1:8,r1h
0x00049de4      f0f8           mov.b #0xf8:8,r0h
0x00049de6      fbfc           mov.b #0xfc:8,r3l
0x00049de8      ff00           mov.b #0x0:8,r7l
0x00049dea      0000           nop
0x00049dec      0000           nop
0x00049dee      01404150       sleep
0x00049df2      5160           divxu r6h,r0
0x00049df4      61c1           bnot r4l,r1h
0x00049df6      d1e1           xor #0xe1:8,r1h
0x00049df8      f0f8           mov.b #0xf8:8,r0h
0x00049dfa      10fb           shal r3l
0x00049dfc      fcff           mov.b #0xff:8,r4l
0x00049dfe      0000           nop
0x00049e00      0000           nop
0x00049e02      01404150       sleep
0x00049e06      5160           divxu r6h,r0
0x00049e08      61c1           bnot r4l,r1h
0x00049e0a      d1e1           xor #0xe1:8,r1h
0x00049e0c      f0f8           mov.b #0xf8:8,r0h
0x00049e0e      10fb           shal r3l
0x00049e10      fcff           mov.b #0xff:8,r4l
0x00049e12      0000           nop
0x00049e14      0000           nop
0x00049e16      01404150       sleep
0x00049e1a      5160           divxu r6h,r0
0x00049e1c      61c1           bnot r4l,r1h
0x00049e1e      d1e1           xor #0xe1:8,r1h
0x00049e20      f0f8           mov.b #0xf8:8,r0h
0x00049e22      10fb           shal r3l
0x00049e24      fcff           mov.b #0xff:8,r4l
0x00049e26      0000           nop
0x00049e28      0006           nop
0x00049e2a      8002           add.b #0x2:8,r0h
0x00049e2c      021f           stc ccr,r7l
0x00049e2e      0000           nop
0x00049e30      004e           nop
0x00049e32      696b           mov.w @r6,r3
0x00049e34      6f6e2020       mov.w @(0x2020:16,r6),r6
0x00049e38      204c           mov.b @0x4c:8,r0h
0x00049e3a      53             invalid
0x00049e3b      2d35           mov.b @0x35:8,r5l
0x00049e3d      3020           mov.b r0h,@0x20:8
0x00049e3f      4544           bcs @@0x44:8
0x00049e41      2020           mov.b @0x20:8,r0h
0x00049e43      2020           mov.b @0x20:8,r0h
0x00049e45      2020           mov.b @0x20:8,r0h
0x00049e47      2020           mov.b @0x20:8,r0h
0x00049e49      312e           mov.b r1h,@0x2e:8
0x00049e4b      3032           mov.b r0h,@0x32:8
0x00049e4d      4d6f           blt @@0x6f:8
0x00049e4f      756e           bxor #0x6:3,r6l
0x00049e51      7400           bor #0x0:3,r0h
0x00049e53      53             invalid
0x00049e54      7472           bor #0x7:3,r2h
0x00049e56      6970           mov.w @r7,r0
0x00049e58      0032           nop
0x00049e5a      3430           mov.b r4h,@0x30:8
0x00049e5c      0046           nop
0x00049e5e      65             invalid
0x00049e5f      65             invalid
0x00049e60      64             invalid
0x00049e61      65             invalid
0x00049e62      7200           bclr #0x0:3,r0h
0x00049e64      3653           mov.b r6h,@0x53:8
0x00049e66      7472           bor #0x7:3,r2h
0x00049e68      6970           mov.w @r7,r0
0x00049e6a      0033           nop
0x00049e6c      3653           mov.b r6h,@0x53:8
0x00049e6e      7472           bor #0x7:3,r2h
0x00049e70      6970           mov.w @r7,r0
0x00049e72      0054           nop
0x00049e74      65             invalid
0x00049e75      7374           btst #0x7:3,r4h
0x00049e77      0046           nop
0x00049e79      482d           bvc @@0x2d:8
0x00049e7b      3300           mov.b r3h,@0x0:8
0x00049e7d      4648           bne @@0x48:8
0x00049e7f      2d47           mov.b @0x47:8,r5l
0x00049e81      3100           mov.b r1h,@0x0:8
0x00049e83      4648           bne @@0x48:8
0x00049e85      2d41           mov.b @0x41:8,r5l
0x00049e87      3100           mov.b r1h,@0x0:8
0x00049e89      53             invalid
0x00049e8a      4341           bls @@0x41:8
0x00049e8c      4e20           bgt @@0x20:8
0x00049e8e      4d6f           blt @@0x6f:8
0x00049e90      746f           bor #0x6:3,r7l
0x00049e92      7200           bclr #0x0:3,r0h
0x00049e94      4146           brn @@0x46:8
0x00049e96      204d           mov.b @0x4d:8,r0h
0x00049e98      6f746f72       mov.w @(0x6f72:16,r7),r4
0x00049e9c      0053           nop
0x00049e9e      415f           brn @@0x5f:8
0x00049ea0      4f42           ble @@0x42:8
0x00049ea2      4a45           bpl @@0x45:8
0x00049ea4      4354           bls @@0x54:8
0x00049ea6      0032           nop
0x00049ea8      3430           mov.b r4h,@0x30:8
0x00049eaa      5f4f           jsr @@0x4f:8
0x00049eac      424a           bhi @@0x4a:8
0x00049eae      4543           bcs @@0x43:8
0x00049eb0      5400           rts
0x00049eb2      3234           mov.b r2h,@0x34:8
0x00049eb4      305f           mov.b r0h,@0x5f:8
0x00049eb6      4845           bvc @@0x45:8
0x00049eb8      4144           brn @@0x44:8
0x00049eba      0046           nop
0x00049ebc      445f           bcc @@0x5f:8
0x00049ebe      4f42           ble @@0x42:8
0x00049ec0      4a45           bpl @@0x45:8
0x00049ec2      4354           bls @@0x54:8
0x00049ec4      0036           nop
0x00049ec6      53             invalid
0x00049ec7      415f           brn @@0x5f:8
0x00049ec9      4f42           ble @@0x42:8
0x00049ecb      4a45           bpl @@0x45:8
0x00049ecd      4354           bls @@0x54:8
0x00049ecf      0033           nop
0x00049ed1      3653           mov.b r6h,@0x53:8
0x00049ed3      415f           brn @@0x5f:8
0x00049ed5      4f42           ble @@0x42:8
0x00049ed7      4a45           bpl @@0x45:8
0x00049ed9      4354           bls @@0x54:8
0x00049edb      0044           nop
0x00049edd      415f           brn @@0x5f:8
0x00049edf      434f           bls @@0x4f:8
0x00049ee1      4152           brn @@0x52:8
0x00049ee3      53             invalid
0x00049ee4      4500           bcs @@0x0:8
0x00049ee6      4441           bcc @@0x41:8
0x00049ee8      5f46           jsr @@0x46:8
0x00049eea      494e           bvs @@0x4e:8
0x00049eec      4500           bcs @@0x0:8
0x00049eee      4558           bcs @@0x58:8
0x00049ef0      505f           mulxu r5h,r7
0x00049ef2      5449           rts
0x00049ef4      4d45           blt @@0x45:8
0x00049ef6      0047           nop
0x00049ef8      4149           brn @@0x49:8
0x00049efa      4e00           bgt @@0x0:8
0x00049efc      0004           nop
0x00049efe      9e64           addx #0x64:8,r6l
0x00049f00      0004           nop
0x00049f02      9e59           addx #0x59:8,r6l
0x00049f04      0004           nop
0x00049f06      9e5d           addx #0x5d:8,r6l
0x00049f08      0004           nop
0x00049f0a      9e64           addx #0x64:8,r6l
0x00049f0c      0004           nop
0x00049f0e      9e6b           addx #0x6b:8,r6l
0x00049f10      0004           nop
0x00049f12      9e4d           addx #0x4d:8,r6l
0x00049f14      0004           nop
0x00049f16      9e73           addx #0x73:8,r6l
0x00049f18      0004           nop
0x00049f1a      9e4d           addx #0x4d:8,r6l
0x00049f1c      0004           nop
0x00049f1e      9e78           addx #0x78:8,r6l
0x00049f20      0004           nop
0x00049f22      9e7d           addx #0x7d:8,r6l
0x00049f24      0004           nop
0x00049f26      9e83           addx #0x83:8,r6l
0x00049f28      0004           nop
0x00049f2a      9e89           addx #0x89:8,r6l
0x00049f2c      0004           nop
0x00049f2e      9e94           addx #0x94:8,r6l
0x00049f30      0004           nop
0x00049f32      9e9d           addx #0x9d:8,r6l
0x00049f34      0004           nop
0x00049f36      9ea7           addx #0xa7:8,r6l
0x00049f38      0004           nop
0x00049f3a      9ebb           addx #0xbb:8,r6l
0x00049f3c      0004           nop
0x00049f3e      9ec5           addx #0xc5:8,r6l
0x00049f40      0004           nop
0x00049f42      9ed0           addx #0xd0:8,r6l
0x00049f44      0000           nop
0x00049f46      0000           nop
0x00049f48      0004           nop
0x00049f4a      9edc           addx #0xdc:8,r6l
0x00049f4c      0004           nop
0x00049f4e      9ee6           addx #0xe6:8,r6l
0x00049f50      0004           nop
0x00049f52      9eee           addx #0xee:8,r6l
0x00049f54      0004           nop
0x00049f56      9ef7           addx #0xf7:8,r6l
0x00049f58      0000           nop
0x00049f5a      1747           neg r7h
0x00049f5c      0000           nop
0x00049f5e      1165           shar r5h
0x00049f60      0000           nop
0x00049f62      1695           and r1l,r5h
0x00049f64      0000           nop
0x00049f66      1747           neg r7h
0x00049f68      0000           nop
0x00049f6a      1747           neg r7h
0x00049f6c      0000           nop
0x00049f6e      1695           and r1l,r5h
0x00049f70      0000           nop
0x00049f72      1695           and r1l,r5h
0x00049f74      0000           nop
0x00049f76      0001           nop
0x00049f78      0002           nop
0x00049f7a      7bf40000       eepmov
0x00049f7e      0000           nop
0x00049f80      0000           nop
0x00049f82      0000           nop
0x00049f84      0001           nop
0x00049f86      0001           nop
0x00049f88      0002           nop
0x00049f8a      7a             invalid
0x00049f8b      2e00           mov.b @0x0:8,r6l
0x00049f8d      0000           nop
0x00049f8f      0000           nop
0x00049f91      0000           nop
0x00049f93      0000           nop
0x00049f95      0200           stc ccr,r0h
0x00049f97      0400           orc #0x0:8,ccr
0x00049f99      027c           stc ccr,r4l
0x00049f9b      3c00           mov.b r4l,@0x0:8
0x00049f9d      0000           nop
0x00049f9f      5a00000f       jmp @0xf:16
0x00049fa3      a000           cmp.b #0x0:8,r0h
0x00049fa5      0600           andc #0x0:8,ccr
0x00049fa7      0400           orc #0x0:8,ccr
0x00049fa9      027d           stc ccr,r5l
0x00049fab      3800           mov.b r0l,@0x0:8
0x00049fad      0000           nop
0x00049faf      0000           nop
0x00049fb1      0000           nop
0x00049fb3      0000           nop
0x00049fb5      0a00           inc r0h
0x00049fb7      0400           orc #0x0:8,ccr
0x00049fb9      027d           stc ccr,r5l
0x00049fbb      9c00           addx #0x0:8,r4l
0x00049fbd      0000           nop
0x00049fbf      0000           nop
0x00049fc1      0000           nop
0x00049fc3      0000           nop
0x00049fc5      0e00           addx r0h,r0h
0x00049fc7      0400           orc #0x0:8,ccr
0x00049fc9      027e           stc ccr,r6l
0x00049fcb      78             invalid
0x00049fcc      0000           nop
0x00049fce      0000           nop
0x00049fd0      0000           nop
0x00049fd2      0000           nop
0x00049fd4      0012           nop
0x00049fd6      0004           nop
0x00049fd8      0002           nop
0x00049fda      7ee60000       biand #0x0:3,@0xe6:8
0x00049fde      0000           nop
0x00049fe0      0000           nop
0x00049fe2      0000           nop
0x00049fe4      0016           nop
0x00049fe6      0003           nop
0x00049fe8      0002           nop
0x00049fea      7a             invalid
0x00049feb      2e00           mov.b @0x0:8,r6l
0x00049fed      0000           nop
0x00049fef      0000           nop
0x00049ff1      0000           nop
0x00049ff3      0000           nop
0x00049ff5      1900           sub.w r0,r0
0x00049ff7      01000280       sleep
0x00049ffb      8a00           add.b #0x0:8,r2l
0x00049ffd      0000           nop
0x00049fff      0000           nop
0x0004a001      0000           nop
0x0004a003      0000           nop
0x0004a005      1a00           dec r0h
0x0004a007      01000280       sleep
0x0004a00b      e400           and #0x0:8,r4h
0x0004a00d      0000           nop
0x0004a00f      0000           nop
0x0004a011      0000           nop
0x0004a013      0000           nop
0x0004a015      1b00           subs #1,r0
0x0004a017      0200           stc ccr,r0h
0x0004a019      027a           stc ccr,r2l
0x0004a01b      d200           xor #0x0:8,r2h
0x0004a01d      0000           nop
0x0004a01f      0000           nop
0x0004a021      0000           nop
0x0004a023      0000           nop
0x0004a025      1d00           cmp.w r0,r0
0x0004a027      0100027a       sleep
0x0004a02b      2e00           mov.b @0x0:8,r6l
0x0004a02d      00             nop
0x0004a02f      0000           nop
0x0004a031      0000           nop
0x0004a033      0000           nop
0x0004a035      1e00           subx r0h,r0h
0x0004a037      0200           stc ccr,r0h
0x0004a039      027a           stc ccr,r2l
0x0004a03b      d200           xor #0x0:8,r2h
0x0004a03d      0000           nop
0x0004a03f      0000           nop
0x0004a041      0000           nop
0x0004a043      0000           nop
0x0004a045      2000           mov.b @0x0:8,r0h
0x0004a047      0800           add.b r0h,r0h
0x0004a049      027a           stc ccr,r2l
0x0004a04b      2e00           mov.b @0x0:8,r6l
0x0004a04d      0000           nop
0x0004a04f      0000           nop
0x0004a051      0000           nop
0x0004a053      0000           nop
0x0004a055      2800           mov.b @0x0:8,r0l
0x0004a057      01000281       sleep
0x0004a05b      2c00           mov.b @0x0:8,r4l
0x0004a05d      0000           nop
0x0004a05f      0000           nop
0x0004a061      0000           nop
0x0004a063      0000           nop
0x0004a065      2900           mov.b @0x0:8,r1l
0x0004a067      01000281       sleep
0x0004a06b      7200           bclr #0x0:3,r0h
0x0004a06d      0000           nop
0x0004a06f      0000           nop
0x0004a071      0000           nop
0x0004a073      0000           nop
0x0004a075      2a00           mov.b @0x0:8,r2l
0x0004a077      01000281       sleep
0x0004a07b      b600           subx #0x0:8,r6h
0x0004a07d      0000           nop
0x0004a07f      0000           nop
0x0004a081      0000           nop
0x0004a083      0000           nop
0x0004a085      2b00           mov.b @0x0:8,r3l
0x0004a087      01000282       sleep
0x0004a08b      52             invalid
0x0004a08c      0000           nop
0x0004a08e      0000           nop
0x0004a090      0000           nop
0x0004a092      0000           nop
0x0004a094      002c           nop
0x0004a096      0001           nop
0x0004a098      0002           nop
0x0004a09a      7a             invalid
0x0004a09b      7c000000       biand #0x0:3,@r0
0x0004a09f      01000000       sleep
0x0004a0a3      0200           stc ccr,r0h
0x0004a0a5      2d00           mov.b @0x0:8,r5l
0x0004a0a7      01000282       sleep
0x0004a0ab      9600           addx #0x0:8,r6h
0x0004a0ad      0000           nop
0x0004a0af      0000           nop
0x0004a0b1      0000           nop
0x0004a0b3      ff00           mov.b #0x0:8,r7l
0x0004a0b5      2e00           mov.b @0x0:8,r6l
0x0004a0b7      0400           orc #0x0:8,ccr
0x0004a0b9      027b           stc ccr,r3l
0x0004a0bb      8400           add.b #0x0:8,r4h
0x0004a0bd      0000           nop
0x0004a0bf      0003           nop
0x0004a0c1      ffff           mov.b #0xff:8,r7l
0x0004a0c3      ff00           mov.b #0x0:8,r7l
0x0004a0c5      3200           mov.b r2h,@0x0:8
0x0004a0c7      01000282       sleep
0x0004a0cb      e600           and #0x0:8,r6h
0x0004a0cd      0000           nop
0x0004a0cf      0000           nop
0x0004a0d1      0000           nop
0x0004a0d3      0000           nop
0x0004a0d5      3300           mov.b r3h,@0x0:8
0x0004a0d7      0100027a       sleep
0x0004a0db      7c000000       biand #0x0:3,@r0
0x0004a0df      0000           nop
0x0004a0e1      0000           nop
0x0004a0e3      ff00           mov.b #0x0:8,r7l
0x0004a0e5      3400           mov.b r4h,@0x0:8
0x0004a0e7      0100027a       sleep
0x0004a0eb      7c000000       biand #0x0:3,@r0
0x0004a0ef      0000           nop
0x0004a0f1      0000           nop
0x0004a0f3      ff00           mov.b #0x0:8,r7l
0x0004a0f5      3500           mov.b r5h,@0x0:8
0x0004a0f7      0400           orc #0x0:8,ccr
0x0004a0f9      027b           stc ccr,r3l
0x0004a0fb      8400           add.b #0x0:8,r4h
0x0004a0fd      0000           nop
0x0004a0ff      0003           nop
0x0004a101      ffff           mov.b #0xff:8,r7l
0x0004a103      ff00           mov.b #0x0:8,r7l
0x0004a105      3900           mov.b r1l,@0x0:8
0x0004a107      0100027a       sleep
0x0004a10b      7c000000       biand #0x0:3,@r0
0x0004a10f      0000           nop
0x0004a111      0000           nop
0x0004a113      0200           stc ccr,r0h
0x0004a115      4000           bra @@0x0:8
0x0004a117      0000           nop
0x0004a119      41ff           brn @@0xff:8
0x0004a11b      ff00           mov.b #0x0:8,r7l
0x0004a11d      8000           add.b #0x0:8,r0h
0x0004a11f      0000           nop
0x0004a121      837f           add.b #0x7f:8,r3h
0x0004a123      ff00           mov.b #0x0:8,r7l
0x0004a125      c000           or #0x0:8,r0h
0x0004a127      0000           nop
0x0004a129      c07f           or #0x7f:8,r0h
0x0004a12b      ff00           mov.b #0x0:8,r7l
0x0004a12d      c080           or #0x80:8,r0h
0x0004a12f      0000           nop
0x0004a131      c0ff           or #0xff:8,r0h
0x0004a133      ff80           mov.b #0x80:8,r7l
0x0004a135      0081           nop
0x0004a137      0091           nop
0x0004a139      05a0           xorc #0xa0:8,ccr
0x0004a13b      09b0           add.w r11,r0
0x0004a13d      00b1           nop
0x0004a13f      00c0           nop
0x0004a141      05c1           xorc #0xc1:8,ccr
0x0004a143      05d0           xorc #0xd0:8,ccr
0x0004a145      00d1           nop
0x0004a147      00d2           nop
0x0004a149      05d5           xorc #0xd5:8,ccr
0x0004a14b      0540           xorc #0x40:8,ccr
0x0004a14d      0b41           adds #1,r1
0x0004a14f      0b42           adds #1,r2
0x0004a151      0b46           adds #1,r6
0x0004a153      0b47           adds #1,r7
0x0004a155      0b43           adds #1,r3
0x0004a157      0b44           adds #1,r4
0x0004a159      0545           xorc #0x45:8,ccr
0x0004a15b      0bb3           adds #2,r3
0x0004a15d      0db4           mov.w r11,r4
0x0004a15f      09d6           add.w r13,r6
0x0004a161      05ff           xorc #0xff:8,ccr
0x0004a163      0010           nop
0x0004a165      0000           nop
0x0004a167      03c3           ldc r3h,ccr
0x0004a169      0440           orc #0x40:8,ccr
0x0004a16b      0000           nop
0x0004a16d      02d9           stc ccr,r1l
0x0004a16f      ca41           or #0x41:8,r2l
0x0004a171      0000           nop
0x0004a173      02e3           stc ccr,r3h
0x0004a175      ee42           and #0x42:8,r6l
0x0004a177      0000           nop
0x0004a179      0313           ldc r3h,ccr
0x0004a17b      c443           or #0x43:8,r4h
0x0004a17d      0000           nop
0x0004a17f      02bb           stc ccr,r3l
0x0004a181      e244           and #0x44:8,r2h
0x0004a183      0000           nop
0x0004a185      02c4           stc ccr,r4h
0x0004a187      6e450000       mov.b @(0x0:16,r4),r5h
0x0004a18b      02bb           stc ccr,r3l
0x0004a18d      6a810000       mov.b r1h,@0x0:16
0x0004a191      02ba           stc ccr,r2l
0x0004a193      c691           or #0x91:8,r6h
0x0004a195      0000           nop
0x0004a197      02bb           stc ccr,r3l
0x0004a199      caa0           or #0xa0:8,r2l
0x0004a19b      0000           nop
0x0004a19d      0460           orc #0x60:8,ccr
0x0004a19f      9cb0           addx #0xb0:8,r4l
0x0004a1a1      0000           nop
0x0004a1a3      02a8           stc ccr,r0l
0x0004a1a5      12b1           rotl r1h
0x0004a1a7      0000           nop
0x0004a1a9      037d           ldc r5l,ccr
0x0004a1ab      18c0           sub.b r4l,r0h
0x0004a1ad      0000           nop
0x0004a1af      02db           stc ccr,r3l
0x0004a1b1      26c1           mov.b @0xc1:8,r6h
0x0004a1b3      0000           nop
0x0004a1b5      02e4           stc ccr,r4h
0x0004a1b7      a0d0           cmp.b #0xd0:8,r0h
0x0004a1b9      0000           nop
0x0004a1bb      02ba           stc ccr,r2l
0x0004a1bd      e4d1           and #0xd1:8,r4h
0x0004a1bf      0000           nop
0x0004a1c1      02bb           stc ccr,r3l
0x0004a1c3      32d2           mov.b r2h,@0xd2:8
0x0004a1c5      0000           nop
0x0004a1c7      02bb           stc ccr,r3l
0x0004a1c9      e2d5           and #0xd5:8,r2h
0x0004a1cb      0000           nop
0x0004a1cd      0351           ldc r1h,ccr
0x0004a1cf      3880           mov.b r0l,@0x80:8
0x0004a1d1      0000           nop
0x0004a1d3      02c4           stc ccr,r4h
0x0004a1d5      6efa0000       mov.b r2l,@(0x0:16,r7)
0x0004a1d9      02bc           stc ccr,r4l
0x0004a1db      aeb3           cmp.b #0xb3:8,r6l
0x0004a1dd      0000           nop
0x0004a1df      02c0           stc ccr,r0h
0x0004a1e1      74b4           bior #0x3:3,r4h
0x0004a1e3      0000           nop
0x0004a1e5      02c3           stc ccr,r3h
0x0004a1e7      5c             invalid
0x0004a1e8      fb00           mov.b #0x0:8,r3l
0x0004a1ea      0002           nop
0x0004a1ec      bdf4           subx #0xf4:8,r5l
0x0004a1ee      d600           xor #0x0:8,r6h
0x0004a1f0      0002           nop
0x0004a1f2      c3c0           or #0xc0:8,r3h
0x0004a1f4      fc00           mov.b #0x0:8,r4l
0x0004a1f6      0002           nop
0x0004a1f8      c3f2           or #0xf2:8,r3h
0x0004a1fa      0000           nop
0x0004a1fc      0002           nop
0x0004a1fe      c46e           or #0x6e:8,r4h
0x0004a200      3fe4           mov.b r7l,@0xe4:8
0x0004a202      2a99           mov.b @0x99:8,r2l
0x0004a204      30be           mov.b r0h,@0xbe:8
0x0004a206      0ded           mov.w r14,r5
0x0004a208      3f94           mov.b r7l,@0x94:8
0x0004a20a      60aa           bset r2l,r2l
0x0004a20c      64             invalid
0x0004a20d      c2f8           or #0xf8:8,r2h
0x0004a20f      3818           mov.b r0l,@0x18:8
0x0004a211      2c0a           mov.b @0xa:8,r4l
0x0004a213      0e0b           addx r0h,r3l
0x0004a215      2d19           mov.b @0x19:8,r5l
0x0004a217      3911           mov.b r1l,@0x11:8
0x0004a219      2503           mov.b @0x3:8,r5h
0x0004a21b      0702           ldc #0x2:8,ccr
0x0004a21d      2410           mov.b @0x10:8,r4h
0x0004a21f      3002           mov.b r0h,@0x2:8
0x0004a221      0202           stc ccr,r2h
0x0004a223      0201           stc ccr,r1h
0x0004a225      01010102       sleep
0x0004a229      0202           stc ccr,r2h
0x0004a22b      0201           stc ccr,r1h
0x0004a22d      0101           sleep
0x0004a231      2c18           mov.b @0x18:8,r4l
0x0004a233      2c0a           mov.b @0xa:8,r4l
0x0004a235      2c0a           mov.b @0xa:8,r4l
0x0004a237      0e0a           addx r0h,r2l
0x0004a239      0e0b           addx r0h,r3l
0x0004a23b      0e0b           addx r0h,r3l
0x0004a23d      2d0b           mov.b @0xb:8,r5l
0x0004a23f      2d19           mov.b @0x19:8,r5l
0x0004a241      2d19           mov.b @0x19:8,r5l
0x0004a243      3919           mov.b r1l,@0x19:8
0x0004a245      3911           mov.b r1l,@0x11:8
0x0004a247      3911           mov.b r1l,@0x11:8
0x0004a249      2511           mov.b @0x11:8,r5h
0x0004a24b      2503           mov.b @0x3:8,r5h
0x0004a24d      2503           mov.b @0x3:8,r5h
0x0004a24f      0703           ldc #0x3:8,ccr
0x0004a251      0702           ldc #0x2:8,ccr
0x0004a253      0702           ldc #0x2:8,ccr
0x0004a255      2402           mov.b @0x2:8,r4h
0x0004a257      2410           mov.b @0x10:8,r4h
0x0004a259      2410           mov.b @0x10:8,r4h
0x0004a25b      3010           mov.b r0h,@0x10:8
0x0004a25d      3018           mov.b r0h,@0x18:8
0x0004a25f      3030           mov.b r0h,@0x30:8
0x0004a261      1030           shal r0h
0x0004a263      1024           shal r4h
0x0004a265      1024           shal r4h
0x0004a267      0224           stc ccr,r4h
0x0004a269      0207           stc ccr,r7h
0x0004a26b      0207           stc ccr,r7h
0x0004a26d      0307           ldc r7h,ccr
0x0004a26f      0325           ldc r5h,ccr
0x0004a271      0325           ldc r5h,ccr
0x0004a273      1125           shar r5h
0x0004a275      1139           shar r1l
0x0004a277      1139           shar r1l
0x0004a279      1939           sub.w r3,r1
0x0004a27b      192d           sub.w r2,r5
0x0004a27d      192d           sub.w r2,r5
0x0004a27f      0b2d           adds #1,r5
0x0004a281      0b0e           adds #1,r6
0x0004a283      0b0e           adds #1,r6
0x0004a285      0a0e           inc r6l
0x0004a287      0a2c           inc r4l
0x0004a289      0a2c           inc r4l
0x0004a28b      182c           sub.b r2h,r4l
0x0004a28d      1830           sub.b r3h,r0h
0x0004a28f      1803           sub.b r0h,r3h
0x0004a291      0200           stc ccr,r0h
0x0004a293      01909050       sleep
0x0004a297      5060           mulxu r6h,r0
0x0004a299      60a0           bset r2l,r0h
0x0004a29b      a080           cmp.b #0x80:8,r0h
0x0004a29d      9010           addx #0x10:8,r0h
0x0004a29f      5040           mulxu r4h,r0
0x0004a2a1      6020           bset r2h,r0h
0x0004a2a3      a008           cmp.b #0x8:8,r0h
0x0004a2a5      ff40           mov.b #0x40:8,r7l
0x0004a2a7      4040           bra @@0x40:8
0x0004a2a9      4040           bra @@0x40:8
0x0004a2ab      4040           bra @@0x40:8
0x0004a2ad      4040           bra @@0x40:8
0x0004a2af      40c0           bra @@0xc0:8
0x0004a2b1      4040           bra @@0x40:8
0x0004a2b3      4040           bra @@0x40:8
0x0004a2b5      4040           bra @@0x40:8
0x0004a2b7      4040           bra @@0x40:8
0x0004a2b9      40c0           bra @@0xc0:8
0x0004a2bb      c040           or #0x40:8,r0h
0x0004a2bd      4040           bra @@0x40:8
0x0004a2bf      4040           bra @@0x40:8
0x0004a2c1      4040           bra @@0x40:8
0x0004a2c3      40c0           bra @@0xc0:8
0x0004a2c5      c0c0           or #0xc0:8,r0h
0x0004a2c7      4040           bra @@0x40:8
0x0004a2c9      4040           bra @@0x40:8
0x0004a2cb      4040           bra @@0x40:8
0x0004a2cd      40c0           bra @@0xc0:8
0x0004a2cf      c0c0           or #0xc0:8,r0h
0x0004a2d1      c040           or #0x40:8,r0h
0x0004a2d3      4040           bra @@0x40:8
0x0004a2d5      4040           bra @@0x40:8
0x0004a2d7      40c0           bra @@0xc0:8
0x0004a2d9      c0c0           or #0xc0:8,r0h
0x0004a2db      c0c0           or #0xc0:8,r0h
0x0004a2dd      4040           bra @@0x40:8
0x0004a2df      4040           bra @@0x40:8
0x0004a2e1      40c0           bra @@0xc0:8
0x0004a2e3      c0c0           or #0xc0:8,r0h
0x0004a2e5      c0c0           or #0xc0:8,r0h
0x0004a2e7      c040           or #0x40:8,r0h
0x0004a2e9      4040           bra @@0x40:8
0x0004a2eb      40c0           bra @@0xc0:8
0x0004a2ed      c0c0           or #0xc0:8,r0h
0x0004a2ef      c0c0           or #0xc0:8,r0h
0x0004a2f1      c0c0           or #0xc0:8,r0h
0x0004a2f3      4040           bra @@0x40:8
0x0004a2f5      40c0           bra @@0xc0:8
0x0004a2f7      c0c0           or #0xc0:8,r0h
0x0004a2f9      c0c0           or #0xc0:8,r0h
0x0004a2fb      c0c0           or #0xc0:8,r0h
0x0004a2fd      c040           or #0x40:8,r0h
0x0004a2ff      40c0           bra @@0xc0:8
0x0004a301      c0c0           or #0xc0:8,r0h
0x0004a303      c0c0           or #0xc0:8,r0h
0x0004a305      c0c0           or #0xc0:8,r0h
0x0004a307      c0c0           or #0xc0:8,r0h
0x0004a309      4080           bra @@0x80:8
0x0004a30b      8080           add.b #0x80:8,r0h
0x0004a30d      8080           add.b #0x80:8,r0h
0x0004a30f      8080           add.b #0x80:8,r0h
0x0004a311      8080           add.b #0x80:8,r0h
0x0004a313      80c0           add.b #0xc0:8,r0h
0x0004a315      8080           add.b #0x80:8,r0h
0x0004a317      8080           add.b #0x80:8,r0h
0x0004a319      8080           add.b #0x80:8,r0h
0x0004a31b      8080           add.b #0x80:8,r0h
0x0004a31d      80c0           add.b #0xc0:8,r0h
0x0004a31f      c080           or #0x80:8,r0h
0x0004a321      8080           add.b #0x80:8,r0h
0x0004a323      8080           add.b #0x80:8,r0h
0x0004a325      8080           add.b #0x80:8,r0h
0x0004a327      80c0           add.b #0xc0:8,r0h
0x0004a329      c0c0           or #0xc0:8,r0h
0x0004a32b      8080           add.b #0x80:8,r0h
0x0004a32d      8080           add.b #0x80:8,r0h
0x0004a32f      8080           add.b #0x80:8,r0h
0x0004a331      80c0           add.b #0xc0:8,r0h
0x0004a333      c0c0           or #0xc0:8,r0h
0x0004a335      c080           or #0x80:8,r0h
0x0004a337      8080           add.b #0x80:8,r0h
0x0004a339      8080           add.b #0x80:8,r0h
0x0004a33b      80c0           add.b #0xc0:8,r0h
0x0004a33d      c0c0           or #0xc0:8,r0h
0x0004a33f      c0c0           or #0xc0:8,r0h
0x0004a341      8080           add.b #0x80:8,r0h
0x0004a343      8080           add.b #0x80:8,r0h
0x0004a345      80c0           add.b #0xc0:8,r0h
0x0004a347      c0c0           or #0xc0:8,r0h
0x0004a349      c0c0           or #0xc0:8,r0h
0x0004a34b      c080           or #0x80:8,r0h
0x0004a34d      8080           add.b #0x80:8,r0h
0x0004a34f      80c0           add.b #0xc0:8,r0h
0x0004a351      c0c0           or #0xc0:8,r0h
0x0004a353      c0c0           or #0xc0:8,r0h
0x0004a355      c0c0           or #0xc0:8,r0h
0x0004a357      8080           add.b #0x80:8,r0h
0x0004a359      80c0           add.b #0xc0:8,r0h
0x0004a35b      c0c0           or #0xc0:8,r0h
0x0004a35d      c0c0           or #0xc0:8,r0h
0x0004a35f      c0c0           or #0xc0:8,r0h
0x0004a361      c080           or #0x80:8,r0h
0x0004a363      80c0           add.b #0xc0:8,r0h
0x0004a365      c0c0           or #0xc0:8,r0h
0x0004a367      c0c0           or #0xc0:8,r0h
0x0004a369      c0c0           or #0xc0:8,r0h
0x0004a36b      c0c0           or #0xc0:8,r0h
0x0004a36d      803f           add.b #0x3f:8,r0h
0x0004a36f      e42a           and #0x2a:8,r4h
0x0004a371      9930           addx #0x30:8,r1l
0x0004a373      be0d           subx #0xd:8,r6l
0x0004a375      ed3f           and #0x3f:8,r5l
0x0004a377      9460           addx #0x60:8,r4h
0x0004a379      aa64           cmp.b #0x64:8,r2l
0x0004a37b      c2f8           or #0xf8:8,r2h
0x0004a37d      3800           mov.b r0l,@0x0:8
0x0004a37f      04a8           orc #0xa8:8,ccr
0x0004a381      bc00           subx #0x0:8,r4l
0x0004a383      04a8           orc #0xa8:8,ccr
0x0004a385      bc00           subx #0x0:8,r4l
0x0004a387      04e8           orc #0xe8:8,ccr
0x0004a389      bd80           subx #0x80:8,r5l
0x0004a38b      4020           bra @@0x20:8
0x0004a38d      0000           nop
0x0004a38f      1010           shal r0h
0x0004a391      2040           mov.b @0x40:8,r0h
0x0004a393      8030           add.b #0x30:8,r0h
0x0004a395      3234           mov.b r2h,@0x34:8
0x0004a397      3628           mov.b r6h,@0x28:8
0x0004a399      2a2c           mov.b @0x2c:8,r2l
0x0004a39b      2e20           mov.b @0x20:8,r6l
0x0004a39d      2224           mov.b @0x24:8,r2h
0x0004a39f      2600           mov.b @0x0:8,r6h
0x0004a3a1      0810           add.b r1h,r0h
0x0004a3a3      1800           sub.b r0h,r0h
0x0004a3a5      c000           or #0x0:8,r0h
0x0004a3a7      0000           nop
0x0004a3a9      c080           or #0x80:8,r0h
0x0004a3ab      0000           nop
0x0004a3ad      2002           mov.b @0x2:8,r0h
0x0004a3af      1400           or r0h,r0h
0x0004a3b1      2002           mov.b @0x2:8,r0h
0x0004a3b3      1c00           cmp.b r0h,r0h
0x0004a3b5      2002           mov.b @0x2:8,r0h
0x0004a3b7      2400           mov.b @0x0:8,r4h
0x0004a3b9      2002           mov.b @0x2:8,r0h
0x0004a3bb      2c00           mov.b @0x0:8,r4l
0x0004a3bd      2002           mov.b @0x2:8,r0h
0x0004a3bf      1500           xor r0h,r0h
0x0004a3c1      2002           mov.b @0x2:8,r0h
0x0004a3c3      1d00           cmp.w r0,r0
0x0004a3c5      2002           mov.b @0x2:8,r0h
0x0004a3c7      2500           mov.b @0x0:8,r5h
0x0004a3c9      2002           mov.b @0x2:8,r0h
0x0004a3cb      2d00           mov.b @0x0:8,r5l
0x0004a3cd      2004           mov.b @0x4:8,r0h
0x0004a3cf      6800           mov.b @r0,r0h
0x0004a3d1      2004           mov.b @0x4:8,r0h
0x0004a3d3      7000           bset #0x0:3,r0h
0x0004a3d5      2004           mov.b @0x4:8,r0h
0x0004a3d7      78             invalid
0x0004a3d8      0020           nop
0x0004a3da      0480           orc #0x80:8,ccr
0x0004a3dc      0020           nop
0x0004a3de      010c0020       sleep
0x0004a3e2      010d0020       sleep
0x0004a3e6      010e0020       sleep
0x0004a3ea      010f0fff       sleep
0x0004a3ee      2050           mov.b @0x50:8,r0h
0x0004a3f0      0e10           addx r1h,r0h
0x0004a3f2      07d0           ldc #0xd0:8,ccr
0x0004a3f4      07d0           ldc #0xd0:8,ccr
0x0004a3f6      07d0           ldc #0xd0:8,ccr
0x0004a3f8      07d0           ldc #0xd0:8,ccr
0x0004a3fa      07d0           ldc #0xd0:8,ccr
0x0004a3fc      07d0           ldc #0xd0:8,ccr
0x0004a3fe      07d0           ldc #0xd0:8,ccr
0x0004a400      07d0           ldc #0xd0:8,ccr
0x0004a402      2010           mov.b @0x10:8,r0h
0x0004a404      0047           nop
0x0004a406      07d0           ldc #0xd0:8,ccr
0x0004a408      07d0           ldc #0xd0:8,ccr
0x0004a40a      07d0           ldc #0xd0:8,ccr
0x0004a40c      07d0           ldc #0xd0:8,ccr
0x0004a40e      07d0           ldc #0xd0:8,ccr
0x0004a410      07d0           ldc #0xd0:8,ccr
0x0004a412      07d0           ldc #0xd0:8,ccr
0x0004a414      07d0           ldc #0xd0:8,ccr
0x0004a416      0840           add.b r4h,r0h
0x0004a418      400a           bra @@0xa:8
0x0004a41a      0500           xorc #0x0:8,ccr
0x0004a41c      0020           nop
0x0004a41e      0255           stc ccr,r5h
0x0004a420      0020           nop
0x0004a422      025d           stc ccr,r5l
0x0004a424      0020           nop
0x0004a426      0265           stc ccr,r5h
0x0004a428      0020           nop
0x0004a42a      026d           stc ccr,r5l
0x0004a42c      4118           brn @@0x18:8
0x0004a42e      6a0000         mov.b @0x0:16,r0h
0x0004a432      0000           nop
0x0004a434      4059           bra @@0x59:8
0x0004a436      0000           nop
0x0004a438      0000           nop
0x0004a43a      0000           nop
0x0004a43c      406f           bra @@0x6f:8
0x0004a43e      e000           and #0x0:8,r0h
0x0004a440      0000           nop
0x0004a442      0000           nop
0x0004a444      0000           nop
0x0004a446      0000           nop
0x0004a448      0000           nop
0x0004a44a      0000           nop
0x0004a44c      40cf           bra @@0xcf:8
0x0004a44e      ff80           mov.b #0x80:8,r7l
0x0004a450      0000           nop
0x0004a452      0000           nop
0x0004a454      4024           bra @@0x24:8
0x0004a456      0000           nop
0x0004a458      0000           nop
0x0004a45a      0000           nop
0x0004a45c      4018           bra @@0x18:8
0x0004a45e      0000           nop
0x0004a460      0000           nop
0x0004a462      0000           nop
0x0004a464      40cc           bra @@0xcc:8
0x0004a466      cc00           or #0x0:8,r4l
0x0004a468      0000           nop
0x0004a46a      0000           nop
0x0004a46c      40af           bra @@0xaf:8
0x0004a46e      fe00           mov.b #0x0:8,r6l
0x0004a470      0000           nop
0x0004a472      0000           nop
0x0004a474      3ff2           mov.b r7l,@0xf2:8
0x0004a476      fc5d           mov.b #0x5d:8,r4l
0x0004a478      77f3           bild #0x7:3,r3h
0x0004a47a      899b           add.b #0x9b:8,r1l
0x0004a47c      3ff3           mov.b r7l,@0xf3:8
0x0004a47e      5f86           jsr @@0x86:8
0x0004a480      e363           and #0x63:8,r3h
0x0004a482      2907           mov.b @0x7:8,r1l
0x0004a484      3ff4           mov.b r7l,@0xf4:8
0x0004a486      25c9           mov.b @0xc9:8,r5h
0x0004a488      35d8           mov.b r5h,@0xd8:8
0x0004a48a      53             invalid
0x0004a48b      2140           mov.b @0x40:8,r1h
0x0004a48d      5000           mulxu r0h,r0
0x0004a48f      0000           nop
0x0004a491      0000           nop
0x0004a493      0040           nop
0x0004a495      5680           rte
0x0004a497      0000           nop
0x0004a499      0000           nop
0x0004a49b      003f           nop
0x0004a49d      eccc           and #0xcc:8,r4l
0x0004a49f      cccc           or #0xcc:8,r4l
0x0004a4a1      cccc           or #0xcc:8,r4l
0x0004a4a3      cd00           or #0x0:8,r5l
0x0004a4a5      0027           nop
0x0004a4a7      1000           shll r0h
0x0004a4a9      c000           or #0x0:8,r0h
0x0004a4ab      0c00           mov.b r0h,r0h
0x0004a4ad      c000           or #0x0:8,r0h
0x0004a4af      ca00           or #0x0:8,r2l
0x0004a4b1      c001           or #0x1:8,r0h
0x0004a4b3      8800           add.b #0x0:8,r0l
0x0004a4b5      c000           or #0x0:8,r0h
0x0004a4b7      2400           mov.b @0x0:8,r4h
0x0004a4b9      c000           or #0x0:8,r0h
0x0004a4bb      2600           mov.b @0x0:8,r6h
0x0004a4bd      c000           or #0x0:8,r0h
0x0004a4bf      2800           mov.b @0x0:8,r0l
0x0004a4c1      c080           or #0x80:8,r0h
0x0004a4c3      0c00           mov.b r0h,r0h
0x0004a4c5      c080           or #0x80:8,r0h
0x0004a4c7      ca00           or #0x0:8,r2l
0x0004a4c9      c081           or #0x81:8,r0h
0x0004a4cb      8800           add.b #0x0:8,r0l
0x0004a4cd      c080           or #0x80:8,r0h
0x0004a4cf      2400           mov.b @0x0:8,r4h
0x0004a4d1      c080           or #0x80:8,r0h
0x0004a4d3      2600           mov.b @0x0:8,r6h
0x0004a4d5      c080           or #0x80:8,r0h
0x0004a4d7      283f           mov.b @0x3f:8,r0l
0x0004a4d9      f4fa           mov.b #0xfa:8,r4h
0x0004a4db      d5f2           xor #0xf2:8,r5h
0x0004a4dd      b870           subx #0x70:8,r0l
0x0004a4df      2340           mov.b @0x40:8,r3h
0x0004a4e1      0589           xorc #0x89:8,ccr
0x0004a4e3      d89d           xor #0x9d:8,r0l
0x0004a4e5      89d8           add.b #0xd8:8,r1l
0x0004a4e7      9e40           addx #0x40:8,r6l
0x0004a4e9      0d0a           mov.w r0,r2
0x0004a4eb      e4c4           and #0xc4:8,r4h
0x0004a4ed      15c9           xor r4l,r1l
0x0004a4ef      8840           add.b #0x40:8,r0l
0x0004a4f1      affe           cmp.b #0xfe:8,r7l
0x0004a4f3      0000           nop
0x0004a4f5      0000           nop
0x0004a4f7      0040           nop
0x0004a4f9      cccc           or #0xcc:8,r4l
0x0004a4fb      0000           nop
0x0004a4fd      0000           nop
0x0004a4ff      0040           nop
0x0004a501      11de           shar r6l
0x0004a503      00d1           nop
0x0004a505      b717           subx #0x17:8,r7h
0x0004a507      5940           jmp @r4
0x0004a509      c387           or #0x87:8,r3h
0x0004a50b      8000           add.b #0x0:8,r0h
0x0004a50d      0000           nop
0x0004a50f      0040           nop
0x0004a511      cfff           or #0xff:8,r7l
0x0004a513      8000           add.b #0x0:8,r0h
0x0004a515      0000           nop
0x0004a517      0040           nop
0x0004a519      6fe00000       mov.w r0,@(0x0:16,r6)
0x0004a51d      0000           nop
0x0004a51f      0004           nop
0x0004a521      01020305       sleep
0x0004a525      0004           nop
0x0004a527      01020305       sleep
0x0004a52b      0004           nop
0x0004a52d      01020305       sleep
0x0004a531      00             nop
0x0004a533      01020305       sleep
0x0004a537      0004           nop
0x0004a539      01020305       sleep
0x0004a53d      0004           nop
0x0004a53f      01020305       sleep
0x0004a543      0004           nop
0x0004a545      01020305       sleep
0x0004a549      0004           nop
0x0004a54b      01020305       sleep
0x0004a54f      0001           nop
0x0004a551      01010101       sleep
0x0004a555      01020200       sleep
0x0004a559      000c           nop
0x0004a55b      fe00           mov.b #0x0:8,r6l
0x0004a55d      000d           nop
0x0004a55f      7b000005       eepmov
0x0004a563      a000           cmp.b #0x0:8,r0h
0x0004a565      000d           nop
0x0004a567      3600           mov.b r6h,@0x0:8
0x0004a569      0004           nop
0x0004a56b      2b00           mov.b @0x0:8,r3l
0x0004a56d      000c           nop
0x0004a56f      b400           subx #0x0:8,r4h
0x0004a571      0011           nop
0x0004a573      c600           or #0x0:8,r6h
0x0004a575      0011           nop
0x0004a577      c640           or #0x40:8,r6h
0x0004a579      affe           cmp.b #0xfe:8,r7l
0x0004a57b      0000           nop
0x0004a57d      0000           nop
0x0004a57f      003f           nop
0x0004a581      f2fc           mov.b #0xfc:8,r2h
0x0004a583      5d77           jsr @r7
0x0004a585      f389           mov.b #0x89:8,r3h
0x0004a587      9b3f           addx #0x3f:8,r3l
0x0004a589      f35f           mov.b #0x5f:8,r3h
0x0004a58b      86e3           add.b #0xe3:8,r6h
0x0004a58d      6329           btst r2h,r1l
0x0004a58f      073f           ldc #0x3f:8,ccr
0x0004a591      f425           mov.b #0x25:8,r4h
0x0004a593      c935           or #0x35:8,r1l
0x0004a595      d853           xor #0x53:8,r0l
0x0004a597      213e           mov.b @0x3e:8,r1h
0x0004a599      803f           add.b #0x3f:8,r0h
0x0004a59b      f200           mov.b #0x0:8,r2h
0x0004a59d      0000           nop
0x0004a59f      0000           nop
0x0004a5a1      0031           nop
0x0004a5a3      003f           nop
0x0004a5a5      f000           mov.b #0x0:8,r0h
0x0004a5a7      0000           nop
0x0004a5a9      0000           nop
0x0004a5ab      0024           nop
0x0004a5ad      003f           nop
0x0004a5af      ec00           and #0x0:8,r4l
0x0004a5b1      0000           nop
0x0004a5b3      0000           nop
0x0004a5b5      0019           nop
0x0004a5b7      003f           nop
0x0004a5b9      e800           and #0x0:8,r0l
0x0004a5bb      0000           nop
0x0004a5bd      0000           nop
0x0004a5bf      0010           nop
0x0004a5c1      003f           nop
0x0004a5c3      e400           and #0x0:8,r4h
0x0004a5c5      0000           nop
0x0004a5c7      0000           nop
0x0004a5c9      0009           nop
0x0004a5cb      003f           nop
0x0004a5cd      e000           and #0x0:8,r0h
0x0004a5cf      0000           nop
0x0004a5d1      0000           nop
0x0004a5d3      0004           nop
0x0004a5d5      003f           nop
0x0004a5d7      d800           xor #0x0:8,r0l
0x0004a5d9      0000           nop
0x0004a5db      0000           nop
0x0004a5dd      0001           nop
0x0004a5df      003f           nop
0x0004a5e1      d000           xor #0x0:8,r0h
0x0004a5e3      0000           nop
0x0004a5e5      0000           nop
0x0004a5e7      0000           nop
0x0004a5e9      003f           nop
0x0004a5eb      c000           or #0x0:8,r0h
0x0004a5ed      0000           nop
0x0004a5ef      0000           nop
0x0004a5f1      00ff           nop
0x0004a5f3      ff3f           mov.b #0x3f:8,r7l
0x0004a5f5      f000           mov.b #0x0:8,r0h
0x0004a5f7      0000           nop
0x0004a5f9      0000           nop
0x0004a5fb      0000           nop
0x0004a5fd      0032           nop
0x0004a5ff      0000           nop
0x0004a601      0032           nop
0x0004a603      0000           nop
0x0004a605      0032           nop
0x0004a607      0000           nop
0x0004a609      0032           nop
0x0004a60b      0040           nop
0x0004a60d      dfff           xor #0xff:8,r7l
0x0004a60f      8000           add.b #0x0:8,r0h
0x0004a611      0000           nop
0x0004a613      0040           nop
0x0004a615      cfff           or #0xff:8,r7l
0x0004a617      8000           add.b #0x0:8,r0h
0x0004a619      0000           nop
0x0004a61b      003f           nop
0x0004a61d      eccc           and #0xcc:8,r4l
0x0004a61f      cccc           or #0xcc:8,r4l
0x0004a621      cccc           or #0xcc:8,r4l
0x0004a623      cd01           or #0x1:8,r5l
0x0004a625      0006           nop
0x0004a627      0004           nop
0x0004a629      0000           nop
0x0004a62b      037d           ldc r5l,ccr
0x0004a62d      1802           sub.b r0h,r2h
0x0004a62f      0006           nop
0x0004a631      0002           nop
0x0004a633      0000           nop
0x0004a635      0481           orc #0x81:8,ccr
0x0004a637      4a03           bpl @@0x3:8
0x0004a639      0006           nop
0x0004a63b      0006           nop
0x0004a63d      0000           nop
0x0004a63f      0481           orc #0x81:8,ccr
0x0004a641      5c             invalid
0x0004a642      0400           orc #0x0:8,ccr
0x0004a644      0600           andc #0x0:8,ccr
0x0004a646      01000004       sleep
0x0004a64a      8178           add.b #0x78:8,r1h
0x0004a64c      0500           xorc #0x0:8,ccr
0x0004a64e      0600           andc #0x0:8,ccr
0x0004a650      0500           xorc #0x0:8,ccr
0x0004a652      0004           nop
0x0004a654      83cc           add.b #0xcc:8,r3h
0x0004a656      0600           andc #0x0:8,ccr
0x0004a658      0600           andc #0x0:8,ccr
0x0004a65a      0300           ldc r0h,ccr
0x0004a65c      0004           nop
0x0004a65e      8538           add.b #0x38:8,r5h
0x0004a660      0000           nop
0x0004a662      0000           nop
0x0004a664      0000           nop
0x0004a666      0004           nop
0x0004a668      8982           add.b #0x82:8,r1l
0x0004a66a      01000703       sleep
0x0004a66e      0400           orc #0x0:8,ccr
0x0004a670      0004           nop
0x0004a672      8614           add.b #0x14:8,r6h
0x0004a674      01010703       sleep
0x0004a678      0402           orc #0x2:8,ccr
0x0004a67a      0004           nop
0x0004a67c      8614           add.b #0x14:8,r6h
0x0004a67e      01020703       sleep
0x0004a682      0401           orc #0x1:8,ccr
0x0004a684      0004           nop
0x0004a686      8614           add.b #0x14:8,r6h
0x0004a688      01030703       sleep
0x0004a68c      0403           orc #0x3:8,ccr
0x0004a68e      0004           nop
0x0004a690      8614           add.b #0x14:8,r6h
0x0004a692      0200           stc ccr,r0h
0x0004a694      0703           ldc #0x3:8,ccr
0x0004a696      0200           stc ccr,r0h
0x0004a698      0004           nop
0x0004a69a      8614           add.b #0x14:8,r6h
0x0004a69c      0201           stc ccr,r1h
0x0004a69e      0703           ldc #0x3:8,ccr
0x0004a6a0      0202           stc ccr,r2h
0x0004a6a2      0004           nop
0x0004a6a4      8614           add.b #0x14:8,r6h
0x0004a6a6      0202           stc ccr,r2h
0x0004a6a8      0703           ldc #0x3:8,ccr
0x0004a6aa      0201           stc ccr,r1h
0x0004a6ac      0004           nop
0x0004a6ae      8614           add.b #0x14:8,r6h
0x0004a6b0      0203           stc ccr,r3h
0x0004a6b2      0703           ldc #0x3:8,ccr
0x0004a6b4      0203           stc ccr,r3h
0x0004a6b6      0004           nop
0x0004a6b8      8614           add.b #0x14:8,r6h
0x0004a6ba      0300           ldc r0h,ccr
0x0004a6bc      0701           ldc #0x1:8,ccr
0x0004a6be      0600           andc #0x0:8,ccr
0x0004a6c0      0004           nop
0x0004a6c2      8614           add.b #0x14:8,r6h
0x0004a6c4      0301           ldc r1h,ccr
0x0004a6c6      0701           ldc #0x1:8,ccr
0x0004a6c8      0602           andc #0x2:8,ccr
0x0004a6ca      0004           nop
0x0004a6cc      8614           add.b #0x14:8,r6h
0x0004a6ce      0400           orc #0x0:8,ccr
0x0004a6d0      0703           ldc #0x3:8,ccr
0x0004a6d2      01000004       sleep
0x0004a6d6      8614           add.b #0x14:8,r6h
0x0004a6d8      0401           orc #0x1:8,ccr
0x0004a6da      0703           ldc #0x3:8,ccr
0x0004a6dc      01020004       sleep
0x0004a6e0      8614           add.b #0x14:8,r6h
0x0004a6e2      0402           orc #0x2:8,ccr
0x0004a6e4      0703           ldc #0x3:8,ccr
0x0004a6e6      01010004       sleep
0x0004a6ea      8614           add.b #0x14:8,r6h
0x0004a6ec      0403           orc #0x3:8,ccr
0x0004a6ee      0703           ldc #0x3:8,ccr
0x0004a6f0      01030004       sleep
0x0004a6f4      8614           add.b #0x14:8,r6h
0x0004a6f6      0500           xorc #0x0:8,ccr
0x0004a6f8      0703           ldc #0x3:8,ccr
0x0004a6fa      0500           xorc #0x0:8,ccr
0x0004a6fc      0004           nop
0x0004a6fe      8614           add.b #0x14:8,r6h
0x0004a700      0501           xorc #0x1:8,ccr
0x0004a702      0703           ldc #0x3:8,ccr
0x0004a704      0502           xorc #0x2:8,ccr
0x0004a706      0004           nop
0x0004a708      8614           add.b #0x14:8,r6h
0x0004a70a      0502           xorc #0x2:8,ccr
0x0004a70c      0703           ldc #0x3:8,ccr
0x0004a70e      0501           xorc #0x1:8,ccr
0x0004a710      0004           nop
0x0004a712      8614           add.b #0x14:8,r6h
0x0004a714      0503           xorc #0x3:8,ccr
0x0004a716      0703           ldc #0x3:8,ccr
0x0004a718      0503           xorc #0x3:8,ccr
0x0004a71a      0004           nop
0x0004a71c      8614           add.b #0x14:8,r6h
0x0004a71e      0600           andc #0x0:8,ccr
0x0004a720      0702           ldc #0x2:8,ccr
0x0004a722      0300           ldc r0h,ccr
0x0004a724      0004           nop
0x0004a726      86f8           add.b #0xf8:8,r6h
0x0004a728      0601           andc #0x1:8,ccr
0x0004a72a      0702           ldc #0x2:8,ccr
0x0004a72c      0302           ldc r2h,ccr
0x0004a72e      0004           nop
0x0004a730      871e           add.b #0x1e:8,r7h
0x0004a732      06             andc #0x0:8,ccr
0x0004a734      0702           ldc #0x2:8,ccr
0x0004a736      0301           ldc r1h,ccr
0x0004a738      0004           nop
0x0004a73a      8744           add.b #0x44:8,r7h
0x0004a73c      0700           ldc #0x0:8,ccr
0x0004a73e      0702           ldc #0x2:8,ccr
0x0004a740      0700           ldc #0x0:8,ccr
0x0004a742      0004           nop
0x0004a744      876a           add.b #0x6a:8,r7h
0x0004a746      0701           ldc #0x1:8,ccr
0x0004a748      0702           ldc #0x2:8,ccr
0x0004a74a      0702           ldc #0x2:8,ccr
0x0004a74c      0004           nop
0x0004a74e      8790           add.b #0x90:8,r7h
0x0004a750      0702           ldc #0x2:8,ccr
0x0004a752      0702           ldc #0x2:8,ccr
0x0004a754      0701           ldc #0x1:8,ccr
0x0004a756      0004           nop
0x0004a758      87b6           add.b #0xb6:8,r7h
0x0004a75a      0000           nop
0x0004a75c      0000           nop
0x0004a75e      0000           nop
0x0004a760      0004           nop
0x0004a762      8982           add.b #0x82:8,r1l
0x0004a764      01000100       sleep
0x0004a768      0700           ldc #0x0:8,ccr
0x0004a76a      0004           nop
0x0004a76c      8982           add.b #0x82:8,r1l
0x0004a76e      0000           nop
0x0004a770      0000           nop
0x0004a772      0000           nop
0x0004a774      0004           nop
0x0004a776      8982           add.b #0x82:8,r1l
0x0004a778      01000100       sleep
0x0004a77c      0700           ldc #0x0:8,ccr
0x0004a77e      0004           nop
0x0004a780      8982           add.b #0x82:8,r1l
0x0004a782      0000           nop
0x0004a784      0000           nop
0x0004a786      0000           nop
0x0004a788      0004           nop
0x0004a78a      8982           add.b #0x82:8,r1l
0x0004a78c      01000004       sleep
0x0004a790      8088           add.b #0x88:8,r0h
0x0004a792      0004           nop
0x0004a794      a624           cmp.b #0x24:8,r6h
0x0004a796      0500           xorc #0x0:8,ccr
0x0004a798      0004           nop
0x0004a79a      855a           add.b #0x5a:8,r5h
0x0004a79c      0004           nop
0x0004a79e      a66a           cmp.b #0x6a:8,r6h
0x0004a7a0      0000           nop
0x0004a7a2      0004           nop
0x0004a7a4      8088           add.b #0x88:8,r0h
0x0004a7a6      0004           nop
0x0004a7a8      a624           cmp.b #0x24:8,r6h
0x0004a7aa      01003000       sleep
0x0004a7ae      0000           nop
0x0004a7b0      0000           nop
0x0004a7b2      01010101       sleep
0x0004a7b6      06ff           andc #0xff:8,ccr
0x0004a7b8      ffff           mov.b #0xff:8,r7l
0x0004a7ba      ffff           mov.b #0xff:8,r7l
0x0004a7bc      0000           nop
0x0004a7be      010239ff       sleep
0x0004a7c2      ffff           mov.b #0xff:8,r7l
0x0004a7c4      ffff           mov.b #0xff:8,r7l
0x0004a7c6      01010103       sleep
0x0004a7ca      0fff           daa r7l
0x0004a7cc      ffff           mov.b #0xff:8,r7l
0x0004a7ce      ffff           mov.b #0xff:8,r7l
0x0004a7d0      0000           nop
0x0004a7d2      0200           stc ccr,r0h
0x0004a7d4      3f03           mov.b r7l,@0x3:8
0x0004a7d6      01ffffff       sleep
0x0004a7da      01010201       sleep
0x0004a7de      ff02           mov.b #0x2:8,r7l
0x0004a7e0      01ffffff       sleep
0x0004a7e4      00ff           nop
0x0004a7e6      0202           stc ccr,r2h
0x0004a7e8      ff00           mov.b #0x0:8,r7l
0x0004a7ea      01ffffff       sleep
0x0004a7ee      01ff0203       sleep
0x0004a7f2      ff01           mov.b #0x1:8,r7l
0x0004a7f4      01ffffff       sleep
0x0004a7f8      00ff           nop
0x0004a7fa      0300           ldc r0h,ccr
0x0004a7fc      ff00           mov.b #0x0:8,r7l
0x0004a7fe      0005           nop
0x0004a800      ffff           mov.b #0xff:8,r7l
0x0004a802      01ff0301       sleep
0x0004a806      ffff           mov.b #0xff:8,r7l
0x0004a808      ff0a           mov.b #0xa:8,r7l
0x0004a80a      ffff           mov.b #0xff:8,r7l
0x0004a80c      00ff           nop
0x0004a80e      0400           orc #0x0:8,ccr
0x0004a810      ffff           mov.b #0xff:8,r7l
0x0004a812      ff00           mov.b #0x0:8,r7l
0x0004a814      01ff01ff       sleep
0x0004a818      0401           orc #0x1:8,ccr
0x0004a81a      ffff           mov.b #0xff:8,r7l
0x0004a81c      ffff           mov.b #0xff:8,r7l
0x0004a81e      02ff           stc ccr,r7l
0x0004a820      00ff           nop
0x0004a822      0402           orc #0x2:8,ccr
0x0004a824      ffff           mov.b #0xff:8,r7l
0x0004a826      ffff           mov.b #0xff:8,r7l
0x0004a828      03ff           ldc r7l,ccr
0x0004a82a      01ff0403       sleep
0x0004a82e      ffff           mov.b #0xff:8,r7l
0x0004a830      ffff           mov.b #0xff:8,r7l
0x0004a832      00ff           nop
0x0004a834      00ff           nop
0x0004a836      0500           xorc #0x0:8,ccr
0x0004a838      ffff           mov.b #0xff:8,r7l
0x0004a83a      ffff           mov.b #0xff:8,r7l
0x0004a83c      ff01           mov.b #0x1:8,r7l
0x0004a83e      01ff0501       sleep
0x0004a842      ffff           mov.b #0xff:8,r7l
0x0004a844      ffff           mov.b #0xff:8,r7l
0x0004a846      ff02           mov.b #0x2:8,r7l
0x0004a848      00ff           nop
0x0004a84a      0502           xorc #0x2:8,ccr
0x0004a84c      ffff           mov.b #0xff:8,r7l
0x0004a84e      ffff           mov.b #0xff:8,r7l
0x0004a850      ff04           mov.b #0x4:8,r7l
0x0004a852      01ff0503       sleep
0x0004a856      ffff           mov.b #0xff:8,r7l
0x0004a858      ffff           mov.b #0xff:8,r7l
0x0004a85a      ff08           mov.b #0x8:8,r7l
0x0004a85c      00ff           nop
0x0004a85e      0600           andc #0x0:8,ccr
0x0004a860      ffff           mov.b #0xff:8,r7l
0x0004a862      ffff           mov.b #0xff:8,r7l
0x0004a864      ff00           mov.b #0x0:8,r7l
0x0004a866      01ff0601       sleep
0x0004a86a      ffff           mov.b #0xff:8,r7l
0x0004a86c      ffff           mov.b #0xff:8,r7l
0x0004a86e      ffff           mov.b #0xff:8,r7l
0x0004a870      00ff           nop
0x0004a872      0602           andc #0x2:8,ccr
0x0004a874      ffff           mov.b #0xff:8,r7l
0x0004a876      ffff           mov.b #0xff:8,r7l
0x0004a878      ffff           mov.b #0xff:8,r7l
0x0004a87a      01ff0700       sleep
0x0004a87e      ffff           mov.b #0xff:8,r7l
0x0004a880      ffff           mov.b #0xff:8,r7l
0x0004a882      ffff           mov.b #0xff:8,r7l
0x0004a884      00ff           nop
0x0004a886      0701           ldc #0x1:8,ccr
0x0004a888      ffff           mov.b #0xff:8,r7l
0x0004a88a      ffff           mov.b #0xff:8,r7l
0x0004a88c      ffff           mov.b #0xff:8,r7l
0x0004a88e      01ff0702       sleep
0x0004a892      ffff           mov.b #0xff:8,r7l
0x0004a894      ffff           mov.b #0xff:8,r7l
0x0004a896      ffff           mov.b #0xff:8,r7l
0x0004a898      00ff           nop
0x0004a89a      0000           nop
0x0004a89c      0000           nop
0x0004a89e      0000           nop
0x0004a8a0      0000           nop
0x0004a8a2      0000           nop
0x0004a8a4      070b           ldc #0xb:8,ccr
0x0004a8a6      0d0e           mov.w r0,r6
