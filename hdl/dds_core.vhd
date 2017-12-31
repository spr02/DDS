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
		LFSR_SEED		: integer := 12364;	-- seed for LFSR
		OUT_WIDTH		: integer := 12		-- number of bits actually output (should be equal to DAC bits)
	);
	port(
		ClkxCI			: in  std_logic;
		RstxRBI			: in  std_logic;
		
		TaylorEnxSI		: in  std_logic;
		-- TaylorAutoxSI	: in  std_logic; --needed???
		
		DitheringEnxSI	: in  std_logic;
		DitherAutoxSI	: in  std_logic;
		DitherMasksxSI	: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		PhixDI			: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		FTWxDI			: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);		
		
		PhixDO			: out std_logic_vector((PHASE_WIDTH - 1) downto 0);
		QxDO			: out std_logic_vector((OUT_WIDTH - 1) downto 0);
		IxDO			: out std_logic_vector((OUT_WIDTH - 1) downto 0)
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

	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------

	-- phase accumulator
	signal PhaseAccxDP, PhaseAccxDN		: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	
	
	-- dithering noise generator
	signal DitherNoisexD				: std_logic_vector((LFSR_WIDTH - 1) downto 0);
	
	-- look up table
	signal Lut0AddrxS					: std_logic_vector((LUT_DEPTH - 1) downto 0);
	signal Lut0AmplIxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal Lut0AmplQxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal SlopeIxD						: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
	
	signal Lut1AddrxS					: std_logic_vector((LUT_DEPTH - 1) downto 0);
	signal Lut1AmplIxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal Lut1AmplQxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal SlopeQxD						: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
	
	-- output signals
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
		SinxDO			=> Lut0AmplQxD,
		CosxDO			=> Lut0AmplIxD
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
	
	LFSR_0 : LFSR
	generic map(
		RND_WIDTH		=> LFSR_WIDTH,
		INITIAL_SEED	=> LFSR_SEED,
		LFSR_POLY		=> "00000000000000000000000000000000"
	)
	port map(
		ClkxCI			=> ClkxCI,
		RstxRBI			=> RstxRBI,
		EnablexSI		=> '1',
		LoadxSI			=> '0',
		SeedxDI			=> (others => '0'),
		RndOutxDO		=> DitherNoisexD
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
			PhaseAccxDP<= (others => '0');
			IxDP			<= (others => '0');
			QxDP			<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			PhaseAccxDP		<= PhaseAccxDN;
			IxDP			<= IxDN;
			QxDP			<= QxDN;
		end if;
	end process p_sync_phase_accumulator;
	

	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------
	
	-- Assignment of the phase accumulator values for I and Q component
-- 	PhaseAccQxD		<= PhaseAccxDP;
-- 	PhaseAccIxD		<= std_logic_vector(unsigned(PhaseAccxDP) + to_unsigned(2**(PHASE_WIDTH - 2), PhaseAccxDP'length));
	
	-- Mapping of phase accumulator to the LUT address
	Lut0AddrxS		<= PhaseAccxDP((PHASE_WIDTH-1) downto (PHASE_WIDTH-LUT_DEPTH));
	Lut1AddrxS		<= std_logic_vector(unsigned(PhaseAccxDP((PHASE_WIDTH-1) downto (PHASE_WIDTH-LUT_DEPTH))) + 1);
	
	--------------------------------------------
    -- ProcessName: p_comb_gradient
    -- This process computes the gradien/slope of between two successive LUT entries
    --------------------------------------------
	p_comb_gradient : process(Lut0AmplIxD, Lut1AmplIxD, Lut0AmplQxD, Lut1AmplQxD)
		variable I0		: signed((Lut0AmplIxD'length) downto 0);
		variable Q0		: signed((Lut0AmplQxD'length) downto 0);
		variable I1		: signed((Lut1AmplIxD'length) downto 0);
		variable Q1		: signed((Lut1AmplQxD'length) downto 0);
		variable SlopeI	: signed((Lut0AmplIxD'length) downto 0);
		variable SlopeQ	: signed((Lut0AmplQxD'length) downto 0);
	
	begin
		I0		:= signed("0" & Lut0AmplIxD);
		Q0		:= signed("0" & Lut0AmplQxD);
		I1 		:= signed("0" & Lut1AmplIxD);
		Q1 		:= signed("0" & Lut1AmplQxD);
		SlopeI	:= (others => '0');
		SlopeQ	:= (others => '0');
		
		SlopeI := I1 - I0;
		SlopeQ := Q1 - Q0;
		
		SlopeIxD <= std_logic_vector(SlopeI((LUT_GRAD_PREC - 1) downto 0));
		SlopeQxD <= std_logic_vector(SlopeQ((LUT_GRAD_PREC - 1) downto 0));
	end process p_comb_gradient;
	
	--------------------------------------------
    -- ProcessName: p_comb_phase_accumulator_logic
    -- This process implements the accumulator logic with an optional addition of dithering noise.
    --------------------------------------------
	p_comb_phase_accumulator_logic : process(PhaseAccxDP, FTWxDI, DitheringEnxSI, DitherMasksxSI, DitherNoisexD)
		variable PhaseAcc		: unsigned((PhaseAccxDP'length - 1) downto 0);
		variable Ftw			: unsigned((FTWxDI'length - 1) downto 0);
		variable DitherNoise 	: unsigned((DitherNoisexD'length - 1) downto 0);
	begin
		PhaseAcc	:= unsigned(PhaseAccxDP);
		Ftw			:= unsigned(FTWxDI);
		DitherNoise	:= unsigned(DitherMasksxSI and DitherNoisexD);
		
		if (DitheringEnxSI = '1') then
			PhaseAcc := PhaseAcc + Ftw + DitherNoise;
		else
			PhaseAcc := PhaseAcc + Ftw;
		end if;
		
		PhaseAccxDN <= std_logic_vector(PhaseAcc);
	end process p_comb_phase_accumulator_logic;
	
	
	
	--------------------------------------------
    -- ProcessName: p_comb_taylor_i
    -- This process implements the optional linear interpolation of the output samples of the I component.
    --------------------------------------------
	p_comb_taylor_i : process (TaylorEnxSI, Lut0AmplIxD, SlopeIxD, DitherNoisexD, PhaseAccxDP)
		variable ComponentI		: signed((Lut0AmplIxD'length - 1) downto 0);
		variable CorrectionI	: signed((Lut0AmplIxD'length + PHASE_WIDTH - LUT_DEPTH - 1) downto 0);
		variable DitherI		: unsigned((DitherNoisexD'length - 1) downto 0);
		variable LutAmplI		: signed((Lut0AmplIxD'length - 1) downto 0);
		variable LutSlopeI		: signed((LUT_GRAD_PREC - 1) downto 0);
		variable PhaseGradI		: signed((PHASE_WIDTH - LUT_DEPTH) downto 0);
	begin
		ComponentI	:= (others => '0');
		CorrectionI	:= (others => '0');
		DitherI		:= unsigned(DitherNoisexD);
		LutAmplI	:= signed(Lut0AmplIxD);
		LutSlopeI	:= signed(SlopeIxD);
		PhaseGradI	:= signed("0" & PhaseAccxDP((PHASE_WIDTH - LUT_DEPTH - 1) downto 0)); -- get the LSBs of the PhaseAccI
	
		if (TaylorEnxSI = '1') then
			-- TODO: do a linear interpolation of I!
-- 			CorrectionI		:= LutSlopeI * PhaseGradI;
			ComponentI		:= LutAmplI + CorrectionI;
		else
			ComponentI		:= LutAmplI;
		end if;
		
		IxDN <= std_logic_vector(ComponentI((LUT_AMPL_PREC - 1)  downto (LUT_AMPL_PREC - OUT_WIDTH)));
	end process p_comb_taylor_i;
	
	--------------------------------------------
    -- ProcessName: p_comb_taylor_q
    -- This process implements the optional linear interpolation of the output samples of the Q component.
    --------------------------------------------
	p_comb_taylor_q : process (TaylorEnxSI, Lut0AmplQxD, SlopeQxD, DitherNoisexD, PhaseAccxDP)
		variable ComponentQ		: signed((Lut0AmplQxD'length - 1) downto 0);
		variable CorrectionQ	: signed((Lut0AmplQxD'length + PHASE_WIDTH - LUT_DEPTH - 1) downto 0);
		variable DitherQ		: unsigned((DitherNoisexD'length - 1) downto 0);
		variable LutAmplQ		: signed((Lut0AmplQxD'length - 1) downto 0);
		variable LutSlopeQ		: signed((LUT_GRAD_PREC - 1) downto 0);
		variable PhaseGradQ		: signed((PHASE_WIDTH - LUT_DEPTH) downto 0);
	begin
		ComponentQ	:= (others => '0');
		CorrectionQ	:= (others => '0');
		DitherQ		:= unsigned(DitherNoisexD);
		LutAmplQ	:= signed(Lut0AmplQxD);
		LutSlopeQ	:= signed(SlopeQxD);
		PhaseGradQ	:= signed("0" & PhaseAccxDP((PHASE_WIDTH - LUT_DEPTH - 1) downto 0)); -- get the LSBs of the PhaseAccQ
	
		if (TaylorEnxSI = '1') then
			-- TODO: do a linear interpolation of Q!
-- 			CorrectionQ		:= LutSlopeQ * PhaseGradQ;
			ComponentQ		:= LutAmplQ + CorrectionQ;
		else
			ComponentQ		:= LutAmplQ;
		end if;
		
		QxDN <= std_logic_vector(ComponentQ((LUT_AMPL_PREC - 1)  downto (LUT_AMPL_PREC - OUT_WIDTH)));
	end process p_comb_taylor_q;
	
	
	
		
	
	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	PhixDO	<= PhaseAccxDP;		-- phase accumulator
	QxDO	<= QxDP;			-- sine or Q component
	IxDO	<= IxDP;			-- cosine or I component

end arch;
