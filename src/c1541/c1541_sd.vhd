---------------------------------------------------------------------------------
-- Commodore 1541 to SD card (read/write) by Dar (darfpga@aol.fr) 24-May-2017
-- http://darfpga.blogspot.fr
--
-- c1541_sd reads D64 data from raw SD card, produces GCR data, feeds c1541_logic
-- Raw SD data : each D64 image must start on 256KB boundaries
-- disk_num allow to select D64 image
--
-- c1541_logic    from : Mark McDougall
-- spi_controller from : Michel Stempin, Stephen A. Edwards
-- via6522        from : Gideon Zweijtzer  <gideon.zweijtzer@gmail.com>
-- T65            from : Daniel Wallner, MikeJ, ehenciak
--
-- c1541_logic    modified for  : remove iec internal OR wired
-- spi_controller replaced with mist_sd_card
-- via6522        modified for : no modification
--
--
-- Input clk 32MHz and 18MHz (18MHz could be replaced with 32/2 if needed)
--     
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity c1541_sd is
port(
	clk32 : in std_logic;
	reset : in std_logic;
    pause : in std_logic;
    ce    : in std_logic;

	
	disk_num : in std_logic_vector(9 downto 0);
	disk_change : in std_logic;
	disk_mount  : in std_logic := '1';
	disk_readonly : in std_logic;
	disk_g64    : in std_logic := '0';

	iec_atn_i  : in std_logic;
	iec_data_i : in std_logic;
	iec_clk_i  : in std_logic;
	
	iec_data_o : out std_logic;
	iec_clk_o  : out std_logic;
	
	sd_lba         : out std_logic_vector(31 downto 0);
	sd_rd          : out std_logic;
	sd_wr          : out std_logic;
	sd_ack         : in  std_logic;

	sd_buff_addr   : in  std_logic_vector(8 downto 0);
	sd_buff_dout   : in  std_logic_vector(7 downto 0);
	sd_buff_din    : out std_logic_vector(7 downto 0);
	sd_buff_wr     : in std_logic;

	led            : out std_logic;

    -- parallel bus
    par_data_i     : in std_logic_vector(7 downto 0);
    par_stb_i      : in std_logic;
    par_data_o     : out std_logic_vector(7 downto 0);
    par_stb_o      : out std_logic;

    ext_en          : in std_logic;
    c1541rom_addr   : out std_logic_vector(14 downto 0);
    c1541rom_data   : in std_logic_vector(7 downto 0);
    c1541rom_cs     : out std_logic
);
end c1541_sd;

architecture struct of c1541_sd is

signal floppy_ram_addr : std_logic_vector(12 downto 0);
signal floppy_ram_di   : std_logic_vector( 7 downto 0);
signal floppy_ram_do   : std_logic_vector( 7 downto 0);
signal floppy_ram_we   : std_logic;

signal c1541_logic_din   : std_logic_vector(7 downto 0); -- data read
signal c1541_logic_dout  : std_logic_vector(7 downto 0); -- data to write
signal mode   : std_logic;                    -- read/write
signal mode_r : std_logic;                    -- read/write
signal stp    : std_logic_vector(1 downto 0); -- stepper motor control
signal stp_r  : std_logic_vector(1 downto 0); -- stepper motor control
signal mtr    : std_logic ;                   -- stepper motor on/off
signal freq   : std_logic_vector(1 downto 0); -- motor (gcr_bit) frequency
signal sync_n : std_logic;                    -- reading SYNC bytes
signal byte_n : std_logic;                    -- byte ready
signal act    : std_logic;                    -- activity LED
signal act_r  : std_logic;                    -- activity LED

signal track_num_dbl     : std_logic_vector(6 downto 0);
signal new_track_num_dbl : std_logic_vector(6 downto 0);
signal sd_busy           : std_logic;

