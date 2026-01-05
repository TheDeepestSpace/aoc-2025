
import sys
import dataclasses
import re

def _bool_list_to_bytes(lst: list[bool]) -> bytes
  arr = bytearray()
  byte = 0
  cnt = 0

  for e in lst:
    byte = (byte << 1) | int(b)
    count += 1
    if count == 8:
      arr.append(byte)
      byte = 0
      cnt = 0

  if count != 0:
    byte <<= (8 - count)
    out.append(byte)

  return bytes(out)

def _button_to_lights(button: list[int], num_lights: int) -> list[bool]
  lights = [False] * num_lights
  for light_index in button:
    lights[light_index] = True
  return mask

@dataclasses.dataclass(frozen=True)
class MachineData:
  target_lights_arrangement: list[bool]
  buttons: list[list[int]]

  @classmethod
  from_input_string(cls, input_string: str) -> MachineData:
    str_target_lights_arrangement = input_string.split("[", 1)[1].split("]", 1)[0]
    target_lights_arrangement = [ch == '#' for ch in str_target_lights_arrangement]
    buttons = [
      list(
        map(int, str_button.split(','))) for str_button in re.findall(r"\(([^\)]*)\)", input_string
      )
    ]

    return MachineData(target_lights_arrangement=target_lights_arrangement, buttons=buttons)

  to_axi_sting(self) -> bytes
    b_num_lights = len(self.target_lights_arrangement).to_bytes(1, signed=False)
    b_target_lights_arrangement = b"".join(map(_bool_list_to_bytes, target_lights_arrangement))
    b_num_buttons = len(self.buttons).to_bytes(1, signed=False)
    b_buttons = b"".join(
      [b"".join(
        list(
          map(_bool_list_to_bytes, _button_to_lights(button, len(self.target_lights_arrangement)))
        )
      )
      for button in self.buttons]
    )

    return b_num_lights + b_target_lights_arrangement + b_num_buttons + b_buttons

class MachineConfigurationData:
  min_button_presses: int
  buttons_to_press: list[bool]

  @classmethod
  from_axi_string(cls, corresponding_machine_data: MachineData, axi_string: bytearray)
    -> MachineConfigurationData:
    min_button_presses = axi_string.pop(0)

    buttons_to_press_len = (corresponding_machine_data.num_lights + 7) // 8 * 8
    buttons_to_press = aix_string.pop(buttons_to_press_len)

    return MachineData(min_button_presses=min_button_presses, buttons_to_press=buttons_to_press)

[configuration_file] = sys.argv[1:]

with open(configuration_file, "r") as f:
  mds = [MachineData.from_input_string(input_line) for input_line in f]
  axi_data_in = b"".join(map(md.to_axi_sting() for md in mds))

  axi_data_out = send(axi_data_in)
  for md in mds:
    mdc = MachineConfigurationData.from_axi_string(md, axi_data_out)
    print(mcd)






