-- -----------------------------------------------------------------------
--
--                                 FPGA 64
--
--     A fully functional commodore 64 implementation in a single FPGA
--
-- -----------------------------------------------------------------------
-- Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
-- -----------------------------------------------------------------------
--
-- System runs on 32 Mhz
-- The VIC-II runs in 4 cycles of first 16 cycles.
-- The CPU runs in the last 16 cycles. Effective cpu speed is 1 Mhz.
-- 
-- -----------------------------------------------------------------------
-- Dar 08/03/2014 
--
-- Based on fpga64_cone
-- add external selection for 15KHz(TV)/31KHz(VGA)
-- add external selection for power on NTSC(60Hz)/PAL(50Hz)
-- add external conection in/out for IEC signal
-- add sid entity 
-- -----------------------------------------------------------------------
-- 
-- Alexey Melnikov 2021
-- 
-- add dma engine
-- implement up to 4x turbo of C128 and smart types.
-- add user port signals
-- various fixes and tweaks
-- 
-- -----------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.numeric_std.all;

-- -----------------------------------------------------------------------

entity fpga64_sid_iec is
generic (
  DUAL : integer := 1 -- 0:no, 1:yes dual SID build option
);
port  (
	clk32       : in  std_logic;
	reset_n     : in  std_logic;
	bios        : in  std_logic_vector(1 downto 0);
	
	pause       : in  std_logic := '0';
	pause_out   : out std_logic;

	-- keyboard interface
	keyboard_matrix_out : out  std_logic_vector(7 downto 0);
	keyboard_matrix_in  :  in  std_logic_vector(7 downto 0);
	kbd_reset   : in  std_logic := '0';
	shift_mod   : in  std_logic_vector(1 downto 0);

	-- external memory
	ramAddr     : out unsigned(15 downto 0);
	ramDin      : in  unsigned(7 downto 0);
	ramDout     : out unsigned(7 downto 0);
	ramCE       : out std_logic;
	ramWE       : out std_logic;

	io_cycle    : out std_logic;
	ext_cycle   : out std_logic;
	refresh     : out std_logic;

	cia_mode    : in  std_logic;
	turbo_mode  : in  std_logic_vector(1 downto 0);
	turbo_speed : in  std_logic_vector(1 downto 0);

	-- VGA/SCART interface
	vic_variant : in std_logic_vector(1 downto 0);
	ntscMode    : in  std_logic;
	hsync       : out std_logic;
	vsync       : out std_logic;
	r           : out unsigned(7 downto 0);
	g           : out unsigned(7 downto 0);
	b           : out unsigned(7 downto 0);
	debugX      : out unsigned(9 downto 0);
	debugY      : out unsigned(8 downto 0);

    phi         : out std_logic;
    phi2_p      : out std_logic; -- Phi 2 positive edge
    phi2_n      : out std_logic; -- Phi 2 negative edge

	-- cartridge port
	game        : in  std_logic;
	exrom       : in  std_logic;
	io_rom      : in  std_logic;
	io_ext      : in  std_logic;
	io_data     : in  unsigned(7 downto 0);
	irq_n       : in  std_logic;
	nmi_n       : in  std_logic;
	nmi_ack     : out std_logic;
	romL        : out std_logic;
	romH        : out std_logic;
	UMAXromH 	: out std_logic;
	IO7			: out std_logic;
	IOE			: out std_logic;
	IOF			: out std_logic;
	freeze_key  : out std_logic;
	mod_key     : out std_logic;
	tape_play   : out std_logic;

	-- dma access
	dma_req     : in  std_logic := '0';
	dma_cycle   : out std_logic;
	dma_addr    : in  unsigned(15 downto 0) := (others => '0');
	dma_dout    : in  unsigned(7 downto 0) := (others => '0');
	dma_din     : out unsigned(7 downto 0);
	dma_we      : in  std_logic := '0';
	irq_ext_n   : in  std_logic := '1';

	-- joystick interface
	joyA        : in  std_logic_vector(6 downto 0);
	joyB        : in  std_logic_vector(6 downto 0);
	pot1        : in  std_logic_vector(7 downto 0);
	pot2        : in  std_logic_vector(7 downto 0);
	pot3        : in  std_logic_vector(7 downto 0);
	pot4        : in  std_logic_vector(7 downto 0);

	--SID
	audio_l     : out std_logic_vector(17 downto 0);
	audio_r     : out std_logic_vector(17 downto 0);
	audio_l_t   : out std_logic_vector(23 downto 0);
	audio_r_t   : out std_logic_vector(23 downto 0);

	--sid_filter  : in  std_logic_vector(1 downto 0);
	sid_ver     : in  std_logic_vector(1 downto 0);
	sid_mode    : in  unsigned(2 downto 0);
	--sid_cfg     : in  std_logic_vector(3 downto 0);
	sid_fc_off_l: in  std_logic_vector(10 downto 0);
	sid_fc_off_r: in  std_logic_vector(10 downto 0);
	sid_fc_base_l : in  std_logic_vector(8 downto 0);
	sid_fc_base_r : in  std_logic_vector(8 downto 0);
	sid_ld_clk  : in  std_logic;
	sid_ld_addr : in  std_logic_vector(11 downto 0);
	sid_ld_data : in  std_logic_vector(15 downto 0);
	sid_ld_wr   : in  std_logic;
	sid_digifix : in  std_logic;

	-- USER
	pb_i        : in  unsigned(7 downto 0);
	pb_o        : out unsigned(7 downto 0);
	pa2_i       : in  std_logic;
	pa2_o       : out std_logic;
	pc2_n_o     : out std_logic;
	flag2_n_i   : in  std_logic;
	sp2_i       : in  std_logic;
	sp2_o       : out std_logic;
	sp1_i       : in  std_logic;
	sp1_o       : out std_logic;
	cnt2_i      : in  std_logic;
	cnt2_o      : out std_logic;
	cnt1_i      : in  std_logic;
	cnt1_o      : out std_logic;

	-- IEC
	iec_data_o	: out std_logic;
	iec_data_i	: in  std_logic;
	iec_clk_o	: out std_logic;
	iec_clk_i	: in  std_logic;
	iec_atn_o	: out std_logic;
	
	c64rom_addr : in  std_logic_vector(13 downto 0);
	c64rom_data : in  std_logic_vector(7 downto 0);
	c64rom_wr   : in  std_logic;

	cass_motor  : out std_logic;
	cass_write  : out std_logic;
	cass_sense  : in  std_logic;
	cass_read   : in  std_logic
);
end fpga64_sid_iec;

