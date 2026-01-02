`default_nettype none

`include "axi_stream_if.svh"

module configure_machine_tb;
  logic clk;
  logic rst_n;

  logic       start_4x6;
  logic [3:0] buttons_4x6 [5:0];
  logic [3:0] target_4x6;
  logic       ready_4x6;
  logic [2:0] min_presses_4x6;
  logic [5:0] buttons_to_press_4x6;

  logic       start_5x5;
  logic [4:0] buttons_5x5 [4:0];
  logic [4:0] target_5x5;
  logic       ready_5x5;
  logic [2:0] min_presses_5x5;
  logic [4:0] buttons_to_press_5x5;

  logic       start_6x4;
  logic [5:0] buttons_6x4 [3:0];
  logic [5:0] target_6x4;
  logic       ready_6x4;
  logic [2:0] min_presses_6x4;
  logic [3:0] buttons_to_press_6x4;

  configure_machine #( .NUM_LIGHTS( 4 ), .NUM_BUTTONS( 6 ) ) u_cfg_4x6
    ( .clk                       ( clk                  )
    , .rst_n                     ( rst_n                )
    , .start                     ( start_4x6            )
    , .buttons                   ( buttons_4x6          )
    , .target_lights_arrangement ( target_4x6           )
    , .ready                     ( ready_4x6            )
    , .min_button_presses        ( min_presses_4x6      )
    , .buttons_to_press          ( buttons_to_press_4x6 )
    );

  configure_machine #( .NUM_LIGHTS( 5 ), .NUM_BUTTONS( 5 ) ) u_cfg_5x5
    ( .clk                       ( clk                  )
    , .rst_n                     ( rst_n                )
    , .start                     ( start_5x5            )
    , .buttons                   ( buttons_5x5          )
    , .target_lights_arrangement ( target_5x5           )
    , .ready                     ( ready_5x5            )
    , .min_button_presses        ( min_presses_5x5      )
    , .buttons_to_press          ( buttons_to_press_5x5 )
    );

  configure_machine #( .NUM_LIGHTS( 6 ), .NUM_BUTTONS( 4 ) ) u_cfg_6x4
    ( .clk                       ( clk                  )
    , .rst_n                     ( rst_n                )
    , .start                     ( start_6x4            )
    , .buttons                   ( buttons_6x4          )
    , .target_lights_arrangement ( target_6x4           )
    , .ready                     ( ready_6x4            )
    , .min_button_presses        ( min_presses_6x4      )
    , .buttons_to_press          ( buttons_to_press_6x4 )
    );

  // Tie tready high for internal solution streams
  assign u_cfg_4x6.solution_stream.tready = 1'b1;
  assign u_cfg_5x5.solution_stream.tready = 1'b1;
  assign u_cfg_6x4.solution_stream.tready = 1'b1;

endmodule
