# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(CURDIR)/../../src/axi_stream_if.svh \
                   $(CURDIR)/../../src/day10.sv \
                   $(CURDIR)/../../src/day10_input_if.svh \
                   $(CURDIR)/../../src/day10_input_reader.sv \
                   $(CURDIR)/../../src/day10_output_if.svh \
                   $(CURDIR)/../../src/day10_output_writer.sv \
                   $(CURDIR)/../../src/axi_read_vector.sv \
                   $(CURDIR)/../../src/axi_write_vector.sv \
                   $(CURDIR)/../../src/flag_fifo.sv \
                   $(CURDIR)/../../src/popcount.sv \
                   $(CURDIR)/../../src/popcount_chain.sv \
                   $(CURDIR)/../../src/enumerate_solutions.sv \
                   $(CURDIR)/../../src/gf2_rref.sv \
                   $(CURDIR)/../../src/configure_machine.sv \
                   $(CURDIR)/day10_tb.sv \

# need to be able to import controller module
export PYTHONPATH := $(PWD)/../..:$(PYTHONPATH)

TOPLEVEL = day10_tb
MODULE = test_integration

COMPILE_ARGS += --trace-fst --trace-structs -I$(CURDIR)/../../src
SIM_ARGS += --trace

include $(shell cocotb-config --makefiles)/Makefile.sim
