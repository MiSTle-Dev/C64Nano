--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: IP file
--Tool Version: V1.9.9.01 (64-bit)
--Part Number: GW5AST-LV138FPG676AES
--Device: GW5AST-138B
--Device Version: B
--Created Time: Fri Mar  1 21:02:59 2024

library IEEE;
use IEEE.std_logic_1164.all;

entity Gowin_PLL_138k_pal is
    port (
        lock: out std_logic;
        clkout0: out std_logic;
        clkout1: out std_logic;
        clkout2: out std_logic;
        clkout3: out std_logic;
        clkin: in std_logic
    );
end Gowin_PLL_138k_pal;

architecture Behavioral of Gowin_PLL_138k_pal is

    signal clkout4: std_logic;
    signal clkout5: std_logic;
    signal clkout6: std_logic;
    signal clkfbout: std_logic;
    signal gw_vcc: std_logic;
    signal gw_gnd: std_logic;
    signal FBDSEL_i: std_logic_vector(5 downto 0);
    signal IDSEL_i: std_logic_vector(5 downto 0);
    signal MDSEL_i: std_logic_vector(6 downto 0);
    signal MDSEL_FRAC_i: std_logic_vector(2 downto 0);
    signal ODSEL0_i: std_logic_vector(6 downto 0);
    signal ODSEL0_FRAC_i: std_logic_vector(2 downto 0);
    signal ODSEL1_i: std_logic_vector(6 downto 0);
    signal ODSEL2_i: std_logic_vector(6 downto 0);
    signal ODSEL3_i: std_logic_vector(6 downto 0);
    signal ODSEL4_i: std_logic_vector(6 downto 0);
    signal ODSEL5_i: std_logic_vector(6 downto 0);
    signal ODSEL6_i: std_logic_vector(6 downto 0);
    signal DT0_i: std_logic_vector(3 downto 0);
    signal DT1_i: std_logic_vector(3 downto 0);
    signal DT2_i: std_logic_vector(3 downto 0);
    signal DT3_i: std_logic_vector(3 downto 0);
    signal ICPSEL_i: std_logic_vector(5 downto 0);
    signal LPFRES_i: std_logic_vector(2 downto 0);
    signal LPFCAP_i: std_logic_vector(1 downto 0);
    signal PSSEL_i: std_logic_vector(2 downto 0);
    signal SSCMDSEL_i: std_logic_vector(6 downto 0);
    signal SSCMDSEL_FRAC_i: std_logic_vector(2 downto 0);

    --component declaration
    component PLL
        generic (
            DYN_IDIV_SEL: string := "FALSE";
            DYN_FBDIV_SEL: string := "FALSE";
            DYN_ODIV0_SEL: string := "FALSE";
            DYN_ODIV1_SEL: string := "FALSE";
            DYN_ODIV2_SEL: string := "FALSE";
            DYN_ODIV3_SEL: string := "FALSE";
            DYN_ODIV4_SEL: string := "FALSE";
            DYN_ODIV5_SEL: string := "FALSE";
            DYN_ODIV6_SEL: string := "FALSE";
            DYN_MDIV_SEL: string := "FALSE";
            DYN_DT0_SEL: string := "TRUE";
            DYN_DT1_SEL: string := "FALSE";
            DYN_DT2_SEL: string := "FALSE";
            DYN_DT3_SEL: string := "FALSE";
            DYN_ICP_SEL: string := "FALSE";
            DYN_LPF_SEL: string := "FALSE";
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
            CLKIN: in std_logic;
            CLKFB: in std_logic;
            RESET: in std_logic;
            PLLPWD: in std_logic;
            RESET_I: in std_logic;
            RESET_O: in std_logic;
            FBDSEL: in std_logic_vector(5 downto 0);
            IDSEL: in std_logic_vector(5 downto 0);
            MDSEL: in std_logic_vector(6 downto 0);
            MDSEL_FRAC: in std_logic_vector(2 downto 0);
            ODSEL0: in std_logic_vector(6 downto 0);
            ODSEL0_FRAC: in std_logic_vector(2 downto 0);
            ODSEL1: in std_logic_vector(6 downto 0);
            ODSEL2: in std_logic_vector(6 downto 0);
            ODSEL3: in std_logic_vector(6 downto 0);
            ODSEL4: in std_logic_vector(6 downto 0);
            ODSEL5: in std_logic_vector(6 downto 0);
            ODSEL6: in std_logic_vector(6 downto 0);
            DT0: in std_logic_vector(3 downto 0);
            DT1: in std_logic_vector(3 downto 0);
            DT2: in std_logic_vector(3 downto 0);
            DT3: in std_logic_vector(3 downto 0);
            ICPSEL: in std_logic_vector(5 downto 0);
            LPFRES: in std_logic_vector(2 downto 0);
            LPFCAP: in std_logic_vector(1 downto 0);
            PSSEL: in std_logic_vector(2 downto 0);
            PSDIR: in std_logic;
            PSPULSE: in std_logic;
            ENCLK0: in std_logic;
            ENCLK1: in std_logic;
            ENCLK2: in std_logic;
            ENCLK3: in std_logic;
            ENCLK4: in std_logic;
            ENCLK5: in std_logic;
            ENCLK6: in std_logic;
            SSCPOL: in std_logic;
            SSCON: in std_logic;
            SSCMDSEL: in std_logic_vector(6 downto 0);
            SSCMDSEL_FRAC: in std_logic_vector(2 downto 0)
        );
    end component;
