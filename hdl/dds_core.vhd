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
	--	Componentes
	------------------------------------------------------------------------------------------------
	component trig_lut is
	generic(
		LUT_DEPTH		: integer := 8;
		LUT_AMPL_PREC	: integer := 16
	);
	port(
		ClkxCI			: in  std_logic;
		RstxRBI			: in  std_logic;
		
		PhasexDI		: in  std_logic_vector((LUT_DEPTH - 1) downto 0);
		
		SinxDO			: out std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
		CosxDO			: out std_logic_vector((LUT_AMPL_PREC - 1) downto 0)
	);
	end component;
	
	component LFSR is
		generic(
			RND_WIDTH		: integer := 9;
			INITIAL_SEED	: integer := 13;
			LFSR_POLY		: std_logic_vector := "000010000"
		);
		port(
			ClkxCI      : in	std_logic;
			RstxRBI     : in	std_logic;

            EnablexSI   : in    std_logic;
            
			-- load seed
			LoadxSI		: in	std_logic;
			SeedxDI		: in	std_logic_vector((RND_WIDTH - 1) downto 0);

			-- output
			RndOutxDO	: out	std_logic_vector((RND_WIDTH - 1) downto 0)
		);
	end component;
	
	component DelayLine is
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
	end component;
	
	component taylor_interpolation is
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
	end component;


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
	signal Lut0AddrxS					: std_logic_vector((LUT_DEPTH - 1) downto 0);
	signal Lut0AmplIxDP, Lut0AmplIxDN	: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal Lut0AmplQxDP, Lut0AmplQxDN	: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal SlopeIxD						: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
	
	signal Lut1AddrxS					: std_logic_vector((LUT_DEPTH - 1) downto 0);
	signal Lut1AmplIxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal Lut1AmplQxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal SlopeQxD						: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
	
	-- taylor series CorrectionI
	signal CorrIxDP, CorrIxDN			: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal CorrQxDP, CorrQxDN			: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	
	-- output signals
	signal TaylorCorrectedIxD			: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal TaylorCorrectedQxD			: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal tmp							: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal QxDN, QxDP					: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal IxDN, IxDP 					: std_logic_vector((OUT_WIDTH - 1) downto 0);

