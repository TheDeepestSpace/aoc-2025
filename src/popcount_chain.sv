`default_nettype none

module popcount_chain
  #(parameter int unsigned MAX_N
  , parameter int unsigned MAX_W
  , parameter int unsigned MAX_N_W = (MAX_N <= 1) ? 1 : $clog2(MAX_N + 1)
  )
  ( input  var logic [MAX_N -1:0]   in
  , input  var logic [MAX_N_W -1:0] n
  , output var logic [MAX_W -1:0]   chain [MAX_N:0]
  );

  assign chain[0] = '0;
  for (genvar i = 0; i < MAX_N; i++) begin: l_chain
    assign
      chain[i + 1] =
        (i < n)
          ? (chain[i] + {{(MAX_W -1){1'b0}}, in[MAX_N - 1 - i]})
          : 'x;
  end
endmodule
