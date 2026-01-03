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

  logic [MAX_NUM_LIGHTS_W -1:0]  num_lights;
  logic [MAX_NUM_BUTTONS_W -1:0] num_buttons;

  logic                          start;
  logic [MAX_NUM_LIGHTS -1:0]    buttons [MAX_NUM_BUTTONS -1:0];
  logic [MAX_NUM_LIGHTS -1:0]    target;

  logic                          ready;
  logic [MAX_NUM_PRESSES_W -1:0] min_presses;
  logic [MAX_NUM_BUTTONS -1:0]   buttons_to_press;

  configure_machine
    #(.MAX_NUM_LIGHTS  ( MAX_NUM_LIGHTS  )
    , .MAX_NUM_BUTTONS ( MAX_NUM_BUTTONS )
    )
    u_cfg
      ( .clk                       ( clk              )
      , .rst_n                     ( rst_n            )

      , .num_lights                ( num_lights       )
      , .num_buttons               ( num_buttons      )

      , .start                     ( start            )
      , .buttons                   ( buttons          )
      , .target_lights_arrangement ( target           )

      , .ready                     ( ready            )
      , .min_button_presses        ( min_presses      )
      , .buttons_to_press          ( buttons_to_press )
      );

  assign u_cfg.solution_stream.tready = 1'b1;

endmodule