-- -----------------------------------------------------------------------

architecture rtl of fpga64_sid_iec is
-- System state machine
constant CYCLE_EXT0: unsigned(4 downto 0) := to_unsigned( 0, 5);
constant CYCLE_EXT1: unsigned(4 downto 0) := to_unsigned( 1, 5);
constant CYCLE_EXT2: unsigned(4 downto 0) := to_unsigned( 2, 5);
constant CYCLE_EXT3: unsigned(4 downto 0) := to_unsigned( 3, 5);
constant CYCLE_DMA0: unsigned(4 downto 0) := to_unsigned( 4, 5);
constant CYCLE_DMA1: unsigned(4 downto 0) := to_unsigned( 5, 5);
constant CYCLE_DMA2: unsigned(4 downto 0) := to_unsigned( 6, 5);
constant CYCLE_DMA3: unsigned(4 downto 0) := to_unsigned( 7, 5);
constant CYCLE_EXT4 : unsigned(4 downto 0) := to_unsigned( 8, 5);
constant CYCLE_EXT5 : unsigned(4 downto 0) := to_unsigned( 9, 5);
constant CYCLE_EXT6 : unsigned(4 downto 0) := to_unsigned(10, 5);
constant CYCLE_EXT7 : unsigned(4 downto 0) := to_unsigned(11, 5);
constant CYCLE_VIC0 : unsigned(4 downto 0) := to_unsigned(12, 5);
constant CYCLE_VIC1 : unsigned(4 downto 0) := to_unsigned(13, 5);
constant CYCLE_VIC2 : unsigned(4 downto 0) := to_unsigned(14, 5);
constant CYCLE_VIC3 : unsigned(4 downto 0) := to_unsigned(15, 5);
constant CYCLE_CPU0 : unsigned(4 downto 0) := to_unsigned(16, 5);
constant CYCLE_CPU1 : unsigned(4 downto 0) := to_unsigned(17, 5);
constant CYCLE_CPU2 : unsigned(4 downto 0) := to_unsigned(18, 5);
constant CYCLE_CPU3 : unsigned(4 downto 0) := to_unsigned(19, 5);
constant CYCLE_CPU4 : unsigned(4 downto 0) := to_unsigned(20, 5);
constant CYCLE_CPU5 : unsigned(4 downto 0) := to_unsigned(21, 5);
constant CYCLE_CPU6 : unsigned(4 downto 0) := to_unsigned(22, 5);
constant CYCLE_CPU7 : unsigned(4 downto 0) := to_unsigned(23, 5);
constant CYCLE_CPU8 : unsigned(4 downto 0) := to_unsigned(24, 5);
constant CYCLE_CPU9 : unsigned(4 downto 0) := to_unsigned(25, 5);
constant CYCLE_CPUA : unsigned(4 downto 0) := to_unsigned(26, 5);
constant CYCLE_CPUB : unsigned(4 downto 0) := to_unsigned(27, 5);
constant CYCLE_CPUC : unsigned(4 downto 0) := to_unsigned(28, 5);
constant CYCLE_CPUD : unsigned(4 downto 0) := to_unsigned(29, 5);
constant CYCLE_CPUE : unsigned(4 downto 0) := to_unsigned(30, 5);
constant CYCLE_CPUF : unsigned(4 downto 0) := to_unsigned(31, 5);

