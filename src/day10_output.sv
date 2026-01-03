interface day10_output_if
  #(parameter int unsigned MAX_NUM_BUTTONS
  , parameter int unsigned MAX_NUM_BUTTONS_W =
      MAX_NUM_BUTTONS <= 1 ? 1 : $clog2(MAX_NUM_BUTTONS + 1)
  , parameter int unsigned MAX_NUM_PRESSES_W = MAX_NUM_BUTTONS_W
  );

  logic [MAX_NUM_PRESSES_W -1:0] min_button_presses;
  logic [MAX_NUM_BUTTONS -1:0]   buttons_to_press;

endinterface
