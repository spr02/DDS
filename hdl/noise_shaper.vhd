-- ----------------------------------------------------------------------------	
-- FILE:	noise_shaper.vhd
-- DESCRIPTION:	Combination of linear interpolation and dithering in a single datapath.
-- DATE:	December 24, 2017
-- AUTHOR(s):	Jannik Springer (jannik.springer@rwth-aachen.de)
-- REVISIONS:	
-- ----------------------------------------------------------------------------	


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.helper_util.all;


entity noise_shaper is
	generic(
		LUT_AMPL_PREC	: integer := 16;	-- number of databits stored in LUT for amplitude
		LUT_GRAD_PREC	: integer := 5;		-- number of databist stored in LUT for gradient (slope)
		CORR_WIDTH		: integer := 16;	-- number of bits used from the multiplier
		GRAD_WIDTH		: integer := 22;	-- number of bits of phase accumulator (LSBs -> PHASE_WIDTH - LUT_DEPTH)
		DITHER_WIDTH	: integer := 4;
		OUT_WIDTH		: integer := 12		-- number of bits actually output (should be equal to DAC bits)
	);
	port(
		ClkxCI				: in  std_logic;
		RstxRBI				: in  std_logic;
		DitherEnxSI			: in  std_logic;
		TaylorEnxSI			: in  std_logic;
		
		AmplxDI				: in  std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
		SlopexDI			: in  std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
		GradxDI				: in  std_logic_vector((GRAD_WIDTH - 1) downto 0);
		DitherNoisexDI		: in  std_logic_vector((DITHER_WIDTH - 1) downto 0);
		
		AmplxDO				: out std_logic_vector((OUT_WIDTH - 1) downto 0)
	);
end noise_shaper;



architecture arch of noise_shaper is
	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------

	-- adder output
	signal TaylorCorrectedxD			: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal AmplxD 						: std_logic_vector((OUT_WIDTH - 1) downto 0);
begin
	------------------------------------------------------------------------------------------------
	--	Instantiate Components
	------------------------------------------------------------------------------------------------
	
	TAYLOR0 : entity work.taylor_interpolation(arch)
	generic map(
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,		-- number of databits stored in LUT for amplitude
		LUT_GRAD_PREC	=> LUT_GRAD_PREC,			-- number of databist stored in LUT for gradient (slope)
		CORR_WIDTH		=> CORR_WIDTH,			-- number of bits used from the multiplier
		GRAD_WIDTH		=> GRAD_WIDTH,	-- number of bits of phase accumulator (LSBs -> PHASE_WIDTH - LUT_DEPTH)
		OUT_WIDTH		=> LUT_AMPL_PREC			-- number of bits actually output (should be equal to DAC bits)
	)
	port map(
		ClkxCI		=> ClkxCI,
		RstxRBI		=> RstxRBI,
		TaylorEnxSI	=> TaylorEnxSI,
		AmplxDI		=> AmplxDI,
		SlopexDI	=> SlopexDI,
		GradxDI		=> GradxDI,
		AmplxDO		=> TaylorCorrectedxD
	);
	
	DITHER : entity work.psnr_dither(arch)
	generic map(
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,
		DITHER_WIDTH	=> DITHER_WIDTH,
		OUT_WIDTH		=> OUT_WIDTH
	)
	port map(
		ClkxCI				=> ClkxCI,
		RstxRBI				=> RstxRBI,
		DitherEnxSI			=> DitherEnxSI,
		AmplxDI				=> TaylorCorrectedxD,
		DitherNoisexDI		=> DitherNoisexDI,
		AmplxDO				=> AmplxD
	);
	
	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	AmplxDO	<= AmplxD;		-- output dithered value

end arch;
