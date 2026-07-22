//
// sdram8.v
//
// sdram controller implementation for the MiST board
// http://code.google.com/p/mist-board/
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

// adapted for TN20k internal 64mbit sdram 32 bit wide
// 2026 Stefan Voss
// 512K x32 bits, 2,048 rows x 256 columns x 32 bits  R:11 C:8
module sdram8 (

    output              sd_clk,
    output              sd_cke,
    inout  [31:0]       sd_data,
    output logic [10:0] sd_addr,
    output      [3:0]   sd_dqm,
    output logic [1:0]  sd_ba,
    output              sd_cs,
    output              sd_we,
    output              sd_ras,
    output              sd_cas,

    input               clk,
    input               reset_n,

    output              ready,

    input      [22:0]   addr,
    input      [7:0]    din,
    output     [7:0]    dout,
    output logic        dout_valid,

    input               refresh,
    input               ce,
    input               we
);

assign sd_cke = 1'b1;

localparam RASCAS_DELAY   = 3'd2;
localparam BURST_LENGTH   = 3'b000;
localparam ACCESS_TYPE    = 1'b0;
localparam CAS_LATENCY    = 3'd2;
localparam OP_MODE        = 2'b00;
localparam NO_WRITE_BURST = 1'b1;

localparam [10:0] MODE = {
    1'b0,
    NO_WRITE_BURST,
    OP_MODE,
    CAS_LATENCY,
    ACCESS_TYPE,
    BURST_LENGTH
};

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------
localparam STATE_CMD_START = 3'd0;   // state in which a new command can be started
localparam STATE_CMD_CONT  = STATE_CMD_START  + RASCAS_DELAY; // command can be continued
localparam STATE_READ      = STATE_CMD_CONT + CAS_LATENCY + 1'd1;
localparam STATE_LAST      = 3'd7;   // last state in cycle

logic [2:0] q = '0;
logic last_ce = 0, last_refresh = 0;
always_ff @(posedge clk) begin
    last_ce <= ce;
    last_refresh <= refresh;

    // start a new cycle on rising edge of ce
    if(ce && !last_ce) q <= 3'd1;
    if((q != 3'd0) || (reset != 5'd0)) q <= q + 3'd1;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------
logic [4:0] reset = 5'h1f;
always_ff @(posedge clk) begin
    if(!reset_n)
        reset <= 5'h1f;
    else if((q == STATE_LAST) && (reset != 0))
        reset <= reset - 5'd1;
end

assign ready = !(|reset);

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

logic [3:0] sd_cmd;   // current command sent to sd ram
logic        wr;
logic [3:0] dqm;

// drive control signals according to current command
assign sd_cs  = sd_cmd[3];
assign sd_ras = sd_cmd[2];
assign sd_cas = sd_cmd[1];
assign sd_we  = sd_cmd[0];
assign sd_dqm = dqm;

logic [7:0] dout_q;
logic [31:0] sd_data_out;
logic        sd_data_oe;

assign dout = dout_q;
assign sd_data = sd_data_oe ? sd_data_out : 32'hZZZZ_ZZZZ;

always_ff @(posedge clk) begin
    logic [7:0]  caddr ;
    logic [7:0]  wrdata;
    logic [1:0]  bt;

    sd_cmd <= CMD_INHIBIT;
    sd_data_oe <= 1'b0;
    dout_valid <= 1'b0;
    dqm <= 4'b0000;

    if((q == STATE_READ) && !wr) begin
        dout_valid <= 1'b1;
        case(bt)
            2'd0: dout_q <= sd_data[7:0];
            2'd1: dout_q <= sd_data[15:8];
            2'd2: dout_q <= sd_data[23:16];
            default: dout_q <= sd_data[31:24];
        endcase
    end

    if(reset != 5'd0) begin
        sd_ba <= 2'b00;
        if(q == STATE_CMD_START) begin
            if(reset == 5'd13) begin
                sd_cmd <= CMD_PRECHARGE;
                sd_addr <= 11'b10000000000;
            end
            if(reset == 5'd2) begin
                sd_cmd <= CMD_LOAD_MODE;
                sd_addr <= MODE;
            end
        end
    end
    else begin
        if(refresh && !last_refresh)
            sd_cmd <= CMD_AUTO_REFRESH;

        if(ce && !last_ce) begin
            sd_cmd  <= CMD_ACTIVE;
            sd_ba   <= addr[22:21];     // bank
            sd_addr <= addr[20:10];     // 11‑bit row address
            caddr   <= addr[9:2];       // 8-bit column address
            bt      <= addr[1:0];       // byte select
            wr      <= we;
            wrdata  <= din;
        end

        if(q == STATE_CMD_CONT) begin
            if(wr) begin
                sd_data_out <= {wrdata, wrdata, wrdata, wrdata};
                sd_data_oe  <= 1'b1;
                dqm <= (bt == 2'd0) ? 4'b1110 :
                       (bt == 2'd1) ? 4'b1101 :
                       (bt == 2'd2) ? 4'b1011 :
                                      4'b0111;
            end
            sd_cmd  <= wr ? CMD_WRITE : CMD_READ;
            sd_addr <= {3'b100, caddr};
        end

        if(q > STATE_CMD_CONT && q < STATE_READ)
            sd_cmd <= CMD_NOP;
    end
end

`ifdef VERILATOR
assign sd_clk = ~clk;
`else
ODDR #(
    .TXCLK_POL(1'b0),
    .INIT(1'b0)
    ) sdramclk_ddr (
    .Q0(sd_clk),
    .Q1(),
    .D0(1'b0),
    .D1(1'b1),
    .TX(1'b0),
    .CLK(clk)
);
`endif

endmodule
