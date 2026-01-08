module axi_read_vector
  #(parameter int unsigned MAX_VEC_LENGTH
  , parameter int unsigned AXI_DATA_WIDTH
  , parameter int unsigned MAX_VEC_LENGTH_W =
    MAX_VEC_LENGTH <= 1 ? 1 : $clog2(MAX_VEC_LENGTH + 1)
  )
  ( input var logic clk
  , input var logic rst_n

  , input var logic start
  , input var logic [MAX_VEC_LENGTH_W -1:0] vec_length

  , axi_stream_if.slave data_in

  , output var logic ready
  , output var logic [MAX_VEC_LENGTH -1:0] vec
  );

  // state declaration

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__READ_CHUNK
    , STATE__DONE
    } state_t;

  state_t state_now, state_next;

  always_ff @ (posedge clk)
    if (!rst_n) state_now <= STATE__INIT;
    else        state_now <= state_next;

  // axi tready logic

  always_comb
    case (state_now)
      STATE__READ_CHUNK: data_in.tready = 1'b1;
      default:           data_in.tready = '0;
    endcase

  // reader readiness

  assign ready = state_now == STATE__DONE;

  // reading chunks

  localparam int unsigned MAX_CHUNKS = (MAX_VEC_LENGTH + AXI_DATA_WIDTH - 1) / AXI_DATA_WIDTH;
  localparam int unsigned MAX_CHUNKS_ITER_W = MAX_CHUNKS <= 1 ? 1 : $clog2(MAX_CHUNKS);
  localparam int unsigned MAX_VEC_LENGTH_WITH_PAD = MAX_CHUNKS * AXI_DATA_WIDTH;

  logic [MAX_VEC_LENGTH_WITH_PAD -1:0] vec_padded;

  logic [MAX_CHUNKS_ITER_W -1:0] chunk_iter;
  logic [MAX_CHUNKS_ITER_W -1:0] chunk_iter_end;

  assign vec = vec_padded[MAX_VEC_LENGTH -1:0];

  assign chunk_iter_end =
    MAX_CHUNKS_ITER_W'((32'(vec_length) + AXI_DATA_WIDTH - 1) / AXI_DATA_WIDTH - 1);

  always_ff @ (posedge clk)
    if (!rst_n)                                              chunk_iter <= '0;
    else
      case (state_now)
        STATE__INIT:                                         chunk_iter <= '0;
        STATE__READ_CHUNK:
          if (data_in.tvalid && chunk_iter < chunk_iter_end) chunk_iter <= chunk_iter + 1'b1;
          else                                               chunk_iter <= chunk_iter;
        default:                                             chunk_iter <= chunk_iter;
      endcase

  always_ff @ (posedge clk)
    case (state_now)
      STATE__READ_CHUNK:
        if (data_in.tvalid)
          vec_padded[chunk_iter * AXI_DATA_WIDTH +:AXI_DATA_WIDTH] <= data_in.tdata;
        else
          vec_padded[chunk_iter * AXI_DATA_WIDTH +:AXI_DATA_WIDTH] <=
            vec_padded[chunk_iter * AXI_DATA_WIDTH +:AXI_DATA_WIDTH];
      default:
        vec_padded[chunk_iter * AXI_DATA_WIDTH +:AXI_DATA_WIDTH] <=
          vec_padded[chunk_iter * AXI_DATA_WIDTH +:AXI_DATA_WIDTH];
    endcase

  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (start)                        state_next = STATE__READ_CHUNK;
        else                              state_next = STATE__INIT;
      STATE__READ_CHUNK:
        if (chunk_iter == chunk_iter_end) state_next = STATE__DONE;
        else                              state_next = STATE__READ_CHUNK;
      STATE__DONE:                        state_next = STATE__INIT;
      default:                            state_next = STATE__INIT;
    endcase

endmodule
