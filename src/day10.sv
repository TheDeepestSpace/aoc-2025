module day10
  #(parameter int unsigned MAX_NUM_LIGHTS
  , parameter int unsigned MAX_NUM_BUTTONS
  , parameter int unsigned AXI_DATA_WIDTH = 8 )
  ( input var logic clk
  , input var logic rst_n

  , axi_stream_if #( .DATA_WIDTH ( 8 ) )  data_in
  , axi_stream_if #( .DATA_WIDTH ( 8 ) ) data_out
  );

  // state declaration

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__READ_INPUT
    , STATE__CONFIGURE_MACHINE
    , STATE__WRITE_OUTPUT
    , STATE__DONE
    } state_t;

  state_t state_now, state_next;

  always_ff @ (posedge clk)
    if (!rst_n) state_now  <= STATE__INIT;
    else        state_next <= state_next;

  // reading input

  logic input_read_start;
  logic input_read_complete;
  logic last_input;

  day10_input #( MAX_NUM_LIGHTS, MAX_NUM_BUTTONS ) day10_input_if();

  day10_input_reader
    #(.MAX_NUM_LIGHTS  ( MAX_NUM_LIGHTS  )
    , .MAX_NUM_BUTTONS ( MAX_NUM_BUTTONS )
    , .AXI_DATA_WIDTH  ( AXI_DATA_WIDTH  )
    )
    u_day10_input_reader
      ( .clk          ( clk                 )
      , .rst_n        ( rst_n               )
      , .data_in      ( data_in             )
      , .start        ( input_read_start    )
      , .reader_ready ( input_read_complete )
      , .end_of_input ( last_input          )
      , .day10_input  ( day10_input_if      )
      );

  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:                      state_next = STATE__READ_INPUT;
      STATE__READ_INPUT:
        if (input_read_complete)        state_next = STATE__CONFIGURE_MACHINE;
        else                            state_next = STATE__READ_INPUT;
      STATE__CONFIGURE_MACHINE:
        if (configure_machine_complete) state_next = STATE__WRITE_OUTPUT;
        else                            state_next = STATE__CONFIGURE_MACHINE;
      STATE__WRITE_OUTPUT:
        if (output_write_complete)
          if (last_input)               state_next = STATE__DONE;
          else                          state_next = STATE__READ_INPUT;
        else                            state_next = STATE__WRITE_OUTPUT;
      STATE__DONE:                      state_next = STATE__DONE;
      default:                          state_next = STATE__INIT;
    endcase

endmodule
