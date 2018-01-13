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
			LUT_DEPTH		: integer := 8;					-- number of lut address bits
			LUT_AMPL_PREC	: integer := 16;				-- number of databits stored in LUT for amplitude
			LUT_GRAD_PREC	: integer := 5;					-- number of databist stored in LUT for gradient (slope)
			PHASE_WIDTH		: integer := 32;				-- number of bits of phase accumulator
			LFSR_WIDTH		: integer := 32;				-- number of bits used for the LFSR/PNGR
            LFSR_POLY       : std_logic_vector := "111";	-- polynomial of the LFSR/PNGR
			LFSR_SEED		: integer := 12364;				-- seed for LFSR
			OUT_WIDTH		: integer := 12					-- number of bits actually output (should be equal to DAC bits)
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
	end component;
	
	function param_slv_to_matlab_log (name : string; x : std_logic_vector) return line is
		variable LogLine : line;
	begin
		write(LogLine, string'("params."));
		write(LogLine, name);
		write(LogLine, string'(" = "));
		write(LogLine, integer'image(to_integer(unsigned(x))));
		write(LogLine, string'(";"));
		return LogLine;
	end function param_slv_to_matlab_log;
	
	function param_int_to_matlab_log (name : string; x : integer) return line is
		variable LogLine : line;
	begin
		write(LogLine, string'("params."));
		write(LogLine, name);
		write(LogLine, string'(" = "));
		write(LogLine, integer'image(x));
		write(LogLine, string'(";"));
		return LogLine;
	end function param_int_to_matlab_log;
	
	function param_sl_to_matlab_log (name : string; x : std_logic) return line is
		variable LogLine : line;
	begin
		write(LogLine, string'("params."));
		write(LogLine, name);
		write(LogLine, string'(" = "));
		if x = '1' then
			write(LogLine, string'("true"));
		else
			write(LogLine, string'("false"));
		end if;
		write(LogLine, string'(";"));
		return LogLine;
	end function param_sl_to_matlab_log;
	
	--------------------------------------------------------------------------------------
	-- Signals
	--------------------------------------------------------------------------------------
	file LOG_FILE					: text is out "../matlab/hdl_out_log.m";
	constant NUM_SAMPLES			: integer := 999;
	
	constant LUT_DEPTH				: integer := 10;
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

	signal TruncDithEnxS	: std_logic;
			
	signal PhaseDithEnxS	: std_logic;
	signal PhaseDithMasksxS	: std_logic_vector((PHASE_WIDTH - 1) downto 0);
			

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
		LFSR_POLY       => "11100000000000000000001000000000", -- 0,1,2,22,32 (32 is set implicitly)
		LFSR_SEED		=> 12364,	-- seed for LFSR
		OUT_WIDTH		=> OUT_WIDTH		-- number of bits actually output (should be equal to DAC bits)
	)
	port map(
		ClkxCI				=> ClkxC,
		RstxRBI				=> RstxRB,
		
		TaylorEnxSI			=> TaylorEnxS,
		
		TruncDithEnxSI		=> TruncDithEnxS,
		
		PhaseDithEnxSI		=> PhaseDithEnxS,
		PhaseDithMasksxSI	=> PhaseDithMasksxS,
		
		PhixDI				=> PhiInxD,
		FTWxDI				=> FTWxD,
		
		PhixDO				=> PhiOutxD,
		QxDO				=> QxD,
		IxDO				=> IxD
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
		TaylorEnxS			<= '1';
		TruncDithEnxS		<= '1';
		PhaseDithEnxS		<= '0';
		PhaseDithMasksxS	<= (others => '0');
		
		PhiInxD				<= (others => '0');
		FTWxD				<= "00000001000000000000000000000000"; 
		FTWxD				<= "00000001111111111111111111111111"; 
-- 		FTWxD				<= "00000001000000000000000000000001"; 
		FTWxD				<= std_logic_vector(to_unsigned(901943132, 32));
		
		wait until rising_edge(RstxRB);
		
		--acount for latency of LUT (2) taylor(2) and dithering (1)
		wait until rising_edge(ClkxC);
		wait until rising_edge(ClkxC);
		wait until rising_edge(ClkxC);
		wait until rising_edge(ClkxC);
		wait until rising_edge(ClkxC);
		
		-- write hdl configuration to matlab log file
		LogLine := param_int_to_matlab_log("len", NUM_SAMPLES+1);
		writeline(LOG_FILE, LogLine);
		LogLine := param_sl_to_matlab_log("PHASE_DITHER", PhaseDithEnxS);
		writeline(LOG_FILE, LogLine);
		LogLine := param_sl_to_matlab_log("AMPL_DITHER", TruncDithEnxS);
		writeline(LOG_FILE, LogLine);
		LogLine := param_sl_to_matlab_log("TAYLOR", TaylorEnxS);
		writeline(LOG_FILE, LogLine);	
		LogLine := param_int_to_matlab_log("N_lut_addr", LUT_DEPTH);
		writeline (LOG_FILE, LogLine);
		LogLine := param_int_to_matlab_log("N_lut", LUT_AMPL_PREC);
		writeline (LOG_FILE, LogLine);
		LogLine := param_int_to_matlab_log("N_adc", OUT_WIDTH);
		writeline (LOG_FILE, LogLine);
		LogLine := param_int_to_matlab_log("N_phase", PHASE_WIDTH);
		writeline (LOG_FILE, LogLine);
		LogLine := param_int_to_matlab_log("N_lfsr", LFSR_WIDTH);
		writeline (LOG_FILE, LogLine);
		LogLine := param_slv_to_matlab_log("FTW_0", FTWxD);
		writeline(LOG_FILE, LogLine);
		
		-- write actual dds output data
		write(LogLine, string'("hdl_dds_out= [..."));
		writeline (LOG_FILE, LogLine);
		
		for i in 0 to NUM_SAMPLES loop
-- 			PhasexD	<= std_logic_vector(to_unsigned(i, PhasexD'length));
			wait until rising_edge(ClkxC);
			
			-- write sine and cosine values to logfile (as matlab variable)
			write(LogLine, string'("["));
			write(LogLine, integer'image(to_integer(signed(IxD))) );
			write(LogLine, string'(", "));
			write(LogLine, integer'image(to_integer(signed(QxD))) );
			if i = NUM_SAMPLES then
				write(LogLine, string'("]];"));
			else
				write(LogLine, string'("];"));
			end if;
			writeline (LOG_FILE, LogLine);
		end loop;
		
		
-- 		-- write last two values to table (as lut has 2 cycles latency)
-- 		wait until rising_edge(ClkxC);
-- 		write(LogLine, string'("["));
-- 		write(LogLine, integer'image(to_integer(signed(IxD))) );
-- 		write(LogLine, string'(", "));
-- 		write(LogLine, integer'image(to_integer(signed(QxD))) );
-- 		write(LogLine, string'("]];"));								---- end line
-- 		writeline (LOG_FILE, LogLine);
		
-- 		wait until rising_edge(ClkxC);
-- 		write(LogLine, string'("["));
-- 		write(LogLine, integer'image(to_integer(signed(IxD))) );
-- 		write(LogLine, string'(", "));
-- 		write(LogLine, integer'image(to_integer(signed(QxD))) );
-- 		write(LogLine, string'("]];"));
-- 		writeline (LOG_FILE, LogLine);
		
		
		wait;
		

	end process p_gen_stimuli;
	
end behav;
