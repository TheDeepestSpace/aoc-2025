`default_nettype none

interface day10_input_if
  #(parameter int unsigned MAX_NUM_LIGHTS
  , parameter int unsigned MAX_NUM_BUTTONS
  , parameter int unsigned MAX_NUM_BUTTONS_W =
      MAX_NUM_BUTTONS <= 1 ? 1 : $clog2(MAX_NUM_BUTTONS + 1)
  , parameter int unsigned MAX_NUM_LIGHTS_W  = MAX_NUM_LIGHTS <= 1 ? 1 : $clog2(MAX_NUM_LIGHTS + 1)
  );

  logic [MAX_NUM_LIGHTS_W -1:0]  num_lights;
  logic [MAX_NUM_BUTTONS_W -1:0] num_buttons;

  logic [MAX_NUM_LIGHTS -1:0] buttons [MAX_NUM_BUTTONS -1:0];
  logic [MAX_NUM_LIGHTS -1:0] target_lights_arrangement;

endinterface
