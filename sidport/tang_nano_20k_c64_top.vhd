-------------------------------------------------------------------------
--  C64 Top level for Tang Nano
--  2023 / 2024 Stefan Voss
--  based on the work of many others
--
--  FPGA64 is Copyrighted 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
--  http://www.syntiac.com/fpga64.html
--
-------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.ALL;

entity tang_nano_20k_c64_top is
  generic
  (
   DUAL  : integer := 1 -- 0:no, 1:yes dual SID build option
  );
  port
  (
    clk         : in std_logic;
    reset       : in std_logic; -- S2 button
    user        : in std_logic; -- S1 button
    leds_n      : out std_logic_vector(5 downto 0);
    io          : in std_logic_vector(4 downto 0);
    uart_rx     : in std_logic;
    uart_tx     : out std_logic;
    -- SPI interface Sipeed M0S Dock external BL616 uC
    m0s         : inout std_logic_vector(5 downto 0);
    --
    tmds_clk_n  : out std_logic;
    tmds_clk_p  : out std_logic;
    tmds_d_n    : out std_logic_vector( 2 downto 0);
    tmds_d_p    : out std_logic_vector( 2 downto 0);
    -- sd interface
    sd_clk      : out std_logic;
    sd_cmd      : inout std_logic;
    sd_dat      : inout std_logic_vector(3 downto 0);
    ws2812      : out std_logic;
    -- "Magic" port names that the gowin compiler connects to the on-chip SDRAM
    O_sdram_clk  : out std_logic;
    O_sdram_cke  : out std_logic;
    O_sdram_cs_n : out std_logic;            -- chip select
    O_sdram_cas_n : out std_logic;           -- columns address select
    O_sdram_ras_n : out std_logic;           -- row address select
    O_sdram_wen_n : out std_logic;           -- write enable
    IO_sdram_dq  : inout std_logic_vector(31 downto 0); -- 32 bit bidirectional data bus
    O_sdram_addr : out std_logic_vector(10 downto 0);  -- 11 bit multiplexed address bus
    O_sdram_ba   : out std_logic_vector(1 downto 0);     -- two banks
    O_sdram_dqm  : out std_logic_vector(3 downto 0);     -- 32/4
    -- Gamepad
    joystick_clk  : out std_logic;
    joystick_mosi : out std_logic;
    joystick_miso : inout std_logic; -- midi_out
    joystick_cs   : inout std_logic; -- midi_in
    -- spi flash interface
    mspi_cs       : out std_logic;
    mspi_clk      : out std_logic;
    mspi_di       : inout std_logic;
    mspi_hold     : inout std_logic;
    mspi_wp       : inout std_logic;
    mspi_do       : inout std_logic
    );
end;

architecture Behavioral_top of tang_nano_20k_c64_top is

signal clk64          : std_logic;
signal clk32          : std_logic;
signal pll_locked     : std_logic;
signal clk_pixel_x10  : std_logic;
signal clk_pixel_x5   : std_logic;
attribute syn_keep : integer;
attribute syn_keep of clk64         : signal is 1;
attribute syn_keep of clk32         : signal is 1;
attribute syn_keep of clk_pixel_x10 : signal is 1;
attribute syn_keep of clk_pixel_x5  : signal is 1;

signal audio_data_l  : std_logic_vector(17 downto 0);
signal audio_data_r  : std_logic_vector(17 downto 0);
signal audio_l       : std_logic_vector(17 downto 0);
signal audio_r       : std_logic_vector(17 downto 0);

-- external memory
signal c64_addr     : unsigned(15 downto 0);
signal c64_data_out : unsigned(7 downto 0);
signal sdram_data   : unsigned(7 downto 0);
signal dout         : std_logic_vector(7 downto 0);
signal idle         : std_logic;
signal dram_addr    : std_logic_vector(22 downto 0);
signal ram_ready    : std_logic;
signal addr         : std_logic_vector(22 downto 0);
signal cs           : std_logic;
signal we           : std_logic;
signal din          : std_logic_vector(7 downto 0);
signal ds           : std_logic_vector(1 downto 0);

-- IEC
signal iec_data_o  : std_logic;
signal iec_data_i  : std_logic;
signal iec_clk_o   : std_logic;
signal iec_clk_i   : std_logic;
signal iec_atn_o   : std_logic;
signal iec_atn_i   : std_logic;

  -- keyboard
signal keyboard_matrix_out : std_logic_vector(7 downto 0);
signal keyboard_matrix_in  : std_logic_vector(7 downto 0);
signal joyUsb1      : std_logic_vector(6 downto 0);
signal joyUsb2      : std_logic_vector(6 downto 0);
signal joyDigital   : std_logic_vector(6 downto 0);
signal joyNumpad    : std_logic_vector(6 downto 0);
signal joyMouse     : std_logic_vector(6 downto 0);
signal joyPaddle    : std_logic_vector(6 downto 0); 
signal joyPaddle2   : std_logic_vector(6 downto 0); 
signal numpad       : std_logic_vector(7 downto 0);
signal joyDS2       : std_logic_vector(6 downto 0);
-- joystick interface
signal joyA        : std_logic_vector(6 downto 0);
signal joyB        : std_logic_vector(6 downto 0);
signal port_1_sel  : std_logic_vector(2 downto 0);
signal port_2_sel  : std_logic_vector(2 downto 0);
-- mouse / paddle
signal pot1        : std_logic_vector(7 downto 0);
signal pot2        : std_logic_vector(7 downto 0);
signal pot3        : std_logic_vector(7 downto 0);
signal pot4        : std_logic_vector(7 downto 0);
signal mouse_x_pos : signed(10 downto 0);
signal mouse_y_pos : signed(10 downto 0);

signal ram_ce      :  std_logic;
signal ram_we      :  std_logic;
signal romCE       :  std_logic;

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
signal joystick1       : std_logic_vector(7 downto 0);
signal joystick2       : std_logic_vector(7 downto 0);
signal mouse_btns     : std_logic_vector(1 downto 0);
signal mouse_x        : signed(7 downto 0);
signal mouse_y        : signed(7 downto 0);
signal mouse_strobe   : std_logic;
signal freeze         : std_logic;

