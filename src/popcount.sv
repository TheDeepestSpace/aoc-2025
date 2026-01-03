`default_nettype none

module popcount
  #(parameter int unsigned MAX_N
  , parameter int unsigned MAX_W   = (MAX_N <= 1) ? 1 : $clog2(MAX_N + 1)
  , parameter int unsigned MAX_N_W = (MAX_N <= 1) ? 1 : $clog2(MAX_N + 1)
  )
  ( input  var logic [MAX_N -1:0]   in
  , input  var logic [MAX_N_W -1:0] n
  , output var logic [MAX_W -1:0]   count
  );

  logic [MAX_W -1:0] chain [MAX_N:0];
  popcount_chain #( .MAX_N ( MAX_N ), .MAX_W ( MAX_W ) ) u_popcount_chain
    ( .in    ( in    )
    , .n     ( n     )
    , .chain ( chain )
    );

  always_comb count = chain[n];

endmodule