signal save_track      : std_logic;
signal track_modified   : std_logic;
signal save_track_stage : std_logic_vector(3 downto 0);
signal id1 : std_logic_vector(7 downto 0);
signal id2 : std_logic_vector(7 downto 0);
signal disk_freq : std_logic_vector(1 downto 0);
signal raw_disk : std_logic;
signal raw_track_len : std_logic_vector(15 downto 0);
signal max_track : std_logic_vector(6 downto 0);
signal wps_flag : std_logic;
signal change_timer : integer;
signal mounted : std_logic := '0';
signal tr00_sense_n : std_logic;

begin
	
tr00_sense_n <='0' when new_track_num_dbl = 7x"00" else '1';

  c1541 : entity work.c1541_logic
  generic map
  (
    DEVICE_SELECT => "00"
  )
  port map
  (
    clk_32M => clk32,
    reset => reset,
    pause => pause,
    ce    => ce,

    -- serial bus
    sb_data_oe => iec_data_o,
    sb_clk_oe  => iec_clk_o,
		
    sb_data_in => iec_data_i,
    sb_clk_in  => iec_clk_i,
    sb_atn_in  => iec_atn_i,
    -- parallel bus
    par_data_i => par_data_i,
    par_stb_i  => par_stb_i,
    par_data_o => par_data_o,
    par_stb_o  => par_stb_o,

	-- drive-side interface
    ds              => "00",     -- device select
    di              => c1541_logic_din,  -- data read 
    do              => c1541_logic_dout, -- data to write
    mode            => mode,     -- read/write
    stp             => stp,      -- stepper motor control
    mtr             => mtr,      -- motor on/off
    freq            => freq,     -- motor frequency
    sync_n          => sync_n,   -- reading SYNC bytes
    byte_n          => byte_n,   -- byte ready
    wps_n           => not wps_flag,      -- write-protect sense (0 = protected)
    tr00_sense_n    => tr00_sense_n, -- track 0 sense
    act             => act,      -- activity LED

    ext_en          => ext_en,
    c1541rom_addr   => c1541rom_addr,
    c1541rom_data   => c1541rom_data,
    c1541rom_cs     => c1541rom_cs
  );

floppy : entity work.gcr_floppy
port map
(
	clk32  => clk32,

	c1541_logic_din  => c1541_logic_din,  -- data read
	c1541_logic_dout => c1541_logic_dout, -- data to write
	 
	mode   => mode,   -- read/write
	mtr    => mtr,    -- stepper motor on/off
	freq   => freq,   -- motor (gcr_bit) frequency
	sync_n => sync_n, -- reading SYNC bytes
	byte_n => byte_n, -- byte ready

	track_num  => new_track_num_dbl(6 downto 1),
	id1        => id1,
	id2        => id2,
	mounted    => mounted,
	raw        => raw_disk,
	raw_freq   => disk_freq,
	raw_track_len => raw_track_len,

	ram_addr   => floppy_ram_addr,
	ram_do     => floppy_ram_do,
	ram_di     => floppy_ram_di,
	ram_we     => floppy_ram_we,
	ram_ready  => not sd_busy,
		
	dbg_sector  => open
);

sd: entity work.mist_sd_card
port map
(
	clk           => clk32,
	reset         => reset,

	ram_addr      => floppy_ram_addr,
	ram_di        => floppy_ram_di,
	ram_do        => floppy_ram_do,
	ram_we        => floppy_ram_we,

	track         => new_track_num_dbl(6 downto 0),
	busy          => sd_busy,
	save_track    => save_track,
	id1           => id1,
	id2           => id2,
	freq          => disk_freq,
	raw           => raw_disk,
	raw_track_len => raw_track_len,
	change        => disk_change,
	mount         => disk_mount,
	g64           => disk_g64,
	max_track     => max_track,

	sd_buff_addr  => sd_buff_addr,
	sd_buff_dout  => sd_buff_dout,
	sd_buff_din   => sd_buff_din,
	sd_buff_wr    => sd_buff_wr,

	sd_lba        => sd_lba,
	sd_rd         => sd_rd,
	sd_wr         => sd_wr,
	sd_ack        => sd_ack
);