signal c64_pause      : std_logic;
signal old_sync       : std_logic;
signal osd_status     : std_logic;
signal ws2812_color   : std_logic_vector(23 downto 0);
signal system_reset   : std_logic_vector(1 downto 0);
signal disk_reset     : std_logic;
signal disk_chg_trg   : std_logic;
signal disk_chg_trg_d : std_logic;
signal sd_img_size    : std_logic_vector(31 downto 0);
signal sd_img_size_d  : std_logic_vector(31 downto 0);
signal sd_img_mounted : std_logic_vector(5 downto 0);
signal sd_img_mounted_d : std_logic;
signal sd_rd          : std_logic_vector(5 downto 0);
signal sd_wr          : std_logic_vector(5 downto 0);
signal disk_lba       : std_logic_vector(31 downto 0);
signal sd_lba         : std_logic_vector(31 downto 0);
signal loader_lba     : std_logic_vector(31 downto 0);
signal sd_busy        : std_logic;
signal sd_done        : std_logic;
signal sd_rd_byte_strobe : std_logic;
signal sd_byte_index  : std_logic_vector(8 downto 0);
signal sd_rd_data     : std_logic_vector(7 downto 0);
signal sd_wr_data     : std_logic_vector(7 downto 0);
signal sd_change      : std_logic;
signal sdc_int        : std_logic;
signal sdc_iack       : std_logic;
signal int_ack        : std_logic_vector(7 downto 0);
signal spi_io_din     : std_logic;
signal spi_io_ss      : std_logic;
signal spi_io_clk     : std_logic;
signal spi_io_dout    : std_logic;
signal disk_g64       : std_logic;
signal disk_g64_d     : std_logic;
signal c1541_reset    : std_logic;
signal c1541_osd_reset : std_logic;
signal system_wide_screen : std_logic;
signal system_floppy_wprot : std_logic_vector(1 downto 0);
signal leds           : std_logic_vector(5 downto 0);
signal system_leds    : std_logic_vector(1 downto 0);
signal led1541        : std_logic;
signal reu_cfg        : std_logic; 
signal dma_req        : std_logic;
signal dma_cycle      : std_logic;
signal dma_addr       : std_logic_vector(15 downto 0);
signal dma_dout       : std_logic_vector(7 downto 0);
signal dma_din        : unsigned(7 downto 0);
signal dma_we         : std_logic;
signal ext_cycle      : std_logic;
signal ext_cycle_d    : std_logic;
signal reu_ram_addr   : std_logic_vector(24 downto 0);
signal reu_ram_dout   : std_logic_vector(7 downto 0);
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
signal cart_data      : std_logic_vector(7 downto 0);
signal cart_addr      : std_logic_vector(22 downto 0);
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
signal hsync_out       : std_logic;
signal vsync_out       : std_logic;
signal hblank          : std_logic;
signal vblank          : std_logic;
signal frz_hs          : std_logic;
signal frz_vs          : std_logic;
signal hbl_out         : std_logic; 
signal vbl_out         : std_logic;
signal midi_data       : std_logic_vector(7 downto 0) := (others =>'0');
signal midi_oe         : std_logic;
signal midi_irq_n      : std_logic := '1';
signal midi_nmi_n      : std_logic;
signal midi_rx         : std_logic;
signal midi_tx         : std_logic;
signal st_midi         : std_logic_vector(2 downto 0);
signal phi             : std_logic;
signal joystick_cs_i   : std_logic;
signal joystick_miso_i : std_logic;
signal frz_hbl         : std_logic;
signal frz_vbl         : std_logic;
signal system_pause    : std_logic;
signal paddle_1        : std_logic_vector(7 downto 0);
signal paddle_2        : std_logic_vector(7 downto 0);
signal paddle_3        : std_logic_vector(7 downto 0);
signal paddle_4        : std_logic_vector(7 downto 0);
signal key_r1          : std_logic;
signal key_r2          : std_logic;
signal key_l1          : std_logic;
signal key_l2          : std_logic;
signal key_triangle    : std_logic;
signal key_square      : std_logic;
signal key_circle      : std_logic;
signal key_cross       : std_logic;
signal IDSEL           : std_logic_vector(5 downto 0);
signal FBDSEL          : std_logic_vector(5 downto 0);
signal ntscModeD       : std_logic;
signal audio_div       : unsigned(8 downto 0);
signal flash_clk       : std_logic;
signal flash_lock      : std_logic;
signal ioctl_download  : std_logic := '0';
signal ioctl_load_addr : std_logic_vector(22 downto 0);
signal ioctl_req_wr    : std_logic := '0';
signal cart_id         : std_logic_vector(15 downto 0);
signal cart_bank_laddr : std_logic_vector(15 downto 0);
signal cart_bank_size  : std_logic_vector(15 downto 0);
signal cart_bank_num   : std_logic_vector(15 downto 0);
signal cart_bank_type  : std_logic_vector(7 downto 0);
signal cart_exrom      : std_logic_vector(7 downto 0);
signal cart_game       : std_logic_vector(7 downto 0);
signal cart_attached   : std_logic := '0';
signal cart_hdr_cnt    : std_logic_vector(3 downto 0);
signal cart_hdr_wr     : std_logic;
signal cart_blk_len    : std_logic_vector(31 downto 0);
signal io_cycle        : std_logic;
signal io_cycle_ce     : std_logic;
signal io_cycle_we     : std_logic;
signal io_cycle_addr   : std_logic_vector(22 downto 0);
signal io_cycle_data   : std_logic_vector(7 downto 0);
signal load_crt        : std_logic := '0';
signal old_download    : std_logic;
signal io_cycleD       : std_logic;
signal ioctl_wr        : std_logic;
signal ioctl_data      : std_logic_vector(7 downto 0);
signal ioctl_addr      : std_logic_vector(22 downto 0);
signal cid             : std_logic_vector(15 downto 0);
-- crt loader
signal erase_to        : std_logic_vector(4 downto 0);
signal erase_cram      : std_logic := '0';
signal old_meminit     : std_logic;
signal inj_end         : std_logic_vector(15 downto 0);
signal inj_meminit_data : std_logic_vector(7 downto 0);
signal force_erase     : std_logic := '0';
signal erasing         : std_logic := '0';
signal do_erase        : std_logic;
signal inj_meminit     : std_logic := '0';
signal load_prg        : std_logic := '0';
signal load_rom        : std_logic := '0';
signal load_reu        : std_logic := '0';
signal load_tap        : std_logic := '0';
signal tap_play_addr   : std_logic_vector(22 downto 0);
signal reset_wait      : std_logic := '0';
signal old_download_r  : std_logic;
signal reset_n         : std_logic;
signal por             : std_logic;
signal c64rom_wr       : std_logic;
signal img_select      : std_logic_vector(2 downto 0);
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
signal tap_play_btn   : std_logic;
signal tap_last_addr  : std_logic_vector(22 downto 0);
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
signal sid_fc_lr       : std_logic_vector(10 downto 0);
signal sid_filter      : std_logic_vector(2 downto 0);
signal georam          : std_logic;
signal sid_fc_base_lr  : std_logic_vector(8 downto 0);
signal uart_data       : unsigned(7 downto 0);
signal uart_oe         : std_logic;
signal uart_en         : std_logic;
signal tx_6551         : std_logic;
signal uart_irq        : std_logic := '0';
signal uart_cs         : std_logic;
signal CLK_6551_EN     : std_logic;
signal phi2_p, phi2_n  : std_logic;
signal sid_ld_addr     : std_logic_vector(11 downto 0) := (others =>'0');
signal sid_ld_data     : std_logic_vector(15 downto 0) := (others =>'0');
signal sid_ld_wr       : std_logic := '0';
signal img_present     : std_logic := '0';
signal c1541_sd_rd     : std_logic;
signal c1541_sd_wr     : std_logic;

-- 64k core ram                      0x000000
-- cartridge RAM banks are mapped to 0x010000
-- cartridge ROM banks are mapped to 0x100000
constant CRT_MEM_START : std_logic_vector(22 downto 0) := 23x"100000";
constant TAP_ADDR      : std_logic_vector(22 downto 0) := 23x"200000";
constant REU_ADDR      : std_logic_vector(22 downto 0) := 23x"400000";

