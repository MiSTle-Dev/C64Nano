#!/bin/bash

rm -f impl/pnr/*.fs

grc --config=gw_sh.grc gw_sh ./build_tm138kpro.tcl
grc --config=gw_sh.grc gw_sh ./build_tm60k.tcl
grc --config=gw_sh.grc gw_sh ./build_tp25k.tcl
grc --config=gw_sh.grc gw_sh ./build_tn20k.tcl
grc --config=gw_sh.grc gw_sh ./build_tn20k_lcd.tcl
grc --config=gw_sh.grc gw_sh ./build_tc60k.tcl
grc --config=gw_sh.grc gw_sh ./build_tc138k.tcl
