import dataclasses
import logging
import re
from typing import Awaitable, Callable


def _bool_list_to_bytes(bits: list[bool]) -> bytes:
    arr = bytearray()
    byte = 0
    count = 0

    for bit in bits:
        if bit:
            byte |= 1 << count
        count += 1
        if count == 8:
            arr.append(byte)
            byte = 0
            count = 0

    if count != 0:
        arr.append(byte)

    return bytes(arr)


def _bytes_to_bool_list(data: bytes, num_bits: int) -> list[bool]:
    bits = []
    for idx in range(num_bits):
        byte = data[idx // 8]
        bits.append(bool((byte >> (7 - (idx % 8))) & 1))
    return bits


def _button_to_lights(button: list[int], num_lights: int) -> list[bool]:
    lights = [False] * num_lights
    for light_index in button:
        lights[light_index] = True
    return lights


@dataclasses.dataclass(frozen=True)
class MachineData:
    target_lights_arrangement: list[bool]
    buttons: list[list[int]]

    @classmethod
    def from_input_string(cls, input_string: str) -> "MachineData":
        str_target_lights_arrangement = input_string.split("[", 1)[1].split("]", 1)[0]
        target_lights_arrangement = [ch == "#" for ch in str_target_lights_arrangement]
        buttons = [
            list(map(int, str_button.split(",")))
            for str_button in re.findall(r"\(([^\)]*)\)", input_string)
        ]

        return cls(target_lights_arrangement=target_lights_arrangement, buttons=buttons)

    def to_axi_string(self) -> bytes:
        b_num_lights = \
          len(self.target_lights_arrangement).to_bytes(1, byteorder="big", signed=False)
        b_target_lights_arrangement = _bool_list_to_bytes(self.target_lights_arrangement)
        b_num_buttons = len(self.buttons).to_bytes(1, byteorder="big", signed=False)
        b_buttons = b"".join(
            _bool_list_to_bytes(
                _button_to_lights(button, len(self.target_lights_arrangement))
            )
            for button in self.buttons
        )

        return b_num_lights + b_target_lights_arrangement + b_num_buttons + b_buttons


@dataclasses.dataclass(frozen=True)
class MachineConfigurationData:
    min_button_presses: int
    buttons_to_press: list[bool]

    @classmethod
    def from_axi_string(
        cls, corresponding_machine_data: MachineData, axi_string: bytearray
    ) -> "MachineConfigurationData":
        min_button_presses = axi_string.pop(0)

        num_buttons = len(corresponding_machine_data.buttons)
        buttons_to_press_len = (num_buttons + 7) // 8
        buttons_to_press_bytes = bytes(axi_string[:buttons_to_press_len])
        del axi_string[:buttons_to_press_len]
        buttons_to_press = _bytes_to_bool_list(buttons_to_press_bytes, num_buttons)

        return cls(
            min_button_presses=min_button_presses, buttons_to_press=buttons_to_press
        )

def analyse_configuration(num: int, md: MachineData, mdc: MachineConfigurationData):
    num_lights = len(md.target_lights_arrangement)
    expected = "".join("#" if light_on else "." for light_on in md.target_lights_arrangement)
    print(f"[machine {num}] expected:")
    print(f"[machine {num}] [{expected}]")
    print(f"[machine {num}] configuring: (in {mdc.min_button_presses} button presses)")
    lights = [False] * num_lights
    print(f"[machine {num}] [" + "." * num_lights + "]")
    for idx, should_press in enumerate(mdc.buttons_to_press):
        if not should_press:
            continue
        for light_index in md.buttons[idx]:
            lights[light_index] = not lights[light_index]
        print(f"[machine {num}] [" + "".join("#" if light_on else "." for light_on in lights) + "]")
    print(f"[machine {num}] done configuring")
    print(f"[machine {num}] lights match target arrangement: {lights == md.target_lights_arrangement}")

    return lights == md.target_lights_arrangement

async def control(input_file: str, send: Callable[[bytes], Awaitable[bytes]]) -> None:
    with open(input_file, "r", encoding="utf-8") as f:
        mds = [MachineData.from_input_string(input_line) for input_line in f]
        axi_data_in = b"".join(md.to_axi_string() for md in mds)

    axi_data_out = bytearray(await send(axi_data_in))

    all_good = True

    for idx, md in enumerate(mds):
        mdc = MachineConfigurationData.from_axi_string(md, axi_data_out)
        all_good &= analyse_configuration(idx + 1, md, mdc)

    return all_good
