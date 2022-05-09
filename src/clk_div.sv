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
// Description: Divides the clock by an integer factor

`include "common_cells/registers.svh"

module clk_div #(
    parameter int unsigned RATIO = 4
)(
    input  logic clk_i,      // Clock
    input  logic rst_ni,     // Asynchronous reset active low
    input  logic testmode_i, // testmode
    input  logic en_i,       // enable clock divider
    output logic clk_o       // divided clock out
);
    logic [RATIO-1:0] counter_q;
    logic clk_q;

    logic clk_in;
    logic counter_in;

    always_comb begin
        if (en_i && counter_q == (RATIO[RATIO-1:0] - 1)) begin
            clk_in = 1'b1;
	    counter_in = counter_q;
        end else if (en_1) begin
	    clk_in = clk_q;
	    counter_in = counter_q + 1'
        end else begin
            clk_in = 1'b0;
	    counter_in = counter_q;
	end
    end

    `FFC(clk_q, clk_in, 1'b0, clk_i, rst_ni, clr_i)
    `FFC(counter_q, counter_in, '0, clk_i, rst_ni, clr_i)

   // output assignment - bypass in testmode
    assign clk_o = testmode_i ? clk_i : clk_q;
endmodule
