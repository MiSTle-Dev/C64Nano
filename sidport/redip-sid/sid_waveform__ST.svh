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



// Combinatorial circuits for combined waveforms sawtooth + triangle.
// Espresso has been used to simplify sums of products per bit, based on
// waveform samples from reSID.
function sid::reg8_t sid_waveform__ST(logic model, sid::reg12_t x);
    if (model == 0)
        // 6581 S + T
        sid_waveform__ST = {
            1'b0,
            ((x & 'h7fc) == 'h7fc),
            ((x & 'h7e0) == 'h7e0) | ((x & 'h3fe) == 'h3fe),
            ((x & 'h7e0) == 'h7e0) | ((x & 'h5ff) == 'h5ff) | ((x & 'h3f0) == 'h3f0),
            ((x & 'h7e0) == 'h7e0) | ((x & 'h1f8) == 'h1f8) | ((x & 'h3f0) == 'h3f0),
            ((x & 'h0fc) == 'h0fc) | ((x & 'h1f8) == 'h1f8) | ((x & 'h3f0) == 'h3f0),
            ((x & 'h07e) == 'h07e) | ((x & 'h1f8) == 'h1f8) | ((x & 'h0fc) == 'h0fc),
            ((x & 'h13f) == 'h13f) | ((x & 'h07e) == 'h07e) | ((x & 'h7fa) == 'h7fa) | ((x & 'h0bf) == 'h0bf) | ((x & 'h0fc) == 'h0fc)
        };
    else
        // 8580 S + T
        sid_waveform__ST = {
            ((x & 'he7e) == 'he7e) | ((x & 'he80) == 'he80) | ((x & 'hf00) == 'hf00) | ((x & 'he7d) == 'he7d),
            ((x & 'h7f8) == 'h7f8) | ((x & 'hf00) == 'hf00),
            ((x & 'h7e0) == 'h7e0) | ((x & 'hf0f) == 'hf0f) | ((x & 'hf1b) == 'hf1b) | ((x & 'hbfe) == 'hbfe) | ((x & 'hf1e) == 'hf1e) | ((x & 'hf40) == 'hf40) | ((x & 'hf30) == 'hf30) | ((x & 'hf29) == 'hf29) | ((x & 'hf26) == 'hf26) | ((x & 'hf80) == 'hf80),
            ((x & 'h7e0) == 'h7e0) | ((x & 'h3f0) == 'h3f0) | ((x & 'hdfe) == 'hdfe) | ((x & 'h5ff) == 'h5ff) | ((x & 'hf80) == 'hf80),
            ((x & 'h7e0) == 'h7e0) | ((x & 'h3f0) == 'h3f0) | ((x & 'hfc0) == 'hfc0) | ((x & 'h1f8) == 'h1f8) | ((x & 'heff) == 'heff),
            ((x & 'h0fc) == 'h0fc) | ((x & 'h1f8) == 'h1f8) | ((x & 'h3f0) == 'h3f0) | ((x & 'hfe0) == 'hfe0),
            ((x & 'h07e) == 'h07e) | ((x & 'hff0) == 'hff0) | ((x & 'h7f7) == 'h7f7) | ((x & 'h1f8) == 'h1f8) | ((x & 'h0fc) == 'h0fc),
            ((x & 'hdbf) == 'hdbf) | ((x & 'h0fc) == 'h0fc) | ((x & 'h3fa) == 'h3fa) | ((x & 'h7f8) == 'h7f8) | ((x & 'h3bf) == 'h3bf) | ((x & 'h07e) == 'h07e)
        };
endfunction