signal sysCycle     : unsigned(4 downto 0) := (others => '0');
signal preCycle     : unsigned(4 downto 0) := (others => '0');
attribute syn_preserve : integer;
attribute syn_preserve of sysCycle : signal is 1;
attribute syn_preserve of preCycle : signal is 1;
signal sysEnable    : std_logic;
signal rfsh_cycle   : unsigned(1 downto 0);

signal dma_active   : std_logic;

signal phi0_cpu     : std_logic;
signal cpuHasBus    : std_logic;

signal baLoc        : std_logic;
signal ba_dma       : std_logic;
signal aec          : std_logic;

signal enableCpu    : std_logic;
signal enableVic    : std_logic;
signal enablePixel  : std_logic;
signal enableSid    : std_logic;

signal irq_cia1     : std_logic;
signal irq_cia2     : std_logic;
signal irq_vic      : std_logic;

signal systemWe     : std_logic;
signal pulseWr_io   : std_logic;
signal systemAddr   : unsigned(15 downto 0);

signal cs_vic       : std_logic;
signal cs_sid       : std_logic;
signal cs_color     : std_logic;
signal cs_cia1      : std_logic;
signal cs_cia2      : std_logic;
signal cs_ram       : std_logic;
signal cpuWe        : std_logic;
signal cpuWe_pre    : std_logic;
signal cpuAddr      : unsigned(15 downto 0);
signal cpuAddr_pre  : unsigned(15 downto 0);
signal cpuDi        : unsigned(7 downto 0);
signal cpuDo        : unsigned(7 downto 0);
signal cpuDo_pre    : unsigned(7 downto 0);
signal cpuIO        : unsigned(7 downto 0);
signal io_data_i    : unsigned(7 downto 0);
signal io7_i        : std_logic;
signal ioe_i        : std_logic;
signal iof_i        : std_logic;

signal io_enable    : std_logic;
signal cpu_cyc      : std_logic;
signal cpu_cyc_s    : std_logic_vector(1 downto 0);
signal turbo_m      : std_logic_vector(2 downto 0);

signal reset        : std_logic := '1';

