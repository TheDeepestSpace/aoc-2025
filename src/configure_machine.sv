`default_nettype none

module configure_machine
  #(parameter int NUM_LIGHTS
  , parameter int NUM_BUTTONS
  , parameter int NUM_PRESSES_W = NUM_BUTTONS <= 1 ? 1 : $clog2(NUM_BUTTONS + 1)
  )
  ( input var logic clk
  , input var logic rst_n

  , input var logic                   start
  , input var logic [NUM_LIGHTS -1:0] buttons [NUM_BUTTONS -1:0]
  , input var logic [NUM_LIGHTS -1:0] target_lights_arrangement

  , output var logic                      ready
  , output var logic [NUM_PRESSES_W -1:0] min_button_presses
  , output var logic [NUM_BUTTONS -1:0]   buttons_to_press
  );

  // state declarations

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__START_COMPUTE_RREF
    , STATE__WAIT_COMPUTE_RREF
    , STATE__READ_SOLUTION
    , STATE__DONE
    } state_t;

  state_t state_now, state_next;

  always_ff @ (posedge clk)
    if (!rst_n) state_now <= STATE__INIT;
    else        state_now <= state_next;

  // construct augmented matrix

  localparam int unsigned AUG_MAT_ROWS = NUM_LIGHTS;
  localparam int unsigned AUG_MAT_COLS = NUM_BUTTONS + 1;
  logic [AUG_MAT_COLS -1:0] augmented_matrix [AUG_MAT_ROWS -1:0];

  for (genvar r = 0; r < AUG_MAT_ROWS; r++) begin: l_build_aug_mat_rows
    for (genvar c = AUG_MAT_COLS -1; c >= 1; c--) begin: l_build_aug_mat_rows
      always_comb augmented_matrix[r][c] = buttons[AUG_MAT_COLS -1 - c][r];
    end
  end

  for (genvar l = 0; l < AUG_MAT_ROWS; l++) begin: l_build_aug_mat_last_col
    always_comb augmented_matrix[l][0] = target_lights_arrangement[l];
  end

  // compute RREF

  logic rref_start, rref_ready;
  logic [AUG_MAT_COLS -1:0] rref [AUG_MAT_ROWS -1:0];

  always_ff @ (posedge clk)
    if (state_now == STATE__START_COMPUTE_RREF) rref_start <= 1'b1;
    else                                        rref_start <= '0;

  gf2_rref #( .ROWS ( AUG_MAT_ROWS ), .COLS ( AUG_MAT_COLS ) ) u_gf2_rref
    ( .clk   ( clk              )
    , .rst_n ( rst_n            )
    , .start ( rref_start       )
    , .AUG   ( augmented_matrix )
    , .ready ( rref_ready       )
    , .RREF  ( rref             )
    );

  // read off solutions

  logic enumerate_solutions_start;
  axi_stream_if #( .DATA_WIDTH ( 8 ) ) solution_stream();

  always_ff @ (posedge clk)
    if (!rst_n)                                 enumerate_solutions_start <= '0;
    else if (state_now == STATE__READ_SOLUTION) enumerate_solutions_start <= 1'b1;
    else                                        enumerate_solutions_start <= '0;

  enumerate_solutions #( .ROWS ( AUG_MAT_ROWS ), .COLS ( AUG_MAT_COLS ) ) u_enumerate_solutions
    ( .clk             ( clk                       )
    , .rst_n           ( rst_n                     )
    , .start           ( enumerate_solutions_start )
    , .RREF            ( rref                      )
    , .solution_stream ( solution_stream.master    )
    );

  // track cheapest solution

  logic [NUM_BUTTONS -1:0]   current_solution;
  logic [NUM_PRESSES_W -1:0] current_solution_popcount;

  always_comb current_solution = solution_stream.tdata[NUM_BUTTONS -1:0];

  popcount #( .N ( NUM_BUTTONS ) ) u_solution_popcount
    ( .in    ( current_solution          )
    , .count ( current_solution_popcount )
    );

  always_ff @ (posedge clk)
    if (!rst_n)
      {min_button_presses, buttons_to_press} <= {{NUM_PRESSES_W{1'b1}}, {NUM_BUTTONS{1'b0}}};
    else if (state_now == STATE__READ_SOLUTION
              && solution_stream.tvalid
              && current_solution_popcount < min_button_presses)
      {min_button_presses, buttons_to_press} <= {current_solution_popcount, current_solution};
    else
      {min_button_presses, buttons_to_press} <= {min_button_presses, buttons_to_press};

  // completion check

  always_ff @ (posedge clk)
    if (state_now == STATE__DONE) ready <= 1'b1;
    else                          ready <= '0;

  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (start)                 state_next = STATE__START_COMPUTE_RREF;
        else                       state_next = STATE__INIT;
      STATE__START_COMPUTE_RREF:
        if (rref_ready)            state_next = STATE__READ_SOLUTION;
        else                       state_next = STATE__WAIT_COMPUTE_RREF;
      STATE__WAIT_COMPUTE_RREF:
        if (rref_ready)            state_next = STATE__READ_SOLUTION;
        else                       state_next = STATE__WAIT_COMPUTE_RREF;
      STATE__READ_SOLUTION:
        if (solution_stream.tlast) state_next = STATE__DONE;
        else                       state_next = STATE__READ_SOLUTION;
      STATE__DONE:                 state_next = STATE__INIT;
      default:                     state_next = STATE__INIT;
    endcase

endmodule
