//
//  AM29F040 (512K x 8) parallel NOR flash
//  Copyright (C) 2025 Alexey Melnikov
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module ez_rom
(
	input  logic        clk,
	input  logic        reset_n,
	input  logic        ce,
	input  logic        we,
	input  logic [19:0] addr,
	input  logic [7:0]  dq_in,
	output logic [7:0]  dq_out,
	output logic        dq_oe, 

	output logic        mem_req,
	input  logic        mem_cycle,
	output logic        mem_oe,

	output logic [19:0] mem_addr,
	input  logic [7:0]  mem_in,
	output logic [7:0]  mem_out,
	output logic        mem_ce,
	output logic        mem_we
);

assign dq_out   = dq_in;
assign dq_oe    = 0;
assign mem_req = 0;
assign mem_oe = 0;
assign mem_addr = addr;
assign mem_out  = mem_in;
assign mem_ce   = 0;
assign mem_we   = 0;

endmodule
