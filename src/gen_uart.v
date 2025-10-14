//============================================================================
//
//  8-bit UART modules
//  MOS 6551/MC6850/AY-31015/TR-1602
//  Copyright (C) 2025 Gyorgy Szombathelyi
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

///////////////////////////////////////////////////////////
///////////////////////// MOS 6551 ////////////////////////
///////////////////////////////////////////////////////////

module gen_uart_mos_6551(
	input        reset,
	input        clk,
	input        clk_en,
	input  [7:0] din,
	output reg [7:0] dout,
	input        rnw,
	input        cs,
	input  [1:0] rs,
	output       irq_n,
	input        cts_n,
	input        dcd_n,
	input        dsr_n,
	output       dtr_n,
	output       rts_n,
	input        rx,
	output       tx
);

reg        sreset;
reg  [3:0] clk_div;
reg        rec_clk;
reg        irq_reset;

reg        tx_start;
reg  [2:0] parity;
reg        echo;
reg  [1:0] tx_ctrl;
reg        dtr;
reg        stop;
reg  [1:0] wordlen;
reg  [7:0] tdr;
reg        tdr_full;
wire       tx_busy;
reg        tx_irq;
wire       tx_out;

reg        rx_reset;
wire [7:0] rx_data;
wire       rx_full;
wire       rx_ovr;
wire       rx_fe;
wire       rx_pe;
reg        rx_nie;
reg        rx_irq;
wire       rx_echo;

reg        rx_full_d;

reg        ext_irq;
reg        dcdb_latch;
reg        dsrb_latch;

wire [7:0] cmd = {parity, echo, tx_ctrl, rx_nie, dtr};
wire [7:0] ctrl = {stop, wordlen, rec_clk, clk_div};
wire [7:0] status = {~irq_n, dsrb_latch, dcdb_latch, ~tdr_full, rx_full, rx_ovr, rx_fe, rx_pe};

assign     dtr_n = ~dtr;
assign     rts_n = tx_ctrl == 0;
assign     tx = echo ? rx_echo : tx_ctrl == 3 ? 1'b0 : tx_out;

always @(posedge clk) begin
	if (reset | sreset) begin
		tx_irq <= 0;
		rx_irq <= 0;
		ext_irq <= 0;
		irq_reset <= 0;
		rx_full_d <= 0;
		tx_start <= 0;
		dtr <= 0;
		rx_nie <= 1; // MOS datasheet says 1, Rockwell says 0. Apple II SSC expects 0.
		tx_ctrl <= 0;
		echo <= 0;
		tdr_full <= 0;
		if (!cs) sreset <= 0;
		rx_reset <= 0;
		if (reset) begin
			parity <= 0;
			rec_clk <= 0;
			clk_div <= 0;
			stop <= 0;
			wordlen <= 0;
		end
	end else begin
		tx_start <= 0;
		rx_reset <= 0;
		irq_reset <= 0;
		if (cs & !rnw) begin
			case (rs)
				0: begin tdr <= din; tdr_full <= 1; end
				1: sreset <= 1;
				2: {parity, echo, tx_ctrl, rx_nie, dtr} <= din;
				3: {stop, wordlen, rec_clk, clk_div} <= din;
				default: ;
			endcase
		end
		if (cs & rnw) begin
			if (rs == 0) rx_reset <= 1; // read RDR
			if (rs == 1) irq_reset <= 1; // read status
		end
		if (!cs) begin
			if (irq_reset) begin
				rx_irq <= 0;
				tx_irq <= 0;
				ext_irq <= 0;
			end
			if (tdr_full & dtr & !tx_busy & !cts_n) begin
				tx_start <= 1;
				tdr_full <= 0;
				tx_irq <= 1;
			end

			rx_full_d <= rx_full;
			if (rx_full & ~rx_full_d)
				rx_irq <= 1;

			if (!ext_irq) begin
				dcdb_latch <= dcd_n;
				dsrb_latch <= dsr_n;
				if (dcdb_latch ^ dcd_n || dsrb_latch ^ dsr_n)
					ext_irq <= 1;
			end
		end
	end
end

assign irq_n = ~(ext_irq | (tx_irq && tx_ctrl == 1) | (rx_irq & !rx_nie));

always @(*) begin
	dout = 8'hff;
	if (cs & rnw) begin
		case (rs)
			0: dout = rx_data;
			1: dout = status;
			2: dout = cmd;
			3: dout = ctrl;
			default: ;
		endcase
	end
