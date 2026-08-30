// cea_linebuf.v
//
// Dual-clock line buffer that decouples the C64/scandoubler pixel domain
// from a CTA-861 compliant HDMI pixel domain.
//
// Why this works without a frame buffer
// -------------------------------------
// The scandoubled C64 line rate and the CTA-861 line rate are identical,
// because both are derived from the same 27 MHz board crystal:
//
//   PAL   source : 31.500 MHz / 1008 = 31 250.000 Hz
//   PAL   CTA    : 27.000 MHz /  864 = 31 250.000 Hz     <- exact match
//
// A two line ping-pong buffer therefore never under- or overruns, and no
// line has to be dropped or repeated.  Only the *pixel clock* changes,
// from 31.5 MHz (1008 clocks per line) to 27 MHz (864 clocks per line),
// which is what turns the wildly non-conformant 288 pixel horizontal
// blanking interval into the 144 pixels the standard asks for.
//
// Frame lock (the important part)
// -------------------------------
// The video_analyzer only issues vreset when the video format CHANGES
// (line length, frame height, screen mode) - not once per frame.  Both
// sides must therefore free-run in lockstep:
//
//   source : src_line clocks/line, src_frame lines/frame (2x the VIC)
//   sink   : hdmi.sv total line count must equal src_frame
//
//   PAL : 31.500 MHz / 1008 = 31 250.000 Hz, 624 lines (2x312)
//         sink: 864 clocks @ 27 MHz, 624 lines  -> exact, zero drift
//   NTSC: 32.940 MHz / 1040 = 31 673.1  Hz, 526 lines (2x263)
//         sink: 852 clocks @ 27 MHz = 31 690.1 Hz (+0.054 %), 526 lines
//
// PAL locks without any drift.  NTSC keeps a small residual slip (about
// one line every 3.6 frames), because the exact 32.7273 MHz
// (27 * 40/33) is not reachable from the 27 MHz crystal with a Gowin
// rPLL (PFD must stay >= 3 MHz).
//
// 2026 - drop-in addition for MiSTle-Dev/C64Nano

module cea_linebuf #(
    parameter integer DWIDTH   = 18,   // 6:6:6 out of scandoubler + OSD
    parameter integer AWIDTH   = 10,   // 2^10 = 1024 >= ACTIVE_W
    parameter integer ACTIVE_W = 720,  // pixels captured per line
    parameter integer ACTIVE_H = 576,  // lines captured per frame
    parameter integer RD_SKEW  = 2     // BRAM + output register latency
)(
    // ---------------- source domain (clk_src = clk_sys) ----------------
    input  wire              clk_src,
    input  wire              vreset_src,   // rare: only on video format changes
    input  wire              ntscmode,     // selects the NTSC source geometry
    input  wire [DWIDTH-1:0] din,

    // ---------------- sink domain (clk_snk = 27 MHz) -------------------
    input  wire              clk_snk,
    output reg               vreset_snk,   // re-synchronised, 1 clk_snk pulse
    input  wire [10:0]       cx,           // sink pixel counter from hdmi.sv
    input  wire [9:0]        cy,           // sink line  counter from hdmi.sv
    output reg  [DWIDTH-1:0] dout
);

// --------------------------------------------------------------------
// storage: two lines, ping-pong.  720 * 18 * 2 = 25 920 bit, the
// GW2AR-18 has 828 kbit of BSRAM.
// --------------------------------------------------------------------
(* ram_style = "block" *)
reg [DWIDTH-1:0] mem [0:(2<<AWIDTH)-1];

// --------------------------------------------------------------------
// write side, source clock domain
//
// source geometry, runtime selected (both clocks derive from the same
// 27 MHz crystal, so the line rates are exact):
//   PAL : 1008 clocks/line, 624 lines/frame   (VIC 312 lines, doubled)
//   NTSC: 1040 clocks/line, 526 lines/frame   (VIC 263 lines, doubled)
wire [11:0] src_line  = ntscmode ? 12'd1040 : 12'd1008;
wire [11:0] src_frame = ntscmode ? 12'd526  : 12'd624;

reg [10:0] wx;
reg [9:0]  wy;
reg        tgl_src = 1'b0;

wire wr_en = (wx < ACTIVE_W) && (wy < ACTIVE_H);

always @(posedge clk_src) begin
    if (vreset_src) begin
        wx      <= 11'd0;
        wy      <= 10'd0;
        tgl_src <= ~tgl_src;
    end else if (wx == src_line - 1) begin
        wx <= 11'd0;
        // wy MUST wrap at the source frame length: the video_analyzer
        // does not issue vreset every frame, so the ping-pong banking
        // only stays aligned when wy and the sink frame counter cycle
        // over the same number of lines (hdmi.sv uses the same totals).
        if (wy == src_frame - 1)
            wy <= 10'd0;
        else
            wy <= wy + 10'd1;
    end else
        wx <= wx + 11'd1;

    if (wr_en)
        mem[{wy[0], wx[AWIDTH-1:0]}] <= din;
end

// --------------------------------------------------------------------
// vreset across the clock boundary
//
// vreset is a single 31.5 MHz cycle (31.7 ns) and the sink clock period
// is 37.0 ns, so level sampling would drop pulses.  Toggle + edge detect
// is immune to that.
// --------------------------------------------------------------------
reg [2:0] tgl_snk;

always @(posedge clk_snk) begin
    tgl_snk    <= {tgl_snk[1:0], tgl_src};
    vreset_snk <= tgl_snk[2] ^ tgl_snk[1];
end

// --------------------------------------------------------------------
// read side, sink clock domain
//
// Sink line r is read while source line r is still being written, so it
// must serve source line r-1, which lives in bank (r-1)[0] == ~r[0].
// Line 0 would fetch the previous frame's last line, so it is blanked;
// one black line at the very top of a 576 line frame sits in the C64
// border and is not visible.
//
// RD_SKEW compensates the BRAM read latency: the address has to lead the
// pixel counter by the number of pipeline stages between here and the
// video_data register in hdmi.sv.  If the image comes out shifted by one
// or two pixels horizontally, this is the knob.
// --------------------------------------------------------------------
wire [10:0] rd_x    = cx + RD_SKEW[10:0];
wire        rd_live = (cy != 10'd0) && (cy < ACTIVE_H) && (rd_x < ACTIVE_W);

always @(posedge clk_snk) begin
    dout <= rd_live ? mem[{~cy[0], rd_x[AWIDTH-1:0]}] : {DWIDTH{1'b0}};
end

endmodule
