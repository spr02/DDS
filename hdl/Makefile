SRC=\
	helper_util.vhd\
	delay_line.vhd\
	cplx_lut.vhd\
	lfsr.vhd\
	taylor.vhd\
	dither.vhd\
	noise_shaper.vhd\
	dds_core.vhd\
	lut_tb.vhd\
	dds_tb.vhd
clock : $(SRC)
	ghdl -a --std=93c $(SRC)
	ghdl -s --std=93c $(SRC)
	ghdl -e --std=93c dds_tb
	make run
run : 
	./run.sh
clean distclean::
	ghdl --clean
	ghdl --remove
	rm -rf *.fst
	rm -rf ../matlab/hdl_out_log.m
