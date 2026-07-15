// 
// loader_sd_card.sv
//
// 2024...26 Stefan Voss
//
module loader_sd_card
(
	input  logic        clk,
	input  logic        reset,

	output logic [31:0] sd_lba,
	output logic [7:0]  sd_rd, // read request for target
	output logic [7:0]  sd_wr, // write request for target
	input  logic        sd_busy, // SD is busy (has accepted read or write request)

	input  logic [8:0]  sd_byte_index, // address of data byte within 512 bytes sector
	input  logic [7:0]  sd_rd_data, // data byte received from SD card
	input  logic        sd_rd_byte_strobe, // SD has read a byte to be stored in  buffer
	input  logic        sd_done, // SD is done (data has been read or written
	output logic [7:0]  sd_wr_data,
	input  logic [31:0] c1541_lba,
	input  logic        c1541_sd_rd,
	input  logic        c1541_sd_wr,
	input  logic [7:0]  c1541_sd_wr_data,

	input  logic [7:0]  sd_img_mounted,
	input  logic [31:0] sd_img_size,
	output logic        load_crt,
	output logic        load_prg,
	output logic        load_rom,
	output logic        load_tap,
	output logic        load_flt,
	output logic        load_reu,
	output logic        loader_busy,

	input logic [6:0]   lobanks[0:63],
	input logic [6:0]   hibanks[0:63],
	input logic [63:0]  lobanks_map,
	input logic [63:0]  hibanks_map,
	input logic [7:0]   bank_cnt,

	output logic        ioctl_download,
	input  logic        ioctl_upload_req,
	output logic        ioctl_upload,
	input  logic [7:0]  ioctl_din,
	output logic [24:0] ioctl_addr,
	output logic [7:0]  ioctl_dout,
	output logic        ioctl_wr,
	output logic        ioctl_rd,
	input  logic        ioctl_wait
);

typedef enum logic [3:0] {
	GO4IT,
	WAIT4CORE,
	READ_WAIT4SD,
	READING,
	READ_NEXT,
	DESELECT,
	START,
	WRITE_PREPARE,
	WRITE_WAIT4CORE,
	WRITING,
	WRITE_FLUSH,
	WRITE_START_SD,
	WRITE_WAIT4SD
} io_state_t;

typedef enum logic [1:0] {
	UP_GLOBAL_HDR,
	UP_CHIP_HDR,
	UP_CHIP_DATA,
	UP_DONE
} upload_state_t;

logic load_ezflash;
logic [2:0] img_select;
io_state_t io_state;
logic [24:0] addr;
logic wr;
logic [8:0] cnt;
logic [1:0] core_wait_cnt;
logic [24:0] img_size [0:7];
logic img_present [0:7];
logic img_presentD [0:7];
logic [6:0] rd_sel;
logic [7:0] boot_flags;  // bit[1]=crt, [2]=prg, [3]=bin, [4]=tap, [5]=flt, [6]=reu, [7]=ezflash
logic old_upload_req;
logic upload_req;
logic write_strobe;
logic [7:0] upload_data;
logic [8:0] buf_addr;
upload_state_t upload_state;
logic [5:0] upload_hdr_idx;
logic [3:0] upload_chip_hdr_idx;
logic [12:0] upload_chip_data_idx;
logic [6:0] upload_chip_bank;
logic       upload_chip_hi;
logic [8:0] chip_sel;

logic [31:0] loader_sd_lba;
logic [6:0]  loader_sd_rd;
logic [6:0]  loader_sd_wr;
logic [7:0]  loader_sd_wr_data;

assign sd_lba     = loader_busy ? loader_sd_lba     : c1541_lba;
assign sd_wr_data = loader_busy ? loader_sd_wr_data : c1541_sd_wr_data;
assign sd_rd      = loader_busy ? {loader_sd_rd, 1'b0} : {7'b0000000, c1541_sd_rd};
assign sd_wr      = loader_busy ? {loader_sd_wr, 1'b0} : {7'b0000000, c1541_sd_wr};