component CLKDIV
    generic (
        DIV_MODE : STRING := "2";
        GSREN: in string := "false"
    );
    port (
        CLKOUT: out std_logic;
        HCLKIN: in std_logic;
        RESETN: in std_logic;
        CALIB: in std_logic
    );
end component;

component rPLL
    generic (
        FCLKIN: in string := "100.0";
        DEVICE: in string := "GW2A-18";
        DYN_IDIV_SEL: in string := "false";
        IDIV_SEL: in integer := 0;
        DYN_FBDIV_SEL: in string := "false";
        FBDIV_SEL: in integer := 0;
        DYN_ODIV_SEL: in string := "false";
        ODIV_SEL: in integer := 8;
        PSDA_SEL: in string := "0000";
        DYN_DA_EN: in string := "false";
        DUTYDA_SEL: in string := "1000";
        CLKOUT_FT_DIR: in bit := '1';
        CLKOUTP_FT_DIR: in bit := '1';
        CLKOUT_DLY_STEP: in integer := 0;
        CLKOUTP_DLY_STEP: in integer := 0;
        CLKOUTD3_SRC: in string := "CLKOUT";
        CLKFB_SEL: in string := "internal";
        CLKOUT_BYPASS: in string := "false";
        CLKOUTP_BYPASS: in string := "false";
        CLKOUTD_BYPASS: in string := "false";
        CLKOUTD_SRC: in string := "CLKOUT";
        DYN_SDIV_SEL: in integer := 2
    );
    port (
        CLKOUT: out std_logic;
        LOCK: out std_logic;
        CLKOUTP: out std_logic;
        CLKOUTD: out std_logic;
        CLKOUTD3: out std_logic;
        RESET: in std_logic;
        RESET_P: in std_logic;
        CLKIN: in std_logic;
        CLKFB: in std_logic;
        FBDSEL: in std_logic_vector(5 downto 0);
        IDSEL: in std_logic_vector(5 downto 0);
        ODSEL: in std_logic_vector(5 downto 0);
        PSDA: in std_logic_vector(3 downto 0);
        DUTYDA: in std_logic_vector(3 downto 0);
        FDLY: in std_logic_vector(3 downto 0)
    );
end component;

begin
  spi_io_din  <= m0s(1);
  spi_io_ss   <= m0s(2);
  spi_io_clk  <= m0s(3);
  m0s(0)      <= spi_io_dout;
  m0s(5)      <= 'Z';

-- mux overlapping DS2 and MIDI signals to IO pin
joystick_cs     <= joystick_cs_i when st_midi = "000" else 'Z';
midi_rx         <= joystick_cs when st_midi /= "000" else '1';
joystick_miso   <= midi_tx when st_midi /= "000" else 'Z';
joystick_miso_i <= joystick_miso when st_midi = "000" else '1';

-- https://store.curiousinventor.com/guides/PS2/
-- https://hackaday.io/project/170365-blueretro/log/186471-playstation-playstation-2-spi-interface

gamepad: entity work.dualshock2
    port map (
    clk           => clk32,
    rst           => not reset_n,
    vsync         => vsync,
    ds2_dat       => joystick_miso_i,
    ds2_cmd       => joystick_mosi,
    ds2_att       => joystick_cs_i,
    ds2_clk       => joystick_clk,
    ds2_ack       => '0',
    stick_lx      => paddle_1,
    stick_ly      => paddle_2,
    stick_rx      => paddle_3,
    stick_ry      => paddle_4,
    key_up        => open,
    key_down      => open,
    key_left      => open,
    key_right     => open,
    key_l1        => key_l1,
    key_l2        => key_l2,
    key_r1        => key_r1,
    key_r2        => key_r2,
    key_triangle  => key_triangle,
    key_square    => key_square,
    key_circle    => key_circle,
    key_cross     => key_cross,
    key_start     => open,
    key_select    => open,
    key_lstick    => open,
    key_rstick    => open,
    debug1        => open,
    debug2        => open
    );

led_ws2812: entity work.ws2812
  port map
  (
   clk    => clk32,
   color  => ws2812_color,
   data   => ws2812
  );

	process(clk32, disk_reset)
    variable reset_cnt : integer range 0 to 2147483647;
    begin
		if disk_reset = '1' then
      disk_chg_trg <= '0';
			reset_cnt := 64000000;
      elsif rising_edge(clk32) then
			if reset_cnt /= 0 then
				reset_cnt := reset_cnt - 1;
			end if;
		end if;

  if reset_cnt = 0 then
    disk_chg_trg <= '1';
  else 
    disk_chg_trg <= '0';
  end if;
end process;

disk_reset <= c1541_osd_reset or not reset_n or c1541_reset or not flash_lock;

-- rising edge sd_change triggers detection of new disk
process(clk32, pll_locked)
  begin
  if pll_locked = '0' then
    sd_change <= '0';
    disk_g64 <= '0';
    disk_g64_d <= '0';
    elsif rising_edge(clk32) then
      sd_img_mounted_d <= sd_img_mounted(0);
      disk_chg_trg_d <= disk_chg_trg;
      disk_g64_d <= disk_g64;

      if sd_img_mounted(0) = '1' then
        img_present <= '0' when sd_img_size = 0 else '1';
      end if;

      if sd_img_mounted_d = '0' and sd_img_mounted(0) = '1' then
        sd_img_size_d <= sd_img_size;
      else 
        sd_img_size_d <= (others => '0'); 
      end if;

      if (sd_img_mounted(0) /= sd_img_mounted_d) or (disk_chg_trg_d = '0' and disk_chg_trg = '1') then
          sd_change  <= '1';
          else
          sd_change  <= '0';
      if sd_img_size_d >= 333744 then  -- g64 disk selected
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
  end if;
end process;

c1541_sd_inst : entity work.c1541_sd
port map
 (
    clk32         => clk32,
    reset         => disk_reset,
    pause         => c64_pause or loader_busy,
    ce            => '0',

    disk_num      => (others =>'0'),
    disk_change   => sd_change, 
    disk_mount    => img_present,
    disk_readonly => system_floppy_wprot(0),
    disk_g64      => disk_g64,

    iec_atn_i     => iec_atn_o,
    iec_data_i    => iec_data_o,
    iec_clk_i     => iec_clk_o,

    iec_atn_o     => iec_atn_i,
    iec_data_o    => iec_data_i,
    iec_clk_o     => iec_clk_i,

    -- Userport parallel bus to 1541 disk
    par_data_i    => drive_par_i,
    par_stb_i     => drive_stb_i,
    par_data_o    => drive_par_o,
    par_stb_o     => drive_stb_o,

    sd_lba        => disk_lba,
    sd_rd         => c1541_sd_rd,
    sd_wr         => c1541_sd_wr,
    sd_ack        => sd_busy,

    sd_buff_addr  => sd_byte_index,
    sd_buff_dout  => sd_rd_data,
    sd_buff_din   => sd_wr_data,
    sd_buff_wr    => sd_rd_byte_strobe,

    led           => led1541,
    ext_en        => ext_en,
    c1541rom_cs   => c1541rom_cs,
    c1541rom_addr => c1541rom_addr,
    c1541rom_data => c1541rom_data
);

