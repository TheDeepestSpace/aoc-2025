import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


def pack_row(row_bits):
    value = 0
    width = len(row_bits)
    for idx, bit in enumerate(row_bits):
        if bit:
            value |= 1 << (width - 1 - idx)
    return value


def unpack_row(value, cols):
    return [((value >> (cols - 1 - idx)) & 1) for idx in range(cols)]


async def run_case(clk, start_sig, aug_in, ready_sig, aug_internal, matrix, expected):
    rows = len(matrix)
    cols = len(matrix[0]) if rows else 0

    for r in range(rows):
        aug_in[r].value = pack_row(matrix[r])

    start_sig.value = 0
    await RisingEdge(clk)
    start_sig.value = 1
    await RisingEdge(clk)
    start_sig.value = 0

    max_cycles = cols * (rows + 3) + 10
    for _ in range(max_cycles):
        await RisingEdge(clk)
        if int(ready_sig.value):
            break
    else:
        raise AssertionError("Timed out waiting for ready")

    observed = []
    for r in range(rows):
        row_val = int(aug_internal[r].value)
        observed.append(unpack_row(row_val, cols))

    if observed != expected:
        raise AssertionError(f"RREF mismatch: expected {expected}, got {observed}")


@cocotb.test()
async def rref_matrices(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.u_rref_2x3.start.value = 0
    dut.u_rref_3x4.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    cases_2x3 = [
        {
            "matrix": [
              [1, 0, 0],
              [0, 1, 0]
            ],
            "expected": [
              [1, 0, 0],
              [0, 1, 0]
            ],
        },
        {
            "matrix": [
              [1, 1, 0],
              [1, 0, 1]
            ],
            "expected": [
              [1, 0, 1],
              [0, 1, 1]
            ],
        },
        {
            "matrix": [
              [0, 1, 1],
              [1, 1, 0]
            ],
            "expected": [
              [1, 0, 1],
              [0, 1, 1]
            ],
        },
    ]
    cases_3x4 = [
        {
            "matrix": [
              [1, 0, 1, 0],
              [1, 1, 0, 1],
              [0, 1, 1, 1]
            ],
            "expected": [
              [1, 0, 1, 0],
              [0, 1, 1, 1],
              [0, 0, 0, 0]
            ],
        },
        {
            "matrix": [
              [0, 1, 0, 1],
              [1, 1, 1, 0],
              [1, 0, 1, 1]
            ],
            "expected": [
              [1, 0, 1, 1],
              [0, 1, 0, 1],
              [0, 0, 0, 0]
            ],
        },
    ]

    for case in cases_2x3:
        await run_case(
            dut.clk,
            dut.start_2x3,
            dut.aug_2x3,
            dut.ready_2x3,
            dut.u_rref_2x3.aug,
            case["matrix"],
            case["expected"],
        )
        await RisingEdge(dut.clk)

    for case in cases_3x4:
        await run_case(
            dut.clk,
            dut.start_3x4,
            dut.aug_3x4,
            dut.ready_3x4,
            dut.u_rref_3x4.aug,
            case["matrix"],
            case["expected"],
        )
        await RisingEdge(dut.clk)