-- CIA signals
signal enableCia_p  : std_logic;
signal enableCia_n  : std_logic;
signal cia1Do       : unsigned(7 downto 0);
signal cia2Do       : unsigned(7 downto 0);
signal cia1_pai     : unsigned(7 downto 0);
signal cia1_pao     : unsigned(7 downto 0);
signal cia1_pbi     : unsigned(7 downto 0);
signal cia1_pbo     : unsigned(7 downto 0);
signal cia2_pai     : unsigned(7 downto 0);
signal cia2_pao     : unsigned(7 downto 0);
signal cia2_pbi     : unsigned(7 downto 0);
signal cia2_pbo     : unsigned(7 downto 0);
signal cia2_pbe     : unsigned(7 downto 0);

signal todclk       : std_logic;

-- video
signal vicColorIndex: unsigned(3 downto 0);
signal vicBus       : unsigned(7 downto 0);
signal vicDi        : unsigned(7 downto 0);
signal vicDiAec     : unsigned(7 downto 0);
signal vicAddr      : unsigned(15 downto 0);
signal vicData      : unsigned(7 downto 0);
signal lastVicDi    : unsigned(7 downto 0);
signal vicAddr1514  : unsigned(1 downto 0);
signal colorData    : unsigned(3 downto 0);
signal colorDataAec : unsigned(3 downto 0);
signal turbo_en     : std_logic;
signal turbo_state  : std_logic;

-- SID signals
signal sid_do       : unsigned(7 downto 0);
signal sid_sel_l    : std_logic;
signal sid_sel_r    : std_logic;
signal pot_x1       : std_logic_vector(7 downto 0);
signal pot_y1       : std_logic_vector(7 downto 0);
signal pot_x2       : std_logic_vector(7 downto 0);
signal pot_y2       : std_logic_vector(7 downto 0);

component mos6526
	PORT (
		clk           : in  std_logic;
		mode          : in  std_logic := '0'; -- 0 - 6526 "old", 1 - 8521 "new"
		phi2_p        : in  std_logic;
		phi2_n        : in  std_logic;
		res_n         : in  std_logic;
		cs_n          : in  std_logic;
		rw            : in  std_logic; -- '1' - read, '0' - write
		rs            : in  unsigned(3 downto 0);
		db_in         : in  unsigned(7 downto 0);
		db_out        : out unsigned(7 downto 0);
		pa_in         : in  unsigned(7 downto 0);
		pa_out        : out unsigned(7 downto 0);
		pa_oe         : out unsigned(7 downto 0);
		pb_in         : in  unsigned(7 downto 0);
		pb_out        : out unsigned(7 downto 0);
		pb_oe         : out unsigned(7 downto 0);
		flag_n        : in  std_logic;
		pc_n          : out std_logic;
		tod           : in  std_logic;
		sp_in         : in  std_logic;
		sp_out        : out std_logic;
		cnt_in        : in  std_logic;
		cnt_out       : out std_logic;
		irq_n         : out std_logic
	);
end component; 

begin

-- -----------------------------------------------------------------------
-- Local signal to outside world
-- -----------------------------------------------------------------------

io_cycle <= '1' when
	(sysCycle >= CYCLE_EXT0 and sysCycle <= CYCLE_EXT3) or
	(sysCycle >= CYCLE_EXT4 and sysCycle <= CYCLE_EXT7 and rfsh_cycle /= "00")  else '0';

-- -----------------------------------------------------------------------
-- System state machine, controls bus accesses
-- and triggers enables of other components
-- -----------------------------------------------------------------------

sysCycle <= preCycle when sysEnable = '1' else CYCLE_EXT4;
pause_out <= not sysEnable;

process(clk32)
begin
	if rising_edge(clk32) then
		preCycle <= preCycle+1;
		if preCycle = CYCLE_CPUF then
		if sysEnable = '1' then
			rfsh_cycle <= rfsh_cycle + 1;
			end if;
		end if;
		
		refresh <= '0';
		if preCycle = CYCLE_DMA3 and rfsh_cycle = "00" then
			sysEnable <= not pause;
			refresh <= '1';
		end if;
	end if;
end process;

process(clk32)
begin
	if rising_edge(clk32) then
		if preCycle = CYCLE_CPUF then
			reset <= not reset_n;
		end if;
	end if;
end process;