sd_lba <= loader_lba when loader_busy = '1' else loader_lba when img_present = '0' else disk_lba;
sd_rd(0) <= c1541_sd_rd when img_present = '1' else '0';
sd_wr(0) <= c1541_sd_wr when img_present = '1' else '0';
ext_en <= '1' when dos_sel(0) = '0' else '0'; -- dolphindos, speeddos
sdc_iack <= int_ack(3);

sd_card_inst: entity work.sd_card
generic map (
    CLK_DIV  => 1
  )
    port map (
    rstn            => pll_locked, 
    clk             => clk32,
  
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
    image_size      => sd_img_size,           -- length of image file
    image_mounted   => sd_img_mounted,

    -- user read sector command interface (sync with clk)
    rstart          => sd_rd,
    wstart          => sd_wr, 
    rsector         => sd_lba,
    rbusy           => sd_busy,
    rdone           => sd_done,           --  done from sd reader acknowledges/clears start

    -- sector data output interface (sync with clk)
    inbyte          => sd_wr_data,        -- sector data output interface (sync with clk)
    outen           => sd_rd_byte_strobe, -- when outen=1, a byte of sector content is read out from outbyte
    outaddr         => sd_byte_index,     -- outaddr from 0 to 511, because the sector size is 512
    outbyte         => sd_rd_data         -- a byte of sector content
);

freeze <= '0';

audio_div  <= to_unsigned(342,9) when ntscMode = '1' else to_unsigned(327,9);

cass_snd <= cass_read and not cass_run and  system_tape_sound   and not cass_finish;
audio_l <= audio_data_l or (5x"00" & cass_snd & 12x"00000");
audio_r <= audio_data_r or (5x"00" & cass_snd & 12x"00000");

video_inst: entity work.video 
port map(
      pll_lock     => pll_locked, 
      clk          => clk32,
      clk_pixel_x5 => clk_pixel_x5,
      audio_div    => audio_div,

      ntscmode  => ntscMode,
      hs_in_n   => hsync,
      vs_in_n   => vsync,

      r_in      => std_logic_vector(r(7 downto 4)),
      g_in      => std_logic_vector(g(7 downto 4)),
      b_in      => std_logic_vector(b(7 downto 4)),

      audio_l => audio_l,  -- interface C64 core specific
      audio_r => audio_r,
      osd_status => osd_status,

      mcu_start => mcu_start,
      mcu_osd_strobe => mcu_osd_strobe,
      mcu_data  => mcu_data_out,

      -- values that can be configure by the user via osd
      system_wide_screen => system_wide_screen,
      system_scanlines => system_scanlines,
      system_volume => system_volume,

      tmds_clk_n => tmds_clk_n,
      tmds_clk_p => tmds_clk_p,
      tmds_d_n   => tmds_d_n,
      tmds_d_p   => tmds_d_p
      );

addr <= io_cycle_addr when io_cycle ='1' else reu_ram_addr(22 downto 0) when ext_cycle = '1' else cart_addr;
cs <= io_cycle_ce when io_cycle ='1' else reu_ram_ce when ext_cycle = '1' else cart_ce; 
we <= io_cycle_we when io_cycle ='1' else reu_ram_we  when ext_cycle = '1' else cart_we;
din <= std_logic_vector(io_cycle_data) when io_cycle ='1' else std_logic_vector(reu_ram_dout) when ext_cycle = '1' else std_logic_vector(c64_data_out);
sdram_data <= unsigned(dout);

dram_inst: entity work.sdram8
   port map(
    -- SDRAM side interface
    sd_clk    => O_sdram_clk,   -- sd clock
    sd_cke    => O_sdram_cke,   -- clock enable
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
    reset_n   => pll_locked,    -- init signal after FPGA config to initialize RAM
    ready     => ram_ready,     -- ram is ready and has been initialized
    refresh   => idle,          -- chipset requests a refresh cycle
    din       => din,           -- data input from chipset/cpu
    dout      => dout,
    addr      => addr,          -- 23 bit word address
    ds        => "00",
    cs        => cs,            -- cpu/chipset requests read/wrie
    we        => we             -- cpu/chipset requests write
  );

-- Clock tree and all frequencies in Hz
-- pll         315000000 / 329400000
-- serdes      157500000 / 164700000
-- dram         63000000 /  65880000
-- core /pixel  31500000 /  32940000
-- IDIV_SEL              2 / 4
-- FBDIV_SEL            34 / 60

process(clk32)
begin
  if rising_edge(clk32) then
    ntscModeD <= ntscMode;
    IDSEL  <= "111101" when ntscModeD = '0' else "111011";
    FBDSEL <= "011101" when ntscModeD = '0' else "000011";
  end if;
end process;

mainclock: rPLL
        generic map (
            FCLKIN => "27",
            DEVICE => "GW2AR-18C",
            DYN_IDIV_SEL => "true",
            IDIV_SEL => 2,
            DYN_FBDIV_SEL => "true",
            FBDIV_SEL => 34,
            DYN_ODIV_SEL => "false",
            ODIV_SEL => 2,
            PSDA_SEL => "0110",   
            DYN_DA_EN => "false", 
            DUTYDA_SEL => "1000",
            CLKOUT_FT_DIR => '1',
            CLKOUTP_FT_DIR => '1',
            CLKOUT_DLY_STEP => 0,
            CLKOUTP_DLY_STEP => 0,
            CLKFB_SEL => "internal",
            CLKOUT_BYPASS => "false",
            CLKOUTP_BYPASS => "false",
            CLKOUTD_BYPASS => "false",
            DYN_SDIV_SEL => 2,
            CLKOUTD_SRC => "CLKOUT",
            CLKOUTD3_SRC => "CLKOUT"
        )
        port map (
            CLKOUT   => clk_pixel_x10,
            LOCK     => pll_locked,
            CLKOUTP  => open,
            CLKOUTD  => clk_pixel_x5,
            CLKOUTD3 => open,
            RESET    => '0',
            RESET_P  => '0',
            CLKIN    => clk,
            CLKFB    => '0',
            FBDSEL   => FBDSEL,
            IDSEL    => IDSEL,
            ODSEL    => (others => '0'),
            PSDA     => (others => '0'),
            DUTYDA   => (others => '0'),
            FDLY     => (others => '1')
        );

div1_inst: CLKDIV
generic map(
    DIV_MODE => "5",
    GSREN    => "false"
)
port map(
    CLKOUT => clk64,
    HCLKIN => clk_pixel_x10,
    RESETN => pll_locked,
    CALIB  => '0'
);

div2_inst: CLKDIV
generic map(
  DIV_MODE => "2",
  GSREN    => "false"
)
port map(
    CLKOUT => clk32,
    HCLKIN => clk64,
    RESETN => pll_locked,
    CALIB  => '0'
);

