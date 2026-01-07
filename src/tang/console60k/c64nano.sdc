//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2026-01-02 11:24:06
create_clock -name spi_clk -period 50 -waveform {0 25} [get_ports {spi_sclk}]
create_clock -name ds_clk -period 500 -waveform {0 250} [get_nets {gamepad_p1/clk_spi}]
create_clock -name ds2_clk -period 500 -waveform {0 250} [get_nets {gamepad_p2/clk_spi}]
//create_clock -name i2sclk -period 500 -waveform {0 250} [get_nets {video_inst/i2s_clk}]
create_clock -name spi_io_clk -period 50 -waveform {0 25} [get_nets {spi_io_clk}]
create_clock -name clk64 -period 15.842 -waveform {0 7} [get_nets {clk64}]
create_clock -name clk64_pal -period 15.842 -waveform {0 7} [get_nets {clk64_pal}]
create_clock -name clk64_ntsc -period 15.842 -waveform {0 7} [get_nets {clk64_ntsc}]
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}] -add
create_generated_clock -name clk32 -source [get_nets {clk64}] -master_clock clk64 -divide_by 2 -multiply_by 1 [get_nets {clk32}]
set_clock_groups -asynchronous -group [get_clocks {clk32}] -group [get_clocks {clk64_pal}]
set_clock_groups -asynchronous -group [get_clocks {clk32}] -group [get_clocks {clk64_ntsc}]
set_clock_groups -asynchronous -group [get_clocks {clk32}] -group [get_clocks {spi_clk}]
set_clock_groups -asynchronous -group [get_clocks {clk32}] -group [get_clocks {ds_clk}]
set_clock_groups -asynchronous -group [get_clocks {clk32}] -group [get_clocks {ds2_clk}]

report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
