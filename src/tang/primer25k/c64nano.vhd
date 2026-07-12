-------------------------------------------------------------------------
--  C64 Top level for Tang Nano Primer 25k
--  2023 / 2026 Stefan Voss
--  based on the work of many others
--
--  FPGA64 is Copyrighted 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
--  http://www.syntiac.com/fpga64.html
--
-------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity c64nano_top is
  generic
  (
   DUAL  : integer := 0; -- 0:no, 1:yes dual SID build option
   MIDI  : integer := 1; -- 0:no, 1:yes optional MIDI Interface
   U6551 : integer := 1;  -- 0:no, 1:yes optional 6551 UART
   C1541 : integer := 1  -- 0:no, 1:yes optional 6551 UART
   );
  port
  (
    bl616_jtagsel : in std_logic;
    jtagseln    : out std_logic;
    clk         : in std_logic;
    key_reset   : in std_logic; -- S2 button high active
    key_user    : in std_logic; -- S1 button high active
    leds_n      : out std_logic_vector(1 downto 0);
    io          : inout std_logic_vector(5 downto 0); -- JS0 Joystick D9
   -- external hw pin UART
    uart_ext_rx : in std_logic;
    uart_ext_tx : out std_logic;
    -- SPI interface external uC
--    pmod_companion_din : in std_logic;
--    pmod_companion_dout : out std_logic;
--    pmod_companion_ss : in std_logic;
--    pmod_companion_clk : in std_logic;
--    pmod_companion_intn : out std_logic;
    -- SPI connection to onboard BL616
    spi_sclk    : in std_logic;
    spi_csn     : in std_logic;
    spi_dir     : out std_logic;
    spi_dat     : in std_logic;
    spi_irqn    : out std_logic;
    --
    tmds_clk_n  : out std_logic;
    tmds_clk_p  : out std_logic;
    tmds_d_n    : out std_logic_vector( 2 downto 0);
    tmds_d_p    : out std_logic_vector( 2 downto 0);
    -- sd interface
    sd_clk      : out std_logic;
    sd_cmd      : inout std_logic;
    sd_dat      : inout std_logic_vector(3 downto 0);
    -- MiSTer SDRAM module
    O_sdram_clk     : out std_logic;
    O_sdram_cs_n    : out std_logic; -- chip select
    O_sdram_cas_n   : out std_logic;
    O_sdram_ras_n   : out std_logic; -- row address select
    O_sdram_wen_n   : out std_logic; -- write enable
    IO_sdram_dq     : inout std_logic_vector(15 downto 0); -- 16 bit bidirectional data bus
    O_sdram_addr    : out std_logic_vector(12 downto 0); -- 13 bit multiplexed address bus
    O_sdram_ba      : out std_logic_vector(1 downto 0); -- two banks
    O_sdram_dqm     : out std_logic_vector(1 downto 0); -- 16/2
    -- spi flash interface
    mspi_cs       : out std_logic;
    mspi_clk      : out std_logic;
    mspi_di       : inout std_logic;
    mspi_hold     : inout std_logic;
    mspi_wp       : inout std_logic;
    mspi_do       : inout std_logic
    );
end;

architecture Behavioral_top of c64nano_top is

signal spare               : std_logic_vector(5 downto 0) := (others => '1'); -- JS1 Joystick D9
signal midi_rx             : std_logic;
signal midi_tx             : std_logic;

type unsigned_array_9b is array (natural range <>) of unsigned(8 downto 0);
type u7_array_t is array (natural range <>) of unsigned(6 downto 0);
signal dac            : unsigned_array_9b(3 downto 0) := (others => (others => '0'));
signal clk64          : std_logic;
signal clk_sys        : std_logic;
signal pll_locked     : std_logic;
signal clk_pixel_x5   : std_logic;
signal clk64_ntsc     : std_logic;
signal pll_locked_ntsc: std_logic;
signal clk_pixel_x5_ntsc  : std_logic;
signal clk64_pal      : std_logic;
signal pll_locked_pal : std_logic;
signal clk_pixel_x5_pal: std_logic;
signal spi_io_clk     : std_logic;
attribute syn_keep : integer;
attribute syn_keep of clk64             : signal is 1;
attribute syn_keep of clk_sys           : signal is 1;
attribute syn_keep of clk_pixel_x5      : signal is 1;
attribute syn_keep of clk64_pal         : signal is 1;
attribute syn_keep of clk64_ntsc        : signal is 1;
attribute syn_keep of clk_pixel_x5_pal  : signal is 1;
attribute syn_keep of clk_pixel_x5_ntsc : signal is 1;
attribute syn_keep of spi_io_clk        : signal is 1;

signal audio_data_l  : std_logic_vector(17 downto 0);
signal audio_data_r  : std_logic_vector(17 downto 0);
-- external memory
signal c64_addr     : unsigned(15 downto 0);
signal c64_data_out : unsigned(7 downto 0);
signal sdram_data   : unsigned(7 downto 0);
signal idle         : std_logic;
signal ram_ready    : std_logic;
signal addr         : unsigned(24 downto 0);
signal cs           : std_logic;
signal we           : std_logic;
signal din          : unsigned(7 downto 0);
signal ds           : std_logic_vector(1 downto 0);
-- IEC
signal c64_iec_clk      : std_logic;
signal c64_iec_data     : std_logic;
signal c64_iec_atn      : std_logic;
signal ext_iec_en       : std_logic_vector(1 downto 0);
signal ext_iec_clk      : std_logic;
signal ext_iec_data     : std_logic;
signal drive_iec_clk    : std_logic;
signal drive_iec_data   : std_logic;
signal drive_iec_clk_o  : std_logic;
signal drive_iec_data_o : std_logic;
signal int_iec_drv      : std_logic_vector(1 downto 0);
  -- keyboard
signal joyUsb1      : std_logic_vector(6 downto 0);
signal joyUsb2      : std_logic_vector(6 downto 0);
signal joyUsb1A     : std_logic_vector(6 downto 0);
signal joyUsb2A     : std_logic_vector(6 downto 0);
signal joyDigital0  : std_logic_vector(6 downto 0);
signal joyDigital1  : std_logic_vector(6 downto 0);
signal joyNumpad    : std_logic_vector(6 downto 0);
signal joyMouse     : std_logic_vector(6 downto 0);
signal numpad       : std_logic_vector(7 downto 0);
signal numpad_d     : std_logic_vector(7 downto 0);
-- joystick interface
signal joyA        : std_logic_vector(6 downto 0);
signal joyB        : std_logic_vector(6 downto 0);
signal joyA_c64    : std_logic_vector(6 downto 0);
signal joyB_c64    : std_logic_vector(6 downto 0);
signal port_1_sel  : std_logic_vector(3 downto 0);
signal port_2_sel  : std_logic_vector(3 downto 0);
-- mouse / paddle
signal pot1        : std_logic_vector(7 downto 0);
signal pot2        : std_logic_vector(7 downto 0);
signal pot3        : std_logic_vector(7 downto 0);
signal pot4        : std_logic_vector(7 downto 0);
signal mouse_x_pos : signed(10 downto 0);
signal mouse_y_pos : signed(10 downto 0);

signal ram_ce      :  std_logic;
signal ram_we      :  std_logic;

