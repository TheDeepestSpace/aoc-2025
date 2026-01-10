import tempfile
import logging

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from controller import controller


@cocotb.test()
async def day10_integration(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    logging.warning("rising edge start axi")
    await RisingEdge(dut.clk)
    logging.warning("rising edge end axi")

    in_bus = AxiStreamBus.from_prefix(dut, "data_in")
    out_bus = AxiStreamBus.from_prefix(dut, "data_out")
    source = AxiStreamSource(in_bus, dut.clk, dut.rst_n, reset_active_level=False)
    sink = AxiStreamSink(out_bus, dut.clk, dut.rst_n, reset_active_level=False)

    input_lines = [
        "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}",
        "[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}",
        "[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}"
    ]
    with tempfile.NamedTemporaryFile("w", delete=False) as handle:
        handle.write("\n".join(input_lines))
        input_path = handle.name

    async def send(payload: bytes) -> bytes:
        logging.warning("sending payload over axi")
        await with_timeout(source.send(AxiStreamFrame(payload)), 100, "us")
        frame = await with_timeout(sink.recv(), 100, "us")
        return bytes(frame.tdata)

    is_all_good = await controller.control(input_path, send)

    assert is_all_good
