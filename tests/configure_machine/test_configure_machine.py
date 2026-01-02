import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout


def pack_bits(bits):
    value = 0
    for idx, bit in enumerate(bits):
        if bit:
            value |= 1 << idx
    return value


async def drive_case(dut, start_sig, buttons_sig, target_sig, ready_sig, min_presses_sig, press_mask_sig,
                     num_lights, buttons, target_bits, expected_count, expected_masks):
    for b_idx, btn in enumerate(buttons):
        mask = pack_bits([(l in btn) for l in range(num_lights)])
        buttons_sig[b_idx].value = mask
    target_sig.value = pack_bits(target_bits)

    start_sig.value = 0
    await RisingEdge(dut.clk)
    start_sig.value = 1
    await RisingEdge(dut.clk)
    start_sig.value = 0

    await with_timeout(RisingEdge(ready_sig), 200, "us")

    observed_count = int(min_presses_sig.value)
    observed_mask = int(press_mask_sig.value)

    if observed_count != expected_count:
        raise AssertionError(f"min presses mismatch: expected {expected_count}, got {observed_count}")
    if observed_mask not in expected_masks:
        raise AssertionError(
            f"buttons_to_press mismatch: expected one of {sorted(expected_masks)}, got {observed_mask}"
        )


@cocotb.test()
async def configure_machine_vectors(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.start_4x6.value = 0
    dut.start_5x5.value = 0
    dut.start_6x4.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    cases = [
        {
            "num_lights": 4,
            "buttons": [
                [3],
                [1, 3],
                [2],
                [2, 3],
                [0, 2],
                [0, 1],
            ],
            "target": [0, 1, 1, 0],
            "expected_count": 2,
            "expected_masks": {(1 << 1) | (1 << 0), (1 << 4) | (1 << 2)},
            "start": dut.start_4x6,
            "buttons_sig": dut.buttons_4x6,
            "target_sig": dut.target_4x6,
            "ready": dut.ready_4x6,
            "min_presses": dut.min_presses_4x6,
            "press_mask": dut.buttons_to_press_4x6,
        },
        {
            "num_lights": 5,
            "buttons": [
                [0, 2, 3, 4],
                [2, 3],
                [0, 4],
                [0, 1, 2],
                [1, 2, 3, 4],
            ],
            "target": [0, 0, 0, 1, 0],
            "expected_count": 3,
            "expected_masks": {(1 << 2) | (1 << 1) | (1 << 0)},
            "start": dut.start_5x5,
            "buttons_sig": dut.buttons_5x5,
            "target_sig": dut.target_5x5,
            "ready": dut.ready_5x5,
            "min_presses": dut.min_presses_5x5,
            "press_mask": dut.buttons_to_press_5x5,
        },
        {
            "num_lights": 6,
            "buttons": [
                [0, 1, 2, 3, 4],
                [0, 3, 4],
                [0, 1, 2, 4, 5],
                [1, 2],
            ],
            "target": [0, 1, 1, 1, 0, 1],
            "expected_count": 2,
            "expected_masks": {(1 << 2) | (1 << 1)},
            "start": dut.start_6x4,
            "buttons_sig": dut.buttons_6x4,
            "target_sig": dut.target_6x4,
            "ready": dut.ready_6x4,
            "min_presses": dut.min_presses_6x4,
            "press_mask": dut.buttons_to_press_6x4,
        },
    ]

    for case in cases:
        await drive_case(
            dut,
            case["start"],
            case["buttons_sig"],
            case["target_sig"],
            case["ready"],
            case["min_presses"],
            case["press_mask"],
            case["num_lights"],
            case["buttons"],
            case["target"],
            case["expected_count"],
            case["expected_masks"],
        )
