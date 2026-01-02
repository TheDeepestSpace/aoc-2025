from dataclasses import dataclass

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


@dataclass(frozen=True)
class RrefCase:
    rows: int
    cols: int
    matrix: list[list[int]]
    expected: list[list[int]]


def pack_row(row_bits):
    value = 0
    width = len(row_bits)
    for idx, bit in enumerate(row_bits):
        if bit:
            value |= 1 << (width - 1 - idx)
    return value


def unpack_row(value, cols):
    return [((value >> (cols - 1 - idx)) & 1) for idx in range(cols)]


async def run_case(dut, case, max_rows, max_cols):
    rows = case.rows
    cols = case.cols
    matrix = case.matrix
    expected = case.expected

    if rows != len(matrix) or cols != len(matrix[0]):
        raise AssertionError("Case dimensions do not match matrix shape")

    dut.rows.value = rows
    dut.cols.value = cols

    for r in range(max_rows):
        dut.aug[r].value = 0

    for r in range(rows):
        row_bits = matrix[r] + ([0] * (max_cols - cols))
        dut.aug[r].value = pack_row(row_bits)

    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    max_cycles = cols * (rows + 3) + 10
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if int(dut.ready.value):
            break
    else:
        raise AssertionError("Timed out waiting for ready")

    observed = []
    for r in range(rows):
        row_val = int(dut.rref[r].value)
        observed.append(unpack_row(row_val, max_cols)[:cols])

    if observed != expected:
        raise AssertionError(f"RREF mismatch: expected {expected}, got {observed}")


@cocotb.test()
async def rref_matrices(dut):
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

    cases = [
        RrefCase(
            rows=2,
            cols=3,
            matrix=[
                [1, 0, 0],
                [0, 1, 0],
            ],
            expected=[
                [1, 0, 0],
                [0, 1, 0],
            ],
        ),
        RrefCase(
            rows=2,
            cols=3,
            matrix=[
                [1, 1, 0],
                [1, 0, 1],
            ],
            expected=[
                [1, 0, 1],
                [0, 1, 1],
            ],
        ),
        RrefCase(
            rows=2,
            cols=3,
            matrix=[
                [0, 1, 1],
                [1, 1, 0],
            ],
            expected=[
                [1, 0, 1],
                [0, 1, 1],
            ],
        ),
        RrefCase(
            rows=3,
            cols=4,
            matrix=[
                [1, 0, 1, 0],
                [1, 1, 0, 1],
                [0, 1, 1, 1],
            ],
            expected=[
                [1, 0, 1, 0],
                [0, 1, 1, 1],
                [0, 0, 0, 0],
            ],
        ),
        RrefCase(
            rows=3,
            cols=4,
            matrix=[
                [0, 1, 0, 1],
                [1, 1, 1, 0],
                [1, 0, 1, 1],
            ],
            expected=[
                [1, 0, 1, 1],
                [0, 1, 0, 1],
                [0, 0, 0, 0],
            ],
        ),
        RrefCase(
            rows=4,
            cols=7,
            matrix=[
                [0, 0, 0, 0, 1, 1, 0],
                [0, 1, 0, 0, 0, 1, 1],
                [0, 0, 1, 1, 1, 0, 1],
                [1, 1, 0, 1, 0, 0, 0],
            ],
            expected=[
                [1, 0, 0, 1, 0, 1, 1],
                [0, 1, 0, 0, 0, 1, 1],
                [0, 0, 1, 1, 0, 1, 1],
                [0, 0, 0, 0, 1, 1, 0],
            ],
        ),
    ]

    for case in cases:
        await run_case(dut, case, max_rows, max_cols)
        await RisingEdge(dut.clk)
