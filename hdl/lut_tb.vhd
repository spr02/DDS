library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

-- use ieee.std_logic_textio.all;


entity sine_lut_tb is
end sine_lut_tb;


architecture behav of sine_lut_tb is
	--------------------------------------------------------------------------------------
	-- Components to be tested
	--------------------------------------------------------------------------------------
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
	
	--------------------------------------------------------------------------------------
	-- Signals
	--------------------------------------------------------------------------------------
	file LOG_FILE : text is out "log.m";
	
	constant LUT_DEPTH				: integer := 8;
	constant LUT_AMPL_PREC			: integer := 16;
	
	
	signal ClkxC					: std_logic;
	signal RstxRB					: std_logic;
	
	signal PhasexD					: std_logic_vector((LUT_DEPTH - 1) downto 0);
		
	signal SinxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	signal CosxD					: std_logic_vector((LUT_AMPL_PREC - 1) downto 0);
	
begin

	------------------------------------------------
	--	  INSTANTIATE Component
	------------------------------------------------
	
	I0 : trig_lut
	generic map(
		LUT_DEPTH		=> LUT_DEPTH,
		LUT_AMPL_PREC	=> LUT_AMPL_PREC
	)
	port map(
		ClkxCI			=> ClkxC, 
		RstxRBI			=> RstxRB,
		
		PhasexDI		=> PhasexD,
		
		SinxDO			=> SinxD,
		CosxDO			=> CosxD
	);
--		 
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
		-- begin log file
		write(LogLine, string'("val_hdl = [..."));
        writeline (LOG_FILE, LogLine);
-- 		write(LogLine, integer'image(KERNEL_SIZE));
-- 			write(LogLine, integer'image(KERNEL_SIZE));
		
		PhasexD		<= (others => '0');
		wait until rising_edge(RstxRB);
		wait until rising_edge(ClkxC);
		wait until rising_edge(ClkxC);
		
		for i in 0 to 255 loop
			PhasexD	<= std_logic_vector(to_unsigned(i, PhasexD'length));
			wait until rising_edge(ClkxC);
			
			-- write sine and cosine values to logfile (as matlab variable)
			write(LogLine, string'("["));
			write(LogLine, integer'image(to_integer(signed(SinxD))) );
			write(LogLine, string'(", "));
			write(LogLine, integer'image(to_integer(signed(CosxD))) );
			write(LogLine, string'("];"));
			writeline (LOG_FILE, LogLine);
		end loop;
		
		
		-- write last two values to table (as lut has 2 cycles latency)
		wait until rising_edge(ClkxC);
		write(LogLine, string'("["));
		write(LogLine, integer'image(to_integer(signed(SinxD))) );
		write(LogLine, string'(", "));
		write(LogLine, integer'image(to_integer(signed(CosxD))) );
		write(LogLine, string'("];"));
		writeline (LOG_FILE, LogLine);
		
		wait until rising_edge(ClkxC);
		write(LogLine, string'("["));
		write(LogLine, integer'image(to_integer(signed(SinxD))) );
		write(LogLine, string'(", "));
		write(LogLine, integer'image(to_integer(signed(CosxD))) );
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
