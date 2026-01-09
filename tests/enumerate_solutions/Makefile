# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(CURDIR)/../../src/enumerate_solutions.sv \
                   $(CURDIR)/../../src/axi_write_vector.sv \
                   $(CURDIR)/enumerate_solutions_tb.sv

TOPLEVEL = enumerate_solutions_tb
MODULE = test_enumerate_solutions

COMPILE_ARGS += --trace-fst --trace-structs -I$(CURDIR)/../../src
SIM_ARGS += --trace

include $(shell cocotb-config --makefiles)/Makefile.sim
