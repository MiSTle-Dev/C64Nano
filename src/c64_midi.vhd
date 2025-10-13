---------------------------------------------------------------------------------
-- c64_midi.vhd - 6850 ACIA based MIDI interface
-- 2022 - Slingshot
--
-- https://codebase64.org/doku.php?id=base:c64_midi_interfaces
-- Mode 1 : SEQUENTIAL CIRCUITS INC.
-- Mode 2 : PASSPORT & SENTECH
-- Mode 3 : DATEL/SIEL/JMS/C-LAB
-- Mode 4 : NAMESOFT
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity c64_midi is
port(
	clk32   : in  std_logic;
	reset   : in  std_logic;
	Mode    : in  std_logic_vector( 2 downto 0);
	E       : in  std_logic;
	IOE     : in  std_logic;
	A       : in  std_logic_vector(15 downto 0);
	Din     : in  std_logic_vector( 7 downto 0);
	Dout    : out std_logic_vector( 7 downto 0);
	OE      : out std_logic;
	RnW     : in  std_logic;
	nIRQ    : out std_logic;
	nNMI    : out std_logic;

	RX      : in  std_logic;
	TX      : out std_logic
);
end c64_midi;

architecture rtl of c64_midi is

--component gen_uart_mc_6850 is
--port (
--	reset     : in  std_logic;
--	clk       : in  std_logic;
--	rx_clk_en : in  std_logic;
--	tx_clk_en : in  std_logic;
--	din       : in  std_logic_vector(7 downto 0);
--	dout      : out std_logic_vector(7 downto 0);
--	rnw       : in  std_logic;
--	cs        : in  std_logic;
--	rs        : in  std_logic;
--	irq_n     : out std_logic;
--	cts_n     : in  std_logic;
--	dcd_n     : in  std_logic;
--	rts_n     : out std_logic;
--	rx        : in  std_logic;
--	tx        : out std_logic
--);
--end component;

signal acia_sel : std_logic;
signal acia_rs  : std_logic;
signal acia_rw  : std_logic;
signal acia_irq_n : std_logic;
signal acia_rxtxclk_sel : std_logic;
signal acia_clk_en : std_logic;
signal acia_clk_en_cnt : unsigned(5 downto 0);
signal acia_din : std_logic_vector(7 downto 0);
begin

	process(clk32) begin
		if rising_edge(clk32) then
			acia_din <= Din;
			if reset = '1' then
				acia_clk_en <= '0';
				acia_clk_en_cnt <= (others=>'0');
			else
				acia_clk_en <= '0';
				acia_clk_en_cnt <= acia_clk_en_cnt + 1;
				-- 2 MHz or 512 kHz
				if acia_clk_en_cnt = 0 or (acia_rxtxclk_sel = '1' and acia_clk_en_cnt(3 downto 0) = 0) then
					acia_clk_en <= '1';
				end if;
			end if;
		end if;
	end process;

	process(Mode, IOE, A, RnW, acia_irq_n) begin
		acia_rxtxclk_sel <= '0';
		acia_sel <= '0';
		acia_rw <= '1';
		acia_rs <= '0';
		nIRQ <= '1';
		nNMI <= '1';
		case Mode is
			when "001" =>
				-- Mode 1 : SEQUENTIAL CIRCUITS INC.
				nIRQ <= acia_irq_n;
				acia_sel <= IOE and not A(2) and not A(3) and not A(4);
				acia_rs <= A(0);
				acia_rw <= A(1);
			when "010" =>
				-- Mode 2 : PASSPORT & SENTECH
				nIRQ <= acia_irq_n;
				acia_sel <= IOE and not A(2) and A(3) and not A(4);
				acia_rs <= A(0);
				acia_rw <= RnW;
			when "011" =>
				-- Mode 3 : DATEL/SIEL/JMS/C-LAB
				acia_rxtxclk_sel <= '1'; -- for 2 MHz RX/TX clock
				nIRQ <= acia_irq_n;
				acia_sel <= IOE and A(2) and not A(3) and not A(4);
				acia_rs <= A(0);
				acia_rw <= A(1);
			when "100" =>
				-- Mode 4 : NAMESOFT
				nNMI <= acia_irq_n;
				acia_sel <= IOE and not A(2) and not A(3) and not A(4);
				acia_rs <= A(0);
				acia_rw <= A(1);
			when others => null;
		end case;
	end process;

	OE <= acia_sel and acia_rw;

	acia_inst : entity work.gen_uart_mc_6850
	port map (
		reset     => reset,
		clk       => clk32,
		rx_clk_en => acia_clk_en,
		tx_clk_en => acia_clk_en,
		din       => acia_din,
		dout      => Dout,
		rnw       => acia_rw,
		cs        => acia_sel,
		rs        => acia_rs,
		irq_n     => acia_irq_n,
		cts_n     => '0',
		dcd_n     => '0',
		rts_n     => open,
		rx        => RX,
		tx        => TX
	);

end rtl;
