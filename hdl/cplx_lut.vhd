-- ----------------------------------------------------------------------------	
-- FILE:	sine_lut.vhd
-- DESCRIPTION:	Serial configuration interface to control DDS and signal generator modules
-- DATE:	December 24, 2017
-- AUTHOR(s):	Jannik Springer (jannik.springer@rwth-aachen.de)
-- REVISIONS:	
-- ----------------------------------------------------------------------------	


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;


entity trig_lut is
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
end trig_lut;


architecture arch of trig_lut is
	------------------------------------------------------------------------------------------------
	--	Functions and types
	------------------------------------------------------------------------------------------------
	type ROM_TYPE is array (0 to (2**(LUT_DEPTH-2) - 1)) of std_logic_vector((2*LUT_AMPL_PREC - 1) downto 0);
	 
	--------------------------------------------
	-- FunctionName: init_lut
	-- This function initializes the memory with the values of a quater sine wave. The values are equally spaced (i.e. from 0 to pi/2 in 1/(2^lut_size) steps).
	--------------------------------------------
	function init_lut (lut_depth : in integer; ampl_precision : integer) return ROM_TYPE is
		variable RomInitxD		: ROM_TYPE := (others => (others => '0'));
		variable sin_val		: real := 0.0;
		variable sin_vect		: std_logic_vector((ampl_precision - 1) downto 0);
		variable cos_val		: real := 0.0;
		variable cos_vect		: std_logic_vector((ampl_precision - 1) downto 0);
	begin
		for i in 0 to 2**(lut_depth-2)-1 loop
			sin_val			:= sin(2.0 * MATH_PI * real(i) / real(2**lut_depth));	-- for actual sine value
			sin_vect		:= std_logic_vector(to_unsigned(integer(round(sin_val * real(2**(ampl_precision - 1) - 1))), ampl_precision));
			cos_val			:= cos(2.0 * MATH_PI * real(i) / real(2**lut_depth));	-- for actual sine value
			cos_vect		:= std_logic_vector(to_unsigned(integer(round(cos_val * real(2**(ampl_precision - 1) - 1))), ampl_precision));
			RomInitxD(i)	:= sin_vect & cos_vect;
		end loop;
		return RomInitxD;
	end function init_lut;
	
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
	--	Signals 
	------------------------------------------------------------------------------------------------
	shared variable TrigLUT	: ROM_TYPE := init_lut(LUT_DEPTH, LUT_AMPL_PREC);

	signal LutAddrxS					: std_logic_vector((LUT_DEPTH - 3) downto 0);
	signal LutOutxD						: std_logic_vector((2*LUT_AMPL_PREC - 1) downto 0);
	
	signal OutConstxSP, OutConstxSN		: std_logic;
	signal InvSinxSP, InvSinxSN			: std_logic;
	signal InvCosxSP, InvCosxSN			: std_logic;
	
	signal LutOutSinxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal LutOutCosxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	
	signal SinxDP, SinxDN				: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal CosxDP, CosxDN				: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
begin

	------------------------------------------------------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
	-- ProcessName: p_sync_rom
	-- This process implements some registers.
	--------------------------------------------
	p_synq_regs : process (ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			OutConstxSP	<= '0';
			InvSinxSP	<= '0';
			InvCosxSP	<= '0';
			SinxDP		<= (others => '0');
			CosxDP		<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			OutConstxSP	<= OutConstxSN;
			InvSinxSP	<= InvSinxSN;
			InvCosxSP	<= InvCosxSN;
			SinxDP		<= SinxDN;
			CosxDP		<= CosxDN;
		end if;
	end process p_synq_regs;
	
	--------------------------------------------
	-- ProcessName: p_sync_rom
	-- This process infers a ROM that stores one quater wave of a sine.
	--------------------------------------------
	p_sync_rom : process (ClkxCI)
	begin
		if ClkxCI'event and ClkxCI = '1' then
			LutOutxD <= TrigLUT(to_integer(unsigned(LutAddrxS)));
		end if;
	end process p_sync_rom;
	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------
	p_comb_const : process (PhasexDI)
	begin
		if PhasexDI(LUT_DEPTH - 2) = '1' and PhasexDI(LUT_DEPTH-3 downto 0) = (PhasexDI(LUT_DEPTH-3 downto 0)'range => '0') then
			OutConstxSN <= '1';
		else
			OutConstxSN <= '0';
		end if;
	end process p_comb_const;
	
	
	LutAddrxS <= PhasexDI(LUT_DEPTH - 3 downto 0) when PhasexDI(LUT_DEPTH - 2) = '0' else twos_complement( PhasexDI(LUT_DEPTH - 3 downto 0) );
	
	-- output the "constant" value in extreme cases (pi/2), i.e. LutOutSinxD = 2^PRECISION-1 and LutOutCosxD = 0
	LutOutSinxD	<= LutOutxD((2*LUT_AMPL_PREC - 1) downto LUT_AMPL_PREC) when OutConstxSP = '0' else std_logic_vector(to_unsigned(2**(LUT_AMPL_PREC-1) - 1, LUT_AMPL_PREC));
	LutOutCosxD	<= LutOutxD((LUT_AMPL_PREC - 1) downto 0) when OutConstxSP = '0' else std_logic_vector(to_unsigned(0, LUT_AMPL_PREC));
	
	-- invert signals
	InvSinxSN <= PhasexDI(LUT_DEPTH - 1);
	InvCosxSN <= PhasexDI(LUT_DEPTH - 1) xor PhasexDI(LUT_DEPTH - 2);
	
	-- get actual sine and cosine values
	SinxDN <= LutOutSinxD when InvSinxSP = '0' else twos_complement(LutOutSinxD);
	CosxDN <= LutOutCosxD when InvCosxSP = '0' else twos_complement(LutOutCosxD);

	
	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	SinxDO	<= SinxDP;
	CosxDO	<= CosxDP;
	
end arch;
