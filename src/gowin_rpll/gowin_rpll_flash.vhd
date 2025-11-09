library IEEE;
use IEEE.std_logic_1164.all;

entity Gowin_rPLL_flash is
    port (
        clkout: out std_logic;
        lock: out std_logic;
        clkoutp: out std_logic;
        clkoutd: out std_logic;
        clkin: in std_logic
    );
end Gowin_rPLL_flash;

architecture Behavioral of Gowin_rPLL_flash is

    signal clkoutd3_o: std_logic;
    signal gw_vcc: std_logic;
    signal gw_gnd: std_logic;
    signal FBDSEL_i: std_logic_vector(5 downto 0);
    signal IDSEL_i: std_logic_vector(5 downto 0);
    signal ODSEL_i: std_logic_vector(5 downto 0);
    signal PSDA_i: std_logic_vector(3 downto 0);
    signal DUTYDA_i: std_logic_vector(3 downto 0);
    signal FDLY_i: std_logic_vector(3 downto 0);

    --component declaration
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
    gw_vcc <= '1';
    gw_gnd <= '0';

    FBDSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    IDSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    ODSEL_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    PSDA_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    DUTYDA_i <= gw_gnd & gw_gnd & gw_gnd & gw_gnd;
    FDLY_i <= gw_vcc & gw_vcc & gw_vcc & gw_vcc;

    rpll_inst: rPLL
        generic map (
            FCLKIN => "27",
            DEVICE => "GW2AR-18C",
            DYN_IDIV_SEL => "false",
            IDIV_SEL => 7,
            DYN_FBDIV_SEL => "false",
            FBDIV_SEL => 18,
            DYN_ODIV_SEL => "false",
            ODIV_SEL => 8,
            PSDA_SEL => "1000",
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
            CLKOUT => clkout,
            LOCK => lock,
            CLKOUTP => clkoutp,
            CLKOUTD => clkoutd,
            CLKOUTD3 => clkoutd3_o,
            RESET => gw_gnd,
            RESET_P => gw_gnd,
            CLKIN => clkin,
            CLKFB => gw_gnd,
            FBDSEL => FBDSEL_i,
            IDSEL => IDSEL_i,
            ODSEL => ODSEL_i,
            PSDA => PSDA_i,
            DUTYDA => DUTYDA_i,
            FDLY => FDLY_i
        );

end Behavioral; --Gowin_rPLL_flash
