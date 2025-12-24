// DDR3-backed framebuffer for Tang Mega 60K/138K and Tang Console 60K/138K
// nand2mario, March 2025
//
// - A framebuffer of any size smaller than 1280x720, backed by a single 16-bit 
//   DDR3 chip. The image is automatically upscaled to 1280x720 and displayed on HDMI.
// - Color depth supported: 12, 15, 18, and 24 bits.
// - Dynamic change of framebuffer size is supported. After change the upscaling
//   logic will adapt to the new size.
// - Image is updated by vsync (`fb_vsync`) and then streaming every pixel (`fb_data` 
//   and `fb_we`).
// - Resource usage: 16 BRAMs, ~3000 LUTs, ~3000 REGs, including DDR3 and HDMI IPs.
//
// Internals,
// - Gowin DDR3 controller IP is used to access DDR3. Accesses are done in 4 pixel 
//   chunks (8x 16-bit words). Each pixel is max 32 bits.
// - 720p timings: 
//      1650=1280 + 110(front porch) + 40(sync) + 220(back porch)
//      750 =720  +   5(front porch) +  5(sync)  + 20(back porch)
//   https://projectf.io/posts/video-timings-vga-720p-1080p/#hd-1280x720-60-hz
// - Input pixels are written to an async FIFO first, then read from the FIFO in memory
//   controller clock domain, and written to DDR3 in 4-pixel, 8-beat chunks.
// - Pixels are continuously read from DDR3 in advance into a pixel buffer, as DDR3 
//   controller's read latency is ~35 cycles.
//
// 8/2025: added support for 138K
// 9/2025: improved performance by batching DDR3 accesses to support VGA resolutions
module ddr3_framebuffer #(
    parameter WIDTH = 640,           // multiples of 4
    parameter HEIGHT = 480, 
    parameter COLOR_BITS = 18        // RGB666
)(
    input               clk_27,      // 27Mhz input clock
    input               clk_g,       // 50Mhz crystal
    input               pll_lock_27,
    input               rst_n,
    output              clk_out,     // 74.25Mhz pixel clock. could be used by user logic
    output              ddr_rst,     // output reset signal for clk_out
    output              init_calib_complete,

    // Framebuffer interface
    input               clk,         // any clock <= 74.25Mhz (or `clk_out`)
    input [10:0]        fb_width,    // actual width of the framebuffer
    input [9:0]         fb_height,   // actual height of the framebuffer
    input [10:0]        disp_width,  // display width to upscale to (e.g. 960 for 4:3 aspect ratio, 1080 for 3:2 aspect ratio)
    input               fb_vsync,    // start of frame signal, on or before the first pixel
    input               fb_we,       // update a pixel and move to next pixel
    input [COLOR_BITS-1:0] fb_data,  // pixel data

    input [15:0]        sound_left,
    input [15:0]        sound_right,

    // DDR3 interface
    output [15:0]       ddr_addr,
    output [3-1:0]      ddr_bank,       
    output              ddr_cs,
    output              ddr_ras,
    output              ddr_cas,
    output              ddr_we,
    output              ddr_ck,
    output              ddr_ck_n,
    output              ddr_cke,
    output              ddr_odt,
    output              ddr_reset_n,
    output [2-1:0]      ddr_dm,
    inout  [16-1:0]     ddr_dq,
    inout  [2-1:0]      ddr_dqs,     
    inout  [2-1:0]      ddr_dqs_n, 

    // HDMI output
	output              tmds_clk_n,
	output              tmds_clk_p,
	output [2:0]        tmds_d_n,
	output [2:0]        tmds_d_p
);

// `include "config.vh"
//`define CONSOLE_138K

/////////////////////////////////////////////////////////////////////
// Clocks
wire memory_clk;
wire clk_x1;
wire hclk5;
assign clk_out = clk_x1;
wire pll_lock;

// dynamic reconfiguration port from DDR controller to framebuffer PLL
reg wr;     // for mDRP
wire mdrp_inc;
wire [1:0] mdrp_op;
wire [7:0] mdrp_wdata;
wire [7:0] mdrp_rdata;
wire pll_stop;
reg pll_stop_r;

// 74.25   pixel clock
// 371.25  5x pixel clock
// 297     DDR3 clock
`ifdef CONSOLE_138K

`else

