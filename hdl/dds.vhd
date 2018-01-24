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
		GRAD_WIDTH		: integer := 18;	-- number of LSBs used from the phase acc for interpolation
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
		
		--sweep logic
		SweepEnxSI			: in  std_logic;
		SweepUpDownxSI		: in  std_logic;
		SweepRatexDI		: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		TopFTWxDI			: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		BotFTWxDI			: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		PhixDI				: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		ValidxSO			: out std_logic;
		PhixDO				: out std_logic_vector((PHASE_WIDTH - 1) downto 0);
		QxDO				: out std_logic_vector((OUT_WIDTH - 1) downto 0);
		IxDO				: out std_logic_vector((OUT_WIDTH - 1) downto 0)
	);
end dds;



architecture arch of dds is
	------------------------------------------------------------------------------------------------
	--	Functions and types
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
	-- FunctionName: twos_complement
	-- This function returns the two's complement of the input vector x.
	--------------------------------------------
	function twos_complement (x : std_logic_vector) return std_logic_vector is
		variable tmp	: std_logic_vector((x'length) downto 0);
	begin
-- 		tmp := not x;
-- 		return std_logic_vector(unsigned(tmp) + 1);
		tmp := '0' & (not x);
		tmp := std_logic_vector(unsigned(tmp) + 1);
		return tmp((x'length - 1) downto 0);
	end function twos_complement;
	
	
	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------

	-- frequency tuning word
	signal FTWxDP, FTWxDN				: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	
	signal UpxSP, UpxSN					: std_logic;
	signal DownxSP, DownxSN				: std_logic;
	signal SweepRatexDP, SweepRatexDN	: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	
	-- ouput signals
	signal ValidxS						: std_logic;
	signal PhixD						: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	signal IxD							: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal QxD							: std_logic_vector((OUT_WIDTH - 1) downto 0);
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
		GRAD_WIDTH		=> GRAD_WIDTH,
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
		FTWxDI				=> FTWxDP,
		PhixDO				=> PhixD,
		QxDO				=> QxD,
		IxDO				=> IxD
	);
	
	
	DELAY_VALID0 : entity work.DelayLine(rtl)
	generic map (
		DELAY_WIDTH		=> 1,
		DELAY_CYCLES	=> 12
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
    -- ProcessName: p_sync_registers
    -- This process implements some registers.
    --------------------------------------------
	p_sync_registers : process(ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			UpxSP			<= '0';
			DownxSP			<= '0';
			SweepRatexDP	<= std_logic_vector(to_unsigned(2**(PHASE_WIDTH-5), PHASE_WIDTH)); -- initialize with a value not zero
-- 			SweepRatexDP	<= SweepRatexDI;
			FTWxDP			<= (others => '0');
-- 			FTWxDP			<= BotFTWxDI;
		elsif ClkxCI'event and ClkxCI = '1' then
			UpxSP			<= UpxSN;
			DownxSP			<= DownxSN;
			SweepRatexDP	<= SweepRatexDN;
			FTWxDP			<= FTWxDN;
		end if;
	end process;
	
	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------
	UpxSN	<= '1' when (signed(FTWxDP) < signed(TopFTWxDI)) else '0'; -- smaller than top
	DownxSN	<= '1' when (signed(FTWxDP) > signed(BotFTWxDI)) else '0'; -- greater than bot
	
	--------------------------------------------
    -- ProcessName: p_comb_sweep_rate
    -- This process controls the logic behind the sweep rate, the modes are up/down or simply up.
    --------------------------------------------
	p_comb_sweep_rate : process(SweepUpDownxSI, SweepRatexDI, SweepRatexDP, UpxSP, DownxSP)
	begin
		if SweepUpDownxSI = '1' then
			if UpxSP = '1' and DownxSP = '0' then
				SweepRatexDN	<= SweepRatexDI; --count up
			elsif UpxSP = '0' and DownxSP = '1'  then
				SweepRatexDN	<= twos_complement(SweepRatexDI); --count down
			else
				SweepRatexDN	<= SweepRatexDP;
			end if;
		else
			SweepRatexDN	<= SweepRatexDI;
		end if;
	end process;
	
	
	--------------------------------------------
    -- ProcessName: p_comb_sweep_logic
    -- This process controls the logic behind the actual frequency tuning word, either sweep (up/down or up) or no sweep.
    --------------------------------------------
	p_comb_sweep_logic : process(FTWxDP, SweepEnxSI, SweepUpDownxSI, SweepRatexDP, UpxSP, BotFTWxDI)
	begin
		if SweepEnxSI = '1' then
			if SweepUpDownxSI = '0' and UpxSP = '0' then
				FTWxDN	<= BotFTWxDI; -- in case of linear up chirp, reset FWT if top is reached
			else
				FTWxDN	<= std_logic_vector(signed(FTWxDP) + signed(SweepRatexDP));
			end if;
		else
			FTWxDN	<= BotFTWxDI;
		end if;
	end process;
	

	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	ValidxSO	<= ValidxS;		-- valid signal for I and Q component
	PhixDO		<= PhixD;		-- phase output
	QxDO		<= QxD;			-- sine or Q component
	IxDO		<= IxD;			-- cosine or I component

end arch;
