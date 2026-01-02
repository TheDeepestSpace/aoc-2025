`default_nettype none

module gf2_rref_tb;
  localparam int unsigned MAX_ROWS = 4;
  localparam int unsigned MAX_COLS = 7;
  localparam int unsigned MAX_ROWS_W = (MAX_ROWS <= 1) ? 1 : $clog2(MAX_ROWS);
  localparam int unsigned MAX_COLS_W = (MAX_COLS <= 1) ? 1 : $clog2(MAX_COLS);

  logic clk;
  logic rst_n;

  logic [MAX_ROWS_W -1:0] rows;
  logic [MAX_COLS_W -1:0] cols;

  logic start;
  logic [MAX_COLS -1:0] aug  [MAX_ROWS -1:0];
  logic ready;
  logic [MAX_COLS -1:0] rref [MAX_ROWS -1:0];

  gf2_rref #(
    .MAX_ROWS ( MAX_ROWS ),
    .MAX_COLS ( MAX_COLS )
  ) u_rref
    ( .clk   ( clk   )
    , .rst_n ( rst_n )
    , .rows  ( rows  )
    , .cols  ( cols  )
    , .start ( start )
    , .AUG   ( aug   )
    , .ready ( ready )
    , .RREF  ( rref  )
    );
endmodule
