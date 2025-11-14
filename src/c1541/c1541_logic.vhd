library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

--
-- Model 1541B
--
-- 2023 & 2025 Stefan Voss Dolphindos 2 and external ROM added

entity c1541_logic is
  generic
  (
    DEVICE_SELECT   : std_logic_vector(1 downto 0)
  );
  port
  (
    clk_32M         : in std_logic;
    reset           : in std_logic;
    pause           : in std_logic;
    ce              : in std_logic;

    -- serial bus
    sb_data_oe      : out std_logic;
    sb_data_in      : in std_logic;
    sb_clk_oe       : out std_logic;
    sb_clk_in       : in std_logic;
    sb_atn_in       : in std_logic;

    -- parallel bus
    par_data_i      : in std_logic_vector(7 downto 0);
    par_stb_i       : in std_logic;
    par_data_o      : out std_logic_vector(7 downto 0);
    par_stb_o       : out std_logic;

  -- drive-side interface
    ds              : in std_logic_vector(1 downto 0);    -- device select
    di              : in std_logic_vector(7 downto 0);    -- disk read data
    do              : out std_logic_vector(7 downto 0);   -- disk data to write
    mode            : out std_logic;                      -- read/write
    stp             : out std_logic_vector(1 downto 0);   -- stepper motor control
    mtr             : out std_logic;                      -- stepper motor on/off
    freq            : out std_logic_vector(1 downto 0);   -- motor frequency
    sync_n          : in std_logic;                       -- reading SYNC bytes
    byte_n          : in std_logic;                       -- byte ready
    wps_n           : in std_logic;                       -- write-protect sense
    tr00_sense_n    : in std_logic;                       -- track 0 sense (unused?)
    act             : out std_logic;                       -- activity LED

    ext_en          : in std_logic;
    c1541rom_addr   : out std_logic_vector(14 downto 0);
    c1541rom_data   : in std_logic_vector(7 downto 0);
    c1541rom_cs     : out std_logic
  );
end c1541_logic;

