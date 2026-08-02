//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.01 (64-bit) 
//Created Time: 2025-02-28 17:08:24
create_clock -name clkin -period 20 -waveform {0 10} [get_ports {clk}]
create_clock -name clk_x4 -period 2.857 -waveform {0 1.429} [get_nets {clk_x4}]
create_clock -name clkx1 -period 10 -waveform {0 5} [get_pins {u_ddr3/gw3_top/u_ddr_phy_top/fclkdiv/CLKOUT}]
set_false_path -from [get_clocks {clk_x4}] -to [get_clocks {clkx1}] 
set_false_path -from [get_clocks {clkx1}] -to [get_clocks {clk_x4}] 
set_false_path -from [get_clocks {clkx1}] -to [get_clocks {clkin}] 
set_false_path -from [get_clocks {clkin}] -to [get_clocks {clk_x4}] 
