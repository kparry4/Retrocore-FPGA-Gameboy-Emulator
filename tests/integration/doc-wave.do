add wave -noupdate /tb/rst
add wave -noupdate /tb/clk
add wave -noupdate /tb/clk2
add wave -noupdate /tb/pc
add wave -noupdate /tb/gb/cpu/regfile/regs
add wave -noupdate /tb/gb/cpu/ctrl.done
add wave -noupdate /tb/gb/cpu/decoder/mpc_enum
add wave -noupdate /tb/gb/cpu/decoder/iflg
add wave -noupdate /tb/gb/cpu/decoder/ie
add wave -noupdate /tb/gb/cpu/decoder/ime
add wave -group {GB} -noupdate /tb/gb/*
add wave -group {Testbench} -noupdate /tb/*
add wave -group {CPU} -noupdate /tb/gb/cpu/*
add wave -group {MMU} -noupdate /tb/gb/mmu/*
add wave -group {MEM} -noupdate /tb/gb/mmu/memory_units/*
add wave -group {BRAM_OUT_MUX} -noupdate /tb/gb/mmu/memory_units/memory_out_muxer/*
add wave -group {IOREG} -noupdate /tb/gb/mmu/io_registers/*
#add wave -group {ALU} -noupdate /tb/gb/cpu/alu/*
add wave -group {PPU} -noupdate /tb/gb/ppu/*
add wave -group {PIXMIX} -noupdate /tb/gb/ppu/pixel_mixer_inst/*
add wave -group {BG} -noupdate /tb/gb/ppu/Pixel_Gen_inst/render_bg_inst/*
add wave -group {Decode} -noupdate /tb/gb/cpu/decoder/*
#add wave -group {RegFile} -noupdate /tb/gb/cpu/regfile/*
add wave -noupdate /tb/prog
