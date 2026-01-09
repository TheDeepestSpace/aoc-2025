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

  , axi_stream_if.slave data_in

  , input  var logic start
  , output var logic reader_ready
  , output var logic end_of_input

  , day10_input_if.producer day10_input
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

  always_ff @ (posedge clk)
    if (!rst_n) state_now <= STATE__INIT;
    else        state_now <= state_next;

  // axi stream proxies

  axi_stream_if #( AXI_DATA_WIDTH ) lights_data_in();
  axi_stream_if #( AXI_DATA_WIDTH ) buttons_data_in();

  assign lights_data_in.tvalid = data_in.tvalid;
  assign lights_data_in.tdata  = data_in.tdata;

  assign buttons_data_in.tvalid = data_in.tvalid;
  assign buttons_data_in.tdata  = data_in.tdata;

  always_comb
    case (state_now)
      STATE__READ_LIGHTS_COUNT, STATE__READ_BUTTON_COUNT: data_in.tready = 1'b1;
      STATE__READ_TARGET_LIGHTS_ARRANGEMENT:              data_in.tready = lights_data_in.tready;
      STATE__READ_BUTTON:                                 data_in.tready = buttons_data_in.tready;
      default:                                            data_in.tready = '0;
    endcase

  // consumer readiness

  assign reader_ready = state_now == STATE__READER_READY;

  always_ff @ (posedge clk)
    if (data_in.tlast)
      end_of_input <= 1'b1;
    else
      end_of_input <= end_of_input;

  // reading lights count

  logic light_count_read_completed;

  always_comb
    case (state_now)
      STATE__READ_LIGHTS_COUNT:
        if (data_in.tvalid) light_count_read_completed = 1'b1;
        else                light_count_read_completed = '0;
      default:              light_count_read_completed = '0;
    endcase

  always_ff @ (posedge clk)
    case (state_now)
      STATE__READ_LIGHTS_COUNT:
        if (data_in.tvalid) day10_input.num_lights <= MAX_NUM_LIGHTS_W'(data_in.tdata);
        else                day10_input.num_lights <= day10_input.num_lights;
      default:              day10_input.num_lights <= day10_input.num_lights;
    endcase

  // read target lights arrangement

  logic target_lights_arrangement_read_start;
  logic target_lights_arrangement_read_completed;

  // don't care, relay on the protocol format
  logic target_lights_arrangement_read_last;

  assign target_lights_arrangement_read_start =
    state_now == STATE__READ_TARGET_LIGHTS_ARRANGEMENT;

  axi_read_vector
    #(.MAX_VEC_LENGTH ( MAX_NUM_LIGHTS )
    , .AXI_DATA_WIDTH ( AXI_DATA_WIDTH )
    , .READ_DIR       ( DIR__RIGHT     )
    )
    u_axi_read_target_lights_arrengement
      ( .clk        ( clk                                      )
      , .rst_n      ( rst_n                                    )

      , .start      ( target_lights_arrangement_read_start     )
      , .vec_length ( day10_input.num_lights                   )
      , .data_in    ( lights_data_in                           )

      , .ready      ( target_lights_arrangement_read_completed )
      , .last       ( target_lights_arrangement_read_last      )
      , .vec        ( day10_input.target_lights_arrangement    )
      );

  // reading button count

  logic button_count_read_completed;

  always_comb
    case (state_now)
      STATE__INIT:          button_count_read_completed = '0;
      STATE__READ_BUTTON_COUNT:
        if (data_in.tvalid) button_count_read_completed = 1'b1;
        else                button_count_read_completed = '0;
      default:              button_count_read_completed = '0;
    endcase

  always_ff @ (posedge clk)
    case (state_now)
      STATE__READ_BUTTON_COUNT:
        if (data_in.tvalid) day10_input.num_buttons <= MAX_NUM_BUTTONS_W'(data_in.tdata);
        else                day10_input.num_buttons <= day10_input.num_buttons;
      default:              day10_input.num_buttons <= day10_input.num_buttons;
    endcase

  // reading button data

  logic buttons_read_start;
  logic buttons_read_completed;

  // dont care, rely on the protocol format
  logic buttons_read_last;

  logic button_ready;

  logic [MAX_NUM_BUTTONS_W -1:0] button_iter;

  assign buttons_read_start = state_now == STATE__READ_BUTTON;

  assign buttons_read_completed = button_ready && button_iter == day10_input.num_buttons - 1;

  always_ff @ (posedge clk)
    if (!rst_n) button_iter <= '0;
    else
      case (state_now)
        // note how we are not resetting button iter at STATE__INIT; this is because we want to
        // continue button axi reader to stream into the last button; if we change button_iter to 0
        // once we are done reading, the last button's data will spill into the first one because
        // button vector reader works as a tube that we point to the right button vector to stream
        // into; therefore we are only resetting the button iter when we are about to start reading
        // buttons
        STATE__READ_BUTTON_COUNT: button_iter <= '0;
        STATE__READ_BUTTON:
          if (button_ready && button_iter < day10_input.num_buttons)
            button_iter <= button_iter + 1'b1;
          else
            button_iter <= button_iter;
        default: button_iter <= button_iter;
      endcase

  axi_read_vector
    #(.MAX_VEC_LENGTH ( MAX_NUM_BUTTONS )
    , .AXI_DATA_WIDTH ( AXI_DATA_WIDTH  )
    , .READ_DIR       ( DIR__RIGHT      )
    )
    u_axi_read_button
      ( .clk        ( clk                              )
      , .rst_n      ( rst_n                            )

      , .start      ( buttons_read_start               )
      , .vec_length ( day10_input.num_lights           )
      , .data_in    ( buttons_data_in                  )

      , .ready      ( button_ready                     )
      , .last       ( buttons_read_last                )
      , .vec        ( day10_input.buttons[button_iter] )
      );


  // state machine logic

  always_comb
    case (state_now)
      STATE__INIT:
        if (start)
          state_next = STATE__READ_LIGHTS_COUNT;
        else
          state_next = STATE__INIT;
      STATE__READ_LIGHTS_COUNT:
        if (light_count_read_completed)
          state_next = STATE__READ_TARGET_LIGHTS_ARRANGEMENT;
        else
          state_next = STATE__READ_LIGHTS_COUNT;
      STATE__READ_TARGET_LIGHTS_ARRANGEMENT:
        if (target_lights_arrangement_read_completed)
          state_next = STATE__READ_BUTTON_COUNT;
        else
          state_next = STATE__READ_TARGET_LIGHTS_ARRANGEMENT;
      STATE__READ_BUTTON_COUNT:
        if (button_count_read_completed)
          state_next = STATE__READ_BUTTON;
        else
          state_next = STATE__READ_BUTTON_COUNT;
      STATE__READ_BUTTON:
        if (buttons_read_completed)
          state_next = STATE__READER_READY;
        else
          state_next = STATE__READ_BUTTON;
      STATE__READER_READY: state_next = STATE__INIT;
      default: state_next = STATE__INIT;
    endcase

endmodule
