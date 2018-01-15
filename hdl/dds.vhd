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


entity dds is
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
-- 		TaylorAutoxSI	: in  std_logic; --needed???
		
		TruncDithEnxSI		: in std_logic;
-- 		DitherAutoxSI	: in  std_logic; --needed???
		PhaseDithEnxSI		: in  std_logic;
		PhaseDithMasksxSI	: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		PhixDI				: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		FTWxDI				: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);		
		
		ValidxSO			: out std_logic;
		PhixDO				: out std_logic_vector((PHASE_WIDTH - 1) downto 0);
		QxDO				: out std_logic_vector((OUT_WIDTH - 1) downto 0);
		IxDO				: out std_logic_vector((OUT_WIDTH - 1) downto 0)
	);
end dds;



architecture arch of dds is
	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------

	-- ouput signals
	signal ValidxS					: std_logic;
	signal IxD						: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal QxD						: std_logic_vector((OUT_WIDTH - 1) downto 0);
begin
	------------------------------------------------------------------------------------------------
	--	Instantiate Components
	------------------------------------------------------------------------------------------------
	DDS0 : entity work.dds_core
	generic map(
		LUT_DEPTH		=> LUT_DEPTH,
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,
		LUT_GRAD_PREC	=> LUT_GRAD_PREC,
		PHASE_WIDTH		=> PHASE_WIDTH,
		LFSR_WIDTH		=> LFSR_WIDTH,
        LFSR_POLY       => LFSR_POLY,
		LFSR_SEED		=> LFSR_SEED,
		OUT_WIDTH		=> OUT_WIDTH
	)
	port map(
		ClkxCI				=> ClkxCI,
		RstxRBI				=> RstxRBI,
		EnablexSI			=> EnablexSI,
		TaylorEnxSI			=> TaylorEnxSI,
		TruncDithEnxSI		=> TruncDithEnxSI,
		PhaseDithEnxSI		=> PhaseDithEnxSI,
		PhaseDithMasksxSI	=> PhaseDithMasksxSI,
		PhixDI				=> PhixDI,
		FTWxDI				=> FTWxDI,
		PhixDO				=> PhixDO,
		QxDO				=> QxD,
		IxDO				=> IxD
	);
	
	
	DELAY_VALID0 : entity work.DelayLine(rtl)
	generic map (
		DELAY_WIDTH		=> 1,
		DELAY_CYCLES	=> 4 -- four instead of five, since EnabelxSI already introduces one cycle delay
	)
	port map(
		ClkxCI			=> ClkxCI,
		RstxRBI			=> RstxRBI,
		EnablexSI		=> '1',
		InputxDI(0)		=> EnablexSI,
		OutputxDO(0)	=> ValidxS
	);

	------------------------------------------------------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
    -- ProcessName: p_sync_phase_accumulator
    -- This process implements the phase accumulator.
    --------------------------------------------
-- 	p_sync_phase_accumulator : process(ClkxCI, RstxRBI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			PhaseAccxDP		<= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			PhaseAccxDP		<= PhaseAccxDN;
-- 		end if;
-- 	end process p_sync_phase_accumulator;
-- 	
	
	--------------------------------------------
    -- ProcessName: p_sync_registers
    -- This process implements some registers to delay or syncronize data.
    --------------------------------------------
-- 	p_sync_registers : process(ClkxCI, RstxRBI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			Lut0AmplIxDP	<= (others => '0');
-- 			CorrIxDP		<= (others => '0');
-- 			IxDP			<= (others => '0');
-- 			Lut0AmplQxDP	<= (others => '0');
-- 			CorrQxDP		<= (others => '0');
-- 			QxDP			<= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			Lut0AmplIxDP	<= Lut0AmplIxDN;
-- 			CorrIxDP		<= CorrIxDN;
-- 			IxDP			<= IxDN;
-- 			Lut0AmplQxDP	<= Lut0AmplQxDN;
-- 			CorrQxDP		<= CorrQxDN;
-- 			QxDP			<= QxDN;
-- 		end if;
-- 	end process p_sync_registers;
	

	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------

	--------------------------------------------
	-- ProcessName: p_comb_phase_accumulator_logic
	-- This process implements the accumulator logic with an optional addition of dithering noise.
	--------------------------------------------
-- 	p_comb_phase_accumulator_logic : process(PhaseAccxDP, FTWxDI, PhaseDithgEnxSI, PhaseDithMasksxSI, DitherNoisexD)
-- 		variable PhaseAcc		: unsigned((PhaseAccxDP'length - 1) downto 0);
-- 		variable Ftw			: unsigned((FTWxDI'length - 1) downto 0);
-- 		variable DitherNoise 	: unsigned((DitherNoisexD'length - 1) downto 0);
-- 	begin
-- 		PhaseAcc	:= unsigned(PhaseAccxDP);
-- 		Ftw			:= unsigned(FTWxDI);
-- 		DitherNoise	:= unsigned(PhaseDithMasksxSI and DitherNoisexD);
-- 		
-- 		if (PhaseDithgEnxSI = '1') then
-- 			PhaseAcc := PhaseAcc + Ftw + DitherNoise;
-- 		else
-- 			PhaseAcc := PhaseAcc + Ftw;
-- 		end if;
-- 		
-- 		PhaseAccxDN <= std_logic_vector(PhaseAcc);
-- 	end process p_comb_phase_accumulator_logic;


	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	ValidxSO	<= ValidxS;		-- valid signal for I and Q component
	QxDO		<= QxD;			-- sine or Q component
	IxDO		<= IxD;			-- cosine or I component

end arch;
