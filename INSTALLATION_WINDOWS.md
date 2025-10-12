# Installation using a Windows PC

This document explains how to install all the necessary files on the
Tang Nano 20K and the M0S Dock in order to use it as a C64 Nano
device.

This has been tested on Windows 11. It should work on older versions too.

Software needed:

  - [Gowin V1.9.11.01](https://www.gowinsemi.com/en/support/home/) **to synthesize the core**
  - [Gowin V1.9.11.02](https://www.gowinsemi.com/en/support/home/) **to program the flash of the TANG FPGA**
  - [BouffaloLabDevCube](https://dev.bouffalolab.com/download) **to flash the BL616**
  - [Latest release](https://github.com/vossstef/tang_nano_20k_c64/releases/latest) of C64Nano **FPGA** bitstream
  - [Latest release](http://github.com/harbaum/FPGA-Companion) of FPGA-Companion **BL616 µC firmware** (if not otherwise stated in the release note)
  - [Latest release](https://dl.sipeed.com/shareURL/TANG/Debugger/onboard/BL616) of the TANG onboard µC bl616 programmer firmware

In order to use the SD card for disks:

  - C64 disk images in .D64 or .G64 format
  - Cartridge images in .CRT format
  - BASIC Program files in .PRG format
  - Tape images in .TAP format
  - C64 Kernal files (8K) in .BIN format
  - SID Filter curve in .FLT format

# Flashing the Tang Nano 20k

First download the Gowin IDE. The Education version is sufficient and
won't need a licence.

Install the IDE on your system (follow the installation instructions
from Gowin).  After the Installation you should have it as an shortcut
on your desktop or in your start menu.

 - Press the ```S2``` button on the Tang Nano 20K and keep it pressed
 - Connect the Tang Nano 20k to the USB on your computer. You should hear the connecting sound of Windows.
 - Release the ```S2``` button

> [!CAUTION]
A FLASH programm attempt without keeping the board in reset may lead to corruption of the C1541 DOS images stored in FLASH requiring re-programming.

 - Start Gowin. **You should see the following screen**

Explanation: The C64Nano core makes use of the flash memory of the
Tang Nano 20k to store c1541 DOS ROMs. This may interfere with the FPGA
flash process. Pressing the ```S2``` during power up will prevent the
Tang Nano 20k from booting into the C64Nano core and will make sure
the flash ROM can be updated.

![](https://github.com/vossstef/tang_nano_20k_c64/blob/main/.assets/gowin1.jpg)

Now press on the “programmer” marked red on the picture above. **You
should see following screen:**

![](https://github.com/vossstef/tang_nano_20k_c64/blob/main/.assets/device.png)

-   Press save on the dialog
-   From there you can add a device for programming by pressing on the little
    icon with the green plus
-   At least three files have to be flashed:
    - The core itself: ```tang_nano_20k_c64.fs```
    - Two c1541 DOS ROMs
-   Than you can choose from the drop downs the parameter you see on the
    pictures.

**Important**:

  - ```tang_nano_20k_c64.fs``` is written to address 0x000000
  - ```reserved for Atari ST ROM``` address 0x100000
  - ```c1541 DOS Dolphin 2``` is written to address 0x200000
  - ```c1541 DOS CBM``` is written to address 0x20C000

Optionally two additional DOS ROMs may be flashed to the alternate
addresses:

  - ```c1541 DOS Speeddos Plus``` is written to address 0x214000
  - ```c1541 DOS Jiffy``` is written to address 0x21C000

These DOS for the c1541 emulation can later be selected from the on-screen-display (OSD).
  - For the FS file please choose the ```tang_nano_20k_c64.fs``` you just downloaded
  - User Code and IDCODE can be ignored
  - Mark each of your configs and press the little icon with the green play
    button. You should see a progress bar and then:

![](https://github.com/vossstef/tang_nano_20k_c64/blob/main/.assets/c64_flash.png)
**At a glance the memory layout of the SPI Flash:**

|                           |          |          |          |          |         | |
|                          -|         -|         -|         -|         -|        -|-|
| Type                      | TN20k    | TP25k    | TM60k    |TM138k    |Console60k/138k| |
| FPGA bitstream            | 0x000000 | 0x000000 | 0x000000 | 0x000000 |0x000000 |ROM size|
| reserved for Atari ST ROM | 0x100000 | 0x100000 | 0x500000 | 0x900000 |0x500000 | - |
| c1541 Dolphin DOS 2       | 0x200000 | 0x200000 | 0x700000 | 0xA00000 |0x700000 |32k|
| c1541 CBM DOS 2.6         | 0x20C000 | 0x20C000 | 0x70C000 | 0xA0C000 |0x70C000 |16k|
| c1541 Speed DOS Plus      | 0x214000 | 0x214000 | 0x714000 | 0xA14000 |0x714000 |16k|
| c1541 Jiffy DOS           | 0x21C000 | 0x21C000 | 0x71C000 | 0xA1C000 |0x71C000 |16k|

**shell / command line Programming alternative**

Windows shell and Gowin Programmer<br>
```programmer_cli  -r 36 --fsFile tang_nano_20k_c64.fs --spiaddr 0x000000 --cable-index 1 --d GW2AR-18C```<br>
```programmer_cli  -r 36 --fsFile tang_nano_20k_c64_25k.fs --spiaddr 0x000000 --cable-index 1 --d GW5A-25A```<br>
```programmer_cli  -r 36 --fsFile tang_nano_20k_c64_60k.fs --spiaddr 0x000000 --cable-index 1 --d GW5AT-60B```<br>
```programmer_cli  -r 36 --fsFile tang_nano_20k_c64_138k.fs --spiaddr 0x000000 --cable-index 1 --d GW5AST-138B```<br>

```programmer_cli -r 38 --mcuFile 2dosa_c.bin --spiaddr 0x200000 --cable-index 1 --d GW2AR-18C```<br>
```programmer_cli -r 38 --mcuFile 2dosa_c.bin --spiaddr 0x200000 --cable-index 1 --d GW5A-25A```<br>
```programmer_cli -r 38 --mcuFile 2dosa_c.bin --spiaddr 0x700000 --cable-index 1 --d GW5AT-60B```<br>
```programmer_cli -r 38 --mcuFile 2dosa_c.bin --spiaddr 0xA00000 --cable-index 1 --d GW5AST-138B```<br><br>
Linux shell and [openFPGAloader](https://github.com/trabucayre/openFPGALoader).<br>
[Please read here if you run into trouble when using openFPGAloader under Linux](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-Doc/flash-in-linux.html).<br>
```openFPGALoader -b tangnano20k --external-flash -o 0x200000  2dosa_c.bin```<br>
```openFPGALoader -b tangnano20k -f tang_nano_20k_c64.fs```<br>
<br>
```openFPGALoader -b tangprimer25k --external-flash -o 0x200000  2dosa_c.bin```<br>
```openFPGALoader -b tangmega138k --external-flash -o 0xA00000  2dosa_c.bin```<br>

**c1541 DOS ROM binaries** <br>
The needed DOS files you will find on the Internet.<br>
```Dolphin DOS 2```<br>
You will [find](https://e4aws.silverdr.com/projects/dolphindos2/) 2dosa_c.bin<br>
Program at offset 0x200000<br>
![](https://github.com/vossstef/tang_nano_20k_c64/blob/main/.assets/dolphin.png)

```CBM DOS```<br>
You will [find](https://sourceforge.net/p/vice-emu/code/HEAD/tree/trunk/vice/data/DRIVES/dos1541-325302-01%2B901229-05.bin) dos1541-325302-01+901229-05.bin<br>
Program at offset 0x20C000<br>

```Speed DOS Plus```<br>
You will [find](https://rr.pokefinder.org/wiki/Speed_DOS#Binaries) or [here](https://csdb.dk/release/?id=21767&show=summary) C1541.ROM<br>
Program at offset 0x214000<br>

```Jiffy DOS```<br>
You will get a 16k [JiffyDos](https://www.go4retro.com/products/jiffydos/) JiffyDOS_C1541.bin file.<br>
Program at offset 0x21C000<br>

**That´s it for the Tang Nano 20k**

## Flashing the BL616 µC

For the BL616 you have to extract and start the BuffaloLabDevCube. 

**If you use the internal BL616 present on the Tang Nano 20K you loose
your possibility to flash the Tang over the USB connection.** It is thus
strongly recommended to use an external BL616 (e.g. a M0S Dock).

However, when using the internal BL616 you will be able to flash the
[original firmware](https://github.com/harbaum/MiSTeryNano/blob/main/bl616/friend_20k)
to the internal BL616 again to restore the flasher functionality of
the Tang Nano 20K. Using an external M0S is nevertheless recommended.

-   Press the ```BOOT``` button on your M0S Dock before you plug the USB connection
    on your PC. You should hear the hardware detecting sound.
-   Start the BuffaloLabDevCube from the directory where you decompressed it it
    ask you what chip should be used. Select BL616/BL618 and press “finish”

![](https://github.com/vossstef/tang_nano_20k_c64/blob/main/.assets/buffstart.png)

- You'll now see the program screen. On the right it should auto detect your
  device with a COM port. If not take a look in the device manager to check for
  the correct device detection.
- On the top click on MCU and browse to the firmware image file named
  ```misterynano_fw_bl616.bin``` (contains a unified firmware both for all cores)
- Choose “Open Uart” and than press “Create & Download”. The firmware should now be
  flashed

![](https://github.com/vossstef/tang_nano_20k_c64/blob/main/.assets/bufffinish.png)

## Prepare the SD card

Format the SD card in FAT32. Copy your D64 / G64 / CRT / PRG / BIN / FLT files files on
it. You can organize your files in subdirectories. These files can later
be selected using the on-screen-display (OSD).
Default Mountpoints:  
Copy a *.D64 Disk image to your sdcard and rename it to disk8.d64 as default c1541 boot image.  
Copy a *.CRT ROM image to your sdcard and rename it to c64crt.crt as default Cartridge boot image.  
Copy a *.PRG BASIC file to your sdcard and rename it to c64prg.prg as default Program boot image.  
Copy a *.TAP Type image to your sdcard and rename it to c64tap.tap as default tape boot image. 
Copy a 8k Byte C64 Kernal ROM file *.BIN to your sdcard and rename it to c64kernal.bin as default Kernal boot image.<br>
Copy a *.FLT sid filter curve to your sdcard and rename it to c64flt.flt as default filter boot image.<br>

That´s it for now. Have fun using the C64Nano
