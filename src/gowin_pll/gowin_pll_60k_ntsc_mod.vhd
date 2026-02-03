
library IEEE;
use IEEE.std_logic_1164.all;

entity Gowin_PLL_60k_ntsc_MOD is
    port (
        lock: out std_logic;
        clkout0: out std_logic;
        clkout1: out std_logic;
        clkout2: out std_logic;
        mdrdo: out std_logic_vector(7 downto 0);
        clkin: in std_logic;
        reset: in std_logic;
        mdclk: in std_logic;
        mdopc: in std_logic_vector(1 downto 0);
        mdainc: in std_logic;
        mdwdi: in std_logic_vector(7 downto 0)
    );
end Gowin_PLL_60k_ntsc_MOD;

architecture Behavioral of Gowin_PLL_60k_ntsc_MOD is

    signal clkout3: std_logic;
    signal clkout4: std_logic;
    signal clkout5: std_logic;
    signal clkout6: std_logic;
    signal clkfbout: std_logic;
    signal gw_gnd: std_logic;
    signal PSSEL_i: std_logic_vector(2 downto 0);
    signal SSCMDSEL_i: std_logic_vector(6 downto 0);
    signal SSCMDSEL_FRAC_i: std_logic_vector(2 downto 0);

    --component declaration
    component PLLA
        generic (
            FCLKIN: string := "100.0";
            IDIV_SEL: integer := 1;
            FBDIV_SEL: integer := 1;
            ODIV0_SEL: integer := 8;
            ODIV0_FRAC_SEL: integer := 0;
            ODIV1_SEL: integer := 8;
            ODIV2_SEL: integer := 8;
            ODIV3_SEL: integer := 8;
            ODIV4_SEL: integer := 8;
            ODIV5_SEL: integer := 8;
            ODIV6_SEL: integer := 8;
            MDIV_SEL: integer := 8;
            MDIV_FRAC_SEL: integer := 0;
            CLKOUT0_EN: string := "FALSE";
            CLKOUT1_EN: string := "FALSE";
            CLKOUT2_EN: string := "FALSE";
            CLKOUT3_EN: string := "FALSE";
            CLKOUT4_EN: string := "FALSE";
            CLKOUT5_EN: string := "FALSE";
            CLKOUT6_EN: string := "FALSE";
            CLKFB_SEL: string := "internal";
            CLKOUT0_DT_DIR: bit := '1';
            CLKOUT1_DT_DIR: bit := '1';
            CLKOUT2_DT_DIR: bit := '1';
            CLKOUT3_DT_DIR: bit := '1';
            CLKOUT0_DT_STEP: integer := 0;
            CLKOUT1_DT_STEP: integer := 0;
            CLKOUT2_DT_STEP: integer := 0;
            CLKOUT3_DT_STEP: integer := 0;
            CLK0_IN_SEL: bit := '0';
            CLK0_OUT_SEL: bit := '0';
            CLK1_IN_SEL: bit := '0';
            CLK1_OUT_SEL: bit := '0';
            CLK2_IN_SEL: bit := '0';
            CLK2_OUT_SEL: bit := '0';
            CLK3_IN_SEL: bit := '0';
            CLK3_OUT_SEL: bit := '0';
            CLK4_IN_SEL: bit_vector := "00";
            CLK4_OUT_SEL: bit := '0';
            CLK5_IN_SEL: bit := '0';
            CLK5_OUT_SEL: bit := '0';
            CLK6_IN_SEL: bit := '0';
            CLK6_OUT_SEL: bit := '0';
            CLKOUT0_PE_COARSE: integer := 0;
            CLKOUT0_PE_FINE: integer := 0;
            CLKOUT1_PE_COARSE: integer := 0;
            CLKOUT1_PE_FINE: integer := 0;
            CLKOUT2_PE_COARSE: integer := 0;
            CLKOUT2_PE_FINE: integer := 0;
            CLKOUT3_PE_COARSE: integer := 0;
            CLKOUT3_PE_FINE: integer := 0;
            CLKOUT4_PE_COARSE: integer := 0;
            CLKOUT4_PE_FINE: integer := 0;
            CLKOUT5_PE_COARSE: integer := 0;
            CLKOUT5_PE_FINE: integer := 0;
            CLKOUT6_PE_COARSE: integer := 0;
            CLKOUT6_PE_FINE: integer := 0;
            DE0_EN: string := "FALSE";
            DE1_EN: string := "FALSE";
            DE2_EN: string := "FALSE";
            DE3_EN: string := "FALSE";
            DE4_EN: string := "FALSE";
            DE5_EN: string := "FALSE";
            DE6_EN: string := "FALSE";
            DYN_DPA_EN: string := "FALSE";
            DYN_PE0_SEL: string := "FALSE";
            DYN_PE1_SEL: string := "FALSE";
            DYN_PE2_SEL: string := "FALSE";
            DYN_PE3_SEL: string := "FALSE";
            DYN_PE4_SEL: string := "FALSE";
            DYN_PE5_SEL: string := "FALSE";
            DYN_PE6_SEL: string := "FALSE";
            ICP_SEL : std_logic_vector(5 downto 0) := "XXXXXX";
            LPF_RES : std_logic_vector(2 downto 0) := "XXX";
            LPF_CAP: bit_vector := "00";
            RESET_I_EN: string := "FALSE";
            RESET_O_EN: string := "FALSE";
            SSC_EN: string := "FALSE"
        );
        port (
            LOCK: out std_logic;
            CLKOUT0: out std_logic;
            CLKOUT1: out std_logic;
            CLKOUT2: out std_logic;
            CLKOUT3: out std_logic;
            CLKOUT4: out std_logic;
            CLKOUT5: out std_logic;
            CLKOUT6: out std_logic;
            CLKFBOUT: out std_logic;
            MDRDO: out std_logic_vector(7 downto 0);
            CLKIN: in std_logic;
            CLKFB: in std_logic;
            RESET: in std_logic;
            PLLPWD: in std_logic;
            RESET_I: in std_logic;
            RESET_O: in std_logic;
            PSSEL: in std_logic_vector(2 downto 0);
            PSDIR: in std_logic;
            PSPULSE: in std_logic;
            SSCPOL: in std_logic;
            SSCON: in std_logic;
            SSCMDSEL: in std_logic_vector(6 downto 0);
            SSCMDSEL_FRAC: in std_logic_vector(2 downto 0);
            MDCLK: in std_logic;
            MDOPC: in std_logic_vector(1 downto 0);
            MDAINC: in std_logic;
            MDWDI: in std_logic_vector(7 downto 0)
        );
    end component;
