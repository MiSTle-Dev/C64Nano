// ----------------------------------------------------------------------------
// This file is part of reDIP SID, a MOS 6581/8580 SID FPGA emulation platform.
// Copyright (C) 2022  Dag Lem <resid@nimrod.no>
//
// This source describes Open Hardware and is licensed under the CERN-OHL-S v2.
//
// You may redistribute and modify this source and make products using it under
// the terms of the CERN-OHL-S v2 (https://ohwr.org/cern_ohl_s_v2.txt).
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
// PARTICULAR PURPOSE. Please see the CERN-OHL-S v2 for applicable conditions.
//
// Source location: https://github.com/daglem/reDIP-SID
// ----------------------------------------------------------------------------



// Clamp to 16 bits.
function sid::s16_t clamp(sid::s17_t x);
    unique case (x[16:15])
      2'b10: clamp = -32768;
      2'b01: clamp =  32767;
      default:
             clamp =  x[15:0];
    endcase
endfunction

// Clamp index to [-1023, 1023].
// A simple bit check cannot be used since -1024 must not be included.
function sid::s11_t tanh_x_clamp(sid::s13_t x);
    tanh_x_clamp = 11'((x < -1023) ? -1023 :
                   (x >  1023) ?  1023 :
                   11'(x));
endfunction

// We take advantage of the fact that tanh(-x) = -tanh(x) to access table data
// for x >= 0 only.
function sid::reg10_t tanh_x_mirror(sid::s11_t x);
    tanh_x_mirror = 10'(x < 0 ? -x : x);
endfunction

function sid::s16_t tanh_y_mirror(logic x_neg, sid::s16_t y);
    tanh_y_mirror = x_neg ? -y : y;
endfunction


