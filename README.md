# C64Nano

The C64Nano is a port of some [MiST](https://github.com/mist-devel/mist-board/wiki) and
[MiSTer](https://mister-devel.github.io/MkDocs_MiSTer/) core components for the
[C64](https://en.wikipedia.org/wiki/Commodore_64):

| Board      | FPGA       | support |Note|
| ---        |        -   | -     |-|
| [Tang Nano 20k](https://wiki.sipeed.com/nano20k)     | [GW2AR](https://www.gowinsemi.com/en/product/detail/38/)  | HDMI / LCD |Dualshock via MiSTeryShield20k spare header **or** Joy to DIP |
| [Tang Primer 25K](https://wiki.sipeed.com/hardware/en/tang/tang-primer-25k/primer-25k.html) | [GW5A-25](https://www.gowinsemi.com/en/product/detail/60/) | HDMI |no Dualshock, no Retro D9 Joystick, no MIDI |
| [Tang Mega 60k NEO](https://wiki.sipeed.com/hardware/en/tang/tang-mega-60k/mega-60k.html) | [GW5AT-60](https://www.gowinsemi.com/en/product/detail/60/) | HDMI / LCD | twin Dualshock |
| [Tang Mega 138k Pro](https://wiki.sipeed.com/hardware/en/tang/tang-mega-138k/mega-138k-pro.html)|[GW5AST-138](https://www.gowinsemi.com/en/product/detail/60/) | HDMI / LCD |twin Dualshock |
| [Tang Console 60K NEO](https://wiki.sipeed.com/hardware/en/tang/tang-console/mega-console.html)|[GW5AT-60](https://www.gowinsemi.com/en/product/detail/60/) | HDMI / LCD |twin Dualshock, no Retro D9 Joystick|

This project relies on a MPU being connected to the FPGA. --> [MiSTle-Dev wiki](https://github.com/MiSTle-Dev/.github/wiki) <--  

> [!NOTE]
> If you don't need the WIFI modem on a TN20K then even the onboard BL616 MPU (normally used for bitstream programming) can be used. A dedicated FPGA bitstream and FPGA companion firmware is needed in that configuration. The onboard BL616 MPU is presently supported for TN20K, Console 60K, Primer 25k and Mega 138kPro. WIFI modem is supported on Console 60K too (requires I-PEX MHF4 connector antenna)

Original C64 core by Peter Wendrich and c1541 by [darfpga](https://github.com/darfpga).  
All HID components and MPU firmware by Till Harbaum

Features:

* PAL 800x576p@50Hz or NTSC 800x480p@60Hz HDMI Video and Audio Output
* TFT-LCD module 800x600 [SH500Q01Z](https://dl.sipeed.com/Accessories/LCD/500Q01Z-00%20spec.pdf) + Speaker support
* USB Keyboard
* [USB Joystick](https://en.wikipedia.org/wiki/Joystick) or [USB Gamepad](https://en.wikipedia.org/wiki/Gamepad)
* [USB Mouse](https://en.wikipedia.org/wiki/Computer_mouse) as [c1351](https://en.wikipedia.org/wiki/Commodore_1351) Mouse emulation
* [USB Gamepad](https://en.wikipedia.org/wiki/Gamepad) Stick as [Paddle](https://www.c64-wiki.com/wiki/Paddle) Emulation
* [USB XBOX 360 Controller](https://en.wikipedia.org/wiki/Xbox_360_controller) as Joystick or Paddle
* [legacy D9 Joystick](https://en.wikipedia.org/wiki/Atari_CX40_joystick) (Atari / Commodore digital type)
* Joystick emulation on Keyboard Numpad
* [Dualshock 2 Controller Gamepad](https://en.wikipedia.org/wiki/DualShock) for [MiSTeryShield20k](https://github.com/harbaum/MiSTeryNano/tree/main/board/misteryshield20k/README.md) via spare [pinheader](/board/misteryshield20k_ds2_adapter/misteryshield20k_ds2_adapter_cable.md). Adapter [venice1200](https://github.com/venice1200)
* [Dualshock 2 Gamepad](https://en.wikipedia.org/wiki/DualShock) DPad / left Stick as Joystick
* [Dualshock 2 Gamepad](https://en.wikipedia.org/wiki/DualShock) Sticks as [Paddle](https://www.c64-wiki.com/wiki/Paddle) Emulation (analog mode)
* Emulation of [C64GS Cheetah Annihilator](https://en.wikipedia.org/wiki/Commodore_64_Games_System) Joystick 2nd Trigger Button (Pot X/Y)
* emulated [1541 Diskdrive](https://en.wikipedia.org/wiki/Commodore_1541) on FAT/extFAT microSD card with parallel bus [Speedloader Dolphin DOS 2](https://rr.pokefinder.org/wiki/Dolphin_DOS). [GER manual](https://www.c64-wiki.de/wiki/Dolphin_DOS)
* c1541 DOS ROM selection
* Cartridge ROM (*.CRT) loader
* Direct BASIC program (*.PRG) injection loader
* Tape (*.TAP) image loader as [C1530 Datasette](https://en.wikipedia.org/wiki/Commodore_Datasette)
* Loadable 8K Kernal ROM (*.BIN)
* [VIC-II](https://en.wikipedia.org/wiki/MOS_Technology_VIC-II) revision and [6526](https://en.wikipedia.org/wiki/MOS_Technology_CIA) / 8521 selection
* [SID](https://en.wikipedia.org/wiki/MOS_Technology_6581) revision 6581 or 8580 selectable
* 2nd dual SID Option and loadable Filter curves
* emulated [RAM Expansion Unit (REU)](https://en.wikipedia.org/wiki/Commodore_REU) or [GeoRAM](https://en.wikipedia.org/wiki/GeoRAM)
* On Screen Display (OSD) for configuration and loadable image selection (D64/G64/CRT/PRG/BIN/TAP/FLT)
* Physical MIDI-IN and OUT
* RS232 Serial Interface [VIC-1011](http://www.zimmers.net/cbmpics/xother.html) or [UP9600](https://www.pagetable.com/?p=1656) mode to Tang onboard USB-C serial port or external hw pin.
* Swiftlink-232 [6551](https://en.wikipedia.org/wiki/MOS_Technology_6551) WIFI Modem Interface to FPGA-Companion up to 38400 Baud
* Freezer support (e.g. Action Replay)

<img src="./.assets/c64_core.png" alt="image" width="80%" height="auto">

## Installation

The installation of C64 Nano on the Tang Nano 20k board can be done using a Linux PC or a Windows PC
[(Instruction)](INSTALLATION_WINDOWS.md).

## c64 Nano on Tang Primer 25K

See [Tang Primer 25K](TANG_PRIMER_25K.md). PMOD TF-CARD V2 is required !

## c64 Nano on Tang Mega 60k NEO

See [Tang Mega 60K NEO](TANG_MEGA_60K.md)

## c64 Nano on Tang Mega 138k Pro

See [Tang Mega 138K Pro](TANG_MEGA_138Kpro.md)

## c64 Nano on Tang Console 60k NEO

See [Tang Console 60K NEO](TANG_CONSOLE_60K.md)

## c64 Nano with LCD and Speaker

See [Tang Nano LCD](TANG_NANO_20k_LCD.md)

## emulated Diskdrive c1541

Emulated 1541 on a regular FAT/exFAT formatted microSD card including parallel bus Speedloader Dolphin DOS 2.0.
Copy a D64 Disk image to your sdcard and rename it to **disk8.d64** as default boot image.
Add further D64 or G64 images as you like and insert card in TN slot. LED 0 acts as Drive activity indicator.

> [!TIP]
> Disk directory listing: [(or F7 keypress)](https://project64.c64.org/hw/dolphindos.txt)  
> command:  
> LOAD"$",8  
> LIST  
> Load first program from Disk: (or just LOAD if Dolphin Kernal active)  
> LOAD"*",8  
> RUN  

c1541 DOS ROM can be selected from OSD (default Dolphin DOS 2.0, CBM DOS, SpeedDos Plus or JiffyDOS)
In case a program don't load correctly select via OSD the factory default CBM DOS an give it a try.

## Cartridge ROM Loader (.CRT)

Cartridge ROM can be loaded via OSD file selection.
Copy a *.CRT to your sdcard and rename it to **c64crt.crt** as default boot cartridge ROM.
Prevent the cartridge load at boot by OSD CRT selection **No Disk** , **Save settings** and System **Cold Boot**.
> [!TIP]
> **Detach Cartridge** by OSD:
> ```temporary``` **Cartridge unload & Reset** ```permanent``` **No Disk**, **Save settings** and System **Cold Boot**

> [!IMPORTANT]
> Be aware that some Freezer Card CRT might require to use the standard C64 Kernal and the standard C1541 CBM DOS.

## BASIC Program Loader (.PRG)

A BASIC Program *.PRG file can be loaded via OSD file selection.
Copy a .PRG to your sdcard and rename it to **c64prg.prg** as default boot basic program. Prevent the PRG load at boot by OSD PRG selection **No Disk** , **Save settings** and **Reset** or System **Cold Boot**.
> [!TIP]
> Check loaded file by command: **LIST**

> [!IMPORTANT]
> command: **RUN**

## Tape Image Loader (*.TAP)

A [Tape](https://en.wikipedia.org/wiki/Commodore_Datasette) *.TAP file can be loaded via OSD file selection
In order to start a tape download choose C64 CBM Kernal (mandatory as Dolphin DOS doesn't support Tape). Best to save Kernal OSD selection via **Save settings**.
> [!IMPORTANT]
> command: **LOAD**  
> ___ Only if you have [Exbasic Level II](https://www.c64-wiki.de/index.php?title=Exbasic_Level_II&oldid=261004). CRT Basic loaded then use command: 
> **LOAD***  
> Screen will blank!

The file is loaded automatically as soon as TAP file selected via OSD (no need to press PLAY TAPE button) in case ***no** TAP had been previously selected*.
As mentioned screen will blank for several seconds and then display briefly the filename of the to be loaded file. It will blank shortly afterwards again till load completed and take a lot of time...
Copy a *.TAP to your sdcard and rename it to **c64tap.tap** as default tape mountpoint.
For **Tape unload** use OSD TAP selection **No Disk** and **Reset** or System **Cold Boot**
> [!WARNING]
> After board power-up or coldboot a TAP file will **not autoloaded** even if TAP file selection had been saved or c64tap.tap mountpoint available !
> Unblock loader by OSD TAP selection **No Disk** or simply select again the desired TAP file to be loaded after you typed **LOAD**

> [!TIP]
> Check loaded file by command: **LIST**

> [!IMPORTANT]
> command: **RUN**

> [!NOTE]
> The available (muffled) Tape Sound audio can be disabled from OSD.

## Kernal Loader (.BIN)

The build-in Dolphin Kernal is the power-up default C64 Kernal with an excellent C1541 speedloader.
> [!TIP]
> If you are fine with that then there is no need to load another Kernal via OSD and just select OSD Kernal BIN selection **No Disk** and **Save settings**!

In general Kernal ROM files *.BIN can be loaded via OSD selection.
Copy a 8K C64 Kernal ROM .BIN to your sdcard and rename it to **c64kernal.bin** as default boot Kernal.
Prevent Kernal load by OSD Kernal BIN selection **No Disk** and **Save settings** and do a **power-cyle** of the board. In this case the build-in Dolphin Kernal will by default be used after next power cycle.

## SID Filter Curve (.FLT)

Custom Filters curves can optionally be loaded via OSD.
> [!TIP]https://www.telnetbbsguide.com/bbs/software/image-bbs/
> This is in most cases not needed and build-in filters curves are already an optimum.

> [!NOTE]
> Remember to select the 6581 chip, not the 8580.
> Select 'Custom 1' as the filter to activate it. When a custom filter is loaded, there's no difference between custom options Custom 1, 2, and 3. Selecting 'Default' switches back to the built-in filter curve.
https://www.telnetbbsguide.com/bbs/software/image-bbs/
Prevent Filter curve load by OSD Kernal **FLT** selection **No Disk** and **Save settings** and **power-cyle** of the board.

## Core Loader Sequencing

The core will after power cycle/ cold-boot start downloading the images on the sdcard in the following order:

> [!NOTE]
> (1) BIN Kernal, (2) CRT ROM, (3) PRG Basic and finally (4) FLT.

## emulated RAM Expansion Unit REU 1750

For those programs the require a [RAM Expansion Unit (REU)](https://en.wikipedia.org/wiki/Commodore_REU) it can be activated by OSD on demand.

Playing [Sonic the Hedgehog V1.2](https://csdb.dk/release/?id=212523)
Enable REU, and load the PRG.  
Playing around with [GEOS](https://en.wikipedia.org/wiki/GEOS_(8-bit_operating_system))
Enable REU, select c1541 CBM DOS ROM and load the PRG.

## Push Button / DIP Switch utilization

* S1 open OSD **and** Swap the Joystick Ports if OSD **Swap Joys** is set to Off mode.  
(you might to press twice to return to original Joystick port setting)

* S2 Reset

> [!CAUTION]
> A FLASH programm attempt without keeping the board in reset may lead to corruption of the C1541 DOS images stored in FLASH requiring re-programming.
> Nano 20k S2 keep pressed during power-up for FLASH programming of FPGA bitstream  

## OSD

invoke by F12 keypress

* Reset
* Cold Reset + memory scrubbing
* Audio Volume + / -
* Scanlines effect %
* Widescreen activation
* HID device selection for Joystick Port 1 and Port 2
* REU activation
* c1541 Drive disk image selection
* c1541 Disk write protetcion
* c1541 Reset
* c1541 DOS ROM selection
* MIDI configuration
* PAL / NTSC Video mode
* VIC-II revision, 6526 / 8521 and SID 6561/8580 selection
* SID Filter selection
* geoRAM activation
* Loader (CRT/PRG/BIN/TAP/FLT) file selection
* Joystick Port Swap
* Cartridge unload

## Gamecontrol support

<u>legacy single D9 Digital Joystick.</u>  
OSD: **Retro D9**
Atari ST type of Joystick 2nd button supported using a MiSTeryNano shield.  
Don't configure e.g. [ArcadeR](https://retroradionics.com) for C64 mode rather than normal digital 2nd button mode (2nd trigger button connect signal to ground)

<u>USB Joystick(s)</u>.  
OSD: **USB #1 Joy** or **USB #2 Joy**
Also [RII Mini Keyboard i8](http://www.riitek.com/product/220.html) left Multimedia Keys are active if **USB #1 Joy** selected.

<u>Dualshock 2 Gamepad Stick or Dpad as Joystick.</u>.  
OSD: **DS #1 Joy** or **DS #2 Joy**
At the moment Dpad only for original Pad. Some clone devices support at the same time Dpad and left stick simultaniously. ```circle and cross``` Buttons as Trigger:

> [!IMPORTANT]
> In a MiSTeryShield20k configuration Dualshock is supported via the internal ``spare J8`` pinheader.
> See [MiSTeryShield20k DS2 Adapter / Cable](/board/misteryshield20k_ds2_adapter/misteryshield20k_ds2_adapter_cable.md) for further information. Thx [venice1200](https://github.com/venice1200) !

> [!NOTE]
> TN20k: You have to select OSD **DS2 #2 Joy** or **DS #2 Paddle** for a ``MiSTeryShield20k`` configuration.
> TN20k: You have to select OSD **DS2 #1 Joy** or **DS #1 Paddle** if you use the ``Sipeed Joy to DIP`` adapter.
> Single DS interface active at the same time!

<u>Keyboard Numpad.</u>  
OSD: **Numpad**

|Numpad| |Numpad|
|-|-|-|
|0  Trigger|8  Up|.  Trigger 2|
|4  Left|-|6  Right|
|-|2  Down|-|

<u>Mouse.</u>  
OSD: **Mouse**
USB Mouse as c1351 Mouse emulation.

<u>Dualshock 2 Gamepad</u> as Paddle  
OSD: **DS #1 Paddle** or **DS #2 Paddle**
Dualshock left Stick in analog mode as VC-1312 Paddle emulation.
ANALOG Paddle mode will be indicated by DS 2 red light indicator.
> [!NOTE]
> TN20k:
> single Dualshock support only
> 4 Paddles mapped to a single Gamepad (X/Y) and both Sticks.
> **square** , **cross**, **circle** and **triangle** used as 4 Trigger buttons
> ``Joyport 1:``  **DS2 #1 Paddle**
> ``Joyport 2:``  **DS2 #1 Paddle**
> or<br>
> ``Joyport 1:``  **DS2 #2 Paddle**
> ``Joyport 2:``  **DS2 #2 Paddle**

<u>USB Paddle</u>.  
OSD: **USB #1 Padd** or **USB #2 Padd**
Left Stick in X / Y analog mode as VC-1312 Paddle emulation.
Button **cross / square** as Trigger

## Keyboard

 ![Layout](\.assets/keymap.gif)
 PAGE UP (Tape Play) Key or the Tang S1 Button swap the Joystick Ports if OSD **Swap Joys** is set to Off mode.

 
 F2,F4,F6,F8,Left/Up keys automatically activate Shift key.  
 F9 - arrow-up key.  
 F10 - = key.  
 F11 (RESTORE) Key as ``FREEZE``. Typically used by Freezer Cards like Action Replay, Snappy Rom etc.  
 F12 OSD  
 Alt,Tab - C= key.  

## LED UI

| LED | function    | TN20K | TP25K |TM60K|TM138K Pro|Console60K|
| --- |           - | -     | -     | -    |-  |-|
| 0 | c1541 activity| x     | x     | x    |x  |x|
| 1 | D64 selected  | x     | x     | x    |x  |-|
| 2 | CRT seleced   | x     | -     |   -  |x  |-|
| 3 | PRG selected  | x     | -     |   -  |x  |-|
| 4 |Kernal selected| x     | -     |   -  |x  |-|
| 5 | TAP selected  | x     | -     |   -  |x  |-|

Solid **<font color="red">red</font>** of the c1541 led after power-up indicates a missing DOS in Flash

## Multicolor RGB LED

* **<font color="green">green</font>**&ensp;&thinsp;&ensp;&thinsp;&ensp;&thinsp;all fine and ready to go
* **<font color="red">red</font>**&ensp;&thinsp;&ensp;&thinsp;&ensp;&thinsp;&ensp;&thinsp;&ensp;&thinsp;something wrong with SDcard / default boot image
* **<font color="blue">blue</font>**&ensp;&thinsp;&ensp;&thinsp;&ensp;&thinsp;&ensp;&thinsp;MPU firmware detected valid FPGA core
* **<font color="yellow">yellow</font>**&ensp;&thinsp;&ensp;&thinsp;&ensp;&thinsp;FPGA core can't detect valid firmware
* **white**&ensp;&thinsp;&ensp;&thinsp;&ensp;&thinsp;-

## MIDI-IN and OUT

<s>Type of MIDI interface can be selected from OSD. There is support for Sequential Inc., Passport/Sentech, DATEL/SIEL/JMS/C-LAB and Namesoft. You can use a [MiSTeryNano shield](https://github.com/harbaum/MiSTeryNano/tree/main/board/misteryshield20k/README.md) to interface to a Keyboard.</s>

## RS232 Serial Interface Swiftlink-232 <-> WIFI Modem

Have a look: [Wiki WIFI Modem](https://github.com/harbaum/FPGA-Companion/wiki/AT-Wi%E2%80%90Fi-modem)  

Most Terminal programs need the Kernal serial routines therefore select via OSD the CBM Kernal rather than default DolphinDOS.  
In addition select OSD System RS232 mode ``Swiftlink DE``. Also possible ACIA [6551](https://en.wikipedia.org/wiki/MOS_Technology_6551) addresses are: $DE00 (default), $DF00 or $D700.  

> [!NOTE]
> Don't forget to active the ``PETSCII`` character input mode if you are sending commands to the modem !

For a PETSCII or ASCII/ANSI BBS you can use [ccgms](https://github.com/mist64/ccgmsterm).  
Press ``F8`` and select modem ``Swiftlink DE`` and Baudrate of ``38400``.  
You can press ``Shift F8`` to toggle in between the different character [modes](https://github.com/mist64/ccgmsterm/blob/main/Documentation.md).  
Connect to you WIFI AP and have a try: ``ATD`` [bbs.retrocampus.com:6510](https://bbs.retrocampus.com) or just have a look at [telnetbbsguide](https://www.telnetbbsguide.com/bbs/software/image-bbs) and choose as you like.  

For a more exotic Turbo56k protocol BBS use [retroterm](https://github.com/retrocomputacion/retroterm).  

Note: Enabling persitent the Swiftlink-232 ACIA 6551 component at $FE00 will block other things like Multicard CRT ROMS. Adress $D700 doesn't block other HW.

## RS232 Serial Interface VIC-1011/UP9600 <-> USB-C / external HW pins

The Tang onboard USB-C serial port can be used for communication with the C64 Userport Serial port in [VIC-1011](http://www.zimmers.net/cbmpics/xother.html) or [UP9600](https://www.pagetable.com/?p=1656) mode. Terminal programs need the Kernal serial routines therefore select via OSD the CBM Kernal rather than default DolphinDOS. For a first start use UP9600 mode and a Terminal program like [ccgms](https://github.com/mist64/ccgmsterm) and on the PC side [Putty](https://www.putty.org) with 2400 Baud.

OSD selection allows to change in between TANG USB-C port or external HW pin interface.

| Board      |RX (I) FPGA |TX (O) FPGA|Note|
|  -         |   -    |   -  | -   |
| TN20k      |75      | 76   | |
| TP25k      |K5      | L5   | J4-6  J4-5, share M0S Dock PMOD|
| TM60k NEO  |AB20    | AA19 | J24-6 J24-5, share M0S Dock PMOD |
| TM138k Pro |H15     | H14  | J24-6 J24-5, share M0S Dock PMOD |

Remember that in + out to be crossed to connect to external device. Level are 3V3 tolerant.

## Powering

Prototype circuit with Keyboard can be powered by Tang USB-C connector from PC or a Power Supply Adapter.

## Synthesis

Source code can be synthesized, fitted and programmed with GOWIN IDE Windows or Linux.

Alternatively use the command line build script **gw_sh.exe / gw_sh.sh** [build_tn20k.tcl](build_tn20k.tcl) , [build_tp25k.tcl](build_tp25k.tcl) or [build_tm138k.tcl](build_tm138k.tcl)

## HW circuit considerations

**Pinmap TN20k Interfaces**
 Sipeed M0S Dock, digital Joystick D9 and DualShock Gamepad connection.
 ![wiring](\.assets/wiring_spi_irq.png)

## Pinmap D-SUB 9 Joystick Interface

* Joystick interface is 3.3V tolerant. Joystick 5V supply pin has to be left floating !

![pinmap](\.assets/vic20-Joystick.png)

|Joystick pin|IO   |Tang Nano pin| FPGA pin |Joystick Function|
|----------- |-----| ---         | -------- |-----            |
| 1          |2    | J6 10       | 25       | UP              |
| 2          |1    | J6 9        | 28       | DOWN            |
| 3          |4    | J6 12       | 29       | LEFT            |
| 4          |3    | J5 11       | 26       | RIGHT           |
| 5          |-    | -           | -        | POT Y/ TRIGGER 3|
| 6          |0    | J5 8        | 27       | TRIGGER         |
| 7          |-    | n.c         | n.c      | 5V              |
| 8          |-    | J5 20       | -        | GND             |
| 9          |-    | -           | 30       | TRIGGER 2       |

## Pinmap Dualshock 2 Controller Interface

<img src="./.assets/controller-pinout.jpg" alt="image" width="30%" height="auto">

| DS pin | Tang Nano pin | FPGA pin | DS Function |
| ----------- | ---   | --------  | ----- |
| 1 | J5 18 | 71 MISO | JOYDAT  |
| 2 | J5 19 | 53 MOSI  | JOYCMD |
| 3 | n.c. | - | 7V5 |
| 4 | J5 15 | - | GND |
| 5 | J5 16| - | 3V3 |
| 6 | J5 17 | 72 CS | JOYATN|
| 7 | J5 20 | 52 MCLK | JOYCLK |
| 8 | n.c. | - | JOYIRQ |
| 9 | n.c. | - | JOYACK |

## Getting started

In order to use this Design the following things are needed:

[Sipeed M0S Dock](https://wiki.sipeed.com/hardware/en/maixzero/m0s/m0s.html) or Raspberry Pi Pico RP2040 or ESP32-S2/S3  
[Sipeed Tang Nano 20k](https://wiki.sipeed.com/nano20k)  
or [Sipeed Tang Primer 25k](https://wiki.sipeed.com/hardware/en/tang/tang-primer-25k/primer-25k.html)  
and [PMOD DVI](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html#PMOD_DVI)  
and [PMOD TF-CARD V2](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html#PMOD_TF-CARD)  
and [PMOD SDRAM](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html#TANG_SDRAM)  
and [M0S PMOD adapter](https://github.com/harbaum/MiSTeryNano/tree/main/board/m0s_pmod/README.md)  
or ad hoc wiring + soldering.
or [Sipeed Tang Mega 138k Pro](https://wiki.sipeed.com/hardware/en/tang/tang-mega-138k/mega-138k-pro.html)  
and [PMOD SDRAM](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html#TANG_SDRAM)  
and [PMOD DS2x2](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html#PMOD_DS2x2)  
and [M0S PMOD adapter](https://github.com/harbaum/MiSTeryNano/tree/main/board/m0s_pmod/README.md)  
or [Tang Mega 60K NEO](https://wiki.sipeed.com/hardware/en/tang/tang-mega-60k/mega-60k.html)  
and [PMOD SDRAM](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html#TANG_SDRAM)  
and [PMOD DS2x2](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html#PMOD_DS2x2)  
and [M0S PMOD adapter](https://github.com/harbaum/MiSTeryNano/tree/main/board/m0s_pmod/README.md)  
or [Tang Console 60K NEO](https://wiki.sipeed.com/hardware/en/tang/tang-console/mega-console.html)  
and [PMOD DS2x2](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html#PMOD_DS2x2)  
and [Sipeed M0S Dock](https://wiki.sipeed.com/hardware/en/maixzero/m0s/m0s.html)
and [M0S PMOD adapter](https://github.com/harbaum/MiSTeryNano/tree/main/board/m0s_pmod/README.md)  
or a [PMOD RP2040-Zero](/board/pizero_pmod/README.md)  

microSD or microSDHC card FAT32 formatted  
TFT Monitor with HDMI Input and Speaker  


