`default_nettype none

`include "axi_stream_if.svh"

module enumerate_solutions
  #(parameter int unsigned MAX_ROWS
  , parameter int unsigned MAX_COLS
  , parameter int unsigned MAX_ROWS_W = (MAX_ROWS <= 1) ? 1 : $clog2(MAX_ROWS + 1)
  , parameter int unsigned MAX_COLS_W = (MAX_COLS <= 1) ? 1 : $clog2(MAX_COLS + 1)
  , parameter int unsigned AXI_DATA_WIDTH = 8
  )
  ( input var logic clk
  , input var logic rst_n

  , input var logic [MAX_ROWS_W -1:0] rows
  , input var logic [MAX_ROWS_W -1:0] cols

  , input var logic start
  , input var logic [MAX_COLS -1:0] RREF [MAX_ROWS -1:0]

  , axi_stream_if.master solution_stream
  );

  // state declarations

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__FIND_BASE_SOLUTION
    , STATE__FIND_NEXT_SOLUTION
    , STATE__WRITE_SOLUTION
    , STATE__DONE
    } state_t;

  state_t state_now, state_next;

  always_ff @ (posedge clk)
    if (!rst_n) state_now <= STATE__INIT;
    else        state_now <= state_next;

  // determine pivots

  localparam int unsigned MAX_VARS_COUNT   = MAX_COLS -1;
  localparam int unsigned MAX_VARS_COUNT_W = (MAX_VARS_COUNT <= 1) ? 1 : $clog2(MAX_VARS_COUNT + 1);
  localparam int unsigned MAX_VARS_INDEX_W = (MAX_VARS_COUNT <= 1) ? 1 : $clog2(MAX_VARS_COUNT);

  // can optimize this by computing in gf2_rref and pass here
  logic [MAX_ROWS -1:0]       row_pivots [MAX_VARS_COUNT -1:0];
  logic [MAX_VARS_COUNT -1:0] pivot_mask;

  localparam int unsigned MAX_ROWS_IDX_W = (MAX_ROWS <= 1) ? 1 : $clog2(MAX_ROWS);
  localparam int unsigned MAX_COLS_IDX_W = (MAX_COLS <= 1) ? 1 : $clog2(MAX_COLS);

  logic [MAX_COLS_IDX_W -1:0] col_rhs_idx;

  always_comb col_rhs_idx = MAX_COLS_IDX_W'(MAX_COLS - cols);

  localparam int unsigned MAX_ROWS_VARS = (MAX_ROWS < MAX_VARS_COUNT) ? MAX_ROWS : MAX_VARS_COUNT;

  for (genvar r = 0; r < MAX_ROWS; r++) begin: l_pivot_scan_row
    for (genvar c = MAX_VARS_COUNT -1; c >= 0; c--) begin: l_pivot_scan_col
      if (c == MAX_VARS_COUNT -1) begin: l_leading_column_special_case
        always_comb row_pivots[c][r] = RREF[r][c +1];
      end else begin: l_following_columns
        always_comb
          if (c + 1 > col_rhs_idx && r < rows)
            row_pivots[c][r] = RREF[r][c +1] & ~(|RREF[r][MAX_COLS -1:c +2]);
          else
            row_pivots[c][r] = 'x;
      end
    end
  end

  for (genvar c = MAX_VARS_COUNT -1; c >= 0; c--) begin: l_build_pivot_mask
    always_comb
      if (c + 1 > col_rhs_idx)
        pivot_mask[c] = |row_pivots[c];
      else
        pivot_mask[c] = 'x;
  end

  // map columns to pivot rows

  logic                         pivot_valid [MAX_ROWS -1:0];
  logic [MAX_VARS_INDEX_W -1:0] pivot_col   [MAX_ROWS -1:0];

  logic [MAX_COLS -1:0] col_mask;
  logic [MAX_COLS -1:0] col_mask_without_rhs;

  logic [MAX_VARS_COUNT_W -1:0] vars;

  assign col_mask             = {MAX_COLS{1'b1}} << col_rhs_idx;
  assign col_mask_without_rhs = {MAX_COLS{1'b1}} << (col_rhs_idx + 1);

  assign vars = cols - 1;

  for (genvar r = 0; r < MAX_ROWS; r++) begin: l_build_pivot_valid
    always_comb
      if (r < rows)
        pivot_valid[r] = |(RREF[r][MAX_COLS -1:0] & col_mask_without_rhs);
      else
        pivot_valid[r] = 'x;
  end

  for (genvar r = 0; r < MAX_ROWS; r++) begin: l_build_pivot_col
    logic [MAX_VARS_INDEX_W -1:0] pivot_col_chain [MAX_VARS_COUNT:0];
    assign pivot_col_chain[0] = '0;
    for (genvar v = 0; v < MAX_VARS_COUNT; v++) begin: l_build_pivot_col_chain
      assign
        pivot_col_chain[v +1] =
          (v < vars && r < rows)
            ? (row_pivots[MAX_VARS_COUNT -1 - v][r] ? MAX_VARS_INDEX_W'(v) : pivot_col_chain[v])
            : pivot_col_chain[v];
    end
    always_comb
      if (r < rows)
        pivot_col[r] = pivot_col_chain[vars];
      else
        pivot_col[r] = 'x;
  end

  // determine free variables

  logic [MAX_VARS_COUNT -1:0]   free_vars_mask;
  logic [MAX_VARS_COUNT_W -1:0] free_vars_count;

  assign free_vars_mask = ~pivot_mask;

  popcount #( .MAX_N ( MAX_VARS_COUNT ), .MAX_W ( MAX_VARS_COUNT_W ) ) u_free_vars_popcount
    ( .in    ( free_vars_mask   )
    , .n     ( vars             )
    , .count ( free_vars_count  )
    );

  // determine base solution

  logic [MAX_VARS_COUNT -1:0]  x0;
  logic [MAX_ROWS -1:0]        x0_rows [MAX_VARS_COUNT -1:0];

  for (genvar c = MAX_VARS_COUNT -1; c >= 0; c--) begin: l_build_vase_solution_cols
    logic [MAX_VARS_INDEX_W-1:0] v;

    assign v = MAX_VARS_INDEX_W'(MAX_VARS_COUNT -1 - c);

    for (genvar r = 0; r < MAX_ROWS_VARS; r++) begin: l_build_base_solution_rows
      always_comb
        if (c + 1 > col_rhs_idx && r < rows)
          if (pivot_valid[r] && pivot_col[r] == v)
            x0_rows[c][r] = RREF[r][col_rhs_idx];
          else
            x0_rows[c][r] = 1'b0;
        else
          x0_rows[c][r] = 'x;
    end
    always_comb
      if (c + 1 > col_rhs_idx)
        x0[c] = |x0_rows[c];
      else
        x0[c] = 'x;
  end

  // determine free variable bases

  logic [MAX_VARS_COUNT -1:0]   bases            [MAX_VARS_COUNT -1:0];
  logic [MAX_VARS_INDEX_W -1:0] bases_iter_chain [MAX_VARS_COUNT:0];

  popcount_chain #( .MAX_N ( MAX_VARS_COUNT ), .MAX_W ( MAX_VARS_INDEX_W ) ) u_bases_iter_chain
    ( .in    ( free_vars_mask   )
    , .n     ( vars             )
    , .chain ( bases_iter_chain )
    );

  // had to give up on "no fors in always_comb" on this one as it would just be too hard to avoid
  // the multi-driver issues with generated-for loops; i think i could eventually pull of building
  // up the vecotrs more explicitly
  always_ff @ (posedge clk)
    if (!rst_n) begin
      for (int bi = 0; bi < MAX_VARS_COUNT; bi++)
        bases[bi] <= '0;
    end else if (state_now == STATE__INIT) begin
      for (int bi = 0; bi < MAX_VARS_COUNT; bi++)
        bases[bi] <= '0;
    end else begin
      for (int c = 0; c < MAX_VARS_COUNT; c++) begin
        if (c + 1 > col_rhs_idx && free_vars_mask[c]) begin
          for (int r = 0; r < MAX_VARS_COUNT; r++) begin
            if (r == MAX_VARS_COUNT - 1 - c) begin
              bases[bases_iter_chain[MAX_VARS_COUNT - 1 - c]][MAX_VARS_COUNT - 1 - r] <= 1'b1;
            end else if (r < rows && pivot_valid[r]) begin
              /* verilator lint_off SELRANGE */
              bases[bases_iter_chain[MAX_VARS_COUNT - 1 - c]]
                   [MAX_VARS_INDEX_W'(MAX_VARS_COUNT - 1) - pivot_col[r]] <= RREF[r][c + 1];
              /* verilator lint_on SELRANGE */
            end else if (r < rows) begin
              bases[bases_iter_chain[MAX_VARS_COUNT - 1 - c]][MAX_VARS_COUNT - 1 - r] <= 1'b0;
            end
          end
        end
      end
    end

  // solution iterator

  logic [MAX_VARS_COUNT_W -1:0] free_vars_iterator_stop;
  logic [MAX_VARS_COUNT_W -1:0] free_vars_iterator;

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

  logic [MAX_VARS_COUNT -1:0] xor_chain [MAX_VARS_COUNT_W:0];

  assign xor_chain[0] = x0;
  for (genvar i = 0; i < MAX_VARS_COUNT_W; i++) begin: l_build_xor_chain
    assign
      xor_chain[i + 1] =
        (i < vars)
          ? (xor_chain[i] ^ ({MAX_VARS_COUNT{free_vars_iterator[i]}} & bases[i]))
          : xor_chain[i];
  end

  logic [MAX_VARS_COUNT -1:0] x_next;
  always_comb
    case (state_now)
      STATE__FIND_BASE_SOLUTION: x_next = x0;
      STATE__FIND_NEXT_SOLUTION: x_next = xor_chain[MAX_VARS_COUNT_W];
      default:                   x_next = x_next;
    endcase

  // last solution check

  logic last_solution;
  always_ff @ (posedge clk)
    if (!rst_n) last_solution <= '0;
    else
      case (state_now)
        STATE__INIT:
          last_solution <= '0;
        STATE__FIND_NEXT_SOLUTION, STATE__FIND_BASE_SOLUTION:
          last_solution <= free_vars_iterator == free_vars_iterator_stop;
        default:
          last_solution <= last_solution;
      endcase

  // solution streaming

  logic solution_write_start;
  logic solution_write_complete;

  assign solution_write_start =
    state_now == STATE__FIND_BASE_SOLUTION || state_now == STATE__FIND_NEXT_SOLUTION;

  axi_write_vector #( .MAX_VEC_LENGTH ( MAX_VARS_COUNT ), .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ) )
    u_axi_write_solution
      ( .clk        ( clk                     )
      , .rst_n      ( rst_n                   )

      , .start      ( solution_write_start    )
      , .vec_length ( vars                    )
      , .vec        ( x_next                  )
      , .last_write ( last_solution           )

      , .ready      ( solution_write_complete )
      , .data_out   ( solution_stream         )
      );

  // states logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (start)                  state_next = STATE__FIND_BASE_SOLUTION;
        else                        state_next = STATE__INIT;
      STATE__FIND_BASE_SOLUTION, STATE__FIND_NEXT_SOLUTION, STATE__WRITE_SOLUTION:
        if (solution_write_complete)
          if (last_solution)        state_next = STATE__DONE;
          else                      state_next = STATE__FIND_NEXT_SOLUTION;
        else                        state_next = STATE__WRITE_SOLUTION;
      STATE__DONE:                  state_next = STATE__INIT;
      default:                      state_next = STATE__INIT;
    endcase

endmodule
