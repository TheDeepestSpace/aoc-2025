`default_nettype none

`include "day10_input_if.svh"
`include "day10_output_if.svh"

module configure_machine
  #(parameter int unsigned MAX_NUM_LIGHTS
  , parameter int unsigned MAX_NUM_BUTTONS
  , parameter int unsigned MAX_NUM_BUTTONS_W =
      MAX_NUM_BUTTONS <= 1 ? 1 : $clog2(MAX_NUM_BUTTONS + 1)
  , parameter int unsigned MAX_NUM_LIGHTS_W  = MAX_NUM_LIGHTS <= 1 ? 1 : $clog2(MAX_NUM_LIGHTS + 1)
  , parameter int unsigned MAX_NUM_PRESSES_W = MAX_NUM_BUTTONS_W
  , parameter int unsigned AXI_DATA_WIDTH = 8
  )
  ( input var logic clk
  , input var logic rst_n

  , input  var logic start
  , output var logic ready
  , input  var logic accepted

  , day10_input_if.consumer  day10_input
  , day10_output_if.producer day10_output
  );

  // state declarations

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__START_COMPUTE_RREF
    , STATE__WAIT_COMPUTE_RREF
    , STATE__READ_SOLUTION_START
    , STATE__READ_SOLUTION_WAIT
    , STATE__PROCESS_SOLUTION
    , STATE__PROCESS_LAST_SOLUTION
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
    MAX_AUG_MAT_COLS <= 1 ? 1 : $clog2(MAX_AUG_MAT_COLS);

  logic [MAX_AUG_MAT_COLS -1:0]   augmented_matrix [MAX_AUG_MAT_ROWS -1:0];
  logic [MAX_AUG_MAT_COLS_W -1:0] rhs_col_idx;

  assign rhs_col_idx = MAX_AUG_MAT_COLS_W'(MAX_AUG_MAT_COLS -1 - day10_input.num_buttons);

  for (genvar r = 0; r < MAX_AUG_MAT_ROWS; r++) begin: l_build_aug_mat_rows
    for (genvar c = 0; c < MAX_AUG_MAT_COLS; c++) begin: l_build_aug_mat_cols
      if ((MAX_AUG_MAT_COLS - 1 - c) < MAX_NUM_BUTTONS) begin: l_aug_btn
        always_comb begin
          if (r < day10_input.num_lights)
            if (c == rhs_col_idx)
              augmented_matrix[r][c] = day10_input.target_lights_arrangement[r];
            else if ((MAX_AUG_MAT_COLS - 1 - c) < day10_input.num_buttons)
              augmented_matrix[r][c] = day10_input.buttons[MAX_AUG_MAT_COLS - 1 - c][r];
            else
              augmented_matrix[r][c] = 'x;
          else
            augmented_matrix[r][c] = 'x;
        end
      end else begin: l_aug_pad
        always_comb begin
          if (r < day10_input.num_lights && c == rhs_col_idx)
            augmented_matrix[r][c] = day10_input.target_lights_arrangement[r];
          else
            augmented_matrix[r][c] = 'x;
        end
      end
    end
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
      ( .clk   ( clk                         )
      , .rst_n ( rst_n                       )

      , .rows  ( day10_input.num_lights      )
      , .cols  ( day10_input.num_buttons + 1 )

      , .start ( rref_start                  )
      , .AUG   ( augmented_matrix            )

      , .ready ( rref_ready                  )
      , .RREF  ( rref                        )
      );

  // enumerate solutions

  logic enumerate_solutions_start;
  axi_stream_if #( AXI_DATA_WIDTH ) solution_stream();

  always_ff @ (posedge clk)
    if (!rst_n)                                       enumerate_solutions_start <= '0;
    else if (state_now == STATE__READ_SOLUTION_START) enumerate_solutions_start <= 1'b1;
    else                                              enumerate_solutions_start <= '0;

  enumerate_solutions
    #(.MAX_ROWS       ( MAX_AUG_MAT_ROWS )
    , .MAX_COLS       ( MAX_AUG_MAT_COLS )
    , .AXI_DATA_WIDTH ( AXI_DATA_WIDTH   )
    )
    u_enumerate_solutions
      ( .clk             ( clk                         )
      , .rst_n           ( rst_n                       )

      , .rows            ( day10_input.num_lights      )
      , .cols            ( day10_input.num_buttons + 1 )

      , .start           ( enumerate_solutions_start   )
      , .RREF            ( rref                        )

      , .solution_stream ( solution_stream.master      )
      );

  // read next solution

  logic solution_read_start;
  logic solution_read_complete;
  logic solution_read_last;

  logic [MAX_NUM_BUTTONS -1:0] current_solution;

  assign solution_read_start = state_now == STATE__READ_SOLUTION_START;

  axi_read_vector
    #(.MAX_VEC_LENGTH ( MAX_NUM_BUTTONS )
    , .AXI_DATA_WIDTH ( AXI_DATA_WIDTH  )
    , .READ_DIR       ( DIR__LEFT       )
    )
    u_axi_read_solution
      ( .clk        ( clk                     )
      , .rst_n      ( rst_n                   )

      , .start      ( solution_read_start     )
      , .vec_length ( day10_input.num_buttons )
      , .data_in    ( solution_stream.slave   )

      , .ready      ( solution_read_complete  )
      , .last       ( solution_read_last      )
      , .vec        ( current_solution        )
      );

  // track cheapest solution

  logic [MAX_NUM_PRESSES_W -1:0] current_solution_popcount;

  popcount
    #(.MAX_N ( MAX_NUM_BUTTONS   )
    , .MAX_W ( MAX_NUM_PRESSES_W )
    )
    u_solution_popcount
      ( .in    ( current_solution          )
      , .n     ( day10_input.num_buttons   )
      , .count ( current_solution_popcount )
      );

  always_ff @ (posedge clk)
    if (!rst_n)
      {day10_output.min_button_presses, day10_output.buttons_to_press} <=
        {{MAX_NUM_PRESSES_W{1'b1}}, {MAX_NUM_BUTTONS{1'b0}}};
    else if (state_now == STATE__INIT)
      {day10_output.min_button_presses, day10_output.buttons_to_press} <=
        {{MAX_NUM_PRESSES_W{1'b1}}, {MAX_NUM_BUTTONS{1'b0}}};
    else if ((state_now == STATE__PROCESS_SOLUTION || state_now == STATE__PROCESS_LAST_SOLUTION)
              && current_solution_popcount < day10_output.min_button_presses)
      {day10_output.min_button_presses, day10_output.buttons_to_press} <=
        {current_solution_popcount, current_solution};
    else
      {day10_output.min_button_presses, day10_output.buttons_to_press} <=
        {day10_output.min_button_presses, day10_output.buttons_to_press};

  // completion check

  always_ff @ (posedge clk)
    if (state_now == STATE__DONE) ready <= 1'b1;
    else                          ready <= '0;

  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (start)                  state_next = STATE__START_COMPUTE_RREF;
        else                        state_next = STATE__INIT;
      STATE__START_COMPUTE_RREF:
        if (rref_ready)             state_next = STATE__READ_SOLUTION_START;
        else                        state_next = STATE__WAIT_COMPUTE_RREF;
      STATE__WAIT_COMPUTE_RREF:
        if (rref_ready)             state_next = STATE__READ_SOLUTION_START;
        else                        state_next = STATE__WAIT_COMPUTE_RREF;
      STATE__READ_SOLUTION_START, STATE__READ_SOLUTION_WAIT:
        if (solution_read_complete)
          if (solution_read_last)   state_next = STATE__PROCESS_LAST_SOLUTION;
          else                      state_next = STATE__PROCESS_SOLUTION;
        else                        state_next = STATE__READ_SOLUTION_WAIT;
      STATE__PROCESS_SOLUTION:      state_next = STATE__READ_SOLUTION_START;
      STATE__PROCESS_LAST_SOLUTION: state_next = STATE__DONE;
      STATE__DONE:
        if (accepted)               state_next = STATE__INIT;
        else                        state_next = STATE__DONE;
      default:                      state_next = STATE__INIT;
    endcase

endmodule
