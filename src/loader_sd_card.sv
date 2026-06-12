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
	output logic [6:0]  sd_rd, // read request for target
	output logic [6:0]  sd_wr, // write request for target
	input  logic        sd_busy, // SD is busy (has accepted read or write request)

	input  logic [8:0]  sd_byte_index, // address of data byte within 512 bytes sector
	input  logic [7:0]  sd_rd_data, // data byte received from SD card
	input  logic        sd_rd_byte_strobe, // SD has read a byte to be stored in  buffer
	input  logic        sd_done, // SD is done (data has been read or written

	output logic [7:0]  sd_wr_data,

	input  logic [7:0]  sd_img_mounted,
	input  logic [31:0] sd_img_size,
	output logic        load_crt,
	output logic        load_prg,
	output logic        load_rom,
	output logic        load_tap,
	output logic        load_flt,
	output logic        load_reu,
	output logic        loader_busy,
	output logic [2:0]  img_select,
	output logic [4:0]  leds,

	output logic        ioctl_download,
	input  logic        ioctl_upload_req,
	output logic        ioctl_upload,
	input  logic [7:0]  ioctl_din,
	output logic [23:0] ioctl_addr,
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
	WRITE_WAIT4CORE,
	WRITING,
	WRITE_START_SD,
	WRITE_WAIT4SD
} io_state_t;

io_state_t io_state;
logic [23:0] addr;
logic [31:0] ch_timeout;
logic wr;
logic [8:0] cnt;
logic [4:0] core_wait_cnt;
logic [23:0] img_size [0:7];
logic img_present [0:7];
logic img_presentD [0:7];
logic [6:0] rd_sel;
logic boot_crt;
logic boot_bin;
logic boot_prg;
logic boot_tap;
logic boot_flt;
logic boot_reu;
logic old_upload_req;
logic upload_req;
logic write_strobe;

integer i;

assign sd_wr_data = 8'd0;

always_ff @(posedge clk) begin

	for(i = 0; i < 8; i = i + 1)
	begin
		img_presentD[i] <= img_present[i];

		if (sd_img_mounted[i]) 
		begin
			img_present[i] <= |sd_img_size;
			img_size[i] <= sd_img_size[23:0];
		end 
	end

	leds[0] <= img_present[0];
	leds[1] <= img_present[1];
	leds[2] <= img_present[2];
	leds[3] <= img_present[3];
	leds[4] <= img_present[4];
	ioctl_rd <= 1'b0;
	ioctl_wr <= wr;
	wr <= 1'b0;
	write_strobe <= 1'b0;

	if(sd_busy) begin
		sd_rd <= 7'd0;
		sd_wr <= 7'd0; 
	end

	old_upload_req <= ioctl_upload_req;
	if(~old_upload_req & ioctl_upload_req)
		upload_req <= 1;

	if(reset)
	begin
		old_upload_req <= 1'b0;
		upload_req <= 1'b0;
		ioctl_upload <= 1'b0;
		ioctl_rd <= 1'b0;
		write_strobe <= 1'b0;
		sd_rd <= 7'd0;
		sd_wr <= 7'd0;
		wr <= 1'b0;
		load_crt <= 1'b0;
		load_prg <= 1'b0;
		load_rom <= 1'b0;
		load_tap <= 1'b0;
		load_flt <= 1'b0;
		load_reu <= 1'b0;
		ioctl_download <= 1'b0;
		ioctl_addr <= 24'd0;
		addr <= 24'd0;
		leds <= 5'd0;
		loader_busy <= 1'b0;
		boot_crt <= 1'b0;
		boot_bin <= 1'b0;
		boot_prg <= 1'b0;
		boot_tap <= 1'b0;
		boot_flt <= 1'b0;
		boot_reu <= 1'b0;
		rd_sel <= 7'd0;
		img_select <= 3'd0;
		cnt <= 9'd0;
		core_wait_cnt <= 5'd0;
		ch_timeout <= 32'd0;
		io_state <= START;
	end
	else
	begin
	case(io_state)
		WRITE_WAIT4CORE: begin
				core_wait_cnt <= core_wait_cnt + 1'd1;
				if(~ioctl_wait && &core_wait_cnt) begin
					io_state <= WRITING;
					core_wait_cnt <= 5'd0;
				end
			end

		WRITING: begin
			write_strobe <= 1'b1;
			ioctl_rd <= 1;
			ioctl_addr <= addr;
			addr <= addr + 1'd1;
			cnt <= cnt + 1'd1;
			if(cnt == 511)
				begin
					io_state <= WRITE_START_SD;
					sd_wr <= 7'b0000001; // request write to sd card CRT
				end
			io_state <= WRITE_WAIT4CORE;
		end

		WRITE_START_SD: begin
		   // wait for SD card to ack the request by becoming busy
		   if(sd_busy) begin
			  io_state <= WRITE_WAIT4SD;
		   end
		end

		WRITE_WAIT4SD: begin
			if(sd_done) begin
				if(addr < img_size[img_select]) begin
					io_state <= WRITE_WAIT4CORE;
					cnt <= 9'd0;
					core_wait_cnt <= 5'd0;
					sd_lba <= sd_lba + 1'd1;
				end
				else
				begin
					ioctl_upload <= 1'b0;
					ioctl_addr <= 24'd0;
					io_state <= START;
				end
			end
		end

		START:
			begin // 0 c1541 1 CRT 2 PRG 3 BIN 4 TAP 5 FLT 6 REU 7 EZFLASH SAVE
				if((|img_size[1]) && upload_req) begin // ! overwrite CRT if upload requested
						upload_req <= 1'b0;
						loader_busy <= 1'b1;
						io_state <= WRITE_WAIT4CORE;
						ch_timeout <= 32'd110000;
						ioctl_addr <= 24'd0;
						ioctl_upload <= 1'b1;
						addr <= 24'd0;
						sd_lba <= 32'd0;
						core_wait_cnt <= 5'd0;
						cnt <= 9'd0;
					end
				else if((|img_size[3]) && ((img_present[3] && ~img_presentD[3]) || (img_present[3] && ~boot_bin))) begin
						img_select <= 3;
						io_state <= GO4IT;
						rd_sel <= 7'b0000100;
						boot_bin <= 1'b1;
					end
				else if((|img_size[1]) && ((img_present[1] && ~img_presentD[1]) || (img_present[1] && ~boot_crt))) begin
						img_select <= 1; 
						io_state <= GO4IT; 
						rd_sel <= 7'b0000001;
						boot_crt <= 1'b1;
					end
				else if((|img_size[2]) && ((img_present[2] && ~img_presentD[2]) || (img_present[2] && ~boot_prg))) begin 
						img_select <= 2;
						io_state <= GO4IT;
						rd_sel <= 7'b0000010;
						boot_prg <= 1'b1;
					end
				else if((|img_size[5]) && ((img_present[5] && ~img_presentD[5]) || (img_present[5] && ~boot_flt))) begin
						img_select <= 5;
						io_state <= GO4IT;
						rd_sel <= 7'b0010000;
						boot_flt <= 1'b1;
					end