end

wire div_en;
gen_uart_mos_6551_baud_gen baud_gen(reset, clk, clk_en, clk_div, div_en);


gen_uart_rx gen_uart_rx(
	.reset(reset | sreset),
	.reset_flags(rx_reset),
	.clk(clk),
	.clk_en(rec_clk ? div_en : clk_en),
	.clk_mult(2'd1),
	.wordlen(wordlen),
	.parity_en(parity[0]),
	.parity_ctrl(parity[2:1]),
	.rx_data(rx_data),
	.rx(rx),
	.rx_echo(rx_echo),
	.fe(rx_fe),
	.pe(rx_pe),
	.ovr(rx_ovr),
	.full(rx_full)
);

gen_uart_tx gen_uart_tx(
	.reset(reset | sreset),
	.clk(clk),
	.clk_en(div_en),
	.clk_mult(2'd1),
	.wordlen(wordlen),
	.parity_en(parity[0]),
	.parity_ctrl(parity[2:1]),
	.tx_data(tdr),
	.start(tx_start),
	.busy(tx_busy),
	.tx(tx_out)
);

endmodule

module gen_uart_mos_6551_baud_gen(
	input        reset,
	input        clk,
	input        clk_en,
	input  [3:0] clk_div,
	output       div_en
);

reg  [11:0] cnt;
reg  [11:0] cnt_val;
always @(*) begin
	case (clk_div)
	 1: cnt_val = 2303; // 50
	 2: cnt_val = 1535; // 75
	 3: cnt_val = 1047; // 109.92
	 4: cnt_val = 855;  // 134.58
	 5: cnt_val = 767;  // 150
	 6: cnt_val = 383;  // 300
	 7: cnt_val = 191;  // 600
	 8: cnt_val = 95;   // 1200
	 9: cnt_val = 63;   // 1800
	10: cnt_val = 47;   // 2400
	11: cnt_val = 31;   // 3600
	12: cnt_val = 23;   // 4800
	13: cnt_val = 15;   // 7200
	14: cnt_val = 11;   // 9600
	15: cnt_val = 5;    // 19200
	default: cnt_val = 0;
	endcase
end

assign div_en = clk_en && cnt == cnt_val;

always @(posedge clk) begin
	if (reset)
		cnt <= 0;
	else if (clk_en) begin
		cnt <= cnt + 1'd1;
		if (cnt == cnt_val) cnt <= 0;
	end
end

endmodule

///////////////////////////////////////////////////////////
////////////////////////// MC 6850 ////////////////////////
///////////////////////////////////////////////////////////

module gen_uart_mc_6850(
	input        reset,
	input        clk,
	input        rx_clk_en,
	input        tx_clk_en,
	input  [7:0] din,
	output reg [7:0] dout,
	input        rnw,
	input        cs,
	input        rs,
	output reg   irq_n,
	input        cts_n,
	input        dcd_n,
	output       rts_n,
	input        rx,
	output       tx
);

reg        sreset;
wire [7:0] status = {~irq_n, rx_pe, rx_ovr, rx_fe, cts_n, dcd_n, ~tdr_full, rx_full};

reg        wordlen;
reg        parity_en;
reg        parity_odd;
reg  [1:0] clk_mult;

reg        rx_reset;
wire [7:0] rx_data;
wire       rx_pe;
wire       rx_fe;
wire       rx_ovr;
wire       rx_full;
reg        rx_ie;

reg  [7:0] tdr;
reg        tx_start;
wire       tx_busy;
reg        tdr_full;
reg  [1:0] tx_ctrl;
wire       tx_out;

assign rts_n = tx_ctrl == 2;
assign tx = tx_ctrl == 3 ? 1'b0 : tx_out;

always @(posedge clk) begin
	if (reset | sreset) begin
		tx_start <= 0;
		tdr_full <= 0;
		rx_reset <= 0;
		if (!cs) sreset <= 0;
		if (reset) begin
			rx_ie <= 0;
			tx_ctrl <= 0;
			parity_en <= 0;
			parity_odd <= 0;
			clk_mult <= 0;
			wordlen <= 0;
		end
	end else begin
		tx_start <= 0;
		rx_reset <= 0;
		if (cs & !rnw) begin
			if (!rs)
				if (din[1:0] == 2'b11) sreset <= 1;
				else begin
					clk_mult <= din[1:0];
					parity_odd <= din[2];
					parity_en <= din[4:3] != 2'b10;
					wordlen <= ~din[4];
					tx_ctrl <= din[6:5];
					rx_ie <= din[7];
				end
			else begin
				tdr <= din;
				tdr_full <= 1;
			end
		end
		if (cs & rnw & rs)
			rx_reset <= 1; // read RDR
		if (!cs & tdr_full & !tx_busy & !cts_n) begin
			tx_start <= 1;
			tdr_full <= 0;
		end
	end
end

always @(*) begin
	dout = 8'hff;
	if (cs & rnw)
		dout = rs ? rx_data : status;
end

always @(posedge clk) begin : irq_logic
	if (reset | sreset)
		irq_n <= 1;
	else
		irq_n <= ~((tx_ctrl == 1 && !tdr_full) || (rx_ie && (rx_full | rx_ovr)));
end

gen_uart_rx gen_uart_rx(
	.reset(reset | sreset),
	.reset_flags(rx_reset),
	.clk(clk),
	.clk_en(rx_clk_en),
	.clk_mult(clk_mult),
	.wordlen({1'b0, wordlen}),
	.parity_en(parity_en),
	.parity_ctrl({1'b0, ~parity_odd}),
	.rx_data(rx_data),
	.rx(rx),
	.rx_echo(),
	.fe(rx_fe),
	.pe(rx_pe),
	.ovr(rx_ovr),
	.full(rx_full)
);

gen_uart_tx gen_uart_tx(
	.reset(reset | sreset),
	.clk(clk),
	.clk_en(tx_clk_en),
	.clk_mult(clk_mult),
	.wordlen({1'b0, wordlen}),
	.parity_en(parity_en),
	.parity_ctrl({1'b0, ~parity_odd}),
	.tx_data(tdr),
	.start(tx_start),
	.busy(tx_busy),
	.tx(tx_out)
);

endmodule

///////////////////////////////////////////////////////////
///////////////////////// AY-31015 ////////////////////////
///////////////////////////////////////////////////////////

module gen_uart_ay_31015(
	input        reset,
	input        clk,
	input        rx_clk_en,
	input        tx_clk_en,
	input  [7:0] din,
	output [7:0] dout,
	input        ds_n,
	output       eoc,
	// status
	output       pe,
	output       fe,
	output       ovr,
	output reg   tbmt,
	output       dav,
	input        rdav_n,
	// control
	input        cs,
	input        np,  // no parity
	input        tsb, // number of stop bits (not implemented)
	input  [1:0] nb,  // word length
	input        eps, // even parity select
	// uart pins
	input        rx,
	output       tx

);

reg   [1:0] wordlen;
reg         parity_en;
reg         parity_even;
reg   [7:0] tdr;

reg         tx_start;
wire        tx_busy;
assign      eoc = ~tx_busy;

always @(posedge clk) begin
	if (reset) begin
		tbmt <= 1;
		tx_start <= 0;
		parity_en <= 0;
		parity_even <= 0;
		wordlen <= 0;
	end else begin
		if (cs) {parity_en, parity_even, wordlen} <= {~np, eps, ~nb};

		tx_start <= 0;
		if (!ds_n) begin
			tdr <= din;
			tbmt <= 0;
		end
		if (ds_n & !tbmt & !tx_busy) begin
			tx_start <= 1;
			tbmt <= 1;
		end
	end
end

gen_uart_rx #(.ALT_OVR(1'b1)) gen_uart_rx(
	.reset(reset),
	.reset_flags(!rdav_n),
	.clk(clk),
	.clk_en(rx_clk_en),
	.clk_mult(2'd1),
	.wordlen(wordlen),
	.parity_en(parity_en),
	.parity_ctrl({1'b0, parity_even}),
	.rx_data(dout),
	.rx(rx),
	.rx_echo(),
	.fe(fe),
	.pe(pe),
	.ovr(ovr),
	.full(dav)
);

gen_uart_tx gen_uart_tx(
	.reset(reset),
	.clk(clk),
	.clk_en(tx_clk_en),
	.clk_mult(2'd1),
	.wordlen(wordlen),
	.parity_en(parity_en),
	.parity_ctrl({1'b0, parity_even}),
	.tx_data(tdr),
	.start(tx_start),
	.busy(tx_busy),
	.tx(tx)
);

endmodule

///////////////////////////////////////////////////////////
///////////////////////// TR-1602 /////////////////////////
///////////////////////////////////////////////////////////

module gen_uart_tr_1602(
	input        reset,
	input        clk,
	input        rx_clk_en, // bitrate x 16
	input        tx_clk_en, // bitrate x 16
	input  [7:0] din,
	output [7:0] dout,
	input        thrl,  // transmitter holding register load
	// status
	output       pe,    // parity error
	output       fe,    // framing error
	output       oe,    // overrun error
	output reg   thre,  // transmitter holding register empty
	output       tre,   // transmitter register empty
	output       dr,    // data received
	input        drr_n, // data received reset
	// control
	input        crl, // control register load
	input        pi,  // parity inhibit
	input        sbs, // stop bit select (not implemented)
	input  [1:0] wls, // word length select (5-6-7-8 bits)
	input        epe, // even parity enable
	// uart pins
	input        rx,
	output       tx

);

reg   [1:0] wordlen;
reg         parity_en;
reg         parity_even;
reg   [7:0] tdr;

reg         tx_start;
wire        tx_busy;
assign      tre = ~tx_busy;

always @(posedge clk) begin
	if (reset) begin
		thre <= 1;
		tx_start <= 0;
		parity_en <= 0;
		parity_even <= 0;
		wordlen <= 0;
	end else begin
		if (crl) {parity_en, parity_even, wordlen} <= {~pi, epe, ~wls};

		tx_start <= 0;
		if (thrl) begin
			tdr <= din;
			thre <= 0;
		end
		if (!thrl & !thre & !tx_busy) begin
			tx_start <= 1;
			thre <= 1;
		end
	end
end

gen_uart_rx #(.ALT_OVR(1'b1)) gen_uart_rx(
	.reset(reset),
	.reset_flags(!drr_n),
	.clk(clk),
	.clk_en(rx_clk_en),
	.clk_mult(2'd1),
	.wordlen(wordlen),
	.parity_en(parity_en),
	.parity_ctrl({1'b0, parity_even}),
	.rx_data(dout),
	.rx(rx),
	.rx_echo(),
	.fe(fe),
	.pe(pe),
	.ovr(oe),
	.full(dr)
);

gen_uart_tx gen_uart_tx(
	.reset(reset),
	.clk(clk),
	.clk_en(tx_clk_en),
	.clk_mult(2'd1),
	.wordlen(wordlen),
	.parity_en(parity_en),
	.parity_ctrl({1'b0, parity_even}),
	.tx_data(tdr),
	.start(tx_start),
	.busy(tx_busy),
	.tx(tx)
);

endmodule

///////////////////////////////////////////////////////////
////////////////// Generic UART receiver //////////////////
///////////////////////////////////////////////////////////

module gen_uart_rx(
	input        reset,
	input        reset_flags,
	input        clk,
	input        clk_en,
	input  [1:0] clk_mult, // 0 - 1x, 1 - 16x, 2 - 64x
	input  [1:0] wordlen, // 8,7,6,5
	input        parity_en,
	input  [1:0] parity_ctrl, // odd, even, mark, space
	output reg [7:0] rx_data,
	input        rx,
	output reg   rx_echo,
	output reg   pe,
	output reg   fe,
	output reg   ovr,
	output reg   full
);

// alternate overrun handling
// default - if overrun, don't copy the shift register to rx_data
// AY-31015 copies anyway
parameter ALT_OVR = 1'b0;

reg  [5:0] cnt;
reg  [5:0] start_pos;
reg  [7:0] shift_reg;
reg  [3:0] bit_cnt;
reg        bit_en;
reg        parity;
reg        parity_err;
reg  [7:0] rx_next;

reg  [3:0] rx_filter;
reg        rx_filtered;
wire       rx_in = |clk_mult ? rx_filtered : rx;

always @(posedge clk) begin
	if (reset) begin
		cnt <= 0;
		bit_en <= 0;
		rx_filter <= 4'b1111;
		rx_filtered <= 1;
	end else begin
		bit_en <= 0;
		if (clk_en) begin
			rx_filter <= { rx, rx_filter[3:1] };
			if ({ rx, rx_filter[3:1] }  == 4'b0000) rx_filtered = 0;
			if ({ rx, rx_filter[3:1] }  == 4'b1111) rx_filtered = 1;
			cnt <= cnt + 1'd1;
			case (clk_mult)
				1: bit_en <= cnt[3:0] == (start_pos[3:0] + 4'd7);
				2: bit_en <= cnt == (start_pos + 6'd31);
				default: bit_en <= 1;
			endcase
		end
	end
end

always @(*)
	case (wordlen)
		1: rx_next = { 1'd0, shift_reg[7:1] };
		2: rx_next = { 2'd0, shift_reg[7:2] };
		3: rx_next = { 3'd0, shift_reg[7:3] };
		default: rx_next = shift_reg[7:0];
	endcase

always @(*)
	case (parity_ctrl)
		0: parity_err = ~(^rx_next ^ parity); // odd
		1: parity_err = ^rx_next ^ parity; // even
		default: parity_err = 0;
	endcase

always @(posedge clk) begin
	if (reset) begin
		pe <= 0;
		fe <= 0;
		ovr <= 0;
		full <= 0;
		bit_cnt <= 0;
	end else begin
		if (reset_flags) begin
			fe <= 0;
			ovr <= 0;
			pe <= 0;
			full <= 0;
		end
		if (bit_en) rx_echo <= rx_in;
		if (bit_cnt == 0 && !rx_in) begin
			// start bit detected
			bit_cnt <= 4'd10 - wordlen + parity_en;
			start_pos <= cnt; // mark the position for middle sampling
		end
		if (bit_en && bit_cnt != 0) begin
			bit_cnt <= bit_cnt - 1'd1;
			shift_reg <= { rx_in, shift_reg[7:1] };
			if (bit_cnt == 2) begin
				parity <= rx_in;
				if (parity_en) shift_reg <= shift_reg; // don't shift in parity bit
			end
			if (bit_cnt == 1) begin
				full <= 1;
				if (!rx_in) // check for valid stop bit
					fe <= 1;
				if (ALT_OVR) begin
					if (full) ovr <= 1;
					rx_data <= rx_next;
					pe <= parity_err & parity_en;
				end else begin
					if (full)
						// If the previous word wasn't read by the CPU, signal overrun,
						// and don't copy the shift register to the receive data register.
						ovr <= 1;
					else begin
						rx_data <= rx_next;
						pe <= parity_err & parity_en;
					end
				end
			end
		end
	end
end

endmodule

///////////////////////////////////////////////////////////
//////////////// Generic UART transmitter /////////////////
///////////////////////////////////////////////////////////

module gen_uart_tx(
	input        reset,
	input        clk,
	input        clk_en,
	input  [1:0] clk_mult, // 0 - 1x, 1 - 16x, 2 - 64x
	input  [1:0] wordlen, // 8,7,6,5
	input        parity_en,
	input  [1:0] parity_ctrl, // odd, even, mark, space
	input  [7:0] tx_data,
	input        start,
	output       busy,
	output       tx
);

reg  [5:0] cnt;
reg [11:0] shift_reg;
reg  [3:0] bit_cnt;
reg        bit_en;
reg        parity;

always @(*) begin
	if (!parity_en)
		parity = 1;
	else case (parity_ctrl)
		0: parity = ~^tx_data; // odd
		1: parity = ^tx_data; // even
		2: parity = 1; // mark
		default: parity = 0; // space
	endcase
end

always @(posedge clk) begin
	if (reset) begin
		cnt <= 0;
		bit_en <= 0;
	end else begin
		bit_en <= 0;
		if (clk_en) begin
			cnt <= cnt + 1'd1;
			case (clk_mult)
				0: bit_en <= 1;
				1: bit_en <= cnt[3:0] == 0;
				default: bit_en <= cnt == 0;
			endcase
		end
	end
end

assign busy = bit_cnt != 0;
assign tx = shift_reg[0];

always @(posedge clk) begin
	reg start_d;

	if (reset) begin
		bit_cnt <= 0;
		start_d <= 0;
		shift_reg[0] <= 1;
	end else begin
		start_d <= start;
		if (start & ~start_d) begin
			bit_cnt <= 4'd11 - wordlen + parity_en;
			shift_reg <= { 1'b1, parity, tx_data, 1'b0, 1'b1 };
			case (wordlen)
				1: shift_reg[10:9] <= {1'b1, parity};
				2: shift_reg[10:8] <= {2'b11, parity};
				3: shift_reg[10:7] <= {3'b111, parity};
				default: ;
			endcase
		end
		if (bit_en && bit_cnt != 0) begin
			bit_cnt <= bit_cnt - 1'd1;
			shift_reg <= { 1'b1, shift_reg[10:1] };
		end
	end
end

endmodule
