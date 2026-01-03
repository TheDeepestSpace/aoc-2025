from dataclasses import dataclass

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


@dataclass(frozen=True)
class EnumCase:
    rows: int
    cols: int
    rref: list[list[int]]
    expected: list[list[int]]
    unordered: bool = False


async def collect_solutions(sink, count):
    frame = await with_timeout(sink.recv(), 5, "us")
    if isinstance(frame.tdata, (bytes, bytearray)):
        solutions = list(frame.tdata)
    else:
        solutions = list(frame.tdata)
    if len(solutions) != count:
        raise AssertionError(f"solution count mismatch: expected {count}, got {len(solutions)}")
    return solutions


async def run_case(dut, sink, case, max_rows, max_cols):
    rows = case.rows
    cols = case.cols
    rref = case.rref
    expected = case.expected

    if rows != len(rref) or cols != len(rref[0]):
        raise AssertionError("Case dimensions do not match rref shape")

    dut.rows.value = rows
    dut.cols.value = cols

    for r in range(max_rows):
        dut.rref[r].value = 0

    for r in range(rows):
        row_bits = rref[r] + ([0] * (max_cols - cols))
        dut.rref[r].value = pack_row(row_bits)

    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    vars_count = cols - 1
    received = await collect_solutions(sink, len(expected))
    received_bits = [unpack_word(word, 8)[:vars_count] for word in received]
    if case.unordered:
        if sorted(received_bits) != sorted(expected):
            raise AssertionError(f"mismatch: expected {expected}, got {received_bits}")
    else:
        if received_bits != expected:
            raise AssertionError(f"mismatch: expected {expected}, got {received_bits}")


@cocotb.test()
async def enumerate_solutions_vectors(dut):
    max_rows = 4
    max_cols = 7

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.start.value = 0
    dut.rows.value = 0
    dut.cols.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    bus = AxiStreamBus.from_prefix(dut, "sol")
    sink = AxiStreamSink(bus, dut.clk, dut.rst_n, reset_active_level=False)
    cases = [
        EnumCase(
            rows=2,
            cols=3,
            rref=[
                [1, 0, 1],
                [0, 1, 0],
            ],
            expected=[
                [1, 0],
            ],
        ),
        EnumCase(
            rows=2,
            cols=3,
            rref=[
                [1, 1, 0],
                [0, 0, 0],
            ],
            expected=[
                [0, 0],
                [1, 1],
            ],
        ),
        EnumCase(
            rows=3,
            cols=4,
            rref=[
                [1, 0, 1, 0],
                [0, 1, 1, 1],
                [0, 0, 0, 0],
            ],
            expected=[
                [0, 1, 0],
                [1, 0, 1],
            ],
        ),
        EnumCase(
            rows=4,
            cols=7,
            rref=[
                [1, 0, 0, 1, 0, 1, 1],
                [0, 1, 0, 0, 0, 1, 1],
                [0, 0, 1, 1, 0, 1, 1],
                [0, 0, 0, 0, 1, 1, 0],
            ],
            expected=[
                [1, 1, 1, 0, 0, 0],
                [0, 0, 0, 0, 1, 1],
                [0, 1, 0, 1, 0, 0],
                [1, 0, 1, 1, 1, 1],
            ],
            unordered=True,
        ),
    ]

    for case in cases:
        await run_case(dut, sink, case, max_rows, max_cols)