signal ntscMode    :  std_logic;
signal hsync       :  std_logic;
signal vsync       :  std_logic;
signal r           :  unsigned(7 downto 0);
signal g           :  unsigned(7 downto 0);
signal b           :  unsigned(7 downto 0);
-- user port
signal pb_o        : std_logic_vector(7 downto 0);
signal pc2_n_o     : std_logic;
signal pb_i        : std_logic_vector(7 downto 0);
signal flag2_n_i   : std_logic;
signal pa2_i       : std_logic;
signal pa2_o       : std_logic;
signal drive_par_i : std_logic_vector(7 downto 0);
signal drive_par_o : std_logic_vector(7 downto 0);
signal drive_stb_i : std_logic;
signal drive_stb_o : std_logic;
-- BL616 interfaces
signal mcu_start      : std_logic;
signal mcu_sys_strobe : std_logic;
signal mcu_hid_strobe : std_logic;
signal mcu_osd_strobe : std_logic;
signal mcu_sdc_strobe : std_logic;
signal data_in_start  : std_logic;
signal mcu_data_out   : std_logic_vector(7 downto 0);
signal hid_data_out   : std_logic_vector(7 downto 0);
signal osd_data_out   : std_logic_vector(7 downto 0) :=  X"55";
signal sys_data_out   : std_logic_vector(7 downto 0);
signal sdc_data_out   : std_logic_vector(7 downto 0);
signal hid_int        : std_logic;
signal system_scanlines : std_logic_vector(1 downto 0);
signal system_volume  : std_logic_vector(1 downto 0);
signal joystick1      : std_logic_vector(7 downto 0);
signal joystick2      : std_logic_vector(7 downto 0);
signal mouse_btns     : std_logic_vector(1 downto 0);
signal mouse_x        : signed(7 downto 0);
signal mouse_y        : signed(7 downto 0);
signal mouse_strobe   : std_logic;
signal c64_pause      : std_logic;
signal osd_status     : std_logic;
signal ws2812_color   : std_logic_vector(23 downto 0);
signal system_reset   : std_logic_vector(1 downto 0);
signal disk_reset     : std_logic;
signal disk_chg_trg   : std_logic;
signal disk_chg_trg_d : std_logic;
signal sd_img_size    : std_logic_vector(31 downto 0);
signal sd_img_size_d  : std_logic_vector(31 downto 0);
signal sd_img_mounted : std_logic_vector(7 downto 0);
signal sd_img_mounted_d : std_logic;
signal sd_rd          : std_logic_vector(7 downto 0);
signal sd_wr          : std_logic_vector(7 downto 0);
signal disk_lba       : unsigned(31 downto 0);
signal sd_lba         : unsigned(31 downto 0);
signal loader_lba     : unsigned(31 downto 0);
signal sd_busy        : std_logic;
signal sd_done        : std_logic;
signal sd_rd_byte_strobe : std_logic;
signal sd_byte_index  : std_logic_vector(8 downto 0);
signal sd_rd_data     : unsigned(7 downto 0);
signal sd_wr_data     : unsigned(7 downto 0);
signal sd_change      : std_logic;
signal sdc_int        : std_logic;
signal sdc_iack       : std_logic;
signal int_ack        : std_logic_vector(7 downto 0);
signal spi_io_din     : std_logic;
signal spi_io_ss      : std_logic;
signal spi_io_dout    : std_logic;
signal spi_ext        : std_logic;
signal disk_g64       : std_logic;
signal disk_g64_d     : std_logic;
signal c1541_reset    : std_logic;
signal c1541_osd_reset : std_logic;
signal system_screen  : std_logic_vector(1 downto 0);
signal system_floppy_wprot : std_logic_vector(1 downto 0);
signal leds           : std_logic_vector(5 downto 0);
signal led1541        : std_logic;
signal reu_cfg        : std_logic_vector(1 downto 0); 
signal dma_req        : std_logic;
signal dma_cycle      : std_logic;
signal dma_addr       : unsigned(15 downto 0);
signal dma_dout       : unsigned(7 downto 0);
signal dma_din        : unsigned(7 downto 0);
signal dma_we         : std_logic;
signal ext_cycle      : std_logic;
signal ext_cycle_d    : std_logic;
signal reu_ram_addr   : unsigned(24 downto 0);
signal reu_ram_dout   : unsigned(7 downto 0);
signal reu_ram_we     : std_logic;
signal reu_irq        : std_logic;
signal IO7            : std_logic;
signal IOE            : std_logic;
signal IOF            : std_logic;
signal reu_dout       : std_logic_vector(7 downto 0);
signal reu_oe         : std_logic;
signal reu_ram_ce     : std_logic;
signal cart_ce        : std_logic;
signal cart_we        : std_logic;
signal cart_data      : unsigned(7 downto 0);
signal cart_addr      : unsigned(24 downto 0);
signal exrom          : std_logic;
signal game           : std_logic;
signal romL           : std_logic;
signal romH           : std_logic;
signal UMAXromH       : std_logic;
signal io_rom         : std_logic;
signal cart_oe        : std_logic;
signal io_data        : unsigned(7 downto 0);
signal db9_joy        : std_logic_vector(5 downto 0);
signal turbo_mode     : std_logic_vector(1 downto 0);
signal turbo_speed    : std_logic_vector(1 downto 0);
signal dos_sel        : std_logic_vector(1 downto 0);
signal c1541rom_cs    : std_logic;
signal c1541rom_addr  : std_logic_vector(14 downto 0);
signal c1541rom_data  : std_logic_vector(7 downto 0);
signal ext_en         : std_logic;
signal nmi            : std_logic;
signal nmi_ack        : std_logic;
signal freeze_key     : std_logic;
signal disk_access    : std_logic;
signal c64_iec_clk_old : std_logic;
signal drive_iec_clk_old : std_logic;
signal drive_stb_i_old : std_logic;
signal drive_stb_o_old : std_logic;
signal midi_data       : std_logic_vector(7 downto 0) := (others =>'0');
signal midi_oe         : std_logic;
signal midi_en         : std_logic;
signal midi_irq_n      : std_logic := '1';
signal midi_nmi_n      : std_logic := '1';
signal st_midi         : std_logic_vector(2 downto 0);
signal phi             : std_logic;
signal system_pause    : std_logic;
signal audio_div       : unsigned(8 downto 0);
signal dcsclksel       : std_logic_vector(3 downto 0);
signal ioctl_download  : std_logic := '0';
signal ioctl_load_addr : unsigned(24 downto 0);
signal ioctl_req_wr    : std_logic := '0';
signal cart_id         : unsigned(7 downto 0);
signal cart_bank_num   : unsigned(7 downto 0);
signal cart_exrom      : std_logic;
signal cart_game       : std_logic;
signal cart_attached   : std_logic := '0';
signal cart_hdr_cnt    : unsigned(3 downto 0);
signal cart_hdr_wr     : std_logic;
signal cart_blk_len    : unsigned(15 downto 0);
signal io_cycle        : std_logic;
signal io_cycle_ce     : std_logic;
signal io_cycle_we     : std_logic;
signal io_cycle_addr   : unsigned(24 downto 0);
signal io_cycle_data   : unsigned(7 downto 0);
signal load_crt        : std_logic := '0';
signal old_download    : std_logic := '0';
signal io_cycleD       : std_logic;
signal ioctl_wr        : std_logic;
signal ioctl_data      : unsigned(7 downto 0);
signal ioctl_addr      : unsigned(24 downto 0);
signal cid             : unsigned(7 downto 0);
-- crt loader
signal erase_to        : unsigned(4 downto 0);
signal erase_cram      : std_logic := '0';
signal old_meminit     : std_logic;
signal inj_end         : unsigned(15 downto 0);
signal inj_meminit_data: unsigned(7 downto 0);
signal force_erase     : std_logic := '0';
signal erasing         : std_logic := '0';
signal do_erase        : std_logic := '1';
signal inj_meminit     : std_logic := '0';
signal load_prg        : std_logic := '0';
signal load_rom        : std_logic := '0';
signal load_reu        : std_logic := '0';
signal load_tap        : std_logic := '0';
signal tap_play_addr   : unsigned(24 downto 0);
signal reset_wait      : std_logic := '0';
signal old_download_r  : std_logic;
signal old_upload      : std_logic := '0';
signal reset_n         : std_logic;
signal por             : std_logic;
signal c64rom_wr       : std_logic;
signal tap_version     : std_logic_vector(1 downto 0);
signal vic_variant     : std_logic_vector(1 downto 0);
signal cia_mode        : std_logic;
signal loader_busy     : std_logic;
-- tape
signal cass_write     : std_logic;
signal cass_motor     : std_logic;
signal cass_sense     : std_logic;
signal cass_read      : std_logic;
signal cass_run       : std_logic;
signal cass_finish    : std_logic;
signal cass_snd       : std_logic;
signal tap_download   : std_logic;
signal tap_reset      : std_logic;
signal tap_loaded     : std_logic;
signal tap_last_addr  : unsigned(24 downto 0);
signal tap_wrreq      : std_logic_vector(1 downto 0);
signal tap_wrfull     : std_logic;
signal tap_start      : std_logic;
signal read_cyc       : std_logic := '0';
signal io_cycle_rD    : std_logic;
signal load_flt       : std_logic := '0';
signal sid_ver        : std_logic;
signal sid_mode       : unsigned(2 downto 0);
signal sid_digifix    : std_logic;
signal system_tape_sound : std_logic;
signal uart_rxD         : std_logic_vector(3 downto 0);
signal uart_rx_filtered : std_logic;
signal cnt2_i          : std_logic;
signal cnt2_o          : std_logic;
signal sp2_i           : std_logic;
signal sp1_o           : std_logic;
signal system_up9600   : unsigned(2 downto 0);
signal sid_fc_offset   : std_logic_vector(2 downto 0);
signal sid_fc_lr       : std_logic_vector(12 downto 0);
signal sid_filter      : std_logic_vector(2 downto 0);
signal georam          : std_logic;
signal uart_data       : unsigned(7 downto 0) := (others =>'0');
signal uart_oe         : std_logic := '0';
signal uart_en         : std_logic := '0';
signal tx_6551         : std_logic := '1';
signal uart_irq        : std_logic := '1'; -- low active
signal uart_cs         : std_logic;
signal CLK_6551_EN     : std_logic;
signal phi2_n          : std_logic;
signal sid_ld_addr     : std_logic_vector(11 downto 0) := (others =>'0');
signal sid_ld_data     : std_logic_vector(15 downto 0) := (others =>'0');
signal sid_ld_wr       : std_logic := '0';
signal img_present     : std_logic := '0';
signal c1541_sd_rd     : std_logic;
signal c1541_sd_wr     : std_logic;
signal joystick0ax     : signed(7 downto 0);
signal joystick0ay     : signed(7 downto 0);
signal joystick1ax     : signed(7 downto 0);
signal joystick1ay     : signed(7 downto 0);
signal joystick_strobe : std_logic;
signal joystick1_x_pos : std_logic_vector(7 downto 0);
signal joystick1_y_pos : std_logic_vector(7 downto 0);
signal joystick2_x_pos : std_logic_vector(7 downto 0);
signal joystick2_y_pos : std_logic_vector(7 downto 0);
signal extra_button1   : std_logic_vector(7 downto 0);
signal extra_button2   : std_logic_vector(7 downto 0);
signal system_uart     : std_logic_vector(1 downto 0);
signal uart_rx_muxed   : std_logic;
signal joyswap         : std_logic;
signal system_joyswap  : std_logic;
signal pd1,pd2,pd3,pd4 : std_logic_vector(7 downto 0);
signal detach_reset_d  : std_logic;
signal detach_reset    : std_logic;
signal disk_pause      : std_logic;
signal flash_ready      : std_logic;
signal rts_cts          : std_logic;
signal dtr              : std_logic;
signal serial_status    : std_logic_vector(31 downto 0);
signal serial_tx_available : std_logic_vector(7 downto 0);
signal serial_tx_strobe : std_logic;
signal serial_tx_data   : std_logic_vector(7 downto 0);
signal serial_rx_available : std_logic_vector(7 downto 0);
signal serial_rx_strobe : std_logic;
signal serial_rx_data   : std_logic_vector(7 downto 0);
signal shift_mod        : std_logic_vector(1 downto 0);
signal usb_key          : std_logic_vector(7 downto 0);
signal mod_key          : std_logic;
signal kbd_strobe       : std_logic;
signal spi_intn         : std_logic;
signal uart_tx_i        : std_logic;
signal boot_button_detected : std_logic := '1';
signal palette          : unsigned(2 downto 0);
signal reu_wrap         : std_logic;
signal c64_data_in      : unsigned(7 downto 0);
signal cart_mem_req     : std_logic;
signal cart_wrdata      : unsigned(7 downto 0);
signal cart_lobanks     : u7_array_t(0 to 63);
signal cart_hibanks     : u7_array_t(0 to 63);
signal cart_bank_cnt    : unsigned(7 downto 0);
signal cart_lobanks_map : unsigned(63 downto 0);
signal cart_hibanks_map : unsigned(63 downto 0);
signal cart_bank_hi     : std_logic;
signal cart_bank_16k    : std_logic;
signal rd_cyc           : unsigned(2 downto 0);
signal ioctl_rd_en      : std_logic := '0';
signal cart_id_hi       : unsigned(7 downto 0);
signal ioctl_req_rd     : std_logic := '0';
signal ioctl_rd         : std_logic := '0';
signal ioctl_din        : unsigned(7 downto 0);
signal start_strk       : std_logic :='0';
signal key              : std_logic_vector(7 downto 0) := (others => '0');
signal key_strobe       : std_logic := '0';
signal act              : unsigned(3 downto 0) := (others => '0');
signal to_cnt           : integer range 0 to 2_000_000 := 0;
signal run_prg          : std_logic;
signal reset_counter    : integer range 0 to 100000 := 0;
signal clear_ram        : std_logic;
signal boot_easyflash   : std_logic;
signal ezfl_save        : std_logic := '0';
signal ezfl_save_old    : std_logic := '0';
signal ezfl_mod         : std_logic := '0';
signal save_cartridge   : std_logic := '0';
signal autosave         : std_logic := '0';
signal ezfl_idx         : std_logic := '0';
signal ioctl_upload     : std_logic := '0';
signal disk_sd_wr_data  : unsigned(7 downto 0);
signal loader_sd_wr_data: unsigned(7 downto 0);
signal ext_old          : std_logic := '0';
signal ext_crt          : std_logic := '0';
signal ezfl_save_en     : std_logic := '0';
attribute syn_preserve  : integer;
attribute syn_preserve of boot_button_detected : signal is 1;
signal tap_io_cycle     : std_logic := '0';
signal dac_l, dac_r     : unsigned(8 downto 0);
signal alo, aro         : signed(15 downto 0);
signal sact             : unsigned(3 downto 0);
signal system_digimax   : unsigned(1 downto 0);
signal ioe_we, iof_we   : std_logic;
signal old_ioe, old_iof : std_logic;

