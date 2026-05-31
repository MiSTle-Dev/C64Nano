-- Baud Rate Generator

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY BaudRate IS
	GENERIC (
		BAUD_RATE	: integer := 230400
	);
	PORT (
      i_CLOCK     : IN std_logic;
      o_serialEn  : OUT std_logic
	);
END BaudRate;

ARCHITECTURE BaudRate_beh OF BaudRate IS

	signal w_serialCount   	: unsigned(15 downto 0);
	signal w_serialCount_d	: unsigned(15 downto 0);

BEGIN
	BAUD_230400: if (BAUD_RATE=230400) generate
		begin	
		baud_div: process (w_serialCount)
			 begin
				  w_serialCount_d <= w_serialCount + to_unsigned(7670, w_serialCount'length);  -- 31.5Mhz 
			 end process;
	end generate BAUD_230400;

	BAUD_115200: if (BAUD_RATE=115200) generate
		begin	
		baud_div: process (w_serialCount)
			 begin
				  w_serialCount_d <= w_serialCount + to_unsigned(1887, w_serialCount'length); -- 64Mhz
			 end process;
	end generate BAUD_115200;
		 
	BAUD_38400: if (BAUD_RATE=38400) generate
		begin	
		baud_div: process (w_serialCount)
			 begin
				  w_serialCount_d <= w_serialCount + to_unsigned(805, w_serialCount'length);
			 end process;
	end generate BAUD_38400;

		 
	process (i_CLOCK)
		begin
			if rising_edge(i_CLOCK) then
			  w_serialCount <= w_serialCount_d;
			  if w_serialCount(15) = '0' and w_serialCount_d(15) = '1' then
					o_serialEn <= '1';
			  else
					o_serialEn <= '0';
			  end if;
			end if;
		end process;

END BaudRate_beh;
