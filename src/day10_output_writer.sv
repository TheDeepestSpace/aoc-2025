module day10_input_writer
  #(parameter int unsigned MAX_NUM_BUTTONS
  , parameter int unsigned MAX_NUM_BUTTONS_W =
      MAX_NUM_BUTTONS <= 1 ? 1 : $clog2(MAX_NUM_BUTTONS + 1)
  , parameter int unsigned AXI_DATA_WIDTH    = 8
  )
  ( input var logic clk
  , input var logic rst_n

  , day10_output_if #( MAX_NUM_BUTTONS ) day10_output

  , input  var logic start
  , input  var logic last_write
  , output var logic writer_ready

  , axi_stream_if #( .DATA_WIDTH ( AXI_DATA_WIDTH ) ) data_out
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

  // writing min presses

  logic min_presses_write_complete;

  assign data_out.tvalid = state_now == STATE__WRITE_MIN_PRESSES;

  always_ff @ (posedge clk)
    if (!rst_n)                min_presses_write_complete <= '0;
    else
      case (state_now)
        STATE__INIT:           min_presses_write_complete <= '0;
        STATE__WRITE_MIN_PRESSES:
          if (data_out.tready) min_presses_write_complete <= 1'b1;
          else                 min_presses_write_complete <= '0;
        default:               min_presses_write_complete <= '0;
      endcase

  always_ff @ (posedge clk)
    case (state_now)
      STATE__WRITE_MIN_PRESSES: data_out.tdata <= AXI_DATA_WIDTH'(day10_output.min_button_presses);
      default:                  data_out.tdata <= data_out.tdata;
    endcase

  // writing buttons to press

  logic buttons_to_press_write_start;
  logic buttons_to_press_write_complete;

  assign buttons_to_press_write_start = state_now == STATE__WRITE_BUTTONS_TO_PRESS;

  axi_write_vector #( .MAX_VEC_LENGTH ( MAX_NUM_BUTTONS ), .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ) )
    u_axi_write_buttons_to_press
      ( .clk        ( clk                             )
      , .rst_n      ( rst_n                           )

      , .start      ( buttons_to_press_write_start    )
      , .vec_length ( day10_output.num_buttons        )
      , .vec        ( day10_output.buttons_to_press   )
      , .last_write ( last_write                      )

      , .ready      ( buttons_to_press_write_complete )
      , .data_out   ( data_out                        )
      );

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
