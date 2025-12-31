import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout

from cocotbext.axi import AxiStreamBus, AxiStreamSink


def pack_row(row_bits):
    value = 0
    width = len(row_bits)
    for idx, bit in enumerate(row_bits):
        if bit:
            value |= 1 << (width - 1 - idx)
    return value


def unpack_word(value, width):
    return [((value >> (width - 1 - idx)) & 1) for idx in range(width)]


def frame_to_int(frame):
    tdata = frame.tdata
    if isinstance(tdata, (bytes, bytearray)):
        return int.from_bytes(tdata, byteorder="little", signed=False)
    return int(tdata)


async def collect_solutions(sink, count):
    solutions = []
    for _ in range(count):
        frame = await with_timeout(sink.recv(), 5, "us")
        solutions.append(frame_to_int(frame))
    return solutions


@cocotb.test()
async def enumerate_solutions_vectors(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.start_2x3.value = 0
    dut.start_3x4.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    bus_2x3 = AxiStreamBus.from_prefix(dut, "sol2x3")
    sink_2x3 = AxiStreamSink(bus_2x3, dut.clk, dut.rst_n, reset_active_level=False)
    rref_2x3_cases = [
        {
            "rref": [
                [1, 0, 1],
                [0, 1, 0],
            ],
            "expected": [
                [1, 0],
            ],
        },
        {
            "rref": [
                [1, 1, 0],
                [0, 0, 0],
            ],
            "expected": [
                [0, 0],
                [1, 1],
            ],
        },
    ]

    for case in rref_2x3_cases:
        for r in range(2):
            dut.rref_2x3[r].value = pack_row(case["rref"][r])
        dut.start_2x3.value = 0
        await RisingEdge(dut.clk)
        dut.start_2x3.value = 1
        await RisingEdge(dut.clk)
        dut.start_2x3.value = 0

        expected = case["expected"]
        received = await collect_solutions(sink_2x3, len(expected))
        received_bits = [unpack_word(word, 2) for word in received]
        if received_bits != expected:
            raise AssertionError(f"2x3 mismatch: expected {expected}, got {received_bits}")

    bus_3x4 = AxiStreamBus.from_prefix(dut, "sol3x4")
    sink_3x4 = AxiStreamSink(bus_3x4, dut.clk, dut.rst_n, reset_active_level=False)
    rref_3x4_cases = [
        {
            "rref": [
                [1, 0, 1, 0],
                [0, 1, 1, 1],
                [0, 0, 0, 0],
            ],
            "expected": [
                [0, 1, 0],
                [1, 0, 1],
            ],
        },
    ]

    for case in rref_3x4_cases:
        for r in range(3):
            dut.rref_3x4[r].value = pack_row(case["rref"][r])
        dut.start_3x4.value = 0
        await RisingEdge(dut.clk)
        dut.start_3x4.value = 1
        await RisingEdge(dut.clk)
        dut.start_3x4.value = 0

        expected = case["expected"]
        received = await collect_solutions(sink_3x4, len(expected))
        received_bits = [unpack_word(word, 3) for word in received]
        if received_bits != expected:
            raise AssertionError(f"3x4 mismatch: expected {expected}, got {received_bits}")
