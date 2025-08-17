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



module sid_core (
    input  logic         clk,
    input  logic         tick_ms,
    input  sid::model_e  model,
    input  sid::bus_i_t  bus_i,
    input  sid::phase_t  phase,
    input  logic         cs,
    output sid::reg8_t   data_o,
    input logic [7:0] pot_x,
    input logic [7:0] pot_y,
    output sid::core_o_t out,
    input  sid::reg8_t   osc3
);

    // Write-only / read-only registers.
    sid::reg_i_t reg_i = '0; // Byte addressable write-only registers
    sid::reg_o_t reg_o;      // Byte addressable read-only registers



    always_comb begin
        reg_o.regs.pot.xy[0] = pot_x;
        reg_o.regs.pot.xy[1] = pot_y;
        out.filter_regs = reg_i.regs.filter;
        reg_o.regs.osc3 = osc3;
        reg_o.regs.env3 = out.voice3.envelope;
    end

    // SID waveform generators.

    // We could have generated the waveform generators, however Yosys currently
    // doesn't support multidimensional packed arrays outside of structs.
    sid::sync_t sync1, sync2, sync3;

    sid_waveform waveform1 (
        .clk        (clk),
        .tick_ms    (tick_ms),
        .res        (bus_i.res),
        .model      (model),
        .phase      (phase),
        .reg_i      (reg_i.regs.voice1.waveform),
        .sync_i     (sync1),
        .sync_o     (sync2),
        .out        (out.voice1.waveform)
    );

    sid_waveform waveform2 (
        .clk        (clk),
        .tick_ms    (tick_ms),
        .res        (bus_i.res),
        .model      (model),
        .phase      (phase),
        .reg_i      (reg_i.regs.voice2.waveform),
        .sync_i     (sync2),
        .sync_o     (sync3),
        .out        (out.voice2.waveform)
    );

    sid_waveform waveform3 (
        .clk        (clk),
        .tick_ms    (tick_ms),
        .res        (bus_i.res),
        .model      (model),
        .phase      (phase),
        .reg_i      (reg_i.regs.voice3.waveform),
        .sync_i     (sync3),
        .sync_o     (sync1),
        .out        (out.voice3.waveform)
    );

    // SID envelope generators.

    sid_envelope envelope1 (
        .clk   (clk),
        .res   (bus_i.res),
        .phase (phase),
        .reg_i (reg_i.regs.voice1.envelope),
        .out   (out.voice1.envelope)
    );

    sid_envelope envelope2 (
        .clk   (clk),
        .res   (bus_i.res),
        .phase (phase),
        .reg_i (reg_i.regs.voice2.envelope),
        .out   (out.voice2.envelope)
    );

    sid_envelope envelope3 (
        .clk   (clk),
        .res   (bus_i.res),
        .phase (phase),
        .reg_i (reg_i.regs.voice3.envelope),
        .out   (out.voice3.envelope)
    );

    // Register read / write.
    logic r;
    logic w;

    sid::reg8_t bus_value = 0;

    always_comb begin
        // Read / write.
        r = cs && bus_i.oe && bus_i.addr >= 'h19 && bus_i.addr < 'h1D;
        w = cs && bus_i.we;
    end

    always_ff @(posedge clk) begin
        // Output from register or bus value.
        data_o <= r ? reg_o.bytes[bus_i.addr - 'h19] : bus_value;
            if (bus_i.res) begin
                reg_i <= '0;
                bus_value <= '0;
            end
            else if (w)
                reg_i.bytes[bus_i.addr] <= bus_i.data;
            if (r) 
                bus_value <= data_o;
            else if (w) 
                bus_value <= bus_i.data;
    end
endmodule
