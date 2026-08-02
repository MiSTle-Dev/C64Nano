module top(
     clk,  
     error,
     error1,
     init_calib_complete_o,
     led,
     ddr_addr,
     ddr_bank,
     ddr_cs,
     ddr_ras,
     ddr_cas,
     ddr_we,
     ddr_ck,
     ddr_ck_n,
     ddr_cke,
     ddr_odt,
     ddr_reset_n,
     ddr_dm,
     ddr_dq,
     ddr_dqs,
     ddr_dqs_n
);

    input                       clk;  
    output                      error;
    output                      error1;
    output                      init_calib_complete_o;
    output reg                  led;
    output [14-1:0]             ddr_addr;       //ROW_WIDTH=14
    output [3-1:0]              ddr_bank;       //BANK_WIDTH=3
    output                      ddr_cs;
    output                      ddr_ras;
    output                      ddr_cas;
    output                      ddr_we;
    output                      ddr_ck;
    output                      ddr_ck_n;
    output                      ddr_cke;
    output                      ddr_odt;
    output                      ddr_reset_n;
    output [2-1:0]              ddr_dm;         //DM_WIDTH=2
    inout  [16-1:0]             ddr_dq;         //DQ_WIDTH=16
    inout  [2-1:0]              ddr_dqs;        //DQS_WIDTH=2
    inout  [2-1:0]              ddr_dqs_n;      //DQS_WIDTH=2




	wire						init_calib_complete;
    wire                        app_wdf_wren;
    wire  [16-1:0]              app_wdf_mask;    //APP_MASK_WIDTH=16
    wire                        app_wdf_end; 
    wire [128-1:0]              app_wdf_data;    //APP_DATA_WIDTH=128
    wire                        app_en;
    wire [2:0]                  app_cmd;
    wire [28-1:0]               app_addr;        //ADDR_WIDTH=28
    wire                        app_sre_req;
    wire                        app_ref_req;
    wire                        app_burst;
    wire                        app_sre_act;
    wire                        app_ref_ack;
    wire                        app_wdf_rdy;
    wire                        app_rdy;
    wire                        app_rd_data_valid; 
    wire                        app_rd_data_end;
    wire [128-1:0]              app_rd_data;     //APP_DATA_WIDTH=128

wire rst_n;
wire pll_lock;
wire clk_x4;
wire err;

assign init_calib_complete_o = ~init_calib_complete;

assign error = ~err;
assign error1 = err;

reg [31:0] led_cnt;

always@(posedge clk_x1 or negedge pll_lock)begin
    if(!pll_lock)
        led <= 1'b0;
    else if(init_calib_complete)begin
        if(led_cnt == 100000000)
            led <= ~led;
    end
    else
        led <= 1'b0;
end
always@(posedge clk_x1 or negedge pll_lock)begin
    if(!pll_lock)
        led_cnt <= 'd0;
    else if(init_calib_complete)begin
        if(led_cnt == 100000000)
            led_cnt <= 'd0;
        else
            led_cnt <= led_cnt + 1'b1;
    end
    else
        led_cnt <= 'd0;
end

Gowin_rPLL upll(
        .clkout(clk_x4), //output clkout
        .lock(pll_lock), //output lock
        .clkin(clk) //input clkin
    );



ddr3_test1  #
    (
     .ADDR_WIDTH(28) ,          //ADDR_WIDTH=28
     .APP_DATA_WIDTH(128) ,     //APP_DATA_WIDTH=128
     .APP_MASK_WIDTH (16),      //APP_MASK_WIDTH=16
     .USER_REFRESH("OFF")
    )u_rd(
    .clk                (clk_x1),
    .rst                (~pll_lock),  
    .app_rdy            (app_rdy),
    .app_en             (app_en),
    .app_cmd            (app_cmd),
    .app_addr           (app_addr),
    .app_wdf_data       (app_wdf_data),
    .app_wdf_wren       (app_wdf_wren),
    .app_wdf_end        (app_wdf_end),
    .app_wdf_mask       (app_wdf_mask),
    .app_burst          (app_burst),
    .app_rd_data_valid  (app_rd_data_valid),
    .app_rd_data        (app_rd_data), 
    .init_calib_complete(init_calib_complete),
    .wr_data_rdy        (app_wdf_rdy),
    .sr_req             (sr_req),
    .error              (err),
    .ref_req            (ref_req)
    );

DDR3_Memory_Interface_Top u_ddr3 (
    .memory_clk      (clk_x4),
    .clk             (clk),
    .rst_n           (pll_lock),   //rst_n
    .cmd_ready       (app_rdy),
    .cmd             (app_cmd),
    .cmd_en          (app_en),
    .addr            (app_addr),
    .wr_data_rdy     (app_wdf_rdy),
    .wr_data         (app_wdf_data),
    .wr_data_en      (app_wdf_wren),
    .wr_data_end     (app_wdf_end),
    .wr_data_mask    (app_wdf_mask),
    .rd_data         (app_rd_data),
    .rd_data_valid   (app_rd_data_valid),
    .rd_data_end     (app_rd_data_end),
    .sr_req          (0),
    .ref_req         (0),
    .sr_ack          (app_sre_act),
    .ref_ack         (app_ref_ack),
    .init_calib_complete(init_calib_complete),
    .clk_out         (clk_x1),
    .pll_lock        (pll_lock), 
    //`ifdef ECC
    //.ecc_err         (ecc_err),
    //`endif
    .burst           (app_burst),
    // mem interface
    .ddr_rst         (ddr_rst),
    .O_ddr_addr      (ddr_addr),
    .O_ddr_ba        (ddr_bank),
    .O_ddr_cs_n      (ddr_cs),
    .O_ddr_ras_n     (ddr_ras),
    .O_ddr_cas_n     (ddr_cas),
    .O_ddr_we_n      (ddr_we),
    .O_ddr_clk       (ddr_ck),
    .O_ddr_clk_n     (ddr_ck_n),
    .O_ddr_cke       (ddr_cke),
    .O_ddr_odt       (ddr_odt),
    .O_ddr_reset_n   (ddr_reset_n),
    .O_ddr_dqm       (ddr_dm),
    .IO_ddr_dq       (ddr_dq),
    .IO_ddr_dqs      (ddr_dqs),
    .IO_ddr_dqs_n    (ddr_dqs_n)
);


endmodule