// 
// sd_card.v
//
// Copyright (c) 2016 Sorgelig
// G64 parsing (c) 2022 Slingshot
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the Lesser GNU General Public License as published
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
//
/////////////////////////////////////////////////////////////////////////

module mist_sd_card
(
	input         clk,
	input         reset,

	output [31:0] sd_lba,
	output reg    sd_rd,
	output reg    sd_wr,
	input         sd_ack,

	input   [8:0] sd_buff_addr,
	input   [7:0] sd_buff_dout,
	output  [7:0] sd_buff_din,
	input         sd_buff_wr,

	input         save_track,
	input         change,
	input         mount,
	input         g64,
	input   [6:0] track,

	input  [12:0] ram_addr,
	input   [7:0] ram_di,
	output  [7:0] ram_do,
	input         ram_we,

	output reg  [7:0] id1,
	output reg  [7:0] id2,
	output reg  [1:0] freq,
	output reg [15:0] raw_track_len,
	output reg  [6:0] max_track,
	output reg    raw,
	output reg    busy
);

wire [9:0] start_sectors[42] =
		'{  0,  0, 21, 42, 63, 84,105,126,147,168,189,210,231,252,273,294,315,336,357,376,395,
		  414,433,452,471,490,508,526,544,562,580,598,615,632,649,666,683,700,717,734,751,768};

reg  [23:0] g64_offsets[88];
reg  [23:0] g64_offsets_din;
wire  [6:0] g64_offs_idx = sd_buff_addr[8:2] - 1'd1;
reg   [6:0] g64_track_idx;
reg  [23:0] g64_offsets_dout;
always @(negedge clk) g64_offsets_dout <= g64_offsets[g64_track_idx];
reg         g64_rd, g64_wr;
reg   [7:0] g64_tlen_lo;

reg   [1:0] freq_table[88];

reg  [31:0] lba;
assign sd_lba = lba;

reg   [4:0] rel_lba;
reg   [4:0] track_lbas;

reg         new_disk;
wire  [6:0] new_track = new_disk ? raw ? 7'b1111111 : {6'h12, 1'b0} : track;

reg   [8:0] sector_offset;

reg [6:0] cur_track = 0;
reg ready = 0;
reg saving = 0;
reg old_ack;
reg old_change;

