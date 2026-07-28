set board "mistle_gw5a_25"
set config "amiga"
source scripts/update_xml.tcl

set_device GW5A-LV25LQ144C1/I0 -name GW5A-25A

add_file am29f040.sv
add_file gen_uart.v
add_file c1541/mist_sd_card.sv
add_file cartridge.sv
add_file gowin_dpb/gowin_dpb_track_buffer_b.v
add_file gowin_dpb/gowin_dpb_trkbuf.v
add_file gowin_dpb/sector_dpram.v
add_file hdmi/audio_clock_regeneration_packet.sv
add_file hdmi/audio_info_frame.sv
add_file hdmi/audio_sample_packet.sv
add_file hdmi/auxiliary_video_information_info_frame.sv
add_file hdmi/hdmi.sv
add_file hdmi/packet_assembler.sv
add_file hdmi/packet_picker.sv
add_file hdmi/serializer.sv
add_file hdmi/source_product_description_info_frame.sv
add_file hdmi/tmds_channel.sv
add_file misc/flash_dspi_gw5a.v
add_file misc/hid.v
add_file misc/mcu_spi.v
add_file misc/osd_u8g2.v
add_file misc/scandoubler.v
add_file misc/sd_card.v
add_file misc/sd_rw.v
add_file misc/sdcmd_ctrl.v
add_file misc/sysctrl.v
add_file misc/video.v
add_file misc/video_analyzer.v
add_file misc/ws2812.v
add_file mos6526.v
add_file reu.v
add_file sdram.v
add_file c1541/c1541_logic.vhd
add_file c1541/c1541_sd.vhd
add_file c1541/gcr_floppy.vhd
add_file c1541/via6522.vhd
add_file c64_midi.vhd
add_file cpu_6510.vhd
add_file fpga64_buslogic_gw5a.vhd
add_file fpga64_keyboard.vhd
add_file fpga64_rgbcolor.vhd
add_file fpga64_sid_iec.vhd
add_file gowin_prom/gowin_prom_basic.vhd
add_file gowin_sdpb/gowin_sdpb_kernal_8k_gw5a.vhd
add_file gowin_prom/gowin_prom_chargen.vhd
add_file gowin_sp/gowin_sp_2k.vhd
add_file gowin_sp/gowin_sp_8k.vhd
add_file gowin_sp/gowin_sp_cram.vhd
add_file t65/T65.vhd
add_file t65/T65_ALU.vhd
add_file t65/T65_MCode.vhd
add_file t65/T65_Pack.vhd
add_file mistle/gw5a_25/c64nano.vhd
add_file video_vicII_656x.vhd
add_file mistle/gw5a_25/gowin_pll_pal.vhd
add_file mistle/gw5a_25/gowin_pll_ntsc.vhd
add_file mistle/gw5a_25/gowin_pll_pal_mod.vhd
add_file mistle/gw5a_25/gowin_pll_ntsc_mod.vhd
add_file mistle/gw5a_25/pll_init.v
add_file mistle/gw5a_25/c64nano.cst
add_file mistle/gw5a_25/c64nano.sdc
add_file loader_sd_card.sv
add_file fifo_sc_hs/FIFO_SC_HS_Top_gw5a.vhd
add_file c1530.vhd
add_file sid/sid_dac.sv
add_file sid/sid_envelope.sv
add_file sid/sid_filter.sv
add_file sid/sid_tables.sv
add_file sid/sid_top.sv
add_file sid/sid_voice.sv
add_file uart6551/BaudRate.vhd
add_file uart6551/io_fifo.v
add_file uart6551/uart_6551.v
add_file misc/c64_xml.hex

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name c64_mistle_gw5a_25
set_option -verilog_std sysv2017
set_option -vhdl_std vhd2008
set_option -top_module c64nano_top
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_cpu_as_gpio 1
set_option -use_i2c_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -rw_check_on_ram 0
set_option -user_code 00000001
#set_option -bit_compress 1
set_option -multi_boot 0
set_option -mspi_jump 0
#set_option -place_option 2
#set_option -route_option 1
set_option -ireg_in_iob 1
set_option -oreg_in_iob 1
set_option -ioreg_in_iob 1
set_option -loading_rate 70.000

run all