module sid_filter #(
    // The 6581 DC offset is approximately -1/18 of the dynamic range of one voice.
    localparam MIXER_DC_6581 = 24'(-(1 << 20)/18),
    localparam MIXER_DC_8580 = 24'(0),
    localparam PI = $acos(-1.0)
)(
    input  logic           clk,
    input  logic [2:0]     stage,
    input  sid::filter_i_t filter_i,
    output sid::s20_t      audio_o
);

    // MOS6581 filter cutoff: 200Hz - 24.2kHz (from cutoff curves below)
    // For reference, the datasheet specifies 30Hz - 12kHz.
    //
    // Max w0 = 2*pi*24200 = 152053.
    // In the filter, we must calculate w0*T for a ~1MHz clock.
    // 1.048576/(2^3)*w0 corresponds to 2^17*w0*T, since T =~ 1/1000000,
    // and 2^(3 + 17) = 1048576.
    // This scaled w0*T fits in a signed 16 bit register.
    //
    // As a first approximation, we use filter cutoff curves.
    // Several measurements of such curves can be found at
    // https://bel.fi/alankila/c64-sw/fc-curves/
    //
    // The curves can be approximated quite well by the following formula:
    //
    // fc_curve(fc,b,d) = b + 12000*(1 + tanh((fc_dac(fc) - (1024 + 512 + d))/350.0))
    //
    // - fc is the value of the FC register (x direction)
    // - b is the base cutoff frequency, shifting the curve in the y direction
    // - fc_dac(fc) is the output from the discontinuous filter cutoff DAC
    // - 1024 + 512 shifts the curve to match the average 6581 filter curve
    // - d further shifts the curve in the x direction, to model any chip
    //
    // Example filter curves:
    //
    // Follin-style: fc_curve(x, 240, -785)
    // Galway-style: fc_curve(x, 280, -405)
    // Average     : fc_curve(x, 250,    0)
    // Strong      : fc_curve(x, 260, +400)
    // Extreme     : fc_curve(x, 200, +760)
    //

    sid::reg11_t fc;
    sid::reg11_t fc_6581;

    sid::s16_t w0_T_lsl17_8580;
    sid::s16_t w0_T_lsl17_6581;
    sid::s16_t w0_T_lsl17_6581_base = 0;

    // Since tanh(-x) = -tanh(x), we store table data for x >= 0 only, and use
    // the functions tanh_x_mirror and tanh_y_mirror for mirroring.
    sid::s16_t w0_T_lsl17_6581_tanh[1024];
    sid::s16_t w0_T_lsl17_6581_y0;
    initial begin
        for (int i = 0; i < 1024; i++) begin
            w0_T_lsl17_6581_tanh[i] = 16'($rtoi(1.048576/8*2*PI*12000*$tanh(i/350.0) + 0.5));
        end
        // NB! Can't lookup from table here, as this precludes the use of BRAM.
        // w0_T_lsl17_6581_y0 = w0_T_lsl17_6581_tanh[0];
        w0_T_lsl17_6581_y0 = 16'($rtoi(1.048576/8*2*PI*12000*1 + 0.5));
    end

    // MOS8580 filter cutoff: 0 - 12.5kHz.
    // Max w0 = 2*pi*12500 = 78540
    // We us the same scaling factor for w0*T as above.
    // The maximum value of the scaled w0*T is 1.048576/8*2*pi*12500 = 10294,
    // which is approximately 5 times the maximum fc (2^11 - 1 = 2047),
    // and may be calculated as 5*fc = 4*fc + fc (shift and add).

    // MOS6581 filter cutoff DAC output.
    sid_dac #(
        .BITS(11)
    ) fc_dac (
        .vin  (fc),
        .vout (fc_6581)
    );

    // Filter resonance.
    //
    // From die photographs, assuming ideal op-amps:
    //
    // MOS6581: 1/Q =~ ~res/8
    // MOS8580: 1/Q =~ 2^((4 - res)/8)
    //
    // The actual range of 1/Q in the MOS6581 is quite different, partly
    // because of low gain op-amps. For now, we use the formula from reSID 0.16.
    //
    // The values are multiplied by 1024 (1 << 10).
    // The coefficient 1024 is dispensed of later by right-shifting 10 times.
    sid::reg11_t _1_Q_lsl10;
    sid::reg11_t _1_Q_6581_lsl10[16];
    sid::reg11_t _1_Q_8580_lsl10[16];
    initial begin
        for (int res = 0; res < 16; res++) begin
            _1_Q_6581_lsl10[res] = 11'($rtoi(1024.0/(0.707 + res/15.0) + 0.5));
            _1_Q_8580_lsl10[res] = 11'($rtoi(1024.0*$pow(2.0, (4.0 - res)/8.0) + 0.5));
        end
    end

    sid::s16_t vi = 0;
    sid::s16_t vd = 0;

    sid::reg4_t mode = 0;
    sid::reg4_t vol  = 0;

    // Hardware 16x16->32 multiply-add:
    // o = c +- (a * b)

    sid::s32_t c = 0;
    logic      s = 0;
    sid::s16_t a = 0;
    sid::s16_t b = 0;
    wire signed [31:0] m = a * b;
    wire signed [31:0] o = s ? (c - m) : (c + m);

    // Filter states for two SID chips, updated as follows:
    // vlp = vlp - w0*vbp
    // vbp = vbp - w0*vhp
    // vhp = 1/Q*vbp - vlp - vi
    sid::s16_t vlp, vlp2, vlp_next;
    sid::s16_t vbp, vbp2, vbp_next;
    sid::s16_t vhp, vhp2, vhp_next;
    sid::s17_t dv;

    sid::reg11_t fc_x;

    always_comb begin
        // Filter cutoff register value.
        fc = { filter_i.regs.fc_hi, filter_i.regs.fc_lo[2:0] };

        // Intermediate results for filter.
        // Shifts -w0*vbp and -w0*vlp right by 17.
        dv       = 17'(o >>> 17);
        vlp_next = clamp(vlp + dv);
        vbp_next = clamp(vbp + dv);
        vhp_next = clamp(o[10 +: 17]);
    end

    always_ff @(posedge clk) begin
        case (stage)
          1: begin
              // MOS6581: w0 = filter curve
              // 1.048576/8*fc_base is approximated by fc_base >> 3.
              w0_T_lsl17_6581_base <= { 10'b0, filter_i.fc_base[8:3] };
              // We have to register fc_x in order to meet timing.
              fc_x <= tanh_x_clamp(signed'(13'(fc_6581)) - filter_i.fc_offset);

              // MOS8580: w0 = 5*fc = 4*fc + fc
              w0_T_lsl17_8580 <= { 3'b0, fc, 2'b0 } + { 5'b0, fc };

              // MOS6581: 1/Q =~ ~res/8 (not used - op-amps are not ideal)
              // MOS8580: 1/Q =~ 2^((4 - res)/8)
              _1_Q_lsl10 <= (filter_i.model == sid::MOS6581) ?
                            _1_Q_6581_lsl10[filter_i.regs.res] :
                            _1_Q_8580_lsl10[filter_i.regs.res];

              // Mux for filter path.
              // Each voice is 22 bits, i.e. the sum of four voices is 24 bits.
              vi <= 16'((((filter_i.regs.filt[0]) ? 24'(filter_i.voice1) : '0) +
                         ((filter_i.regs.filt[1]) ? 24'(filter_i.voice2) : '0) +
                         ((filter_i.regs.filt[2]) ? 24'(filter_i.voice3) : '0) +
                         ((filter_i.regs.filt[3]) ? 24'(filter_i.ext_in) : '0)) >>> 7);

              // Mux for direct audio path.
              // 3 OFF (mode[3]) disconnects voice 3 from the direct audio path.
              // We add in the mixer DC here, to save time in calculation of
              // the final audio sum.
              vd <= 16'((((filter_i.model == sid::MOS6581) ?
                          MIXER_DC_6581 :
                          MIXER_DC_8580) +
                         (filter_i.regs.filt[0] ? '0 : 24'(filter_i.voice1)) +
                         (filter_i.regs.filt[1] ? '0 : 24'(filter_i.voice2)) +
                         (filter_i.regs.filt[2] |
                          filter_i.regs.mode[3] ? '0 : 24'(filter_i.voice3)) +
                         (filter_i.regs.filt[3] ? '0 : 24'(filter_i.ext_in))) >>> 7);

              // Save settings to facilitate expedited filter pipeline setup.
              mode <= filter_i.regs.mode;
              vol  <= filter_i.regs.vol;
          end
          2: begin
              // Read from BRAM.
              w0_T_lsl17_6581 <= w0_T_lsl17_6581_tanh[tanh_x_mirror(fc_x)];
          end
          3: begin
              // vlp = vlp - w0*vbp
              // We first calculate -w0*vbp
              c <= 0;
              s <= 1'b1;
              a <= (filter_i.model == sid::MOS6581) ?
                   w0_T_lsl17_6581_base + w0_T_lsl17_6581_y0 + tanh_y_mirror(fc_x[10], w0_T_lsl17_6581) :
                   w0_T_lsl17_8580;   // w0*T << 17
              b <= vbp;               // vbp
          end
          4: begin
              // Result for vlp ready. See calculation of vlp_next above.
              { vlp, vlp2 } <= { vlp2, vlp_next };

              // vbp = vbp - w0*vhp
              // We first calculate -w0*vhp
              c <= 0;
              s <= 1'b1;
              // a <= a;              // w0*T << 17
              b <= vhp;               // vhp
          end
          5: begin
              // Result for vbp ready. See calculation of vbp_next above.
              { vbp, vbp2 } <= { vbp2, vbp_next };

              // vhp = 1/Q*vbp - vlp - vi
              c <= -(32'(vlp2) + 32'(vi)) << 10;
              s <= 1'b0;
              a <= 16'(_1_Q_lsl10);   // 1/Q << 10
              b <= vbp_next;          // vbp
          end
          6: begin
              // Result for vbp ready. See calculation of vhp_next above.
              { vhp, vhp2 } <= { vhp2, vhp_next };

              // Audio output: aout = vol*amix
              // In the real SID, the signal is inverted first in the mixer
              // op-amp, and then again in the volume control op-amp.
              c <= 0;
              s <= 1'b0;
              a <= { 12'b0, vol };    // Master volume
              b <=  clamp(17'(vd) +   // Audio mixer / master volume input
                          (mode[0] ? 17'(vlp2)     : '0) +
                          (mode[1] ? 17'(vbp2)     : '0) +
                          (mode[2] ? 17'(vhp_next) : '0));
          end
          7: begin
              // Final result for audio output ready.
              // The effective width is 20 bits (4 bit volume * 16 bit audio).
              audio_o <= o[19:0];
          end
        endcase
    end
endmodule
