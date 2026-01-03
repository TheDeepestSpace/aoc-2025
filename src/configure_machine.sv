`default_nettype none

module configure_machine
  #(parameter int unsigned MAX_NUM_LIGHTS
  , parameter int unsigned MAX_NUM_BUTTONS
  , parameter int unsigned MAX_NUM_BUTTONS_W =
      MAX_NUM_BUTTONS <= 1 ? 1 : $clog2(MAX_NUM_BUTTONS + 1)
  , parameter int unsigned MAX_NUM_LIGHTS_W  = MAX_NUM_LIGHTS <= 1 ? 1 : $clog2(MAX_NUM_LIGHTS + 1)
  , parameter int unsigned MAX_NUM_PRESSES_W = MAX_NUM_BUTTONS_W
  )
  ( input var logic clk
  , input var logic rst_n

  , input  var logic start
  , output var logic ready

  , day10_input_if #( MAX_NUM_LIGHTS, MAX_NUM_BUTTONS ) day10_input
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

  localparam int unsigned MAX_AUG_MAT_ROWS = MAX_NUM_LIGHTS;
  localparam int unsigned MAX_AUG_MAT_COLS = MAX_NUM_BUTTONS + 1;
  localparam int unsigned MAX_AUG_MAT_COLS_W =
    MAX_AUG_MAT_COLS <= 1 ? 1 : $clog2(MAX_AUG_MAT_COLS + 1);

  logic [MAX_AUG_MAT_COLS -1:0] augmented_matrix [MAX_AUG_MAT_ROWS -1:0];

  for (genvar r = 0; r < MAX_AUG_MAT_ROWS; r++) begin: l_build_aug_mat_rows
    for (genvar c = MAX_AUG_MAT_COLS -1; c >= 1; c--) begin: l_build_aug_mat_rows
      always_comb
        if (r < num_lights && MAX_AUG_MAT_COLS -1 -c < num_buttons)
          augmented_matrix[r][c] = buttons[MAX_AUG_MAT_COLS -1 - c][r];
        else
          augmented_matrix[r][c] = 'x;
    end
  end

  for (genvar l = 0; l < MAX_AUG_MAT_ROWS; l++) begin: l_build_aug_mat_last_col
    always_comb
      if (l < num_lights)
        augmented_matrix[l][MAX_AUG_MAT_COLS_W'(MAX_AUG_MAT_COLS -1 - num_buttons)] =
          target_lights_arrangement[l];
      else
        augmented_matrix[l][MAX_AUG_MAT_COLS_W'(MAX_AUG_MAT_COLS -1 - num_buttons)] = 'x;
  end

  // compute RREF

  logic rref_start, rref_ready;
  logic [MAX_AUG_MAT_COLS -1:0] rref [MAX_AUG_MAT_ROWS -1:0];

  always_ff @ (posedge clk)
    if (state_now == STATE__START_COMPUTE_RREF) rref_start <= 1'b1;
    else                                        rref_start <= '0;

  gf2_rref
    #(.MAX_ROWS ( MAX_AUG_MAT_ROWS )
    , .MAX_COLS ( MAX_AUG_MAT_COLS )
    )
    u_gf2_rref
      ( .clk   ( clk              )
      , .rst_n ( rst_n            )

      , .rows  ( num_lights       )
      , .cols  ( num_buttons + 1  )

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

  enumerate_solutions
    #(.MAX_ROWS ( MAX_AUG_MAT_ROWS )
    , .MAX_COLS ( MAX_AUG_MAT_COLS )
    )
    u_enumerate_solutions
      ( .clk             ( clk                       )
      , .rst_n           ( rst_n                     )

      , .rows            ( num_lights                )
      , .cols            ( num_buttons + 1           )

      , .start           ( enumerate_solutions_start )
      , .RREF            ( rref                      )

      , .solution_stream ( solution_stream.master    )
      );

  // track cheapest solution

  logic [MAX_NUM_BUTTONS -1:0]   current_solution;
  logic [MAX_NUM_PRESSES_W -1:0] current_solution_popcount;

  always_comb current_solution =
    solution_stream.tdata
      [ solution_stream.DATA_WIDTH -1
      : solution_stream.DATA_WIDTH -1 - MAX_NUM_BUTTONS +1
      ];

  popcount
    #(.MAX_N ( MAX_NUM_BUTTONS   )
    , .MAX_W ( MAX_NUM_PRESSES_W )
    )
    u_solution_popcount
      ( .in    ( current_solution          )
      , .n     ( num_buttons               )
      , .count ( current_solution_popcount )
      );

  always_ff @ (posedge clk)
    if (!rst_n)
      {min_button_presses, buttons_to_press} <=
        {{MAX_NUM_PRESSES_W{1'b1}}, {MAX_NUM_BUTTONS{1'b0}}};
    else if (state_now == STATE__INIT)
      {min_button_presses, buttons_to_press} <=
        {{MAX_NUM_PRESSES_W{1'b1}}, {MAX_NUM_BUTTONS{1'b0}}};
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
