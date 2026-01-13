`default_nettype none

`include "axi_stream_if.svh"

module configure_machine_tb;
  localparam int unsigned MAX_NUM_LIGHTS = 6;
  localparam int unsigned MAX_NUM_BUTTONS = 6;
  localparam int unsigned MAX_NUM_BUTTONS_W =
    (MAX_NUM_BUTTONS <= 1) ? 1 : $clog2(MAX_NUM_BUTTONS + 1);
  localparam int unsigned MAX_NUM_LIGHTS_W =
    (MAX_NUM_LIGHTS <= 1) ? 1 : $clog2(MAX_NUM_LIGHTS + 1);
  localparam int unsigned MAX_NUM_PRESSES_W = MAX_NUM_BUTTONS_W;

  logic clk;
  logic rst_n;

  logic start;
  logic ready;
  logic accepted;

  day10_input_if  #( MAX_NUM_LIGHTS, MAX_NUM_BUTTONS ) day10_input();
  day10_output_if #( MAX_NUM_BUTTONS )                 day10_output();

  logic day10_input_busy;

  configure_machine
    #(.MAX_NUM_LIGHTS  ( MAX_NUM_LIGHTS  )
    , .MAX_NUM_BUTTONS ( MAX_NUM_BUTTONS )
    )
    u_cfg
      ( .clk                       ( clk              )
      , .rst_n                     ( rst_n            )

      , .start                     ( start            )
      , .ready                     ( ready            )
      , .accepted                  ( accepted         )

      , .day10_input               ( day10_input      )
      , .day10_output              ( day10_output     )

      , .day10_input_busy          ( day10_input_busy )
      );

endmodule
