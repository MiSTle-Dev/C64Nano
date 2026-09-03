// video.v

module video (
          input	   clk,
          input    clk_pixel_x5,
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
          input        osd_stereo_mix,

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

wire signed [15:0] audio_left_s  = $signed(audio_l) >>> 1;
wire signed [15:0] audio_right_s = $signed(audio_r) >>> 1;

logic signed [14:0] mixed_audio_left;
logic signed [14:0] mixed_audio_right;
logic signed [14:0] scaled_audio_left;
logic signed [14:0] scaled_audio_right;

always_comb begin
    if (!osd_stereo_mix) begin
        mixed_audio_left  = $signed(audio_l) >>> 1;
        mixed_audio_right = $signed(audio_r) >>> 1;
    end
    else begin
        mixed_audio_left  = (audio_left_s  - (audio_left_s  >>> 2))
                          + (audio_right_s >>> 2);
        mixed_audio_right = (audio_right_s - (audio_right_s >>> 2))
                          + (audio_left_s >>> 2);
    end

    case (system_volume)
        3'b100: begin
            scaled_audio_left  = mixed_audio_left;
            scaled_audio_right = mixed_audio_right;
        end
        3'b011: begin
            scaled_audio_left  = (mixed_audio_left  >>> 1) + (mixed_audio_left  >>> 2);
            scaled_audio_right = (mixed_audio_right >>> 1) + (mixed_audio_right >>> 2);
        end
        3'b010: begin
            scaled_audio_left  = mixed_audio_left  >>> 1;
            scaled_audio_right = mixed_audio_right >>> 1;
        end
        3'b001: begin
            scaled_audio_left  = mixed_audio_left  >>> 2;
            scaled_audio_right = mixed_audio_right >>> 2;
        end
        default: begin
            scaled_audio_left  = 15'sd0;
            scaled_audio_right = 15'sd0;
        end
    endcase
end

// Generate the audio clock with a regular divider. HDMI captures samples on
// the rising edge of clk_audio; samples are updated on its falling edge and
// remain stable for the following capture.
logic [8:0] audio_divider;
logic [8:0] audio_divider_counter;
logic      clk_audio;
always_comb begin
    if (ntscmode)
        audio_divider = 9'd342; // 343 clk cycles, 32.94 MHz NTSC
    else
        audio_divider = 9'd327; // 328 clk cycles, 31.50 MHz PAL
end

always @(posedge clk) begin
    if (!pll_lock) begin
        audio_divider_counter <= 9'd0;
        clk_audio <= 1'b0;
        audio_reg[0] <= 16'd0;
        audio_reg[1] <= 16'd0;
    end
    else if (audio_divider_counter < audio_divider) begin
        audio_divider_counter <= audio_divider_counter + 9'd1;
    end
    else begin
        audio_divider_counter <= 9'd0;
        if (clk_audio) begin
            clk_audio <= 1'b0;

            // Register the processed signed PCM sample for HDMI.
            audio_reg[0] <= {scaled_audio_left[14], scaled_audio_left[14:0]};
            audio_reg[1] <= {scaled_audio_right[14], scaled_audio_right[14:0]};
        end
        else begin
            clk_audio <= 1'b1;
        end
    end
end

wire [2:0] tmds;
wire tmds_clock;

hdmi #(
   .AUDIO_RATE(48000), 
   .AUDIO_BIT_WIDTH(16),
   .VENDOR_NAME( { "MiSTle", 16'd0} ),
   .PRODUCT_DESCRIPTION( {"C64", 104'd0})
) hdmi(
  .clk_pixel_x5(clk_pixel_x5),
  .clk_pixel(clk),
  .clk_audio(clk_audio),
  .audio_sample_word( audio_reg ),
  .tmds(tmds),
  .tmds_clock(tmds_clock),

  // video input
  .stmode(vmode),    // current video mode PAL/NTSC/MONO
  .screen(system_screen),
  .reset(vreset),    // signal to synchronize HDMI
  // Atari STE outputs 4 bits per color. Scandoubler outputs 6 bits (to be
  // able to implement dark scanlines) and HDMI expects 8 bits per color
  .rgb( { osd_r, 2'b00, osd_g, 2'b00, osd_b, 2'b00 } )
);

// differential output
ELVDS_OBUF tmds_bufds [3:0] (
        .I({tmds_clock, tmds}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
);

endmodule