pll_ddr3 pll_ddr3_inst(
    .pll_init_bypass(1'b1), // 60K: bypass init sequence to use u_pll_mDRP_intf
    .lock(pll_lock), 
    .clkout0(), 
    .clkout2(memory_clk), 
    .clkin(clk_27), 
    .reset(~pll_lock_27),
    .mdclk(clk_g),          // 60K: use Dynamic Reconfiguration Port (mDRP) to stop PLL
    .mdopc(mdrp_op),        // 0: nop, 1: write, 2: read
    .mdainc(mdrp_inc),      // increment register address
    .mdwdi(mdrp_wdata),     // data to be written
    .mdrdo(mdrp_rdata)      // data read from register
);

// 74.25 -> 371.25 TMDS clock
pll_hdmi pll_hdmi_inst(
    .clkin(clk_x1),
    .clkout0(hclk5),
    .mdclk(clk_g)
);

reg mdrp_wr;
reg [7:0] pll_stop_count;
pll_mDRP_intf u_pll_mDRP_intf(
    .clk(clk_g),
    .rst_n(pll_lock_27),
    .pll_lock(pll_lock),
    .wr(mdrp_wr),
    .mdrp_inc(mdrp_inc),
    .mdrp_op(mdrp_op),
    .mdrp_wdata(mdrp_wdata),
    .mdrp_rdata(mdrp_rdata)
);

always@(posedge clk_g) begin
    pll_stop_r <= pll_stop;
    mdrp_wr <= pll_stop ^ pll_stop_r;
    if (pll_stop_r && !pll_stop && pll_stop_count != 8'hff) begin
        pll_stop_count <= pll_stop_count + 1;
    end
end
`endif

/////////////////////////////////////////////////////////////////////
// DDR3 controller

// A single 16-bit 4Gb DDR3 memory chip
wire           app_rdy;             // command and data
reg            app_en;
reg    [2:0]   app_cmd;
reg   [27:0]   app_addr;        

wire           app_wdf_rdy;         // write data
reg            app_wdf_wren;
wire  [15:0]   app_wdf_mask = 0;
wire           app_wdf_end = 1; 
reg  [127:0]   app_wdf_data;        

wire           app_rd_data_valid;   // read data
wire           app_rd_data_end;
wire [127:0]   app_rd_data;     

wire           app_sre_req = 0;      
wire           app_ref_req = 0;
wire           app_burst = 1;
wire           app_sre_act;
wire           app_ref_ack;

DDR3_Memory_Interface_Top u_ddr3 (
    .memory_clk      (memory_clk),
    .pll_stop        (pll_stop),
    .clk             (clk_g),
    .rst_n           (1'b1),   
    //.app_burst_number(0),
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
    //.pll_lock        (1'b1), 
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

/////////////////////////////////////////////////////////////////////
// Audio

localparam AUDIO_RATE=48000;
localparam AUDIO_CLK_DELAY = 74250 * 1000 / AUDIO_RATE / 2;
logic [$clog2(AUDIO_CLK_DELAY)-1:0] audio_divider;
logic clk_audio;

always_ff@(posedge clk_x1) 
begin
    if (audio_divider != AUDIO_CLK_DELAY - 1) 
        audio_divider++;
    else begin 
        clk_audio <= ~clk_audio; 
        audio_divider <= 0; 
    end
end

reg [15:0] audio_sample_word [1:0], audio_sample_word0 [1:0];
always @(posedge clk_x1) begin       // crossing clock domain
    audio_sample_word0[0] <= sound_left;
    audio_sample_word[0] <= audio_sample_word0[0];
    audio_sample_word0[1] <= sound_right;
    audio_sample_word[1] <= audio_sample_word0[1];
end

/////////////////////////////////////////////////////////////////////
// HDMI TX

wire [10:0] cx;
wire [9:0] cy;
reg [23:0] rgb;

// HDMI output.
wire [2:0] tmds;
localparam VIDEOID = 4;
localparam VIDEO_REFRESH = 60.0;
localparam AUDIO_BIT_WIDTH = 16;
localparam AUDIO_OUT_RATE = 32000;

hdmi #( .VIDEO_ID_CODE(VIDEOID), 
        .DVI_OUTPUT(0), 
        .VIDEO_REFRESH_RATE(VIDEO_REFRESH),
        .IT_CONTENT(1),
        .AUDIO_RATE(AUDIO_OUT_RATE), 
        .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
        .START_X(0),
        .START_Y(0) )

hdmi(   .clk_pixel_x5(hclk5), 
        .clk_pixel(clk_x1), 
        .clk_audio(clk_audio),
        .rgb(rgb), 
        .reset( ddr_rst ),
        .audio_sample_word(audio_sample_word),
        .tmds(tmds), 
        .tmds_clock(), 
        .cx(cx), 
        .cy(cy),
        .frame_width(),
        .frame_height() );

// Gowin LVDS output buffer
ELVDS_OBUF tmds_bufds [3:0] (
    .I({clk_x1, tmds}),
    .O({tmds_clk_p, tmds_d_p}),
    .OB({tmds_clk_n, tmds_d_n})
);

/////////////////////////////////////////////////////////////////////
// 720p Framebuffer

localparam FB_SIZE = WIDTH * HEIGHT;
localparam RENDER_DELAY = 74_250_000 * 8 / WIDTH / HEIGHT / 60;   // 32
localparam PREFETCH_POW = 6;                    // 5: 32 pixels, 6: 64 pixels
localparam PREFETCH_SIZE = 1 << PREFETCH_POW;   // how many pixels to prefetch

reg [7:0] cursor_x, cursor_y;   // a green 8x8 block on grey background for demo
reg [7:0] cursor_delay;         // 32 cycles per write

reg write_pixels_req;           // toggle to write 8 pixels
reg write_pixels_ack;
reg [9:0] wr_x, wr_y;           // write position
reg [$clog2(FB_SIZE*2)-1:0] wr_addr;

reg [$clog2(FB_SIZE*2)-1:0] rd_addr;
reg prefetch;                   // will start prefetch next cycle
reg [10:0] prefetch_x;
reg [$clog2(1280+WIDTH)-1:0] prefetch_x_cnt;
reg [$clog2(720+HEIGHT)-1:0] prefetch_y_cnt;
reg [$clog2(FB_SIZE*2)-1:0] prefetch_addr_line;   // current line to prefetch

reg [COLOR_BITS-1:0] pixels [0:PREFETCH_SIZE-1];  // prefetch buffer
reg [$clog2(WIDTH)-1:0] ox;
reg [$clog2(HEIGHT)-1:0] oy;
reg [$clog2(1280+WIDTH)-1:0] xcnt;
reg [$clog2(720+HEIGHT)-1:0] ycnt;

// Framebuffer update - accumulate 4 pixels and then send to DDR3
reg [$clog2(WIDTH)-1:0] b_x;
reg [$clog2(HEIGHT)-1:0] b_y;
reg b_vsync_toggle, b_vsync_toggle_r, b_vsync_toggle_rr;
wire fifo_can_read;
wire fifo_can_write;
wire [4*COLOR_BITS-1:0] fifo_data;
wire [6:0] fifo_level;
reg fifo_read;
reg fifo_write;

reg fb_vsync_r;
always @(posedge clk) begin
    fb_vsync_r <= fb_vsync;
    if (fb_vsync & ~fb_vsync_r) begin   // sample vsync rising edge
        b_vsync_toggle <= ~b_vsync_toggle;
    end
end

// Group incoming pixels (clk) into 4-pixel words and push to FIFO
reg [1:0]  wgrp_cnt;                             // 0..3 pixels collected
reg [4*COLOR_BITS-1:0] wgrp_data;                // packed as {p3,p2,p1,p0}
reg        wgrp_pending;                         // group ready to write when FIFO can accept

async_fifo #(.BUFFER_ADDR_WIDTH(4), .DATA_WIDTH(4*COLOR_BITS)) u_asyncfifo (
  .reset(fb_vsync & ~fb_vsync_r),      // clear FIFO on new VGA frame
  .write_clk(clk), .write(fifo_write), .write_data(wgrp_data), .can_write(fifo_can_write),  
  .read_clk(clk_x1), .read(fifo_read), .read_data(fifo_data),  .can_read(fifo_can_read),
  .read_available(fifo_level)
);

// Assemble 4 pixels per FIFO word (clk domain)
always @(posedge clk) begin
    fifo_write <= 1'b0;
    if (ddr_rst | ~init_calib_complete) begin
        wgrp_cnt <= 0;
        wgrp_pending <= 0;
        wgrp_data <= 0;
    end else begin
        // Accept a pixel only if we're not holding a pending group
        if (fb_we && !wgrp_pending) begin
            case (wgrp_cnt)
                2'd0: begin
                    wgrp_data[COLOR_BITS-1:0] <= fb_data; 
                    wgrp_cnt <= 2'd1;
                end
                2'd1: begin
                    wgrp_data[2*COLOR_BITS-1:COLOR_BITS] <= fb_data;
                    wgrp_cnt <= 2'd2;
                end
                2'd2: begin
                    wgrp_data[3*COLOR_BITS-1:2*COLOR_BITS] <= fb_data;
                    wgrp_cnt <= 2'd3;
                end
                2'd3: begin
                    wgrp_data[4*COLOR_BITS-1:3*COLOR_BITS] <= fb_data;
                    wgrp_cnt <= 2'd0;
                    wgrp_pending <= 1'b1; // group ready
                end
            endcase
        end
        // Try to push the pending group into FIFO
        if (wgrp_pending && fifo_can_write) begin
            fifo_write <= 1'b1;
            wgrp_pending <= 1'b0;
        end
    end
end

// cross to clk_x1 domain
always @(posedge clk_x1) begin
    b_vsync_toggle_rr <= b_vsync_toggle_r;
    b_vsync_toggle_r <= b_vsync_toggle;
end

// Batch write control: start when FIFO has >=8 groups (32 pixels); write 8 groups
reg write_batch_active;
reg mem_dir_write;              // 1: write mode (suppress read commands)
reg [3:0] batch_groups_left;    // number of 4-pixel groups left in batch
wire write_inflight = write_pixels_req ^ write_pixels_ack; // DDR write pending
wire new_frame = b_vsync_toggle_rr != b_vsync_toggle_r;

always @(posedge clk_x1) begin : write_batch_control
    fifo_read <= 1'b0;
    if (ddr_rst | ~init_calib_complete) begin
        wr_x <= 0; wr_y <= 0;
        write_pixels_req <= 0;
        write_batch_active <= 0;
        mem_dir_write <= 0;
        batch_groups_left <= 0;
        
    end else begin
        if (new_frame) begin
            wr_x <= 0; wr_y <= 0;
        end

        // Start a new batch when at least 8 groups are queued
        if (!write_batch_active && !mem_dir_write && fifo_level >= 7'd8) begin
            write_batch_active <= 1'b1;
            mem_dir_write <= 1'b1;   // switch to write mode
            batch_groups_left <= 4'd8;
        end

        if (write_batch_active) begin       // write batch_groups_left (8) groups of pixels
            // If FIFO not empty and no write in flight, issue DDR write using current fifo_data
            if (fifo_can_read && !write_inflight) begin
                wr_addr <= {wr_y * WIDTH + {wr_x[9:2], 2'b0}, 1'b0};
                app_wdf_data <= { {(32-COLOR_BITS){1'b0}}, fifo_data[4*COLOR_BITS-1:3*COLOR_BITS],
                                  {(32-COLOR_BITS){1'b0}}, fifo_data[3*COLOR_BITS-1:2*COLOR_BITS],
                                  {(32-COLOR_BITS){1'b0}}, fifo_data[2*COLOR_BITS-1:1*COLOR_BITS],
                                  {(32-COLOR_BITS){1'b0}}, fifo_data[1*COLOR_BITS-1:0] };
                write_pixels_req <= ~write_pixels_req;
                fifo_read <= 1'b1;          // advance FIFO to next group
                batch_groups_left <= batch_groups_left - 1;
                if (batch_groups_left == 1) write_batch_active <= 0;  // last group
                // advance framebuffer coordinates by 4 pixels
                wr_x <= wr_x + 4;
                if (wr_x + 4 >= fb_width) begin
                    wr_x <= 0;
                    wr_y <= wr_y + 1;
                end
            end
        end

        // If batch completed and last write is fully acknowledged, return to read mode
        if (!write_batch_active && mem_dir_write && !write_inflight) begin
            mem_dir_write <= 1'b0;
        end
    end
end

// upscaling and output RGB
reg [$clog2(WIDTH)-1:0] ox_r;
reg [10:0] x_start, x_end;      // determined by fb_width
reg [10:0] diff_720_height, diff_disp_width_width;
reg [10:0] x_prefetch_start;

always @(posedge clk_x1) begin
    if (ddr_rst | ~init_calib_complete) begin
        ox <= 0; oy <= 0; xcnt <= 0; ycnt <= 0;
    end else begin
        // keep original pixel coordinates
        if (cx == x_end) begin
            ox <= 0; xcnt <= 0;
            if (cy == 0) begin
                oy <= 0;
                ycnt <= fb_height;
            end else begin
                ycnt <= ycnt + fb_height;
                if (ycnt >= diff_720_height) begin
                    ycnt <= ycnt - diff_720_height;
                    oy <= oy + 1;
                end
            end
        end 
        if (cx >= x_start && cx < x_end) begin
            xcnt <= xcnt + fb_width;
            if (xcnt >= diff_disp_width_width) begin
                xcnt <= xcnt - diff_disp_width_width;
                ox <= ox + 1;
            end
            rgb <= torgb(pixels[cx == 0 ? 0 : ox[PREFETCH_POW-1:0]]);
        end else
            rgb <= 24'h202020;

        // if (cy >= 300 && cy < 330)    // a blue bar in the middle for debug
        //     rgb <= 24'h4040ff;
    end
end

// some precalculation
always @(posedge clk) begin
    x_start <= (1280-disp_width)/2;
    x_end <= (1280+disp_width)/2;
    diff_720_height <= 720 - fb_height;
    diff_disp_width_width <= disp_width - fb_width;
end

// TODO: wrapping while prefetching is not implemented yet
always @(posedge clk_x1) begin
    if (ddr_rst | ~init_calib_complete) begin
        prefetch_x <= 0;
    end else begin
        if (cx == 0) begin
            prefetch_x <= PREFETCH_SIZE;      // We fetch up to prefetch_x
            prefetch_x_cnt <= fb_width;
            if (cy == 0) begin
                prefetch_y_cnt <= 0;
                prefetch_addr_line <= 0;
            end else begin
                prefetch_y_cnt <= prefetch_y_cnt + fb_height;
                if (prefetch_y_cnt >= diff_720_height) begin
                    prefetch_y_cnt <= prefetch_y_cnt - diff_720_height;
                    prefetch_addr_line <= prefetch_addr_line + {WIDTH, 1'b0};
                end
            end
        end else if (cx >= x_start && prefetch_x < fb_width) begin
            prefetch_x_cnt <= prefetch_x_cnt + fb_width;
            if (prefetch_x_cnt >= diff_disp_width_width) begin
                prefetch_x_cnt <= prefetch_x_cnt - diff_disp_width_width;
                prefetch_x <= prefetch_x + 1;
            end
        end
    end
end

reg cmd_done, data_done;
reg [10:0] read_x;
wire read_handshake = app_rdy & app_cmd == 3'b001 & app_en;
wire write_handshake = app_rdy & app_cmd == 3'b000 & app_en;
wire data_handshake = app_wdf_rdy & app_wdf_wren;

// actual framebuffer DDR3 read/write
always @(posedge clk_x1) begin : ddr3_rw
    app_en <= 0;
    app_wdf_wren <= 0;

    if (ddr_rst | ~init_calib_complete) begin
        cmd_done <= 0;
        data_done <= 0;
    end else begin
        if (write_pixels_req ^ write_pixels_ack) begin // process writes
            if (!cmd_done && app_rdy) begin   // send command next cycle
                app_en <= 1'b1;
                app_cmd <= 3'b000;
                app_addr <= wr_addr;
                cmd_done <= 1'b1;
            end
            if (!data_done && app_wdf_rdy) begin   // send data next cycle
                app_wdf_wren <= 1;
                data_done <= 1'b1;
            end
            if ((cmd_done | app_rdy) & (data_done | app_wdf_rdy)) begin
                // whole transaction is done
                write_pixels_ack <= write_pixels_req;
                cmd_done <= 0;
                data_done <= 0;
            end
        end else if (!mem_dir_write && read_x + 4 <= prefetch_x && cx < x_end && app_rdy) begin   // process reads
            app_en <= 1;
            app_cmd <= 3'b001;
            app_addr <= {read_x, 1'b0} + prefetch_addr_line;
            read_x <= read_x + 4;
        end 

        if (cx == 0) read_x <= 0;       // start new line
    end
end

// receive pixels from DDR3 and write to pixels[] in 8 cycles
reg [PREFETCH_POW-1:0] bram_addr;
always @(posedge clk_x1) begin
    if (cx == 0)     // reset addr before line start
        bram_addr <= 0;

    if (app_rd_data_valid) begin
        for (int i = 0; i < 4; i++) begin
            pixels[bram_addr+i] <= app_rd_data[32*i+:COLOR_BITS];
        end
        bram_addr <= bram_addr + 4;
    end
end


// Convert color to RGB888
function [23:0] torgb(input [23:0] pixel);
    case (COLOR_BITS)
    12: torgb = {pixel[11:8], 4'b0, pixel[7:4], 4'b0, pixel[3:0], 4'b0};
    15: torgb = {pixel[14:10], 3'b0, pixel[9:5], 3'b0, pixel[4:0], 3'b0};
    18: torgb = {pixel[17:12], 2'b0, pixel[11:6], 2'b0, pixel[5:0], 2'b0};
    21: torgb = {pixel[20:14], 1'b0, pixel[13:7], 1'b0, pixel[6:0], 1'b0};
    24: torgb = pixel;
    default: torgb = 24'hbabeef;
    endcase
endfunction

endmodule
