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

	output logic        ioctl_download,
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
	START
} io_state_t;

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
logic [8:0] buf_addr;

logic [31:0] loader_sd_lba;
logic [6:0]  loader_sd_rd;
logic [7:0]  loader_sd_wr_data;

assign sd_lba     = loader_busy ? loader_sd_lba     : c1541_lba;
assign sd_wr_data = loader_busy ? loader_sd_wr_data : c1541_sd_wr_data;
assign sd_rd      = loader_busy ? {loader_sd_rd, 1'b0} : {7'b0000000, c1541_sd_rd};
assign sd_wr      = loader_busy ? 8'b0 : {7'b0000000, c1541_sd_wr};

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

	if(sd_busy) begin
		loader_sd_rd <= '0;
	end

	if(reset)
	begin

		ioctl_rd <= 0;
		loader_sd_rd <= '0;
		loader_sd_lba <= '0;
		wr <= 0;
		load_crt <= 0;
		load_prg <= 0;
		load_rom <= 0;
		load_tap <= 0;
		load_flt <= 0;
		load_reu <= 0;
		ioctl_download <= 0;
		ioctl_addr <= '0;
		addr <= '0;
		buf_addr <= '0;
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

	case(io_state)
		START:
			begin // 0 c1541 1 CRT 2 PRG 3 BIN 4 TAP 5 FLT 6 REU 7 unused
			if((|img_size[3]) && ((img_present[3] && ~img_presentD[3]) || (img_present[3] && ~boot_flags[3]))) begin
					// Kernal file select
					img_select <= 3;
					io_state <= GO4IT;
					rd_sel <= 7'b0000100;
					boot_flags[3] <= 1;
					end
			else if((|img_size[1]) && ((img_present[1] && ~img_presentD[1]) || (img_present[1] && ~boot_flags[1]))) begin
					// CRT file select
					img_select <= 1; 
					io_state <= GO4IT; 
					rd_sel <= 7'b0000001;
					boot_flags[1] <= 1;
					end
			else if((|img_size[2]) && ((img_present[2] && ~img_presentD[2]) || (img_present[2] && ~boot_flags[2]))) begin
					// PRG file select 
					img_select <= 2;
					io_state <= GO4IT;
					rd_sel <= 7'b0000010;
					boot_flags[2] <= 1;
					end
			else if((|img_size[5]) && ((img_present[5] && ~img_presentD[5]) || (img_present[5] && ~boot_flags[5]))) begin
					// FLT file select
					img_select <= 5;
					io_state <= GO4IT;
					rd_sel <= 7'b0010000;
					boot_flags[5] <= 1;
					end
			else if((|img_size[4]) && img_present[4] && ~img_presentD[4]) begin
					// TAP file select
					img_select <= 4;
					io_state <= GO4IT;
					rd_sel <= 7'b0001000;
					boot_flags[4] <= 1;
					end
			else if((|img_size[6]) && ((img_present[6] && ~img_presentD[6]) || (img_present[6] && ~boot_flags[6]))) begin
					// REU file select
					img_select <= 6;
					io_state <= GO4IT;
					rd_sel <= 7'b0100000;
					boot_flags[6] <= 1;
					end
			//else if((|img_size[7]) && ((img_present[7] && ~img_presentD[7]) || (img_present[7] && ~boot_flags[7]))) begin // EZFLASH file select
				// unused
				//		boot_flags[7] <= 1;
				//		end
			//else if((|img_size[0]) && img_present[0] && ~img_presentD[0]) begin 
				// C1541 select
				//		img_select <= 0;   // use for mux instead busy
				//	end
				else begin
						loader_busy <= 0;
						ioctl_download <= 0;
						load_crt <= 0;
						load_prg <= 0;
						load_rom <= 0;
						load_tap <= 0;
						load_flt <= 0;
						load_reu <= 0;
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
	.data_b(8'b0),
	.wren_b(1'b0),
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
	.wreb(1'b0),// write from ioctl to buffer (write)
	.ada(sd_byte_index),  // sd module
	.dina(sd_rd_data),    // sd module
	.adb(buf_addr),
	.dinb(8'b0)
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