begin
    gw_gnd <= '0';

    PSSEL_i <= gw_gnd & gw_gnd & gw_gnd;
    SSCMDSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    SSCMDSEL_FRAC_i <= gw_gnd & gw_gnd & gw_gnd;

    PLLA_inst: PLLA
        generic map (
            FCLKIN => "50",
            IDIV_SEL => 2,
            FBDIV_SEL => 1,
            ODIV0_SEL => 3,
            ODIV1_SEL => 6,
            ODIV2_SEL => 15,
            ODIV3_SEL => 8,
            ODIV4_SEL => 8,
            ODIV5_SEL => 8,
            ODIV6_SEL => 8,
            MDIV_SEL => 39,
            MDIV_FRAC_SEL => 2,
            ODIV0_FRAC_SEL => 0,
            CLKOUT0_EN => "TRUE",
            CLKOUT1_EN => "TRUE",
            CLKOUT2_EN => "TRUE",
            CLKOUT3_EN => "FALSE",
            CLKOUT4_EN => "FALSE",
            CLKOUT5_EN => "FALSE",
            CLKOUT6_EN => "FALSE",
            CLKFB_SEL => "INTERNAL",
            CLKOUT0_DT_DIR => '1',
            CLKOUT1_DT_DIR => '1',
            CLKOUT2_DT_DIR => '1',
            CLKOUT3_DT_DIR => '1',
            CLKOUT0_DT_STEP => 0,
            CLKOUT1_DT_STEP => 0,
            CLKOUT2_DT_STEP => 0,
            CLKOUT3_DT_STEP => 0,
            CLK0_IN_SEL => '0',
            CLK0_OUT_SEL => '0',
            CLK1_IN_SEL => '0',
            CLK1_OUT_SEL => '0',
            CLK2_IN_SEL => '0',
            CLK2_OUT_SEL => '0',
            CLK3_IN_SEL => '0',
            CLK3_OUT_SEL => '0',
            CLK4_IN_SEL => "00",
            CLK4_OUT_SEL => '0',
            CLK5_IN_SEL => '0',
            CLK5_OUT_SEL => '0',
            CLK6_IN_SEL => '0',
            CLK6_OUT_SEL => '0',
            DYN_DPA_EN => "FALSE",
            CLKOUT0_PE_COARSE => 0,
            CLKOUT0_PE_FINE => 0,
            CLKOUT1_PE_COARSE => 0,
            CLKOUT1_PE_FINE => 0,
            CLKOUT2_PE_COARSE => 0,
            CLKOUT2_PE_FINE => 0,
            CLKOUT3_PE_COARSE => 0,
            CLKOUT3_PE_FINE => 0,
            CLKOUT4_PE_COARSE => 0,
            CLKOUT4_PE_FINE => 0,
            CLKOUT5_PE_COARSE => 0,
            CLKOUT5_PE_FINE => 0,
            CLKOUT6_PE_COARSE => 0,
            CLKOUT6_PE_FINE => 0,
            DYN_PE0_SEL => "FALSE",
            DYN_PE1_SEL => "FALSE",
            DYN_PE2_SEL => "FALSE",
            DYN_PE3_SEL => "FALSE",
            DYN_PE4_SEL => "FALSE",
            DYN_PE5_SEL => "FALSE",
            DYN_PE6_SEL => "FALSE",
            DE0_EN => "FALSE",
            DE1_EN => "FALSE",
            DE2_EN => "FALSE",
            DE3_EN => "FALSE",
            DE4_EN => "FALSE",
            DE5_EN => "FALSE",
            DE6_EN => "FALSE",
            RESET_I_EN => "FALSE",
            RESET_O_EN => "FALSE",
            ICP_SEL => "XXXXXX",
            LPF_RES => "XXX",
            LPF_CAP => "00",
            SSC_EN => "FALSE"
        )
        port map (
            LOCK => lock,
            CLKOUT0 => clkout0,
            CLKOUT1 => clkout1,
            CLKOUT2 => clkout2,
            CLKOUT3 => clkout3,
            CLKOUT4 => clkout4,
            CLKOUT5 => clkout5,
            CLKOUT6 => clkout6,
            CLKFBOUT => clkfbout,
            MDRDO => mdrdo,
            CLKIN => clkin,
            CLKFB => gw_gnd,
            RESET => reset,
            PLLPWD => gw_gnd,
            RESET_I => gw_gnd,
            RESET_O => gw_gnd,
            PSSEL => PSSEL_i,
            PSDIR => gw_gnd,
            PSPULSE => gw_gnd,
            SSCPOL => gw_gnd,
            SSCON => gw_gnd,
            SSCMDSEL => SSCMDSEL_i,
            SSCMDSEL_FRAC => SSCMDSEL_FRAC_i,
            MDCLK => mdclk,
            MDOPC => mdopc,
            MDAINC => mdainc,
            MDWDI => mdwdi
        );

end Behavioral; --Gowin_PLL_60k_ntsc_MOD
