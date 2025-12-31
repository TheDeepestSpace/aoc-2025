`default_nettype none

module enumerate_solutions #( parameter int ROWS, parameter int COLS )
  ( input var logic clk
  , input var logic rst_n

  , input var logic start
  , input var logic [COLS -1:0] RREF [ROWS -1:0]

  // assume 8-bit tdata width
  , axi_stream_if.master solution_stream
  );

  // state declarations

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__FIND_BASE_SOLUTION
    , STATE__FIND_NEXT_SOLUTION
    , STATE__WAIT_FOR_RECEIPT
    , STATE__DONE
    } state_t;

  state_t state_now, state_next;

  always_ff @ (posedge clk)
    if (!rst_n) state_now <= STATE__INIT;
    else        state_now <= state_next;

  // determine free variables

  localparam int unsigned VARS_COUNT        = COLS -1;
  localparam int unsigned VARS_COUNT_W      = (VARS_COUNT <= 1) ? 1 : $clog2(VARS_COUNT + 1);
  localparam int unsigned VARS_INDEX_W      = (VARS_COUNT <= 1) ? 1 : $clog2(VARS_COUNT);

  logic [VARS_COUNT -1:0]   free_vars_mask;
  logic [VARS_COUNT_W -1:0] free_vars_count;

  localparam int unsigned ROWS_VARS = (ROWS < VARS_COUNT) ? ROWS : VARS_COUNT;

  for (genvar c = 0; c < ROWS_VARS; c++) begin: l_build_free_vars_mask
    always_comb free_vars_mask[VARS_COUNT -1 - c] = RREF[c][VARS_COUNT - c] == '0;
  end

  popcount #( .N ( VARS_COUNT ), .W ( VARS_COUNT_W ) ) u_free_vars_popcount
    ( .in    ( free_vars_mask  )
    , .count ( free_vars_count )
    );

  // determine base solution

  logic [VARS_COUNT -1:0]  x0;

  for (genvar i = 0; i < ROWS_VARS; i++) begin: l_build_base_solution
    always_comb
      if (free_vars_mask[VARS_COUNT -1 - i]) x0[VARS_COUNT -1 - i] = 0;
      else                                   x0[VARS_COUNT -1 - i] = RREF[i][0];
  end

  // determine free variable bases

  logic [VARS_COUNT -1:0]   bases            [VARS_COUNT -1:0];
  logic [VARS_INDEX_W -1:0] bases_iter_chain [VARS_COUNT:0];

  popcount_chain #( .N ( VARS_COUNT ), .W ( VARS_INDEX_W ) ) u_bases_iter_chain
    ( .in    ( free_vars_mask   )
    , .chain ( bases_iter_chain )
    );

  for (genvar c = VARS_COUNT - 1; c >= 0; c--) begin: l_build_bases_col
    for (genvar r = 0; r < VARS_COUNT; r++) begin: l_build_bases_row
      always_comb
        if (state_now == STATE__INIT) bases[c][r] = '0;
        else if (free_vars_mask[c] != '0)
          if (r == VARS_COUNT -1 - c) bases[bases_iter_chain[VARS_COUNT -1 - c]][r] = 1'b1;
          else                        bases[bases_iter_chain[VARS_COUNT -1 - c]][r] = RREF[r][c +1];
        else                          bases[bases_iter_chain[VARS_COUNT -1 - c]][r] =
                                        bases[bases_iter_chain[VARS_COUNT -1 - c]][r];
    end
  end

  // solution iterator

  logic [VARS_COUNT_W -1:0] free_vars_iterator_stop;
  logic [VARS_COUNT_W -1:0] free_vars_iterator;

  always_comb
    if (free_vars_count == 0) free_vars_iterator_stop = '0;
    else                      free_vars_iterator_stop = (1 << free_vars_count) - 1;

  always_ff @ (posedge clk)
    case (state_now)
      STATE__INIT:               free_vars_iterator <= '0;
      STATE__FIND_BASE_SOLUTION: free_vars_iterator <= free_vars_iterator + 1'b1;
      STATE__FIND_NEXT_SOLUTION: free_vars_iterator <= free_vars_iterator + 1'b1;
      default:                   free_vars_iterator <= free_vars_iterator;
    endcase

  // next solution

  logic [VARS_COUNT -1:0] xor_chain [VARS_COUNT_W:0];

  assign xor_chain[0] = x0;
  for (genvar i = 0; i < VARS_COUNT_W; i++) begin: l_build_xor_chain
    assign xor_chain[i + 1] = xor_chain[i] ^ ({VARS_COUNT{free_vars_iterator[i]}} & bases[i]);
  end

  logic [VARS_COUNT -1:0] x_next;
  always_ff @ (posedge clk)
    if (state_now == STATE__FIND_BASE_SOLUTION) x_next <= x0;
    else                                        x_next <= xor_chain[VARS_COUNT_W];

  // last solution check

  logic last_solution;
  always_comb last_solution = free_vars_iterator == free_vars_iterator_stop;

  // solution streaming

  logic [solution_stream.DATA_WIDTH - VARS_COUNT - 1:0] t_data_padding = '0;

  always_ff @ (posedge clk)
    {solution_stream.tvalid, solution_stream.tdata, solution_stream.tlast} <=
      (state_now == STATE__FIND_BASE_SOLUTION || state_now == STATE__FIND_NEXT_SOLUTION ?
        {1'b1, t_data_padding, x_next, last_solution ? 1'b1 : '0} : '0);

  // states logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (start)                  state_next = STATE__FIND_BASE_SOLUTION;
        else                        state_next = STATE__INIT;
      STATE__FIND_BASE_SOLUTION:
        if (solution_stream.tready)
          if (last_solution)        state_next = STATE__DONE;
          else                      state_next = STATE__FIND_NEXT_SOLUTION;
        else                        state_next = STATE__WAIT_FOR_RECEIPT;
      STATE__FIND_NEXT_SOLUTION:    state_next = STATE__FIND_NEXT_SOLUTION;
      STATE__WAIT_FOR_RECEIPT:
        if (solution_stream.tready)
          if (last_solution)        state_next = STATE__DONE;
          else                      state_next = STATE__FIND_NEXT_SOLUTION;
        else                        state_next = STATE__WAIT_FOR_RECEIPT;
      STATE__DONE:                  state_next = STATE__INIT;
      default:                      state_next = STATE__INIT;
    endcase


endmodule
