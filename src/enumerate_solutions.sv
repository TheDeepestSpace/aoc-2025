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

  // determine pivots

  localparam int unsigned VARS_COUNT   = COLS -1;
  localparam int unsigned VARS_COUNT_W = (VARS_COUNT <= 1) ? 1 : $clog2(VARS_COUNT + 1);
  localparam int unsigned VARS_INDEX_W = (VARS_COUNT <= 1) ? 1 : $clog2(VARS_COUNT);

  // can optimize this by computing in gf2_rref and pass here
  logic [ROWS -1:0]       row_pivots [VARS_COUNT -1:0];
  logic [VARS_COUNT -1:0] pivot_mask;

  localparam int unsigned ROWS_VARS = (ROWS < VARS_COUNT) ? ROWS : VARS_COUNT;

  for (genvar r = 0; r < ROWS; r++) begin: l_pivot_scan_row
    for (genvar c = VARS_COUNT -1; c >= 0; c--) begin: l_pivot_scan_col
      if (c == VARS_COUNT -1) begin: l_leading_column_special_case
        always_comb row_pivots[c][r] = RREF[r][c +1];
      end else begin: l_following_columns
        always_comb row_pivots[c][r] = RREF[r][c +1] & ~(|RREF[r][VARS_COUNT:c +2]);
      end
    end
  end

  for (genvar c = VARS_COUNT -1; c >= 0; c--) begin: l_build_pivot_mask
    assign pivot_mask[c] = |row_pivots[c];
  end

  // map columns to pivot rows

  logic                     pivot_valid [ROWS -1:0];
  logic [VARS_INDEX_W -1:0] pivot_col   [ROWS -1:0];

  for (genvar r = 0; r < ROWS; r++) begin: l_build_pivot_valid
    assign pivot_valid[r] = |RREF[r][COLS -1:1];
  end

  for (genvar r = 0; r < ROWS; r++) begin: l_build_pivot_col
    logic [VARS_INDEX_W -1:0] pivot_col_chain [VARS_COUNT:0];
    assign pivot_col_chain[0] = '0;
    for (genvar v = 0; v < VARS_COUNT; v++) begin: l_build_pivot_col_chain
      assign
        pivot_col_chain[v +1] =
          row_pivots[VARS_COUNT -1 - v][r] ? VARS_INDEX_W'(v) : pivot_col_chain[v];
    end
    assign pivot_col[r] = pivot_col_chain[VARS_COUNT];
  end

  // determine free variables

  logic [VARS_COUNT -1:0]   free_vars_mask;
  logic [VARS_COUNT_W -1:0] free_vars_count;

  assign free_vars_mask = ~pivot_mask;

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
      if (r < ROWS_VARS) begin: l_build_bases_from_concrete_rows
        always_comb
          if (state_now == STATE__INIT) bases[c][VARS_COUNT -1 - r] = '0;
          else if (free_vars_mask[c] != '0)
            if (r == VARS_COUNT -1 - c)
              bases[bases_iter_chain[VARS_COUNT -1 - c]][VARS_COUNT -1 - r] = 1'b1;
            else if (pivot_valid[r])
              bases
                [bases_iter_chain[VARS_COUNT -1 - c]]
                  [VARS_INDEX_W'(VARS_COUNT -1 -pivot_col[r])] =
                    RREF[r][c +1];
            else
              bases[bases_iter_chain[VARS_COUNT -1 - c]][VARS_COUNT -1 - r] = 1'b0;
          else
            bases[bases_iter_chain[VARS_COUNT -1 - c]][VARS_COUNT -1 - r] =
              bases[bases_iter_chain[VARS_COUNT -1 - c]][VARS_COUNT -1 - r];
      end else begin: l_build_bases_from_implied_rows
        always_comb
          if (state_now == STATE__INIT) bases[c][VARS_COUNT -1 - r] = '0;
          else if (free_vars_mask[c] != '0)
            if (r == VARS_COUNT -1 - c)
              bases[bases_iter_chain[VARS_COUNT -1 - c]][VARS_COUNT -1 - r] = 1'b1;
            else
              bases[bases_iter_chain[VARS_COUNT -1 - c]][VARS_COUNT -1 - r] = 1'b0;
          else
            bases[bases_iter_chain[VARS_COUNT -1 - c]][VARS_COUNT -1 - r] =
              bases[bases_iter_chain[VARS_COUNT -1 - c]][VARS_COUNT -1 - r];
      end
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
  always_comb
    case (state_now)
      STATE__FIND_BASE_SOLUTION: x_next = x0;
      STATE__FIND_NEXT_SOLUTION: x_next = xor_chain[VARS_COUNT_W];
      default:                   x_next = x_next;
    endcase

  // last solution check

  logic last_solution;
  always_comb last_solution = free_vars_iterator == free_vars_iterator_stop;

  // solution streaming

  logic [solution_stream.DATA_WIDTH - VARS_COUNT - 1:0] t_data_padding = '0;

  always_comb
    case (state_now)
      STATE__FIND_BASE_SOLUTION, STATE__FIND_NEXT_SOLUTION:
        {solution_stream.tvalid, solution_stream.tdata, solution_stream.tlast} =
          {1'b1, t_data_padding, x_next, (last_solution ? 1'b1 : 1'b0)};
      default:
        {solution_stream.tvalid, solution_stream.tdata, solution_stream.tlast} =
          {1'b0, {solution_stream.DATA_WIDTH{1'b0}}, 1'b0};
    endcase

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
      STATE__FIND_NEXT_SOLUTION:
        if (solution_stream.tready)
          if (last_solution)        state_next = STATE__DONE;
          else                      state_next = STATE__FIND_NEXT_SOLUTION;
        else                        state_next = STATE__WAIT_FOR_RECEIPT;
      STATE__WAIT_FOR_RECEIPT:
        if (solution_stream.tready)
          if (last_solution)        state_next = STATE__DONE;
          else                      state_next = STATE__FIND_NEXT_SOLUTION;
        else                        state_next = STATE__WAIT_FOR_RECEIPT;
      STATE__DONE:                  state_next = STATE__INIT;
      default:                      state_next = STATE__INIT;
    endcase


endmodule
