`default_nettype none

module popcount #(parameter int N, parameter int W = (N <= 1) ? 1 : $clog2(N +1) )
  ( input  var logic [N -1:0] in
  , output var logic [W -1:0] count
  );

  logic [W -1:0] chain [N:0];
  popcount_chain #( .N ( N ), .W ( W ) ) u_popcount_chain
    ( .in    ( in    )
    , .chain ( chain )
    );
  assign count = chain[N];

endmodule
