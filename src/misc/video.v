// video.v

module video (
          input	   clk,           // C64 / scandoubler domain, 31.5 or 32.94 MHz
          input    clk27,         // CTA-861 pixel clock, 27 MHz
          input    clk27_x5,      // 135 MHz, phase locked to clk27
          input    pll_lock,

          input    ntscmode,
	      input	   vs_in_n,
	      input	   hs_in_n,
          input    de_in,

	      input [3:0]  r_in,
	      input [3:0]  g_in,
	      input [3:0]  b_in,

          input [15:0] audio_l,
          input [15:0] audio_r,

          output osd_status,

          // (spi) interface from MCU
          input	   mcu_start,
          input	   mcu_osd_strobe,
          input [7:0]  mcu_data,

          // values that can be configure by the user via osd          
          input [1:0]  system_scanlines,
          input [2:0]  system_volume,
          input [1:0]  system_screen,
          input    osd_stereo_mix,

	      // hdmi/tdms
	      output	   tmds_clk_n,
	      output	   tmds_clk_p,
	      output [2:0] tmds_d_n,
	      output [2:0] tmds_d_p  
	      );
   



/* -------------------- HDMI video and audio -------------------- */
wire vreset;
wire [1:0] vmode;

video_analyzer video_analyzer (
   .clk(clk),
   .vs(vs_in_n),
   .hs(hs_in_n),
   .de(de_in),
   .screen(system_screen),
   .ntscmode(ntscmode),
   .mode(vmode),
   .vreset(vreset)
);  

wire sd_hs_n, sd_vs_n; 
wire [5:0] sd_r;
wire [5:0] sd_g;
wire [5:0] sd_b;
  
