create_clock -name spi_io_clk -period 50 -waveform {0 25} [get_nets {spi_io_clk}]
create_clock -name clk_in -period 37.037 -waveform {0 18.5} [get_ports {clk_in}] -add
create_clock -name pmod_companion_clk -period 50 -waveform {0 25} [get_ports {pmod_companion_clk}] -add
create_clock -name spi_sclk -period 50 -waveform {0 25} [get_ports {spi_sclk}] -add
create_generated_clock -name clk_pixel_x10 -source [get_ports {clk_in}] -master_clock clk_in -divide_by 3 -multiply_by 35 [get_pins {mainclock/CLKOUT}]
create_generated_clock -name clk64 -source [get_pins {mainclock/CLKOUT}] -master_clock clk_pixel_x10 -divide_by 5 -multiply_by 1 [get_pins {div1_inst/CLKOUT}]
create_generated_clock -name clk_sys -source [get_pins {div1_inst/CLKOUT}] -master_clock clk64 -divide_by 2 -multiply_by 1 [get_pins {div2_inst/CLKOUT}]
create_generated_clock -name flash_clk -source [get_ports {clk_in}] -master_clock clk_in -divide_by 4 -multiply_by 10 [get_nets {flash_clk}]
create_generated_clock -name clk27_x10 -source [get_ports {clk_in}] -master_clock clk_in -divide_by 1 -multiply_by 10 [get_pins {ceaclock/CLKOUT}]
create_generated_clock -name clk27_x5 -source [get_ports {clk_in}] -master_clock clk_in -divide_by 2 -multiply_by 10 [get_pins {ceaclock/CLKOUTD}]
create_generated_clock -name clk27 -source [get_pins {ceaclock/CLKOUTD}] -master_clock clk27_x5 -divide_by 5 -multiply_by 1 [get_pins {div3_inst/CLKOUT}]
create_clock -name clk_audio -period 20833 -waveform {0 10416.5} [get_pins {video_inst/clk_audio_s0/Q}] -add
set_clock_groups -asynchronous -group [get_clocks {clk_sys}] -group [get_clocks {clk27}]
set_clock_groups -asynchronous -group [get_clocks {clk_sys}] -group [get_clocks {flash_clk}]
set_clock_groups -asynchronous -group [get_clocks {clk_sys}] -group [get_clocks {spi_io_clk}]
set_clock_groups -asynchronous -group [get_clocks {clk_sys}] -group [get_clocks {clk_audio}]
set_clock_groups -asynchronous -group [get_clocks {clk_sys}] -group [get_clocks {pmod_companion_clk}]
set_clock_groups -asynchronous -group [get_clocks {clk_sys}] -group [get_clocks {spi_sclk}]
report_timing -hold -from_clock [all_clocks] -to_clock [all_clocks] -max_paths 100 -max_common_paths 1
report_timing -setup -from_clock [all_clocks] -to_clock [all_clocks] -max_paths 100 -max_common_paths 1

