-- ----------------------------------------------------------------------------	
-- FILE:	dither.vhd
-- DESCRIPTION:	Module that adds noise before truncating input to desired width.
-- DATE:	December 24, 2017
-- AUTHOR(s):	Jannik Springer (jannik.springer@rwth-aachen.de)
-- REVISIONS:	
-- ----------------------------------------------------------------------------	


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.helper_util.all;


entity psnr_dither is
	generic(
		LUT_AMPL_PREC	: integer := 16;	-- number of databits stored in LUT for amplitude
		DITHER_WIDTH	: integer := 4;
		OUT_WIDTH		: integer := 12		-- number of bits actually output (should be equal to DAC bits)
	);
	port(
		ClkxCI				: in  std_logic;
		RstxRBI				: in  std_logic;
		DitherEnxSI			: in  std_logic;
		
		AmplxDI				: in  std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
		DitherNoisexDI		: in  std_logic_vector((DITHER_WIDTH - 1) downto 0);
		
		AmplxDO				: out std_logic_vector((OUT_WIDTH - 1) downto 0)
	);
end psnr_dither;



architecture arch of psnr_dither is
	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------

	-- input buffer/delay
	signal AmplInxDP, AmplInxDN					: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal AmplInDelayxDP						: std_logic_vector((OUT_WIDTH - 1) downto 0);
	
	-- adder output
	signal SumxDP, SumxDN						: std_logic_vector((LUT_AMPL_PREC - 1)  downto 0);
	signal AmplDitheredxDP, AmplDitheredxDN		: std_logic_vector((OUT_WIDTH - 1) downto 0);
	
	-- output signal buffer
	signal AmplOutxDP, AmplOutxDN				: std_logic_vector((OUT_WIDTH - 1) downto 0);
begin
	
	
	------------------------------------------------------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
    -- ProcessName: p_sync_registers
    -- This process implements some registers.
    --------------------------------------------
	p_sync_registers : process(ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			AmplInxDP		<= (others => '0');
			SumxDP			<= (others => '0');
			AmplDitheredxDP	<= (others => '0');
			AmplOutxDP		<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			AmplInxDP		<= AmplInxDN;
			AmplInDelayxDP	<= AmplInxDP;
			SumxDP			<= SumxDN;
			AmplDitheredxDP	<= AmplDitheredxDN;
			AmplOutxDP		<= AmplOutxDN;
		end if;
	end process p_sync_registers;
	

	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------

	AmplInxDN <= AmplxDI(AmplxDI'left downto (LUT_AMPL_PREC - OUT_WIDTH));
	
	--------------------------------------------
    -- ProcessName: p_comb_dither_add
    -- This process implements an adder. It is used to add the dither
    -- noise to the input amplitude.
    --------------------------------------------
	p_comb_dither_add : process (AmplxDI, DitherNoisexDI)
		variable Ampl		: signed((LUT_AMPL_PREC - 1) downto 0);
		variable Dither		: signed((LUT_AMPL_PREC - 1) downto 0);
		variable Sum		: signed((LUT_AMPL_PREC - 1) downto 0);
	begin
		Ampl	:= signed(AmplxDI);
		Dither	:= signed(resize(unsigned(DitherNoisexDI), Dither'length));
		Sum		:= Ampl + Dither;
		
		SumxDN	<= std_logic_vector(Sum);
	end process;
	
	
	--------------------------------------------
    -- ProcessName: p_comb_saturate
    -- This process implements saturation logic for positive numbers.
    --------------------------------------------
	p_comb_saturate : process (AmplInxDP, SumxDP)
		constant MSB_POS	: natural := 15;
		variable Sum		: signed((LUT_AMPL_PREC - 1) downto 0);
	begin
		Sum	:= signed(SumxDP);
		
		-- saturate if a was positive and sum overflowed (both versions work)
		if AmplInxDP(AmplInxDP'left) = '0' and Sum(Sum'left) = '1' then
-- 			Sum := "0" & (Sum'left-1 downto 0 => '1');		--version 1
			Sum := (MSB_POS => '1', others => '0');			--version 2
			Sum := to_signed(2**(LUT_AMPL_PREC-1) - 1, LUT_AMPL_PREC);
		end if;	
		
		AmplDitheredxDN <= std_logic_vector(Sum(Sum'left downto (LUT_AMPL_PREC - OUT_WIDTH)));
	end process;
	
	
	--------------------------------------------
    -- ProcessName: p_comb_mux_dither
    -- This process implements an multiplexer that forwards either the dithered amplitude or
    -- simply the input value.
    --------------------------------------------
	p_comb_mux_dither : process(DitherEnxSI, AmplInxDP, AmplDitheredxDP)
	begin
		if DitherEnxSI = '1' then
			AmplOutxDN <= AmplDitheredxDP;
		else
			AmplOutxDN <= AmplInDelayxDP;
		end if;
	end process;

	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	AmplxDO	<= AmplOutxDP;		-- output dithered value

end arch;