-- PHI0/2-clock emulation
process(clk32)
begin
	if rising_edge(clk32) then
		if sysCycle = CYCLE_VIC3 then
			phi0_cpu <= '1';
			if baLoc = '1' or (cpuWe = '1' and dma_active = '0') or (ba_dma = '1' and dma_active = '1') then
				cpuHasBus <= '1';
			end if;
		end if;
		if sysCycle = CYCLE_CPUF then
			phi0_cpu <= '0';
			cpuHasBus <= '0';
		end if;
	end if;
end process;

	phi <= phi0_cpu;
    phi2_p <= enableCia_p;
    phi2_n <= enableCia_n;

process(clk32)
begin
	if rising_edge(clk32) then
		enableVic <= '0';
		enableCia_n <= '0';
		enableCia_p <= '0';
		enableSid <= '0';

		case sysCycle is
		when CYCLE_VIC2 =>
			enableVic <= '1';
		when CYCLE_CPUE =>
			enableVic <= '1';
		when CYCLE_CPUC =>
			enableCia_n <= '1';
		when CYCLE_CPUF =>
			enableCia_p <= '1';
			enableSid <= '1';
		when others =>
			null;
		end case;
	end if;
end process;

-- -----------------------------------------------------------------------
-- Color RAM
-- -----------------------------------------------------------------------
colorram: entity work.Gowin_SP_cram
    port map (
        unsigned(dout) => colorData,
        clk => clk32,
        oce => '1',
        ce => '1',
        reset => '0',
        wre => cs_color and pulseWr_io,
        ad => std_logic_vector(systemAddr(9 downto 0)),
        din => std_logic_vector(cpuDo(3 downto 0))
    );

-- -----------------------------------------------------------------------
-- PLA and bus-switches
-- -----------------------------------------------------------------------
buslogic: entity work.fpga64_buslogic
port map (
	clk => clk32,
	reset => reset,
	bios => bios,

	cpuHasBus => cpuHasBus,
	aec => aec,

	bankSwitch => cpuIO(2 downto 0),

	game => game,
	exrom => exrom,
	io_rom => io_rom,
	io_ext => io_ext or sid_sel_r,
	io_data => io_data_i,

	ramData => ramDin,

	cpuWe => cpuWe,
	cpuAddr => cpuAddr,
	cpuData => cpuDo,
	vicAddr => vicAddr,
	vicData => vicData,
	sidData => sid_do,
	colorData => colorData,
	cia1Data => cia1Do,
	cia2Data => cia2Do,
	lastVicData => lastVicDi,

	systemWe => systemWe,
	systemAddr => systemAddr,
	dataToCpu => cpuDi,
	dataToVic => vicDi,

	io_enable => io_enable,

	cs_vic => cs_vic,
	cs_sid => cs_sid,
	cs_color => cs_color,
	cs_cia1 => cs_cia1,
	cs_cia2 => cs_cia2,
	cs_ram => cs_ram,
	cs_ioE => ioe_i,
	cs_ioF => iof_i,
	cs_io7 => io7_i,
	cs_romL => romL,
	cs_romH => romH,
	cs_UMAXromH => UMAXromH,

	c64rom_addr => c64rom_addr,
	c64rom_data => c64rom_data,
	c64rom_wr => c64rom_wr
);

IO7 <= io7_i;
IOE <= ioe_i;
IOF <= iof_i;

process(clk32)
begin
	if rising_edge(clk32) then
		pulseWr_io <= '0';
		if cpuWe = '1' then
			if sysCycle = CYCLE_CPUC then
				pulseWr_io <= '1';
			end if;
		end if;
	end if;
end process;

-- -----------------------------------------------------------------------
-- VIC-II video interface chip
-- -----------------------------------------------------------------------
process(clk32)
begin
	if rising_edge(clk32) then
		if phi0_cpu = '1' then
			if cpuWe = '1' and cs_vic = '1' then
				vicBus <= cpuDo;
			else
				vicBus <= x"FF";
			end if;
		end if;
	end if;
end process;

-- In the first three cycles after BA went low, the VIC reads
-- $ff as character pointers and
-- as color information the lower 4 bits of the opcode after the access to $d011.
vicDiAec <= vicBus when aec = '0' else vicDi;
colorDataAec <= cpuDi(3 downto 0) when aec = '0' else colorData;