architecture SYN of c1541_logic is

  -- clocks, reset
  signal p2_h_r         : std_logic;
  signal p2_h_f         : std_logic;
    
  -- cpu signals  
  signal cpu_a          : std_logic_vector(23 downto 0);
  signal cpu_di         : std_logic_vector(7 downto 0);
  signal cpu_do         : std_logic_vector(7 downto 0);
  signal cpu_rw_n       : std_logic;
  signal cpu_irq_n      : std_logic;
  signal cpu_so_n       : std_logic;

  -- rom signals
  signal rom_cs         : std_logic;
  signal rom_do         : std_logic_vector(cpu_di'range); 

  -- ram signals
  signal ram_cs         : std_logic;
  signal ram_wr         : std_logic;
  signal ram_do         : std_logic_vector(cpu_di'range);
  
  -- UC1 (VIA6522) signals
  signal uc1_do         : std_logic_vector(7 downto 0);
  signal uc1_do_oe_n    : std_logic;
  signal uc1_cs2_n      : std_logic;
  signal uc1_irq_n      : std_logic;
  signal uc1_ca1_i      : std_logic;
  signal uc1_pa_i       : std_logic_vector(7 downto 0);
  signal uc1_pa_o       : std_logic_vector(7 downto 0);
  signal uc1_pa_oe_n    : std_logic_vector(7 downto 0);
  signal uc1_pb_i       : std_logic_vector(7 downto 0);
  signal uc1_pb_o       : std_logic_vector(7 downto 0);
  signal uc1_pb_oe_n    : std_logic_vector(7 downto 0);
  signal uc1_cb2_o      : std_logic;
  signal uc1_cb2_oe     : std_logic;
    
  -- UC3 (VIA6522) signals
  signal uc3_do         : std_logic_vector(7 downto 0);
  signal uc3_do_oe_n    : std_logic;
  signal uc3_cs2_n      : std_logic;
  signal uc3_irq_n      : std_logic;
  signal uc3_ca1_i      : std_logic;
  signal uc3_ca2_o      : std_logic;
  signal uc3_ca2_oe_n   : std_logic;
  signal uc3_pa_i       : std_logic_vector(7 downto 0);
  signal uc3_pa_o       : std_logic_vector(7 downto 0);
  signal uc3_cb2_o      : std_logic;
  signal uc3_cb2_oe_n   : std_logic;
  signal uc3_pa_oe_n    : std_logic_vector(7 downto 0);
  signal uc3_pb_i       : std_logic_vector(7 downto 0);
  signal uc3_pb_o       : std_logic_vector(7 downto 0);
  signal uc3_pb_oe_n    : std_logic_vector(7 downto 0);
  signal uc3_cb1_o      : std_logic;
  signal uc3_cb1_oe     : std_logic;

  -- internal signals
  signal atn            : std_logic; -- attention
  signal soe            : std_logic; -- set overflow enable
  
  signal uc1_pa_oe      : std_logic_vector(7 downto 0);
  signal uc1_pb_oe      : std_logic_vector(7 downto 0);
  signal uc1_irq        : std_logic;
  signal uc3_irq        : std_logic;
  signal uc3_ca2_oe     : std_logic;
  signal uc3_cb2_oe     : std_logic;
  signal uc3_pa_oe      : std_logic_vector(7 downto 0);
  signal uc3_pb_oe      : std_logic_vector(7 downto 0);

  signal cpu_a_slice    : std_logic_vector(3 downto 0);

  signal uc1_ca2_o      : std_logic;
  signal uc1_ca2_oe     : std_logic;
  signal uc1_cb1_o      : std_logic;
  signal uc1_cb1_oe     : std_logic;
  signal cb1_i          : std_logic;

  signal cpu_b_slice    : std_logic_vector(2 downto 0);
  signal extram_cs      : std_logic;
  signal extram_do      : std_logic_vector(7 downto 0) := x"FF";
  signal extram_wr      : std_logic;

  begin

  process (clk_32M)
    variable count  : std_logic_vector(4 downto 0) := (others => '0');
  begin
    if rising_edge(clk_32M) then
        if pause = '0' then count := std_logic_vector(unsigned(count) + 1); end if;
    end if;
    if count = "00000" then p2_h_r <= '1'; else p2_h_r <='0' ; end if;
    if count = "10000" then p2_h_f <= '1'; else p2_h_f <='0' ; end if;
  end process;

  -- decode logic
  process (cpu_a, cpu_a_slice)
  begin
    ram_cs <= '0';
    uc1_cs2_n <= '1';
    uc3_cs2_n <= '1';

    -- address decoder logic using a 74LS42 BCD decoder
    cpu_a_slice <= cpu_a(15)&cpu_a(12)&cpu_a(11)&cpu_a(10);
    case cpu_a_slice is
      when "0000" => ram_cs <= '1';     -- RAM $0000-$07FF (2KB) + mirrors
      when "0001" => ram_cs <= '1';     -- RAM $0000-$07FF (2KB) + mirrors
      when "0110" => uc1_cs2_n <= '0';  -- UC1 (VIA6522) $1800-$180F + mirrors
      when "0111" => uc3_cs2_n <= '0';  -- UC3 (VIA6522) $1C00-$1C0F + mirrors
      when others => null;
    end case;
  end process;

  -- qualified write signals
  ram_wr <= '1' when ram_cs = '1' and cpu_rw_n = '0' else '0';
  extram_wr <= '1' when extram_cs = '1' and cpu_rw_n = '0' else '0';

  process (cpu_a, cpu_b_slice)
  begin
  rom_cs <= '0';
  extram_cs <= '0';
  cpu_b_slice <= cpu_a(15)&cpu_a(14)&cpu_a(13);
    case cpu_b_slice is
      when "110" => rom_cs <= '1';    -- 8k standard rom low
      when "111" => rom_cs <= '1';    -- 8k standard rom high
      when "101" => rom_cs <= '1';    -- 8k extra rom
      when "100" => extram_cs <= '1'; -- 8k extra ram 
      when others => null;
    end case;
  end process;

  c1541rom_cs <= cpu_a(15) and p2_h_r and cpu_rw_n;
  c1541rom_addr <= cpu_a(14 downto 0);
  rom_do <= c1541rom_data;
  
-- 8k extra sram extension for dolphin dos
ram_8kinst :  entity work.Gowin_SP_8k
port map (
    dout => extram_do,
    clk => clk_32M,
    oce => '1',
    ce => ext_en,
    reset => reset,
    wre => extram_wr,
    ad => cpu_a(12 downto 0),
    din => cpu_do
);

  sb_data_oe <= not (uc1_pb_o(1) or uc1_pb_oe_n(1)) and not atn;
  sb_clk_oe <= not(uc1_pb_o(3) or not uc1_pb_oe(3));

  par_stb_o  <= uc1_ca2_o or not uc1_ca2_oe;
  par_data_o <= uc1_pa_o or not uc1_pa_oe; 
  cb1_i <= par_stb_i when ext_en = '1' else '1';
  uc1_pa_i <= par_data_i when ext_en = '1' else  "1111111" & tr00_sense_n;

  -- PB
  uc1_pb_i(0) <=  not (sb_data_in and sb_data_oe);
  uc1_pb_i(1) <=  '1';
  uc1_pb_i(2) <=  not (sb_clk_in and sb_clk_oe);
  uc1_pb_i(4 downto 3) <= "11"; -- NC
  atn <= (uc1_pb_o(4) or uc1_pb_oe_n(4)) xor (not sb_atn_in);
  uc1_pb_i(6 downto 5) <= DEVICE_SELECT xor ds;     -- allows override
  uc1_pb_i(7) <= not sb_atn_in;

  --
  -- hook up UC3 ports
  --
  soe <= uc3_ca2_o or uc3_ca2_oe_n;
  do <= uc3_pa_o or uc3_pa_oe_n;
  mode <= uc3_cb2_o or uc3_cb2_oe_n;
  stp(1) <= uc3_pb_o(0) or uc3_pb_oe_n(0);
  stp(0) <= uc3_pb_o(1) or uc3_pb_oe_n(1);
  mtr <= uc3_pb_o(2) or uc3_pb_oe_n(2);
  act <= uc3_pb_o(3) or uc3_pb_oe_n(3);
  freq <= uc3_pb_o(6 downto 5) or uc3_pb_oe_n(6 downto 5);
  uc3_pb_i <= sync_n & "11" & wps_n & "1111";
  
  --
  -- CPU connections
  --
  cpu_di <= cpu_do when cpu_rw_n = '0' else
            rom_do when rom_cs = '1' else
            ram_do when ram_cs = '1' else
            uc1_do when uc1_cs2_n = '0' else
            uc3_do when uc3_cs2_n = '0' else
            extram_do when extram_cs = '1' else
            (others => '1');
  cpu_irq_n <= uc1_irq_n and uc3_irq_n;
  cpu_so_n <= byte_n or not soe;
  
  cpu_inst : entity work.T65
    port map
    (
      Mode        => "00",
      Res_n       => not reset,
      Enable      => p2_h_f,
      Clk         => clk_32M,
      Rdy         => '1',
      Abort_n     => '1',
      IRQ_n       => cpu_irq_n,
      NMI_n       => '1',
      SO_n        => cpu_so_n,
      R_W_n       => cpu_rw_n,
      A           => cpu_a,
      DI          => cpu_di,
      DO          => cpu_do
    );

    ram_inst :  entity work.Gowin_SP_2k
    port map (
        dout => ram_do,
        clk => clk_32M,
        oce => '1',
        ce => '1',
        reset => reset,
        wre => ram_wr,
        ad => cpu_a(10 downto 0),
        din => cpu_do
    );

  uc1_pa_oe_n <= not uc1_pa_oe;
  uc1_pb_oe_n <= not uc1_pb_oe;
  uc1_irq_n   <= not uc1_irq;

  uc1_via6522_inst : entity work.via6522
    port map
    (
      clock           => clk_32M,
      rising          => p2_h_r,
      falling         => p2_h_f,
      reset           => reset,

      addr            => cpu_a(3 downto 0),
      wen             => not cpu_rw_n and not uc1_cs2_n,
      ren             => cpu_rw_n and not uc1_cs2_n,
      data_in         => cpu_do,
      data_out        => uc1_do,

      port_a_o        => uc1_pa_o,
      port_a_t        => uc1_pa_oe,
      port_a_i        => uc1_pa_i and (uc1_pa_o or not uc1_pa_oe),

      port_b_o        => uc1_pb_o,
      port_b_t        => uc1_pb_oe,
      port_b_i        => uc1_pb_i and (uc1_pb_o or not uc1_pb_oe),

      ca1_i           => not sb_atn_in,

      ca2_o           => uc1_ca2_o,
      ca2_t           => uc1_ca2_oe,
      ca2_i           => uc1_ca2_o or not uc1_ca2_oe,

      cb1_o           => uc1_cb1_o,
      cb1_t           => uc1_cb1_oe, 
      cb1_i           => cb1_i and (uc1_cb1_o or not uc1_cb1_oe),

      cb2_o           => uc1_cb2_o,
      cb2_t           => uc1_cb2_oe,
      cb2_i           => uc1_cb2_o or not uc1_cb2_oe,

      irq             => uc1_irq
    );

  uc3_irq_n    <= not uc3_irq;
  uc3_ca2_oe_n <= not uc3_ca2_oe;
  uc3_cb2_oe_n <= not uc3_cb2_oe;
  uc3_pa_oe_n  <= not uc3_pa_oe;
  uc3_pb_oe_n  <= not uc3_pb_oe;

  uc3_via6522_inst : entity work.via6522
    port map
    (
      clock           => clk_32M,
      rising          => p2_h_r,
      falling         => p2_h_f,
      reset           => reset,

      addr            => cpu_a(3 downto 0),
      wen             => not cpu_rw_n and not uc3_cs2_n,
      ren             => cpu_rw_n and not uc3_cs2_n,
      data_in         => cpu_do,
      data_out        => uc3_do,

      port_a_o        => uc3_pa_o,
      port_a_t        => uc3_pa_oe,
      port_a_i        => di and (uc3_pa_o or not uc3_pa_oe),

      port_b_o        => uc3_pb_o,
      port_b_t        => uc3_pb_oe,
      port_b_i        => uc3_pb_i and (uc3_pb_o or not uc3_pb_oe) ,

      ca1_i           => cpu_so_n,

      ca2_o           => uc3_ca2_o,
      ca2_t           => uc3_ca2_oe,
      ca2_i           => uc3_ca2_o or not uc3_ca2_oe,

      cb1_o           => uc3_cb1_o,
      cb1_t           => uc3_cb1_oe,
      cb1_i           => uc3_cb1_o or not uc3_cb1_oe,

      cb2_o           => uc3_cb2_o,
      cb2_t           => uc3_cb2_oe,
      cb2_i           => uc3_cb2_o or not uc3_cb2_oe,

      irq             => uc3_irq
    );
end SYN;
