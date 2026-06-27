---------------------------------------------------------------------------------
-- Commodore 1541 gcr floppy (read/write) by Dar (darfpga@aol.fr) 23-May-2017
-- http://darfpga.blogspot.fr
--
-- produces GCR data, byte(ready) and sync signal to feed c1541_logic from current
-- track buffer ram which contains D64 data
--
-- gets GCR data from c1541_logic, while producing byte(ready) signal. Data feed 
-- track buffer ram after conversion
--
-- Input clk 32MHz
--     
-- 2026 Stefan Voss: DolphinDos write fixed based on work done by mateusz nalewajski
-- (DD verifies the GCR bitstream for a sector rather than the decoded bytes)
--  VHDL 2008 cleanup
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity gcr_floppy is
port(
	clk32  : in  std_logic;
	c1541_logic_din  : out std_logic_vector(7 downto 0);   -- data from ram to 1541 logic
	c1541_logic_dout : in  std_logic_vector(7 downto 0);   -- data from 1541 logic to ram 
	mode   : in  std_logic;                      -- read/write
	mtr    : in  std_logic;                      -- stepper motor on/off
	freq   : in  std_logic_vector(1 downto 0);   -- motor (gcr_bit) frequency
	sync_n : out std_logic;                      -- reading SYNC bytes
	byte_n : out std_logic;                      -- byte ready
	
	track_num   : in  std_logic_vector(5 downto 0);
	id1         : in  std_logic_vector(7 downto 0);
	id2         : in  std_logic_vector(7 downto 0);
	raw_freq    : in  std_logic_vector(1 downto 0);
	mounted     : in  std_logic;
	raw         : in  std_logic;
	raw_track_len : in  std_logic_vector(15 downto 0);

	ram_addr    : out std_logic_vector(12 downto 0);
	ram_do      : in  std_logic_vector(7 downto 0);
	ram_di      : out std_logic_vector(7 downto 0);
	ram_we      : out std_logic;
	ram_ready   : in  std_logic;
	
	dbg_sector  : out std_logic_vector(4 downto 0)
);
end gcr_floppy;

architecture struct of gcr_floppy is

signal bit_clk_en  : std_logic;
signal bit_clk_div : unsigned(7 downto 0);
signal sync_cnt    : std_logic_vector(5 downto 0) := (others => '0');
signal byte_cnt    : std_logic_vector(8 downto 0) := (others => '0');
signal byte_in     : std_logic_vector(7 downto 0);
signal byte_out    : std_logic_vector(7 downto 0);
signal byte_we     : std_logic;
signal byte_addr   : std_logic_vector(12 downto 0);
signal nibble      : std_logic := '0';
signal gcr_bit_cnt : std_logic_vector(3 downto 0) := (others => '0');
signal bit_cnt     : std_logic_vector(2 downto 0) := (others => '0');

signal sync_in_n   : std_logic;
signal byte_in_n   : std_logic;

signal sector      : std_logic_vector(4 downto 0) := (others => '0');
signal state       : std_logic                    := '0';

signal data_header : std_logic_vector(7 downto 0);
signal data_body   : std_logic_vector(7 downto 0);
signal data        : std_logic_vector(7 downto 0);
signal data_cks    : std_logic_vector(7 downto 0);
signal gcr_nibble  : std_logic_vector(4 downto 0);
signal gcr_bit     : std_logic;
signal gcr_byte    : std_logic_vector(7 downto 0);

signal mode_r1     : std_logic;
signal mode_r2     : std_logic;

signal old_track   : std_logic_vector(5 downto 0);

signal raw_bit_clk_en : std_logic;
signal raw_bit_clk_div: unsigned(7 downto 0);
signal raw_byte_cnt   : std_logic_vector(12 downto 0);
signal raw_bit_cnt    : unsigned(2 downto 0);
signal raw_byte_in    : std_logic_vector( 7 downto 0);
signal raw_byte_we    : std_logic;
signal synced_bit_cnt : unsigned(2 downto 0);
signal shift_reg      : std_logic_vector(17 downto 0);
signal sync_in_n_raw  : std_logic;
signal byte_in_n_raw  : std_logic;

type gcr_array is array(0 to 15) of std_logic_vector(4 downto 0);
type gcr_tail_array is array(0 to 20) of std_logic_vector(7 downto 0);

signal gcr_lut : gcr_array := 
	("01010","11010","01001","11001",
	 "01110","11110","01101","11101",
	 "10010","10011","01011","11011",
	 "10110","10111","01111","10101");
	 
