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

  // state declarations

  typedef enum logic [2:0]
    { INPUT_STAGE_STATE__INIT
    , INPUT_STAGE_STATE__READ
    , INPUT_STAGE_STATE__WAIT_READ
    , INPUT_STAGE_STATE__STORE
    , INPUT_STAGE_STATE__NOTIFY_STORED
    , INPUT_STAGE_STATE__DONE
    } input_stage_state_t;

  typedef enum logic [2:0]
    { OUTPUT_STAGE_STATE__INIT
    , OUTPUT_STAGE_STATE__LOAD
    , OUTPUT_STAGE_STATE__WRITE
    , OUTPUT_STAGE_STATE__WAIT_WRITE
    , OUTPUT_STAGE_STATE__DONE
    } output_stage_state_t;

  input_stage_state_t  input_stage_state_now, input_stage_state_next;
  output_stage_state_t output_stage_state_now, output_stage_state_next;

  always_ff @ (posedge clk)
    if (!rst_n) input_stage_state_now <= INPUT_STAGE_STATE__INIT;
    else        input_stage_state_now <= input_stage_state_next;

  always_ff @ (posedge clk)
    if (!rst_n) output_stage_state_now <= OUTPUT_STAGE_STATE__INIT;
    else        output_stage_state_now <= output_stage_state_next;

  // reading input

  logic input_read_start;
  logic input_read_complete;
  logic last_input;

  day10_input_if #( MAX_NUM_LIGHTS, MAX_NUM_BUTTONS ) day10_input_if();

  assign input_read_start = input_stage_state_now == INPUT_STAGE_STATE__READ;

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

  // store input

  day10_input_if #( MAX_NUM_LIGHTS, MAX_NUM_BUTTONS ) day10_stored_input_if();
  logic input_storage_busy;

  // TODO: turn day10_input into a struct
  always_ff @ (posedge clk)
    if (input_stage_state_now == INPUT_STAGE_STATE__STORE) begin
      if (!input_storage_busy) begin
        day10_stored_input_if.num_lights                <= day10_input_if.num_lights;
        day10_stored_input_if.num_buttons               <= day10_input_if.num_buttons;
        day10_stored_input_if.buttons                   <= day10_input_if.buttons;
        day10_stored_input_if.target_lights_arrangement <= day10_input_if.target_lights_arrangement;
      end
    end

  // last read/write flag smuggling

  logic last_write;

  flag_fifo #( .DEPTH ( 4 ) )
    u_last_input_flag_fifo
      ( .clk       (  clk )
      , .rst_n     ( rst_n )

      , .push      ( !input_storage_busy && input_stage_state_now == INPUT_STAGE_STATE__STORE )
      , .push_data ( last_input                                                               )

      , .pop      ( output_stage_state_now == OUTPUT_STAGE_STATE__WRITE )
      , .pop_data ( last_write                                          )
      );

  // configure machine logic

  day10_output_if #( MAX_NUM_BUTTONS ) day10_output_if();

  logic configure_machine_start;
  logic configure_machine_complete;

  always_comb configure_machine_start = input_stage_state_now == INPUT_STAGE_STATE__NOTIFY_STORED;

  configure_machine
    #(.MAX_NUM_LIGHTS  ( MAX_NUM_LIGHTS  )
    , .MAX_NUM_BUTTONS ( MAX_NUM_BUTTONS )
    , .AXI_DATA_WIDTH  ( AXI_DATA_WIDTH  )
    )
    u_configure_machine
      ( .clk              ( clk                        )
      , .rst_n            ( rst_n                      )
      , .start            ( configure_machine_start    )
      , .ready            ( configure_machine_complete )
      , .accepted         ( output_write_complete      )
      , .day10_input      ( day10_stored_input_if      )
      , .day10_output     ( day10_output_if            )
      , .day10_input_busy ( input_storage_busy         )
      );

  // writing output

  logic output_write_start;
  logic output_write_complete;

  assign output_write_start = output_stage_state_now == OUTPUT_STAGE_STATE__WRITE;

  day10_output_writer #( .MAX_NUM_BUTTONS ( MAX_NUM_BUTTONS ), .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ) )
    u_day10_output_writer
      ( .clk          ( clk                   )
      , .rst_n        ( rst_n                 )

      , .day10_input  ( day10_input_if        )
      , .day10_output ( day10_output_if       )
      , .start        ( output_write_start    )
      , .last_write   ( last_write            )
      , .writer_ready ( output_write_complete )

      , .data_out     ( data_out              )
      );

  // state machines' logics

  always_comb
    case (input_stage_state_now)
      INPUT_STAGE_STATE__INIT:   input_stage_state_next = INPUT_STAGE_STATE__READ;
      INPUT_STAGE_STATE__READ, INPUT_STAGE_STATE__WAIT_READ:
        if (input_read_complete) input_stage_state_next = INPUT_STAGE_STATE__STORE;
        else                     input_stage_state_next = INPUT_STAGE_STATE__WAIT_READ;
      INPUT_STAGE_STATE__STORE:
        if (input_storage_busy)  input_stage_state_next = INPUT_STAGE_STATE__STORE;
        else                     input_stage_state_next = INPUT_STAGE_STATE__NOTIFY_STORED;
      INPUT_STAGE_STATE__NOTIFY_STORED:
        if (last_input)          input_stage_state_next = INPUT_STAGE_STATE__DONE;
        else                     input_stage_state_next = INPUT_STAGE_STATE__READ;
      INPUT_STAGE_STATE__DONE:   input_stage_state_next = INPUT_STAGE_STATE__DONE;
      default:                   input_stage_state_next = INPUT_STAGE_STATE__INIT;
    endcase

  always_comb
    case (output_stage_state_now)
      OUTPUT_STAGE_STATE__INIT:         output_stage_state_next = OUTPUT_STAGE_STATE__LOAD;
      OUTPUT_STAGE_STATE__LOAD:
        if (configure_machine_complete) output_stage_state_next = OUTPUT_STAGE_STATE__WRITE;
        else                            output_stage_state_next = OUTPUT_STAGE_STATE__LOAD;
      OUTPUT_STAGE_STATE__WRITE, OUTPUT_STAGE_STATE__WAIT_WRITE:
        if (output_write_complete)
          if (last_write)               output_stage_state_next = OUTPUT_STAGE_STATE__DONE;
          else                          output_stage_state_next = OUTPUT_STAGE_STATE__LOAD;
        else                            output_stage_state_next = OUTPUT_STAGE_STATE__WAIT_WRITE;
      OUTPUT_STAGE_STATE__DONE:         output_stage_state_next = OUTPUT_STAGE_STATE__DONE;
      default:                          output_stage_state_next = OUTPUT_STAGE_STATE__INIT;
    endcase

endmodule
