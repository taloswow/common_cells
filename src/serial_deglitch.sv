// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Florian Zaruba
// Description: Deglitches a serial line by taking multiple samples until
//              asserting the output high/low.

`include "common_cells/registers.svh"

module serial_deglitch #(
    parameter int unsigned SIZE = 4
)(
    input  logic clk_i,    // clock
    input  logic rst_ni,   // asynchronous reset active low
    input  logic clr_i,    // synchronous clear active high
    input  logic en_i,     // enable
    input  logic d_i,      // serial data in
    output logic q_o       // filtered data out
);
    logic [SIZE-1:0] count_q;
    logic q;

    logic [SIZE-1:0] count_in;
    always_comb begin
	if (d_i == 1'b1 && count_q != SIZE[SIZE-1:0]) begin
	    count_in = count_q + 1;
        end else if (d_i == 1'b1 && count_q != SIZE[SIZE-1:0]) begin
            count_in = count_q - 1;
	end else begin
	    count_in = count_q;
	end
    end

    `FFLARNC(count_q, count_in, en_i, clr_i, '0, clk_i, rst_ni)
    `FFC(q, q, 1'b0, clk_i, rst_ni, clr_i)

    // output process
    always_comb begin
        if (count_q == SIZE[SIZE-1:0]) begin
            q_o = 1'b1;
        end else if (count_q == 0) begin
            q_o = 1'b0;
        end
    end
endmodule