always @(posedge clk) begin

	old_ack <= sd_ack;
	if(sd_ack) {sd_rd,sd_wr} <= 0;

	old_change <= change;
	if(~old_change & change) begin
		ready <= mount;
		saving <= 0;
		busy <= 0;
		id1 <= 8'h20;
		id2 <= 8'h20;
		new_disk <= mount;
		raw <= g64;
		if(!g64) max_track <= 7'd80;
		{g64_rd, g64_wr} <= 0;
	end
	else
	if(reset) begin
		cur_track <= 'b1111111;
		busy  <= 0;
		sd_rd <= 0;
		sd_wr <= 0;
		saving<= 0;
		id1   <= 8'h20;
		id2   <= 8'h20;
		new_disk <= 0;
		{g64_rd, g64_wr} <= 0;
	end
	else
	if(g64_rd) begin
		g64_rd <= 0;
		if (g64_offsets_dout != 0) begin
			sector_offset <= g64_offsets_dout[8:0];
			lba <= g64_offsets_dout[23:9];
			track_lbas <= 5'd1; // will read later
			sd_rd <= 1;
			busy <= 1;
		end
		else
			raw_track_len <= 0;
	end
	else
	if(g64_wr) begin
		g64_wr <= 0;
		if(g64_offsets_dout != 0) begin
			// sector offset and length is already determined in the read phase
			// rewind lba to the start of the track
			lba <= g64_offsets_dout[23:9];
			saving <= 1;
			sd_wr <= 1;
			busy <= 1;
		end
	end
	else
	if(busy) begin
		// BAM offset A2 and A3 -> header ID1,ID2
		if(!raw && cur_track == {5'h12, 1'b0} && rel_lba == 0 && !saving && sd_buff_wr) begin
			if (sd_buff_addr == 9'h1a2) id1 <= sd_buff_dout;
			else if (sd_buff_addr == 9'h1a3) id2 <= sd_buff_dout;
		end

		// scan G64 track offsets
		if(raw && cur_track == 'b1111111 && !saving && sd_buff_wr) begin
			if ({rel_lba, sd_buff_addr} == 14'h9) max_track <= sd_buff_dout[6:0];
			// track offsets
			if ({rel_lba, sd_buff_addr} >= 14'hc && {rel_lba, sd_buff_addr} <= 14'h15b)
			case (sd_buff_addr[1:0])
				2'b00: g64_offsets_din[ 7: 0] <= sd_buff_dout;
				2'b01: g64_offsets_din[15: 8] <= sd_buff_dout;
				2'b10: g64_offsets_din[23:16] <= sd_buff_dout;
				2'b11: g64_offsets[g64_offs_idx] <= g64_offsets_din;
				default: ;
			endcase
			// speed zones
			if ({rel_lba, sd_buff_addr} >= 14'h15c && {rel_lba, sd_buff_addr} <= 14'h2ab && sd_buff_addr[1:0] == 0)
				freq_table[{rel_lba, sd_buff_addr[8:2]} - 12'h055] <= sd_buff_dout[1:0];
		end
		// G64 track length
		if(raw && cur_track != 'b1111111 && !saving && sd_buff_wr) begin
			if ({rel_lba, sd_buff_addr} == sector_offset) g64_tlen_lo[7:0] <= sd_buff_dout;
			if ({rel_lba, sd_buff_addr} == sector_offset + 1'd1) begin
				raw_track_len <= {sd_buff_dout, g64_tlen_lo};
				track_lbas <= (sector_offset + 2'd2 + {sd_buff_dout, g64_tlen_lo} + 9'd511) >> 4'd9;
			end
		end

		if(old_ack && ~sd_ack) begin
			if(track_lbas != 0 && rel_lba != track_lbas - 1'd1) begin
				lba <= lba + 1'd1;
				rel_lba <= rel_lba + 1'd1;
				if(saving) sd_wr <= 1;
					else sd_rd <= 1;
			end
			else
			if(saving && ((cur_track[6:1] != track[6:1]) || (raw && cur_track[0] != track[0]))) begin
				saving <= 0;
				cur_track <= track;
				rel_lba <= 0;
				if (raw) begin
					g64_track_idx <= track;
					g64_rd <= 1;
				end
				else begin
					sector_offset <= { start_sectors[track[6:1]][0], 8'd0 } ;
					lba <= start_sectors[track[6:1]][9:1];
					track_lbas <= (start_sectors[track[6:1]+1'd1] - start_sectors[track[6:1]] + 1'd1) >> 1'd1;
					sd_rd <= 1;
				end
			end
			else
			begin
				freq <= freq_table[cur_track];
				busy <= 0;
			end
		end
	end
	else
	if(ready) begin
		if(save_track && cur_track != 'b1111111) begin
			rel_lba <= 0;
			if (raw) begin
				g64_track_idx <= cur_track;
				g64_wr <= 1;
			end
			else begin
				saving <= 1;
				lba <= start_sectors[cur_track[6:1]][9:1];
				sd_wr <= 1;
				busy <= 1;
			end
		end
		else
		if((cur_track[6:1] != track[6:1]) || (raw && cur_track[0] != track[0]) || new_disk) begin
			saving <= 0;
			new_disk <= 0;
			rel_lba <= 0;
			cur_track <= new_track;
			if (raw) begin
				// G64 support
				if (new_disk) begin
					lba <= 0; // read header
					track_lbas <= 5'd2;
					sd_rd <= 1;
					busy <= 1;
				end
				else begin
					g64_track_idx <= new_track;
					g64_rd <= 1;
				end
			end
			else begin
				sector_offset <= { start_sectors[new_track[6:1]][0], 8'd0 } ;
				lba <= start_sectors[new_track[6:1]][9:1];
				track_lbas <= 5'((start_sectors[new_track[6:1]+1'd1] - start_sectors[new_track[6:1]] + 1'd1) >> 1'd1);
				sd_rd <= 1;
				busy <= 1;
			end
		end
	end
end

// track buffer for maximum of 8192+512 bytes storage

// track buffer - IO controller side
wire [13:0] sd_ram_addr = { rel_lba, sd_buff_addr };
wire [7:0] track_buffer_do_sd;
wire [7:0] track_buffer_b_do_sd;

// track buffer - GCR floppy side
wire [13:0] fd_ram_addr = ram_addr + sector_offset;
wire   [7:0] track_buffer_do_fd;
wire   [7:0] track_buffer_b_do_fd;

Gowin_DPB_trkbuf trkbuf_inst(
	.douta(track_buffer_do_sd), 
	.doutb(track_buffer_do_fd), 
	.clka(clk), 
	.ocea(1'b1), 
	.cea(1'b1), 
	.reseta(1'b0), 
	.wrea(sd_buff_wr & !sd_ram_addr[13]), 
	.clkb(clk), 
	.oceb(1'b1), 
	.ceb(1'b1), 
	.resetb(1'b0), 
	.wreb(ram_we & !fd_ram_addr[13]), 
	.ada(sd_ram_addr[12:0]),
	.dina(sd_buff_dout), 
	.adb(fd_ram_addr[12:0]), 
	.dinb(ram_di)
);

Gowin_DPB_track_buffer_b trkbuf_inst_b(
	.douta(track_buffer_b_do_sd), 
	.doutb(track_buffer_b_do_fd), 
	.clka(clk), 
	.ocea(1'b1), 
	.cea(1'b1), 
	.reseta(1'b0), 
	.wrea(sd_buff_wr & sd_ram_addr[13]), 
	.clkb(clk), 
	.oceb(1'b1), 
	.ceb(1'b1), 
	.resetb(1'b0), 
	.wreb(ram_we & fd_ram_addr[13]), 
	.ada(sd_ram_addr[8:0]),
	.dina(sd_buff_dout), 
	.adb(fd_ram_addr[8:0]), 
	.dinb(ram_di)
);

assign ram_do = fd_ram_addr[13] ? track_buffer_b_do_fd : track_buffer_do_fd;
assign sd_buff_din = sd_ram_addr[13] ? track_buffer_b_do_sd : track_buffer_do_sd;

endmodule
