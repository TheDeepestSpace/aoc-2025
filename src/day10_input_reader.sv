module day10_input_reader
  #(parameter int unsigned MAX_NUM_LIGHTS
  , parameter int unsigned MAX_NUM_BUTTONS
  , parameter int unsigned MAX_NUM_BUTTONS_W =
      MAX_NUM_BUTTONS <= 1 ? 1 : $clog2(MAX_NUM_BUTTONS + 1)
  , parameter int unsigned MAX_NUM_LIGHTS_W  = MAX_NUM_LIGHTS <= 1 ? 1 : $clog2(MAX_NUM_LIGHTS + 1)
  , parameter int unsigned AXI_DATA_WIDTH    = 8
  )
  ( input var logic clk
  , input var logic rst_n

  , axi_stream_if #( .DATA_WIDTH ( AXI_DATA_WIDTH ) ) data_in

  , input  var logic consumer_ready
  , output var logic reader_ready
  , output var logic end_of_input

  , day10_input_if #( MAX_NUM_LIGHTS, MAX_NUM_BUTTONS ) day10_input
  );

  // state declarations

  typedef enum logic [2:0]
    { STATE__INIT
    , STATE__READ_LIGHTS_COUNT
    , STATE__READ_TARGET_LIGHTS_ARRANGEMENT
    , STATE__READ_BUTTON_COUNT
    , STATE__READ_BUTTON
    , STATE__READER_READY
    } state_t;

  state_t state_now, state_next;

  // axi stream readiness

  always_ff @ (posedge clk)
    if (!rst_n)               data_in.tready <= '0;
    else
      case (state_now)
        STATE__READ_LIGHTS_COUNT
        , STATE__READ_TARGET_LIGHTS_ARRANGEMENT
        , STATE__READ_BUTTON_COUNT
        , STATE__READ_BUTTON: data_in.tready <= 1'b1;
        default:              data_in.tready <= '0;
      endcase

  // reading lights count

  logic light_count_read_completed;

  always_ff @ (posedge clk)
    if (!rst_n)               light_count_read_completed <= '0;
    else
      case (state_now)
        STATE__INIT:          light_count_read_completed <= '0;
        STATE__READ_LIGHTS_COUNT:
          if (data_in.tvalid) light_count_read_completed <= 1'b1;
          else                light_count_read_completed <= '0;
        default:              light_count_read_completed <= '0;
      endcase

  always_ff @ (posedge clk)
    case (state_now)
      STATE__READ_LIGHTS_COUNT:
        if (data_in.tvalid) day10_input.num_lights <= MAX_NUM_LIGHTS_W'(data_in.tdata);
        else                day10_input.num_lights <= day10_input.num_lights;
      default:              day10_input.num_lights <= dat10_input.num_lights;
    endcase

  // read target lights arrangement

  logic target_lights_arrangement_read;

  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (consumer_ready)                 state_next = STATE__READ_LIGHTS_COUNT;
        else                                state_next = STATE__INIT;
      STATE__READ_LIGHTS_COUNT:
        if (light_count_read_completed)     state_next = STATE__READ_TARGET_LIGHTS_ARRANGEMENT;
        else                                state_next = STATE__READ_LIGHTS_COUNT;
      STATE__READ_TARGET_LIGHTS_ARRANGEMENT:
        if (target_lights_arrangement_read) state_next = STATE__READ_BUTTON_COUNT;
        else                                state_next = STATE__READ_TARGET_LIGHTS_ARRANGEMENT;
      STATE__READ_BUTTON_COUNT:
        if (button_count_read_completed)    state_next = STATE__READ_BUTTON;
        else                                state_next = STATE__READ_BUTTON_COUNT;
      STATE__READ_BUTTON:
        if (buttons_read_completed)         state_next = STATE__READER_READY;
        else                                state_next = STATE__READ_BUTTON;
      STATE__READER_READY:                  state_next = STATE__INIT;
      default:                              state_next = STATE_INIT;
    endcase


endmodule