vic: entity work.video_vicii_656x
generic map (
	registeredAddress => true,
	emulateRefresh => true,
	emulateLightpen => true,
	emulateGraphics => true
)			
port map (
	clk => clk32,
	reset => reset,
	enaPixel => enablePixel,
	enaData => enableVic,
	phi => phi0_cpu,
	
	baSync => '0',
	ba => baLoc,
	ba_dma => ba_dma,

	mode6569 => (not ntscMode),
	mode6567old => '0',
	mode6567R8 => ntscMode,
	mode6572 => '0',
	
	turbo_en => turbo_en,
	turbo_state => turbo_state,
	variant => vic_variant,  -- 00 - NMOS, 01 - HMOS, 10 - old HMOS

	cs => cs_vic,
	we => cpuWe,
	lp_n => cia1_pbi(4),

	aRegisters => cpuAddr(5 downto 0),
	diRegisters => cpuDo,
	di => vicDiAec,
	diColor => colorDataAec,
	do => vicData,

	vicAddr => vicAddr(13 downto 0),
	addrValid => aec,
	
	hsync => hSync,
	vsync => vSync,
	colorIndex => vicColorIndex,
	debugX  => debugX,
	debugY  => debugY,
	irq_n => irq_vic
);

c64colors: entity work.fpga64_rgbcolor
port map (
	index => vicColorIndex,
	r => r,
	g => g,
	b => b
);

process(clk32)
begin
	if rising_edge(clk32) then
		if sysCycle = CYCLE_VIC3 then
			lastVicDi <= vicDi;
		end if;
	end if;
end process;

-- VIC bank to address lines
-- 
-- The glue logic on a C64C will generate a glitch during 10 <-> 01
-- generating 00 (in other words, bank 3) for one cycle.
--
-- When using the data direction register to change a single bit 0->1
-- (in other words, decreasing the video bank number by 1 or 2),
-- the bank change is delayed by one cycle. This effect is unstable.
process(clk32)
begin
	if rising_edge(clk32) then
		if phi0_cpu = '0' and enableVic = '1' then
			vicAddr1514 <= not cia2_pao(1 downto 0);
		end if;
	end if;
end process;

-- emulate only the first glitch (enough for Undead from Emulamer)
vicAddr(15 downto 14) <= "11" when ((vicAddr1514 xor not cia2_pao(1 downto 0)) = "11") and (cia2_pao(0) /= cia2_pao(1)) else not unsigned(cia2_pao(1 downto 0));

-- Pixel timing
process(clk32)
begin
	if rising_edge(clk32) then
		enablePixel <= '0';
		if sysCycle = CYCLE_VIC2
		or sysCycle = CYCLE_EXT2
		or sysCycle = CYCLE_DMA2
		or sysCycle = CYCLE_EXT6
		or sysCycle = CYCLE_CPU2
		or sysCycle = CYCLE_CPU6
		or sysCycle = CYCLE_CPUA
		or sysCycle = CYCLE_CPUE then
			enablePixel <= '1';
		end if;
	end if;
end process;

-- -----------------------------------------------------------------------
-- SID
-- -----------------------------------------------------------------------
-- Right SID Port: Same,DE00,D420,D500,DF00
sid_sel_l <= cs_sid when sid_mode(2 downto 1) /= 1 else (cs_sid and ((not sid_mode(0) and not cpuAddr(5)) or (sid_mode(0) and not cpuAddr(8))));
sid_sel_r <= sid_sel_l when sid_mode = 0 else ioe_i when sid_mode = 1 else iof_i when sid_mode = 4 else (cs_sid and not sid_sel_l);
io_data_i <= io_data when io_ext = '1' else sid_do when sid_sel_r = '1' else (others => '1');

pot_x1 <= (others => '1' ) when cia1_pao(6) = '0' else not pot1;
pot_y1 <= (others => '1' ) when cia1_pao(6) = '0' else not pot2;
pot_x2 <= (others => '1' ) when cia1_pao(7) = '0' else not pot3;
pot_y2 <= (others => '1' ) when cia1_pao(7) = '0' else not pot4;

