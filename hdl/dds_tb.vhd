library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

entity dds_tb is
end dds_tb;


architecture behav of dds_tb is
	--------------------------------------------------------------------------------------
	-- Components to be tested
	--------------------------------------------------------------------------------------
	component dds_core is
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
	end component;
	
	--------------------------------------------------------------------------------------
	-- Signals
	--------------------------------------------------------------------------------------
	file LOG_FILE : text is out "log.m";
	
	constant LUT_DEPTH				: integer := 8;
	constant LUT_AMPL_PREC			: integer := 16;
	constant LUT_GRAD_PREC			: integer := 16;
	constant PHASE_WIDTH			: integer := 32;	-- number of bits of phase accumulator
	constant LFSR_WIDTH				: integer := 32;	-- number of bits used for the LFSR/PNGR
	constant LFSR_SEED				: integer := 12364;	-- seed for LFSR
	constant OUT_WIDTH				: integer := 12;		-- number of bits actually output (should be equal to DAC bits)
	
	
	signal ClkxC					: std_logic;
	signal RstxRB					: std_logic;
	
-- 	signal PhaseAxD					: std_logic_vector((LUT_DEPTH - 1) downto 0);
-- 	signal PhaseBxD					: std_logic_vector((LUT_DEPTH - 1) downto 0);
-- 		
-- 	signal AmplAxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
-- 	signal GradAxD					: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
-- 	signal AmplBxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
-- 	signal GradBxD					: std_logic_vector((LUT_GRAD_PREC - 1) downto 0);
	
	
	signal TaylorEnxS		: std_logic;
			-- TaylorAutoxSI	: in  std_logic; --needed???
	signal DitheringEnxS	: std_logic;
	signal DitherAutoxS		: std_logic;
	signal DitherMasksxS	: std_logic_vector((PHASE_WIDTH - 1) downto 0);
			
	signal PhiInxD			: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	signal FTWxD			: std_logic_vector((PHASE_WIDTH - 1) downto 0);		
			
	signal PhiOutxD			: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	signal QxD				: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal IxD				: std_logic_vector((OUT_WIDTH - 1) downto 0);
	
begin

	------------------------------------------------
	--	  INSTANTIATE Component
	------------------------------------------------
	
	I0 : dds_core
	generic map(
		LUT_DEPTH		=> LUT_DEPTH,		-- number of lut address bits
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,	-- number of databits stored in LUT for amplitude
		LUT_GRAD_PREC	=> LUT_GRAD_PREC,		-- number of databist stored in LUT for gradient (slope)
		PHASE_WIDTH		=> PHASE_WIDTH,	-- number of bits of phase accumulator
		LFSR_WIDTH		=> LFSR_WIDTH,	-- number of bits used for the LFSR/PNGR
		LFSR_SEED		=> 12364,	-- seed for LFSR
		OUT_WIDTH		=> OUT_WIDTH		-- number of bits actually output (should be equal to DAC bits)
	)
	port map(
		ClkxCI			=> ClkxC,
		RstxRBI			=> RstxRB,
		
		TaylorEnxSI		=> TaylorEnxS,
		-- TaylorAutoxSI	: in  std_logic; --needed???
		
		DitheringEnxSI	=> DitheringEnxS,
		DitherAutoxSI	=> DitherAutoxS,
		DitherMasksxSI	=> DitherMasksxS,
		
		PhixDI			=> PhiInxD,
		FTWxDI			=> FTWxD,
		
		PhixDO			=> PhiOutxD,
		QxDO			=> QxD,
		IxDO			=> IxD
	);		 
	------------------------------------------------
	--	  Generate Clock Signal
	------------------------------------------------
	p_clock: process
	begin
		ClkxC <= '0';
		wait for 50 ns;
		ClkxC <= '1';
		wait for 50 ns;
	end process p_clock;
	
	------------------------------------------------
	--	  Generate Reset Signal
	------------------------------------------------
	p_reset: process
	begin
		RstxRB <= '0';
		wait for 10 ns;
		RstxRB <= '1';
		wait;
	end process p_reset;


	
	------------------------------------------------
	--	  Generate Stimuli
	------------------------------------------------
	p_gen_stimuli: process
		variable LogLine : line;
	begin
		TaylorEnxS		<= '0';
		DitheringEnxS	<= '0';
		DitherAutoxS	<= '0';
		DitherMasksxS	<= (others => '0');
		
		PhiInxD			<= (others => '0');
		FTWxD			<= "00000000010000000000000000000000";
		
		wait until rising_edge(RstxRB);
		wait until rising_edge(ClkxC);
		wait until rising_edge(ClkxC);
		
		for i in 0 to 255 loop
-- 			PhasexD	<= std_logic_vector(to_unsigned(i, PhasexD'length));
			wait until rising_edge(ClkxC);
			
			-- write sine and cosine values to logfile (as matlab variable)
			write(LogLine, string'("["));
			write(LogLine, integer'image(to_integer(signed(QxD))) );
			write(LogLine, string'(", "));
			write(LogLine, integer'image(to_integer(signed(IxD))) );
			write(LogLine, string'("];"));
			writeline (LOG_FILE, LogLine);
		end loop;
		
		
		-- write last two values to table (as lut has 2 cycles latency)
		wait until rising_edge(ClkxC);
		write(LogLine, string'("["));
		write(LogLine, integer'image(to_integer(signed(QxD))) );
		write(LogLine, string'(", "));
		write(LogLine, integer'image(to_integer(signed(IxD))) );
		write(LogLine, string'("];"));
		writeline (LOG_FILE, LogLine);
		
		wait until rising_edge(ClkxC);
		write(LogLine, string'("["));
		write(LogLine, integer'image(to_integer(signed(QxD))) );
		write(LogLine, string'(", "));
		write(LogLine, integer'image(to_integer(signed(IxD))) );
		write(LogLine, string'("]];"));
		writeline (LOG_FILE, LogLine);
		
		
		wait;
--		 WrEnablexS  <= '0';
--		 ColxS	   <= (others => '0');
--		 RowxS	   <= (others => '0');
--		 EntryInxD   <= (others => '0');
--		 TransposexS <= '0';
--		 ColRowxS	<= (others => '0');
--		 OffsetxS	<= (others => '0');
--		 -----
--		 TransposexS <= '0';
--		 NextColxS <= '0';
--		 NextRowxS <= '0';
--		 PrevColxS <= '0';
--		 PrevRowxS <= '0';
--		 
--		 ------
--		 ColRowResetBxS <= '0';
--		 NextColBxS <= '0';
--		 NextRowBxS <= '0';
--		 
--		 ------
--		 RowResetAxS <= '0';
--		 NextRowAxS <= '0';
--		 ColAxS <= (others => '0');
--		 
--		 wait until rising_edge(RstxRB);
--		 wait until rising_edge(ClkxC);
--		 NextRowBxS <= '1';
--		 NextRowAxS <= '1';
--		 wait until rising_edge(ClkxC);
--		 wait until rising_edge(ClkxC);
--		 NextRowAxS <= '1';
--		 wait until rising_edge(ClkxC);
--		 wait until rising_edge(ClkxC);
--		 NextRowAxS <= '1';
--		 wait until rising_edge(ClkxC);
--		 NextRow
--		 
--		 wait;
		
		
	end process p_gen_stimuli;
	
end behav;
