add wave -noupdate /tb/rst
add wave -noupdate /tb/clk
add wave -noupdate /tb/clk2
add wave -noupdate /tb/pc
add wave -noupdate /tb/gb/cpu/regfile/regs
add wave -noupdate /tb/gb/cpu/ctrl.done
add wave -noupdate /tb/gb/cpu/decoder/mpc_enum
add wave -group {GB} -noupdate /tb/gb/*
add wave -group {Testbench} -noupdate /tb/*
add wave -group {CPU} -noupdate /tb/gb/cpu/*
add wave -group {ALU} -noupdate /tb/gb/cpu/alu/*
add wave -group {Decode} -noupdate /tb/gb/cpu/decoder/*
add wave -group {RegFile} -noupdate /tb/gb/cpu/regfile/*
add wave -noupdate /tb/prog