signal sector_max : std_logic_vector(4 downto 0);

signal gcr_byte_out   : std_logic_vector(7 downto 0);
signal gcr_bit_out    : std_logic;
signal gcr_nibble_out : std_logic_vector(4 downto 0);
signal nibble_out     : std_logic_vector(3 downto 0);
signal gcr_tail       : gcr_tail_array := (others => (others => '0'));

signal autorise_write : std_logic;
signal autorise_count : std_logic;

signal lfsr : std_logic_vector(3 downto 0) := "0001";

begin

ram_addr <=       raw_byte_cnt when raw = '1' else byte_addr;
ram_we <=          raw_byte_we when raw = '1' else byte_we;
ram_di <=     c1541_logic_dout when raw = '1' else byte_out;
c1541_logic_din <= raw_byte_in when raw = '1' else byte_in;

sync_n <= '1' when ram_ready = '0' or mtr = '0' else
	sync_in_n_raw when raw = '1' else
	sync_in_n;

dbg_sector <= sector;

with byte_cnt select
  data_header <= 
		X"08"                          when "000000000",
	  ("00" & track_num) xor ("000" & sector) xor id1 xor id2 when "000000001",
	  "000"&sector                    when "000000010",
	  "00"&track_num                  when "000000011",
	  id2                             when "000000100",
	  id1                             when "000000101",
	  X"0F"                           when others;

