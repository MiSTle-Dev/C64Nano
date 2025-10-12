
@echo off
set GWSH=C:\Gowin\Gowin_V1.9.11.01_x64\IDE\bin\gw_sh

echo.
echo ============ build mega138k pro ===============
echo.
%GWSH% build_tm138kpro.tcl
echo.
echo ============ build mega 60k  ===============
echo.
%GWSH% build_tm60k.tcl
echo.
echo ============ build primer 25k  ===============
echo.
%GWSH% build_tp25k.tcl
echo.
echo ============ build nano 20k  ===============
echo.
%GWSH% build_tn20k.tcl
echo.
echo ============ build mega138k pro LCD ===============
echo.
%GWSH% build_tm138kpro_lcd.tcl
echo.
echo ============ build mega 60k LCD ===============
echo.
%GWSH% build_tm60k_lcd.tcl
echo.
echo ============ build nano 20k LCD ===============
echo.
%GWSH% build_tn20k_lcd.tcl
echo.
echo ============ build console 60k ===============
echo.
%GWSH% build_tc60k.tcl
echo.
echo "done."
dir impl\pnr\*.fs