constant RAM_ADDR      : unsigned(24 downto 0) := 25x"0000000";-- System RAM: 64k
constant CRM_ADDR      : unsigned(24 downto 0) := 25x"0010000";-- Cartridge RAM: 64k
constant CRT_ADDR      : unsigned(24 downto 0) := 25x"0200000";-- Cartridge: 2M
constant TAP_ADDR      : unsigned(24 downto 0) := 25x"0400000";-- Tape buffer
constant GEO_ADDR      : unsigned(24 downto 0) := 25x"0C00000";-- GeoRAM: 4M
constant REU_ADDR      : unsigned(24 downto 0) := 25x"1000000";-- REU: 16M

component CLKDIV
    generic (
        DIV_MODE : STRING := "2"
    );
    port (
        CLKOUT: out std_logic;
        HCLKIN: in std_logic;
        RESETN: in std_logic;
        CALIB: in std_logic
    );
end component;

component DCS
    generic (
        DCS_MODE : STRING := "RISING"
    );
    port (
        CLKOUT: out std_logic;
        CLKSEL: in std_logic_vector(3 downto 0);
        CLKIN0: in std_logic;
        CLKIN1: in std_logic;
        CLKIN2: in std_logic;
        CLKIN3: in std_logic;
        SELFORCE: in std_logic
    );
end component;

begin

  process (pll_locked_pal)
  begin
    if rising_edge(pll_locked_pal) then
      boot_button_detected <= '1' when key_user = '1' or key_reset = '1' else '0';
    end if;
  end process;

-- enable JTAG if any button has been pressed during boot and also once
-- the external FPGA Companion has been seen
  jtagseln <= '1' when (not pll_locked_pal or boot_button_detected or spi_ext or bl616_jtagsel) = '0' else '0';

  spi_io_din <= spi_dat;
  spi_io_ss <= spi_csn;
  spi_io_clk <= spi_sclk;
  spi_dir <= spi_io_dout;
  spi_irqn <=  spi_intn;

  midi_rx <= uart_ext_rx;
  uart_ext_tx <= midi_tx when midi_en = '1' else uart_tx_i;

  ext_iec_clk  <= '1' when ext_iec_en = "00" else  -- USER_IN[2]
                    io(0) when ext_iec_en = "01" else
                    spare(0) when ext_iec_en = "10" else
                    '0';

  ext_iec_data <= '1' when ext_iec_en = "00" else  -- USER_IN[4]
                    io(1) when ext_iec_en = "01" else
                    spare(1) when ext_iec_en = "10" else
                    '0';

-- Joystick 2 / Spare
  spare(0) <= 'Z' when ((c64_iec_clk = '1' and drive_iec_clk_o = '1') or (ext_iec_en = "00") or (ext_iec_en = "01"))
              else '0'; -- USER_OUT[2]

  spare(2) <= 'Z' when ((reset_n = '1' and c1541_osd_reset = '0') or (ext_iec_en = "00") or (ext_iec_en = "01"))
              else '0'; -- USER_OUT[3] 

  spare(1) <= 'Z' when ((c64_iec_data = '1' and drive_iec_data_o = '1') or (ext_iec_en = "00") or (ext_iec_en = "01"))
              else '0'; -- USER_OUT[4]

  spare(3) <= 'Z' when (c64_iec_atn = '1') or (ext_iec_en = "00" or (ext_iec_en = "01")) 
              else '0';-- USER_OUT[5]

  spare(5 downto 4) <= "ZZ";

-- Joystick 1
  io(0) <= 'Z' when ((c64_iec_clk = '1' and drive_iec_clk_o = '1') or (ext_iec_en = "00") or (ext_iec_en = "10"))
              else '0'; -- USER_OUT[2]

  io(2) <= 'Z' when ((reset_n = '1' and c1541_osd_reset = '0') or (ext_iec_en = "00") or (ext_iec_en = "10"))
              else '0'; -- USER_OUT[3] 

  io(1) <= 'Z' when ((c64_iec_data = '1' and drive_iec_data_o = '1') or (ext_iec_en = "00") or (ext_iec_en = "10"))
              else '0'; -- USER_OUT[4]

  io(3) <= 'Z' when (c64_iec_atn = '1') or (ext_iec_en = "00" or (ext_iec_en = "10"))
              else '0';-- USER_OUT[5]

  io(5 downto 4) <= "ZZ";

  drive_iec_clk  <= drive_iec_clk_o  and ext_iec_clk;
  drive_iec_data <= drive_iec_data_o and ext_iec_data;

--  led_ws2812: entity work.ws2812
--  port map
--  (
--    clk    => clk_sys,
--    color  => ws2812_color,
--    data   => ws2812
--  );

process(clk_sys)
variable reset_cnt : integer range 0 to 2147483647;
  begin
  if rising_edge(clk_sys) then
    if disk_reset = '1' then
      disk_chg_trg <= '0';
      reset_cnt := 64000000;
    elsif reset_cnt /= 0 then
      reset_cnt := reset_cnt - 1;
    elsif reset_cnt = 0 then
      disk_chg_trg <= '1';
    end if;
  end if;
end process;

-- delay disk start to keep loader at power-up intact
process(clk_sys, por)
  variable pause_cnt : integer range 0 to 2147483647;
  begin
  if por = '1' then
    disk_pause <= '1';
    pause_cnt := 34000000;
  elsif rising_edge(clk_sys) then
    if pause_cnt /= 0 then
      pause_cnt := pause_cnt - 1;
    elsif pause_cnt = 0 then 
      disk_pause <= '0';
    end if;
  end if;
end process;

disk_reset <= '1' when not flash_ready or disk_pause or c1541_osd_reset or not reset_n or por or c1541_reset else '0';

