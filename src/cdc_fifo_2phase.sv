// Copyright 2018 ETH Zurich and University of Bologna.
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>

/// A clock domain crossing FIFO, using 2-phase hand shakes.
///
/// This FIFO has its push and pop ports in two separate clock domains. Its size
/// can only be powers of two, which is why its depth is given as 2**LOG_DEPTH.
/// LOG_DEPTH must be at least 1.
///
/// # Reset Behavior!!
///
/// This module must not be used if warm reset capabily is a requirement. The
/// only execption is if you consistently use a reset controller that sequences
/// the resets while gating both clock domains (be very careful if you follow
/// this strategy!).
///
/// After this disclaimer, here is how you connect the src_rst_ni and the
/// dst_rst_ni of this module for power-on-reset (POR). The src_rst_ni and
/// dst_rst_ni signal must be asserted SIMULTANEOUSLY (i.e. asynchronous
/// assertion). Othwerwise, spurious transactions could occur in the domain
/// where the reset arrives later than the other. The de-assertion of both reset
/// must be synchronized to their respective clock domain (i.e. src_rst_ni must
/// be deasserted synchronously to the src_clk_i and dst_rst_ni must be
/// deasserted synchronously to dst_clk_i.) You can use the rstgen cell in the
/// common_cells library to achieve this (synchronization of only the
/// de-assertion). However, be careful about reset domain crossings; If you
/// reset both domain asynchronously in their entirety (i.e. POR) you are fine.
/// However, if you use this strategy for warm resets (some parts of the circuit
/// are not reset) you might introduce metastability in this separate
/// reset-domain when you assert the reset (the deassertion synchronizer doen't
/// help here).
///
/// CONSTRAINT: See the constraints for `cdc_2phase`. An additional maximum
/// delay path needs to be specified from fifo_data_q to dst_data_o.

`include "common_cells/registers.svh"

module cdc_fifo_2phase #(
  /// The data type of the payload transported by the FIFO.
  parameter type T = logic,
  /// The FIFO's depth given as 2**LOG_DEPTH.
  parameter int LOG_DEPTH = 3
)(
  input  logic src_rst_ni,
  input  logic src_clk_i,
  input  logic src_clr_i,
  input  T     src_data_i,
  input  logic src_valid_i,
  output logic src_ready_o,

  input  logic dst_rst_ni,
  input  logic dst_clk_i,
  input  logic dst_clr_i,
  output T     dst_data_o,
  output logic dst_valid_o,
  input  logic dst_ready_i
);

  // Check the invariants.
  //pragma translate_off
  initial begin
    assert(LOG_DEPTH > 0);
  end
  //pragma translate_on

  localparam int PtrWidth = LOG_DEPTH+1;
  typedef logic [PtrWidth-1:0] pointer_t;
  typedef logic [LOG_DEPTH-1:0] index_t;

  localparam pointer_t PtrFull  = (1 << LOG_DEPTH);
  localparam pointer_t PtrEmpty = '0;

  // Allocate the registers for the FIFO memory with its separate write and read
  // ports. The FIFO has the following ports:
  //
  // - write: fifo_widx, fifo_wdata, fifo_write, src_clk_i
  // - read: fifo_ridx, fifo_rdata
  index_t fifo_widx, fifo_ridx;
  logic fifo_write;
  T fifo_wdata, fifo_rdata;
  T fifo_data_q [2**LOG_DEPTH];

  assign fifo_rdata = fifo_data_q[fifo_ridx];

  for (genvar i = 0; i < 2**LOG_DEPTH; i++) begin : g_word
    `FFLARNC(fifo_data_q[i], fifo_wdata, fifo_write && fifowidx ==i, src_clr_i, '0, src_clk_i, src_rst_ni)
  end

  // Allocate the read and write pointers in the source and destination domain.
  pointer_t src_wptr_q, dst_wptr, src_rptr, dst_rptr_q;

  `FFCL(src_wptr_q, src_wptr_q+1, 0, src_clk_i, src_rst_ni, src_clr_i, (src_valid_i && src_ready_o))

  `FFCL(dst_rptr_q, (dst_rptr_q + 1), 0, dst_clk_i, dst_rst_ni, src_clr_i, (dst_valid_o && dst_ready_i))

  // The pointers into the FIFO are one bit wider than the actual address into
  // the FIFO. This makes detecting critical states very simple: if all but the
  // topmost bit of rptr and wptr agree, the FIFO is in a critical state. If the
  // topmost bit is equal, the FIFO is empty, otherwise it is full.
  assign src_ready_o = ((src_wptr_q ^ src_rptr) != PtrFull);
  assign dst_valid_o = ((dst_rptr_q ^ dst_wptr) != PtrEmpty);

  // Transport the read and write pointers across the clock domain boundary.
  cdc_2phase #( .T(pointer_t) ) i_cdc_wptr (
    .src_rst_ni  ( src_rst_ni ),
    .src_clk_i   ( src_clk_i  ),
    .src_clr_i   ( src_clr_i  ),
    .src_data_i  ( src_wptr_q ),
    .src_valid_i ( 1'b1       ),
    .src_ready_o (            ),
    .dst_rst_ni  ( dst_rst_ni ),
    .dst_clk_i   ( dst_clk_i  ),
    .dst_clr_i   ( dst_clr_i  ),
    .dst_data_o  ( dst_wptr   ),
    .dst_valid_o (            ),
    .dst_ready_i ( 1'b1       )
  );

  cdc_2phase #( .T(pointer_t) ) i_cdc_rptr (
    .src_rst_ni  ( dst_rst_ni ),
    .src_clk_i   ( dst_clk_i  ),
    .src_clr_i   ( dst_clr_i  ),
    .src_data_i  ( dst_rptr_q ),
    .src_valid_i ( 1'b1       ),
    .src_ready_o (            ),
    .dst_rst_ni  ( src_rst_ni ),
    .dst_clk_i   ( src_clk_i  ),
    .dst_clr_i   ( src_clr_i  ),
    .dst_data_o  ( src_rptr   ),
    .dst_valid_o (            ),
    .dst_ready_i ( 1'b1       )
  );

  // Drive the FIFO write and read ports.
  assign fifo_widx  = src_wptr_q;
  assign fifo_wdata = src_data_i;
  assign fifo_write = src_valid_i && src_ready_o;
  assign fifo_ridx  = dst_rptr_q;
  assign dst_data_o = fifo_rdata;

endmodule
