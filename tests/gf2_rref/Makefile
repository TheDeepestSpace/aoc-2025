# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(CURDIR)/../../src/gf2_rref.sv $(CURDIR)/gf2_rref_tb.sv

TOPLEVEL = gf2_rref_tb
MODULE = test_gf2_rref

COMPILE_ARGS += --trace-fst --trace-structs
SIM_ARGS += --trace

include $(shell cocotb-config --makefiles)/Makefile.sim
