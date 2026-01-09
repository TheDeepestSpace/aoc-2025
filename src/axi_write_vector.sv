module axi_write_vector
  #(parameter int unsigned MAX_VEC_LENGTH
  , parameter int unsigned AXI_DATA_WIDTH
  , parameter int unsigned MAX_VEC_LENGTH_W =
      MAX_VEC_LENGTH <= 1 ? 1 : $clog2(MAX_VEC_LENGTH + 1)
  )
  ( input var logic clk
  , input var logic rst_n

  , input var logic start
  , input var logic [MAX_VEC_LENGTH_W -1:0] vec_length
  , input var logic [MAX_VEC_LENGTH -1:0] vec
  , input var logic last_write

  , output var logic ready
  , axi_stream_if.master data_out
  );

  // state management

  typedef enum logic [1:0]
    { STATE__INIT
    , STATE__WRITE_CHUNK
    } state_t;

  state_t state_now, state_next;

  always_ff @ (posedge clk)
    if (!rst_n) state_now <= STATE__INIT;
    else        state_now <= state_next;

  // chunk processing

  localparam int unsigned MAX_CHUNKS =
    (MAX_VEC_LENGTH + AXI_DATA_WIDTH - 1) / AXI_DATA_WIDTH;
  localparam int unsigned MAX_CHUNKS_ITER_W =
    MAX_CHUNKS <= 1 ? 1 : $clog2(MAX_CHUNKS + 1);
  localparam int unsigned MAX_VEC_LENGTH_WITH_PAD = MAX_CHUNKS * AXI_DATA_WIDTH;

  logic [MAX_VEC_LENGTH_WITH_PAD -1:0] vec_padded;

  logic [MAX_CHUNKS_ITER_W -1:0] chunk_iter;
  logic [MAX_CHUNKS_ITER_W -1:0] total_chunks;
  logic [MAX_CHUNKS_ITER_W -1:0] chunk_iter_end;
  logic                          last_chunk;

  assign vec_padded = {vec, {(MAX_VEC_LENGTH_WITH_PAD - MAX_VEC_LENGTH){1'b0}}};

  assign total_chunks   =
    MAX_CHUNKS_ITER_W'((32'(vec_length) + AXI_DATA_WIDTH - 1) / AXI_DATA_WIDTH);
  assign chunk_iter_end = (total_chunks == '0) ? '0 : total_chunks - 1'b1;
  assign last_chunk     = (chunk_iter == chunk_iter_end) && (total_chunks != '0);

  always_ff @ (posedge clk)
    if (!rst_n)                                                  chunk_iter <= '0;
    else
      case (state_now)
        STATE__INIT:                                             chunk_iter <= '0;
        STATE__WRITE_CHUNK:
          if (data_out.tvalid && data_out.tready && !last_chunk) chunk_iter <= chunk_iter + 1'b1;
          else                                                   chunk_iter <= chunk_iter;
        default:                                                 chunk_iter <= chunk_iter;
      endcase

  always_comb data_out.tvalid = (state_now == STATE__WRITE_CHUNK);
  always_comb data_out.tlast =  (state_now == STATE__WRITE_CHUNK) && last_chunk && last_write;

  always_comb data_out.tdata = vec_padded[chunk_iter * AXI_DATA_WIDTH +: AXI_DATA_WIDTH];

  assign ready = data_out.tvalid && data_out.tready && last_chunk;

  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (start)
          if (total_chunks == '0) state_next = STATE__INIT;
          else                    state_next = STATE__WRITE_CHUNK;
        else                      state_next = STATE__INIT;
      STATE__WRITE_CHUNK:
        if (ready)                state_next = STATE__INIT;
        else                      state_next = STATE__WRITE_CHUNK;
      default:                    state_next = STATE__INIT;
    endcase

endmodule
