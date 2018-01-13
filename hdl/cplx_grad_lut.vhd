-- ----------------------------------------------------------------------------	
-- FILE:	cplx_grad_lut.vhd
-- DESCRIPTION:	Serial configuration interface to control DDS and signal generator modules
-- DATE:	December 24, 2017
-- AUTHOR(s):	Jannik Springer (jannik.springer@rwth-aachen.de)
-- REVISIONS:	
-- ----------------------------------------------------------------------------	


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;


entity cplx_grad_lut is
	generic(
		LUT_DEPTH		: integer := 8;
		LUT_AMPL_PREC	: integer := 16;
		LUT_GRAD_PREC	: integer := 16
	);
	port(
		ClkxCI			: in  std_logic;
		RstxRBI			: in  std_logic;
		
		PhasexDI		: in  std_logic_vector((LUT_DEPTH - 1) downto 0);
		
		AmplIxDO		: out std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
		GradIxDO		: out std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
		AmplQxDO		: out std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
		GradQxDO		: out std_logic_vector((LUT_AMPL_PREC - 1) downto 0)
	);
end cplx_grad_lut;


architecture arch of cplx_grad_lut is
	------------------------------------------------------------------------------------------------
	--	Signals 
	------------------------------------------------------------------------------------------------
	signal Lut0AddrxS					: std_logic_vector((LUT_DEPTH - 1) downto 0);
	signal Lut0AmplIxDP, Lut0AmplIxDN	: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal Lut0AmplQxDP, Lut0AmplQxDN	: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal SlopeIxD						: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
	
	signal Lut1AddrxS					: std_logic_vector((LUT_DEPTH - 1) downto 0);
	signal Lut1AmplIxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal Lut1AmplQxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal SlopeQxD						: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
begin
	------------------------------------------------------------------------------------------------
	--	Instantiate Components
	------------------------------------------------------------------------------------------------
	LUT0 : entity work.trig_lut(arch)
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
	
	LUT1 : entity work.trig_lut
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
			Lut0AmplIxDP	<= (others => '0');
			Lut0AmplQxDP	<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			Lut0AmplIxDP	<= Lut0AmplIxDN;
			Lut0AmplQxDP	<= Lut0AmplQxDN;
		end if;
	end process;
	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------
	
	-- Mapping of phase input to the LUT address
	Lut0AddrxS		<= PhasexDI;
	Lut1AddrxS		<= std_logic_vector(unsigned(PhasexDI) + 1);
	
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
	end process;

	
	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	AmplIxDO	<= Lut0AmplIxDN;
	GradIxDO	<= SlopeIxD;
	AmplQxDO	<= Lut0AmplQxDN;
	GradQxDO	<= SlopeQxD;
	
end arch;
