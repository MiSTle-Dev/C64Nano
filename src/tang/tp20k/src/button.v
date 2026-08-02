module button(out,in,clk,rstn);
input  in;
input clk;
output out;
input rstn;

reg in_reg0;
reg in_reg1;
reg in_reg2;

localparam st_const = 20'd1000000; //20ms at 50MHz

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        in_reg0 <= 1'b0;
        in_reg1 <= 1'b0;
        in_reg2 <= 1'b0;
    end
    else begin
        in_reg0 <= in;
        in_reg1 <= in_reg0;
        in_reg2 <= in_reg1;
    end
end

reg [19:0] cnt;
always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        cnt <= 20'd0;
    end
    else begin
        if (in_reg1 == in_reg2) begin
            cnt <= cnt + 1'b1;
        end
        else begin
            cnt <= 20'd0;
        end
    end
end

reg out;
always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        out <= 1'b0;
    end
    else begin
        if (cnt == st_const) begin
            out <= in_reg2;
        end
    end
end

endmodule