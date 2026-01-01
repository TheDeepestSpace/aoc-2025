`default_nettype none

module gf2_rref_tb;
  logic clk;
  logic rst_n;

  logic       start_2x3;
  logic [2:0] aug_2x3 [1:0];
  logic       ready_2x3;
  logic [2:0] rref_2x3 [1:0];

  logic       start_3x4;
  logic [3:0] aug_3x4 [2:0];
  logic       ready_3x4;
  logic [3:0] rref_3x4 [2:0];

  logic       start_4x7;
  logic [6:0] aug_4x7 [3:0];
  logic       ready_4x7;
  logic [6:0] rref_4x7 [3:0];

  gf2_rref #( .ROWS( 2 ), .COLS( 3 ) ) u_rref_2x3
    ( .clk   ( clk       )
    , .rst_n ( rst_n     )
    , .start ( start_2x3 )
    , .AUG   ( aug_2x3   )
    , .ready ( ready_2x3 )
    , .RREF  ( rref_2x3  )
    );

  gf2_rref #( .ROWS( 3 ), .COLS( 4 ) ) u_rref_3x4
    ( .clk   ( clk       )
    , .rst_n ( rst_n     )
    , .start ( start_3x4 )
    , .AUG   ( aug_3x4   )
    , .ready ( ready_3x4 )
    , .RREF  ( rref_3x4  )
    );

  gf2_rref #( .ROWS( 4 ), .COLS( 7 ) ) u_rref_4x7
    ( .clk   ( clk       )
    , .rst_n ( rst_n     )
    , .start ( start_4x7 )
    , .AUG   ( aug_4x7   )
    , .ready ( ready_4x7 )
    , .RREF  ( rref_4x7  )
    );
endmodule
