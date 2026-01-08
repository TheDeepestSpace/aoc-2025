`default_nettype none

`include "axi_stream_if.svh"

module day10_tb;
  localparam int unsigned MAX_NUM_LIGHTS = 7;
  localparam int unsigned MAX_NUM_BUTTONS = 7;
  localparam int unsigned AXI_DATA_WIDTH = 8;

  logic clk;
  logic rst_n;

  logic                        data_in_tvalid;
  logic                        data_in_tready;
  logic [AXI_DATA_WIDTH -1:0]  data_in_tdata;
  logic                        data_in_tlast;

  logic                        data_out_tvalid;
  logic                        data_out_tready;
  logic [AXI_DATA_WIDTH -1:0]  data_out_tdata;
  logic                        data_out_tlast;

  axi_stream_if #( .DATA_WIDTH ( AXI_DATA_WIDTH ) ) data_in();
  axi_stream_if #( .DATA_WIDTH ( AXI_DATA_WIDTH ) ) data_out();

  assign data_in.tvalid = data_in_tvalid;
  assign data_in.tdata  = data_in_tdata;
  assign data_in.tlast  = data_in_tlast;
  assign data_in_tready = data_in.tready;

  assign data_out_tvalid = data_out.tvalid;
  assign data_out_tdata  = data_out.tdata;
  assign data_out_tlast  = data_out.tlast;
  assign data_out.tready = data_out_tready;

  day10
    #(.MAX_NUM_LIGHTS  ( MAX_NUM_LIGHTS  )
    , .MAX_NUM_BUTTONS ( MAX_NUM_BUTTONS )
    , .AXI_DATA_WIDTH  ( AXI_DATA_WIDTH  )
    )
    u_day10
      ( .clk      ( clk      )
      , .rst_n    ( rst_n    )
      , .data_in  ( data_in  )
      , .data_out ( data_out )
      );
endmodule
