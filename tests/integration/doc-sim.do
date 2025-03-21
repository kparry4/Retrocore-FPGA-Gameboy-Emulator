# testfloat.do 
#
# Modification by Oklahoma State University & Harvey Mudd College
# Use with Testbench 
# James Stine, 2008; David Harris 2021
# Go Cowboys!!!!!!
#
# Takes 1:10 to run RV64IC tests using gui

# run with vsim -do "do wally.do rv64ic riscvarchtest-64m"
onbreak {resume}

# create library
if [file exists work] {
    vdel -all
}
vlib work

# compile source files
# suppress spurious warnngs about 
# "Extra checking for conflicts with always_comb done at vopt time"
# because vsim will run vopt

# start and run simulation
# remove +acc flag for faster sim during regressions if there is no need to access internal signals
# $num = the added words after the call
vlog ../../code/Integration/cpu/*.svh ../../code/Integration/cpu/*.svh doc-tb.sv ../../code/Integration/cpu/*.sv ../../code/Integration/MMU/*.sv ../../code/Integration/MMU/*.svh ../../code/Integration/MMU/BRAMS/*.v /afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/altera_primitives.v /afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/220model.v /afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/sgate.v /afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/altera_mf.v /afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/cyclonev_atoms.v ../../code/*.sv  +define+TEST="${1}"  -suppress 2583,7063,8607,2697 
# vlog ../../code/cpu/*.svh doc-tb.sv +define+TEST="${1}"  -suppress 2583,7063,8607,2697 

# Change TEST_SIZE to only test certain FP width
# values are QP, DP, SP, HP or all for all tests
vsim -voptargs=+acc work.tb

# Set WAV variable to avoid having any output to wave (to limit disk space)
quietly set WAV 1;

# Determine if nowave argument is provided this removes any output to
# a wlf or wave window to reduce disk space.
if {$WAV eq 0} {
    puts "No wave output is selected"
} else {
    puts "wave output is selected"
    view wave
    # add log -recursive /*
    do doc-wave.do    
}  

#-- Run the Simulation 
run -all
noview -tb doc.sv
view wave
