//*****************************************************************************
// (c) Copyright 2009 - 2013 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 3.0
//  \   \         Application        : MIG
//  /   /         Filename           : example_top.v
// /___/   /\     Date Last Modified : $Date: 2011/06/02 08:36:27 $
// \   \  /  \    Date Created       : Fri Jan 14 2011
//  \___\/\___\
//
// Device           : 7 Series
// Design Name      : QDRII+ SDRAM
// Purpose          :
//   Top-level  module. This module serves as an example,
//   and allows the user to synthesize a self-contained design,
//   which they can be used to test their hardware.
//   In addition to the memory controller, the module instantiates:
//     1. Synthesizable testbench - used to model user's backend logic
//        and generate different traffic patterns
// Reference        :
// Revision History :
//*****************************************************************************

`timescale 1ps/1ps

module qdr_example_top #
  (

   parameter MEM_TYPE              = "QDR2PLUS",
                                     // # of CK/CK# outputs to memory.
   parameter DATA_WIDTH            = 36,
                                     // # of DQ (data)
   parameter BW_WIDTH              = 4,
                                     // # of byte writes (data_width/9)
   parameter ADDR_WIDTH            = 20,
                                     // Address Width
   //***************************************************************************
   // The following parameters are mode register settings
   //***************************************************************************
   parameter BURST_LEN             = 4,
                                     // Burst Length of the design (4 or 2).

   //***************************************************************************
   // Simulation parameters
   //***************************************************************************
   parameter SIMULATION            = "FALSE",
                                     // Should be TRUE during design simulations and
                                     // FALSE during implementations

   //***************************************************************************
   // IODELAY and PHY related parameters
   //***************************************************************************
   parameter TCQ                   = 100,
   
   // Number of taps in target IDELAY
   parameter integer DEVICE_TAPS = 32,

   
   //***************************************************************************
   // System clock frequency parameters
   //***************************************************************************
   parameter nCK_PER_CLK           = 2,
                                     // # of memory CKs per fabric CLK

      //***************************************************************************
   // Traffic Gen related parameters
   //***************************************************************************
   parameter BL_WIDTH              = 8,
   parameter PORT_MODE             = "BI_MODE",
   parameter DATA_MODE             = 4'b0010,
   parameter EYE_TEST              = "FALSE",
                                     // set EYE_TEST = "TRUE" to probe memory
                                     // signals. Traffic Generator will only
                                     // write to one single location and no
                                     // read transactions will be generated.
   parameter DATA_PATTERN          = "DGEN_ALL",
                                      // "DGEN_HAMMER", "DGEN_WALKING1",
                                      // "DGEN_WALKING0","DGEN_ADDR","
                                      // "DGEN_NEIGHBOR","DGEN_PRBS","DGEN_ALL"
   parameter CMD_PATTERN           = "CGEN_ALL",
                                      // "CGEN_PRBS","CGEN_FIXED","CGEN_BRAM",
                                      // "CGEN_SEQUENTIAL", "CGEN_ALL"
   parameter CMD_WDT               = 'h3FF,
   parameter WR_WDT                = 'h1FFF,
   parameter RD_WDT                = 'h3FF,
   parameter BEGIN_ADDRESS         = 32'h00000000,
   parameter END_ADDRESS           = 32'h00000fff,
   parameter PRBS_EADDR_MASK_POS   = 32'hfffff000,

   //***************************************************************************
   // Wait period for the read strobe (CQ) to become stable
   //***************************************************************************
   //parameter CLK_STABLE            = (20*1000*1000/(CLK_PERIOD*2)),
                                     // Cycles till CQ/CQ# is stable

   //***************************************************************************
   // Debug parameter
   //***************************************************************************
   parameter DEBUG_PORT            = "OFF",
                                     // # = "ON" Enable debug signals/controls.
                                     //   = "OFF" Disable debug signals/controls.
      
   parameter RST_ACT_LOW           = 1
                                     // =1 for active low reset,
                                     // =0 for active high.
   )
  (

   input       [1:0]       qdriip_cq_p,     //Memory Interface
   input       [1:0]       qdriip_cq_n,
   input       [35:0]      qdriip_q,
   inout  wire  [1:0]      qdriip_k_p,
   inout  wire  [1:0]      qdriip_k_n,
   output wire [35:0]      qdriip_d,
   output wire [19:0]      qdriip_sa,
   output wire             qdriip_w_n,
   output wire             qdriip_r_n,
   output wire [3:0]       qdriip_bw_n,
   output wire             qdriip_dll_off_n,
  
      

   // System reset - Default polarity of sys_rst pin is Active Low.
   // System reset polarity will change based on the option 
   // selected in GUI.
   input                    sys_rstn,
   input                    sys_clk_i,// Single-ended iodelayctrl clk (reference clock)
   input                    clk_ref_i,
   output [3:0]             led,
   
   ///user_logic
   output                   init_calib_complete,
       
   input                    qdr_fifoin_wr_en,
   input   [63:0]           qdr_fifoin_wr_data,
   output                   qdr_fifoin_prog_full,
   input                    qdr_fifoin_wr_clk,
       
   output  [63:0]           qdr_fifoout_rd_data,
   output                   qdr_fifoout_rd_data_valid,
   input                    qdr_fifoout_rd_clk,
   input                    emc_fifo_almost_full,
   
   input    [4:0]           frame_cal_num_in,
   output   [4:0]           frame_cal_num_out
   
   
   );
 
  // clogb2 function - ceiling of log base 2
  function integer clogb2 (input integer size);
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
        size = size >> 1;
    end
  endfunction

   localparam APP_DATA_WIDTH        = BURST_LEN*DATA_WIDTH;
   localparam APP_MASK_WIDTH        = APP_DATA_WIDTH / 9;
   
      
   // Number of bits needed to represent DEVICE_TAPS
   localparam integer TAP_BITS = clogb2(DEVICE_TAPS - 1);
   // Number of bits to represent number of cq/cq#'s
   localparam integer CQ_BITS  = clogb2(DATA_WIDTH/9 - 1);
   // Number of bits needed to represent number of q's
   localparam integer Q_BITS   = clogb2(DATA_WIDTH - 1);

  // Wire declarations
   wire                            user_clk;
   wire                            rst_clk;
   wire                            cmp_err;
   wire                            dbg_clear_error;
   wire                            app_wr_cmd0;
   wire                            app_wr_cmd1;
   wire [ADDR_WIDTH-1:0]           app_wr_addr0;
   wire [ADDR_WIDTH-1:0]           app_wr_addr1;
   wire                            app_rd_cmd0;
   wire                            app_rd_cmd1;
   wire [ADDR_WIDTH-1:0]           app_rd_addr0;
   wire [ADDR_WIDTH-1:0]           app_rd_addr1;
   wire [(BURST_LEN*DATA_WIDTH)-1:0] app_wr_data0;
   wire [(DATA_WIDTH*2)-1:0]         app_wr_data1;
   wire [(BURST_LEN*BW_WIDTH)-1:0]   app_wr_bw_n0;
   wire [(BW_WIDTH*2)-1:0]           app_wr_bw_n1;
   wire                            app_cal_done;
   wire                            app_rd_valid0;
   wire                            app_rd_valid1;
   (* keep= "true"*)
   wire [(BURST_LEN*DATA_WIDTH)-1:0] app_rd_data0;
   wire [(DATA_WIDTH*2)-1:0]         app_rd_data1;
   wire [(ADDR_WIDTH*2)-1:0]         tg_addr;
   wire [APP_DATA_WIDTH-1:0]       cmp_data;
   wire [47:0]                     wr_data_counts;
   wire [47:0]                     rd_data_counts;


 
     wire                                        locked;
//***************************************************************************


      
// Start of User Design top instance
//***************************************************************************
// The User design is instantiated below. The memory interface ports are
// connected to the top-level and the application interface ports are
// connected to the traffic generator module. This provides a reference
// for connecting the memory controller to system.
//***************************************************************************

  QDR_K7 //#
//    (
//     #parameters_mapping_user_design_top_instance#
//     .RST_ACT_LOW                      (RST_ACT_LOW)
//     )
    u_QDR_K7
      (
       
     
     // Memory interface ports
     .qdriip_cq_p                     (qdriip_cq_p),
     .qdriip_cq_n                     (qdriip_cq_n),
     .qdriip_q                        (qdriip_q),
     .qdriip_k_p                      (qdriip_k_p),
     .qdriip_k_n                      (qdriip_k_n),
     .qdriip_d                        (qdriip_d),
     .qdriip_sa                       (qdriip_sa),
     .qdriip_w_n                      (qdriip_w_n),
     .qdriip_r_n                      (qdriip_r_n),
     .qdriip_bw_n                     (qdriip_bw_n),
     .qdriip_dll_off_n                (qdriip_dll_off_n),
     .init_calib_complete              (init_calib_complete),
      
     
     // Application interface ports
     .app_wr_cmd0                     (app_wr_cmd0),
     .app_wr_cmd1                     (1'b0),
     .app_wr_addr0                    (app_wr_addr0),
     .app_wr_addr1                    ({ADDR_WIDTH{1'b0}}),
     .app_rd_cmd0                     (app_rd_cmd0),
     .app_rd_cmd1                     (1'b0),
     .app_rd_addr0                    (app_rd_addr0),
     .app_rd_addr1                    ({ADDR_WIDTH{1'b0}}),
     .app_wr_data0                    (app_wr_data0),
     .app_wr_data1                    ({DATA_WIDTH*2{1'b0}}),
     .app_wr_bw_n0                    ({BURST_LEN*BW_WIDTH{1'b0}}),
     .app_wr_bw_n1                    ({2*BW_WIDTH{1'b0}}),
     .app_rd_valid0                   (app_rd_valid0),
     .app_rd_valid1                   (app_rd_valid1),
     .app_rd_data0                    (app_rd_data0),
     .app_rd_data1                    (app_rd_data1),
     .clk                             (user_clk),
     .rst_clk                         (rst_clk),
     
     
     
     // System Clock Ports
     .sys_clk_i                       (sys_clk_i),
     
     // Reference Clock Ports
     .clk_ref_i                       (clk_ref_i),
      
       .sys_rst                        (sys_rstn)
       );
// End of User Design top instance

user_logic user_logic (
		.app_wr_cmd0                    (app_wr_cmd0), 
		.app_wr_addr0                   (app_wr_addr0), 
		.app_wr_data0                   (app_wr_data0), 
		.app_rd_cmd0                    (app_rd_cmd0), 
		.app_rd_addr0                   (app_rd_addr0), 
		.app_rd_valid0                  (app_rd_valid0), 
		.app_rd_data0                   (app_rd_data0), 
		.qdr_user_clk                   (user_clk),
		
		.qdr_fifoin_wr_en               (qdr_fifoin_wr_en), 
      .qdr_fifoin_wr_data             (qdr_fifoin_wr_data), 
      .qdr_fifoin_prog_full           (qdr_fifoin_prog_full), 
      .qdr_fifoin_wr_clk              (qdr_fifoin_wr_clk), 
      .qdr_fifoout_rd_data            (qdr_fifoout_rd_data), 
      .qdr_fifoout_rd_data_valid      (qdr_fifoout_rd_data_valid), 
      .qdr_fifoout_rd_clk             (qdr_fifoout_rd_clk),
		.emc_fifo_almost_full           (emc_fifo_almost_full),
		.phy_init_done                  (init_calib_complete),
		
		.rst                            (~sys_rstn),
		//.trig                           (trig)
		
		.frame_cal_num_in               (frame_cal_num_in),
		.frame_cal_num_out              (frame_cal_num_out)
     );		 

reg clk_led;
reg [27:0] clk_cnt;
always @(posedge user_clk)begin
   if(!sys_rstn)begin
	   clk_cnt<=28'h0;
		clk_led<=1'b0;
	end else begin
	    if(clk_cnt==28'h2FAF080)begin
		   clk_cnt<=28'h0;
			clk_led<=~clk_led;
		 end else begin
		   clk_cnt<=clk_cnt+1;
		 end
	end
end
    assign led[0]=clk_led;
    assign led[1]=locked;
    assign led[2]=init_calib_complete;
	assign led[3]=sys_rstn;

      

endmodule
