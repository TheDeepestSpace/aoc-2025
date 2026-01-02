`ifndef AXI_STREAM_IF__HG
`define AXI_STREAM_IF__HG

interface axi_stream_if #( parameter int DATA_WIDTH = 8 );

  logic                   tvalid;
  logic                   tready;
  logic [DATA_WIDTH -1:0] tdata;
  logic                   tlast;

  // Producer drives valid + data
  modport master
    ( output tvalid
    , output tdata
    , output tlast
    , input  tready
    );

  // Consumer drives ready
  modport slave
    ( input  tvalid
    , input  tdata
    , input  tlast
    , output tready
    );

endinterface

`endif