sidpipe: entity work.sid_api
port map (
    clk => clk32,
	reset => reset,
	we => pulseWr_io,
	cs => unsigned'(sid_sel_r & sid_sel_l),
	phi2  => enableSid,
	addr => cpuAddr(4 downto 0),
	data_i => cpuDo,
	data_o => sid_do,
	pot_x_l => pot_x1 and pot_x2,
	pot_y_l => pot_y1 and pot_y2,
	pot_x_r => pot_x1 and pot_x2,
	pot_y_r => pot_y1 and pot_y2,
	mode    => sid_ver(0),
	fc_offset_l => sid_fc_off_l,
	fc_offset_r => sid_fc_off_r,
    fc_base_l => sid_fc_base_l,
    fc_base_r => sid_fc_base_r,

	audio_o_l => audio_l_t,
	audio_o_r => audio_r_t,

	audio_i_l(23) => sid_ver(0) and sid_digifix,
	audio_i_l(22 downto 0) => (others => '0'),
	audio_i_r(23) => sid_ver(0) and sid_digifix,
	audio_i_r(22 downto 0) => (others => '0')
	);

	audio_l <= audio_l_t(23 downto 6);
	audio_r <= audio_r_t(23 downto 6);

-- -----------------------------------------------------------------------
-- CIAs
-- -----------------------------------------------------------------------
cia1: mos6526
port map (
	clk => clk32,
	mode => cia_mode,
	phi2_p => enableCia_p,
	phi2_n => enableCia_n,
	res_n => not reset,
	cs_n => not cs_cia1,
	rw => not cpuWe,

	rs => cpuAddr(3 downto 0),
	db_in => cpuDo,
	db_out => cia1Do,

	pa_in => cia1_pai,
	pa_out => cia1_pao,
	pb_in => cia1_pbi,
	pb_out => cia1_pbo,

	flag_n => cass_read,
	sp_in => sp1_i,
	sp_out => sp1_o,
	cnt_in => cnt1_i,
	cnt_out => cnt1_o,

	tod => todclk,

	irq_n => irq_cia1
);

cia2: mos6526
port map (
	clk => clk32,
	mode => cia_mode,
	phi2_p => enableCia_p,
	phi2_n => enableCia_n,
	res_n => not reset,
	cs_n => not cs_cia2,
	rw => not cpuWe,

	rs => cpuAddr(3 downto 0),
	db_in => cpuDo,
	db_out => cia2Do,

	pa_in => cia2_pai and cia2_pao,
	pa_out => cia2_pao,
	pb_in => (pb_i and not cia2_pbe) or (cia2_pbo and cia2_pbe),
	pb_out => cia2_pbo,
	pb_oe => cia2_pbe,

	flag_n => flag2_n_i,
	pc_n => pc2_n_o,

	sp_in => sp2_i,
	sp_out => sp2_o,
	cnt_in => cnt2_i,
	cnt_out => cnt2_o,

	tod => todclk,

	irq_n => irq_cia2
);

serialBus: process(clk32)
begin
	if rising_edge(clk32) then
		if sysCycle = CYCLE_EXT5 then
			cia2_pai(7) <= iec_data_i and not cia2_pao(5);
			cia2_pai(6) <= iec_clk_i and not cia2_pao(4);
		end if;
	end if;
end process;

cia2_pai(5 downto 0) <= "111" & pa2_i & "11";

iec_data_o <= not cia2_pao(5);
iec_clk_o  <= not cia2_pao(4);
iec_atn_o  <= not cia2_pao(3);

pb_o  <= cia2_pbo;
pa2_o <= cia2_pao(2);

process(clk32)
variable sum: integer range 0 to 33000000;
begin
	if rising_edge(clk32) then
		if reset = '1' then
			todclk <= '0';
			sum := 0;
		elsif ntscMode = '1' then
			sum := sum + 120;
			if sum >= 32940000 then  -- adjusted to GW2A PLL capabilities
				sum := sum - 32940000;
				todclk <= not todclk;
			end if;
		else
			sum := sum + 100;
			if sum >= 31500000 then
				sum := sum - 31500000;
				todclk <= not todclk;
			end if;
		end if;
	end if;
