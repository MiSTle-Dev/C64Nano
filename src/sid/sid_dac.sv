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

// ----------------------------------------------------------------------------
// This file is based on documentation and code from reSID, see
// https://github.com/daglem/reSID
//
// The SID DACs are built up as follows:
//
//          n  n-1      2   1   0    VGND
//          |   |       |   |   |      |   Termination
//         2R  2R      2R  2R  2R     2R   only for
//          |   |       |   |   |      |   MOS 8580
//      Vo  --R---R--...--R---R--    ---
//
//
// All MOS 6581 DACs are missing a termination resistor at bit 0. This causes
// pronounced errors for the lower 4 - 5 bits (e.g. the output for bit 0 is
// actually equal to the output for bit 1), resulting in DAC discontinuities
// for the lower bits.
// In addition to this, the 6581 DACs exhibit further severe discontinuities
// for higher bits, which may be explained by a less than perfect match between
// the R and 2R resistors, or by output impedance in the NMOS transistors
// providing the bit voltages. A good approximation of the actual DAC output is
// achieved for 2R/R ~ 2.20.
//
// The MOS 8580 DACs, on the other hand, do not exhibit any discontinuities.
// These DACs include the correct termination resistor, and also seem to have
// very accurately matched R and 2R resistors (2R/R = 2.00).
// ----------------------------------------------------------------------------



module sid_dac #(
    parameter int  BITS       = 12,
    parameter real _2R_DIV_R  = 2.20,
    parameter int  TERM       = 0
)(
    input  logic [BITS-1:0] vin,
    output logic [BITS-1:0] vout
);
    localparam int SCALEBITS = 4;
    localparam int MSB       = BITS + SCALEBITS - 1;

    logic [MSB:0] bitval [0:BITS-1];
    logic [MSB:0] bitsum;

    always_comb begin
        bitsum = logic'(1) << (SCALEBITS - 1);

        for (int i = 0; i < BITS; i++) begin
            bitsum += (vin[i] ? bitval[i] : '0);
        end

        vout = bitsum[MSB -: BITS];
    end

    always_comb begin
        for (int i = 0; i < BITS; i++)
            bitval[i] = '0;

        if (_2R_DIV_R == 2.20 && TERM == 0 && SCALEBITS == 4) begin
            case (BITS)
                12: begin
                    bitval[0]  = 'h0021;
                    bitval[1]  = 'h0030;
                    bitval[2]  = 'h0055;
                    bitval[3]  = 'h00A0;
                    bitval[4]  = 'h0135;
                    bitval[5]  = 'h0256;
                    bitval[6]  = 'h0486;
                    bitval[7]  = 'h08C6;
                    bitval[8]  = 'h1102;
                    bitval[9]  = 'h20F8;
                    bitval[10] = 'h3FEC;
                    bitval[11] = 'h7BED;
                end

                11: begin
                    bitval[0]  = 'h0020;
                    bitval[1]  = 'h002F;
                    bitval[2]  = 'h0052;
                    bitval[3]  = 'h009C;
                    bitval[4]  = 'h012B;
                    bitval[5]  = 'h0243;
                    bitval[6]  = 'h0463;
                    bitval[7]  = 'h0880;
                    bitval[8]  = 'h107B;
                    bitval[9]  = 'h1FF4;
                    bitval[10] = 'h3DF3;
                end

                8: begin
                    bitval[0]  = 'h001D;
                    bitval[1]  = 'h002A;
                    bitval[2]  = 'h004B;
                    bitval[3]  = 'h008D;
                    bitval[4]  = 'h0110;
                    bitval[5]  = 'h020E;
                    bitval[6]  = 'h03FB;
                    bitval[7]  = 'h07B8;
                end
            endcase
        end
    end
endmodule

