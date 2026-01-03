`default_nettype none

`include "axi_stream_if.svh"

module enumerate_solutions_tb;
  localparam int unsigned MAX_ROWS = 4;
  localparam int unsigned MAX_COLS = 7;
  localparam int unsigned MAX_ROWS_W = (MAX_ROWS <= 1) ? 1 : $clog2(MAX_ROWS + 1);
  localparam int unsigned MAX_COLS_W = (MAX_COLS <= 1) ? 1 : $clog2(MAX_COLS + 1);

  logic clk;
  logic rst_n;

  logic [MAX_ROWS_W -1:0] rows;
  logic [MAX_COLS_W -1:0] cols;

  logic start;
  logic [MAX_COLS -1:0] rref [MAX_ROWS -1:0];

  logic       sol_tvalid;
  logic       sol_tready;
  logic [7:0] sol_tdata;
  logic       sol_tlast;

  axi_stream_if #( .DATA_WIDTH( 8 ) ) solution_stream();

  assign sol_tvalid = solution_stream.tvalid;
  assign sol_tdata  = solution_stream.tdata;
  assign sol_tlast  = solution_stream.tlast;
  assign solution_stream.tready = sol_tready;

  enumerate_solutions
    #(.MAX_ROWS ( MAX_ROWS )
    , .MAX_COLS ( MAX_COLS )
    )
    u_enum
      ( .clk             ( clk             )
      , .rst_n           ( rst_n           )
      , .rows            ( rows            )
      , .cols            ( cols            )
      , .start           ( start           )
      , .RREF            ( rref            )
      , .solution_stream ( solution_stream )
      );
endmodule