// CRT header ROM - 64 bytes of static configuration data
logic [7:0] CRT_HEADER[0:63] = '{
	8'h43, 8'h36, 8'h34, 8'h20, 8'h43, 8'h41, 8'h52, 8'h54,  // "C64 CART"
	8'h52, 8'h49, 8'h44, 8'h47, 8'h45, 8'h20, 8'h20, 8'h20,  // "RIDGE   "
	8'h00, 8'h00, 8'h00, 8'h40, 8'h01, 8'h00, 8'h00, 8'h20,  // header size, EasyFlash type
	8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,  // EXROM, flags
	8'h45, 8'h61, 8'h73, 8'h79, 8'h46, 8'h6c, 8'h61, 8'h73,  // "EasyFlas"
	8'h68, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,  // "h" + padding
	8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,  // padding
	8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00   // padding
};

function automatic logic [7:0] crt_header_byte(input logic [5:0] idx);
	return CRT_HEADER[idx];
endfunction

// CHIP header base ROM - indices 0-10 static, 11-12 computed with bank/address
logic [7:0] CHIP_HEADER_BASE[0:15] = '{
	8'h43, 8'h48, 8'h49, 8'h50,              // "CHIP"
	8'h00, 8'h00, 8'h20, 8'h10,              // header size (0x20), total size (0x10 = 16-byte header + 8KB)
	8'h00, 8'h02, 8'h00, 8'h00,              // reserved, chip type (0x02 = ROM)
	8'h00, 8'h00, 8'h20, 8'h00               // reserved, reserved
};

function automatic logic [7:0] chip_header_byte(input logic [3:0] idx, input logic [6:0] bank, input logic hi);
	case(idx)
		4'd11: return {1'b0, bank};
		4'd12: return hi ? 8'hA0 : 8'h80;
		default: return CHIP_HEADER_BASE[idx];
	endcase
endfunction

