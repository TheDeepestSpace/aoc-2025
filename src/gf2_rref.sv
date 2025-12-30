`default_nettype none

module gf2_rref
  #(parameter int unsigned ROWS
  , parameter int unsigned COLS
  )
  ( input  var logic clk
  , input  var logic rst_n

  , input  var logic start
  , input  var logic [COLS -1:0] AUG  [ROWS -1:0]

  , output var logic ready
  , output var logic [COLS -1:0] RREF [ROWS -1:0]
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

  logic [COLS -1:0] aug [ROWS -1:0];

  for (genvar i = 0; i < ROWS; i++) begin: l_build_aug
    always_ff @ (posedge clk)
      if (!rst_n)                        aug[i] <= '0;
      else if (state_now == STATE__INIT) aug[i] <= AUG[i];
      else if (state_now == STATE__SWAP)
        if (i == col_iter_as_row_iter)   aug[i] <= aug[pivot_row_idx];
        else if (i == pivot_row_idx)     aug[i] <= aug[col_iter_as_row_iter];
        else                             aug[i] <= aug[i];
      else if (state_now == STATE__ZERO_OUT_COL)
        if (i == col_iter_as_row_iter)   aug[i] <= aug[i];
        else if (aug[i][col_iter] == 0)  aug[i] <= aug[i];
        else                             aug[i] <= aug[i] ^ aug[col_iter_as_row_iter];
      else                               aug[i] <= aug[i];

    always_ff @ (posedge clk)
      if (rst_n && state_now == STATE__DONE) RREF[i] <= aug[i];
      else                                   RREF[i] <= RREF[i];
  end

  // column iterator

  localparam int unsigned COLS_W = (COLS <= 1) ? 1 : $clog2(COLS);
  logic [COLS_W -1:0] col_iter;

  always_ff @ (posedge clk)
    if (!rst_n)                 col_iter <= COLS_W'(COLS -1);
    else
      case (state_now)
        STATE__INIT:            col_iter <= COLS_W'(COLS -1);
        STATE__UPDATE_COL_ITER: col_iter <= col_iter - 1'b1;
        default:                col_iter <= col_iter;
      endcase

  // pivot checks

  localparam int unsigned ROWS_W = (ROWS <= 1) ? 1 : $clog2(ROWS);
  logic [ROWS_W -1:0] row_iter;
  logic [ROWS_W -1:0] pivot_row_idx;
  logic [ROWS_W -1:0] col_iter_as_row_iter;

  logic pivot_found;
  assign pivot_found = aug[row_iter][col_iter];
  assign col_iter_as_row_iter = ROWS_W'(COLS -1 - col_iter);

  always_ff @ (posedge clk)
    if (!rst_n) row_iter <= '0;
    else
      case (state_now)
        STATE__INIT:                             row_iter <= '0;
        STATE__UPDATE_COL_ITER:                  row_iter <= col_iter_as_row_iter + 1'b1;
        STATE__FIND_PIVOT:
          if (pivot_found)                       row_iter <= row_iter;
          else if (row_iter == ROWS_W'(ROWS -1)) row_iter <= row_iter;
          else                                   row_iter <= row_iter + 1'b1;
        default:                                 row_iter <= row_iter;
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
        if (start)                              state_next = STATE__FIND_PIVOT;
        else                                    state_next = STATE__INIT;
      STATE__FIND_PIVOT:
        if (pivot_found)
          if (row_iter != col_iter_as_row_iter) state_next = STATE__SWAP;
          else                                  state_next = STATE__ZERO_OUT_COL;
        else if (row_iter == ROWS_W'(ROWS -1))  state_next = STATE__UPDATE_COL_ITER;
        else                                    state_next = STATE__FIND_PIVOT;
      STATE__UPDATE_COL_ITER:
        if (col_iter == 1)                      state_next = STATE__DONE;
        else                                    state_next = STATE__FIND_PIVOT;
      STATE__SWAP:                              state_next = STATE__ZERO_OUT_COL;
      STATE__ZERO_OUT_COL:                      state_next = STATE__UPDATE_COL_ITER;
      STATE__DONE:                              state_next = STATE__INIT;
      default:                                  state_next = STATE__INIT;
    endcase

endmodule
