
// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: <zarubaf@iis.ee.ethz.ch>
//
// Description: Simple shift register for arbitrary depth and types

`include "common_cells/registers.svh"

module shift_reg #(
    parameter type dtype         = logic,
    parameter int unsigned Depth = 1
)(
    input  logic clk_i,    // Clock
    input  logic rst_ni,   // Asynchronous reset active low
    input  logic clr_i,    // Synchronous clear active high
    input  dtype d_i,
    output dtype d_o
);

    // register of depth 0 is a wire
    if (Depth == 0) begin : gen_pass_through
        assign d_o = d_i;
    // register of depth 1 is a simple register
    end else if (Depth == 1) begin : gen_register
        `FFC(d_o, d_i, '0, clk_i, rst_ni, clr_i)
    // if depth is greater than 1 it becomes a shift register
    end else if (Depth > 1) begin : gen_shift_reg
        dtype [Depth-1:0] reg_d, reg_q;
        assign d_o = reg_q[Depth-1];
        assign reg_d = {reg_q[Depth-2:0], d_i};

        `FFC(reg_q, reg_d, '0, clk_i, rst_ni, clr_i)
    end

endmodule
