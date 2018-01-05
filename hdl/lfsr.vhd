----------------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Author:  Jannik Springer
--		  jannik.springer@rwth-aachen.de
----------------------------------------------------------------------------
-- 
-- Create Date:	
-- Design Name: 
-- Module Name:	
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
-- 		This is a simple LFSR which generates a pseudo random sequence, it can be loaded with a seed for better randomness
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
-- Polynomial can be looked up e.g. at https://www.xilinx.com/support/documentation/application_notes/xapp210.pdf
-- The format of the generic LSFR_POLY is "x^0 x^1 ... x^(N-1)" note that x^N does not have to be set as it will be set
-- implicitly!
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity LFSR is
		generic(
			RND_WIDTH		: integer := 9;
			INITIAL_SEED	: integer := 13;
			LFSR_POLY		: std_logic_vector := "100001000"
		);
		port(
			ClkxCI		: in	std_logic;
			RstxRBI	 	: in	std_logic;

			EnablexSI	: in	std_logic;
			
			-- load seed
			LoadxSI		: in	std_logic;
			SeedxDI		: in	std_logic_vector((RND_WIDTH - 1) downto 0);

			-- output
			RndOutxDO	: out	std_logic_vector((RND_WIDTH - 1) downto 0)
		);
end LFSR;


architecture rtl of LFSR is
	------------------------------------------------
	--	Signals
	------------------------------------------------	
	signal RndOutxDP, RndOutxDN	: std_logic_vector((RND_WIDTH - 1) downto 0);
begin

	------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------
	p_sync : process (ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			RndOutxDP <= std_logic_vector(to_unsigned(INITIAL_SEED, RndOutxDP'length));
		elsif ClkxCI'event and ClkxCI = '1' then
			if (LoadxSI = '1') then
				RndOutxDP <= SeedxDI;
			else
				if (EnablexSI = '1') then
					RndOutxDP <= RndOutxDN;
				end if;
			end if;
		end if;
	end process p_sync;

	------------------------------------------------
	--	Combinatorical process (feed back logic)
	------------------------------------------------
   	p_comb_FEED_BACK : process (RndOutxDP)
	   variable FeedbackxD	 : std_logic;
	begin
-- 		-- This can be used to generate the value zero.
-- 		if (to_integer(unsigned(RndOutxDP(RND_WIDTH - 1 downto 1))) = 0) then
-- 			FeedbackxD := not RndOutxDP(0);
-- 		else
-- 			FeedbackxD := RndOutxDP(0);
-- 		end if;
		FeedbackxD := RndOutxDP(0);
		
		RndOutxDN(RND_WIDTH - 1) <= FeedbackxD;		-- LSB connects to MSB
		for I in (RND_WIDTH - 1) downto 1 loop
			if (LFSR_POLY(RND_WIDTH - I) = '1') then
				RndOutxDN(I - 1) <= RndOutxDP(I) xor FeedbackxD;
			else
				RndOutxDN(I - 1) <= RndOutxDP(I);
			end if;
		end loop;
	end process p_comb_FEED_BACK;


	------------------------------------------------
	--	Output Assignment
	------------------------------------------------
	RndOutxDO <= RndOutxDP;

end rtl;
