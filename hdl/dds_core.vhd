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


entity dds_core is
	generic(
		LUT_DEPTH		: integer := 8;		-- number of lut address bits
		LUT_AMPL_PREC	: integer := 16;	-- number of databits stored in LUT for amplitude
		LUT_GRAD_PREC	: integer := 5;		-- number of databist stored in LUT for gradient (slope)
		PHASE_WIDTH		: integer := 32;	-- number of bits of phase accumulator
		LFSR_WIDTH		: integer := 32;	-- number of bits used for the LFSR/PNGR
        LFSR_POLY       : std_logic_vector := "111"; -- polynomial of the LFSR/PNGR
		LFSR_SEED		: integer := 12364;	-- seed for LFSR
		OUT_WIDTH		: integer := 12		-- number of bits actually output (should be equal to DAC bits)
	);
	port(
		ClkxCI				: in  std_logic;
		RstxRBI				: in  std_logic;
		
		EnablexSI			: in  std_logic;
		
		TaylorEnxSI			: in  std_logic;
		
		TruncDithEnxSI		: in std_logic;
		 
		PhaseDithEnxSI		: in  std_logic;
		PhaseDithMasksxSI	: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		PhixDI				: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		FTWxDI				: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);		
		
		PhixDO				: out std_logic_vector((PHASE_WIDTH - 1) downto 0);
		QxDO				: out std_logic_vector((OUT_WIDTH - 1) downto 0);
		IxDO				: out std_logic_vector((OUT_WIDTH - 1) downto 0)
	);
end dds_core;



architecture arch of dds_core is
	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------

	-- phase accumulator
	signal PhaseAccxDP, PhaseAccxDN		: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	signal PhaseGradxDP					: std_logic_vector((PHASE_WIDTH - LUT_DEPTH - 1) downto 0);
	
	
	-- dithering noise generator
	signal DitherNoisexD					: std_logic_Vector((LFSR_WIDTH - 1) downto 0);
	signal DitherNoiseAmplxD				: std_logic_vector((LUT_AMPL_PREC - OUT_WIDTH - 1) downto 0);
	
	-- look up table
	signal AmplIxD						: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal SlopeIxD						: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
	
	signal AmplQxD						: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal SlopeQxD						: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
	
	-- output signals
	signal DitheredAmplIxD				: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal DitheredAmplQxD				: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal QxDN, QxDP					: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal IxDN, IxDP 					: std_logic_vector((OUT_WIDTH - 1) downto 0);

