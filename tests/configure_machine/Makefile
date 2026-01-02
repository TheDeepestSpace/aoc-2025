# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(CURDIR)/../../src/axi_stream_if.svh \
                   $(CURDIR)/../../src/popcount.sv \
                   $(CURDIR)/../../src/popcount_chain.sv \
                   $(CURDIR)/../../src/enumerate_solutions.sv \
                   $(CURDIR)/../../src/gf2_rref.sv \
                   $(CURDIR)/../../src/configure_machine.sv \
                   $(CURDIR)/configure_machine_tb.sv

TOPLEVEL = configure_machine_tb
MODULE = test_configure_machine

COMPILE_ARGS += --trace-fst --trace-structs -I$(CURDIR)/../../src
SIM_ARGS += --trace

include $(shell cocotb-config --makefiles)/Makefile.sim