function automatic logic [8:0] find_chip_from(input logic [6:0] start_bank, input logic start_hi);
	int unsigned b;
	int unsigned start_u;
	begin : find_loop
		find_chip_from = '0;
		start_u = {25'd0, start_bank};
		for(b = 0; b < 64; b = b + 1) begin
			if(b >= start_u) begin
				if(b == start_u) begin
					if(!start_hi && lobanks_map[b[5:0]]) begin
						find_chip_from = {1'b1, b[6:0], 1'b0};
						disable find_loop;
					end
					if(hibanks_map[b[5:0]]) begin
						find_chip_from = {1'b1, b[6:0], 1'b1};
						disable find_loop;
					end
				end
				else begin
					if(lobanks_map[b[5:0]]) begin
						find_chip_from = {1'b1, b[6:0], 1'b0};
						disable find_loop;
					end
					if(hibanks_map[b[5:0]]) begin
						find_chip_from = {1'b1, b[6:0], 1'b1};
						disable find_loop;
					end
				end
			end
		end
	end
endfunction

integer i;

always_ff @(posedge clk) begin

	for(i = 0; i < 8; i = i + 1)
	begin
		img_presentD[i] <= img_present[i];

		if (sd_img_mounted[i]) 
		begin
			img_present[i] <= |sd_img_size;
			img_size[i] <= sd_img_size[24:0];
		end 
	end

	ioctl_rd <= 0;
	ioctl_wr <= wr;
	wr <= 0;
	write_strobe <= 0;

	if(sd_busy) begin
		loader_sd_rd <= '0;
		loader_sd_wr <= '0;
	end

	old_upload_req <= ioctl_upload_req;

	if(reset)
	begin
		upload_req <= 0;
		ioctl_upload <= 0;
		ioctl_rd <= 0;
		write_strobe <= 0;
		loader_sd_rd <= '0;
		loader_sd_wr <= '0;
		loader_sd_lba <= '0;
		wr <= 0;
		load_crt <= 0;
		load_prg <= 0;
		load_rom <= 0;
		load_tap <= 0;
		load_flt <= 0;
		load_reu <= 0;
		load_ezflash <= 0;
		ioctl_download <= 0;
		ioctl_addr <= '0;
		addr <= '0;
		upload_data <= '0;
		buf_addr <= '0;
		upload_state <= UP_GLOBAL_HDR;
		upload_hdr_idx <= '0;
		upload_chip_hdr_idx <= '0;
		upload_chip_data_idx <= '0;
		upload_chip_bank <= '0;
		upload_chip_hi <= 0;
		loader_busy <= 0;
		boot_flags <= '0;
		rd_sel <= '0;
		img_select <= '0;
		cnt <= '0;
		core_wait_cnt <= '0;
		io_state <= START;
	end
	else
	begin

	if(~old_upload_req & ioctl_upload_req)
		upload_req <= 1;

	case(io_state)
		WRITE_PREPARE: begin
			if(upload_state == UP_DONE) begin
				if(cnt != '0) begin
					upload_data <= 8'hFF;
					io_state <= WRITING;
				end
				else begin
					ioctl_upload <= 0;
					io_state <= START;
				end
			end
			else if(upload_state == UP_GLOBAL_HDR) begin
				upload_data <= crt_header_byte(upload_hdr_idx);
				io_state <= WRITING;
			end
			else if(upload_state == UP_CHIP_HDR) begin
				upload_data <= chip_header_byte(upload_chip_hdr_idx, upload_chip_bank, upload_chip_hi);
				io_state <= WRITING;
			end
			else begin
				if((upload_chip_hi && !hibanks_map[upload_chip_bank]) || (!upload_chip_hi && !lobanks_map[upload_chip_bank])) begin
					upload_data <= 8'hFF;
					io_state <= WRITING;
				end
				else begin
					ioctl_addr <= {5'd0, (upload_chip_hi ? hibanks[upload_chip_bank] : lobanks[upload_chip_bank]), upload_chip_data_idx};
					ioctl_rd <= 1;
					core_wait_cnt <= '0;
					io_state <= WRITE_WAIT4CORE;
				end
			end
		end

		WRITE_WAIT4CORE: begin
				if(~ioctl_wait) begin
					core_wait_cnt <= core_wait_cnt + 1;
					if(&core_wait_cnt) begin
						upload_data <= ioctl_din;
						io_state <= WRITING;
					end
				end
				else begin
					core_wait_cnt <= '0;
				end
			end

		WRITING: begin
			write_strobe <= 1;
			buf_addr <= cnt;
			addr <= addr + 1;
			cnt <= cnt + 1;

			if(upload_state == UP_GLOBAL_HDR) begin
				if(upload_hdr_idx == 6'd63) begin
					chip_sel = find_chip_from('0, 1'b0);
					if(chip_sel[8]) begin
						upload_chip_bank <= chip_sel[7:1];
						upload_chip_hi <= chip_sel[0];
						upload_chip_hdr_idx <= '0;
						upload_chip_data_idx <= '0;
						upload_state <= UP_CHIP_HDR;
					end
					else begin
						upload_chip_bank <= '0;
						upload_chip_hi <= 1'b0;
						upload_chip_hdr_idx <= '0;
						upload_chip_data_idx <= '0;
						upload_state <= UP_CHIP_HDR;
					end
				end
				else begin
					upload_hdr_idx <= upload_hdr_idx + 1'd1;
				end
			end
			else if(upload_state == UP_CHIP_HDR) begin
				if(upload_chip_hdr_idx == 4'd15) begin
					upload_chip_data_idx <= '0;
					upload_state <= UP_CHIP_DATA;
				end
				else begin
					upload_chip_hdr_idx <= upload_chip_hdr_idx + 1'd1;
				end
			end
			else if(upload_state == UP_CHIP_DATA) begin
				if(upload_chip_data_idx == 13'd8191) begin
					if(upload_chip_hi && upload_chip_bank == 7'd63) begin
						upload_state <= UP_DONE;
					end
					else begin
						chip_sel = find_chip_from(upload_chip_hi ? (upload_chip_bank + 1'd1) : upload_chip_bank, upload_chip_hi ? 1'b0 : 1'b1);
						if(chip_sel[8]) begin
							upload_chip_bank <= chip_sel[7:1];
							upload_chip_hi <= chip_sel[0];
							upload_chip_hdr_idx <= '0;
							upload_chip_data_idx <= '0;
							upload_state <= UP_CHIP_HDR;
						end
						else begin
							if(upload_chip_hi) begin
								if(upload_chip_bank == 7'd63) begin
									upload_state <= UP_DONE;
								end
								else begin
									upload_chip_bank <= upload_chip_bank + 1'd1;
									upload_chip_hi <= 1'b0;
									upload_chip_hdr_idx <= '0;
									upload_chip_data_idx <= '0;
									upload_state <= UP_CHIP_HDR;
								end
							end
							else begin
								upload_chip_hi <= 1'b1;
								upload_chip_hdr_idx <= '0;
								upload_chip_data_idx <= '0;
								upload_state <= UP_CHIP_HDR;
							end
						end
					end
				end
				else begin
					upload_chip_data_idx <= upload_chip_data_idx + 1'd1;
				end
			end

			if(cnt == 511) io_state <= WRITE_FLUSH;
			else io_state <= WRITE_PREPARE;
		end

		WRITE_FLUSH: begin
			loader_sd_wr <= 7'b1000000; // request write to sd card, EZFLASH index
			io_state <= WRITE_START_SD;
		end

		WRITE_START_SD: begin
		   // wait for SD card to ack the request by becoming busy
		   if(sd_busy) begin
			  io_state <= WRITE_WAIT4SD;
		   end
		end

		WRITE_WAIT4SD: begin
			if(sd_done) begin
				if(upload_state == UP_DONE) begin
					ioctl_upload <= 0;
					io_state <= START;
					loader_busy <= 0;
				end
				else begin
					io_state <= WRITE_PREPARE;
					cnt <= '0;
					loader_sd_lba <= loader_sd_lba + 1;
				end
			end
		end

		START:
			begin // 0 c1541 1 CRT 2 PRG 3 BIN 4 TAP 5 FLT 6 REU 7 EZFLASH SAVE
				if((|img_size[7]) && upload_req && (|bank_cnt || |lobanks_map || |hibanks_map)) begin //
						upload_req <= 0;
						loader_busy <= 1;
						io_state <= WRITE_PREPARE;
						ioctl_addr <= '0;
						ioctl_upload <= 1;
						addr <= '0;
						buf_addr <= '0;
						loader_sd_lba <= '0;
						core_wait_cnt <= '0;
						cnt <= '0;
						upload_state <= UP_GLOBAL_HDR;
						upload_hdr_idx <= '0;
						upload_chip_hdr_idx <= '0;
						upload_chip_data_idx <= '0;
						upload_chip_bank <= '0;
						upload_chip_hi <= 0;
					end
			else if((|img_size[3]) && ((img_present[3] && ~img_presentD[3]) || (img_present[3] && ~boot_flags[3]))) begin
					img_select <= 3;
					io_state <= GO4IT;
					rd_sel <= 7'b0000100;
					boot_flags[3] <= 1;
					end
			else if((|img_size[1]) && ((img_present[1] && ~img_presentD[1]) || (img_present[1] && ~boot_flags[1]))) begin
					img_select <= 1; 
					io_state <= GO4IT; 
					rd_sel <= 7'b0000001;
					boot_flags[1] <= 1;
					end
			else if((|img_size[2]) && ((img_present[2] && ~img_presentD[2]) || (img_present[2] && ~boot_flags[2]))) begin 
					img_select <= 2;
					io_state <= GO4IT;
					rd_sel <= 7'b0000010;
					boot_flags[2] <= 1;
					end
			else if((|img_size[5]) && ((img_present[5] && ~img_presentD[5]) || (img_present[5] && ~boot_flags[5]))) begin
					img_select <= 5;
					io_state <= GO4IT;
					rd_sel <= 7'b0010000;
					boot_flags[5] <= 1;
					end
				else if((|img_size[4]) && img_present[4] && ~img_presentD[4]) begin
						img_select <= 4;
						io_state <= GO4IT;
						rd_sel <= 7'b0001000;
					boot_flags[4] <= 1;
					end
			else if((|img_size[6]) && ((img_present[6] && ~img_presentD[6]) || (img_present[6] && ~boot_flags[6]))) begin
					img_select <= 6;
					io_state <= GO4IT;
					rd_sel <= 7'b0100000;
					boot_flags[6] <= 1;
					end
			else if((|img_size[7]) && ((img_present[7] && ~img_presentD[7]) || (img_present[7] && ~boot_flags[7]))) begin // EZFLASH file select
					boot_flags[7] <= 1;
					end
				//else if((|img_size[0]) && img_present[0] && ~img_presentD[0]) begin // C1541
				//		img_select <= 0;   // use for mux instead busy
				//	end
				else begin
						loader_busy <= 0;
						ioctl_upload <= 0;
						ioctl_download <= 0;
						load_crt <= 0;
						load_prg <= 0;
						load_rom <= 0;
						load_tap <= 0;
						load_flt <= 0;
						load_reu <= 0;
						load_ezflash <= 0;
					end
			end

		GO4IT: begin
					loader_busy <= 1;
					load_crt <= rd_sel[0];
					load_prg <= rd_sel[1];
					load_rom <= rd_sel[2]; 
					load_tap <= rd_sel[3]; 
					load_flt <= rd_sel[4]; 
					load_reu <= rd_sel[5];
					load_ezflash <= rd_sel[6];
					ioctl_addr <= '0;
					ioctl_download <= 1;
					addr <= '0;
					loader_sd_lba <= '0;
					core_wait_cnt <= '0;
					io_state <= WAIT4CORE;
			end

		WAIT4CORE: begin
				if(~ioctl_wait) begin
					loader_sd_rd <= rd_sel;
					cnt <= '0;
					io_state <= READ_WAIT4SD;
				end
			end

		READ_WAIT4SD:
			if(sd_done)
				io_state <= READING;

		READING: begin
				if(addr <= img_size[img_select])
					io_state <= READ_NEXT;
				else 
				begin
					ioctl_download <= 0;
					io_state <= DESELECT;
				end
			end

		READ_NEXT: begin
				core_wait_cnt <= core_wait_cnt + 1;
				if(~ioctl_wait && &core_wait_cnt) begin
					wr <= 1;
					buf_addr <= cnt;
					ioctl_addr <= addr;
					addr <= addr + 1;
					cnt <= cnt + 1;
					if(cnt == 511 && (addr + 1) < img_size[img_select]) begin
							loader_sd_lba <= loader_sd_lba + 1;
							io_state <= WAIT4CORE;
						end
					else
						io_state <= READING;
				end
				else
					io_state <= READING;
		end

		DESELECT: begin
				load_crt <= 0;
				load_prg <= 0;
				load_rom <= 0;
				load_tap <= 0;
				load_flt <= 0;
				load_reu <= 0;
				load_ezflash <= 0;
				loader_busy <= 0;
				io_state <= START;
			end

		default: ;

		endcase
	end // else: !if(reset)
end

`ifdef VERILATOR
sector_dpram #(8, 9) trkbuf_inst_loader
(
	.clock(clk),

	.address_a(sd_byte_index),
	.data_a(sd_rd_data),
	.wren_a(sd_rd_byte_strobe),
	.q_a(loader_sd_wr_data),

	.address_b(buf_addr),
	.data_b(upload_data),
	.wren_b(write_strobe),
	.q_b(ioctl_dout)
);
`else
Gowin_DPB_track_buffer_b trkbuf_inst_loader(
	.douta(loader_sd_wr_data),   // sd module, write data to SD card (write)
	.doutb(ioctl_dout),
	.clka(clk), 
	.ocea(1'b1), 
	.cea(1'b1), 
	.reseta(1'b0), 
	.wrea(sd_rd_byte_strobe),// sd_rd_byte_strobe && sd_busy
	.clkb(clk), 
	.oceb(1'b1), 
	.ceb(1'b1),
	.resetb(1'b0), 
	.wreb(write_strobe),// write from ioctl to buffer (write)
	.ada(sd_byte_index),  // sd module
	.dina(sd_rd_data),    // sd module
	.adb(buf_addr),
	.dinb(upload_data)
);
`endif
endmodule

`ifdef VERILATOR
module sector_dpram #(parameter DATAWIDTH=8, ADDRWIDTH=9)
(
	input                   clock,

	input   [ADDRWIDTH-1:0] address_a,
	input   [DATAWIDTH-1:0] data_a,
	input                   wren_a,
	output reg [DATAWIDTH-1:0] q_a,

	input   [ADDRWIDTH-1:0] address_b,
	input   [DATAWIDTH-1:0] data_b,
	input                   wren_b,
	output reg [DATAWIDTH-1:0] q_b
);

reg [DATAWIDTH-1:0] ram[0:(1<<ADDRWIDTH)-1];

always @(posedge clock) begin
	if(wren_a) begin
		ram[address_a] <= data_a;
		q_a <= data_a;
	end else begin
		q_a <= ram[address_a];
	end
end

always @(posedge clock) begin
	if(wren_b) begin
		ram[address_b] <= data_b;
		q_b <= data_b;
	end else begin
		q_b <= ram[address_b];
	end
end

endmodule
`endif
