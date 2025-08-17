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



// Combinatorial circuits for combined waveforms pulse + sawtooth + triangle.
// Espresso has been used to simplify sums of products per bit, based on
// waveform samples from reSID.
function sid::reg8_t sid_waveform_PST(logic model, sid::reg12_t x);
    if (model == 0)
        // 6581 P + S + T
        sid_waveform_PST = {
            1'b0,
            ((x & 'h7fc) == 'h7fc) | ((x & 'h7fb) == 'h7fb),
            ((x & 'h7ef) == 'h7ef) | ((x & 'h7f7) == 'h7f7) | ((x & 'h7fc) == 'h7fc) | ((x & 'h7fb) == 'h7fb) | ((x & 'h3ff) == 'h3ff),
            ((x & 'h7fc) == 'h7fc) | ((x & 'h3ff) == 'h3ff) | ((x & 'h7f7) == 'h7f7) | ((x & 'h7fb) == 'h7fb),
            ((x & 'h7fc) == 'h7fc) | ((x & 'h3ff) == 'h3ff) | ((x & 'h7fb) == 'h7fb),
            ((x & 'h7fd) == 'h7fd) | ((x & 'h3ff) == 'h3ff) | ((x & 'h7fe) == 'h7fe),
            ((x & 'h7fd) == 'h7fd) | ((x & 'h3ff) == 'h3ff) | ((x & 'h7fe) == 'h7fe),
            ((x & 'h3ff) == 'h3ff) | ((x & 'h7fe) == 'h7fe)
        };
    else
        // 8580 P + S + T
        sid_waveform_PST = {
            ((x & 'he89) == 'he89) | ((x & 'he3e) == 'he3e) | ((x & 'hec0) == 'hec0) | ((x & 'he8a) == 'he8a) | ((x & 'hdf7) == 'hdf7) | ((x & 'hdf8) == 'hdf8) | ((x & 'he85) == 'he85) | ((x & 'he6a) == 'he6a) | ((x & 'he90) == 'he90) | ((x & 'he83) == 'he83) | ((x & 'he67) == 'he67) | ((x & 'hea0) == 'hea0) | ((x & 'hf00) == 'hf00) | ((x & 'he5e) == 'he5e) | ((x & 'he70) == 'he70) | ((x & 'he6c) == 'he6c),
            ((x & 'heee) == 'heee) | ((x & 'h7ef) == 'h7ef) | ((x & 'h7f2) == 'h7f2) | ((x & 'h7f4) == 'h7f4) | ((x & 'hef0) == 'hef0) | ((x & 'h7f8) == 'h7f8) | ((x & 'hf00) == 'hf00) | ((x & 'h7f1) == 'h7f1),
            ((x & 'hf78) == 'hf78) | ((x & 'h7f0) == 'h7f0) | ((x & 'h7ee) == 'h7ee) | ((x & 'hf74) == 'hf74) | ((x & 'hf6f) == 'hf6f) | ((x & 'hf80) == 'hf80) | ((x & 'hbff) == 'hbff),
            ((x & 'hdff) == 'hdff) | ((x & 'hbfe) == 'hbfe) | ((x & 'h7ef) == 'h7ef) | ((x & 'h7f2) == 'h7f2) | ((x & 'h3ff) == 'h3ff) | ((x & 'h7f4) == 'h7f4) | ((x & 'hfc0) == 'hfc0) | ((x & 'hfb8) == 'hfb8) | ((x & 'h7f8) == 'h7f8) | ((x & 'hfb6) == 'hfb6),
            ((x & 'hbfe) == 'hbfe) | ((x & 'hfdc) == 'hfdc) | ((x & 'hdfe) == 'hdfe) | ((x & 'h7f7) == 'h7f7) | ((x & 'hfda) == 'hfda) | ((x & 'hbfd) == 'hbfd) | ((x & 'h7f8) == 'h7f8) | ((x & 'h3ff) == 'h3ff) | ((x & 'hfe0) == 'hfe0) | ((x & 'heff) == 'heff),
            ((x & 'hfeb) == 'hfeb) | ((x & 'h7fa) == 'h7fa) | ((x & 'hbfe) == 'hbfe) | ((x & 'hdfe) == 'hdfe) | ((x & 'hff0) == 'hff0) | ((x & 'h7fc) == 'h7fc) | ((x & 'h3ff) == 'h3ff) | ((x & 'hfec) == 'hfec) | ((x & 'heff) == 'heff),
            ((x & 'hff6) == 'hff6) | ((x & 'hdff) == 'hdff) | ((x & 'hf7f) == 'hf7f) | ((x & 'hbfe) == 'hbfe) | ((x & 'h7fc) == 'h7fc) | ((x & 'hff5) == 'hff5) | ((x & 'h3ff) == 'h3ff) | ((x & 'hff8) == 'hff8) | ((x & 'heff) == 'heff),
            ((x & 'hdff) == 'hdff) | ((x & 'hf7f) == 'hf7f) | ((x & 'hffa) == 'hffa) | ((x & 'h7fe) == 'h7fe) | ((x & 'hff9) == 'hff9) | ((x & 'hffc) == 'hffc) | ((x & 'h3ff) == 'h3ff) | ((x & 'heff) == 'heff)
        };
endfunction
