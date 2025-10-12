create_clock -name clk -period 37.037 -waveform {0 18.5} [get_ports {clk}] -add
create_generated_clock -name clk_pixel_x10 -source [get_ports {clk}] -master_clock clk -divide_by 3 -multiply_by 35 [get_pins {mainclock/CLKOUT}]
create_generated_clock -name mspi_clk -source [get_ports {clk}] -master_clock clk -divide_by 7 -multiply_by 26 -duty_cycle 50 -phase 135 [get_pins {flashclock/CLKOUTP}]
create_generated_clock -name clk64 -source [get_pins {mainclock/CLKOUT}] -master_clock clk_pixel_x10 -divide_by 5 -multiply_by 1 [get_pins {div1_inst/CLKOUT}]
create_generated_clock -name clk32 -source [get_pins {div1_inst/CLKOUT}] -master_clock clk64 -divide_by 2 -multiply_by 1 [get_pins {div2_inst/CLKOUT}]
report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
