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
-- 		This is a simple LFSR which generates a pseudo random sequence, it can be loaded with a seed for better randomness
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity RandomGenerator is
		generic(
			RND_WIDTH		: integer := 9;
			INITIAL_SEED	: integer := 12
		);
		port(
			ClkxCI      : in	std_logic;
			RstxRBI     : in	std_logic;

            EnablexSI   : in    std_logic;
            
            -- load seed
            LoadxSI     : in    std_logic;
            SeedxDI     : in    std_logic_vector((RND_WIDTH - 1) downto 0);
            
            -- output
			RndOutxDO	: out	std_logic_vector((RND_WIDTH - 1) downto 0)
		);
end RandomGenerator;


architecture rtl of RandomGenerator is
    ------------------------------------------------
	--	Components
	------------------------------------------------
    component lfsr
            generic(
                RND_WIDTH        : integer := 9;
                INITIAL_SEED     : integer := 13;
                LFSR_POLY        : std_logic_vector := "000010000"
            );
            port(
                ClkxCI      : in    std_logic;
                RstxRBI     : in    std_logic;
    
                EnablexSI   : in    std_logic;
                
                -- load seed
                LoadxSI     : in    std_logic;
                SeedxDI     : in    std_logic_vector((RND_WIDTH - 1) downto 0);
    
                -- output
                RndOutxDO    : out    std_logic_vector((RND_WIDTH - 1) downto 0)
            );
    end component;
    
    ------------------------------------------------
    --    functions
    ------------------------------------------------
    function get_lfsr_poly (w : integer) return std_logic_vector is
        variable poly_slv : std_logic_vector(0 to w - 1);
    begin
        case w is
            when 2 =>       poly_slv := "11";
            when 3 =>       poly_slv := "111";
            when 4 =>       poly_slv := "1001";
            when 5 =>       poly_slv := "10010";
            when 6 =>       poly_slv := "100001";
            when 7 =>       poly_slv := "1000001";
            when 8 =>       poly_slv := "10001110";
            when 9 =>       poly_slv := "100001000";
            when 10 =>      poly_slv := "1000000100";
            when others =>  poly_slv := (others => '0');
        end case;
        return poly_slv;
    end function;

begin
    
    ------------------------------------------------
	--	Instances
	------------------------------------------------
    RND0: LFSR
    generic map(
        RND_WIDTH        => RND_WIDTH,
        INITIAL_SEED     => INITIAL_SEED,
        LFSR_POLY        => get_lfsr_poly(RND_WIDTH)
    )
    port map(
        ClkxCI      => ClkxCI,
        RstxRBI     => RstxRBI,
        EnablexSI   => EnablexSI,
        LoadxSI     => LoadxSI,
        SeedxDI     => SeedxDI,
        RndOutxDO   => RndOutxDO
    );
    
    
    ------------------------------------------------
	--	Output Assignment
	------------------------------------------------
end rtl;