-- 64.125Mhz for flash controller c1541 ROM
flashclock: rPLL
        generic map (
          FCLKIN => "27",
          DEVICE => "GW2AR-18C",
          DYN_IDIV_SEL => "false",
          IDIV_SEL => 7,
          DYN_FBDIV_SEL => "false",
          FBDIV_SEL => 18,
          DYN_ODIV_SEL => "false",
          ODIV_SEL => 8,
          PSDA_SEL => "0110", -- phase shift 135°
          DYN_DA_EN => "false",
          DUTYDA_SEL => "1000",
          CLKOUT_FT_DIR => '1',
          CLKOUTP_FT_DIR => '1',
          CLKOUT_DLY_STEP => 0,
          CLKOUTP_DLY_STEP => 0,
          CLKFB_SEL => "internal",
          CLKOUT_BYPASS => "false",
          CLKOUTP_BYPASS => "false",
          CLKOUTD_BYPASS => "false",
          DYN_SDIV_SEL => 2,
          CLKOUTD_SRC => "CLKOUT",
          CLKOUTD3_SRC => "CLKOUT"
        )
        port map (
            CLKOUT   => flash_clk, -- clock Flash controller
            LOCK     => flash_lock,
            CLKOUTP  => mspi_clk, -- phase shifted clock SPI Flash
            CLKOUTD  => open,
            CLKOUTD3 => open,
            RESET    => '0',
            RESET_P  => '0',
            CLKIN    => clk,
            CLKFB    => '0',
            FBDSEL   => (others => '0'),
            IDSEL    => (others => '0'),
            ODSEL    => (others => '0'),
            PSDA     => (others => '0'),
            DUTYDA   => (others => '0'),
            FDLY     => (others => '1')
        );

leds_n <=  not leds;
leds(0) <= led1541;
joyDS2     <=    ("00" & (key_l1 or key_r1) & key_circle & key_square & key_cross & key_triangle);
--                       4  3  2  1  0 digital c64 
--                       TR RI LE DN UP
joyDigital <= not("11" & io(0) & io(3) & io(4) & io(1) & io(2));
joyUsb1    <=    ("00" & joystick1(4) & joystick1(0) & joystick1(1) & joystick1(2) & joystick1(3));
joyUsb2    <=    ("00" & joystick2(4) & joystick2(0) & joystick2(1) & joystick2(2) & joystick2(3));
joyNumpad  <=     "00" & numpad(4) & numpad(0) & numpad(1) & numpad(2) & numpad(3);
joyMouse   <=     "00" & mouse_btns(0) & "000" & mouse_btns(1);
joyPaddle  <=    ("00" & '0' & key_l1 & key_l2 & "00"); -- bound to physical paddle position DS2
joyPaddle2 <=    ("00" & '0' & key_r1 & key_r2 & "00");

-- send external DB9 joystick port to µC
db9_joy <= not('1' & io(0), io(2), io(1), io(4), io(3));

process(clk32)
begin
	if rising_edge(clk32) then
    case port_1_sel is
      when "000"  => joyA <= joyDigital;
      when "001"  => joyA <= joyUsb1;
      when "010"  => joyA <= joyUsb2;
      when "011"  => joyA <= joyNumpad;
      when "100"  => joyA <= joyDS2;
      when "101"  => joyA <= joyMouse;
      when "110"  => joyA <= joyPaddle;
      when "111"  => joyA <= (others => '0');
      when others => null;
    end case;
  end if;
end process;

process(clk32)
begin
	if rising_edge(clk32) then
    case port_2_sel is
      when "000"  => joyB <= joyDigital;
      when "001"  => joyB <= joyUsb1;
      when "010"  => joyB <= joyUsb2;
      when "011"  => joyB <= joyNumpad;
      when "100"  => joyB <= joyDS2;
      when "101"  => joyB <= joyMouse;
      when "110"  => joyB <= joyPaddle2;
      when "111"  => joyB <= (others => '0');
      when others => null;
      end case;
  end if;
end process;

-- paddle pins - mouse
pot1 <= not paddle_1 when port_1_sel = "110" else ('0' & std_logic_vector(mouse_x_pos(6 downto 1)) & '0');
pot2 <= not paddle_2 when port_1_sel = "110" else ('0' & std_logic_vector(mouse_y_pos(6 downto 1)) & '0');
pot3 <= not paddle_3 when port_2_sel = "110" else ('0' & std_logic_vector(mouse_x_pos(6 downto 1)) & '0');
pot4 <= not paddle_4 when port_2_sel = "110" else ('0' & std_logic_vector(mouse_y_pos(6 downto 1)) & '0');

process(clk32, reset_n)
 variable mov_x: signed(6 downto 0);
 variable mov_y: signed(6 downto 0);
begin
  if  reset_n = '0' then
    mouse_x_pos <= (others => '0');
    mouse_y_pos <= (others => '0');
  elsif rising_edge(clk32) then
    if mouse_strobe = '1' then
     -- due to limited resolution on the c64 side, limit the mouse movement speed
     if mouse_x > 40 then mov_x:="0101000"; elsif mouse_x < -40 then mov_x:= "1011000"; else mov_x := mouse_x(6 downto 0); end if;
     if mouse_y > 40 then mov_y:="0101000"; elsif mouse_y < -40 then mov_y:= "1011000"; else mov_y := mouse_y(6 downto 0); end if;
     mouse_x_pos <= mouse_x_pos - mov_x;
     mouse_y_pos <= mouse_y_pos + mov_y;
    end if;
  end if;
end process;

