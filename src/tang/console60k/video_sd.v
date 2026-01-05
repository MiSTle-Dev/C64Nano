// video.v

module video
#(
    parameter bit STEREO = 1'b0
)
 (
          input	   clk,
          input    clk_pixel_x5,
          input    pll_lock,
          input [8:0] audio_div,

          input    ntscmode,

          input    hbl_in,
          input    vbl_in,

          input	   vs_in_n,
          input	   hs_in_n,

          input [3:0]  r_in,
          input [3:0]  g_in,
          input [3:0]  b_in,

          input [17:0] audio_l,
          input [17:0] audio_r,

          output osd_status,

          // (spi) interface from MCU
          input	   mcu_start,
          input	   mcu_osd_strobe,
          input [7:0]  mcu_data,

          // values that can be configure by the user via osd          
          input [1:0]  system_scanlines,
          input [1:0]  system_volume,
          input	       system_wide_screen,
          // digital video out for lcd
          output lcd_clk,
          output lcd_hs_n,
          output lcd_vs_n,
          output reg lcd_de,
          output [7:0] lcd_r,
          output [7:0] lcd_g,
          output [7:0] lcd_b,
          output lcd_bl,

         // audio
          output hp_bck,
          output hp_ws,
          output hp_din,
          output pa_en
 );

/* -------------------- HDMI video and audio -------------------- */

// generate 48khz audio clock
reg clk_audio;

reg [8:0] aclk_cnt;

always @(posedge clk) begin
    // divisor = pixel clock / 48000 / 2 - 1
    if(aclk_cnt < audio_div)
        aclk_cnt <= aclk_cnt + 9'd1;
    else begin
        aclk_cnt <= 9'd0;
        clk_audio <= ~clk_audio;
    end
end

wire sd_hs_n, sd_vs_n;
wire hb_out, vb_out;
wire [5:0] sd_r;
wire [5:0] sd_g;
wire [5:0] sd_b;
  
scandoubler #(11) scandoubler (
        // system interface
        .clk_sys(clk),
        .bypass(1'b0),
        .ce_divider(3'd1),
        .pixel_ena(),

        // scanlines (00-none 01-25% 10-50% 11-75%)
        .scanlines(system_scanlines),

        // shifter video interface
        .hb_in(hbl_in),
        .vb_in(vbl_in),
        .hs_in(hs_in_n),
        .vs_in(vs_in_n),
        .r_in( r_in ),
        .g_in( g_in ),
        .b_in( b_in ),

        // output interface
        .hb_out(hb_out),
        .vb_out(vb_out),
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

wire [2:0] tmds;
wire tmds_clock;

// Audio c64 core specific
reg [15:0] alo,aro;
always @(posedge clk) begin
	reg [16:0] alm,arm;

	arm <= {audio_r[17],audio_r[17:2]};
	alm <= {audio_l[17],audio_l[17:2]};
	alo <= ^alm[16:15] ? {alm[16], {15{alm[15]}}} : alm[15:0];
	aro <= ^arm[16:15] ? {arm[16], {15{arm[15]}}} : arm[15:0];
end

// scale audio for valume by signed division
wire [15:0] audio_vol_l = 
    (system_volume == 2'd0)?16'd0:
    (system_volume == 2'd1)?{ {2{alo[15]}}, alo[15:2] }:
    (system_volume == 2'd2)?{ alo[15], alo[15:1] }:
    alo;

wire [15:0] audio_vol_r = 
    (system_volume == 2'd0)?16'd0:
    (system_volume == 2'd1)?{ {2{aro[15]}}, aro[15:2] }:
    (system_volume == 2'd2)?{ aro[15], aro[15:1] }:
    aro;


reg i2s_clk;
reg [7:0] i2s_clk_cnt;
always @(posedge clk or negedge pll_lock) begin
    if (~pll_lock) begin
        i2s_clk_cnt <= 8'd0;
        i2s_clk <= 1'b0;
        end
    else begin
       if(i2s_clk_cnt < (ntscmode?32500000:31500000) / (24000*32) / 2 - 1)
            i2s_clk_cnt <= i2s_clk_cnt + 8'd1;
        else begin
            i2s_clk_cnt <= 8'd0;
            i2s_clk <= ~i2s_clk;
        end
    end
end

// sign expand and add both channels
wire [15:0] audio_mix = { audio_vol_l[14], audio_vol_l} + { audio_vol_r[14], audio_vol_r };

// shift audio down to reduce amp output volume to a sane range
localparam AUDIO_SHIFT = (STEREO)?2:3;   // 2 TM138k / TM60k and 3 // TN20k
wire [15:0] audio_scaled = { { AUDIO_SHIFT+1{audio_mix[15]}}, audio_mix[14:AUDIO_SHIFT] };
 
// count 32 bits, 16 left and 16 right channel. MAX samples
// on rising edge
reg [15:0] audio;
reg [4:0] audio_bit_cnt;
always @(posedge i2s_clk) begin
   if(!pll_lock) audio_bit_cnt <= 5'd0;
   else          audio_bit_cnt <= audio_bit_cnt + 5'd1;
    // latch data so it's stable during transmission
    if(audio_bit_cnt == 5'd31)
     audio <= audio_scaled;
end

// generate i2s signals
assign hp_bck = !i2s_clk;
assign hp_ws = !pll_lock?1'b0:audio_bit_cnt[4];
assign hp_din = !pll_lock?1'b0:audio[15-audio_bit_cnt[3:0]];
assign pa_en = (STEREO)?~pll_lock:pll_lock; // TM138/60k enable amplifier 0=on and 1= off, TN20k vice versa

assign lcd_clk = clk;
assign lcd_hs_n = sd_hs_n;
assign lcd_vs_n = sd_vs_n;
assign lcd_bl = pll_lock;
assign lcd_r = {osd_r,2'b00};
assign lcd_g = {osd_g,2'b00};
assign lcd_b = {osd_b,2'b00};

reg [10:0] hcnt; // max 1040
reg [9:0] vcnt;  // max 624

// generate lcd de signal
localparam XNTSC = 11'd1850;
localparam YNTSC = 10'd980;
localparam XPAL  = 11'd1880;
localparam YPAL  = 10'd940;

//assign lcd_de = (hcnt < 11'd800) && (vcnt < 10'd480);

// after scandoubler (with dim lines), ste video is 3*6 bits
// lcd r and b are only 5 bits, so there may be some color
// offset

always @(posedge clk) begin
   reg last_vs_n, last_hs_n;

   last_hs_n <= lcd_hs_n;

   // rising edge/end of hsync
   if(lcd_hs_n && !last_hs_n) begin
      hcnt <= (ntscmode)?XNTSC:XPAL;
      
      last_vs_n <= lcd_vs_n;
      if(lcd_vs_n && !last_vs_n) begin
        vcnt <= (ntscmode)?YNTSC:YPAL;
      end else
	vcnt <= vcnt + 10'd1;
   end else
      hcnt <= hcnt + 11'd1;
end

reg old_hde;
always @(posedge clk) begin
		old_hde <= !hb_out;
		if(old_hde ^ !hb_out) lcd_de <= !vb_out & !hb_out;
	end

endmodule

