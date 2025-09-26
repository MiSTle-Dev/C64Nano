create_clock -name ds_clk -period 500 -waveform {0 250} [get_nets {gamepad_p1/clk_spi}] -add
create_clock -name ds2_clk -period 500 -waveform {0 250} [get_nets {gamepad_p2/clk_spi}] -add
create_clock -name flash_clk -period 15.833 -waveform {0 7.5} [get_nets {flash_clk}] -add
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}] -add
create_clock -name clk32 -period 32.708 -waveform {0 16} [get_nets {clk32}] -add
create_clock -name clk64 -period 65.415 -waveform {0 30} [get_nets {clk64}] -add
create_clock -name clk_pixel_x5 -period 6.115 -waveform {0 3} [get_nets {clk_pixel_x5}] -add
create_clock -name clk_audio -period 20833 -waveform {0 10000} [get_nets {video_inst/clk_audio}] -add
create_clock -name mspi_clk -period 15.287 -waveform {0 7.5} [get_ports {mspi_clk}] -add
create_clock -name spi_clk -period 50 -waveform {0 25} [get_ports {spi_sclk}] -add
set_clock_groups -asynchronous -group [get_clocks {flash_clk}] -group [get_clocks {clk_audio}] -group [get_clocks {clk64}] -group [get_clocks {clk32}] -group [get_clocks {spi_clk}] -group [get_clocks {clk_pixel_x5}]
report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
