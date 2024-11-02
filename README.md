Amiga CPU Blit Read-Only (Proof of Concept ROM)
===============================================

Racing The Beam on the Amiga without RAM
----------------------------------------

Target requirements:  
  - Motorola 68000/68010 CPU @ 7 MHz (fixed timing)
  - PAL on reset (NTSC possible, but needs rewrite)

The current research state fills a standard PAL LoRes screen (320x256)
with four colors per scanline completely with the CPU. The chipset is
setup to draw and fill three bitplanes by DMA from uninitialized Chip
RAM (in fact, the machine does not require any installed RAM modules).
The first bitplane is masked with identical colors. The bitplane data
for the other bitplanes is overridden by the CPU (right after the DMA
controller filled the bitplane data registers). There are even enough
CPU cycles left to write one long per scanline to any memory location
(used to update one color per scanline: more than four screen colors).

Release files:  
  - [cpubltro-a1k.adf](cpubltro-a1k.adf) Kickstart disk (Amiga 1000)
  - [cpubltro-0fc.rom](cpubltro-0fc.rom) 256K ROM image (MapROM or emulator)
  - [cpubltro-0f8.rom](cpubltro-0f8.rom) 512K ROM image (MapROM or emulator)
  - [cpubltro-0f8.bin](cpubltro-0f8.bin) 512K byte swapped ROM image (EPROM)

If all works as expected, the screen looks like this:  
![Amiga CPU Blit Read-Only - main screen image](cpubltro.png)

TODO: Fill the remaining ROM space with animation frames.


Details
-------

DMA Time Slot Allocation / Horizontal Line
(Amiga Hardware Reference Manual - edited/fixed):  
![DMA Time Slot Allocation / Horizontal Line](dmasloth.png)

The DMA controller (Agnus) fetches the bitplane data words from Chip RAM and
sends it to the video processor (Denise) by writing to the BPLxDAT registers.
The Denise converts that planar registers into a color lookup and serializes
it for the video DAC (Vidiot). Since this conversion is triggered by BPL1DAT
and BPLxDAT can be written by the CPU, we are able to overwrite the data for
the second and third bitplane (long write, the slots are next to each other).

With active ROM overlay and/or read-only RAM, we have:  
  - only 16 CPU registers as object memory, for everything
  - no stack (exceptions/interrupts more or less unusable)
  - no sprites, no copper, very limited blitter (BLTNZERO)
  - no control over the bitplane data fetched by the Agnus

The last point automatically implies that we have to override the bitplane
data for the whole display window. While the first bitplane can be ignored
(double color table entries), we need to fetch and write 20 words per line
and bitplane for a normal 320px LoRes screen (HiRes is out of the question
due to too few free CPU slots). Therefore, we have to (extremely cleverly)
fill registers, fetch memory, and write the BPLxDAT registers at the right
time (exactly every eight slots without any room for write timing errors).

Copying a long (BPL2DAT/BPL3DAT) takes at least ten slots (.R.r.W.w.p) and
if you do this every other block, only six slots remain in between and the
writes for the next block must start exactly four slots later. Fortunately,
the PEA instruction prefetches the next instruction word before writing to
memory (unusual) and is short enough. But this forces the use (and balance
due to pre-decrement) of the SP register for referencing the bitplane data
registers. One address register has to refer to the image source data (A6).

| Step  | Inst                    | Slots              |
| :---- | :---------------------- | :----------------- |
| ReadR | `MOVEM.L (A6)+,D1-A5`   | `.p(.R.r){13}.R.p` |
| SetCn | `MOVE.L  D7,(A0)`       | `.W.w.p`           |
| BlitM | `MOVE.L  (A6)+,(SP)[+]` | `.R.r.[-]W.w.p`    |
| BlitA | `PEA     (An);-(SP)`    | `.p.W.w`           |
| BlitD | `MOVE.L  Dn,(An)[+]`    | `.W.w.p`           |
| MoveA | `MOVEA.L Dn,An`         | `.p`               |

Please note that all the above instructions use an even number of slots,
and all PAL lines have an odd slot count of 227 ($00-$E2). However, the
CPU must wait with chipset register writes when the slot is used by DMA.

