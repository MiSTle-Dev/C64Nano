module pll_mDRP_intf(
    input clk,
    input rst_n,
    input pll_lock,
    input wr,
    output reg mdrp_inc,
    output reg [1:0] mdrp_op,
    output reg [7:0] mdrp_wdata,
    input  [7:0] mdrp_rdata
);

    reg wr_r;
    reg rd_r;
    reg [7:0] wdata_r;
    reg [7:0] addr_r;
    reg [4:0] c_s;
    reg [4:0] n_s;
    reg [2:0] cnt;
    reg pll_lock_r;

    localparam IDLE     =   5'b00001;
    localparam OP_WR    =   5'b00010;
    localparam OP_WR1   =   5'b00100;
    localparam OP_RD    =   5'b01000;
    localparam WAIT_R   =   5'b10000;

    localparam NOOP   = 2'b00;
    localparam RDCODE = 2'b10;
    localparam WRCODE = 2'b01;

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            pll_lock_r <= 1'b0;
        else
            pll_lock_r <= pll_lock;
    end
    
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            c_s <= IDLE;
        else
            c_s <= n_s;
    end

    always@(*)begin
        case(c_s)
            IDLE:
                if(pll_lock & (~pll_lock_r))
                    n_s = OP_RD;
                else
                    n_s = IDLE;
            OP_WR:
                if(~pll_lock)
                    n_s = IDLE;
                else if(wr)
                    n_s = OP_WR1;
                else
                    n_s = OP_WR;
            OP_WR1:
                if(~pll_lock)
                    n_s = IDLE;
                else if(wr)
                    n_s = IDLE;
                else
                    n_s = OP_WR1;
            OP_RD:
                if(~pll_lock)
                    n_s = IDLE;
                else if(cnt == 3'd6-1)
                    n_s = WAIT_R;
                else
                    n_s = OP_RD;
            WAIT_R:
                if(~pll_lock)
                    n_s = IDLE;
                else 
                    n_s = OP_WR;
            default:n_s = IDLE;
        endcase
    end

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            mdrp_op <= NOOP;
        else if(c_s == IDLE)
            mdrp_op <= NOOP;
        else if((c_s == OP_WR | c_s == OP_WR1) & wr)
            mdrp_op <= WRCODE;
        else
            mdrp_op <= RDCODE;
    
    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            mdrp_inc <= 1'b0;
        else if(c_s == IDLE)
            mdrp_inc <= 1'b0;
        else if(c_s == OP_RD)
            mdrp_inc <= 1'b1;
        else
            mdrp_inc <= 1'b0;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            cnt <= 'd0;
        else if(c_s == OP_RD)
            cnt <= cnt + 1'b1;
        else
            cnt <= 'd0;
    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            mdrp_wdata <= 8'd0;
        else if(c_s == OP_WR & wr)
            mdrp_wdata <= {1'b0,mdrp_rdata[6:0]};
        else if(c_s == OP_WR1 & wr)
            mdrp_wdata[7] <= 1'b1;
endmodule