begin
	------------------------------------------------------------------------------------------------
	--	Instantiate Components
	------------------------------------------------------------------------------------------------
	LUT0 : trig_lut
	generic map(
		LUT_DEPTH		=> LUT_DEPTH,
		LUT_AMPL_PREC	=> LUT_AMPL_PREC
	)
	port map(
		ClkxCI			=> ClkxCI, 
		RstxRBI			=> RstxRBI,
		PhasexDI		=> Lut0AddrxS,
		SinxDO			=> Lut0AmplQxDN,
		CosxDO			=> Lut0AmplIxDN
	);
	
	LUT1 : trig_lut
	generic map(
		LUT_DEPTH		=> LUT_DEPTH,
		LUT_AMPL_PREC	=> LUT_AMPL_PREC
	)
	port map(
		ClkxCI			=> ClkxCI, 
		RstxRBI			=> RstxRBI,
		PhasexDI		=> Lut1AddrxS,
		SinxDO			=> Lut1AmplQxD,
		CosxDO			=> Lut1AmplIxD
	);
	
	LFSR0 : LFSR
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
	
	LINE0 : DelayLine
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
	
	TAYLOR_I : taylor_interpolation
	generic map(
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,		-- number of databits stored in LUT for amplitude
		LUT_GRAD_PREC	=> LUT_GRAD_PREC,			-- number of databist stored in LUT for gradient (slope)
		CORR_WIDTH		=> LUT_AMPL_PREC,			-- number of bits used from the multiplier
		GRAD_WIDTH		=> PHASE_WIDTH - LUT_DEPTH,	-- number of bits of phase accumulator (LSBs -> PHASE_WIDTH - LUT_DEPTH)
		OUT_WIDTH		=> LUT_AMPL_PREC			-- number of bits actually output (should be equal to DAC bits)
	)
	port map(
		ClkxCI		=> ClkxCI,
		RstxRBI		=> RstxRBI,
		AmplxDI		=> Lut0AmplIxDN,
		SlopexDI	=> SlopeIxD,
		GradxDI		=> PhaseGradxDP,
		AmplxDO		=> TaylorCorrectedIxD
	);
	
	TAYLOR_Q : taylor_interpolation
	generic map(
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,		-- number of databits stored in LUT for amplitude
		LUT_GRAD_PREC	=> LUT_GRAD_PREC,			-- number of databist stored in LUT for gradient (slope)
		CORR_WIDTH		=> LUT_AMPL_PREC,			-- number of bits used from the multiplier
		GRAD_WIDTH		=> PHASE_WIDTH - LUT_DEPTH,	-- number of bits of phase accumulator (LSBs -> PHASE_WIDTH - LUT_DEPTH)
		OUT_WIDTH		=> LUT_AMPL_PREC			-- number of bits actually output (should be equal to DAC bits)
	)
	port map(
		ClkxCI		=> ClkxCI,
		RstxRBI		=> RstxRBI,
		AmplxDI		=> Lut0AmplQxDN,
		SlopexDI	=> SlopeQxD,
		GradxDI		=> PhaseGradxDP,
		AmplxDO		=> TaylorCorrectedQxD
	);
	
	tmp <= TaylorCorrectedIxD(15 downto 4);

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
			PhaseAccxDP		<= PhaseAccxDN;
		end if;
	end process p_sync_phase_accumulator;
	
	
	--------------------------------------------
    -- ProcessName: p_sync_registers
    -- This process implements some registers to delay or syncronize data.
    --------------------------------------------
	p_sync_registers : process(ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			Lut0AmplIxDP	<= (others => '0');
			CorrIxDP		<= (others => '0');
			IxDP			<= (others => '0');
			Lut0AmplQxDP	<= (others => '0');
			CorrQxDP		<= (others => '0');
			QxDP			<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			Lut0AmplIxDP	<= Lut0AmplIxDN;
			CorrIxDP		<= CorrIxDN;
			IxDP			<= IxDN;
			Lut0AmplQxDP	<= Lut0AmplQxDN;
			CorrQxDP		<= CorrQxDN;
			QxDP			<= QxDN;
		end if;
	end process p_sync_registers;
	

	
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
	end process p_comb_phase_accumulator_logic;
	
	
	-- Mapping of phase accumulator to the LUT address
	Lut0AddrxS		<= PhaseAccxDP((PHASE_WIDTH-1) downto (PHASE_WIDTH-LUT_DEPTH));
	Lut1AddrxS		<= std_logic_vector(unsigned(PhaseAccxDP((PHASE_WIDTH-1) downto (PHASE_WIDTH-LUT_DEPTH))) + 1);
	
	--------------------------------------------
    -- ProcessName: p_comb_gradient
    -- This process computes the gradien/slope of between two successive LUT entries
    --------------------------------------------
	p_comb_gradient : process(Lut0AmplIxDN, Lut1AmplIxD, Lut0AmplQxDN, Lut1AmplQxD)
		variable I0		: signed((Lut0AmplIxDN'length) downto 0);
		variable Q0		: signed((Lut0AmplQxDN'length) downto 0);
		variable I1		: signed((Lut1AmplIxD'length) downto 0);
		variable Q1		: signed((Lut1AmplQxD'length) downto 0);
		variable SlopeI	: signed((Lut0AmplIxDN'length) downto 0);
		variable SlopeQ	: signed((Lut0AmplQxDN'length) downto 0);
	
	begin
		I0		:= signed("0" & Lut0AmplIxDN);
		Q0		:= signed("0" & Lut0AmplQxDN);
		I1 		:= signed("0" & Lut1AmplIxD);
		Q1 		:= signed("0" & Lut1AmplQxD);
		SlopeI	:= (others => '0');
		SlopeQ	:= (others => '0');
		
		SlopeI := I1 - I0;
		SlopeQ := Q1 - Q0;
		
		SlopeIxD <= std_logic_vector(SlopeI((LUT_GRAD_PREC - 1) downto 0));
		SlopeQxD <= std_logic_vector(SlopeQ((LUT_GRAD_PREC - 1) downto 0));
	end process p_comb_gradient;
	
	
	
	
-- 	--------------------------------------------
-- 	-- ProcessName: p_comb_correction_q
-- 	-- This process implements a multiplier, that is used to calculate the taylor correction value.
-- 	--------------------------------------------
-- 	p_comb_correction_q : process(SlopeQxD, PhaseGradxDP)
-- 		constant PosMSB			: integer := LUT_GRAD_PREC + PHASE_WIDTH - LUT_DEPTH;
-- 		constant PosLSB			: integer := LUT_GRAD_PREC + PHASE_WIDTH - LUT_DEPTH - LUT_AMPL_PREC;
-- 		variable PhaseGradQ		: signed((PHASE_WIDTH - LUT_DEPTH) downto 0); -- 25
-- 		variable LutSlopeQ		: signed((LUT_GRAD_PREC - 1) downto 0); -- 16
-- 		variable CorrectionQ	: signed((LUT_GRAD_PREC + PHASE_WIDTH - LUT_DEPTH) downto 0); --16+32-8+1 = 41
-- 	begin
-- 		CorrectionQ	:= (others => '0');
-- 		LutSlopeQ	:= signed(SlopeQxD);
-- 		PhaseGradQ	:= signed("0" & PhaseGradxDP); -- get the LSBs of the PhaseAccQ
-- 	
-- 		CorrectionQ		:= LutSlopeQ * PhaseGradQ;
-- 		CorrQxDN		<= std_logic_vector(CorrectionQ((PosMSB - 1) downto PosLSB));
-- 	end process p_comb_correction_q;
-- 	
-- 	--------------------------------------------
-- 	-- ProcessName: p_comb_taylor_q
-- 	-- This process implements the optional linear interpolation of the output samples of the Q component.
-- 	--------------------------------------------
-- 	p_comb_taylor_q : process (TaylorEnxSI, Lut0AmplQxDP, CorrQxDP, SlopeQxD, DitherNoisexD, PhaseGradxDP, TruncDithEnxSI)
-- 		variable ComponentQ		: signed((Lut0AmplQxDP'length - 1) downto 0);
-- 		variable LutAmplQ		: signed((Lut0AmplQxDP'length - 1) downto 0);
-- 		variable DitherQ		: unsigned((DitherNoisexD'length - 1) downto 0);
-- 		variable CorrectionQ	: signed((LUT_AMPL_PREC - 1) downto 0);
-- 	begin
-- 		ComponentQ	:= (others => '0');
-- 		CorrectionQ	:= signed(CorrQxDP);
-- 		DitherQ		:= unsigned(DitherNoisexD);
-- 		LutAmplQ	:= signed(Lut0AmplQxDP);
-- 	
-- 		if (TaylorEnxSI = '1') then
-- 			ComponentQ		:= LutAmplQ + CorrectionQ;
-- 		else
-- 			ComponentQ		:= LutAmplQ;
-- 		end if;
-- 		
-- 		if (TruncDithEnxSI = '1') then
-- 			ComponentQ		:= signed(unsigned(ComponentQ) + resize(DitherQ((LUT_AMPL_PREC-OUT_WIDTH-1) downto 0), ComponentQ'length));
-- 		end if;
-- 		
-- 		QxDN <= std_logic_vector(ComponentQ((LUT_AMPL_PREC - 1)  downto (LUT_AMPL_PREC - OUT_WIDTH)));
-- 	end process p_comb_taylor_q;
	
	
	p_comb_dither_add_i : process (TaylorCorrectedIxD, DitherNoiseAmplxD)
		variable Val		: signed((LUT_AMPL_PREC - 1) downto 0);
		variable Dither		: signed((LUT_AMPL_PREC - 1) downto 0);
		variable Sum		: signed((LUT_AMPL_PREC - 1) downto 0);
		constant tmp		: natural := 15;
	begin
		Val		:= signed(TaylorCorrectedIxD);
		Dither	:= signed(resize(unsigned(DitherNoiseAmplxD), Dither'length));
		Sum		:= Val + Dither;
		
		-- saturate if a was positive and sum overflowed (both versions work)
		if Val(Val'left) = '0' and Sum(Sum'left) = '1' then
-- 			Sum := "0" & (Sum'left-1 downto 0 => '1');
			Sum := (tmp => '1', others => '0');
			Sum := to_signed(2**(LUT_AMPL_PREC-1) - 1, LUT_AMPL_PREC);
		end if;	
		
		IxDN <= std_logic_vector(Sum(Sum'left downto (LUT_AMPL_PREC - OUT_WIDTH)));
	end process p_comb_dither_add_i;
	
	p_comb_dither_add_q : process (TaylorCorrectedQxD, DitherNoiseAmplxD)
		variable Val		: signed((LUT_AMPL_PREC - 1) downto 0);
		variable Dither		: signed((LUT_AMPL_PREC - 1) downto 0);
		variable Sum		: signed((LUT_AMPL_PREC - 1) downto 0);
	begin
		Val		:= signed(TaylorCorrectedQxD);
		Dither	:= signed(resize(unsigned(DitherNoiseAmplxD), Dither'length));
		Sum		:= Val + Dither;
		
		-- saturate if a was positive and sum overflowed (both versions work)
		if Val(Val'left) = '0' and Sum(Sum'left) = '1' then
-- 			Sum := "0" & (Sum'left-1 downto 0 => '1');
			Sum := to_signed(2**(LUT_AMPL_PREC-1) - 1, LUT_AMPL_PREC);
		end if;	
		
		QxDN <= std_logic_vector(Sum(Sum'left downto (LUT_AMPL_PREC - OUT_WIDTH)));
	end process p_comb_dither_add_q;
	
	
	
	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	PhixDO	<= PhaseAccxDP;		-- phase accumulator
	QxDO	<= QxDP;			-- sine or Q component
	IxDO	<= IxDP;			-- cosine or I component

end arch;
