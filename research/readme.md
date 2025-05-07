Links
=====

- [Yet Another Cycle Hunting Table (Yacht)](https://www.atari-forum.com/viewtopic.php?f=68&t=24710)


Boing
=====

Oldest `Boing!` animation found on `Workbench Demos` disk from 1985-08-22.

Grabs
-----

Scaled with effective original ball PAR 20:23 (DAR 32:23).

![Workbench Demos Animations](images/wbdemos-boing-1.png)  
![Boing! ball initialization](images/wbdemos-boing-2.png)
![Boing! line initialization](images/wbdemos-boing-3.png)  
![Boing! grid initialization](images/wbdemos-boing-4.png)
![Boing! back initialization](images/wbdemos-boing-5.png)  
![Boing! initialization done](images/wbdemos-boing-6.png)

Ghidra
------

More or less complete analysis of the above `Boing!` executable.

- install [Ghidra 11.3.1](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_11.3.1_build)
  and the [Motorola FFP extension](https://github.com/nicodex/ghidra_motorolaffp/releases)
- restart Ghidra and restore [ghidra/wb_1.0_demos-22aug85-boing.gar](ghidra/wb_1.0_demos-22aug85-boing.gar)  
  ![Restore wb_1.0_demos-22aug85](ghidra/wb_1.0_demos-22aug85.png)
- double-click `wb_1.0_demos-22aug85/Animations/Boing!` and take a look around  
  ![Ghidra Boing! (1985-08-22)](ghidra/wb_1.0_demos-22aug85-boing.png)

