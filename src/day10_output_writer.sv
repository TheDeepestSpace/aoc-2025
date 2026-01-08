module day10_output_writer
  #(parameter int unsigned MAX_NUM_BUTTONS
  , parameter int unsigned MAX_NUM_BUTTONS_W =
      MAX_NUM_BUTTONS <= 1 ? 1 : $clog2(MAX_NUM_BUTTONS + 1)
  , parameter int unsigned AXI_DATA_WIDTH    = 8
  )
  ( input var logic clk
  , input var logic rst_n

  , day10_input_if.consumer  day10_input
  , day10_output_if.consumer day10_output

  , input  var logic start
  , input  var logic last_write
  , output var logic writer_ready

  , axi_stream_if.master data_out
  );

  // state management

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__WRITE_MIN_PRESSES
    , STATE__WRITE_BUTTONS_TO_PRESS
    , STATE__WRITER_READY
    } state_t;

  state_t state_now, state_next;

  always_ff @ (posedge clk)
    if (!rst_n) state_now <= STATE__INIT;
    else        state_now <= state_next;

  // axi handshake proxy

  axi_stream_if #( AXI_DATA_WIDTH ) buttons_to_press_data_out();

  always_comb
    case (state_now)
      STATE__WRITE_BUTTONS_TO_PRESS: buttons_to_press_data_out.tready = data_out.tready;
      default:                       buttons_to_press_data_out.tready = '0;
    endcase

  always_comb
    case (state_now)
      STATE__WRITE_MIN_PRESSES:      data_out.tvalid = 1'b1;
      STATE__WRITE_BUTTONS_TO_PRESS: data_out.tvalid = buttons_to_press_data_out.tvalid;
      default:                       data_out.tvalid = '0;
    endcase

  always_comb
    case (state_now)
      STATE__WRITE_BUTTONS_TO_PRESS: data_out.tlast = buttons_to_press_data_out.tlast;
      default:                       data_out.tlast = '0;
    endcase

  always_comb
    case (state_now)
      STATE__WRITE_MIN_PRESSES:
        data_out.tdata = AXI_DATA_WIDTH'(day10_output.min_button_presses);
      STATE__WRITE_BUTTONS_TO_PRESS:
        data_out.tdata = buttons_to_press_data_out.tdata;
      default:
        data_out.tdata = '0;
    endcase

  // tracking min presses writing

  logic min_presses_write_complete;

  assign min_presses_write_complete = state_now == STATE__WRITE_MIN_PRESSES && data_out.tready;

  // writing buttons to press

  logic buttons_to_press_write_start;
  logic buttons_to_press_write_complete;

  assign buttons_to_press_write_start = state_now == STATE__WRITE_BUTTONS_TO_PRESS;

  axi_write_vector #( .MAX_VEC_LENGTH ( MAX_NUM_BUTTONS ), .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ) )
    u_axi_write_buttons_to_press
      ( .clk        ( clk                              )
      , .rst_n      ( rst_n                            )

      , .start      ( buttons_to_press_write_start     )
      , .vec_length ( day10_input.num_buttons          )
      , .vec        ( day10_output.buttons_to_press    )
      , .last_write ( last_write                       )

      , .ready      ( buttons_to_press_write_complete  )
      , .data_out   ( buttons_to_press_data_out.master )
      );

  // writer completion

  assign writer_ready = state_now == STATE__WRITER_READY;

  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (start)                           state_next = STATE__WRITE_MIN_PRESSES;
        else                                 state_next = STATE__INIT;
      STATE__WRITE_MIN_PRESSES:
        if (min_presses_write_complete)      state_next = STATE__WRITE_BUTTONS_TO_PRESS;
        else                                 state_next = STATE__WRITE_MIN_PRESSES;
      STATE__WRITE_BUTTONS_TO_PRESS:
        if (buttons_to_press_write_complete) state_next = STATE__WRITER_READY;
        else                                 state_next = STATE__WRITE_BUTTONS_TO_PRESS;
      STATE__WRITER_READY:                   state_next = STATE__INIT;
      default:                               state_next = STATE__INIT;
    endcase

endmodule
