//--------------------------------------------------------------------------------------------------------
module glitch_filter # (parameter 
  FILTER_CYCLE = 3
) (
    input       clk,
    input       rstn,
    input       din,
    output      dout
);
localparam          DW_LOG  = $clog2(FILTER_CYCLE);
reg                 din_reg =0;
reg                 dout_reg =0;
reg [DW_LOG-1:0]    cnt;
wire                din_pos,din_neg;
wire                dec_edge;

assign din_pos  = din  && ~din_reg;
assign din_neg  = ~din && din_reg;
assign dec_edge = din_pos ^din_neg;

always @(posedge clk or negedge rstn)
    if (~rstn)
        din_reg <=0;
    else
        din_reg <=din;

always @(posedge clk or negedge rstn)
    if (~rstn)
        cnt <=0;
    else if (dec_edge || cnt==FILTER_CYCLE-1)
        cnt <=0;
    else
        cnt <=cnt+1;

always @(posedge clk or negedge rstn)
    if (~rstn)
        dout_reg <=0;
    else if (cnt==FILTER_CYCLE-1)
        dout_reg <=din_reg;

endmodule