mcu_spi_inst: entity work.mcu_spi 
port map (
  clk            => clk32,
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
  clk             => clk32,
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
  joystick0       => joystick1,
  joystick1       => joystick2,
  numpad          => numpad,
  keyboard_matrix_out => keyboard_matrix_out,
  keyboard_matrix_in  => keyboard_matrix_in,
  key_restore     => freeze_key,
  tape_play       => open,
  mod_key         => open,
  mouse_btns      => mouse_btns,
  mouse_x         => mouse_x,
  mouse_y         => mouse_y,
  mouse_strobe    => mouse_strobe
 );

 module_inst: entity work.sysctrl 
 port map 
 (
  clk                 => clk32,
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
  system_wide_screen  => system_wide_screen,
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

  int_out_n           => m0s(4),
  int_in              => std_logic_vector(unsigned'(x"0" & sdc_int & "0" & hid_int & "0")),
  int_ack             => int_ack,

  buttons             => std_logic_vector(unsigned'(reset & user)), -- S0 and S1 buttons on Tang Nano 20k
  leds                => system_leds,         -- two leds can be controlled from the MCU
  color               => ws2812_color -- a 24bit color to e.g. be used to drive the ws2812
);

process(clk32)
variable toX:	integer;
begin
  if rising_edge(clk32) then
    c64_iec_clk_old   <= iec_clk_i;
    drive_iec_clk_old <= iec_clk_o;
    drive_stb_i_old   <= drive_stb_i;
    drive_stb_o_old   <= drive_stb_o;
    if c64_iec_clk_old /= iec_clk_i
      or drive_iec_clk_old /= iec_clk_o
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

uart_en <= '1' when ((system_up9600(2) = '1' or system_up9600(1) = '1') 
                  and (sid_mode = 0 or sid_mode = 2)) else '0';  -- D400 or D420
uart_oe <= not ram_we and uart_cs and uart_en;
io_data <=  unsigned(cart_data) when cart_oe = '1' else
            unsigned(midi_data) when midi_oe = '1' else
            uart_data when uart_oe = '1' else
            unsigned(reu_dout);

c64rom_wr <= load_rom and ioctl_download and ioctl_wr when ioctl_addr(16 downto 14) = "000" else '0';

-- Example filter curves:
-- Follin-style: fc_curve(x, 240, -785)
-- Galway-style: fc_curve(x, 280, -405)
-- Average     : fc_curve(x, 250,    0)  default
-- Strong      : fc_curve(x, 260, +400)
-- Extreme     : fc_curve(x, 200, +760)
process(clk32)
begin
  if rising_edge(clk32) then
  case sid_filter is
    when 3x"0" =>
    -- Follin-style: fc_curve(x, 240, -785)
    sid_fc_lr <= std_logic_vector(to_signed(-785, sid_fc_lr'length)); --  Final FC register offset for curve shifting
    sid_fc_base_lr <= std_logic_vector(to_unsigned(240, sid_fc_base_lr'length)); -- Base cutoff frequency in Hz    

    when 3x"1" =>
    -- Galway-style: fc_curve(x, 280, -405)
    sid_fc_lr <= std_logic_vector(to_signed(-405, sid_fc_lr'length)); --  Final FC register offset for curve shifting
    sid_fc_base_lr <= std_logic_vector(to_unsigned(280, sid_fc_base_lr'length)); -- Base cutoff frequency in Hz    

    -- Average     : fc_curve(x, 250,    0)  default
    when 3x"2" =>
      sid_fc_lr <= std_logic_vector(to_signed(0, sid_fc_lr'length)); --  Final FC register offset for curve shifting
      sid_fc_base_lr <= std_logic_vector(to_unsigned(250, sid_fc_base_lr'length)); -- Base cutoff frequency in Hz    

    when 3x"3" =>
    -- Strong      : fc_curve(x, 260, +400)
    sid_fc_lr <= std_logic_vector(to_signed(400, sid_fc_lr'length)); --  Final FC register offset for curve shifting
    sid_fc_base_lr <= std_logic_vector(to_unsigned(260, sid_fc_base_lr'length)); -- Base cutoff frequency in Hz    

    when 3x"4" =>
    -- Extreme     : fc_curve(x, 200, +760)
    sid_fc_lr <= std_logic_vector(to_signed(760, sid_fc_lr'length)); --  Final FC register offset for curve shifting
    sid_fc_base_lr <= std_logic_vector(to_unsigned(200, sid_fc_base_lr'length)); -- Base cutoff frequency in Hz    

    when others => 
    -- Average default
    sid_fc_lr <= std_logic_vector(to_signed(0, sid_fc_lr'length)); --  Final FC register offset for curve shifting
    sid_fc_base_lr <= std_logic_vector(to_unsigned(250, sid_fc_base_lr'length)); -- Base cutoff frequency in Hz    
    end case;
  end if;
end process;

fpga64_sid_iec_inst: entity work.fpga64_sid_iec
  generic map (
    DUAL =>  DUAL   -- 0:no, 1:yes  Dual SID component build
  )
  port map
  (
  clk32        => clk32,
  reset_n      => reset_n and pll_locked and ram_ready,
  bios         => "00",
  pause        => freeze,
  pause_out    => c64_pause,
  -- keyboard interface
  keyboard_matrix_out => keyboard_matrix_out,
  keyboard_matrix_in  => keyboard_matrix_in,
  kbd_reset    => '0',
  shift_mod    => (others => '0'),

  -- external memory
  ramAddr      => c64_addr,
  ramDin       => sdram_data,
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
  r            => r,
  g            => g,
  b            => b,
  debugX       => open,
	debugY       => open,

  phi          => phi,
  phi2_p       => phi2_p, -- Phi 2 positive edge
  phi2_n       => phi2_n, -- Phi 2 negative edge

  game         => game,
  exrom        => exrom,
  io_rom       => io_rom,
  io_ext       => (reu_oe or cart_oe or midi_oe or uart_oe),
  io_data      => io_data,
  irq_n        => midi_irq_n,
  nmi_n        => (not nmi and midi_nmi_n and not (uart_irq and uart_en)),
  nmi_ack      => nmi_ack,
  romL         => romL,
  romH         => romH,
  UMAXromH     => UMAXromH,
  IO7          => IO7,
  IOE          => IOE,
  IOF          => IOF,
  freeze_key   => open,
  mod_key      => open,
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
  joyA         => joyA,
  joyB         => joyB,
  pot1         => pot1,
  pot2         => pot2,
  pot3         => pot3,
  pot4         => pot4,

  --SID
  audio_l      => audio_data_l,
  audio_r      => audio_data_r,
  sid_ver      => sid_ver & sid_ver,
  sid_mode     => sid_mode,
  sid_fc_off_l => sid_fc_lr,
  sid_fc_off_r => sid_fc_lr,
  sid_ld_clk   => clk32,
  sid_ld_addr  => sid_ld_addr,
  sid_ld_data  => sid_ld_data,
  sid_ld_wr    => sid_ld_wr,
  sid_digifix  => sid_digifix,
  sid_fc_base_r => sid_fc_base_lr,
  sid_fc_base_l => sid_fc_base_lr,

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
  iec_data_o   => iec_data_o,
  iec_data_i   => iec_data_i,
  iec_clk_o    => iec_clk_o,
  iec_clk_i    => iec_clk_i,
  iec_atn_o    => iec_atn_o,

  c64rom_addr  => ioctl_addr(13 downto 0),
  c64rom_data  => ioctl_data,
  c64rom_wr    => c64rom_wr,

  cass_motor   => cass_motor,
  cass_write   => cass_write,
  cass_sense   => cass_sense,
  cass_read    => cass_read
  );

process(clk32)
begin
  if rising_edge(clk32) then
    ext_cycle_d <= ext_cycle;
  end if;
end process;

reu_oe  <= IOF and reu_cfg;
reu_ram_ce <= not ext_cycle_d and ext_cycle and dma_req;

reu_inst: entity work.reu
port map(
    clk       => clk32,
    reset     => not reset_n,
    cfg       => std_logic_vector(unsigned'( '0' & reu_cfg) ),
  
    dma_req   => dma_req,
    dma_cycle => dma_cycle,
    dma_addr  => dma_addr,
    dma_dout  => dma_dout,
    dma_din   => dma_din,
    dma_we    => dma_we,
  
    ram_cycle => ext_cycle,
    ram_addr  => reu_ram_addr,
    ram_dout  => reu_ram_dout,
    ram_din   => dout,
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
-- phase shift 135° TN, TP and 270° TM
-- offset in spi flash TN20K, TP25K $200000, TM138K $A00000
flash_inst: entity work.flash 
port map(
    clk       => flash_clk,
    resetn    => flash_lock,
    ready     => open,
    busy      => open,
    address   => ("0010" & "000" & dos_sel & c1541rom_addr),
    cs        => c1541rom_cs,
    dout      => c1541rom_data,
    mspi_cs   => mspi_cs,
    mspi_di   => mspi_di,
    mspi_hold => mspi_hold,
    mspi_wp   => mspi_wp,
    mspi_do   => mspi_do
);

cid <= cart_id when cart_attached = '1' else X"0099" when georam ='1' else X"00FF";

cartridge_inst: entity work.cartridge
port map
  (
    clk32       => clk32,
    reset_n     => reset_n,
  
    cart_loading    => ioctl_download and load_crt,
    cart_id         => cid,
    cart_exrom      => cart_exrom,
    cart_game       => cart_game,
    cart_bank_laddr => cart_bank_laddr,
    cart_bank_size  => cart_bank_size,
    cart_bank_num   => cart_bank_num,
    cart_bank_type  => cart_bank_type,
    cart_bank_raddr => ioctl_load_addr,
    cart_bank_wr    => cart_hdr_wr,
  
    exrom       => exrom,
    game        => game,
  
    romL        => romL,
    romH        => romH,
    UMAXromH    => UMAXromH,
    IOE         => IOE,
    IOF         => IOF,
    mem_write   => ram_we,
    mem_ce      => ram_ce,
    mem_ce_out  => cart_ce,
    mem_write_out => cart_we,
    IO_rom      => io_rom,
    IO_rd       => cart_oe,
    IO_data     => cart_data,
    addr_in     => c64_addr,
    data_in     => c64_data_out,
    addr_out    => cart_addr,

    freeze_key  => freeze_key,
    mod_key     => '0',
    nmi         => nmi,
    nmi_ack     => nmi_ack
  );

  midi_inst : entity work.c64_midi
  port map (
    clk32   => clk32,
    reset   => not reset_n or not (st_midi(2) or st_midi(1) or st_midi(0)),
    Mode    => st_midi,
    E       => phi,
    IOE     => IOE,
    A       => std_logic_vector(c64_addr),
    Din     => std_logic_vector(c64_data_out),
    Dout    => midi_data,
    OE      => midi_oe,
    RnW     => not (ram_we and IOE),
    nIRQ    => midi_irq_n,
    nNMI    => midi_nmi_n,
 
    RX      => midi_rx,
    TX      => midi_tx
  );

crt_inst : entity work.loader_sd_card
port map (
  clk               => clk32,
  system_reset      => system_reset,

  sd_lba            => loader_lba,
  sd_rd             => sd_rd(5 downto 1),
  sd_wr             => sd_wr(5 downto 1),
  sd_busy           => sd_busy,
  sd_done           => sd_done,

  sd_byte_index     => sd_byte_index,
  sd_rd_data        => sd_rd_data,
  sd_rd_byte_strobe => sd_rd_byte_strobe,

  sd_img_mounted    => sd_img_mounted,
  loader_busy       => loader_busy,
  load_crt          => load_crt,
  load_prg          => load_prg,
  load_rom          => load_rom,
  load_tap          => load_tap,
  load_flt          => load_flt,
  sd_img_size       => sd_img_size,
  leds              => leds(5 downto 1),
  img_select        => img_select,

  ioctl_download    => ioctl_download,
  ioctl_addr        => ioctl_addr,
  ioctl_data        => ioctl_data,
  ioctl_wr          => ioctl_wr,
  ioctl_wait        => ioctl_req_wr or reset_wait
);

-- spi loader
process(clk32)
begin
  if rising_edge(clk32) then
    old_download <= ioctl_download;
    io_cycleD <= io_cycle;
    cart_hdr_wr <= '0';

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
      end if;

    if io_cycle = '1' and io_cycleD = '1' then
      io_cycle_ce <= '0';
      io_cycle_we <= '0';
    end if;

    if ioctl_wr = '1' then
      if load_prg = '1' then
        -- PRG header
        -- Load address low-byte
          if ioctl_addr = 0 then
              ioctl_load_addr(7 downto 0) <= ioctl_data;
              inj_end(7 downto 0)  <= ioctl_data; 
          -- Load address high-byte
          elsif ioctl_addr = 1 then
              ioctl_load_addr(22 downto 8) <= 7x"00" & ioctl_data;
              inj_end(15 downto 8) <= ioctl_data;
          else
              ioctl_req_wr <= '1';
              inj_end <= inj_end + 1;
          end if;
      end if;

      if load_tap = '1' then
        if ioctl_addr = 0  then ioctl_load_addr <= TAP_ADDR; end if;
        if ioctl_addr = 12 then tap_version <= ioctl_data(1 downto 0); end if;
        ioctl_req_wr <= '1';
      end if;

      if load_crt = '1' then
        if ioctl_addr = 0 then
          ioctl_load_addr <= CRT_MEM_START;
          cart_blk_len <= (others => '0');
          cart_hdr_cnt <= (others => '0');
        end if;

        if(ioctl_addr = x"16") then cart_id(15 downto 8) <= ioctl_data; end if;
        if(ioctl_addr = x"17") then cart_id(7 downto 0) <= ioctl_data; end if;
        if(ioctl_addr = x"18") then cart_exrom <= ioctl_data; end if;
        if(ioctl_addr = x"19") then cart_game <= ioctl_data; end if;

        if(ioctl_addr >= x"40") then
          if cart_blk_len = 0 and cart_hdr_cnt = 0 then
            cart_hdr_cnt <= x"1";
            if ioctl_load_addr(12 downto 0) /= 0 then
              -- align to 8KB boundary
              ioctl_load_addr(12 downto 0) <= (others => '0');
              ioctl_load_addr(22 downto 13) <= ioctl_load_addr(22 downto 13) + 1;
            end if;
            elsif cart_hdr_cnt /= 0 then
              cart_hdr_cnt <= cart_hdr_cnt + 1;
              if(cart_hdr_cnt = 4)  then cart_blk_len(31 downto 24)  <= ioctl_data; end if;
              if(cart_hdr_cnt = 5)  then cart_blk_len(23 downto 16)  <= ioctl_data; end if;
              if(cart_hdr_cnt = 6)  then cart_blk_len(15 downto 8)   <= ioctl_data; end if;
              if(cart_hdr_cnt = 7)  then cart_blk_len(7 downto 0)    <= ioctl_data; end if;
              if(cart_hdr_cnt = 8)  then cart_blk_len <= cart_blk_len - X"10"; end if;
              if(cart_hdr_cnt = 9)  then cart_bank_type <= ioctl_data; end if;
              if(cart_hdr_cnt = 10) then cart_bank_num(15 downto 8)  <= ioctl_data; end if;
              if(cart_hdr_cnt = 11) then cart_bank_num(7 downto 0)   <= ioctl_data; end if;
              if(cart_hdr_cnt = 12) then cart_bank_laddr(15 downto 8)<= ioctl_data; end if;
              if(cart_hdr_cnt = 13) then cart_bank_laddr(7 downto 0) <= ioctl_data; end if;
              if(cart_hdr_cnt = 14) then cart_bank_size(15 downto 8) <= ioctl_data; end if;
              if(cart_hdr_cnt = 15) then cart_bank_size(7 downto 0)  <= ioctl_data; end if;
              if(cart_hdr_cnt = 15) then cart_hdr_wr <= '1'; end if;
        else
              cart_blk_len <= cart_blk_len - 1;
              ioctl_req_wr <= '1';
              end if;
       end if;
     end if;
  end if;

      -- cart added
      if old_download /= ioctl_download and load_crt = '1' then
        cart_attached <= old_download;
        erase_cram <= '1';
      end if;

     -- meminit for RAM injection
        if old_download /= ioctl_download and load_prg = '1' and inj_meminit = '0' then
          inj_meminit <= '1';
          ioctl_load_addr <= (others => '0');
        end if;

        if inj_meminit = '1' and ioctl_req_wr = '0' then
                -- finish at $100
                if ioctl_load_addr(15 downto 0) = x"0100" then 
                    inj_meminit <= '0'; 
                end if;
               -- Initialize BASIC pointers to simulate the BASIC LOAD command
               case ioctl_load_addr(7 downto 0) is
                -- TXT (2B-2C)
                -- Set these two bytes to $01, $08 just as they would be on reset (the BASIC LOAD command does not alter these)
                when x"2b" => inj_meminit_data <= X"01";ioctl_req_wr <= '1';
                when x"2c" => inj_meminit_data <= X"08";ioctl_req_wr <= '1';
                -- SAVE_START (AC-AD)
                -- Set these two bytes to zero just as they would be on reset (the BASIC LOAD command does not alter these)
                when x"ac"|x"ad" => inj_meminit_data <= X"00";ioctl_req_wr <= '1';
                -- VAR (2D-2E), ARY (2F-30), STR (31-32), LOAD_END (AE-AF)
                -- Set these just as they would be with the BASIC LOAD command (essentially they are all set to the load end address)
                when x"2d"|x"2f"|x"31"|x"ae" => inj_meminit_data <= inj_end(7 downto 0);ioctl_req_wr <= '1';
                when x"2e"|x"30"|x"32"|x"af" => inj_meminit_data <= inj_end(15 downto 8);ioctl_req_wr <= '1';
                  -- advance the address
                when others => ioctl_load_addr <= ioctl_load_addr + 1;
             end case;
        end if;

      old_meminit <= inj_meminit;

      if  system_reset(1) = '1' then
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

por <= system_reset(0) or not pll_locked;

process(clk32, por)
variable reset_counter : integer;
  begin
    if por = '1' then
          reset_counter := 100000;
          do_erase <= '1';
          reset_n <= '0';
          reset_wait <= '0';
          force_erase <= '0';
       elsif rising_edge(clk32) then
        if reset_counter = 0 then reset_n <= '1'; else reset_n <= '0'; end if;
        old_download_r <= ioctl_download;
        if old_download_r = '0' and ioctl_download = '1' and load_prg = '1' then
          do_erase <= '1';
          reset_wait <= '1';
          reset_counter := 255;
        elsif ioctl_download = '1' and (load_crt = '1' or load_rom = '1') then
          do_erase <= '1';
          reset_counter := 255;
        elsif erasing = '1' then force_erase <= '0';
        elsif reset_counter = 0 then
          do_erase <= '0';
          if reset_wait = '1' and c64_addr = X"FFCF" then reset_wait <= '0'; end if;
        else
          reset_counter := reset_counter - 1;
          if reset_counter = 100 and do_erase = '1' then force_erase <= '1'; end if;
      end if;
    end if;
end process;

process(clk32)
begin
  if rising_edge(clk32) then
    sid_ld_wr <= '0';
    if ioctl_wr = '1' and load_flt = '1' and ioctl_addr < std_logic_vector(to_unsigned(6144, ioctl_addr'length)) then
        if ioctl_addr(0) = '1' then
          sid_ld_data(15 downto 8) <= ioctl_data;
          sid_ld_addr <= ioctl_addr(12 downto 1);
          sid_ld_wr <= '1';
        else
          sid_ld_data(7 downto 0) <= ioctl_data;
        end if;
    end if;
	end if;
end process;

--------------- TAP -------------------

tap_download <= ioctl_download and load_tap;
tap_reset <= '1' when reset_n = '0' or tap_download = '1'or tap_last_addr = 0 or cass_finish = '1' or (cass_run = '1'and ((unsigned(tap_last_addr) - unsigned(tap_play_addr)) < 80)) else '0';
tap_loaded <= '1' when tap_play_addr < tap_last_addr else '0';

process(clk32)
begin
  if rising_edge(clk32) then
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
        if io_cycle = '0' and io_cycle_rD = '1' and tap_wrfull = '0' and tap_loaded = '1' then
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
  clk32           => clk32,
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

	-- UART_RX synchronizer
	process(clk32)
	begin
		if rising_edge(clk32) then
			uart_rxD <= uart_rxD(2 downto 0) & uart_rx;
			if uart_rxD = "0000" then uart_rx_filtered <= '0'; end if;
			if uart_rxD = "1111" then uart_rx_filtered <= '1'; end if;
		end if;
	end process;

-- connect user port
process (all)
begin
  pa2_i <= pa2_o;
  cnt2_i <= '1';
  sp2_i <= '1';
  pb_i <= pb_o;
  drive_par_i <= (others => '1');
  drive_stb_i <= '1';
  uart_tx <= '1';
  flag2_n_i <= '1';
  uart_cs <= '0';
  if ext_en = '1' and disk_access = '1' then
   -- c1541 parallel bus
   drive_par_i <= pb_o;
   drive_stb_i <= pc2_n_o;
   pb_i <= drive_par_o;
   flag2_n_i <= drive_stb_o;
 elsif system_up9600 = 0 then
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
   uart_tx <= pa2_o;
   flag2_n_i <= uart_rx_filtered;
   pb_i(0) <= uart_rx_filtered;
   -- Zeromodem
   --pb_i(6) <= pb_o(1);  -- RTS > CTS
   --pb_i(4) <= pb_o(2);  -- DTR > DCD
   --pb_i(7) <= pb_o(2);  -- DTR > DSR
   elsif system_up9600 = 1 then 
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
   uart_tx <= pa2_o and sp1_o;
   sp2_i <= uart_rx_filtered;
   flag2_n_i <= uart_rx_filtered;
   pb_i(0) <= uart_rx_filtered;
   -- Zeromodem
   --pb_i(6) <= pb_o(1);  -- RTS > CTS
   --pb_i(4) <= pb_o(2);  -- DTR > DCD
  elsif system_up9600 = 2 then
    uart_tx <= tx_6551;
    uart_cs <= IOE;
  elsif system_up9600 = 3 then
    uart_tx <= tx_6551;
    uart_cs <= IOF;
  elsif system_up9600 = 4 then
    uart_tx <= tx_6551;
    uart_cs <= IO7;
  end if;
end process;

-- | SwiftLink       $DE00/$DF00/$D700/NMI (300-38400 baud)
-- | Turbo-232 only: $DE07/56839/TURBO232+7  Enhanced-Speed Register
-- https://gglabs.us/node/2057
uart_inst : entity work.glb6551
port map (
  RESET_N     => reset_n,
  CLK         => clk32,
  RX_CLK      => open,
  RX_CLK_IN   => CLK_6551_EN,
  XTAL_CLK_IN => CLK_6551_EN,
  PH_2        => '1',
  DI          => c64_data_out,
  DO          => uart_data,
  IRQ         => uart_irq,
  CS          => unsigned'( not uart_en & uart_cs ),
  RW_N        => not (ram_we and uart_cs),
  RS          => c64_addr(1 downto 0),
  TXDATA_OUT  => tx_6551,
  RXDATA_IN   => uart_rx,
  RTS         => open,
  CTS         => '1',
  DCD         => '1',
  DTR         => open,
  DSR         => '1'
  );

--  3.686.400Hz clock enable derived from 315 Mhz clock
baudgen_inst: entity work.BaudRate
 GENERIC map(
  BAUD_RATE	=> 230400
 )
 port map(
   i_CLOCK	=> clk_pixel_x10,
   o_serialEn	=> CLK_6551_EN
);

end Behavioral_top;