There are not enough CPU slots per scanline remaining to synchronize on
every horizontal line. Only the first displayed line is started in sync
and the following lines are completely filled with CPU instructions. It
even allows us to fetch two more longs and write a long to any location
(this will be used to update one screen color at the start of the line).
The draw loop is completely unrolled and is currently 13 KiB (52 * 256)
in size. Compared to the 22 KiB (4 * 2 + 22 * 4 * 256) image/field data,
it looked more appealing (to me :-] ) to have more colors on the screen.
In the end the drawing routine uses all but one register left for state.

Updating color registers should happen very early inside the horizontal
line, because the Denise needs some time to serialize the data and uses
the currently active color entries. Updating the color right after last
bitmap data word, the color would be used for the display of this block.
It is also easier to understand/code that this value is for the current
line. Therefore, the color is written right after the long fetch (which
starts in the previous line) and is used/displayed far left at slot $30.

| Symbol  | Description                                                |
| :------ | :--------------------------------------------------------- |
| `m`     | DMA memory refresh channel (RGA used for video sync codes) |
| `d`     | DMA disk channel (custom.dskdatr/dskdat: disabled)         |
| `s`     | DMA sprite channels (custom.spr.dataa/datab: disabled)     |
| `1`-`3` | DMA bitplane channels (custom.bpl1dat/bpl2dat/bpl3dat)     |
| `b`     | Unused DMA bitplane slots (outside DIW and bitplane 4)     |
| `.`     | CPU intruction processing                                  |
| `p`     | CPU intruction word (pre)fetch                             |
| `R`/`r` | CPU memory read (big-endian most/least significant word)   |
| `W`/`w` | CPU memory write (big-endian most/least significant word)  |
| `-`     | CPU wait cycles (chipset register write blocked by DMA)    |

|  Draw |                     CPU/DMA Time Slot Allocation / Horizontal Line |
| ----: | -----------------------------------------------------------------: |
|  Time | `DDDDDDEEE0000000000000000111111111111111122222222222222223333333` |
|  slot | `ABCDEF0120123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456` |
|   DMA | `b_b_b_b__m_m_m_m_d_d_d_a_a_a_a_s_s_s_s_s_s_s_s_s_s_s_s_s_s_s_s_b` |
| ReadR | `.p.R.r.R.r.R.r.R.r.R.r.R.r.R.r.R.r.R.r.R.r.R.r.R.r.R.r.R.p______` |
| SetCn | `__________________________________________________________.W.w.p` |
| Image | `___>D1_>D2_>D3_>D4_>D5_>D6_>D7_>A0_>A1_>A2_>A3_>A4_>A5____D7/A0>` |
|  Time |      `33333333344444444444444445555555555555555666666666666666677` |
|  slot |      `789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF01` |
|   DMA |      `_b_b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_` |
| BlitM |      `.R.r.-W.w.p______.R.r.W.w.p______.R.r.W.w.p______.R.r.W.w.p` |
| BlitA |      `___________.p.W.w__________.p.W.w__________.p.W.w__________` |
| Image |      `_____>M1>_____A1>____>M2>_____A2>____>M3>_____A3>____>M4>__` |
|  Time |         `7777777777777788888888888888889999999999999999AAAAAAAAAA` |
|  slot |         `23456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789` |
|   DMA |         `b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_` |
| BlitM |         `______.R.r.W.w.p______.R.r.W.w.p________________________` |
| BlitA |         `.p.W.w__________.p.W.w__________________________________` |
| BlitD |         `__________________________________.W.w.p__.W.w.p__.W.w.p` |
| MoveA |         `________________________________.p______.p______.p______` |
| Image |         `___A4>____>M5>_____A5>____>M6>_____D1>_____D2>_____D3>__` |
|  Time |                 `AAAAAABBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCDDDDDDDDDD` |
|  slot |                 `ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789` |
|   DMA |                 `b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_b_2_3_1_` |
| BlitM |                 `______.R.r.W.w.p______.R.r.W.w.p______.R.r.W.w.p` |
| BlitA |                 `.p.W.w__________.p.W.w__________.p.W.w__________` |
| Image |                 `___D4>____>M7>_____D5>____>M8>_____D6>____>M9>__` |

The DMA controller (Agnus) and the video processor (Denise) have their own
internal horizontal position (HPOS) counters. The Denise reinitializes its
HPOS counter when the Agnus writes the STREQU/STRVBL/STRHOR registers, and
internally has double the resolution (CCK * 2). The Agnus HPOS counter can
be read from the VHPOSR register, but even if it's counting CCK/slots, the
Agnus HPOS counter is four (9 / 2) slots further than the documented above.
And while we're at it: note that the Agnus VPOS is incremented at HPOS = 2.

