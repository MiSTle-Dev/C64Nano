create_clock -name m0s[3] -period 50 -waveform {0 25} [get_ports {m0s[3]}]
create_clock -name spi_io_clk -period 50 -waveform {0 25} [get_nets {spi_io_clk}]
create_clock -name clk -period 37.037 -waveform {0 18.5} [get_ports {clk}] -add
create_generated_clock -name clk_pixel_x10 -source [get_ports {clk}] -master_clock clk -divide_by 3 -multiply_by 35 [get_pins {mainclock/CLKOUT}]
create_generated_clock -name mspi_clk -source [get_ports {clk}] -master_clock clk -divide_by 8 -multiply_by 19 -duty_cycle 50 -phase 180 [get_nets {mspi_clk}]
create_generated_clock -name flash_clk -source [get_ports {clk}] -master_clock clk -divide_by 8 -multiply_by 19 [get_nets {flash_clk}]
create_generated_clock -name clk_pixel_x5 -source [get_ports {clk}] -master_clock clk -divide_by 6 -multiply_by 35 [get_pins {mainclock/CLKOUTD}]
create_generated_clock -name clk64 -source [get_pins {mainclock/CLKOUT}] -master_clock clk_pixel_x10 -divide_by 5 -multiply_by 1 [get_pins {div1_inst/CLKOUT}]
create_generated_clock -name clk32 -source [get_pins {div1_inst/CLKOUT}] -master_clock clk64 -divide_by 2 -multiply_by 1 [get_pins {div2_inst/CLKOUT}]
set_clock_groups -asynchronous -group [get_clocks {flash_clk}] -group [get_clocks {clk32}]
set_clock_groups -asynchronous -group [get_clocks {clk32}] -group [get_clocks {m0s[3]}]
set_clock_groups -asynchronous -group [get_clocks {clk32}] -group [get_clocks {spi_io_clk}]
report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
