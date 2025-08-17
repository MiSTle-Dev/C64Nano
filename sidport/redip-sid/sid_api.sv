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




module sid_api #(
    // FC offset for average 6581 filter curve.
    localparam FC_OFFSET_6581 = 12'sh600
)(
    input  logic clk,
    input  logic [4:0] addr,
    input  logic [7:0] data_i,
    input  logic phi2,
    input  logic we,
    input  logic reset,
    input  logic [1:0]cs,
    output logic [7:0] data_o,
    input  logic [7:0] pot_x_l,
    input  logic [7:0] pot_y_l,
    input  logic [7:0] pot_x_r,
    input  logic [7:0] pot_y_r,
    input  logic mode,
	input  logic signed [10:0] fc_offset_l,
	input  logic signed [10:0] fc_offset_r,
    input  logic [8:0] fc_base_l,
    input  logic [8:0] fc_base_r,
    output logic signed [23:0] audio_o_l,
    output logic signed [23:0] audio_o_r,
    input  logic signed [23:0] audio_i_l,
    input  logic signed [23:0] audio_i_r
);

    sid::bus_i_t bus_i;
    sid::pot_o_t pot_o;
    sid::audio_t audio_i;
    sid::audio_t audio_o;
    sid::cfg_t sid1_cfg;
    sid::cfg_t sid2_cfg;
    sid::model_e model;

    always_comb begin
        audio_o_l = audio_o.left;
        audio_o_r = audio_o.right;
        audio_i.left = audio_i_l;
        audio_i.right = audio_i_r;

        bus_i.addr = addr;
        bus_i.data = data_i;
        bus_i.we = we;
        bus_i.oe = ~we;
        bus_i.res = reset;

        sid1_cfg.model = mode ? sid::MOS8580 : sid::MOS6581;
        sid1_cfg.addr = '0;
        sid1_cfg.fc_base = fc_base_l;
        sid1_cfg.fc_offset = fc_offset_l;

        sid2_cfg.model = mode ? sid::MOS8580 : sid::MOS6581;
        sid2_cfg.addr = '0;
        sid2_cfg.fc_base = fc_base_r;
        sid2_cfg.fc_offset = fc_offset_r;
    end

    // SID core clock phase.
    logic        phi2_prev = 0;
    (* onehot *)
    sid::phase_t phase     = 0;

    always_ff @(posedge clk) begin
        phi2_prev <= phi2;
        phase     <= { phase[1:0], phi2_prev & ~phi2 };
    end

    // Tick approximately every ms, for smaller counters in submodules.
    // ~1MHz / 1024 = ~1kHz
    logic  [9:0]  timer = 0;
    logic [10:0]  timer_next;
    logic         timer_tick;

    always_comb begin
        // Use carry as tick.
        timer_next = { 1'b0, timer } + 1;
        timer_tick = timer_next[10];
    end

    always_ff @(posedge clk) begin
        if (phase[sid::PHI2]) begin
            // Update timer, discarding carry.
            timer <= timer_next[9:0];
        end
    end

    // sid::cfg_t sid_cfg = '{ sid1_model: ... };
//`ifdef SID2
//    sid::cfg_t  sid1_cfg = { sid::MOS8580, sid::D400, 9'd250, 11'sd0 };
//    sid::cfg_t  sid2_cfg = { sid::MOS8580, sid::D420 | sid::D500 | sid::DE00, 9'd250, 11'sd0 };
//`else
//    sid::cfg_t  sid1_cfg = { sid::MOS6581, sid::D400, 9'd250, 11'sd0 };
//    sid::cfg_t  sid2_cfg = { sid::MOS6581, sid::D400, 9'd250, 11'sd0 };
//`endif

    // NB! Don't put multi-bit variables in arrays, as Yosys handles that incorrectly.
    sid::reg8_t sid1_data_o, sid2_data_o;

    // Digital outputs from SID cores.
    sid::core_o_t core1_o,   core2_o;
    sid::reg8_t   sid1_osc3, sid2_osc3;

    // SID core #1.
    sid_core sid1 (
        .clk     (clk),
        .tick_ms (timer_tick),
        .model   (sid1_cfg.model),
        .bus_i   (bus_i),
        .phase   (phase),
        .cs      (cs[0]),
        .data_o  (sid1_data_o),
        .pot_x   (pot_x_l),
        .pot_y   (pot_y_l),
        .out     (core1_o),
        .osc3    (sid1_osc3)
    );

    // SID core #2 - no POT pins.
    sid_core sid2 (
        .clk     (clk),
        .tick_ms (timer_tick),
        .model   (sid2_cfg.model),
        .bus_i   (bus_i),
        .phase   (phase),
        .cs      (cs[1]),
        .data_o  (sid2_data_o),
        .pot_x   (pot_x_r),
        .pot_y   (pot_y_r),
        .out     (core2_o),
        .osc3    (sid2_osc3)
    );

    // Pipeline for voice outputs.
    sid::model_e   voice_model;
    sid::voice_i_t voice_i;
    sid::reg8_t    osc_o;
    sid::s22_t     voice_o;

    logic [3:0] voice_stage = 0, next_voice_stage;

    sid_voice voice_pipeline (
        .clk     (clk),
        .tick_ms (timer_tick),
        .active  (voice_stage >= 2 && voice_stage <= 8),
        .model   (voice_model),
        .voice_i (voice_i),
        .voice_o (voice_o),  // 1 cycle delay
        .osc_o   (osc_o)     // 1 cycle delay
    );

    // Pipeline for filter outputs.
    sid::filter_i_t filter_i;
    sid::s20_t      filter_o;
    sid::s20_t      filter_o_left;
    sid::s22_t      audio_i_right;

    logic [3:0] filter_state = 0, next_filter_state;
    logic       filter_no;
    logic [2:0] filter_stage;
    logic [1:0] filter_done  = 0, next_filter_done;

    sid_filter filter_pipeline (
        .clk      (clk),
        .stage    (filter_stage),
        .filter_i (filter_i),
        .audio_o  (filter_o) // 8 cycle delay
    );

    always_comb begin
        case (voice_stage)
          // Start voice pipeline when the SIDs are done.
          0: next_voice_stage = { 3'b0, phase[sid::PHI1] };
          // Finished after stage 9.
          9: next_voice_stage = 0;
          default:
             next_voice_stage = 4'(voice_stage + 1);
        endcase

        case (filter_state)
          // Start filter pipeline when all voices from SID #1 are done.
          0: next_filter_state = { 3'b0, voice_stage == 5 };
          // Start filter #2 after filter #1 is done.
          // filter_stage will wrap around to zero after filter #2 is done.
          7: next_filter_state = { 1'b1, 3'd1 };
          default:
             next_filter_state = 4'(filter_state + 1);
        endcase

        filter_no    = filter_state[3];
        filter_stage = filter_state[2:0];

        case (filter_state)
          { 1'b0, 3'd7 }:
            next_filter_done = 1;
          { 1'b1, 3'd7 }:
            next_filter_done = 2;
          default:
            next_filter_done = 0;
        endcase
    end

    always_ff @(posedge clk) begin
        // Calculate 2*3 voice outputs.
        // osc_o and voice_o are delayed by 1 cycle.
        // FIXME: Calculate voice3 first, in order to have OSC3 ready 2 cycles earlier?
        case (voice_stage)
          1: begin
              voice_model     <= sid1_cfg.model;
              voice_i         <= core1_o.voice1;
          end
          2: begin
              voice_i         <= core1_o.voice2;
          end
          3: begin
              voice_i         <= core1_o.voice3;

              filter_i.voice1 <= voice_o;
          end
          4: begin
              voice_model     <= sid2_cfg.model;
              voice_i         <= core2_o.voice1;

              filter_i.voice2 <= voice_o;
          end
          5: begin
              voice_i         <= core2_o.voice2;

              filter_i.voice3 <= voice_o;
              sid1_osc3       <= osc_o;

              // Setup for SID #1 filter pipeline.
              filter_i.model     <= sid1_cfg.model;
              filter_i.fc_base   <= sid1_cfg.fc_base;
              filter_i.fc_offset <= sid1_cfg.fc_offset + FC_OFFSET_6581;
              filter_i.regs      <= core1_o.filter_regs;
              filter_i.ext_in    <= audio_i.left[23 -: 22];
              // Save audio input for SID #2.
              audio_i_right      <= audio_i.right[23 -: 22];

              // Ready for SID #1 filter pipeline, see below.
          end
          6: begin
              voice_i         <= core2_o.voice3;

              filter_i.voice1 <= voice_o;
          end
          7: begin
              filter_i.voice2 <= voice_o;
          end
          8: begin
              filter_i.voice3 <= voice_o;
              sid2_osc3       <= osc_o;
          end
          9: begin
              // Setup for SID #2 filter pipeline.
              // The filter input state is only used during the first 4 cycles
              // in sid_filter, so it's safe to change it just now.
              filter_i.model     <= sid2_cfg.model;
              filter_i.fc_base   <= sid2_cfg.fc_base;
              filter_i.fc_offset <= sid2_cfg.fc_offset + FC_OFFSET_6581;
              filter_i.regs      <= core2_o.filter_regs;
              filter_i.ext_in    <= audio_i_right;
          end
        endcase

        voice_stage <= next_voice_stage;

        // Combine 2 audio stage outputs.
        case (filter_done)
          1: begin
              filter_o_left <= filter_o;
          end
          2: begin
              audio_o.left  <= { filter_o_left, 4'b0 };
              audio_o.right <= { filter_o,      4'b0 };
          end
        endcase

        filter_state <= next_filter_state;
        filter_done  <= next_filter_done;
    end

    always_comb begin
        // Default to SID #1 for data out.
        data_o = cs == 2'b10 ? sid2_data_o : sid1_data_o;
    end
endmodule
