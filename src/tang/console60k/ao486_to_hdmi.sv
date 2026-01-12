// VGA video and sound to HDMI converter with DDR3 framebuffer
// nand2mario, 9/2025
module ao486_to_hdmi (
    input               clk27,            // 27Mhz for generating HDMI and DDR3 clocks
    input               pll_lock_27,
    input               clk50,
	input               resetn,
    output              clk_pixel,        // 74.25Mhz pixel clock output
    input         [5:0] ddr_prefetch_delay,
    output              init_calib_complete,

    // ao486 VGA video signals
	input               clk_vga,          // ao486 VGA clock
    input               vga_ce,           // clock enable for VGA output
    input         [7:0] vga_r,
    input         [7:0] vga_g,
    input         [7:0] vga_b,
    input               vga_hs,
    input               vga_vs,
    input               vga_de,           // blank_n
    input               freeze,           // freeze video output (for debug)

    // audio input
    input        [15:0] sound_left,
    input        [15:0] sound_right,

    // overlay interface
    input               overlay,
    output    reg [7:0] overlay_x,
    output    reg [7:0] overlay_y,
    input        [15:0] overlay_color,

    // DDR3 interface
    output       [15:0] ddr_addr,   
    output       [2:0]  ddr_bank,       
    output              ddr_cs,
    output              ddr_ras,
    output              ddr_cas,
    output              ddr_we,
    output              ddr_ck,
    output              ddr_ck_n,
    output              ddr_cke,
    output              ddr_odt,
    output              ddr_reset_n,
    output       [1:0]  ddr_dm,
    inout        [15:0] ddr_dq,
    inout        [1:0]  ddr_dqs,     
    inout        [1:0]  ddr_dqs_n, 

	// output signals
	output              tmds_clk_n,
	output              tmds_clk_p,
	output        [2:0] tmds_d_n,
	output        [2:0] tmds_d_p
);

// ------------------------------------------------------------ video mode detection

// Simple frame size estimator using VGA signals.
// - Counts active pixels while `vga_de` is high (gated by `vga_ce`) to determine width.
// - Counts number of active lines per frame to determine height.
// - Latches measurements on the rising edge of VSYNC.

reg  [10:0] fb_width;
reg   [9:0] fb_height;
wire        fb_size_valid;

reg  [10:0] cur_line_width;
reg  [10:0] max_line_width;
reg   [9:0] line_count;
reg         de_r;
reg         vs_r;
reg vsD, hsD;

assign fb_size_valid = (fb_width != 0) && (fb_height != 0);

always @(posedge clk_vga) begin
    if (!resetn) begin
        fb_width       <= 0;
        fb_height      <= 0;
        cur_line_width <= 0;
        max_line_width <= 0;
        line_count     <= 0;
        de_r           <= 0;
        vs_r           <= 0;
    end else begin
        if (vga_ce) begin
            de_r <= vga_de;
            vs_r <= vga_vs;
            hsD <= vga_hs;

            // Count active pixels in the line
          if (vga_de) begin
             if (!de_r)   // Start of active portion of a line
               cur_line_width <= 1;
             else
               cur_line_width <= cur_line_width + 1'b1;
             end
            // End of active portion of a line
            if(vga_hs && !hsD) begin
                if (cur_line_width > max_line_width)
                    max_line_width <= cur_line_width;
                if (cur_line_width != 0)
                    line_count <= line_count + 1'b1;
            end
            // Rising edge of VSYNC: latch frame size and reset counters
            if (vga_vs && !vs_r) begin
                fb_width       <= max_line_width;
                fb_height      <= line_count;
                cur_line_width <= 0;
                max_line_width <= 0;
                line_count     <= 0;
            end
        end
    end
end


// ------------------------------------------------------------ framebuffer

reg frame_end, frame_end_r;
reg overlay_r;
reg overlay_we;
reg vsync;
reg [3:0] overlay_cnt;
reg [17:0] overlay_data;
reg vga_vs_r;
// BGR5 to RGB6

always @(posedge clk_vga) begin
    overlay_r <= overlay;
    vsync <= 0;
    overlay_we <= 0;
    frame_end <= 0;
    frame_end_r <= frame_end;

    if (~freeze) begin
        if (!overlay) begin
            vga_vs_r <= vga_vs;
            vsync <= vga_vs & ~vga_vs_r;     // always use rising edge
        end else if (overlay && !overlay_r) begin
            // init overlay display
            overlay_x <= 0;
            overlay_y <= 0;
            overlay_we <= 0;
            overlay_cnt <= 0;
        end else if (overlay) begin
            // send overlay data to framebuffer
            // overlay runs at clk50
            // 15 clk50 cycles per pixel, 57.3K pixels -> 58fps
            overlay_cnt <= overlay_cnt == 14 ? 0 : overlay_cnt + 1;
            case (overlay_cnt)
            0: begin
                if (overlay_x == 0 && overlay_y == 0)
                    vsync <= 1;
            end

            12: begin
                overlay_data <= {overlay_color[4:0], 1'b0, overlay_color[9:5], 1'b0, overlay_color[14:10], 1'b0};
                overlay_we <= 1;
            end

            14: begin
                overlay_x <= overlay_x + 1;
                if (overlay_x == 255) begin
                    overlay_y <= overlay_y + 1;
                    if (overlay_y == 223) 
                        overlay_y <= 0;
                end
            end
            default: ;
            endcase
        end
    end
end

ddr3_framebuffer #(
    .WIDTH(1024),
    .HEIGHT(768),
    .COLOR_BITS(18)
) fb (
    .clk_27(clk27),
    .pll_lock_27(pll_lock_27),
    .clk_g(clk50),
    .clk_out(clk_pixel),
    .rst_n(resetn),
    .ddr_rst(),
    .init_calib_complete(init_calib_complete),
    // .ddr_prefetch_delay(ddr_prefetch_delay),
    
    // Framebuffer interface
    .clk(clk_vga),
    .fb_width(overlay ? 256 : fb_width),
    .fb_height(overlay ? 224 : fb_height),
    .disp_width(960),         // 960x720 is 4:3
    .fb_vsync(vsync),
    .fb_we(vga_hs && !hsD),
    // Pack VGA RGB888 to RGB666 expected by framebuffer: {R[7:2], G[7:2], B[7:2]}
    // Previously this passed a 24-bit {R,G,B} vector into an 18-bit port, causing truncation
    // and channel mixing on hardware (red/green swapped/garbled). Simulation bypassed this path.
    .fb_data(overlay ? overlay_data : {vga_r[7:2], vga_g[7:2], vga_b[7:2]}),
    
    .sound_left(sound_left),
    .sound_right(sound_right),

    // DDR3 interface
    .ddr_addr(ddr_addr),
    .ddr_bank(ddr_bank),
    .ddr_cs(ddr_cs),
    .ddr_ras(ddr_ras),
    .ddr_cas(ddr_cas),
    .ddr_we(ddr_we),
    .ddr_ck(ddr_ck),
    .ddr_ck_n(ddr_ck_n),
    .ddr_cke(ddr_cke),
    .ddr_odt(ddr_odt),
    .ddr_reset_n(ddr_reset_n),
    .ddr_dm(ddr_dm),
    .ddr_dq(ddr_dq),
    .ddr_dqs(ddr_dqs),
    .ddr_dqs_n(ddr_dqs_n),
    
    // HDMI output
    .tmds_clk_n(tmds_clk_n),
    .tmds_clk_p(tmds_clk_p),
    .tmds_d_n(tmds_d_n),
    .tmds_d_p(tmds_d_p)
);

endmodule
