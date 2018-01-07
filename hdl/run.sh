#set entity name
entity_top="dds_tb"

#overide default, if command line parameter is set
if [ -n "$1" ]; then entity_top=$1; fi
fst_file=$entity_top".fst"
gtkw_file=$entity_top".gtkw"

#exit directly if a command fails
set -e

echo '########## Simulation ##########'
ghdl -r $entity_top --stop-time=1ms --fst=$fst_file     # generate fst file

echo '########## View ################'
if [ ! -f "$gtkw_file" ]
then
	gtkwave $fst_file        # run for the first time
else
    gtkwave $gtkw_file       # run after project file is created (in GUI)
fi