end process;

-- -----------------------------------------------------------------------
-- 6510 CPU / DMA
-- -----------------------------------------------------------------------
cpu: entity work.cpu_6510
port map (
	clk => clk32,
	reset => reset,
	enable => enableCpu and not dma_active,
	nmi_n => irq_cia2 and nmi_n,
	nmi_ack => nmi_ack,
	irq_n => irq_cia1 and irq_vic and irq_n and irq_ext_n,
	rdy => baLoc,

	di => cpuDi,
	addr => cpuAddr_pre,
	do => cpuDo_pre,
	we => cpuWe_pre,

	diIO => cpuIO(7) & cpuIO(6) & cpuIO(5) & cass_sense & cpuIO(3) & "111",
	doIO => cpuIO
);

cass_motor <= cpuIO(5);
cass_write <= cpuIO(3);

ramDout <= cpuDo;
ramAddr <= systemAddr;
ramWE   <= systemWe when sysCycle >= CYCLE_CPU0 else '0';
ramCE   <= cs_ram when sysCycle = CYCLE_VIC0 or cpu_cyc = '1' else '0';

cpu_cyc <= '1' when 
				(sysCycle = CYCLE_CPU0 and turbo_m(0) = '1' and cs_ram = '1' ) or
				(sysCycle = CYCLE_CPU4 and turbo_m(1) = '1' and cs_ram = '1' ) or
				(sysCycle = CYCLE_CPU8 and turbo_m(2) = '1' and cs_ram = '1' ) or
				(sysCycle = CYCLE_CPUC and (io_enable = '1'  or cs_ram = '1')) else '0';
				
process(clk32)
begin
	if rising_edge(clk32) then
		cpu_cyc_s <= cpu_cyc_s(0) & cpu_cyc;
		enableCpu <= cpu_cyc_s(1);
		io_enable <= io_enable and not enableCpu;

		if sysCycle = CYCLE_EXT0 then
			io_enable <= '1';
		end if;

		-- 2 points to register DMA request before CPU cycles.
		if sysCycle = CYCLE_EXT1 or sysCycle = CYCLE_EXT5 then
			dma_active <= dma_req;
			turbo_en <= turbo_mode(0);
			turbo_m <= "000";
			if dma_req = '0' and ((turbo_mode(0) and turbo_state) = '1' or turbo_mode(1) = '1') then
				case turbo_speed is
					when "00" => turbo_m <= "010";
					when "01" => turbo_m <= "110";
					when "10" => turbo_m <= "111";
					when others => turbo_m <= "111";
				end case;
			end if;
		end if;
	end if;
end process;

cpuAddr <= cpuAddr_pre when dma_active = '0' else dma_addr;
cpuDo   <= cpuDo_pre   when dma_active = '0' else dma_dout;
cpuWe   <= cpuWe_pre   when dma_active = '0' else dma_we;

ext_cycle <= '1' when (sysCycle >= CYCLE_DMA0 and sysCycle <= CYCLE_DMA3) else '0';
dma_cycle <= '1' when (sysCycle >= CYCLE_CPU0 and sysCycle <= CYCLE_CPUF) and cpuHasBus = '1' and dma_active = '1' else '0';
dma_din   <= cpuDi;

-- -----------------------------------------------------------------------
-- Keyboard
-- -----------------------------------------------------------------------
Keyboard_inst: entity work.fpga64_keyboard
port map (
	clk => clk32,
	
	reset => kbd_reset,

	keyboard_matrix_out => keyboard_matrix_out,
	keyboard_matrix_in => keyboard_matrix_in,

	joyA => not unsigned(joyA(6 downto 0)),
	joyB => not unsigned(joyB(6 downto 0)),
	pai => cia1_pao,
	pbi => cia1_pbo,
	pao => cia1_pai,
	pbo => cia1_pbi,
	
	shift_mod => shift_mod,

	restore_key => freeze_key,
	tape_play => tape_play,
	mod_key => mod_key,
	backwardsReadingEnabled => '1'
);

end architecture;
