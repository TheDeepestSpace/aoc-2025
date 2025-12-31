`default_nettype none

module popcount_chain
  #(parameter int N
  , parameter int W = (N <= 1) ? 1 : $clog2(N + 1)
  )
  ( input  var logic [N -1:0] in
  , output var logic [W -1:0] chain [N:0]
  );

  assign chain[0] = '0;
  for (genvar i = 0; i < N; i++) begin: l_chain
    assign chain[i + 1] = chain[i] + {{(W -1){1'b0}}, in[N - 1 - i]};
  end
endmodule
