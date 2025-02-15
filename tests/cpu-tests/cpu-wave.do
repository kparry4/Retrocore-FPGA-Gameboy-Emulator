add wave -noupdate /tb/rst
add wave -noupdate /tb/clk
add wave -noupdate /tb/pc
add wave -noupdate /tb/cpu/regfile/regs
add wave -noupdate /tb/cpu/decoder/mpc_enum
add wave -group {Testbench} -noupdate /tb/*
add wave -group {CPU} -noupdate /tb/cpu/*
add wave -group {Decode} -noupdate /tb/cpu/decoder/*
add wave -group {RegFile} -noupdate /tb/cpu/regfile/*
