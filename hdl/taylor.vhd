-- ----------------------------------------------------------------------------	
-- FILE:	dds_core.vhd
-- DESCRIPTION:	Serial configuration interface to control DDS and signal generator modules
-- DATE:	December 24, 2017
-- AUTHOR(s):	Jannik Springer (jannik.springer@rwth-aachen.de)
-- REVISIONS:	
-- ----------------------------------------------------------------------------	


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.helper_util.all;


entity taylor_interpolation is
	generic(
		LUT_AMPL_PREC	: integer := 16;	-- number of databits stored in LUT for amplitude
		LUT_GRAD_PREC	: integer := 5;		-- number of databist stored in LUT for gradient (slope)
		CORR_WIDTH		: integer := 16;	-- number of bits used from the multiplier
		GRAD_WIDTH		: integer := 22;	-- number of bits of phase accumulator (LSBs -> PHASE_WIDTH - LUT_DEPTH)
		OUT_WIDTH		: integer := 12		-- number of bits actually output (should be equal to DAC bits)
	);
	port(
		ClkxCI				: in  std_logic;
		RstxRBI				: in  std_logic;
		
		AmplxDI				: in  std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
		SlopexDI			: in  std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
		GradxDI				: in  std_logic_vector((GRAD_WIDTH - 1) downto 0);
		
		AmplxDO				: out std_logic_vector((OUT_WIDTH - 1) downto 0)
	);
end taylor_interpolation;



architecture arch of taylor_interpolation is
	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------
	-- taylor series correction
	signal CorrxDP, CorrxDN		: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal AmplInxDP			: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);

	-- output signals
	signal AmplxDN, AmplxDP		: std_logic_vector((OUT_WIDTH - 1) downto 0);
begin
	
	
	------------------------------------------------------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
    -- ProcessName: p_sync_phase_accumulator
    -- This process implements the phase accumulator.
    --------------------------------------------
	p_sync_registers : process(ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			CorrxDP			<= (others => '0');
			AmplxDP			<= (others => '0');
			AmplInxDP		<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			CorrxDP			<= CorrxDN;
			AmplxDP			<= AmplxDN;
			AmplInxDP		<= AmplxDI;	-- delay AmplxDI by one cylce to account for latency of multiplier
		end if;
	end process p_sync_registers;
	

	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------

	--------------------------------------------
    -- ProcessName: p_comb_correction
    -- This process implements a multiplier, that is used to calculate the taylor correction value.
    --------------------------------------------
	p_comb_correction : process(SlopexDI, GradxDI)
		constant PosMSB			: integer := LUT_GRAD_PREC + GRAD_WIDTH; --16+32-10 = 38
		constant PosLSB			: integer := LUT_GRAD_PREC + GRAD_WIDTH - CORR_WIDTH; --16+32-10-16 = 22
		variable PhaseGrad		: signed(GRAD_WIDTH downto 0); -- 25
		variable LutSlope		: signed((LUT_GRAD_PREC - 1) downto 0); -- 16
		variable Correction		: signed((LUT_GRAD_PREC + GRAD_WIDTH) downto 0); --16+32-8+1 = 41
	begin
		Correction		:= (others => '0');
		LutSlope		:= signed(SlopexDI);
		PhaseGrad		:= signed("0" & GradxDI); -- get the LSBs of the PhaseAccQ
	
		Correction		:= LutSlope * PhaseGrad;
		CorrxDN			<= std_logic_vector(Correction((PosMSB - 1) downto PosLSB));
	end process p_comb_correction;
	
	--------------------------------------------
    -- ProcessName: p_comb_taylor
    -- This process implements the optional linear interpolation of the output samples.
    --------------------------------------------
	p_comb_taylor : process (AmplInxDP, CorrxDP)
		variable CorrAmpl		: signed((LUT_AMPL_PREC - 1) downto 0);
		variable LutAmpl		: signed((LUT_AMPL_PREC - 1) downto 0);
		variable Correction		: signed((CORR_WIDTH - 1) downto 0);
	begin
		CorrAmpl	:= (others => '0');
		Correction	:= signed(CorrxDP);
		LutAmpl		:= signed(AmplInxDP);
	
		CorrAmpl	:= LutAmpl + Correction;

		AmplxDN <= std_logic_vector(CorrAmpl((LUT_AMPL_PREC - 1)  downto (LUT_AMPL_PREC - OUT_WIDTH)));
	end process p_comb_taylor;

	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	AmplxDO	<= AmplxDP;		-- output taylor corrected amplitude

end arch;
