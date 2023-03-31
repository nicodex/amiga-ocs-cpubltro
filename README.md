Amiga CPU Blit Read-Only (Proof of Concept ROM)
===============================================

Testing CPU drawing without _any_ memory writes.

Target: PAL OCS/ECS with 7(4+2)-bitplane anomaly  
(Agnus: 4-bitplane DMAs, Denise: 6-bitplane EHB,  
last two bitplane data is written with the CPU).


Notes
-----

Judging from the tests on my Amiga 500,  
even with an MC68000 it seems possible  
(with some preloading and loop unrolling)  
to fill the blitplane just in time.

- 11 MSB bits undrawn in left-most word
- example sequence (last complete line):
```
00: 0000000000100001
01: 0000000000100000
02: 0000000000011111
03: 0000000000011111 ; repeat
04: 0000000000011110
05: 0000000000011101
06: 0000000000011100
07: 0000000000011011
08: 0000000000011011 ; repeat
09: 0000000000011010
0A: 0000000000011001
0B: 0000000000011000
0C: 0000000000010111
0D: 0000000000010111 ; repeat
0E: 0000000000010110
0F: 0000000000010101
10: 0000000000010100
11: 0000000000010011
12: 0000000000010011 ; repeat
13: 0000000000010010
14: 0000000000010001
15: 0000000000010000
16: 0000000000001111
17: 0000000000001111 ; repeat
```

![A500 MC68000](captures/a500-000-ecs_1.png)
