create_clock -name clk -period 20 -waveform {0 5} [get_ports {clk}]
create_clock -name clk32 -period 31.746 -waveform {0 5} [get_nets {clk32}]
create_clock -name clk64 -period 15.873 -waveform {0 5} [get_nets {clk64}]
create_clock -name clk_pixel_x5 -period 6.349 -waveform {0 1} [get_nets {clk_pixel_x5}] -add
create_clock -name clk_audio -period 20833 -waveform {0 5} [get_nets {video_inst/clk_audio}] -add
create_clock -name mspi_clk -period 15.595 -waveform {0 5} [get_ports {mspi_clk}] -add
create_clock -name spi_io_clk -period 50 -waveform {0 25} [get_nets {spi_io_clk}]
create_clock -name pmod_companion_clk -period 40.000 -waveform {0 25} [get_ports {pmod_companion_clk}] -add
report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
set_clock_groups -asynchronous -group [get_clocks {clk_audio}] 
                               -group [get_clocks {clk64}] 
                               -group [get_clocks {clk32}] 
                               -group [get_clocks {clk_pixel_x5}] 