-- rising edge sd_change triggers detection of new disk
process(clk_sys, pll_locked)
  begin
  if pll_locked = '0' then
    sd_change <= '0';
    disk_g64 <= '0';
    sd_img_size_d <= (others => '0');
    disk_chg_trg_d <= '0';
    img_present <= '0';
  elsif rising_edge(clk_sys) then
      sd_img_mounted_d <= sd_img_mounted(0);
      disk_chg_trg_d <= disk_chg_trg;
      disk_g64_d <= disk_g64;

      if sd_img_mounted(0) = '1' then
        img_present <= '0' when sd_img_size = x"00000000" else '1';
      end if;

      if sd_img_mounted_d = '0' and sd_img_mounted(0) = '1' then
        sd_img_size_d <= sd_img_size;
      end if;

      if (sd_img_mounted(0) /= sd_img_mounted_d) or
         (disk_chg_trg_d = '0' and disk_chg_trg = '1') then
          sd_change  <= '1';
          else
          sd_change  <= '0';
      end if;

      if unsigned(sd_img_size_d) >= to_unsigned(333744, sd_img_size_d'length) then  -- g64 disk selected
        disk_g64 <= '1';
      else
        disk_g64 <= '0';
      end if;

      if (disk_g64 /= disk_g64_d) then
        c1541_reset  <= '1'; -- reset needed after G64 change
      else
        c1541_reset  <= '0';
      end if;
  end if;
end process;

yes_c1541: if C1541 /= 0 generate
  c1541_sd_inst : entity work.c1541_sd
  port map
  (
      clk32         => clk_sys,
      reset         => disk_reset,
      pause         => loader_busy,
      ce            => '0',
      ds            => int_iec_drv,

      disk_num      => (others =>'0'),
      disk_change   => sd_change, 
      disk_mount    => img_present,
      disk_readonly => system_floppy_wprot(0),
      disk_g64      => disk_g64,

      iec_atn_i     => c64_iec_atn,
      iec_data_i    => c64_iec_data and ext_iec_data,
      iec_clk_i     => c64_iec_clk and ext_iec_clk,

      iec_data_o    => drive_iec_data_o,
      iec_clk_o     => drive_iec_clk_o,

      -- Userport parallel bus to 1541 disk
      par_data_i    => drive_par_i,
      par_stb_i     => drive_stb_i,
      par_data_o    => drive_par_o,
      par_stb_o     => drive_stb_o,

      unsigned(sd_lba) => disk_lba,
      sd_rd         => c1541_sd_rd,
      sd_wr         => c1541_sd_wr,
      sd_ack        => sd_busy,
      sd_done       => sd_done,

      sd_buff_addr  => sd_byte_index,
      sd_buff_dout  => std_logic_vector(sd_rd_data),
      unsigned(sd_buff_din) => disk_sd_wr_data,
      sd_buff_wr    => sd_rd_byte_strobe,

      led           => led1541,
      ext_en        => ext_en,
      c1541rom_cs   => c1541rom_cs,
      c1541rom_addr => c1541rom_addr,
      c1541rom_data => c1541rom_data
  );
  sd_lba <= loader_lba when loader_busy = '1' else disk_lba;
  sd_wr_data <= loader_sd_wr_data when loader_busy = '1' else disk_sd_wr_data;
  sd_rd(0) <= '0' when loader_busy = '1' else c1541_sd_rd;
  sd_wr(0) <= '0' when loader_busy = '1' else c1541_sd_wr;
  ext_en <= '1' when dos_sel(0) = '0' else '0'; -- dolphindos, speeddos
else generate
  sd_lba <= loader_lba;
  sd_wr_data <= loader_sd_wr_data;
  sd_rd(0) <= '0';
  sd_wr(0) <= '0';
  drive_par_o <= (others => '1');
  drive_stb_o <= '1';
  disk_sd_wr_data <= (others => '0'); 
	drive_iec_data_o <= '1';
	drive_iec_clk_o <= '1';
  ext_en <= '0';
end generate yes_c1541;

sdc_iack <= int_ack(3);

sd_card_inst: entity work.sd_card
generic map (
    CLK_DIV  => 0,
    SIMULATE => 0,
    IMAGE_FIFO_BITS => 9
  )
    port map (
    rstn            => pll_locked,
    clk             => clk_sys,
  
    -- SD card signals
    sdclk           => sd_clk,
    sdcmd           => sd_cmd,
    sddat           => sd_dat,

    -- mcu interface
    data_strobe     => mcu_sdc_strobe,
    data_start      => mcu_start,
    data_in         => mcu_data_out,
    data_out        => sdc_data_out,

    -- interrupt to signal communication request
    irq             => sdc_int,
    iack            => sdc_iack,

    -- output file/image information. Image size is e.g. used by fdc to 
    -- translate between sector/track/side and lba sector
    image_size(31 downto 0) => sd_img_size,           -- length of image file
    image_mounted => sd_img_mounted,

    rom_image_selection_strobe => open,
    rom_image_selected => open,
    rom_image_accepted => '0',
    rom_image_data_available => open,
    rom_image_data => open,
    rom_image_data_strobe => '0',

    -- user read sector command interface (sync with clk)
    rstart          => sd_rd,
    wstart          => sd_wr, 
    rsector         => sd_lba,
    rsrc            => open, -- source currently being process and for which 

    rbusy           => sd_busy,
    rdone           => sd_done,           --  done from sd reader acknowledges/clears start

    -- sector data output interface (sync with clk)
    inbyte          => sd_wr_data,        -- sector data output interface (sync with clk)
    outen           => sd_rd_byte_strobe, -- when outen=1, a byte of sector content is read out from outbyte
    outaddr         => sd_byte_index,     -- outaddr from 0 to 511, because the sector size is 512
    outbyte         => sd_rd_data         -- a byte of sector content
);

audio_div  <= to_unsigned(342,9) when ntscMode = '1' else to_unsigned(327,9);

cass_snd <= cass_read and not cass_run and  system_tape_sound   and not cass_finish;

process(clk_sys)
begin
    if rising_edge(clk_sys) then
        old_ioe <= IOE;
        ioe_we <= (not old_ioe) and IOE and ram_we;

        old_iof <= IOF;
        iof_we <= (not old_iof) and IOF and ram_we;
    end if;
end process;

process(clk_sys)
    variable dac_index : integer range 0 to 3;
    variable alm, arm : signed(16 downto 0);
begin
    if rising_edge(clk_sys) then
        if system_digimax = "00" or reset_n = '0' then
            dac <= (others => (others => '0'));
            sact <= (others => '0');
        elsif ((system_digimax(1) = '1' and iof_we = '1') or 
               (system_digimax(1) = '0' and ioe_we = '1')) and c64_addr(2) = '0' then
            dac_index := to_integer(unsigned(c64_addr(1 downto 0)));
            dac(dac_index) <= resize(unsigned(c64_data_out), 9);
            if unsigned(c64_data_out) /= 0 then
                sact(to_integer(unsigned(c64_addr(1 downto 0)))) <= '1';
            end if;
        end if;

        -- Guess mono/stereo/4-channel modes
        if unsigned(act) < 2 then
            dac_l <= unsigned(dac(0)) + unsigned(dac(0));
            dac_r <= unsigned(dac(0)) + unsigned(dac(0));
        elsif unsigned(sact) < 3 then
            dac_l <= unsigned(dac(1)) + unsigned(dac(1));
            dac_r <= unsigned(dac(0)) + unsigned(dac(0));
        else
            dac_l <= unsigned(dac(1)) + unsigned(dac(2));
            dac_r <= unsigned(dac(0)) + unsigned(dac(3));
        end if;

        alm := signed(audio_data_l(17) & std_logic_vector(audio_data_l(17 downto 2))) 
               + signed(std_logic_vector'("00") & std_logic_vector(dac_l) & std_logic_vector'("000000")) 
               + signed((0 => cass_snd) & std_logic_vector'("000000000"));

        arm := signed(audio_data_r(17) & std_logic_vector(audio_data_r(17 downto 2))) 
               + signed(std_logic_vector'("00") & std_logic_vector(dac_r) & std_logic_vector'("000000")) 
               + signed((0 => cass_snd) & std_logic_vector'("000000000"));
        
        if (alm(16) xor alm(15)) = '1' then
            alo <= alm(16) & (alm(15) & alm(15) & alm(15) & alm(15) & alm(15) & alm(15) 
                              & alm(15) & alm(15) & alm(15) & alm(15) & alm(15) & alm(15) 
                              & alm(15) & alm(15) & alm(15));
        else
            alo <= alm(15 downto 0);
        end if;

        if (arm(16) xor arm(15)) = '1' then
            aro <= arm(16) & (arm(15) & arm(15) & arm(15) & arm(15) & arm(15) & arm(15) 
                              & arm(15) & arm(15) & arm(15) & arm(15) & arm(15) & arm(15) 
                              & arm(15) & arm(15) & arm(15));
        else
            aro <= arm(15 downto 0);
        end if;
    end if;
end process;

video_inst: entity work.video 
port map(
      pll_lock     => pll_locked, 
      clk          => clk_sys,
      clk_pixel_x5 => clk_pixel_x5,
      audio_div    => audio_div,

      ntscmode  => ntscMode,
      hs_in_n   => hsync,
      vs_in_n   => vsync,
      de_in     => '1',

      r_in      => r(7 downto 4),
      g_in      => g(7 downto 4),
      b_in      => b(7 downto 4),

      audio_l => alo,
      audio_r => aro,
      osd_status => osd_status,

      mcu_start => mcu_start,
      mcu_osd_strobe => mcu_osd_strobe,
      mcu_data  => mcu_data_out,

      -- values that can be configure by the user via osd
      system_screen => system_screen,
      system_scanlines => system_scanlines,
      system_volume => system_volume,

      tmds_clk_n => tmds_clk_n,
      tmds_clk_p => tmds_clk_p,
      tmds_d_n   => tmds_d_n,
      tmds_d_p   => tmds_d_p
      );

addr <= cart_addr
           when io_cycle = '1' and cart_mem_req = '1' else
        io_cycle_addr
           when io_cycle = '1' else
        reu_ram_addr
           when ext_cycle = '1' else
        cart_addr;

cs <= cart_ce
         when io_cycle = '1' and cart_mem_req = '1' else
      io_cycle_ce
         when io_cycle = '1' else
      reu_ram_ce
         when ext_cycle = '1' else
      cart_ce;

we <= cart_we
         when io_cycle = '1' and cart_mem_req = '1' else
      io_cycle_we
         when io_cycle = '1' else
      reu_ram_we
         when ext_cycle = '1' else
      cart_we;

din <= cart_wrdata
           when io_cycle = '1' and cart_mem_req = '1' else
       io_cycle_data
           when io_cycle = '1' else
       reu_ram_dout
           when ext_cycle = '1' else
       cart_wrdata;

dram_inst: entity work.sdram
port map(
    -- SDRAM side interface
    sd_clk    => O_sdram_clk,   -- sd clock
    sd_data   => IO_sdram_dq,   -- 32 bit bidirectional data bus
    sd_addr   => O_sdram_addr,  -- 11 bit multiplexed address bus
    sd_dqm    => O_sdram_dqm,   -- two byte masks
    sd_ba     => O_sdram_ba,    -- two banks
    sd_cs     => O_sdram_cs_n,  -- a single chip select
    sd_we     => O_sdram_wen_n, -- write enable
    sd_ras    => O_sdram_ras_n, -- row address select
    sd_cas    => O_sdram_cas_n, -- columns address select
    -- cpu/chipset interface
    clk       => clk64,         -- sdram is accessed at 64MHz
    init      => not pll_locked,-- init signal after FPGA config to initialize RAM
    refresh   => idle,          -- chipset requests a refresh cycle
    din       => din,           -- data input from chipset/cpu
    dout      => sdram_data,
    addr      => addr,          -- 25 bit word address
    ce        => cs,            -- cpu/chipset requests read/wrie
    we        => we             -- cpu/chipset requests write
  );

ram_ready <= '1';

-- Clock tree and all frequencies in Hz
-- TN 20k
-- pal                   / ntsc
-- pll         315000000 / 329400000
-- serdes      157500000 / 164700000
-- dram         63000000 /  65880000
-- core /pixel  31500000 /  32940000

-- TP 25k
-- pal                   / ntsc
-- pll         315000000 / 325000000
-- serdes      157500000 / 162500000
-- dram         63000000 /  65000000
-- core /pixel  31500000 /  32500000

clk_switch_2: DCS
	generic map (
		DCS_MODE => "RISING"
	)
	port map (
		CLKIN0   => clk64_pal,  -- main pll 1
		CLKIN1   => clk64_ntsc, -- main pll 2
		CLKIN2   => '0',
		CLKIN3   => '0',
		CLKSEL   => dcsclksel,
		SELFORCE => '0', -- glitch less mode
		CLKOUT   => clk64 -- switched clock
	);
  
pll_locked <= pll_locked_pal and pll_locked_ntsc;
dcsclksel <= "0001" when ntscMode = '0' else "0010";

clk_switch_1: DCS
generic map (
    DCS_MODE => "RISING"
)
port map (

    CLKIN0 => clk_pixel_x5_pal,
    CLKIN1 => clk_pixel_x5_ntsc,
    CLKIN2 => '0',
    CLKIN3 => '0',
    SELFORCE => '1',
    CLKOUT => clk_pixel_x5,
    CLKSEL => dcsclksel
);

div_inst: CLKDIV
generic map(
  DIV_MODE => "2"
)
port map(
    CLKOUT => clk_sys,
    HCLKIN => clk64,
    RESETN => pll_locked,
    CALIB  => '0'
);

mainclock_pal: entity work.Gowin_PLL_pal
port map (
    clkin => clk,
    clkout0 => open,
    clkout1 => clk_pixel_x5_pal,
    clkout2 => clk64_pal,    -- 0 deg clk64_pal,
    clkout3 => mspi_clk, -- 135 deg
    clkout4 => open,     -- 0 deg clk_sys_pal,
    clkout5 => open,     -- 180 deg
    lock => pll_locked_pal,
    mdclk => clk
);

mainclock_ntsc: entity work.Gowin_PLL_ntsc
port map (
    clkin => clk,
    clkout0 => open,
    clkout1 => clk_pixel_x5_ntsc,
    clkout2 => clk64_ntsc,
    clkout4 => open, -- 0 deg clk_sys_ntsc,
    lock => pll_locked_ntsc,
    mdclk => clk
);

leds_n <=  leds(1 downto 0);
leds(0) <= led1541;
leds(1) <= ioctl_download or ioctl_upload;

--                    6   5  4  3  2  1  0
--                  TR3 TR2 TR RI LE DN UP digital c64 
-- 3rd button of GS controller are triggerd also by extra buttons mapped Joysticks
joyDigital0 <= (others => '0') when (ext_iec_en = "01") or (osd_status = '1') else not('1' & io(5) & io(0) & io(3) & io(4) & io(1) & io(2));
joyDigital1 <= (others => '0') when (ext_iec_en = "10") or (osd_status = '1') else not('1' & spare(5) & spare(0) & spare(3) & spare(4) & spare(1) & spare(2));
joyUsb1     <= (joystick1(6) or extra_button1(2)) & joystick1(5 downto 4) & joystick1(0) & joystick1(1) & joystick1(2) & joystick1(3);
joyUsb2     <= (joystick2(6) or extra_button2(2)) & joystick2(5 downto 4) & joystick2(0) & joystick2(1) & joystick2(2) & joystick2(3);
joyNumpad   <= '0' & numpad(5 downto 4) & numpad(0) & numpad(1) & numpad(2) & numpad(3);
joyMouse    <= "00" & mouse_btns(0) & "000" & mouse_btns(1);
joyUsb1A    <= "00" & '0' & joystick1(5) & joystick1(4) & "00"; -- Y,X button
joyUsb2A    <= "00" & '0' & joystick2(5) & joystick2(4) & "00"; -- Y,X button

-- send external DB9 joystick port to µC
db9_joy <= (others => '0') when ext_iec_en = "01" else not(io(5) & io(0) & io(2) & io(1) & io(4) & io(3));

process(clk_sys)
begin
	if rising_edge(clk_sys) then
    case port_1_sel is
      when "0000"  => joyA <= joyDigital0;
      when "0001"  => joyA <= joyDigital1;
      when "0010"  => joyA <= joyUsb1;
      when "0011"  => joyA <= joyUsb2;
      when "0110"  => joyA <= joyNumpad;
      when "0111"  => joyA <= joyMouse;
      when "1000"  => joyA <= joyUsb1A;
      when "1001"  => joyA <= joyUsb2A;
      when others  => joyA <= (others => '0');
    end case;

    case port_2_sel is
      when "0000"  => joyB <= joyDigital0;
      when "0001"  => joyB <= joyDigital1;
      when "0010"  => joyB <= joyUsb1;
      when "0011"  => joyB <= joyUsb2;
      when "0110"  => joyB <= joyNumpad;
      when "0111"  => joyB <= joyMouse;
      when "1000"  => joyB <= joyUsb1A;
      when "1001"  => joyB <= joyUsb2A;
      when others  => joyB <= (others => '0');
    end case;
  end if;
end process;

-- process to toggle joy A/B port with Keyboard page-up (STRG + CSR UP)
process(clk_sys)
begin
  if rising_edge(clk_sys) then
    if vsync = '1' then
      numpad_d <= numpad;
      if numpad(7) = '1' and numpad_d(7) = '0' then
        joyswap <= not joyswap; -- toggle mode
        elsif system_joyswap = '1' then -- OSD fixed setting mode
          joyswap <= '1'; -- OSD fixed setting mode
      end if;
    end if;
  end if;
end process;

-- swap joysticks
joyA_c64 <= joyB when joyswap = '1' else joyA;
joyB_c64 <= joyA when joyswap = '1' else joyB;

-- swap paddle 
pot1 <= pd3 when joyswap = '1' else pd1;
pot2 <= pd4 when joyswap = '1' else pd2;
pot3 <= pd1 when joyswap = '1' else pd3;
pot4 <= pd2 when joyswap = '1' else pd4;

-- paddle - mouse - GS controller 2nd button and 3rd button
pd1 <=    joystick1_x_pos(7 downto 0) when port_1_sel = "1000" else
          joystick2_x_pos(7 downto 0) when port_1_sel = "1001" else
          ('0' & std_logic_vector(mouse_x_pos(6 downto 1)) & '0') when port_1_sel = "0111" else
          x"ff" when unsigned(port_1_sel) < 7 and joyA(5) = '1' else x"00";

pd2 <=    joystick1_y_pos(7 downto 0) when port_1_sel = "1000" else
          joystick2_y_pos(7 downto 0) when port_1_sel = "1001" else
          ('0' & std_logic_vector(mouse_y_pos(6 downto 1)) & '0') when port_1_sel = "0111" else
          x"ff" when unsigned(port_1_sel) < 7 and joyA(6) = '1' else x"00";

pd3 <=    joystick1_x_pos(7 downto 0) when port_2_sel = "1000" else
          joystick2_x_pos(7 downto 0) when port_2_sel = "1001" else
          ('0' & std_logic_vector(mouse_x_pos(6 downto 1)) & '0') when port_2_sel = "0111" else
          x"ff" when unsigned(port_2_sel) < 7 and joyB(5) = '1' else x"00";

pd4 <=    joystick1_y_pos(7 downto 0) when port_2_sel = "1000" else
          joystick2_y_pos(7 downto 0) when port_2_sel = "1001" else
          ('0' & std_logic_vector(mouse_y_pos(6 downto 1)) & '0') when port_2_sel = "0111" else
          x"ff" when unsigned(port_2_sel) < 7 and joyB(6) = '1' else x"00";

process(clk_sys, reset_n)
 variable mov_x: signed(6 downto 0);
 variable mov_y: signed(6 downto 0);
 begin
  if reset_n = '0' then
    mouse_x_pos <= (others => '0');
    mouse_y_pos <= (others => '0');
    joystick1_x_pos <= x"ff";
    joystick1_y_pos <= x"ff";
    joystick2_x_pos <= x"ff";
    joystick2_y_pos <= x"ff";
  elsif rising_edge(clk_sys) then
    if mouse_strobe = '1' then
     -- due to limited resolution on the c64 side, limit the mouse movement speed
     if mouse_x > 40 then mov_x:="0101000"; elsif mouse_x < -40 then mov_x:= "1011000"; else mov_x := mouse_x(6 downto 0); end if;
     if mouse_y > 40 then mov_y:="0101000"; elsif mouse_y < -40 then mov_y:= "1011000"; else mov_y := mouse_y(6 downto 0); end if;
      mouse_x_pos <= mouse_x_pos - mov_x;
      mouse_y_pos <= mouse_y_pos + mov_y;
    elsif joystick_strobe = '1' then
      joystick1_x_pos <= std_logic_vector(joystick0ax(7 downto 0));
      joystick1_y_pos <= std_logic_vector(joystick0ay(7 downto 0));
      joystick2_x_pos <= std_logic_vector(joystick1ax(7 downto 0));
      joystick2_y_pos <= std_logic_vector(joystick1ay(7 downto 0));
    end if;
  end if;
end process;

mcu_spi_inst: entity work.mcu_spi 
port map (
  clk            => clk_sys,
  reset          => not pll_locked,
  -- SPI interface to BL616 MCU
  spi_io_ss      => spi_io_ss,      -- SPI CSn
  spi_io_clk     => spi_io_clk,     -- SPI SCLK
  spi_io_din     => spi_io_din,     -- SPI MOSI
  spi_io_dout    => spi_io_dout,    -- SPI MISO
  -- byte interface to the various core components
  mcu_sys_strobe => mcu_sys_strobe, -- byte strobe for system control target
  mcu_hid_strobe => mcu_hid_strobe, -- byte strobe for HID target  
  mcu_osd_strobe => mcu_osd_strobe, -- byte strobe for OSD target
  mcu_sdc_strobe => mcu_sdc_strobe, -- byte strobe for SD card target
  mcu_start      => mcu_start,
  mcu_sys_din    => sys_data_out,
  mcu_hid_din    => hid_data_out,
  mcu_osd_din    => osd_data_out,
  mcu_sdc_din    => sdc_data_out,
  mcu_dout       => mcu_data_out
);

-- decode SPI/MCU data received for human input devices (HID) 
hid_inst: entity work.hid
 port map 
 (
  clk             => clk_sys,
  reset           => not pll_locked,
  -- interface to receive user data from MCU (mouse, kbd, ...)
  data_in_strobe  => mcu_hid_strobe,
  data_in_start   => mcu_start,
  data_in         => mcu_data_out,
  data_out        => hid_data_out,

  -- input local db9 port events to be sent to MCU
  db9_port        => db9_joy,
  irq             => hid_int,
  iack            => int_ack(1),

  -- output HID data received from USB
  usb_kbd         => usb_key,
  kbd_strobe      => kbd_strobe,
  joystick0       => joystick1,
  joystick1       => joystick2,
  numpad          => numpad,
  mouse_btns      => mouse_btns,
  mouse_x         => mouse_x,
  mouse_y         => mouse_y,
  mouse_strobe    => mouse_strobe,
  joystick0ax     => joystick0ax,
  joystick0ay     => joystick0ay,
  joystick1ax     => joystick1ax,
  joystick1ay     => joystick1ay,
  joystick_strobe => joystick_strobe,
  extra_button0   => extra_button1,
  extra_button1   => extra_button2
);

 module_inst: entity work.sysctrl 
 port map 
 (
  clk                 => clk_sys,
  reset               => not pll_locked,
--
  data_in_strobe      => mcu_sys_strobe,
  data_in_start       => mcu_start,
  data_in             => mcu_data_out,
  data_out            => sys_data_out,

  -- values that can be configured by the user
  system_reu_cfg      => reu_cfg,
  system_reset        => system_reset,
  system_scanlines    => system_scanlines,
  system_volume       => system_volume,
  system_screen       => system_screen,
  system_floppy_wprot => system_floppy_wprot,
  system_port_1       => port_1_sel,
  system_port_2       => port_2_sel,
  system_dos_sel      => dos_sel,
  system_1541_reset   => c1541_osd_reset,
  system_sid_digifix  => sid_digifix,
  system_turbo_mode   => turbo_mode,
  system_turbo_speed  => turbo_speed,
  system_video_std    => ntscMode,
  system_midi         => st_midi,
  system_pause        => system_pause,
  system_vic_variant  => vic_variant, 
  system_cia_mode     => cia_mode,
  system_sid_ver      => sid_ver,
  system_sid_mode     => sid_mode,
  system_tape_sound   => system_tape_sound,
  system_up9600       => system_up9600,
  system_sid_filter   => sid_filter,
  system_sid_fc_offset => sid_fc_offset,
  system_georam       => georam,
  system_uart         => system_uart,
  system_joyswap      => system_joyswap,
  system_detach_reset => detach_reset,
  system_shift_mod    => shift_mod,
  system_palette      => palette,
  system_ext_iec_en   => ext_iec_en,
  system_int_iec_drv  => int_iec_drv,
  system_reu_wrap     => reu_wrap,
  system_run_prg      => run_prg,
  system_clear_ram    => clear_ram,
  system_boot_easyflash=> boot_easyflash,
  system_autosave     => autosave,
  system_save_cartridge => save_cartridge,
  system_digimax        => system_digimax,

  -- port io (used to expose rs232)
  port_status       => serial_status,
  port_out_available => serial_tx_available,
  port_out_strobe   => serial_tx_strobe,
  port_out_data     => serial_tx_data,
  port_in_available => serial_rx_available,
  port_in_strobe    => serial_rx_strobe,
  port_in_data      => serial_rx_data,

  int_out_n           => spi_intn,
  int_in              => unsigned'(x"0" & sdc_int & '0' & hid_int & '0'),
  int_ack             => int_ack,

  buttons             => unsigned'(key_user & key_reset), -- S2 and S1 buttons
  leds                => open,
  color               => open
);

process(clk_sys)
variable toX:	integer := 0;
begin
  if rising_edge(clk_sys) then
    c64_iec_clk_old   <= c64_iec_clk;
    drive_iec_clk_old <= drive_iec_clk;
    drive_stb_i_old   <= drive_stb_i;
    drive_stb_o_old   <= drive_stb_o;

    if c64_iec_clk_old /= c64_iec_clk
      or drive_iec_clk_old /= drive_iec_clk
      or ((drive_stb_i_old /= drive_stb_i
      or drive_stb_o_old /= drive_stb_o) and ext_en = '1') then
        disk_access <= '1';
        toX := 16000000; -- 0.5s
    elsif toX /= 0 then
      toX := toX - 1;
    else  
      disk_access <= '0';
    end if;
  end if;
end process;

uart_en <= system_up9600(2) or system_up9600(1);
uart_oe <= not ram_we and uart_cs and uart_en;
io_data <=  unsigned(cart_data) when cart_oe = '1' else
            unsigned(reu_dout)  when reu_oe = '1' else
            unsigned(midi_data) when (midi_oe and midi_en) = '1' else
            unsigned(uart_data) when uart_oe = '1' else
            x"FF";
c64rom_wr <= load_rom and ioctl_download and ioctl_wr when ioctl_addr(16 downto 14) = "000" else '0';
sid_fc_lr <= std_logic_vector(to_unsigned(16#600#, sid_fc_lr'length) - unsigned("000" & sid_fc_offset & "0000000")) when sid_filter(2) = '1' else (others => '0');

fpga64_sid_iec_inst: entity work.fpga64_sid_iec
  generic map (
    DUAL =>  DUAL   -- 0:no, 1:yes  Dual SID component build
  )
  port map
  (
  clk32        => clk_sys,
  reset_n      => reset_n,
  bios         => "00",
  pause        => '0',
  pause_out    => c64_pause,

  usb_key      => key,
  kbd_strobe   => key_strobe,
  kbd_reset    => not reset_n,
  shift_mod    => not shift_mod,

  -- external memory
  ramAddr      => c64_addr,
  ramDin       => c64_data_in,
  ramDout      => c64_data_out,
  ramCE        => ram_ce,
  ramWE        => ram_we,
  io_cycle     => io_cycle,
  ext_cycle    => ext_cycle,
  refresh      => idle,

  cia_mode     => cia_mode,
  turbo_mode   => ((turbo_mode(1) and not disk_access) & turbo_mode(0)),
  turbo_speed  => turbo_speed,

  vic_variant  => vic_variant,
  ntscMode     => ntscMode,
  hsync        => hsync,
  vsync        => vsync,
  palette      => palette,
  r            => r,
  g            => g,
  b            => b,

  phi          => phi,
  phi2_p       => open,
  phi2_n       => phi2_n,

  game         => game,
  exrom        => exrom,
  io_rom       => io_rom,
  io_ext       => reu_oe or cart_oe or uart_oe or (midi_oe and midi_en),
  io_data      => io_data,
  irq_n        => midi_irq_n or (not midi_en),
  nmi_n        => not nmi and (uart_irq or not uart_en), -- and (midi_nmi_n or not midi_en),
  nmi_ack      => nmi_ack,
  romL         => romL,
  romH         => romH,
  UMAXromH     => UMAXromH,
  IO7          => IO7,
  IOE          => IOE,
  IOF          => IOF,
  freeze_key   => freeze_key,
  mod_key      => mod_key,
  tape_play    => open,

  -- dma access
  dma_req      => dma_req,
  dma_cycle    => dma_cycle,
  dma_addr     => unsigned(dma_addr),
  dma_dout     => unsigned(dma_dout),
  dma_din      => dma_din,
  dma_we       => dma_we,
  irq_ext_n    => not reu_irq,

  -- joystick interface
  joyA         => joyA_c64,
  joyB         => joyB_c64,
  pot1         => pot1,
  pot2         => pot2,
  pot3         => pot3,
  pot4         => pot4,

  --SID
  audio_l      => audio_data_l,
  audio_r      => audio_data_r,
  sid_filter   => "11",
  sid_ver      => sid_ver & sid_ver,
  sid_mode     => sid_mode,
  sid_cfg      => std_logic_vector(sid_filter(1 downto 0) & sid_filter(1 downto 0)),
  sid_fc_off_l => sid_fc_lr,
  sid_fc_off_r => sid_fc_lr,
  sid_ld_clk   => clk_sys,
  sid_ld_addr  => sid_ld_addr,
  sid_ld_data  => sid_ld_data,
  sid_ld_wr    => sid_ld_wr,
  sid_digifix  => sid_digifix,
  -- USER
  pb_i         => unsigned(pb_i),
  std_logic_vector(pb_o) => pb_o,
  pa2_i        => pa2_i,
  pa2_o        => pa2_o,
  pc2_n_o      => pc2_n_o,
  flag2_n_i    => flag2_n_i,
  sp2_i        => sp2_i,
  sp2_o        => open,
  sp1_i        => '1',
  sp1_o        => sp1_o,
  cnt2_i       => cnt2_i,
  cnt2_o       => cnt2_o,
  cnt1_i       => '1',
  cnt1_o       => open,

  -- IEC
  iec_data_o   => c64_iec_data,
  iec_atn_o    => c64_iec_atn,
  iec_clk_o    => c64_iec_clk,
  iec_data_i   => drive_iec_data,
  iec_clk_i    => drive_iec_clk,

  c64rom_addr  => std_logic_vector(ioctl_addr(13 downto 0)),
  c64rom_data  => std_logic_vector(ioctl_data),
  c64rom_wr    => c64rom_wr,

  cass_motor   => cass_motor,
  cass_write   => cass_write,
  cass_sense   => cass_sense,
  cass_read    => cass_read
  );

process(clk_sys)
begin
  if rising_edge(clk_sys) then
    ext_cycle_d <= ext_cycle;
  end if;
end process;

reu_oe  <= '1' when IOF = '1' and reu_cfg /= "00" else '0';
reu_ram_ce <= not ext_cycle_d and ext_cycle and dma_req;

reu_inst: entity work.reu
generic map(
  REU_ADDR => REU_ADDR
)
port map(
    clk       => clk_sys,
    reset     => not reset_n,
    cfg       => reu_cfg,
    wrap      => reu_wrap,
  
    dma_req   => dma_req,
    dma_cycle => dma_cycle,
    dma_addr  => dma_addr,
    dma_dout  => dma_dout,
    dma_din   => dma_din,
    dma_we    => dma_we,
  
    ram_cycle => ext_cycle,
    ram_addr  => reu_ram_addr,
    ram_dout  => reu_ram_dout,
    ram_din   => sdram_data,
    ram_we    => reu_ram_we,
    
    cpu_addr  => c64_addr, 
    cpu_dout  => c64_data_out,
    cpu_din   => reu_dout,
    cpu_we    => ram_we,
    cpu_cs    => IOF,
    
    irq       => reu_irq
  ); 

-- c1541 ROM's SPI Flash
-- TN20k  Winbond 25Q64JVIQ
-- TP25k  XTX XT25F64FWOIG
-- TM138k Winbond 25Q128BVEA
-- TM60k  Winbond 25Q64JVIQ
-- phase shift 135° TN, TP and 270° TM
-- offset in spi flash TN20K, TP25K $200000, TM138K $A00000
flash_inst: entity work.flash 
port map(
    clk       => clk64_pal,
    resetn    => pll_locked_pal and jtagseln,
    ready     => flash_ready,
    busy      => open,
    address   => (X"2" & "000" & dos_sel & c1541rom_addr),
    cs        => c1541rom_cs,
    dout      => c1541rom_data,
    mspi_cs   => mspi_cs,
    mspi_di   => mspi_di,
    mspi_hold => mspi_hold,
    mspi_wp   => mspi_wp,
    mspi_do   => mspi_do
);

cid <= cart_id when cart_attached = '1' else x"63" when georam ='1' else x"FF";

cartridge_inst: entity work.cartridge
generic map(
  RAM_ADDR => RAM_ADDR,
  CRM_ADDR => CRM_ADDR,
  CRT_ADDR => CRT_ADDR,
  GEO_ADDR => GEO_ADDR
)
port map(
    clk32           => clk_sys,
    reset_n         => reset_n,
  
    cart_loading    => ioctl_download and load_crt,
    cart_id         => cid,
    cart_exrom      => cart_exrom,
    cart_game       => cart_game,
    cart_bank_hi    => cart_bank_hi,
    cart_bank_16k   => cart_bank_16k,
    cart_bank_num   => cart_bank_num,
    cart_bank_addr  => ioctl_load_addr(20 downto 13),
    cart_bank_wr    => cart_hdr_wr,
    cart_boot       => boot_easyflash,
    lobanks         => cart_lobanks,
    hibanks         => cart_hibanks,
    lobanks_map     => cart_lobanks_map,
    hibanks_map     => cart_hibanks_map,
    bank_cnt        => cart_bank_cnt,

    exrom           => exrom,
    game            => game,

    romL        => romL,
    romH        => romH,
    UMAXromH    => UMAXromH,
    IOE         => IOE,
    IOF         => IOF,
    mem_write   => ram_we,
    mem_ce      => ram_ce,
    mem_ce_out  => cart_ce,
    mem_write_out => cart_we,
    mem_in      => sdram_data,
    mem_out     => cart_wrdata,
    mem_addr    => cart_addr,
    mem_req     => cart_mem_req,
    mem_cycle   => io_cycle,
    IO_rom      => io_rom,
    IO_rd       => cart_oe,
    IO_data     => cart_data,
    addr_in     => c64_addr,
    data_in     => c64_data_out,
    data_out    => c64_data_in,

    freeze_key  => freeze_key,
    mod_key     => mod_key,
    nmi         => nmi,
    nmi_ack     => nmi_ack
  );

ezfl_save <= save_cartridge or (autosave and ezfl_mod);

process(clk_sys)
  begin
  if rising_edge(clk_sys) then
    if cart_mem_req = '1' then 
      ezfl_mod <= '1'; 
    end if;

    if ioctl_download = '1' and load_crt = '1' then
      ezfl_mod <= '0'; 
    end if;
    
    if ioctl_upload = '1' then 
      ezfl_mod <= '0';
      ezfl_save_en <= '0';
    end if;

    ezfl_save_old <= ezfl_save;
    if ezfl_save_old = '0' and ezfl_save = '1' then
      ezfl_idx <= not save_cartridge;
    end if;

    ext_old <= ext_crt;
	  if ext_old = '0' and ext_crt = '1' then
      ezfl_save_en <= '1';
    end if;

  end if;
end process;

midi_en <= '1' when st_midi /= "000" else '0';

yes_midi: if MIDI /= 0 generate
  midi_inst : entity work.c64_midi
  port map (
    clk32   => clk_sys,
    reset   => (not reset_n) or (not midi_en),
    Mode    => st_midi,
    E       => phi,
    IOE     => IOE and midi_en,
    A       => std_logic_vector(c64_addr),
    Din     => std_logic_vector(c64_data_out),
    Dout    => midi_data,
    OE      => midi_oe,
    RnW     => not ram_we,
    nIRQ    => midi_irq_n,
    nNMI    => midi_nmi_n,
 
    RX      => midi_rx,
    TX      => midi_tx
  );
else generate
    midi_oe <= '0';
    midi_irq_n <= '1';
    midi_nmi_n <= '1';
    midi_data <= x"FF";
    midi_tx <= '1';
end generate yes_midi;

crt_inst : entity work.loader_sd_card
port map (
  clk               => clk_sys,
  reset             => std_logic(system_reset(1) or not pll_locked),

  sd_lba            => loader_lba,
  sd_rd             => sd_rd(7 downto 1),
  sd_wr             => sd_wr(7 downto 1),
  sd_busy           => sd_busy,
  sd_done           => sd_done,

  sd_byte_index     => sd_byte_index,
  sd_rd_data        => sd_rd_data,
  sd_rd_byte_strobe => sd_rd_byte_strobe,
  sd_wr_data        => loader_sd_wr_data,

  sd_img_mounted    => sd_img_mounted,
  loader_busy       => loader_busy,
  load_crt          => load_crt,
  load_prg          => load_prg,
  load_rom          => load_rom,
  load_tap          => load_tap,
  load_flt          => load_flt,
  load_reu          => load_reu,
  sd_img_size       => sd_img_size,

  lobanks           => cart_lobanks,
  hibanks           => cart_hibanks,
  lobanks_map       => cart_lobanks_map,
  hibanks_map       => cart_hibanks_map,
  bank_cnt          => cart_bank_cnt,

  ioctl_download    => ioctl_download,
  ioctl_upload_req  => ezfl_save,
  ioctl_upload      => ioctl_upload,
  ioctl_din         => ioctl_din,
  ioctl_addr        => ioctl_addr,
  ioctl_dout        => ioctl_data,
  ioctl_wr          => ioctl_wr,
  ioctl_rd          => ioctl_rd,
  ioctl_wait        => ioctl_req_wr or reset_wait or ioctl_req_rd
);

process(clk_sys)
begin
  if rising_edge(clk_sys) then
    old_download <= ioctl_download;
    old_upload <= ioctl_upload;
    io_cycleD <= io_cycle;
    cart_hdr_wr <= '0';
    detach_reset_d <= detach_reset;

    if io_cycle = '0' and io_cycleD = '1' then
      io_cycle_ce <= '1';
      io_cycle_we <= '0';
      io_cycle_addr <= tap_play_addr + TAP_ADDR;
      if ioctl_req_wr = '1' then
        ioctl_req_wr <= '0';
        io_cycle_we <= '1';
        io_cycle_addr <= ioctl_load_addr;
        ioctl_load_addr <= ioctl_load_addr + 1;
        if erasing = '1' then  -- fill RAM with 64 bytes 0, 64 bytes ff
          io_cycle_data <= (others => ioctl_load_addr(6));
        elsif inj_meminit = '1' then 
          io_cycle_data <= inj_meminit_data;
        else 
          io_cycle_data <= ioctl_data;
        end if;
      end if;

      if ioctl_req_rd = '1' then
        io_cycle_addr <= ioctl_load_addr;
        ioctl_rd_en <= '1';
      end if;
    end if;

    if io_cycle = '1' then
      io_cycle_ce <= '0';
      io_cycle_we <= '0';
      ioctl_rd_en <= '0';
    end if;

    if old_upload = '0' and ioctl_upload = '1' then
      ioctl_load_addr <= CRT_ADDR;
      rd_cyc <= (others => '0');
      ioctl_req_rd <= '0';
      ioctl_rd_en <= '0';
    end if;

    if ioctl_rd = '1' then
      ioctl_load_addr <= CRT_ADDR + resize(ioctl_addr, ioctl_load_addr'length);
      ioctl_req_rd <= '1';
    end if;

    rd_cyc <= rd_cyc(1 downto 0) & (io_cycle and io_cycle_ce and ioctl_rd_en);

    if rd_cyc(2) = '1' then
      ioctl_din <= sdram_data;
      ioctl_req_rd <= '0';
    end if;

    if ioctl_wr = '1' then
      if load_prg = '1' then
        -- PRG header
        -- Load address low-byte
        if ioctl_addr = to_unsigned(0, ioctl_addr'length) then
          ioctl_load_addr(7 downto 0) <= ioctl_data;
          inj_end(7 downto 0)  <= ioctl_data;
          -- Load address high-byte
        elsif ioctl_addr = to_unsigned(1, ioctl_addr'length) then
          ioctl_load_addr(ioctl_load_addr'high downto 8) <=
            (ioctl_load_addr(ioctl_load_addr'high downto (8 + ioctl_data'length))'range => '0') & ioctl_data;
          inj_end(15 downto 8) <= ioctl_data;
        else
          ioctl_req_wr <= '1';
          inj_end <= inj_end + 1;
        end if;

      elsif load_crt = '1' then
        if ioctl_addr = to_unsigned(0, ioctl_addr'length) then
          ioctl_load_addr <= CRT_ADDR;
          cart_blk_len <= (others => '0');
          cart_hdr_cnt <= (others => '0');
        end if;

        if unsigned(ioctl_addr) = to_unsigned(16#16#, ioctl_addr'length) then
          cart_id_hi <= ioctl_data;
        end if;

        if ioctl_addr = to_unsigned(16#17#, ioctl_addr'length) then
          if cart_id_hi /= to_unsigned(0, cart_id_hi'length) then
            cart_id <= x"FF";
          else
            cart_id <= ioctl_data;
          end if;
        end if;

        if ioctl_addr = to_unsigned(16#18#, ioctl_addr'length) then
          cart_exrom <= ioctl_data(0);
        end if;

        if ioctl_addr = to_unsigned(16#19#, ioctl_addr'length) then
          cart_game <= ioctl_data(0);
        end if;

        if ioctl_addr >= to_unsigned(16#40#, ioctl_addr'length) then
          if cart_blk_len = to_unsigned(0, cart_blk_len'length) or 
          cart_hdr_cnt /= to_unsigned(0, cart_hdr_cnt'length) then
            cart_hdr_cnt <= cart_hdr_cnt + 1;

            if cart_hdr_cnt = to_unsigned(6, cart_hdr_cnt'length) then
              cart_blk_len <= ioctl_data & x"00";
            end if;

            if cart_hdr_cnt = to_unsigned(11, cart_hdr_cnt'length) then
              cart_bank_num <= ioctl_data;
            end if;

            if cart_hdr_cnt = to_unsigned(12, cart_hdr_cnt'length) then
              if ioctl_data > to_unsigned(16#80#, ioctl_data'length) then
                cart_bank_hi <= '1';
              else
                cart_bank_hi <= '0';
              end if;
            end if;

            if cart_hdr_cnt = to_unsigned(14, cart_hdr_cnt'length) then
              if ioctl_data > to_unsigned(16#20#, ioctl_data'length) then
                cart_bank_16k <= '1';
              else
                cart_bank_16k <= '0';
              end if;
            end if;

            if unsigned(cart_hdr_cnt) = to_unsigned(15, cart_hdr_cnt'length) then
              cart_hdr_wr <= '1';
            end if;
          else
            cart_blk_len <= cart_blk_len - 1;
            ioctl_req_wr <= '1';
          end if;
        end if;

      elsif load_tap = '1' then
        if ioctl_addr = to_unsigned(0, ioctl_addr'length) then ioctl_load_addr <= TAP_ADDR; end if;
        if ioctl_addr = to_unsigned(12, ioctl_addr'length) then tap_version <= std_logic_vector(ioctl_data(1 downto 0)); end if;
        ioctl_req_wr <= '1';

      elsif load_reu = '1' then
        if ioctl_addr = to_unsigned(0, ioctl_addr'length) then ioctl_load_addr <= REU_ADDR; end if;
        ioctl_req_wr <= '1';
      end if;

    end if;

    -- cart added
    if (old_download /= ioctl_download) and load_crt = '1' then
      cart_attached <= old_download;
      erase_cram <= '1';
      ext_crt <= ioctl_download and load_crt;
    end if;

    -- meminit for RAM injection
    if (old_download /= ioctl_download) and load_prg = '1' and inj_meminit = '0' then
      inj_meminit <= '1';
      ioctl_load_addr <= (others => '0');
    end if;

    if inj_meminit = '1' then
      if ioctl_req_wr = '0' then
        -- check if done
        if ioctl_load_addr(15 downto 0) = x"0100" then
          inj_meminit <= '0';
        else
          ioctl_req_wr <= '1';
          -- Initialize BASIC pointers to simulate the BASIC LOAD command
          case ioctl_load_addr(7 downto 0) is
            -- TXT (2B-2C)
            -- Set these two bytes to $01, $08 just as they would be on reset (the BASIC LOAD command does not alter these)
            when x"2B" => inj_meminit_data <= x"01";
            when x"2C" => inj_meminit_data <= x"08";
            -- SAVE_START (AC-AD)
            -- Set these two bytes to zero just as they would be on reset (the BASIC LOAD command does not alter these)
            when x"AC" | x"AD" => inj_meminit_data <= x"00";
            -- VAR (2D-2E), ARY (2F-30), STR (31-32), LOAD_END (AE-AF)
            -- Set these just as they would be with the BASIC LOAD command (essentially they are all set to the load end address)
            when x"2D" | x"2F" | x"31" | x"AE" => inj_meminit_data <= inj_end(7 downto 0);
            when x"2E" | x"30" | x"32" | x"AF" => inj_meminit_data <= inj_end(15 downto 8);
            when others =>
              ioctl_req_wr <= '0';
              -- advance the address
              ioctl_load_addr <= ioctl_load_addr + 1;
          end case;
        end if;
      end if;
    end if;

    old_meminit <= inj_meminit;
    start_strk  <= '1' when old_meminit = '1' and inj_meminit = '0' else '0';

    if detach_reset_d = '0' and detach_reset = '1' then
      cart_attached <= '0';
    end if;

    -- start RAM erasing
    if erasing = '0' and force_erase ='1' then
      erasing <= '1';
      ioctl_load_addr <= (others => '0');
    end if;

    -- RAM erasing control
    if erasing = '1' and ioctl_req_wr = '0' then
      erase_to <= erase_to + 1;
      if erase_to = "11111" then
        if ioctl_load_addr(16 downto 0) < (erase_cram & x"FFFF") then 
          ioctl_req_wr <= '1';
        else
          erasing <= '0';
          erase_cram <= '0';
        end if;
      end if;
    end if;

  end if;
end process;

process(clk_sys)
begin
  if rising_edge(clk_sys) then
    if reset_n = '0' then
      act <= (others => '0');
      key <= (others => '0');
      key_strobe <= kbd_strobe;
    end if;

    if act /= to_unsigned(0, act'length) then
      to_cnt <= to_cnt + 1;

      if to_cnt > 1280000 then
        to_cnt <= 0;
        act <= act + 1;

        case to_integer(act) is
          when 1  => key(6 downto 0) <= 7X"15"; -- R
          when 3  => key(6 downto 0) <= 7X"18"; -- U
          when 5  => key(6 downto 0) <= 7X"11"; -- N
          when 7  => key(6 downto 0) <= 7X"28"; -- <RETURN>
          when 9  => key(7 downto 0) <= (others => '0');
          when 10 => act <= (others => '0');
          when others => null;
        end case;

        key(7) <= not act(0);-- press/release

        if act >= to_unsigned(9, act'length) then
          key_strobe <= kbd_strobe;
        else
          key_strobe <= not key_strobe;
        end if;

      end if;
    else
      to_cnt <= 0;
      key <= usb_key;
      key_strobe <= kbd_strobe;
    end if;

    if (start_strk = '1') and (run_prg = '1') then
      act <= to_unsigned(1, act'length);
      key <= (others => '0');
      key_strobe <= '0';
    end if;
  end if;
end process;

por <= system_reset(1) or system_reset(0) or not pll_locked or not ram_ready;

process(clk_sys)
  begin
    if rising_edge(clk_sys) then
      old_download_r <= ioctl_download;

      if reset_counter = 0 then
        reset_n <= '1';
      else
        reset_n <= '0';
      end if;

      if por = '1' or detach_reset = '1' then
        if system_reset(1) = '1' then
          do_erase <= '1';
        end if;
      reset_counter <= 100000;
      elsif old_download_r = '0' and ioctl_download = '1' and load_prg = '1' then
        do_erase <= '1';
        reset_wait <= '1';
        reset_counter <= 255;
      elsif ioctl_download = '1' and (load_crt or load_rom) = '1' then
        do_erase <= '1';
        reset_counter <= 255;
      elsif erasing = '1' then 
        force_erase <= '0';
      elsif reset_counter = 0 then
        do_erase <= '0';
        if reset_wait = '1' and c64_addr = to_unsigned(16#FFCF#, c64_addr'length) then reset_wait <= '0'; end if;
      else
        reset_counter <= reset_counter - 1;
        if reset_counter = 100 and (clear_ram = '1' or do_erase = '1') then
          force_erase <= '1'; 
        end if;
      end if;
    end if;
end process;

process(clk_sys)
begin
  if rising_edge(clk_sys) then
    sid_ld_wr <= '0';
    if ioctl_wr = '1' and load_flt = '1' and ioctl_addr < to_unsigned(6144, ioctl_addr'length) then
        if ioctl_addr(0) = '1' then
          sid_ld_data(15 downto 8) <= std_logic_vector(ioctl_data);
          sid_ld_addr <= std_logic_vector(ioctl_addr(12 downto 1));
          sid_ld_wr <= '1';
        else
          sid_ld_data(7 downto 0) <= std_logic_vector(ioctl_data);
        end if;
    end if;
	end if;
end process;

--------------- TAP -------------------

tap_download <= ioctl_download and load_tap;
tap_reset <= '1' when reset_n = '0' or tap_download = '1' or tap_last_addr = to_unsigned(0, tap_last_addr'length) or cass_finish = '1' or (cass_run = '1'and ((tap_last_addr - tap_play_addr) < to_unsigned(80, tap_last_addr'length))) else '0';
tap_loaded <= '1' when tap_play_addr < tap_last_addr else '0';
tap_io_cycle <= not tap_wrfull and tap_loaded;

process(clk_sys)
begin
  if rising_edge(clk_sys) then
      io_cycle_rD <= io_cycle;
      tap_wrreq(1 downto 0) <= tap_wrreq(1 downto 0) sll 1;

      if tap_reset = '1' then
        -- C1530 module requires one more byte at the end due to fifo early check.
        read_cyc <= '0';
        tap_last_addr <= ioctl_addr + 2 when tap_download = '1' else (others => '0');
        tap_play_addr <= (others => '0');
        tap_start <= tap_download;
      else
        tap_start <= '0';
        if io_cycle = '0' and io_cycle_rD = '1' and tap_io_cycle = '1' then
            read_cyc <= '1';
          end if;
        if io_cycle = '1' and io_cycle_rD = '1' and read_cyc = '1' then
            tap_play_addr <= tap_play_addr + 1;
            read_cyc <= '0';
            tap_wrreq(0) <= '1';
          end if;
      end if;
  end if;
end process;

c1530_inst: entity work.c1530
port map (
  clk32           => clk_sys,
  restart_tape    => tap_reset,
  wav_mode        => '0',
  tap_version     => tap_version,
  host_tap_in     => std_logic_vector(sdram_data),
  host_tap_wrreq  => tap_wrreq(1),
  tap_fifo_wrfull => tap_wrfull,
  tap_fifo_error  => cass_finish,
  cass_read       => cass_read,
  cass_write      => cass_write,
  cass_motor      => cass_motor,
  cass_sense      => cass_sense,
  cass_run        => cass_run,
  osd_play_stop_toggle => tap_start,
  ear_input       => '0'
);

-- external HW pin UART interface
-- 00 BL616 debug UART to ext HW pins
-- 01 USB-C BL616 UART to Userport UART if ext MPU in use
-- 10 Userport UART to ext HW pins
-- 11 6551 UART to ext HW pins 
-- bl616_jtagsel BL616 USB UART if PMOD MPU in use
uart_rx_muxed <= bl616_jtagsel when system_uart = "01" else uart_ext_rx when system_uart = "10" else '1';
--uart_ext_tx <= uart_rx when system_uart = "00" else uart_tx_i;

-- UART_RX synchronizer
process(clk_sys)
begin
    if rising_edge(clk_sys) then
      uart_rxD(0) <= uart_rx_muxed;
      uart_rxD(1) <= uart_rxD(0);
      if uart_rxD(0) = uart_rxD(1) then
        uart_rx_filtered <= uart_rxD(1);
      end if;
    end if;
end process;

-- connect user port
process (all)
begin
  pa2_i <= pa2_o;
  cnt2_i <= '1';
  sp2_i <= '1';
  pb_i <= (others => '1');
  drive_par_i <= (others => '1');
  drive_stb_i <= '1';
  uart_tx_i <= '1';
  flag2_n_i <= '1';
  uart_cs <= '0';
  if ext_en = '1' and disk_access = '1' then
    -- c1541 parallel bus
    drive_par_i <= pb_o;
    drive_stb_i <= pc2_n_o;
    pb_i <= drive_par_o;
    flag2_n_i <= drive_stb_o;
  elsif system_up9600 = to_unsigned(0, system_up9600'length) and (disk_access = '0' or ext_en = '0') then
    -- UART 
    -- https://www.pagetable.com/?p=1656
    -- FLAG2 RXD
    -- PB0 RXD in
    -- PB1 RTS out
    -- PB2 DTR out
    -- PB3 RI in
    -- PB4 DCD in
    -- PB5
    -- PB6 CTS in
    -- PB7 DSR in
    -- PA2 TXD out
    uart_tx_i <= pa2_o;
    flag2_n_i <= uart_rx_filtered;
    pb_i(0) <= uart_rx_filtered;
    -- Zeromodem
    pb_i(6) <= not pb_o(1);  -- RTS > CTS
    pb_i(4) <= not pb_o(2);  -- DTR > DCD
    pb_i(7) <= not pb_o(2);  -- DTR > DSR
  elsif system_up9600 = to_unsigned(1, system_up9600'length) and (disk_access = '0' or ext_en = '0') then
    -- UART UP9600
    -- https://www.pagetable.com/?p=1656
    -- SP1 TXD
    -- PA2 TXD
    -- PB0 RXD
    -- SP2 RXD
    -- FLAG2 RXD
    -- PB7 to CNT2 
    pb_i(7) <= cnt2_o;
    cnt2_i <= pb_o(7);
    uart_tx_i <= pa2_o and sp1_o;
    sp2_i <= uart_rx_filtered;
    flag2_n_i <= uart_rx_filtered;
    pb_i(0) <= uart_rx_filtered;
    elsif system_up9600 = to_unsigned(2, system_up9600'length) then
      uart_tx_i <= tx_6551;
      uart_cs <= IOE;
    elsif system_up9600 = to_unsigned(3, system_up9600'length) then
      uart_tx_i  <= tx_6551;
      uart_cs <= IOF;
    elsif system_up9600 = to_unsigned(4, system_up9600'length) then
      uart_tx_i <= tx_6551;
      uart_cs <= IO7;
  end if;
end process;

-- |SwiftLink       $DE00/$DF00/$D700/NMI (38400 baud)
yes_uart: if U6551 /= 0 generate
uart_inst : entity work.glb6551
port map (
  RESET_N     => reset_n,
  CLK         => clk_sys,
  RX_CLK      => open,
  RX_CLK_IN   => CLK_6551_EN,
  XTAL_CLK_IN => CLK_6551_EN,
  PH_2        => phi2_n,
  DI          => c64_data_out,
  DO          => uart_data,
  IRQ         => uart_irq,
  CS          => unsigned'(not uart_en & uart_cs),
  RW_N        => not ram_we,
  RS          => c64_addr(1 downto 0),
  TXDATA_OUT  => tx_6551,
  RXDATA_IN   => uart_rx_filtered,
  RTS         => rts_cts,
  CTS         => rts_cts,
  DCD         => dtr,
  DTR         => dtr,
  DSR         => dtr,
  -- serial/rs232 interface io-controller<-> UART
  serial_status_out   => serial_status,
  serial_data_out_available => serial_tx_available,
  serial_strobe_out   => serial_tx_strobe,
  serial_data_out     => serial_tx_data,

  serial_data_in_free => serial_rx_available,
  serial_strobe_in    => serial_rx_strobe,
  serial_data_in      => serial_rx_data
  );

uart_clk_inst : entity work.BaudRate
port map (
      i_CLOCK     => clk_sys,
      o_serialEn  => CLK_6551_EN
);
else generate
  tx_6551 <= '1';
  uart_data <= x"FF";
  uart_irq <= '1';
end generate yes_uart;

end Behavioral_top;