//				else if((img_present[4] && ~img_presentD[4]) || (img_present[4] && ~boot_tap))
				else if((|img_size[4]) && img_present[4] && ~img_presentD[4]) begin
						img_select <= 4;
						io_state <= GO4IT;
						rd_sel <= 7'b0001000;
						boot_tap <= 1'b1;
					end
				else if((|img_size[6]) && ((img_present[6] && ~img_presentD[6]) || (img_present[6] && ~boot_reu))) begin
						img_select <= 6;
						io_state <= GO4IT;
						rd_sel <= 7'b0100000;
						boot_reu <= 1'b1;
					end
				else if((|img_size[0]) && img_present[0] && ~img_presentD[0]) begin // C1541
						img_select <= 0; 
					end
				else if((|img_size[7]) && img_present[7] && ~img_presentD[7]) begin // EZFLASH SAVE
						img_select <= 7; 
					end
			end

		GO4IT: begin
					loader_busy <= 1'b1;
					load_crt <= rd_sel[0];
					load_prg <= rd_sel[1];
					load_rom <= rd_sel[2]; 
					load_tap <= rd_sel[3]; 
					load_flt <= rd_sel[4]; 
					load_reu <= rd_sel[5]; 
					ch_timeout <= 32'd110000; // 32'd1508863;
					ioctl_addr <= 24'd0;
					ioctl_download <= 1'b1;
					addr <= 24'd0;
					sd_lba <= 32'd0;
					core_wait_cnt <= 5'd0;
					io_state <= WAIT4CORE;
			end

		WAIT4CORE: begin
				if(ch_timeout > 0) ch_timeout <= ch_timeout - 1'd1;
				if(ch_timeout == 0 && ~ioctl_wait) 
				begin
					sd_rd <= rd_sel;
					cnt <= 9'd0;
					io_state <= READ_WAIT4SD;
				end
			end

		READ_WAIT4SD:
			if(sd_done)
				io_state <= READING;

		READING: begin
				if(addr < img_size[img_select])
					io_state <= READ_NEXT;
				else 
				begin
					ioctl_download <= 1'b0;
					ioctl_addr <= 24'd0;
					io_state <= DESELECT;
				end
			end

		READ_NEXT: begin
				core_wait_cnt <= core_wait_cnt + 1'd1;
				if(~ioctl_wait && &core_wait_cnt) 
					begin
						wr <= 1'b1;
						ioctl_addr <= addr;
						addr <= addr + 1'd1;
						cnt <= cnt + 1'd1;
						if(cnt == 511) 
							begin
								sd_lba <= sd_lba + 1'd1;
								ch_timeout <= 1'd1;
								io_state <= WAIT4CORE;
							end
					end
					else
						io_state <= READING;
			end

		DESELECT: begin
				load_crt <= 1'b0;
				load_prg <= 1'b0;
				load_rom <= 1'b0;
				load_tap <= 1'b0;
				load_flt <= 1'b0;	
				load_reu <= 1'b0;			
				loader_busy <= 1'b0;
				io_state <= START;
			end

		default: ;

		endcase
	end // else: !if(reset)
end

Gowin_DPB_track_buffer_b trkbuf_inst_loader(
	.douta(sd_wr_data),   // sd module, write data to SD card (write)
	.doutb(ioctl_dout),
	.clka(clk), 
	.ocea(1'b1), 
	.cea(1'b1), 
	.reseta(1'b0), 
	.wrea(sd_rd_byte_strobe && sd_busy),// sd module
	.clkb(clk), 
	.oceb(1'b1), 
	.ceb(1'b1),
	.resetb(1'b0), 
	.wreb(write_strobe),// write from ioctl to buffer (write)
	.ada(sd_byte_index),  // sd module
	.dina(sd_rd_data),    // sd module
	.adb(ioctl_addr[8:0]),
	.dinb(ioctl_din)      // data from ioctl to be written to SD card (write)
);

endmodule
