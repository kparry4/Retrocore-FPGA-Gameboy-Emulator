# Target executable
TARGET = simv

# Source files
SRC = $(wildcard *.sv) $(wildcard *.v) $(wildcard block_rams/*.v)

# Set the number of threads to use for parallel compilation (2 * cores)
CORES = $(shell getconf _NPROCESSORS_ONLN)
THREADS = $(shell echo $$((2 * $(CORES))))

# Vlogan flags
VLOGANFLAGS = -full64 -sverilog -debug_all +lint=none,noVCDE +warn=all \
					 -timescale=1ns/1ps +v2k
VCSUUMFLAGS = -full64 -sverilog -debug_all +lint=none,noVCDE +warn=all \
					 -timescale=1ns/1ps

# VCS flags
VCSFLAGS = -full64 -sverilog -debug_all +lint=none,noVCDE +warn=all -j$(THREADS) \
					 -timescale=1ns/1ps +v2k
COMMON_FLAGS +=

# Simulator
SIM = vcs

# Altera FPGA library files (for simulation)
INC_V = /afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/altera_primitives.v \
				/afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/220model.v \
				/afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/sgate.v \
				/afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/altera_mf.v \
				/afs/ece/support/altera/release/16.1.2/quartus/eda/sim_lib/cyclonev_atoms.v
INC_V_FLAGS = $(addprefix -v , $(INC_V))
INC_SV =
INC_SV_FLAGS = $(addprefix -v , $(INC_SV))

# Copy common flags
VCSFLAGS += $(COMMON_FLAGS)

default : $(SRC)
	$(SIM) $(VCSFLAGS) $(INC_V_FLAGS) $(INC_SV_FLAGS) -o $(TARGET) $(SRC)


mat_gen : $(SRC) .cp_mat_gen
	$(SIM) $(VCSFLAGS) $(INC_V_FLAGS) $(INC_SV_FLAGS) -o $(TARGET) $(SRC)


.cp_mat_gen :
	python3 generate_matrix.py rom16_16_gen.mif rom16_32_gen.mif ram8_16_gen.mif oam_gen.mif hram_gen.mif
	cp rom16_16_gen.mif quartus_block_ram_sv/mif_files/16kB_word16bit_init.mif
	cp rom16_32_gen.mif rquartus_block_ram_sv/mif_files/16kB_word32bit_init.mif
	cp ram8_16_gen.mif quartus_block_ram_sv/mif_files/8kB_word16bit_init.mif
	cp oam_gen.mif quartus_block_ram_sv/mif_files/oam_init.mif
	cp hram_gen.mif quartus_block_ram_sv/mif_files/hram_init.mif


clean :
	-rm -r csrc
	-rm -r DVEfiles
	-rm $(TARGET)
	-rm -r $(TARGET).daidir
	-rm ucli.key
	-rm quartus_block_ram_sv/mif_files/*.mif

MODULE?=TB

test_one : .vlogan
	$(SIM) $(VCSUUMFLAGS) -nc $(MODULE)

.vlogan :
	vlogan $(VLOGANFLAGS) $(INC_V_FLAGS) $(INC_SV_FLAGS) $(SRC)

.PHONY : mat1 mat2 mat_gen .cp_mat1 .cp_mat2 .cp_mat_gen clean .vlogan test_one
