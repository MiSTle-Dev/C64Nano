//Copyright (C)2014-2024 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.9.01 (64-bit) 
//Created Time: 2024-02-23 14:26:15
create_clock -name clk32 -period 31.746 -waveform {0 5} [get_nets {clk32}]
create_clock -name flash_clk -period 15.595 -waveform {0 5} [get_nets {flash_clk}]
create_clock -name clk64 -period 15.873 -waveform {0 5} [get_nets {clk64}]
create_clock -name ds2_clk -period 8000 -waveform {0 5} [get_nets {gamepad/clk_spi}]
create_clock -name clk_pixel_x10 -period 3.175 -waveform {0 1.587} [get_nets {clk_pixel_x10}]
create_clock -name joymiso -period 8000 -waveform {0 20} [get_ports {joystick_miso}]
create_clock -name clk -period 37.037 -waveform {0 5} [get_ports {clk}]
create_clock -name clk_pixel_x5 -period 6.349 -waveform {0 1.25} [get_nets {clk_pixel_x5}] -add
create_clock -name clk_audio -period 20833.332 -waveform {0 5} [get_nets {video_inst/clk_audio}] -add
create_clock -name mspi_clk -period 15.595 -waveform {0 5} [get_ports {mspi_clk}] -add
report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