Supporting the 68010 makes the synchronization even more complex, since the
68010 instructions are sometimes faster, especially if a branch isn't taken.
That's the reason why the VHPOSR register is read again after the wait loop.
Using a jump tower with NOPs (word aligned, two slots), forces us to remove
the least significant (odd) bit and always synchronizing to even time slots
(the odd off-by-one slots will be indirectly fixed by the blocked DMA slot).

Doing the math for synchronizing the 68000 to `$DA`:  
  - `$D0` is the maximum position to read the HPOS for the jump offset
  - `$BC` is the maximum position where we have to leave the wait loop

| 68000 | Synchronization                               |
| ----: | :-------------------------------------------- |
| Agnus | `BBBBBBBBBBBBCCCCCCCCCCCCCCCCDDDDDDDDDDDDDDD` |
|  HPOS | `456789ABCDEF0123456789ABCDEF0123456789ABCDE` |
|  move | `______.r.p_______.r.p______________________` |
|   cmp | `__________.p_________.p____________________` |
|   blo | `____________..p.p______...p________________` |
|  move | `___________________________.r.p____________` |
|   sub | `_______________________________.p__________` |
|   and | `_________________________________.p________` |
|   jmp | `___________________________________....p.p_` |
|  Time | `BBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCDDDDDDDDDDD` |
|  slot | `0123456789ABCDEF0123456789ABCDEF0123456789A` |

Doing the math for the 68010, leaving loop on `$BC`:  
  - `$C4` (`$C5 & ~1`) is the minimum HPOS we have to support
  - therefore, the jump tower has to contain at least six NOP

| 68010 | Synchronization                               |
| ----: | :-------------------------------------------- |
| Agnus | `BBBBBBBBBBBBCCCCCCCCCCCCCCCCDDDDDDDDDDDDDDD` |
|  HPOS | `456789ABCDEF0123456789ABCDEF0123456789ABCDE` |
|  move | `_______.r.p________________________________` |
|   cmp | `___________.p______________________________` |
|   blo | `_____________..p___________________________` |
|  move | `________________.r.p_______________________` |
|   sub | `____________________.p_____________________` |
|   and | `______________________.p___________________` |
|   jmp | `________________________....p.p____________` |
|   nop | `_______________________________.p.p.p.p.p.p` |
|  Time | `BBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCDDDDDDDDDDD` |
|  slot | `0123456789ABCDEF0123456789ABCDEF0123456789A` |

The implemented jump tower contains 7 NOPs (1 << 4 - 2 bytes = 0x0E),
which allows us to use the jump tower size as a jump offset mask, to
avoid jumping too far on faster CPUs (display garbage, but no crash).


Notes
-----

Comments, bugfixes, and tests on real hardware are very welcome.

Emulation requires a very accurate CPU/DMA simulation, e.g.:  
  - [WinUAE](https://www.winuae.net/download/) 5.0.0+ (Windows/Wine)
  - [vAmiga.net](https://vamiganet.github.io/) (vAmiga online version)

Previous research states:  
  - [v0.2.1](https://github.com/nicodex/amiga-ocs-cpubltro/tree/v0.2.1)
    `EHB42 mode`, static 352x280 image
  - [v0.1](https://github.com/nicodex/amiga-ocs-cpubltro/tree/v0.1)
    `EHB42 mode`, simple loop counter

`EHB42 mode` is my name for an Amiga OCS/ECS chipset anomaly:  
With `BPLCON0.BPU = 7` the Agnus fills 4 bitplanes with DMA,
but the Denise draws 6 bitplanes (in Extra Half Brite mode).
`BPL5DAT/BPL6DAT` are not written by the Agnus and can/have
to be filled by CPU. This can/will be used for nice effects.


License
-------

This work is 'public domain' and licensed under the [CC0 1.0 Universal] license.

- [TLDRLegal: CC0 1.0 Universal](https://www.tldrlegal.com/license/creative-commons-cc0-1-0-universal)
- [gnu.org/licenses: CC0 1.0 Universal](https://www.gnu.org/licenses/license-list.html#CC0)

This project attempts to conform to the [REUSE] recommendations.

[CC0 1.0 Universal]: LICENSES/CC0-1.0.txt
[REUSE]: https://reuse.software/