--sd_spi : entity work.spi_controller
--port map
--(
--	cs_n => sd_cs_n,  --: out std_logic; -- MMC chip select
--	mosi => sd_mosi,  --: out std_logic; -- Data to card (master out slave in)
--	miso => sd_miso,  --: in  std_logic; -- Data from card (master in slave out)
--	sclk => sd_sclk,  --: out std_logic; -- Card clock
--	bus_available => bus_available,
--
--	ram_addr => spi_ram_addr, -- out unsigned(13 downto 0);
--	ram_di   => spi_ram_di,   -- out unsigned(7 downto 0);
--	ram_do   => ram_do,       -- in  unsigned(7 downto 0);
--	ram_we   => spi_ram_we,
--		
--	track_num     => new_track_num_dbl(6 downto 1),
--	disk_num      => disk_num,
--	busy          => sd_busy,
--	save_track    => save_track,
--	sector_offset => sector_offset,
--
--	clk => clk_spi_ctrlr,
--	reset => reset,
--
--	dbg_state => dbg_sd_state
--);

wps_flag <= disk_readonly when change_timer = 0 else not disk_readonly;

process (clk32,reset)
begin
	if reset = '1' then
		change_timer <= 0;
	elsif rising_edge(clk32) then
		if disk_change = '1' then
			mounted <= disk_mount;
			change_timer <= 1000000;
		elsif change_timer /= 0 then
			change_timer <= change_timer - 1;
		end if;
	end if;
end process;

process (clk32)
begin
	if rising_edge(clk32) then
		stp_r <= stp;
		act_r <= act;
		mode_r <= mode;
		if reset = '1' then
			track_num_dbl <= "0100100";--"0000010";
			track_modified <= '0';
			save_track_stage <= X"0";
		else
			if mtr = '1' then
				if(  (stp_r = "00" and stp = "10")
					or (stp_r = "10" and stp = "01")
					or (stp_r = "01" and stp = "11")
					or (stp_r = "11" and stp = "00")) then
						if track_num_dbl < max_track then
							track_num_dbl <= track_num_dbl + '1';
							if track_modified = '1' then
								if save_track_stage = X"0" then
									save_track_stage <= X"1";
								end if;	
							else
								new_track_num_dbl <= track_num_dbl + '1';
							end if;	
						end if;
				end if;
				
				if(  (stp_r = "00" and stp = "11")
					or (stp_r = "10" and stp = "00")
					or (stp_r = "01" and stp = "10")
					or (stp_r = "11" and stp = "01")) then 
						if track_num_dbl > "0000010" then
							track_num_dbl <= track_num_dbl - '1';
							if track_modified = '1' then
								if save_track_stage = X"0" then
									save_track_stage <= X"1";
								end if;	
							else
								new_track_num_dbl <= track_num_dbl - '1';
							end if;	
						end if;
				end if;
				
				if mode_r = '0' and mode = '1' then -- leaving write mode
				  track_modified <= '1';
				end if;
			end if;		
			
			if act = '0' and act_r = '1' then -- stopping activity
				if track_modified = '1' and save_track_stage = X"0" then
					save_track_stage <= X"1";
				end if;	
			end if;
				
			-- save track state machine
			case save_track_stage is
			when X"0" => 
				new_track_num_dbl <= track_num_dbl;
			when X"1" =>
				save_track <= '1';
				if sd_busy = '1' then
					save_track_stage <= X"2";
				end if;
			when X"2" =>
					save_track_stage <= X"3";
			when X"3" =>
					save_track_stage <= X"4";
			when X"4" =>
				save_track <= '0'; -- must released save_track for spi_controler				
				if sd_busy = '0' then 
					save_track_stage <= X"5";
				end if;
			when X"5" =>
				track_modified <= '0';
				save_track_stage <= X"0";	
			when others => 
				save_track_stage <= X"0";						
			end case;
			
		end if; -- reset
	end if;  -- rising edge clock
end process;


led <= act;

end struct;
