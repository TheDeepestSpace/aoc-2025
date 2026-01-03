module day10 #( parameter int unsigned MAX_NUM_LIGHTS, parameter int unsigned MAX_NUM_BUTTONS )
  ( input var logic clk
  , input var logic rst_n

  , axi_stream_if #( .DATA_WIDTH ( 8 ) )  data_in
  , axi_stream_if #( .DATA_WIDTH ( 8 ) ) data_out
  );

endmodule
