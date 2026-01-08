from dataclasses import dataclass

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout


def pack_bits(bits):
    value = 0
    for idx, bit in enumerate(bits):
        if bit:
            value |= 1 << idx
    return value


@dataclass(frozen=True)
class ConfigureCase:
    num_lights: int
    buttons: list[list[int]]
    target: list[int]
    expected_count: int
    expected_masks: set[int]


async def run_case(dut, case, max_lights, max_buttons):
    num_buttons = len(case.buttons)
    if num_buttons > max_buttons:
        raise AssertionError("Case exceeds max buttons")
    if case.num_lights > max_lights:
        raise AssertionError("Case exceeds max lights")

    dut.day10_input.num_lights.value = case.num_lights
    dut.day10_input.num_buttons.value = num_buttons

    for b_idx in range(max_buttons):
        dut.day10_input.buttons[b_idx].value = 0

    for b_idx, btn in enumerate(case.buttons):
        mask = pack_bits([(l in btn) for l in range(max_lights)])
        dut.day10_input.buttons[b_idx].value = mask

    target_bits = case.target + ([0] * (max_lights - len(case.target)))
    dut.day10_input.target_lights_arrangement.value = pack_bits(target_bits)

    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.accepted.value = 1;
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await with_timeout(RisingEdge(dut.ready), 200, "us")

    observed_count = int(dut.day10_output.min_button_presses.value)
    observed_mask_raw = int(dut.day10_output.buttons_to_press.value)
    observed_mask = 0
    for idx in range(max_buttons):
        if observed_mask_raw & (1 << (max_buttons - 1 - idx)):
            observed_mask |= 1 << idx

    if observed_count != case.expected_count:
        raise AssertionError(
            f"min presses mismatch: expected {case.expected_count}, got {observed_count}"
        )
    if observed_mask not in case.expected_masks:
        raise AssertionError(
            f"buttons_to_press mismatch: expected one of {sorted(case.expected_masks)}, got {observed_mask}"
        )


@cocotb.test()
async def configure_machine_vectors(dut):
    max_lights = 6
    max_buttons = 6

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.start.value = 0
    dut.day10_input.num_lights.value = 0
    dut.day10_input.num_buttons.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    cases = [
        ConfigureCase(
            num_lights=4,
            buttons=[
                [3],
                [1, 3],
                [2],
                [2, 3],
                [0, 2],
                [0, 1],
            ],
            target=[0, 1, 1, 0],
            expected_count=2,
            expected_masks={(1 << 4) | (1 << 5), (1 << 1) | (1 << 3)},
        ),
        ConfigureCase(
            num_lights=5,
            buttons=[
                [0, 2, 3, 4],
                [2, 3],
                [0, 4],
                [0, 1, 2],
                [1, 2, 3, 4],
            ],
            target=[0, 0, 0, 1, 0],
            expected_count=3,
            expected_masks={(1 << 2) | (1 << 3) | (1 << 4)},
        ),
        ConfigureCase(
            num_lights=6,
            buttons=[
                [0, 1, 2, 3, 4],
                [0, 3, 4],
                [0, 1, 2, 4, 5],
                [1, 2],
            ],
            target=[0, 1, 1, 1, 0, 1],
            expected_count=2,
            expected_masks={(1 << 2) | (1 << 1)},
        ),
    ]

    for case in cases:
        await run_case(dut, case, max_lights, max_buttons)
