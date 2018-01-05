echo '########## Simulation ##########'
ghdl -r dds_tb --stop-time=1ms --fst=dds_tb.fst     # fst file used from now on
echo '########## View ################'
# gtkwave dds_tb.fst        # run for the first time (used from now on)
gtkwave dds_tb.gtkw &      # run after project file is created (in GUI)

