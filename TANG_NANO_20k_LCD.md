# C64Nano with LCD Output

Video output is adapted for a 5" TFT-LCD module 800x480 Type [SH500Q01Z](https://dl.sipeed.com/Accessories/LCD/500Q01Z-00%20spec.pdf) (Ilitek ILI6122)

Sipeed sells a 5 inch LCD for the Tang Nano 20k. This LCD has a resultion
of 800x480 pixels and attaches directly to the Tang Nano 20k without using the
HDMI connector. This is supported by all cores. The Tang 20k, 60k and 138k Pro additionally comes with a built-in I2S DAC and audio amplifier which comes
in handy in this setup to add sound output.

> [!NOTE]
> TN20k: No Dualshock, no D9 retro Joystick, no external RS232 support

For actual board setup also have a look at the [VIC20][def] pages.

## Adhoc setup of a TN20k, LCD, Speaker and M0S

**Pinmap TN20k Interfaces LCD Output**
LCD, Speaker

![setup](\.assets/tn20k_lcd.png)

## Adhoc setup of a TM60k, LCD, Speaker and M0S

> [!IMPORTANT]
> To enable the LCD Interface the tiny jumper J17 (near Button Key1 ) need to be plugged to position 1 + 2.

![setup](\.assets/tm60k_lcd.png)

[def]: https://github.com/vossstef/VIC20Nano/blob/main/TANG_LCD.md
