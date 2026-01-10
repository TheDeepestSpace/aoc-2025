`include "axi_stream_if.svh"

module day10
  #(parameter int unsigned MAX_NUM_LIGHTS
  , parameter int unsigned MAX_NUM_BUTTONS
  , parameter int unsigned AXI_DATA_WIDTH = 8
  )
  ( input var logic clk
  , input var logic rst_n

  , axi_stream_if.slave  data_in
  , axi_stream_if.master data_out
  );

  // state declaration

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__READ_INPUT
    , STATE__WAIT_READ_INPUT
    , STATE__CONFIGURE_MACHINE
    , STATE__WAIT_CONFIGURE_MACHINE
    , STATE__WRITE_OUTPUT
    , STATE__WAIT_WRITE_OUTPUT
    , STATE__DONE
    } state_t;

  state_t state_now, state_next;

  always_ff @ (posedge clk)
    if (!rst_n) state_now <= STATE__INIT;
    else        state_now <= state_next;

  // reading input

  logic input_read_start;
  logic input_read_complete;
  logic last_input;

  day10_input_if #( MAX_NUM_LIGHTS, MAX_NUM_BUTTONS ) day10_input_if();

  assign input_read_start = state_now == STATE__READ_INPUT;

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

  // configure machine logic

  day10_output_if #( MAX_NUM_BUTTONS ) day10_output_if();

  logic configure_machine_start;
  logic configure_machine_complete;

  always_comb configure_machine_start = state_now == STATE__CONFIGURE_MACHINE;

  configure_machine
    #(.MAX_NUM_LIGHTS  ( MAX_NUM_LIGHTS  )
    , .MAX_NUM_BUTTONS ( MAX_NUM_BUTTONS )
    , .AXI_DATA_WIDTH  ( AXI_DATA_WIDTH  )
    )
    u_configure_machine
      ( .clk          ( clk                        )
      , .rst_n        ( rst_n                      )
      , .start        ( configure_machine_start    )
      , .ready        ( configure_machine_complete )
      , .accepted     ( output_write_complete      )
      , .day10_input  ( day10_input_if             )
      , .day10_output ( day10_output_if            )
      );

  // writing output

  logic output_write_start;
  logic output_write_complete;

  assign output_write_start = state_now == STATE__WRITE_OUTPUT;

  day10_output_writer #( .MAX_NUM_BUTTONS ( MAX_NUM_BUTTONS ), .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ) )
    u_day10_output_writer
      ( .clk          ( clk                   )
      , .rst_n        ( rst_n                 )

      , .day10_input  ( day10_input_if        )
      , .day10_output ( day10_output_if       )
      , .start        ( output_write_start    )
      , .last_write   ( last_input            )
      , .writer_ready ( output_write_complete )

      , .data_out     ( data_out              )
      );

  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:                      state_next = STATE__READ_INPUT;
      STATE__READ_INPUT, STATE__WAIT_READ_INPUT:
        if (input_read_complete)        state_next = STATE__CONFIGURE_MACHINE;
        else                            state_next = STATE__WAIT_READ_INPUT;
      STATE__CONFIGURE_MACHINE, STATE__WAIT_CONFIGURE_MACHINE:
        if (configure_machine_complete) state_next = STATE__WRITE_OUTPUT;
        else                            state_next = STATE__WAIT_CONFIGURE_MACHINE;
      STATE__WRITE_OUTPUT, STATE__WAIT_WRITE_OUTPUT:
        if (output_write_complete)
          if (last_input)               state_next = STATE__DONE;
          else                          state_next = STATE__READ_INPUT;
        else                            state_next = STATE__WAIT_WRITE_OUTPUT;
      STATE__DONE:                      state_next = STATE__DONE;
      default:                          state_next = STATE__INIT;
    endcase

endmodule
