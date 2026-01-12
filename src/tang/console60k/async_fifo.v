// Based on: https://log.martinatkins.me/2020/06/07/verilog-async-fifo/
// Async FIFO implementation
module async_fifo(
  input                       reset,          // async assert; deassert synced per domain
  input                       write_clk,
  input                       write,
  input      [DATA_WIDTH-1:0] write_data,
  output reg                  can_write,
  input                       read_clk,
  input                       read,
  output reg [DATA_WIDTH-1:0] read_data,
  output reg                  can_read,
  output     [BUFFER_ADDR_WIDTH:0] read_available
);
    parameter DATA_WIDTH = 16;
    parameter BUFFER_ADDR_WIDTH = 8;
    parameter BUFFER_SIZE = 2 ** BUFFER_ADDR_WIDTH;

    // Our buffer as a whole is accessed by both the write_clk and read_clk
    // domains, but read_clk is only used to access elements >= read_ptr and
    // write_clk only for elements < read_ptr. We're expecting this buffer to
    // be inferred as a dual-port block RAM, so the board-specific top module
    // should choose a suitable buffer size to allow that inference.
    reg [DATA_WIDTH-1:0] buffer [BUFFER_SIZE-1:0] /* xx synthesis syn_ramstyle="block_ram" */ ;

    ///// RESET SYNCHRONIZATION /////

    // Generate per-domain synchronous resets (async assert, sync deassert)
    reg [1:0] wr_rst_sync;
    reg [1:0] rd_rst_sync;
    wire      wr_rst = wr_rst_sync[0];
    wire      rd_rst = rd_rst_sync[0];

    always @(posedge write_clk or posedge reset) begin
        if (reset) wr_rst_sync <= 2'b11; else wr_rst_sync <= {1'b0, wr_rst_sync[1]};
    end

    always @(posedge read_clk or posedge reset) begin
        if (reset) rd_rst_sync <= 2'b11; else rd_rst_sync <= {1'b0, rd_rst_sync[1]};
    end

    ///// WRITE CLOCK DOMAIN /////

    // This is an address into the buffer array.
    // It intentionally has one additional bit so we can track wrap-around by
    // comparing with the MSB of read_ptr (or, at least, with the grey-code
    // form that we synchronize over into this clock domain.)
    reg [BUFFER_ADDR_WIDTH:0] write_ptr;
    wire [BUFFER_ADDR_WIDTH-1:0] write_addr = write_ptr[BUFFER_ADDR_WIDTH-1:0]; // truncated version without the wrap bit

    // This is the grey-coded version of write_ptr in the write clock domain.
    reg [BUFFER_ADDR_WIDTH:0] write_ptr_grey_w;

    // This is the grey-coded version of read_ptr in the write clock domain,
    // synchronized over here using module read_ptr_grey_sync declared later.
    wire [BUFFER_ADDR_WIDTH:0] read_ptr_grey_w;

    // Write pointer (and its grey-coded equivalent) increments whenever
    // "write" is set on a clock, as long as our buffer isn't full.
    wire [BUFFER_ADDR_WIDTH:0] next_write_ptr = write_ptr + 1;
    wire [BUFFER_ADDR_WIDTH:0] next_write_ptr_grey_w = (next_write_ptr >> 1) ^ next_write_ptr;
    // Our buffer is full if the read and write addresses are the same but the
    // MSBs (wrap bits) are different. We compare the grey code versions here
    // so we can use our cross-domain-synchronized copy of the read pointer.
    wire current_can_write = write_ptr_grey_w != { ~read_ptr_grey_w[BUFFER_ADDR_WIDTH:BUFFER_ADDR_WIDTH-1], read_ptr_grey_w[BUFFER_ADDR_WIDTH-2:0] };
    wire next_can_write = next_write_ptr_grey_w != { ~read_ptr_grey_w[BUFFER_ADDR_WIDTH:BUFFER_ADDR_WIDTH-1], read_ptr_grey_w[BUFFER_ADDR_WIDTH-2:0] };
    always @(posedge write_clk) begin
        if (wr_rst) begin
            write_ptr <= 0;
            write_ptr_grey_w <= 0;
            can_write <= 1;
        end else begin
            if (write && can_write) begin
                write_ptr <= next_write_ptr;
                write_ptr_grey_w <= next_write_ptr_grey_w;
                can_write <= next_can_write;
            end else begin
                can_write <= current_can_write;
            end
        end
    end

    // If "write" is set on a clock then we commit write_data into the current
    // write address.
    always @(posedge write_clk) begin
        if (write && can_write) begin
            buffer[write_addr] <= write_data;
        end
    end

    ///// READ CLOCK DOMAIN /////

    // This is an address into the buffer array.
    // It intentionally has one additional bit so we can track wrap-around by
    // comparing with the MSB of write_ptr (or, at least, with the grey-code
    // form that we synchronize over into this clock domain.)
    reg [BUFFER_ADDR_WIDTH:0] read_ptr;
    wire [BUFFER_ADDR_WIDTH-1:0] read_addr = read_ptr[BUFFER_ADDR_WIDTH-1:0]; // truncated version without the wrap bit

    // This is the grey-coded version of write_ptr in the read clock domain.
    reg [BUFFER_ADDR_WIDTH:0] read_ptr_grey_r;

    // This is the grey-coded version of write_ptr in the read clock domain,
    // synchronized over here using module write_ptr_grey_sync declared later.
    wire [BUFFER_ADDR_WIDTH:0] write_ptr_grey_r;

    // Convert grey-coded write pointer to binary in read clock domain
    function [BUFFER_ADDR_WIDTH:0] grey2bin;
        input [BUFFER_ADDR_WIDTH:0] g;
        integer i;
        begin
            grey2bin[BUFFER_ADDR_WIDTH] = g[BUFFER_ADDR_WIDTH];
            for (i = BUFFER_ADDR_WIDTH-1; i >= 0; i = i - 1) begin
                grey2bin[i] = grey2bin[i+1] ^ g[i];
            end
        end
    endfunction
    wire [BUFFER_ADDR_WIDTH:0] write_ptr_bin_r = grey2bin(write_ptr_grey_r);
    assign read_available = write_ptr_bin_r - read_ptr;

    // Read pointer (and its grey-coded equivalent) increments whenever
    // "read" is set on a clock, as long as our buffer isn't full.
    wire [BUFFER_ADDR_WIDTH:0] next_read_ptr = read_ptr + 1;
    wire [BUFFER_ADDR_WIDTH:0] next_read_ptr_grey_r = (next_read_ptr >> 1) ^ next_read_ptr;
    // Our buffer is empty if the read and write addresses are the same and the
    // MSBs (wrap bits) are also equal. We compare the grey code versions here
    // so we can use our cross-domain-synchronized copy of the write pointer.
    wire current_can_read = read_ptr_grey_r != write_ptr_grey_r;
    wire next_can_read = next_read_ptr_grey_r != write_ptr_grey_r;
    always @(posedge read_clk) begin
        if (rd_rst) begin
            read_ptr <= 0;
            read_ptr_grey_r <= 0;
            read_data <= 0;
            can_read <= 0;
        end else begin
            if (read) begin
                if (can_read) begin
                    read_ptr <= next_read_ptr;
                    read_ptr_grey_r <= next_read_ptr_grey_r;
                end
                can_read <= next_can_read;
                if (next_can_read) begin
                    read_data <= buffer[next_read_ptr];
                end else begin
                    read_data <= 0;
                end
            end else begin
                can_read <= current_can_read;
                if (current_can_read) begin
                    read_data <= buffer[read_addr];
                end else begin
                    read_data <= 0;
                end
            end
        end
    end

    ///// CROSS-DOMAIN /////

    // Synchronize read_ptr_grey_r into read_ptr_grey_w.
    crossdomain #(.SIZE(BUFFER_ADDR_WIDTH+1)) read_ptr_grey_sync (
        .reset(wr_rst),
        .clk(write_clk),
        .data_in(read_ptr_grey_r),
        .data_out(read_ptr_grey_w)
    );

    // Synchronize write_ptr_grey_w into write_ptr_grey_r.
    crossdomain #(.SIZE(BUFFER_ADDR_WIDTH+1)) write_ptr_grey_sync (
        .reset(rd_rst),
        .clk(read_clk),
        .data_in(write_ptr_grey_w),
        .data_out(write_ptr_grey_r)
    );

endmodule

// This is a generalization of the crossdomain module from earlier that
// now supports a customizable value size, so we can safely transmit multi-bit
// values as long as they are grey coded.
module crossdomain #(parameter SIZE = 1) (
  input reset,
  input clk,
  input [SIZE-1:0] data_in,
  output reg [SIZE-1:0] data_out
);

    reg [SIZE-1:0] data_tmp;

    always @(posedge clk) begin
        if (reset) begin
            {data_out, data_tmp} <= 0;
        end else begin
            {data_out, data_tmp} <= {data_tmp, data_in};
        end
    end

endmodule
