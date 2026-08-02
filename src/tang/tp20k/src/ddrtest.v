

`timescale 1ps/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2016/07/27 10:58:47
// Design Name:
// Module Name: user_test
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module ddr3_test1 #(
    parameter ADDR_WIDTH = 28,
    parameter APP_DATA_WIDTH = 256,
    parameter APP_MASK_WIDTH = 32,
    parameter USER_REFRESH = "OFF"
    )
    (
    //input
    clk, 
    rst, 
    app_rdy, 
    app_rd_data_valid, 
    app_rd_data, 
    init_calib_complete,
    wr_data_rdy,
    //output
    app_en,
    app_cmd, 
    app_addr, 
    app_wdf_data, 
    app_wdf_wren,
    app_wdf_end, 
    app_wdf_mask, 
    app_burst,
    sr_req, 
    ref_req,
    error
    
    );

    input clk;
    input rst;
    input app_rdy;
    input app_rd_data_valid;
    input wr_data_rdy;
    input [APP_DATA_WIDTH-1:0] app_rd_data;
    input init_calib_complete;

    output reg           app_en;
    output reg     [2:0] app_cmd;
    output reg     [ADDR_WIDTH-1:0] app_addr ;
    output reg     [APP_DATA_WIDTH-1:0] app_wdf_data ;
    output reg     app_wdf_wren;
    output     app_wdf_end;
    output [APP_MASK_WIDTH-1:0] app_wdf_mask ;
    output app_burst;
    output sr_req;
    output ref_req; 
    output error;

    reg [15:0] error_int1;
    
	

    reg app_rd_data_valid_r;
    reg [APP_DATA_WIDTH-1:0] app_rd_data_r/* synthesis syn_preserve = 1 */;
    reg app_rd_data_valid_rr;
    reg [APP_DATA_WIDTH-1:0] app_rd_data_rr/* synthesis syn_preserve = 1 */;

    always@(posedge clk or posedge rst)begin
        if(rst)begin
            app_rd_data_valid_r <= 1'b0;
            app_rd_data_r <= 'd0;
            app_rd_data_valid_rr <= 1'b0;
            app_rd_data_rr <= 'd0;
        end
        else begin
            app_rd_data_valid_r <= app_rd_data_valid;
            app_rd_data_r <= app_rd_data;
            app_rd_data_valid_rr <= app_rd_data_valid_r;
            app_rd_data_rr <= app_rd_data_r;
        end
    end

    assign app_wdf_mask = 0;
    assign sr_req = 0;
    assign ref_req = 0;
    assign app_burst = 0;
	
	wire [63:0] EYE_MEM [0:7];
	
	assign	EYE_MEM[0] = 64'h5883adb4c88ad596;
	assign	EYE_MEM[1] = 64'h1122334455667788;
	assign	EYE_MEM[2] = 64'h99aabbccddeeff00;
	assign	EYE_MEM[3] = 64'h0000ffff0000ffff;
	assign  EYE_MEM[4] = 64'hffff0000ffff0000;
	assign  EYE_MEM[5] = 64'h00000000ffff0000;
	assign  EYE_MEM[6] = 64'haf5d632fc8b91658;
	assign  EYE_MEM[7] = 64'hffffffff0000ffff;

	wire [63:0] EYE_MEM_C [0:7];
	
	assign	EYE_MEM_C[0] = 64'h5883adb4c88ad596;
	assign	EYE_MEM_C[1] = 64'h1122334455667788;
	assign	EYE_MEM_C[2] = 64'h99aabbccddeeff00;
	assign	EYE_MEM_C[3] = 64'h0000ffff0000ffff;
	assign  EYE_MEM_C[4] = 64'hffff0000ffff0000;
	assign  EYE_MEM_C[5] = 64'h00000000ffff0000;
	assign  EYE_MEM_C[6] = 64'haf5d632fc8b91658;
	assign  EYE_MEM_C[7] = 64'hffffffff0000ffff;

    reg [63:0] comp_data;

    localparam IDLE                     =   7'b0000001;
    localparam WR_BANK_CH               =   7'b0000010;//BANK0~7,ROW0,COL0
    localparam RD_BANK_CH               =   7'b0000100;
    localparam WR_ROW_CH                =   7'b0001000;//BANK0,ROW0~16384,COL0
    localparam RD_ROW_CH                =   7'b0010000;
    localparam WR_COL_CH                =   7'b0100000;//BANK0,ROW0,COL0~1024
    localparam RD_COL_CH                =   7'b1000000;


    reg [6:0] c_s;
    reg [6:0] n_s;
    reg [2:0] bank;
    reg [13:0] row;
    reg [9:0] col;
	
	reg [2:0] cnt_r;
	
    reg [2:0] cnt1;
    reg [2:0] cnt2;
    reg [6:0] cnt3;

    always@(posedge clk or posedge rst)begin
        if(rst)
            c_s <= IDLE;
        else
            c_s <= n_s;
    end

   always@(*)begin
        case(c_s)
            IDLE                 :begin
                if(init_calib_complete)
                    n_s = WR_BANK_CH;
                else
                    n_s = IDLE;
            end
            WR_BANK_CH           :begin //BANK0~7,ROW0,COL0
                if((app_rdy & wr_data_rdy) & (&cnt1))
                    n_s = RD_BANK_CH;
                else
                    n_s = WR_BANK_CH;
            end 
            RD_BANK_CH           :begin
                if(app_rdy & (&cnt1))
                    n_s = WR_ROW_CH;
//                    n_s = IDLE;
                else
                    n_s = RD_BANK_CH;
            end 
            WR_ROW_CH            :begin
                if((app_rdy & wr_data_rdy) & (&cnt2))
                    n_s = RD_ROW_CH;
                else
                    n_s = WR_ROW_CH;
            end 
            RD_ROW_CH            :begin
                if(app_rdy & (&cnt2))
                    n_s = WR_COL_CH;
                else
                    n_s = RD_ROW_CH;
            end 
            WR_COL_CH            :begin
                if((app_rdy & wr_data_rdy) & (&cnt3))
                    n_s = RD_COL_CH;
                else
                    n_s = WR_COL_CH;
            end 
            RD_COL_CH            :begin
                if(app_rdy & (&cnt3))
                    n_s = IDLE;
                else
                    n_s = RD_COL_CH;
            end 
 
            default:n_s = IDLE;
        endcase
    end
	
	//assign app_en = (c_s == WR_BANK_CH | c_s == WR_ROW_CH | c_s == WR_COL_CH) ?  (app_rdy & wr_data_rdy) : 
	//				(c_s == RD_BANK_CH | c_s == RD_ROW_CH | c_s == RD_COL_CH) ? app_rdy : 1'b0;
    always@(posedge clk or posedge rst)
        if(rst)
            app_en <= 1'b0;
        else if((c_s == WR_BANK_CH | c_s == WR_ROW_CH | c_s == WR_COL_CH) & app_rdy & wr_data_rdy)
            app_en <= 1'b1;
        else if((c_s == RD_BANK_CH | c_s == RD_ROW_CH | c_s == RD_COL_CH) & app_rdy)
            app_en <= 1'b1;
        else
            app_en <= 1'b0;

	
	//assign app_cmd = (c_s == WR_BANK_CH | c_s == WR_ROW_CH | c_s == WR_COL_CH) ? 3'b000 : 3'b001;
    always@(posedge clk or posedge rst)
        if(rst)
            app_cmd <= 3'b000;
        else if(c_s == WR_BANK_CH | c_s == WR_ROW_CH | c_s == WR_COL_CH)
            app_cmd <= 3'b000;
        else
            app_cmd <= 3'b001;
	
	//assign app_wdf_wren = (c_s == WR_BANK_CH | c_s == WR_ROW_CH | c_s == WR_COL_CH) ?  (app_rdy & wr_data_rdy) : 1'b0;
    always@(posedge clk or posedge rst)
        if(rst)
            app_wdf_wren <= 1'b0;
        else if((c_s == WR_BANK_CH | c_s == WR_ROW_CH | c_s == WR_COL_CH) & app_rdy & wr_data_rdy)
            app_wdf_wren <= 1'b1;
        else
            app_wdf_wren <= 1'b0;
	assign app_wdf_end = app_wdf_wren;
	
	
	always@(posedge clk or posedge rst)begin
		if(rst)
			cnt1 <= 'd0;
		else if((c_s == WR_BANK_CH & app_rdy & wr_data_rdy) | (c_s == RD_BANK_CH & app_rdy))begin
            if(&cnt1)
                cnt1 <= 'd0;
            else
                cnt1 <= cnt1 + 1'b1;
		end
	end

	always@(posedge clk or posedge rst)begin
		if(rst)
			cnt2 <= 'd0;
		else if((c_s == WR_ROW_CH & app_rdy & wr_data_rdy) | (c_s == RD_ROW_CH & app_rdy))begin
            if(&cnt2)
                cnt2 <= 'd0;
            else
                cnt2 <= cnt2 + 1'b1;
		end
	end

    always@(posedge clk or posedge rst)begin
		if(rst)
			cnt3 <= 'd0;
		else if((c_s == WR_COL_CH & app_rdy & wr_data_rdy) | (c_s == RD_COL_CH & app_rdy))begin
            if(&cnt3)
                cnt3 <= 'd0;
            else
                cnt3 <= cnt3 + 1'b1;
		end
	end

	//assign app_addr = {1'b0,bank,row,col};
    always@(posedge clk or posedge rst)
        if(rst)
            app_addr <= 'd0;
        else
            app_addr <= {1'b0,bank,row,col};

    always@(posedge clk or posedge rst)begin
        if(rst)begin
            bank <= 3'd0;
            row <= 14'd0;
            col <= 10'd0;
        end
        else begin
            case(c_s)
            IDLE                 :begin
                bank <= 3'd0;
                row <= 14'd0;
                col <= 10'd0;
            end
            
            WR_BANK_CH           :begin //BANK0~7,ROW0,COL0
                if(app_rdy & wr_data_rdy)begin
                    if(&cnt1)
                        bank <= 'd0;
                    else 
                        bank <= bank + 1'b1;
                end
            end 
            RD_BANK_CH           :begin
                if(app_rdy)begin
                    if(&cnt1)
                        bank <= 'd0;
                    else 
                        bank <= bank + 1'b1;
                end
            end 
            
            WR_ROW_CH            :begin
                if(app_rdy & wr_data_rdy)begin
                    if(&cnt2)
                        row <= 'd0;
                    else
                        row <= row + 1'b1;
                end
            end 
            RD_ROW_CH            :begin
                if(app_rdy)begin
                    if(&cnt2)
                        row <= 'd0;
                    else
                        row <= row + 1'b1;
                end
            end 
            WR_COL_CH            :begin
                if(app_rdy & wr_data_rdy)begin
					if(&cnt3)
						col <= 'd0;
					else
						col <= col + 4'd8;
				end
            end 
            RD_COL_CH            :begin
                if(app_rdy)begin
					if(&cnt3)
						col <= 'd0;
					else
						col <= col + 4'd8;
				end
            end 
            
            default:;
            endcase
        end
    end



    always@(posedge clk or posedge rst)
        if(rst)
            app_wdf_data <= 'd0;
        else if(c_s == WR_BANK_CH)
            app_wdf_data <= {EYE_MEM[cnt1],EYE_MEM[cnt1]};
        else if(c_s == WR_ROW_CH)
            app_wdf_data <= {EYE_MEM[cnt2[2:0]],EYE_MEM[cnt2[2:0]]};
        else if(c_s == WR_COL_CH)
            app_wdf_data <= {EYE_MEM[cnt3[2:0]],EYE_MEM[cnt3[2:0]]};
        else
            app_wdf_data <= 'd0;

    always@(posedge clk or posedge rst)begin
		if(rst)
			cnt_r <= 'd0;
		else if(app_rd_data_valid_r)
			cnt_r <= cnt_r + 1'b1;
	end

    always@(posedge clk or posedge rst)begin
        if(rst)
            comp_data <= 'd0;
        else
            comp_data <= EYE_MEM_C[cnt_r];
    end

 
    generate
    genvar uei,uej;
        for(uei=0;uei<2;uei=uei+1)begin:user_err_gen
            for(uej=0;uej<4;uej=uej+1)begin
            always@(posedge clk or posedge rst)begin
                if(rst)
                    error_int1[uei*4+uej] <= 1'b0;
                else if(app_rd_data_valid_rr & app_rd_data_rr[(uei*64+uej*16)+:16] != comp_data[uej*16+:16])
                    error_int1[uei*4+uej] <= 1'b1;
            end
            end
        end
    endgenerate
	

	
	assign error = |error_int1;
//    assign error = error_int1;
endmodule










