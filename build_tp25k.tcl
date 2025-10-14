set_device GW5A-LV25MG121NC1/I0 -name GW5A-25A

add_file src/gen_uart.v
add_file src/c1541/mist_sd_card.sv
add_file src/cartridge.v
add_file src/gowin_dpb/gowin_dpb_track_buffer_b.v
add_file src/gowin_dpb/gowin_dpb_trkbuf.v
add_file src/gowin_dpb/sector_dpram.v
add_file src/hdmi/audio_clock_regeneration_packet.sv
add_file src/hdmi/audio_info_frame.sv
add_file src/hdmi/audio_sample_packet.sv
add_file src/hdmi/auxiliary_video_information_info_frame.sv
add_file src/hdmi/hdmi.sv
add_file src/hdmi/packet_assembler.sv
add_file src/hdmi/packet_picker.sv
add_file src/hdmi/serializer.sv
add_file src/hdmi/source_product_description_info_frame.sv
add_file src/hdmi/tmds_channel.sv
add_file src/misc/flash_dspi_gw5a.v
add_file src/misc/hid.v
add_file src/misc/mcu_spi.v
add_file src/misc/osd_u8g2.v
add_file src/misc/scandoubler.v
add_file src/misc/sd_card.v
add_file src/misc/sd_rw.v
add_file src/misc/sdcmd_ctrl.v
add_file src/misc/sysctrl.v
add_file src/misc/video.v
add_file src/misc/video_analyzer.v
add_file src/misc/ws2812.v
add_file src/mos6526.v
add_file src/reu.v
add_file src/sdram.v
add_file src/c1541/c1541_logic.vhd
add_file src/c1541/c1541_sd.vhd
add_file src/c1541/gcr_floppy.vhd
add_file src/c1541/via6522.vhd
add_file src/c64_midi.vhd
add_file src/cpu_6510.vhd
add_file src/fpga64_buslogic_gw5a.vhd
add_file src/fpga64_keyboard.vhd
add_file src/fpga64_rgbcolor.vhd
add_file src/fpga64_sid_iec.vhd
add_file src/gowin_prom/gowin_prom_basic.vhd
add_file src/gowin_sdpb/gowin_sdpb_kernal_8k_gw5a.vhd
add_file src/gowin_prom/gowin_prom_chargen.vhd
add_file src/gowin_sp/gowin_sp_2k.vhd
add_file src/gowin_sp/gowin_sp_8k.vhd
add_file src/gowin_sp/gowin_sp_cram.vhd
add_file src/t65/T65.vhd
add_file src/t65/T65_ALU.vhd
add_file src/t65/T65_MCode.vhd
add_file src/t65/T65_Pack.vhd
add_file src/tang/primer25k/c64nano.vhd
add_file src/video_vicII_656x.vhd
add_file src/gowin_pll/gowin_pll_pal.vhd
add_file src/gowin_pll/gowin_pll_ntsc.vhd
add_file src/tang/primer25k/c64nano.cst
add_file src/tang/primer25k/c64nano.sdc
add_file src/loader_sd_card.sv
add_file src/fifo_sc_hs/FIFO_SC_HS_Top_gw5a.vhd
add_file src/c1530.vhd
add_file src/sid/sid_dac.sv
add_file src/sid/sid_envelope.sv
add_file src/sid/sid_filter.sv
add_file src/sid/sid_tables.sv
add_file src/sid/sid_top.sv
add_file src/sid/sid_voice.sv
add_file src/uart6551/BaudRate.vhd
add_file src/uart6551/io_fifo.v
add_file src/uart6551/uart_6551.v
add_file src/misc/c64_xml.hex

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name C64Nano_TP25k
set_option -verilog_std sysv2017
set_option -vhdl_std vhd2008
set_option -top_module c64nano_top
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_cpu_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_jtag_as_gpio 1
set_option -rw_check_on_ram 0
set_option -user_code 00000001
set_option -bit_compress 1
set_option -multi_boot 0
set_option -mspi_jump 0
set_option -place_option 2
set_option -route_option 1
set_option -ireg_in_iob 1
set_option -oreg_in_iob 1
set_option -ioreg_in_iob 1
set_option -power_on_reset_monitor 1
set_option -timing_driven 1
set_option -cst_warn_to_error 1
set_option -rpt_auto_place_io_info 1
set_option -convert_sdp32_36_to_sdp16_18 1
set_option -correct_hold_violation 1
set_option -loading_rate 70.000

#run syn
run all
