# Makefile for MIPS Processor (Class 13 - Final Demo)
# Targets:
#   make         : Compile and run simulation
#   make wave    : Open GTKWave
#   make clean   : Remove generated files

SRC = mips.v control_unit.v hazard_unit.v \
      main_decoder.v alu_decoder.v \
      datapath.v pc.v instruction_memory.v \
      reg_file.v alu.v data_memory.v \
      pwm_controller.v

TB  = mips_tb.v
OUT = stall.out
VCD = mips.vcd

all: compile run

compile:
	iverilog -o $(OUT) $(TB) $(SRC)

run:
	vvp -n $(OUT)

wave:
	gtkwave $(VCD) &

clean:
	if exist $(OUT) del $(OUT)
	if exist $(VCD) del $(VCD)
