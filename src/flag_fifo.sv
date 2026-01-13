// a rudimentary single-bit fifo
module flag_fifo
  #(parameter int unsigned DEPTH   = 4
  , parameter int unsigned ADDR_W  = DEPTH <= 1 ? 1 : $clog2(DEPTH)
  , parameter int unsigned COUNT_W = DEPTH <= 1 ? 1 : $clog2(DEPTH + 1)
  )
  ( input var logic clk
  , input var logic rst_n

  , input var logic push
  , input var logic push_data

  , input  var logic pop
  , output var logic pop_data
  );

  logic [DEPTH -1:0]   mem;
  logic [ADDR_W -1:0]  read_addr;
  logic [ADDR_W -1:0]  write_addr;
  logic [COUNT_W -1:0] count;

  logic empty;
  logic full;

  assign empty = count == '0;
  assign full  = count == COUNT_W'(DEPTH);

  always_ff @ (posedge clk)
    if (!rst_n)             pop_data <= '0;
    else if (pop && !empty) pop_data <= mem[read_addr];
    else                    pop_data <= pop_data;

  always_ff @ (posedge clk)
    if (!rst_n)             read_addr <= '0;
    else if (pop && !empty) read_addr <= read_addr + 1'b1;
    else                    read_addr <= read_addr;

  always_ff @ (posedge clk)
    if (!rst_n)             write_addr <= '0;
    else if (push && !full) write_addr <= write_addr + 1'b1;
    else                    write_addr <= write_addr;

  always_ff @ (posedge clk)
    if (!rst_n)             count <= '0;
    else if (pop && !empty) count <= count - 1'b1;
    else if (push && !full) count <= count + 1'b1;
    else                    count <= count;

  always_ff @ (posedge clk)
    if (!rst_n)             mem             <= '0;
    else if (push && !full) mem[write_addr] <= push_data;
    else                    mem             <= mem;

endmodule
