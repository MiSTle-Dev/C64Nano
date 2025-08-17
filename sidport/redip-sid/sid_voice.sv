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



`include "sid_waveform_PST.svh"
`include "sid_waveform__ST.svh"

// Waveform selector, voice DCA (digitally controlled amplifier).
// Modeling of non-linearities in MOS6581 waveform and envelope DACs.
module sid_voice #(
    localparam WAVEFORM_DC_6581 = -16'sh380,   // OSC3 = 'h38 at 5.94V.
    localparam WAVEFORM_DC_8580 = -16'sh800,   // No DC offsets in the MOS8580.
    localparam VOICE_DC_6581    = 32'('h340*'hff), // Measured from samples.
    localparam VOICE_DC_8580    = 32'h0,      // No DC offsets in the MOS8580.
    localparam WF_0_TTL_6581    = 13'd200,  // Waveform 0 TTL ~200ms
    localparam WF_0_TTL_8580    = 13'd5000  // Waveform 0 TTL ~5s
)(
    input  logic          clk,
    input  logic          tick_ms,
    input  logic          active,
    input  sid::model_e   model,
    input  sid::voice_i_t voice_i,
    // The outputs are delayed by 1 cycle.
    output sid::s22_t     voice_o,
    output sid::reg8_t    osc_o
);

    // Registered values for pipelined calculation.
    sid::model_e model_prev    = sid::MOS6581;
    logic        pulse_prev    = 0;
    sid::reg4_t  selector_prev = 0;

    // Pre-calculated waveforms for waveform selection.
    sid::reg12_t norm;          // Selected regular waveform
    sid::reg12_t norm_6581;     // Output from 6581 waveform DAC
    sid::reg12_t norm_dac = 0;  // 6581 / 8580 result
    sid::reg12_t norm_osc = 0;  // For OSC3
    sid::reg12_t wave_osc;      // Resulting waveform
    sid::reg8_t  comb;          // Selected combined waveform
    sid::reg8_t  pst      = 0;  // Combined waveforms
    sid::reg8_t  ps__6581 = 0;
    sid::reg8_t  ps__8580 = 0;
    sid::reg8_t  p_t_6581 = 0;
    sid::reg8_t  p_t_8580 = 0;
    sid::reg8_t  _st      = 0;

    // Output from non-linear 6581 envelope DAC.
    sid::reg8_t env_6581;

    // Inputs to voice DCA.
//    sid::s32_t voice_DC;
//    sid::s16_t wave_dac;
//    sid::s16_t env_dac  = 0;
    // Output from voice DCA.
    /* verilator lint_off UNUSED */