scandoubler #(11) scandoubler (
        // system interface
        .clk_sys(clk),
        .bypass(1'b0),
        .ce_divider(1'b1),
        .pixel_ena(),

        // scanlines (00-none 01-25% 10-50% 11-75%)
        .scanlines(system_scanlines),

        // shifter video interface
        .hs_in(hs_in_n),
        .vs_in(vs_in_n),
        .r_in( r_in ),
        .g_in( g_in ),
        .b_in( b_in ),

        // output interface
        .hs_out(sd_hs_n),
        .vs_out(sd_vs_n),
        .r_out(sd_r),
        .g_out(sd_g),
        .b_out(sd_b)
);

wire [5:0] osd_r;
wire [5:0] osd_g;
wire [5:0] osd_b;  

osd_u8g2 osd_u8g2 (
        .clk(clk),
        .reset(!pll_lock),

        .data_in_strobe(mcu_osd_strobe),
        .data_in_start(mcu_start),
        .data_in(mcu_data),

        .hs(sd_hs_n),
        .vs(sd_vs_n),
		     
        .r_in(sd_r),
        .g_in(sd_g),
        .b_in(sd_b),
		     
        .r_out(osd_r),
        .g_out(osd_g),
        .b_out(osd_b),
        .osd_status(osd_status)
);   

// latch audio, so it's stable during 48khz transfer
reg [15:0] audio_reg [2]; // 16 bit signed audio for HDMI

// Sign-extend inputs to 16-bit BEFORE mixing – intermediate sum
// cannot overflow, result always fits back in 15 bit.
wire signed [15:0] audio_left_s  = {{1{audio_l[14]}}, audio_l};
wire signed [15:0] audio_right_s = {{1{audio_r[14]}}, audio_r};

reg signed [14:0] mixed_audio_left;
reg signed [14:0] mixed_audio_right;
reg signed [14:0] scaled_audio_left;
reg signed [14:0] scaled_audio_right;

// generate 48khz audio clock
`define PIXEL_CLOCK 27000000

localparam [31:0] AUDIO_INC = (64'd48000 <<< 32) / `PIXEL_CLOCK;
reg [31:0] aclk_acc;
reg        clk_audio;
reg        aclk_tick;

always @(posedge clk) begin
    aclk_acc  <= aclk_acc + AUDIO_INC;
    clk_audio <= aclk_acc[31];                 // msb of the accumulator = 48kHz
    aclk_tick <= (clk_audio != aclk_acc[31]);  // high the cycle after each edge

    // The sample word must not change on the same clk_pixel edge that toggles
    // clk_audio: the hdmi module latches it on that very edge, so data and
    // clock would race and the captured word could pick up wrong bits, which
    // is audible as noisy samples. Updating one cycle later leaves the word
    // stable for a full audio half period before it is sampled.
    if(aclk_tick) begin
        // --- Stereo Mix (75/25)-------------------------------------------
        // 16-bit signed wires prevent any overflow; the result
        // always fits in 15 bit and is truncated safely on assignment. 
	    case (osd_stereo_mix)
            1'b0: begin   // no mix
                mixed_audio_left  <= audio_l;
                mixed_audio_right <= audio_r;
            end
            default: begin  // 75 / 25 blend
                mixed_audio_left  <= (audio_left_s  - (audio_left_s  >>> 2))
                                   + (audio_right_s >>> 2);
                mixed_audio_right <= (audio_right_s - (audio_right_s >>> 2))
                                   + (audio_left_s  >>> 2);
            end
        endcase

    // --- Volume scaling ----------------------------------------
        // mixed_audio_* are reg signed [14:0], so >>> is always
        // arithmetic – no $signed() wrapper required.
        case (system_volume) 
            3'b100: begin // 100%
                scaled_audio_left  <= mixed_audio_left;
                scaled_audio_right <= mixed_audio_right;
            end
            3'b011: begin // 75%
                scaled_audio_left  <= (mixed_audio_left  >>> 1) + (mixed_audio_left  >>> 2);
                scaled_audio_right <= (mixed_audio_right >>> 1) + (mixed_audio_right >>> 2);
            end
            3'b010: begin // 50%
                scaled_audio_left  <= mixed_audio_left  >>> 1;
                scaled_audio_right <= mixed_audio_right >>> 1;
            end
            3'b001: begin // 25%
                scaled_audio_left  <= mixed_audio_left  >>> 2;
                scaled_audio_right <= mixed_audio_right >>> 2;
            end
            3'b000: begin // Mute
                scaled_audio_left  <= 15'd0;
                scaled_audio_right <= 15'd0;
            end
            default: begin // fallback 50 %
                scaled_audio_left  <= mixed_audio_left  >>> 1;
                scaled_audio_right <= mixed_audio_right >>> 1;
            end
        endcase

        // --- HDMI audio register ----------------------------------
        // Convert signed two's complement → offset binary:
        // flip sign bit (bit 14).  Bit 15 = 0 (15-bit audio in 16-bit slot).
        // Explicit per-element assignment avoids unpacked-array ambiguity.
        audio_reg[0] <= {scaled_audio_left[14],  scaled_audio_left[14:0]};
        audio_reg[1] <= {scaled_audio_right[14], scaled_audio_right[14:0]};	

    end
end

wire [2:0] tmds;
wire tmds_clock;

/* ---------------- 31.5/32.94 MHz  ->  27 MHz CTA-861 ---------------- */

wire [10:0] cx;
wire [9:0]  cy;
wire        vreset27;
wire [17:0] lb_rgb;

cea_linebuf #(
    .DWIDTH(18),
    .ACTIVE_W(720),
    .ACTIVE_H(576)
) cea_linebuf (
    .clk_src(clk),
    .vreset_src(vreset),
    .ntscmode(ntscmode),
    .din({osd_r, osd_g, osd_b}),

    .clk_snk(clk27),
    .vreset_snk(vreset27),
    .cx(cx),
    .cy(cy),
    .dout(lb_rgb)
);

hdmi #(
   .AUDIO_RATE(48000), 
   .AUDIO_BIT_WIDTH(16),
   .VENDOR_NAME( { "MiSTle", 16'd0} ),
   .PRODUCT_DESCRIPTION( {"C64", 104'd0})
) hdmi(
  .clk_pixel_x5(clk27_x5),
  .clk_pixel(clk27),
  .clk_audio(clk_audio),
  .audio_sample_word( audio_reg ),
  .cx(cx),
  .cy(cy),
  .tmds(tmds),
  .tmds_clock(tmds_clock),

  // video input
  .stmode(vmode),    // current video mode PAL/NTSC/MONO
  .screen(system_screen),
  .reset(vreset27),  // vreset, re-synchronised into the 27 MHz domain
  // Scandoubler outputs 6 bits per colour (to be able to implement dark
  // scanlines), HDMI expects 8. Pixels now arrive via the line buffer.
  .rgb( { lb_rgb[17:12], 2'b00, lb_rgb[11:6], 2'b00, lb_rgb[5:0], 2'b00 } )
);

// differential output
ELVDS_OBUF tmds_bufds [3:0] (
        .I({tmds_clock, tmds}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
);

endmodule
