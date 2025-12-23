--Copyright (C)2014-2025 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: IP file
--Tool Version: V1.9.12 (64-bit)
--Part Number: GW5AST-LV138FPG676AC1/I0
--Device: GW5AST-138
--Device Version: B
--Created Time: Sat Dec 20 13:09:21 2025

library IEEE;
use IEEE.std_logic_1164.all;

entity Gowin_OSC is
    port (
        oscout: out std_logic
    );
end Gowin_OSC;

architecture Behavioral of Gowin_OSC is

    --component declaration
    component OSC
        generic (
            FREQ_DIV: in integer := 100
        );
        port (
            OSCOUT: out std_logic
        );
    end component;

begin
    osc_inst: OSC
        generic map (
            FREQ_DIV => 10
        )
        port map (
            OSCOUT => oscout
        );

end Behavioral; --Gowin_OSC
