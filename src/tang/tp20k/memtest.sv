
`timescale 1ns / 100ps

// Main clock frequency
localparam FREQ=31_500_000;

module memtest(

    input clk,
    input sys_resetn,
    input write_level_done,
    input read_calib_done,
    input fail_high,
    input fail_low,
    output reg mem_resetn,
    output reg meminit_check // pulse when memory initialization is checked
    );

// Memory initialization control
// After reset, every 250ms we check whether memory is successsfully intialized and tested.
// If not we reset the whole machine, print a message and hope it will finally succeed.
reg [$clog2(FREQ/5+1)-1:0] meminit_cnt;

always @(posedge clk) begin
    meminit_cnt <= meminit_cnt == 0 ? 23'd0 : meminit_cnt - 23'd1;
    mem_resetn <= 1'b1;
    meminit_check <= 0;
    if (meminit_cnt == 1) begin
        meminit_check <= 1'b1;
        if (~write_level_done || ~read_calib_done || (fail_high && fail_low)) begin
            mem_resetn <= 0; // reset DDR3 controller
            meminit_cnt <= FREQ/5; // check again in 0.2 sec
        end
    end

    if (~sys_resetn) begin
        meminit_cnt <= FREQ/5;
        meminit_check <= 1'b0;
        mem_resetn <= 1'b1;
    end
end

endmodule