//    sid::s32_t voice_res;
    /* verilator lint_on UNUSED */

    // Waveform 0 value and age.
    /* verilator lint_off LITENDIAN */
    // FIXME: Yosys doesn't support multidimensional packed arrays outside
    // of structs, nor arrays of structs.
    struct packed {
        logic [0:5][12:0] age;
        logic [0:5][11:0] value;
    } waveform_0;
    /* verilator lint_on LITENDIAN */

    logic [12:0] waveform_0_age = 0;
    logic [11:0] waveform_0_value;
    logic        waveform_0_faded;

    // Combined waveform lookup tables.
    sid::reg8_t sid_waveform_PS__6581[2048];
    sid::reg8_t sid_waveform_PS__8580[4096];
    sid::reg8_t sid_waveform_P_T_6581[2048];
    sid::reg8_t sid_waveform_P_T_8580[2048];

    // MOS6581 waveform DAC output.
    sid_dac #(
        .BITS (12)
    ) waveform_dac (
        .vin  (norm),
        .vout (norm_6581)
    );

    // MOS6581 envelope DAC output.
    sid_dac #(
        .BITS (8)
    ) envelope_dac (
        .vin  (voice_i.envelope),
        .vout (env_6581)
    );

    // Voice DCA (digitally controlled amplifier).
    // voice_res = voice_DC + waveform*envelope
    // The result fits in 22 bits.

    // Registered inputs to voice DCA.
    sid::s32_t voice_DC  = 0;
    sid::s16_t wave_dac = 0;
    sid::s16_t env_dac = 0;

    // Voice DCA (digitally controlled amplifier).
    // dca_out = dca_DC + wav_dac*env_dac
    // The result fits in 22 bits.
    // o = c + (a * b)
    wire signed [31:0] m = wave_dac * env_dac;
    wire signed [31:0] voice_res = voice_DC + m;

    always_comb begin
        // With respect to the oscillator, the waveform cycle delays are:
        // * saw_tri: 0 (6581) / 1 (8580)
        // * pulse:   1
        // * noise:   2

        // Regular waveforms are computed on cycle 1. These are passed through
        // the non-linear MOS6581 waveform DAC.
        // The result for pulse is identical, but we include it for simplicity.
        // All combined waveforms which include noise output zero after a few
        // cycles.
        unique case (voice_i.waveform.selector)
          'b1000:  norm = { voice_i.waveform.noise, 4'b0 };
          'b0100:  norm = { 12{voice_i.waveform.pulse} };
          'b0010:  norm = voice_i.waveform.saw_tri;
          'b0001:  norm = { voice_i.waveform.saw_tri[10:0], 1'b0 };
          'b0000:  norm = waveform_0.value[0];
          default: norm = 0;
        endcase

        // Final waveform selection on cycle 2.
        // All inputs to the combinational logic are from cycle 1.
        unique case (selector_prev)
          'b0111:  comb = pst & { 8{pulse_prev} };
          'b0110:  comb = ((model_prev == sid::MOS6581) ? ps__6581 : ps__8580) & { 8{pulse_prev} };
          'b0101:  comb = ((model_prev == sid::MOS6581) ? p_t_6581 : p_t_8580) & { 8{pulse_prev} };
          'b0011:  comb = _st;
          default: comb = 0;
        endcase

        // Setup for voice DCA multiply-add, ready on cycle 2.
        voice_DC = (model_prev == sid::MOS6581) ?
                   VOICE_DC_6581 :
                   VOICE_DC_8580;
        wave_dac = 16'({ norm_dac | { comb, 4'b0 } }) +
                   ((model_prev == sid::MOS6581) ?
                    WAVEFORM_DC_6581 :
                    WAVEFORM_DC_8580);

        wave_osc = norm_osc | { comb, 4'b0 };

        // Update of waveform 0 for next cycle.
        waveform_0_faded = waveform_0_age == ((model_prev == sid::MOS6581) ? WF_0_TTL_6581 : WF_0_TTL_8580);
        waveform_0_value = selector_prev == 'b0000 && waveform_0_faded ? 0 : wave_osc;

        // The outputs are delayed by 1 cycle.
        osc_o   = wave_osc[11 -: 8];
        // The DCA output fits in 22 bits.
        voice_o = voice_res[21:0];
    end

    always_ff @(posedge clk) begin
        if (active) begin
            // Cycle 1: Register all candidate waveforms, to synchronize with
            // output from BRAM, and deliver one result per cycle from a pipeline.

            // For pipelined selection of waveform.
            model_prev    <= model;
            pulse_prev    <= voice_i.waveform.pulse;
            selector_prev <= voice_i.waveform.selector;

            // Regular waveforms, passed through the non-linear MOS6581
            // waveform DAC.
            norm_dac <= (model == sid::MOS6581) ?
                        norm_6581 :
                        norm;
            // For OSC3.
            norm_osc <= norm;

            // Combined waveforms.
            // These aren't accurately modeled in the analog domain, so passing
            // them through the non-linear MOS6581 DAC wouldn't make much sense.
            // Skipping this avoids further muxing, and speeds up the design.
            // NB! Waveform 0 is currently passed through the DAC, even if it
            // originated as a combined waveform.
            pst      <= sid_waveform_PST(model, voice_i.waveform.saw_tri);
            ps__6581 <= sid_waveform_PS__6581[voice_i.waveform.saw_tri[10:0]];
            ps__8580 <= sid_waveform_PS__8580[voice_i.waveform.saw_tri];
            p_t_6581 <= sid_waveform_P_T_6581[voice_i.waveform.saw_tri[10:0]];
            p_t_8580 <= sid_waveform_P_T_8580[voice_i.waveform.saw_tri[10:0]];
            _st      <= sid_waveform__ST(model, voice_i.waveform.saw_tri);

            // Update of waveform 0.
            waveform_0_age   <= 13'(voice_i.waveform.selector == 'b0000 ? waveform_0.age[0] + { 12'b0, tick_ms } : 0);
            waveform_0.age   <= { waveform_0.age[1:5],   waveform_0_age   };
            waveform_0.value <= { waveform_0.value[1:5], waveform_0_value };

            // Setup for voice DCA multiply-add, ready on cycle 2.
            env_dac  <= (model == sid::MOS6581) ?
                        16'(env_6581) :
                        16'(voice_i.envelope);
        end
    end

    // od -An -tx1 -v reSID/src/wave6581_PS_.dat | head -128 | cut -b2- > sid_waveform_PS__6581.hex
    // od -An -tx1 -v reSID/src/wave8580_PS_.dat |             cut -b2- > sid_waveform_PS__8580.hex
    // od -An -tx1 -v reSID/src/wave6581_P_T.dat | head -128 | cut -b2- > sid_waveform_P_T_6581.hex
    // od -An -tx1 -v reSID/src/wave8580_P_T.dat | head -128 | cut -b2- > sid_waveform_P_T_8580.hex
    initial begin
        $readmemh("sid_waveform_PS__6581.hex", sid_waveform_PS__6581);
        $readmemh("sid_waveform_PS__8580.hex", sid_waveform_PS__8580);
        $readmemh("sid_waveform_P_T_6581.hex", sid_waveform_P_T_6581);
        $readmemh("sid_waveform_P_T_8580.hex", sid_waveform_P_T_8580);
    end
endmodule
