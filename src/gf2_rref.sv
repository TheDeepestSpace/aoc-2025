`default_nettype none

module gf2_rref
  #(parameter int unsigned MAX_ROWS
  , parameter int unsigned MAX_COLS
  , parameter int unsigned MAX_ROWS_W     = (MAX_ROWS <= 1) ? 1 : $clog2(MAX_ROWS + 1)
  , parameter int unsigned MAX_COLS_W     = (MAX_COLS <= 1) ? 1 : $clog2(MAX_COLS + 1)
  , parameter int unsigned MAX_ROWS_IDX_W = (MAX_ROWS <= 1) ? 1 : $clog2(MAX_ROWS)
  , parameter int unsigned MAX_COLS_IDX_W = (MAX_COLS <= 1) ? 1 : $clog2(MAX_COLS)
  )
  ( input  var logic clk
  , input  var logic rst_n

  , input  var logic [MAX_ROWS_W -1:0] rows
  , input  var logic [MAX_COLS_W -1:0] cols

  , input  var logic start
  , input  var logic [MAX_COLS -1:0] AUG  [MAX_ROWS -1:0]

  , output var logic ready
  , output var logic [MAX_COLS -1:0] RREF [MAX_ROWS -1:0]
  );

  // state declarations

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__FIND_PIVOT
    , STATE__SWAP
    , STATE__ZERO_OUT_COL
    , STATE__UPDATE_COL_ITER
    , STATE__DONE
    } state_t;

  state_t state_now, state_next;

  always_ff @ (posedge clk)
    if (!rst_n) state_now <= STATE__INIT;
    else        state_now <= state_next;

  // augmented matrix manipulations [A|B]

  logic [MAX_COLS -1:0] aug [MAX_ROWS -1:0];

  for (genvar r = 0; r < MAX_ROWS; r++) begin: l_build_aug
    always_ff @ (posedge clk)
      if (!rst_n)                        aug[r] <= '0;
      else if (r < rows)
        if (state_now == STATE__INIT) aug[r] <= AUG[r];
        else if (state_now == STATE__SWAP)
          if (r == col_iter_as_row_iter)   aug[r] <= aug[pivot_row_idx];
          else if (r == pivot_row_idx)     aug[r] <= aug[col_iter_as_row_iter];
          else                             aug[r] <= aug[r];
        else if (state_now == STATE__ZERO_OUT_COL)
          if (r == row_iter)
            aug[r] <= aug[r];
          else if (aug[r][col_iter] == 0)
            aug[r] <= aug[r];
          else
            aug[r] <= aug[r] ^ aug[row_iter];
        else
          aug[r] <= aug[r];
      else
        aug[r] <= aug[r];

    always_ff @ (posedge clk)
      if (rst_n && state_now == STATE__DONE) RREF[r] <= aug[r];
      else                                   RREF[r] <= RREF[r];
  end

  // column iterator

  logic [MAX_COLS_IDX_W -1:0] col_iter;
  logic [MAX_COLS_IDX_W -1:0] col_rhs_idx;

  always_ff @ (posedge clk)
    if (!rst_n)                 col_iter <= MAX_COLS_IDX_W'(MAX_COLS -1);
    else
      case (state_now)
        STATE__INIT:            col_iter <= MAX_COLS_IDX_W'(MAX_COLS -1);
        STATE__UPDATE_COL_ITER: col_iter <= col_iter - 1'b1;
        default:                col_iter <= col_iter;
      endcase

  always_comb col_rhs_idx = MAX_COLS_IDX_W'(MAX_COLS - cols);

  // pivot checks

  logic [MAX_ROWS_IDX_W -1:0] row_iter;
  logic [MAX_ROWS_IDX_W -1:0] row_iter_start;
  logic [MAX_ROWS_IDX_W -1:0] row_iter_end;
  logic                       row_iter_start_valid;
  logic [MAX_ROWS_IDX_W -1:0] pivot_row_idx;
  logic [MAX_ROWS_IDX_W -1:0] col_iter_as_row_iter;
  logic                       col_iter_as_row_iter_valid;

  logic pivot_found;
  assign pivot_found = aug[row_iter][col_iter];
  assign col_iter_as_row_iter = MAX_ROWS_IDX_W'(MAX_COLS -1 - col_iter);
  assign col_iter_as_row_iter_valid = MAX_COLS -1 - 32'(col_iter) < rows;

  always_comb row_iter_end = MAX_ROWS_IDX_W'(rows - 1);

  always_ff @ (posedge clk)
    if (!rst_n) {row_iter_start, row_iter_start_valid} <= {{MAX_ROWS_IDX_W{1'b0}}, 1'b1};
    else
      case (state_now)
        STATE__INIT: {row_iter_start, row_iter_start_valid} <= {{MAX_ROWS_IDX_W{1'b0}}, 1'b1};
        STATE__FIND_PIVOT:
          if (pivot_found)
            if (row_iter_start_valid)
              {row_iter_start, row_iter_start_valid} <=
                {row_iter_start + 1'b1, MAX_ROWS_W'(row_iter_start) + 1'b1 != rows};
            else {row_iter_start, row_iter_start_valid} <= {row_iter_start, row_iter_start_valid};
          else {row_iter_start, row_iter_start_valid} <= {row_iter_start, row_iter_start_valid};
        default: {row_iter_start, row_iter_start_valid} <= {row_iter_start, row_iter_start_valid};
      endcase

  always_ff @ (posedge clk)
    if (!rst_n) row_iter <= '0;
    else
      case (state_now)
        STATE__INIT:                         row_iter <= '0;
        STATE__UPDATE_COL_ITER:              row_iter <= row_iter_start;
        STATE__FIND_PIVOT:
          if (pivot_found)                   row_iter <= row_iter;
          else if (row_iter == row_iter_end) row_iter <= row_iter;
          else                               row_iter <= row_iter + 1'b1;
        STATE__SWAP:                         row_iter <= col_iter_as_row_iter;
        default:                             row_iter <= row_iter;
      endcase

  always_ff @ (posedge clk)
    if (!rst_n)                                             pivot_row_idx <= '0;
    else if (state_now == STATE__FIND_PIVOT && pivot_found) pivot_row_idx <= row_iter;
    else                                                    pivot_row_idx <= pivot_row_idx;

  // completeness indicator

  always_ff @ (posedge clk)
    if (!rst_n)                        ready <= '0;
    else if (state_now == STATE__DONE) ready <= 1'b1;
    else                               ready <= '0;

  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (start)                             state_next = STATE__FIND_PIVOT;
        else                                   state_next = STATE__INIT;
      STATE__FIND_PIVOT:
        if (!row_iter_start_valid)             state_next = STATE__UPDATE_COL_ITER;
        else if (pivot_found)
          if (!col_iter_as_row_iter_valid)     state_next = STATE__ZERO_OUT_COL;
          else if (row_iter == row_iter_start) state_next = STATE__ZERO_OUT_COL;
          else                                 state_next = STATE__SWAP;
        else if (row_iter == row_iter_end)     state_next = STATE__UPDATE_COL_ITER;
        else                                   state_next = STATE__FIND_PIVOT;
      STATE__UPDATE_COL_ITER:
        if (col_iter == col_rhs_idx)           state_next = STATE__DONE;
        else                                   state_next = STATE__FIND_PIVOT;
      STATE__SWAP:                             state_next = STATE__ZERO_OUT_COL;
      STATE__ZERO_OUT_COL:                     state_next = STATE__UPDATE_COL_ITER;
      STATE__DONE:                             state_next = STATE__INIT;
      default:                                 state_next = STATE__INIT;
    endcase

endmodule