begin
    gw_vcc <= '1';
    gw_gnd <= '0';

    FBDSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    IDSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    MDSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    MDSEL_FRAC_i <= gw_gnd & gw_gnd & gw_gnd;
    ODSEL0_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    ODSEL0_FRAC_i <= gw_gnd & gw_gnd & gw_gnd;
    ODSEL1_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    ODSEL2_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    ODSEL3_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    ODSEL4_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    ODSEL5_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    ODSEL6_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    DT0_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    DT1_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    DT2_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    DT3_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    ICPSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    LPFRES_i <= gw_gnd & gw_gnd & gw_gnd;
    LPFCAP_i <= gw_gnd & gw_gnd;
    PSSEL_i <= gw_gnd & gw_gnd & gw_gnd;
    SSCMDSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    SSCMDSEL_FRAC_i <= gw_gnd & gw_gnd & gw_gnd;

    PLL_inst: PLL
        generic map (
            FCLKIN => "50",
            IDIV_SEL => 2,
            FBDIV_SEL => 1,
            ODIV0_SEL => 5,
            ODIV1_SEL => 10,
            ODIV2_SEL => 25,
            ODIV3_SEL => 50,
            ODIV4_SEL => 8,
            ODIV5_SEL => 8,
            ODIV6_SEL => 8,
            MDIV_SEL => 63,
            MDIV_FRAC_SEL => 0,
            ODIV0_FRAC_SEL => 0,
            CLKOUT0_EN => "TRUE",
            CLKOUT1_EN => "TRUE",
            CLKOUT2_EN => "TRUE",
            CLKOUT3_EN => "TRUE",
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
            SSC_EN => "FALSE",
            DYN_IDIV_SEL => "FALSE",
            DYN_FBDIV_SEL => "FALSE",
            DYN_MDIV_SEL => "FALSE",
            DYN_ODIV0_SEL => "FALSE",
            DYN_ODIV1_SEL => "FALSE",
            DYN_ODIV2_SEL => "FALSE",
            DYN_ODIV3_SEL => "FALSE",
            DYN_ODIV4_SEL => "FALSE",
            DYN_ODIV5_SEL => "FALSE",
            DYN_ODIV6_SEL => "FALSE",
            DYN_DT0_SEL => "FALSE",
            DYN_DT1_SEL => "FALSE",
            DYN_DT2_SEL => "FALSE",
            DYN_DT3_SEL => "FALSE",
            DYN_ICP_SEL => "FALSE",
            DYN_LPF_SEL => "FALSE"
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
            CLKIN => clkin,
            CLKFB => gw_gnd,
            RESET => gw_gnd,
            PLLPWD => gw_gnd,
            RESET_I => gw_gnd,
            RESET_O => gw_gnd,
            FBDSEL => FBDSEL_i,
            IDSEL => IDSEL_i,
            MDSEL => MDSEL_i,
            MDSEL_FRAC => MDSEL_FRAC_i,
            ODSEL0 => ODSEL0_i,
            ODSEL0_FRAC => ODSEL0_FRAC_i,
            ODSEL1 => ODSEL1_i,
            ODSEL2 => ODSEL2_i,
            ODSEL3 => ODSEL3_i,
            ODSEL4 => ODSEL4_i,
            ODSEL5 => ODSEL5_i,
            ODSEL6 => ODSEL6_i,
            DT0 => DT0_i,
            DT1 => DT1_i,
            DT2 => DT2_i,
            DT3 => DT3_i,
            ICPSEL => ICPSEL_i,
            LPFRES => LPFRES_i,
            LPFCAP => LPFCAP_i,
            PSSEL => PSSEL_i,
            PSDIR => gw_gnd,
            PSPULSE => gw_gnd,
            ENCLK0 => gw_vcc,
            ENCLK1 => gw_vcc,
            ENCLK2 => gw_vcc,
            ENCLK3 => gw_vcc,
            ENCLK4 => gw_vcc,
            ENCLK5 => gw_vcc,
            ENCLK6 => gw_vcc,
            SSCPOL => gw_gnd,
            SSCON => gw_gnd,
            SSCMDSEL => SSCMDSEL_i,
            SSCMDSEL_FRAC => SSCMDSEL_FRAC_i
        );

end Behavioral; --Gowin_PLL_138k_pal
