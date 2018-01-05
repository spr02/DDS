----------------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Author:  Jannik Springer
--          jannik.springer@rwth-aachen.de
----------------------------------------------------------------------------
-- 
-- Create Date:    
-- Design Name: 
-- Module Name:    
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--      
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity DelayLine is
	generic(
		DELAY_WIDTH		: integer := 16;
		DELAY_CYCLES	: integer := 5
	);
	port(
		ClkxCI      : in	std_logic;
		RstxRBI     : in	std_logic;

		EnablexSI	: in	std_logic;

		InputxDI		: in	std_logic_vector((DELAY_WIDTH - 1) downto 0);
		OutputxDO	: out	std_logic_vector((DELAY_WIDTH - 1) downto 0)
	);
end DelayLine;


architecture rtl of DelayLine is
	------------------------------------------------
	--	Signals and Types
	------------------------------------------------
	type delay_reg_type is array (0 to (DELAY_CYCLES - 1)) of std_logic_vector((DELAY_WIDTH - 1) downto 0);
	signal delay_regs : delay_reg_type;
begin
    
    -- add registers between input and output
    CYCLES_GREATER_ZERO : if DELAY_CYCLES > 0 generate
        ------------------------------------------------
        --	Synchronus process (sequential logic and registers)
        ------------------------------------------------
        p_sync : process (ClkxCI, RstxRBI)
        begin
            if RstxRBI = '0' then
                delay_regs <= (others => (others => '0'));
            elsif ClkxCI'event and ClkxCI = '1' then
                if (EnablexSI = '1') then
                    delay_regs(0) <= InputxDI;
                end if;
                
                for i in 0 to (DELAY_CYCLES - 2) loop
                    if (EnablexSI = '1') then
                        delay_regs(i + 1) <= delay_regs(i);
                    end if;
                end loop;
            end if;
        end process p_sync;
        
        ------------------------------------------------
        --	Output Assignment
        ------------------------------------------------
        OutputxDO <= delay_regs(DELAY_CYCLES - 1);
	end generate CYCLES_GREATER_ZERO;
	
	-- simply connect input and output
	CYCLES_EQUAL_ZERO : if DELAY_CYCLES = 0 generate
	    OutputxDO <= InputxDI;
	end generate CYCLES_EQUAL_ZERO;
	
end rtl;
