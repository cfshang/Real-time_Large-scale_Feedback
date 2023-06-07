// ----------------------------------------------------------------------------
// (c) Copyright 2014 Xilinx, Inc. All rights reserved.
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
// ----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
// Title      : FIFO block level
// Project    : 10G/25G Gigabit Ethernet
//-----------------------------------------------------------------------------
// File       : axi_10g_ethernet_0_fifo_block.v
// Author     : Xilinx Inc.
//-----------------------------------------------------------------------------
// Description: This is the FIFO block level code for the 10G/25G Gigabit
//              Ethernet IP. It contains example design AXI FIFOs connected to
//              the AXI-S transmit and receive interfaces of the Ethernet core.
//-----------------------------------------------------------------------------

`timescale 1ps / 1ps

module axi_10g_ethernet_0_fifo_block  #(
   parameter                           FIFO_SIZE = 1024,
   parameter                           src_mac_addr =48'h5a0102030405,
   //parameter                           des_addr =48'hda0102030405,
   parameter                           dest_mac_addr =48'h248a0775b3f0,
   parameter                           src_ip_addr=32'h5a030201,
   parameter                           dest_ip_addr=32'h010203da,
   parameter                           pkt_len =16'h2008  //8k data + pkt_cnt(4B) +frame_num(4B)

) (
   // Port declarations
   //input                               refclk_p,
   //input                               refclk_n,
   input                               dclk,
   input                               reset,
   output                              resetdone_out,
   input                               qplllock_out,
   //output                              coreclk_out,
   output                              rxrecclk_out,

      // AXI Lite config I/F
   input                               s_axi_aclk,
   input                               s_axi_aresetn,
   input       [10:0]                  s_axi_awaddr,
   input                               s_axi_awvalid,
   output                              s_axi_awready,
   input       [31:0]                  s_axi_wdata,
   input                               s_axi_wvalid,
   output                              s_axi_wready,
   output      [1:0]                   s_axi_bresp,
   output                              s_axi_bvalid,
   input                               s_axi_bready,
   input       [10:0]                  s_axi_araddr,
   input                               s_axi_arvalid,
   output                              s_axi_arready,

   output      [31:0]                  s_axi_rdata,
   output      [1:0]                   s_axi_rresp,
   output                              s_axi_rvalid,
   input                               s_axi_rready,

   output                              xgmacint,

   input       [7:0]                   tx_ifg_delay,
   output      [25:0]                  tx_statistics_vector,
   output      [29:0]                  rx_statistics_vector,
   output                              tx_statistics_valid,
   output                              rx_statistics_valid,
   input                               tx_axis_mac_aresetn,
   input                               tx_axis_fifo_aresetn,
//   input       [63:0]                  tx_axis_fifo_tdata,
//   input       [7:0]                   tx_axis_fifo_tkeep,
//   input                               tx_axis_fifo_tvalid,
//   input                               tx_axis_fifo_tlast,
//   output                              tx_axis_fifo_tready,

   input                               rx_axis_mac_aresetn,
   input                               rx_axis_fifo_aresetn,
//   output      [63:0]                  rx_axis_fifo_tdata,
//   output      [7:0]                   rx_axis_fifo_tkeep,
//   output                              rx_axis_fifo_tvalid,
//   output                              rx_axis_fifo_tlast,
//   input                               rx_axis_fifo_tready,

   //Pause axis
   input      [15:0]                   pause_val,
   input                               pause_req,

   output                              txp,
   output                              txn,
   input                               rxp,
   input                               rxn,

   input                               signal_detect,
   input                               sim_speedup_control,
   input                               tx_fault,
   output      [7:0]                   pcspma_status,
	
	output                              txoutclk,
	input                               areset_coreclk,
	input                               txuserrdy,
	input                               coreclk,
	input                               gttxreset,
	input                               gtrxreset,
	input                               txusrclk,
	input                               txusrclk2,
	input                               qplloutclk,
	input                               qplloutrefclk,
	input                               reset_counter_done,
	
	input                               gemc_txfifo_wr_clk,     
    input [63:0]                        gemc_txfifo_din,        
    input                               gemc_txfifo_wr,         
    output                              gemc_txfifo_almost_full,
	
	input  [4:0]                        frame_cal_num_in
	//input                               pat_gen_start
	
   );

/*-------------------------------------------------------------------------*/

   // Signal declarations
    
//   wire rx_axis_mac_aresetn_i  = ~reset | rx_axis_mac_aresetn;
//   wire rx_axis_fifo_aresetn_i = ~reset | rx_axis_fifo_aresetn;
//   wire tx_axis_mac_aresetn_i  = ~reset | tx_axis_mac_aresetn;
//   wire tx_axis_fifo_aresetn_i = ~reset | tx_axis_fifo_aresetn;
   
  (* keep= "true"  *)
   wire          [63:0]                  tx_axis_mac_tdata;
   (* keep= "true"  *)
   wire         [7:0]                   tx_axis_mac_tkeep;
   (* keep= "true"  *)
   wire                                  tx_axis_mac_tvalid;
   (* keep= "true"  *)
   wire                                  tx_axis_mac_tlast;
   (* keep= "true"  *)
   wire                                 tx_axis_mac_tready;
  
  (* keep= "true"  *)
   wire         [63:0]                  rx_axis_mac_tdata;
   (* keep= "true"  *)
   wire         [7:0]                   rx_axis_mac_tkeep;
   (* keep= "true"  *)
   wire                                 rx_axis_mac_tvalid;
   (* keep= "true"  *)
   wire                                 rx_axis_mac_tuser;
   (* keep= "true"  *)
   wire                                 rx_axis_mac_tlast;

  // wire                                 coreclk;
   wire                                 tx_disable;
	/////////Ann///////////////////////////////////
	wire                                 tx_resetdone_int;
	wire                                 rx_resetdone_int;
   //wire                                 reset_counter_done;
	//wire                                 gttxreset;
	//wire                                 gtrxreset;
	//wire                                 qplloutclk;
	//wire                                 qplloutrefclk;
	 (* keep = "true" *)
	 wire        txfifo_rd;
     wire [63:0] txfifo_dout;
     wire        txfifo_empty;
     
     reg    app_end_of_frame;
     (* keep= "true"  *)
     wire   app_valid;
     wire  [63:0]    app_data;
	
	
	
  // assign coreclk_out = coreclk;
	
	assign resetdone_out          = tx_resetdone_int && rx_resetdone_int;

	
 //---------------------------------------------------------------------------
  // Instantiate the AXI 10G Ethernet core
  //---------------------------------------------------------------------------
  axi_10g_ethernet_0 ethernet_core_i (
      .dclk                            (dclk),
      .coreclk                         (coreclk),
      .txusrclk                        (txusrclk),
      .txusrclk2                       (txusrclk2),
      .txoutclk                        (txoutclk),
      .areset_coreclk                  (areset_coreclk),
      .txuserrdy                       (txuserrdy),
      .rxrecclk_out                    (rxrecclk_out),
      .areset                          (reset),
      .tx_resetdone                    (tx_resetdone_int),
      .rx_resetdone                    (rx_resetdone_int),
      .reset_counter_done              (reset_counter_done),
      .gttxreset                       (gttxreset),
      .gtrxreset                       (gtrxreset),
      .qplllock                        (qplllock_out),
      .qplloutclk                      (qplloutclk),
      .qplloutrefclk                   (qplloutrefclk),
		
      .tx_ifg_delay                    (tx_ifg_delay),
      .tx_statistics_vector            (tx_statistics_vector),
      .tx_statistics_valid             (tx_statistics_valid),
      .rx_statistics_vector            (rx_statistics_vector),
      .rx_statistics_valid             (rx_statistics_valid),
      .s_axis_pause_tdata              (pause_val),
      .s_axis_pause_tvalid             (pause_req),

      .tx_axis_aresetn                 (tx_axis_mac_aresetn),
      .s_axis_tx_tdata                 (tx_axis_mac_tdata),
      .s_axis_tx_tvalid                (tx_axis_mac_tvalid),
      .s_axis_tx_tlast                 (tx_axis_mac_tlast),
      .s_axis_tx_tuser                 (1'b0),
      .s_axis_tx_tkeep                 (tx_axis_mac_tkeep),
      .s_axis_tx_tready                (tx_axis_mac_tready),

      .rx_axis_aresetn                 (rx_axis_mac_aresetn),
      .m_axis_rx_tdata                 (rx_axis_mac_tdata),
      .m_axis_rx_tkeep                 (rx_axis_mac_tkeep),
      .m_axis_rx_tvalid                (rx_axis_mac_tvalid),
      .m_axis_rx_tuser                 (rx_axis_mac_tuser),
      .m_axis_rx_tlast                 (rx_axis_mac_tlast),
      .s_axi_aclk                      (s_axi_aclk),
      .s_axi_aresetn                   (s_axi_aresetn),
      .s_axi_awaddr                    (s_axi_awaddr),
      .s_axi_awvalid                   (s_axi_awvalid),
      .s_axi_awready                   (s_axi_awready),
      .s_axi_wdata                     (s_axi_wdata),
      .s_axi_wvalid                    (s_axi_wvalid),
      .s_axi_wready                    (s_axi_wready),
      .s_axi_bresp                     (s_axi_bresp),
      .s_axi_bvalid                    (s_axi_bvalid),
      .s_axi_bready                    (s_axi_bready),
      .s_axi_araddr                    (s_axi_araddr),
      .s_axi_arvalid                   (s_axi_arvalid),
      .s_axi_arready                   (s_axi_arready),
      .s_axi_rdata                     (s_axi_rdata),
      .s_axi_rresp                     (s_axi_rresp),
      .s_axi_rvalid                    (s_axi_rvalid),
      .s_axi_rready                    (s_axi_rready),

      .xgmacint                        (xgmacint),

      // Serial links
      .txp                             (txp),
      .txn                             (txn),
      .rxp                             (rxp),
      .rxn                             (rxn),

      .sim_speedup_control             (sim_speedup_control),
      .signal_detect                   (signal_detect),
      .tx_fault                        (tx_fault),
      .tx_disable                      (tx_disable),
      .pcspma_status                   (pcspma_status)
   );
   

 transmitter transmitter0
 (   
    .reset                             (reset),
    .app_clk                           (coreclk),
    .app_valid                         (app_valid),
    .app_data                          (app_data),
    .app_pkt_len                       (pkt_len),  //8k data + pkt_cnt(4B) +frame_num(4B)=8200B
    .app_end_of_frame                  (app_end_of_frame),
    .app_tx_afull                      (app_tx_afull),
    //.app_tx_overflow                   (),
    .src_mac_addr                      (src_mac_addr),
    .dest_mac_addr                     (dest_mac_addr),
    .src_ip_addr                       (src_ip_addr),
    .dest_ip_addr                      (dest_ip_addr),
    .src_port_number                   (0),
    .dest_port_number                  (1),
    .enable_vlan                       (1'b0),
    .vlan_id                           (12'h0), 
    .vlan_priority                     (3'b000),
    .preamble_data                     (56'h0),
    .enable_custom_preamble            (1'b0),
    .mac_clk                           (coreclk),
    .mac_tx_tdata                      (tx_axis_mac_tdata),
    .mac_tx_tkeep                      (tx_axis_mac_tkeep),
    .mac_tx_tvalid                     (tx_axis_mac_tvalid),
    .mac_tx_tlast                      (tx_axis_mac_tlast),
    .mac_tx_tready                     (tx_axis_mac_tready),
    .pcspma_status                     (pcspma_status)
    );  
    
 receiver       receiver
 (
    .mac_clk                            (coreclk),
    .mac_rx_tdata                       (rx_axis_mac_tdata),
    .mac_rx_tkeep                       (rx_axis_mac_tkeep),
    .mac_rx_tvalid                      (rx_axis_mac_tvalid),
    .mac_rx_tlast                       (rx_axis_mac_tlast),
    .mac_rx_tuser                       (rx_axis_mac_tuser),
    .mac_rx_tready                      (1'b1),
    .phy_rx_up                          (pcspma_status[0]),
    .local_mac                          (dest_mac_addr),
    .local_ip                           (src_ip_addr),
    .local_port                         (1),
    .app_rx_clk                         (),
    .app_rx_data_valid                  (),
    .app_rx_data                        (),
    .app_rx_end_of_frame                (),
    .app_rx_src_mac_addr                (),
    .app_rx_dest_mac_addr               (),
    .app_rx_src_ip_addr                 (),
    .app_rx_dest_ip_addr                (),
    .app_rx_src_port_number             (),
    .app_rx_dest_port_number            (),
    .app_rx_pkt_len                     ()
   
    
 );
 
 GEMC_TXFIFO txfifo (
       .rst                  (reset), // input rst
       .wr_clk               (gemc_txfifo_wr_clk), // input wr_clk
       .rd_clk               (coreclk), // input rd_clk
       .din                  (gemc_txfifo_din), // input [63 : 0] din
       .wr_en                (gemc_txfifo_wr), // input wr_en
       .rd_en                (txfifo_rd), // input rd_en
       .dout                 (txfifo_dout), // output [63 : 0] dout
       .full                 (), // output full
       .almost_full          (gemc_txfifo_almost_full), // output almost_full
       .empty                (txfifo_empty) // output empty
 );
 
     reg  [11:0]    data_cnt; //64bit
     (* keep= "true"  *)
     reg  [1:0]     state;
     reg  [31:0]    pkt_num;
     reg  [31:0]    frame_num;
     
 always @(posedge coreclk)begin
     if(reset)begin
        app_end_of_frame<=1'b0;
        data_cnt<=12'h0;
        state<=2'b00;
        pkt_num<=32'h0;
       // frame_num<=32'h0;
     end else begin
        case(state)
           0:begin
                app_end_of_frame<=1'b0;
                if (!txfifo_empty) begin
                    state<=2'b01;
                    app_end_of_frame<=1'b0;
                 end
              end
           1:begin //pkt_cnt(4B) +frame_num(4B)
                if(!app_tx_afull)begin
                   state<=2'b10;
                   pkt_num<=pkt_num+1;
                end
             end
           2:begin                
               if(app_valid)begin
                  if(data_cnt==12'h3ff)begin  //8kB data
                     data_cnt<=12'h0;
                     
                     state<=2'b11;
                     app_end_of_frame<=1'b1;
                  end else begin
                     data_cnt<=data_cnt+1;
                  end
               end
             end
           3:begin
                
                 state<=2'b00;
             end
         endcase
     end
  end
  
  reg [11:0]    pkt_cnt_in_frame;
  reg           app_end_of_frame_buf;
  always @(posedge coreclk)begin
      if(reset)begin
         frame_num<=32'h0;
         pkt_cnt_in_frame<=12'h0;
         app_end_of_frame_buf<=1'b0;
      end else begin
         app_end_of_frame_buf<=app_end_of_frame;
         if((!app_end_of_frame_buf) & app_end_of_frame) begin
            if(pkt_cnt_in_frame==12'h3ff)begin
              pkt_cnt_in_frame<=12'h0;
              frame_num<=frame_num+1;
            end else begin
              pkt_cnt_in_frame<=pkt_cnt_in_frame+1;
            end
         end
      end
   end
         
  
  //assign app_valid=((state==1) | (state==2)) & (~app_tx_afull);
  assign app_valid=((state==1)&(~app_tx_afull))|txfifo_rd;
  assign app_data=(state==1)?{pkt_num,frame_num[15:0],11'h0,frame_cal_num_in} : txfifo_dout;
  assign txfifo_rd=(state==2) & (~app_tx_afull) &(~txfifo_empty);
 

   
////--------------- user logic ------------------//
//        reg [2:0]       state;
//		reg [7:0]       byte_cnt;
//		reg [11:0]      pkt_cnt;
//		(* keep= "true"  *)
//		reg [15:0]      frame_num;
//		always @(posedge coreclk) begin
//		   if(reset)begin 
//		     state<=3'b000;
//			 byte_cnt<=8'h0;
//			 tx_axis_mac_tlast<=1'b0;
//		   end else begin
//		      case(state)
//			     3'b000:begin   
//				          if(~txfifo_empty)begin  
//						      state<=3'b001;
//						  end
//					   end
//			     3'b001:begin 
//				          if(tx_axis_mac_tvalid&tx_axis_mac_tready)begin  //包头1，des addr + src addr
//						     state<=3'b010;
//					      end
//					   end
//			     3'b010:begin 
//				          if(tx_axis_mac_tvalid&tx_axis_mac_tready)begin  //包头2 src addr + pkt_cnt
//						     state<=3'b011;
//					      end
//					   end
//				 3'b011:begin
//				           if(tx_axis_mac_tvalid&tx_axis_mac_tready)begin  //包头2 src addr + frame_num
//                              state<=3'b100;
//                           end 
//                        end
//				 3'b100:begin  
//				         if(tx_axis_mac_tvalid&tx_axis_mac_tready)begin  
//	                         if(byte_cnt==8'h7f)begin   
//								state<=3'b000;
//								tx_axis_mac_tlast<=1'b0;
//								byte_cnt<=8'h0;
//						     end else if(byte_cnt==8'h7e)begin 
//							    tx_axis_mac_tlast<=1'b1;
//								byte_cnt<=byte_cnt+1;
//						     end else begin
//							    byte_cnt<=byte_cnt+1;
//							 end
//						  end
//					   end
//			  endcase
//		   end
//		end

//      reg [2:0] state_reg;
//	always @(posedge coreclk) begin
//		   if(reset)begin 
//              pkt_cnt<=12'h0;
//			  frame_num<=16'h0;
//              state_reg<=3'b000;			  
//         end else begin
//			  state_reg<=state;
//			  if((state==3'b000)&(state_reg==3'b100))begin
//			     pkt_cnt<=pkt_cnt+1;
//				  if(pkt_cnt==12'hfff)begin  //一帧图像
//			        frame_num<=frame_num+1;
//			     end
//			  end			  
//			end
//	 end
 			
		
//	assign 	tx_axis_mac_tkeep=8'hff;
////	assign   tx_axis_mac_tvalid=(state==2'b01) | (state==2'b10) | ((state==2'b11)& (~txfifo_empty));
////	assign   tx_axis_mac_tdata=(state==2'b01)?( {16'h0405,des_addr}) :((state==2'b10)? ({4'h0,pkt_cnt,48'h04025a010203}):txfifo_dout);
//	assign   txfifo_rd=(state==3'b100) & (~txfifo_empty) & tx_axis_mac_tready; 
//	always @(*) begin
//	        if(reset)begin
//	           tx_axis_mac_tvalid<=1'b0;
//	           tx_axis_mac_tdata<=64'h0;
//	        end else begin
//	           case(state)
//	              3'b000:begin
//	                       tx_axis_mac_tvalid<=1'b0;
//	                       tx_axis_mac_tdata<=64'h0;
//	                     end
//	              3'b001:begin
//	                        tx_axis_mac_tvalid<=1'b1;
//                            tx_axis_mac_tdata<={16'h0405,des_addr};
//	                     end
//	              3'b010:begin
//	                       tx_axis_mac_tvalid<=1'b1;
//	                       tx_axis_mac_tdata<={4'h0,pkt_cnt,48'h040a5a010203};
//	                     end
//	              3'b011:begin
//	                       tx_axis_mac_tvalid<=1'b1;
//                           tx_axis_mac_tdata<={48'b0,frame_num};
//                         end
//                  3'b100:begin
//                            tx_axis_mac_tvalid<=~txfifo_empty;
//                            tx_axis_mac_tdata<=txfifo_dout;
//                         end
//               endcase
//             end
//          end
	               
	                     

       
//       reg 	[7:0]   rx_cnt;
//       reg  [47:0]  head1;
//       reg  [47:0]  head2;
//       reg  [11:0]  rx_pkt_cnt_old;
//       reg  [11:0]  rx_pkt_cnt;
//       (* keep= "true"  *)
//       reg          head_err;
//       (* keep= "true"  *)
//       reg          pkt_num_err;
       
//       always @(posedge coreclk)begin
//          if(reset)begin
//             rx_cnt<=8'h0;
//             head1<=64'h0;
//             head2<=64'h0;
//             rx_pkt_cnt_old<=12'h0;
//             rx_pkt_cnt<=12'hfff;
//              head_err<=1'b0;
//              pkt_num_err<=1'b0;
//          end else begin
//             if(rx_axis_mac_tvalid)begin
//               if(rx_cnt==8'h82)begin
//                  rx_cnt<=8'h0;
//               end else begin
//                  rx_cnt<=rx_cnt+1;
//               end
//               if(rx_cnt==8'h0)begin
//                 head1<=rx_axis_mac_tdata[47:0];
//                 head2[15:0]<=rx_axis_mac_tdata[63:48];
//                 head_err<=1'b0;
//                 pkt_num_err<=1'b0;
//               end else if(rx_cnt==8'h1)begin
//                 head2[47:16]<=rx_axis_mac_tdata[31:0];
//                 rx_pkt_cnt_old<=rx_pkt_cnt;
//                 rx_pkt_cnt<=rx_axis_mac_tdata[59:48];
//               end else if( rx_cnt==8'h2)begin
//                 if((head1!=des_addr)|(head2!=src_addr))begin
//                    head_err<=1'b1;
//                 end else if((rx_pkt_cnt_old!=(rx_pkt_cnt-1)) & (rx_pkt_cnt!=0))begin
//                    pkt_num_err<=1'b1;
//                 end
//               end
//             end
//          end
//       end   
              
endmodule
