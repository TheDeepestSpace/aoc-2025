`default_nettype none

`include "axi_stream_if.svh"

module enumerate_solutions_tb;
  logic clk;
  logic rst_n;

  logic       start_2x3;
  logic [2:0] rref_2x3 [1:0];
  logic       sol2x3_tvalid;
  logic       sol2x3_tready;
  logic [7:0] sol2x3_tdata;
  logic       sol2x3_tlast;

  logic       start_3x4;
  logic [3:0] rref_3x4 [2:0];
  logic       sol3x4_tvalid;
  logic       sol3x4_tready;
  logic [7:0] sol3x4_tdata;
  logic       sol3x4_tlast;

  axi_stream_if #( .DATA_WIDTH( 8 ) ) solution_stream_2x3();
  axi_stream_if #( .DATA_WIDTH( 8 ) ) solution_stream_3x4();

  assign sol2x3_tvalid = solution_stream_2x3.tvalid;
  assign sol2x3_tdata  = solution_stream_2x3.tdata;
  assign sol2x3_tlast  = solution_stream_2x3.tlast;
  assign solution_stream_2x3.tready = sol2x3_tready;

  assign sol3x4_tvalid = solution_stream_3x4.tvalid;
  assign sol3x4_tdata  = solution_stream_3x4.tdata;
  assign sol3x4_tlast  = solution_stream_3x4.tlast;
  assign solution_stream_3x4.tready = sol3x4_tready;

  enumerate_solutions #( .ROWS( 2 ), .COLS( 3 ) ) u_enum_2x3
    ( .clk             ( clk                 )
    , .rst_n           ( rst_n               )
    , .start           ( start_2x3           )
    , .RREF            ( rref_2x3            )
    , .solution_stream ( solution_stream_2x3 )
    );

  enumerate_solutions #( .ROWS( 3 ), .COLS( 4 ) ) u_enum_3x4
    ( .clk             ( clk                 )
    , .rst_n           ( rst_n               )
    , .start           ( start_3x4           )
    , .RREF            ( rref_3x4            )
    , .solution_stream ( solution_stream_3x4 )
    );
endmodule