with byte_cnt select
	data_body <=
		X"07"     when std_logic_vector(to_unsigned(  0, byte_cnt'length)),
		data_cks  when std_logic_vector(to_unsigned(257, byte_cnt'length)),
		X"00"     when std_logic_vector(to_unsigned(258, byte_cnt'length)),
		X"00"     when std_logic_vector(to_unsigned(259, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(260, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(261, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(262, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(263, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(264, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(265, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(266, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(267, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(268, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(269, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(270, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(271, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(272, byte_cnt'length)),
		X"0F"     when std_logic_vector(to_unsigned(273, byte_cnt'length)),
		ram_do    when others;
	
with state select
	data <= data_header when '0', data_body when others;

with nibble select
	gcr_nibble <=
		gcr_lut(to_integer(unsigned(data(7 downto 4)))) when '0',
		gcr_lut(to_integer(unsigned(data(3 downto 0)))) when others;

gcr_bit <= gcr_nibble(to_integer(unsigned(gcr_bit_cnt)));

sector_max <=  "10100" when unsigned(track_num) < to_unsigned(18, track_num'length) else
			   "10010" when unsigned(track_num) < to_unsigned(25, track_num'length) else
			   "10001" when unsigned(track_num) < to_unsigned(31, track_num'length) else
               "10000";

gcr_bit_out <= gcr_byte_out(to_integer(unsigned(not bit_cnt)));

with gcr_nibble_out select
	nibble_out <= 	X"0" when "01010",--"01010",
						X"1" when "01011",--"11010",
						X"2" when "10010",--"01001",
						X"3" when "10011",--"11001",
						X"4" when "01110",--"01110",
						X"5" when "01111",--"11110",
						X"6" when "10110",--"01101",
						X"7" when "10111",--"11101",
						X"8" when "01001",--"10010",
						X"9" when "11001",--"10011",
						X"A" when "11010",--"01011",
						X"B" when "11011",--"11011",
						X"C" when "01101",--"10110",
						X"D" when "11101",--"10111",
						X"E" when "11110",--"01111",
						X"F" when others; --"10101",			

with freq select
	bit_clk_div <= to_unsigned(16#67#, bit_clk_div'length) when "11",
				   to_unsigned(16#6F#, bit_clk_div'length) when "10",
				   to_unsigned(16#77#, bit_clk_div'length) when "01",
				   to_unsigned(16#7F#, bit_clk_div'length) when others;

with raw_freq select
raw_bit_clk_div <= to_unsigned(16#67#, raw_bit_clk_div'length) when "11",
				   to_unsigned(16#6F#, raw_bit_clk_div'length) when "10",
				   to_unsigned(16#77#, raw_bit_clk_div'length) when "01",
				   to_unsigned(16#7F#, raw_bit_clk_div'length) when others;

process (clk32)
	variable bit_clk_cnt : unsigned(7 downto 0) := (others => '0');
	variable raw_bit_clk_cnt : unsigned(7 downto 0) := (others => '0');
begin
	if rising_edge(clk32) then

		mode_r1 <= mode;

		bit_clk_en <= '0';
		raw_bit_clk_en <= '0';
		byte_n <= '1';
		if (mode_r1 xor mode) = '1' then -- read <-> write change
			bit_clk_cnt := (others => '0');
			raw_bit_clk_cnt := (others => '0');
		elsif mtr = '1' then
			if bit_clk_cnt = 0 then
				bit_clk_en <= '1';
				bit_clk_cnt := bit_clk_div;
			else
				bit_clk_cnt := bit_clk_cnt - 1;
			end if;

			if raw_bit_clk_cnt = 0 then
				raw_bit_clk_en <= '1';
				raw_bit_clk_cnt := raw_bit_clk_div;
			else
				raw_bit_clk_cnt := raw_bit_clk_cnt - 1;
			end if;

			if ((byte_in_n = '0' and raw = '0') or (byte_in_n_raw = '0' and raw = '1')) and ram_ready = '1' then
				if bit_clk_cnt > to_unsigned(16, bit_clk_cnt'length) and bit_clk_cnt < to_unsigned(94, bit_clk_cnt'length) then
					byte_n <= '0';
				end if;
			end if;
		end if;
	end if;
end process;

lfsr_process : process(clk32)
begin
	if rising_edge(clk32) then
		lfsr <= (lfsr(0) xor lfsr(1)) & lfsr(3 downto 1);
	end if;
end process;

sync_in_n_raw <= '0' when shift_reg(17 downto 8) = "11"&x"FF" and unsigned(raw_track_len) /= 0 and mode = '1' else '1';

-- G64 handling
raw_read_write_process : process(clk32)
begin
	if rising_edge(clk32) then
		raw_byte_we <= '0';
		if mtr = '0' or mounted = '0' or raw = '0' then
			raw_byte_cnt <= std_logic_vector(to_unsigned(1026, raw_byte_cnt'length));
			synced_bit_cnt <= (others => '0');
			raw_bit_cnt <= (others => '0');
			byte_in_n_raw <= '1';
			shift_reg <= (others => '0');
		else
			if bit_clk_en = '1' then
				byte_in_n_raw <= '1';
				shift_reg(17 downto 8) <= shift_reg(16 downto 7);

				if shift_reg(10 downto 7) /= "0000" or lfsr(0) = '1' then
					-- not weak GCR (or randomly shift and insert '1' if weak)
					if shift_reg(10 downto 7) = "0000" then
						shift_reg(8) <= '1';
					end if;
					if synced_bit_cnt = to_unsigned(7, synced_bit_cnt'length) then
						byte_in_n_raw <= '0';
						raw_byte_in <= shift_reg(15 downto 8);
					end if;

					synced_bit_cnt <= synced_bit_cnt + 1;
				end if;

				if sync_in_n_raw = '0' or ram_ready = '0' or unsigned(raw_track_len) = 0 then
					synced_bit_cnt <= (others => '0');
				end if;
			end if;

			if raw_bit_clk_en = '1' then
				raw_bit_cnt <= raw_bit_cnt + 1;
				if raw_bit_cnt = 0 then
					shift_reg(7 downto 0) <= ram_do;
				else
					shift_reg(7 downto 0) <= shift_reg(6 downto 0) & '0';
				end if;

				if raw_bit_cnt = to_unsigned(7, raw_bit_cnt'length) then
					if unsigned(raw_track_len) /= 0 then
						raw_byte_we <= not mode;
					end if;
					raw_byte_cnt <= std_logic_vector(unsigned(raw_byte_cnt) + 1);
					if unsigned(raw_byte_cnt) >= unsigned(raw_track_len) + 1 and unsigned(raw_track_len) /= 0 then
					raw_byte_cnt <= std_logic_vector(to_unsigned(2, raw_byte_cnt'length));
					end if;
				end if;
			end if;
		end if;
	end if;
end process;

-- D64 handling
read_write_process : process (clk32)
begin
	if rising_edge(clk32) then
		if raw = '0' then
			old_track <= track_num;

			if old_track /= track_num then
				sector <= (others => '0'); --reset sector number on track change
			for i in 0 to 20 loop
				gcr_tail(i) <= (others => '0');
			end loop;
			elsif mounted = '1' and bit_clk_en = '1' then

				mode_r2 <= mode;
				if mode = '1' then autorise_write <= '0'; end if;

				if (mode xor mode_r2) = '1' then 
					if mode = '1' then  -- leaving write mode
						sync_in_n <= '0';
						sync_cnt <= (others => '0');
						state <= '0';
					else                -- entering write mode
						byte_cnt    <= (others => '0');
						nibble      <= '0';
						gcr_bit_cnt <= (others => '0');
						bit_cnt     <= (others => '0');
						gcr_byte    <= (others => '0');
						data_cks    <= (others => '0');
					end if;
				end if;

				if sync_in_n = '0' and mode = '1' then

					byte_cnt        <= (others => '0');
					nibble          <= '0';
					gcr_bit_cnt     <= (others => '0');
					bit_cnt         <= (others => '0');
					byte_in         <= (others => '1');
					gcr_byte        <= (others => '0');
					data_cks        <= (others => '0');

					if sync_cnt = std_logic_vector(to_unsigned(39, sync_cnt'length)) then
						sync_cnt <= (others => '0');
						sync_in_n <= '1';
					else
						sync_cnt <= std_logic_vector(unsigned(sync_cnt) + 1);
					end if;

				end if;

				if sync_in_n = '1' or mode = '0' then

					gcr_bit_cnt <= std_logic_vector(unsigned(gcr_bit_cnt) + 1);
					if gcr_bit_cnt = X"4" then
						gcr_bit_cnt <= (others => '0');
						if nibble = '1' then 
							nibble    <= '0';
							byte_addr <= sector & byte_cnt(7 downto 0);
							if byte_cnt = std_logic_vector(to_unsigned(0, byte_cnt'length)) then
								data_cks <= (others => '0');
							else
								data_cks <= data_cks xor data;
							end if;
							if mode = '1' or (mode = '0' and autorise_count = '1') then
								byte_cnt <= std_logic_vector(unsigned(byte_cnt) + 1);
							end if;
						else
							nibble <= '1';
							if mode = '0' and byte_out = X"07" then
								autorise_write <= '1';
								autorise_count <= '1';
							end if;
							if byte_cnt >= std_logic_vector(to_unsigned(256, byte_cnt'length)) then
								autorise_write <= '0';
								autorise_count <= '0';
							end if;
						end if;
					end if;

					bit_cnt <= std_logic_vector(unsigned(bit_cnt) + 1);
					byte_in_n  <= '1';
					if bit_cnt = X"7" then
						byte_in_n <= '0';
						gcr_byte_out <= c1541_logic_dout;
						if mode = '0' and state = '1' and byte_cnt = std_logic_vector(to_unsigned(256, byte_cnt'length)) then
							gcr_tail(to_integer(unsigned(sector))) <= c1541_logic_dout;
						end if;
					end if;

					if state = '0' then
						-- header
						if byte_cnt = std_logic_vector(to_unsigned(15, byte_cnt'length)) and unsigned(bit_cnt) = 0 then
							sync_in_n <= '0';
							state<= '1';
						end if;
					else
						-- data
						if byte_cnt = std_logic_vector(to_unsigned(273, byte_cnt'length)) then 
							sync_in_n <= '0';
							state <= '0';
							if sector = sector_max then 
								sector <= (others=>'0');
							else
								sector <= std_logic_vector(unsigned(sector) + 1);
							end if;
						end if;
					end if;

					-- demux byte from floppy (ram)
					gcr_byte <= gcr_byte(6 downto 0) & gcr_bit;

					if bit_cnt = X"7" then
						if mode = '1' and state = '1' and gcr_tail(to_integer(unsigned(sector))) /= X"00" and
						(byte_cnt = std_logic_vector(to_unsigned(258, byte_cnt'length))) then 
							byte_in <= gcr_tail(to_integer(unsigned(sector)));
						else
							byte_in <= gcr_byte(6 downto 0) & gcr_bit;
						end if;
					end if;

					-- serialise/convert byte to floppy (ram)
					gcr_nibble_out <= gcr_nibble_out(3 downto 0) & gcr_bit_out;

					if gcr_bit_cnt = X"0" then
						if nibble = '0' then 
							byte_out(3 downto 0) <= nibble_out;
						else
							byte_out(7 downto 4) <= nibble_out;
						end if;
					end if;

					if gcr_bit_cnt = X"1" and nibble = '0' then
						if autorise_write = '1' then
							byte_we <= '1';
						end if;
					else
						byte_we <= '0';
					end if;

				end if;
			end if;
		end if;
	end if;
end process;

end struct;