begin
	------------------------------------------------------------------------------------------------
	--	Instantiate Components
	------------------------------------------------------------------------------------------------
	LUT0 : entity work.cplx_grad_lut(arch)
	generic map(
		LUT_DEPTH		=> LUT_DEPTH,
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,
		LUT_GRAD_PREC	=> LUT_GRAD_PREC
	)
	port map(
		ClkxCI			=> ClkxCI,
		RstxRBI			=> RstxRBI,
		PhasexDI		=> PhaseAccxDP((PHASE_WIDTH-1) downto (PHASE_WIDTH-LUT_DEPTH)),
		AmplIxDO		=> AmplIxD,
		GradIxDO		=> SlopeIxD,
		AmplQxDO		=> AmplQxD,
		GradQxDO		=> SlopeQxD
	);
	
	LFSR0 : entity work.psnr_lfsr(rtl)
	generic map(
		RND_WIDTH		=> LFSR_WIDTH,
		INITIAL_SEED	=> LFSR_SEED,
		LFSR_POLY		=> LFSR_POLY
	)
	port map(
		ClkxCI			=> ClkxCI,
		RstxRBI			=> RstxRBI,
		EnablexSI		=> '1',
		LoadxSI			=> '0',
		SeedxDI			=> (others => '0'),
		RndOutxDO		=> DitherNoisexD
	);
	
	DitherNoiseAmplxD <= DitherNoisexD((LUT_AMPL_PREC - OUT_WIDTH - 1) downto 0);
	
	LINE0 : entity work.DelayLine(rtl)
	generic map (
		DELAY_WIDTH		=> PHASE_WIDTH - LUT_DEPTH,
		DELAY_CYCLES	=> 2
	)
	port map(
		ClkxCI			=> ClkxCI,
		RstxRBI			=> RstxRBI,
		EnablexSI		=> '1',
		InputxDI		=> PhaseAccxDP((PHASE_WIDTH-LUT_DEPTH-1) downto 0),
		OutputxDO		=> PhaseGradxDP
	);
	
	
	NOISE_SHAPER_I : entity work.noise_shaper(arch)
	generic map(
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,
		LUT_GRAD_PREC	=> LUT_GRAD_PREC,
		CORR_WIDTH		=> LUT_AMPL_PREC,
		GRAD_WIDTH		=> PHASE_WIDTH - LUT_DEPTH,
		DITHER_WIDTH	=> LUT_AMPL_PREC - OUT_WIDTH,
		OUT_WIDTH		=> OUT_WIDTH
	)
	port map(
		ClkxCI				=> ClkxCI,
		RstxRBI				=> RstxRBI,
		DitherEnxSI			=> TruncDithEnxSI,
		TaylorEnxSI			=> TaylorEnxSI,
		AmplxDI				=> AmplIxD,
		SlopexDI			=> SlopeIxD,
		GradxDI				=> PhaseGradxDP,
		DitherNoisexDI		=> DitherNoiseAmplxD,
		AmplxDO				=> DitheredAmplIxD
	);

	NOISE_SHAPER_Q : entity work.noise_shaper(arch)
	generic map(
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,
		LUT_GRAD_PREC	=> LUT_GRAD_PREC,
		CORR_WIDTH		=> LUT_AMPL_PREC,
		GRAD_WIDTH		=> PHASE_WIDTH - LUT_DEPTH,
		DITHER_WIDTH	=> LUT_AMPL_PREC - OUT_WIDTH,
		OUT_WIDTH		=> OUT_WIDTH
	)
	port map(
		ClkxCI				=> ClkxCI,
		RstxRBI				=> RstxRBI,
		DitherEnxSI			=> TruncDithEnxSI,
		TaylorEnxSI			=> TaylorEnxSI,
		AmplxDI				=> AmplQxD,
		SlopexDI			=> SlopeQxD,
		GradxDI				=> PhaseGradxDP,
		DitherNoisexDI		=> DitherNoiseAmplxD,
		AmplxDO				=> DitheredAmplQxD
	);
	
	------------------------------------------------------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
    -- ProcessName: p_sync_phase_accumulator
    -- This process implements the phase accumulator.
    --------------------------------------------
	p_sync_phase_accumulator : process(ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			PhaseAccxDP		<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			if EnablexSI = '1' then
				PhaseAccxDP		<= PhaseAccxDN;
			end if;
		end if;
	end process;
	
	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------

	--------------------------------------------
	-- ProcessName: p_comb_phase_accumulator_logic
	-- This process implements the accumulator logic with an optional addition of dithering noise.
	--------------------------------------------
	p_comb_phase_accumulator_logic : process(PhaseAccxDP, FTWxDI, PhaseDithEnxSI, PhaseDithMasksxSI, DitherNoisexD)
		variable PhaseAcc		: unsigned((PhaseAccxDP'length - 1) downto 0);
		variable Ftw			: unsigned((FTWxDI'length - 1) downto 0);
		variable DitherNoise 	: unsigned((DitherNoisexD'length - 1) downto 0);
	begin
		PhaseAcc	:= unsigned(PhaseAccxDP);
		Ftw			:= unsigned(FTWxDI);
		DitherNoise	:= unsigned(PhaseDithMasksxSI and DitherNoisexD);
		
		if (PhaseDithEnxSI = '1') then
			PhaseAcc := PhaseAcc + Ftw + DitherNoise;
		else
			PhaseAcc := PhaseAcc + Ftw;
		end if;
		
		PhaseAccxDN <= std_logic_vector(PhaseAcc);
	end process;
	

	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	PhixDO	<= PhaseAccxDP;			-- phase accumulator
	IxDO	<= DitheredAmplIxD;		-- cosine or I component
	QxDO	<= DitheredAmplQxD;		-- sine or Q component

end arch;
