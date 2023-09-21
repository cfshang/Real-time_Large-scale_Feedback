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
//------------------------------------------------------------------------------------------
// Title      : Frame generator
// Project    : 10G Gigabit Ethernet
//------------------------------------------------------------------------------------------
// File       : axi_10g_ethernet_0_axi_pat_gen.v
// Author     : Xilinx Inc.
// -----------------------------------------------------------------------------------------
// Description: This is a very simple pattern generator which will generate packets
//              with the supplied dest_addr and src_addr and incrementing data.  The packet size
//              increments between the min and max size (which can be set to the same value if a
//              specific size is required
//
//              the pattern generator is throttled by the FIFO hitting full which in turn
//              is throttled by the transmit rate of the MAC.  Since the example
//              design system does not use active flow control it is possible for the FIFO's to
//              overflow on RX.  To avoid this a basic rate controller is implemented which will
//              throttle the pattern generator output to below the maximum data rate.
//------------------------------------------------------------------------------------------

`timescale 1ps/1ps

(* dont_touch = "yes" *)
module transmitter (
   input wire         reset, 
   input wire app_clk,                
   input wire app_valid,              
   input wire [63:0] app_data,         
   input wire [15:0] app_pkt_len,     
   input wire app_end_of_frame,        
   input wire [47:0] src_mac_addr,
   input wire [47:0] dest_mac_addr,
   input wire [31:0] src_ip_addr,
   input wire [31:0] dest_ip_addr,
   input wire [15:0] src_port_number,
   input wire [15:0] dest_port_number,
   output wire app_tx_afull,
   //output wire app_tx_overflow,

   input wire          enable_vlan,
   input wire  [11:0]  vlan_id,
   input wire  [2:0]   vlan_priority,
   input wire  [55:0]  preamble_data,
   input wire          enable_custom_preamble,

   input wire           mac_clk,
   output  [63:0]        mac_tx_tdata,
   output  [7:0]         mac_tx_tkeep,
   output                mac_tx_tvalid,
   output                mac_tx_tlast,
   input  wire           mac_tx_tready 
   ,
   input [7:0] pcspma_status
);
   wire app_reset;
   wire mac_reset;
   
   axi_10g_ethernet_0_sync_reset app_reset_gen (
   .clk                             (app_clk),
   .reset_in                        (reset),
   .reset_out                       (app_reset)
   );
   
    axi_10g_ethernet_0_sync_reset mac_reset_gen (
   .clk                             (mac_clk),
   .reset_in                        (reset),
   .reset_out                       (mac_reset)
   );
   
   reg [47:0] local_mac;
   reg [47:0] dest_mac;
   reg [31:0] local_ip;
   reg [31:0] packet_ctrl_ip;
   reg [15:0] local_port;
   reg [15:0] packet_ctrl_port;
   reg [15:0] packet_ctrl_size;
   reg [15:0] pkt_len;
   
     always @ (posedge mac_clk )
     begin
        if(mac_reset)
            begin  
                 local_mac        <= 48'h02020A000001;
                 dest_mac         <= 48'hE41D2D1CFC01;
                 local_ip         <= 32'h0A000001;
                 packet_ctrl_ip   <= 32'h0A0000C9;
                 local_port       <= 16'hEA60;
                 packet_ctrl_port <= 16'hEA60;
                 packet_ctrl_size <= 16'h404;
                 pkt_len          <= 16'h2020;
             end
         else
             begin  
                  local_mac        <= src_mac_addr;
                  dest_mac         <= dest_mac_addr;
                  local_ip         <= src_ip_addr;
                  packet_ctrl_ip   <= dest_ip_addr;
                  local_port       <= src_port_number;
                  packet_ctrl_port <= dest_port_number;
                  packet_ctrl_size <= {3'h0,app_pkt_len[15:3]};
                  pkt_len          <= app_pkt_len;
              end
       end
   
   reg [15:0] ip_length;
   reg [15:0] udp_length;
   reg [17:0] ip_checksum_0;
   reg [16:0] ip_checksum_1;
   reg [15:0] ip_checksum;
   wire [17:0] ip_checksum_fixed_0;
   wire [16:0] ip_checksum_fixed_1;
   wire [15:0] ip_checksum_fixed;
   wire tready;
   assign tready = mac_tx_tready;
   (* keep = "true" *)
   wire packet_rd;
   wire [63:0] packet_data;
   assign packet_rd = tready && (gen_state == TX_SEND_HDR_5 || (gen_state == ADDR_VLAN) || ((gen_state == TX_SEND_HDR_6 || gen_state == DATA)&& (tx_size != 0)));

   wire empty;

//tx_fifo_64x2048 tx_fifo (
//    .rst(app_reset), 
//    .wr_clk(app_clk), 
//    .rd_clk(mac_clk), 
//    .din(app_data), 
//    .wr_en(app_valid), 
//    .rd_en(packet_rd), 
//    .dout(packet_data), 
//    .full(), 
//    .almost_full(app_tx_afull), 
//    .overflow(app_tx_overflow), 
//    .empty(empty)
//    );
tx_fifo_64x2048 tx_fifo (
      .clk(app_clk),                  // input wire clk
      .rst(app_reset),                  // input wire rst
        .din(app_data),                  // input wire [63 : 0] din
        .wr_en(app_valid),              // input wire wr_en
        .rd_en(packet_rd),              // input wire rd_en
        .dout(packet_data),                // output wire [63 : 0] dout
        .full(),                // output wire full
        .almost_full(app_tx_afull),  // output wire almost_full
        .empty(empty)              // output wire empty
    );    
    reg [3:0] app_symbol_cnt;
    reg app_symbol_valid;
    always @ (posedge app_clk )
    begin
         if(app_reset)
              begin
                   app_symbol_cnt <= 4'hf;
               end
          else if(app_symbol_cnt < 4'hf)
              begin
               app_symbol_cnt <= app_symbol_cnt + 4'h1;
               end
          else if(app_end_of_frame)
              begin
                   app_symbol_cnt <= 4'h0;
               end
          else 
              begin
               app_symbol_cnt <= app_symbol_cnt;
               end
   end
   
  always @ (posedge app_clk )
    begin
         if(app_reset)
            begin
                app_symbol_valid <= 1'b0;
            end
         else if ( (app_symbol_cnt > 4'h0) && (app_symbol_cnt < 4'hf))
            begin
                app_symbol_valid <= 1'b1;
            end
         else 
            begin
                app_symbol_valid <= 1'b0;
            end    
   end
  
  reg mac_symbol_valid;
  reg mac_symbol_valid_reg;
  wire mac_end_of_frame;
  assign mac_end_of_frame = !mac_symbol_valid_reg && mac_symbol_valid;
  
  always @ (posedge mac_clk )
  begin
       if(mac_reset)
           begin
                 mac_symbol_valid <= 1'b0;
                   mac_symbol_valid_reg <= 1'b0;
            end
        else 
           begin
                 mac_symbol_valid <= app_symbol_valid;
                   mac_symbol_valid_reg <= mac_symbol_valid;
            end
   end
  
	
      reg [3:0] symbol_cnt;
      reg symbol_valid_1; // this signal is actually valid in the case that the input signal app_end_of_frame is valid  and  the transmitter of 10 GbE is not working ( it means the state is IDLE).
      reg symbol_valid_2;//this signal is actually valid in the case that the input signal app_end_of_frame is valid while the transmitter of 10 GbE is working. this valid signal should last until the state changes to be IDLE.
      wire symbol_valid;
      assign symbol_valid = symbol_valid_1 || symbol_valid_2;
      
      always @ (posedge mac_clk )
      begin
           if(mac_reset)
                begin
                     symbol_cnt <= 4'hf;
                 end
            else if(symbol_cnt < 4'hf)
                begin
                 symbol_cnt <= symbol_cnt + 4'h1;
                 end
            else if(mac_end_of_frame)
                begin
                     symbol_cnt <= 4'h0;
                 end
            else 
                begin
                 symbol_cnt <= symbol_cnt;
                 end
     end
     
    always @ (posedge mac_clk )
      begin
           if(mac_reset)
              begin
                  symbol_valid_1 <= 1'b0;
              end
           else if (mac_end_of_frame)
              begin
                  symbol_valid_1 <= 1'b1;
              end
           else if ( symbol_cnt == 4'h1 )
              begin
                  symbol_valid_1 <= 1'b0;
              end
           else 
              begin
                  symbol_valid_1 <= symbol_valid_1;
              end    
     end
     
     always @ (posedge mac_clk )
       begin
            if(mac_reset)
               begin
                   symbol_valid_2 <= 1'b0;
               end
            else if (mac_end_of_frame)
               begin
                   symbol_valid_2 <= 1'b1;
               end
            else if (gen_state == IDLE)
               begin
                   symbol_valid_2 <= 1'b0;
               end
            else 
               begin
                   symbol_valid_2 <= symbol_valid_2;
               end    
      end
    
    reg symbol_valid_reg;
    wire tx_trig;
    assign tx_trig = symbol_valid_reg && !symbol_valid;


always @ (posedge mac_clk )
begin
     if(mac_reset)
	     begin
				 symbol_valid_reg <= 1'b0;
		  end
	  else 
	     begin
				 symbol_valid_reg <= symbol_valid;
		  end
end


   // gen_state states
//   localparam                          IDLE        = 0,
//                                       PREAMBLE    = 1,
//                                       ADDR        = 2,
//                                       ADDR_TL_D   = 3,  // ADDRESS + TYPE/LENGTH + DATA
//                                       ADDR_VLAN   = 4,  // ADDRESS + VLAN
//                                       TL_D        = 5,  // TYPE/LENGTH + DATA
//                                       DATA        = 6;  // DATA
                                       
   localparam                          IDLE        = 4'd0,
                                       PREAMBLE    = 4'd1,
                                       TX_SEND_HDR_1 = 4'd2,
                                       TX_SEND_HDR_2 = 4'd3,
                                       TX_SEND_HDR_3 = 4'd4,
                                       TX_SEND_HDR_4 = 4'd5,
                                       TX_SEND_HDR_5 = 4'd6,
                                       TX_SEND_HDR_6 = 4'd7,// UDP_checksum + DATA
                                       ADDR_VLAN   = 4'd8,  // ADDRESS + VLAN
                                       TL_D        = 4'd9,  // TYPE/LENGTH + DATA
                                       DATA        = 4'd10,  // DATA
                                       LAST_DATA   = 4'd11;


   // used when custom preamble is enabled
   localparam                          START_CODE  = 8'hFB;
   
   reg         [3:0]                   gen_state        = 4'd0;
   wire        [31:0]                  vlan_header;
  // generate the vlan fields
    assign vlan_header                  = {8'h81, 8'h00, vlan_priority, 1'b0, vlan_id};
    
   reg                                tvalid_int;
   reg                                 tlast_int      = 0;
   reg         [7:0]                   tkeep_int      = 8'd0;
   reg         [63:0]                  tdata_int      = 64'd0;
   assign mac_tx_tvalid = tvalid_int;
   assign mac_tx_tlast = tlast_int;
   assign mac_tx_tkeep = tkeep_int;
   assign mac_tx_tdata = tdata_int;

   reg [15:0] tx_size;


   //--------------------------
   // Main state machine
   //--------------------------
   // (if preamble enabled)
   // 1st cycle : PREAMBLE
   // 2nd cycle : DA + SA++++++++++++++++++++++
   // 3rd cycle : SA + L/T + DATA  OR!  SA + VLAN
   // 4th cycle : DATA OR! L/T + DATA
   // 5th cycle : DATA

   // (if preamble disabled)
   // 1st cycle : DA + SA
   // 2nd cycle : SA + L/T + DATA  OR!  SA + VLAN
   // 3rd cycle : DATA OR! L/T + DATA
   // 4th cycle : DATA

/* UDP * 20161025 by Lin Shu */
//1st cycle: {src_mac[4], src_mac[5], dest_mac[0], dest_mac[1] dest_mac[2], dest_mac[3], dest_mac[4], dest_mac[5]}
//2nd cycle: {IP Type, IP version, Ethetype[0], Ethertype[1], src_mac[0], src_mac[1], src_mac[2], src_mac[3]}
//3rd cycle: {protocol(UDP), TTL, frag_offset[0], flags, ID[0], ID[1], ipsize[0], ipsize[1]}
//4th cycle: {dest_ip[23:16], dest_ip[31:24], src_ip[7:0], src_ip[15:8], src_ip[23:16], src_ip[31:24], ip_checksum[7:0], ip_checksum[15:8]}
//5th cycle: {udp_length[7:0], udp_length[15:8], dest_port[7:0], dest_port[15:8],src_port[7:0], src_port[15:8], dest_ip[7:0],dest_ip[15:8]}
//6th cycle: {data,8'h00,8'h00}
//7th cycle: data

reg [15:0] data_leftovers;

   always @(posedge mac_clk)
   begin
   tlast_int         <= 1'b0;
   /* always latch data to store leftovers */
   data_leftovers <= packet_data[15:0];
      if (mac_reset) begin
         tx_size           <=  16'h0;
         gen_state                     <= IDLE;
         udp_length        <= 16'd0;
         ip_length         <= 16'd0;
         ip_checksum_0     <= 18'd0;
         ip_checksum_1     <= 17'd0;
         ip_checksum       <= 16'd0;
         tvalid_int <= 1'b0;
         tlast_int  <= 1'b0;
         tkeep_int  <= 8'b00000000;
      end
      else begin
         case (gen_state)
            IDLE : begin
              if(tx_trig) begin
                 tvalid_int <= 1'b1;
                 tkeep_int <= 8'b11111111;
                 tx_size   <= packet_ctrl_size - 16'h1;
                 if (enable_custom_preamble) begin
                    gen_state      <= PREAMBLE;
                 end
                 else begin
                    gen_state      <= TX_SEND_HDR_1;
                 end
              end
            end
            PREAMBLE : begin
               if (tready) begin
                    gen_state            <= TX_SEND_HDR_1;
               end
            end
            TX_SEND_HDR_1: begin
               if (tready) begin
                  if (enable_vlan) begin
                     gen_state         <= ADDR_VLAN;
                  end
                  else begin
                     gen_state         <= TX_SEND_HDR_2;
                  end
               end
            end
            TX_SEND_HDR_2 : begin
               if (tready) begin
                  gen_state            <= TX_SEND_HDR_3;
               end
            end
            TX_SEND_HDR_3 : begin
               if (tready) begin
                  gen_state            <= TX_SEND_HDR_4;
               end
            end
            TX_SEND_HDR_4 : begin
               if (tready) begin
                  gen_state            <= TX_SEND_HDR_5;
               end
            end
            TX_SEND_HDR_5 : begin
               if (tready) begin
                  gen_state            <= TX_SEND_HDR_6;
               end
            end                        
            TX_SEND_HDR_6 : begin
               if (tready) begin
                  tx_size       <= tx_size - 16'h1;
                  if(tx_size == 16'd0)
                     begin
                     tkeep_int          <= 8'b00000011;
                     gen_state         <= LAST_DATA;
                     tlast_int         <= 1'b1;
                     end
                  else
                  begin
                  gen_state            <= DATA;
                  end
               end
            end
            ADDR_VLAN : begin
               if (tready) begin
                  gen_state            <= TL_D;
               end
            end
            TL_D : begin
               if (tready) begin
               tx_size       <= tx_size - 16'h1;
                  if(tx_size == 16'd0)
                     begin
                     tkeep_int          <= 8'b00000011;
                     gen_state         <= LAST_DATA;
                     tlast_int         <= 1'b1;
                     end
                  else
                  begin
                  gen_state            <= DATA;
                  end
               end
            end
            DATA : begin
               if (tready) begin
               tx_size       <= tx_size - 16'h1;
                  if (tx_size == 16'd0)
                     begin
                     tkeep_int          <= 8'b00000011;
                     gen_state         <= LAST_DATA;
                     tlast_int         <= 1'b1;
                     
                     end
                  else
                     begin
                     gen_state         <= DATA;
                     end
               end
            end
            LAST_DATA:begin
                if(tready) begin
                gen_state               <= IDLE;
                tkeep_int          <= 8'b00000000;
                tvalid_int <= 1'b0;
                tlast_int <= 1'b0;
                end
             end
            default : begin
               gen_state               <= IDLE;
            end
         endcase
               // compute the ip length
         ip_length <= pkt_len + 16'd28;
         // compute the udp length
         udp_length <= pkt_len + 16'd8;
         // compute the ip checksum (1's complement logic)
         ip_checksum_0 <= {2'b00, ip_checksum_fixed     }+
                          {2'b00, ip_length             }+
                          {2'b00, packet_ctrl_ip[31:16] }+
                          {2'b00, packet_ctrl_ip[15:0 ] };
         ip_checksum_1 <= {1'b0 , ip_checksum_0[15:0 ]  }+
                          {15'b0, ip_checksum_0[17:16]  };
         ip_checksum   <= ~(ip_checksum_1[15:0] + {15'b0, ip_checksum_1[16]});
      end
   end

  /* checkdsum assignments */
  assign ip_checksum_fixed_0 = {8'h00, 16'h8412} + {8'h00, local_ip[31:16]} + {8'h00, local_ip[15:0]};
  assign ip_checksum_fixed_1 = {1'b0, ip_checksum_fixed_0[15:0]} + {15'b0, ip_checksum_fixed_0[17:16]};
  assign ip_checksum_fixed   = {ip_checksum_fixed_1[15:0]} + {15'b0, ip_checksum_fixed_1[16]};
 
   // Form tdata_int here
  
      always @(*)
      begin
         case (gen_state)
            PREAMBLE           : tdata_int    <= {preamble_data[7:0],preamble_data[15:8],preamble_data[23:16],preamble_data[31:24],
                                                  preamble_data[39:32],preamble_data[47:40],preamble_data[55:48],START_CODE};
                                /* {src_mac[4], src_mac[5], dest_mac[0], dest_mac[1] dest_mac[2], dest_mac[3], dest_mac[4], dest_mac[5]} */
            TX_SEND_HDR_1      : tdata_int    <= {local_mac[39:32], local_mac[47:40], dest_mac[ 7:0 ], dest_mac[15:8 ],
                                                      dest_mac[23:16],  dest_mac[31:24], dest_mac[39:32], dest_mac[47:40]};
                               /* {IP Type, IP version, Ethetype[0], Ethertype[1], src_mac[0], src_mac[1], src_mac[2], src_mac[3]} */                       
            TX_SEND_HDR_2      : tdata_int    <= {         8'h00,           8'h45,            8'h00,           8'h08,
                                                    local_mac[7:0], local_mac[15:8], local_mac[23:16], local_mac[31:24]};
                               /* {protocol(UDP), TTL, frag_offset[0], flags, ID[0], ID[1], ipsize[0], ipsize[1]} */ 
            TX_SEND_HDR_3      : tdata_int    <= {8'h11, 8'hff, 8'h00, 8'h40, 8'h00, 8'h00, ip_length[7:0], ip_length[15:8]};
                       
            TX_SEND_HDR_4      : tdata_int    <= {packet_ctrl_ip[23:16], packet_ctrl_ip[31:24], local_ip[7:0], local_ip[15:8], local_ip[23:16], local_ip[31:24], ip_checksum[7:0], ip_checksum[15:8]};
           
            TX_SEND_HDR_5      : tdata_int    <= {udp_length[7:0], udp_length[15:8], packet_ctrl_port[7:0], packet_ctrl_port[15:8],
                                                 local_port[7:0], local_port[15:8],   packet_ctrl_ip[7:0],   packet_ctrl_ip[15:8]};
                                                 
//            TX_SEND_HDR_6      : tdata_int    <= {packet_data[23:16], packet_data[31:24], packet_data[39:32], packet_data[47:40],
//                                                                      packet_data[55:48], packet_data[63:56], 8'h00,              8'h00};
            TX_SEND_HDR_6      : tdata_int    <= {packet_data[23:16], packet_data[31:24], packet_data[39:32], packet_data[47:40],
                                                 packet_data[55:48], packet_data[63:56], 8'h00,              8'h00};
                                                          
            ADDR_VLAN          : tdata_int    <= {vlan_header[7:0],vlan_header[15:8],vlan_header[23:16],vlan_header[31:24],
                                                 local_mac[7:0], local_mac[15:8], local_mac[23:16], local_mac[31:24]};
            TL_D               : tdata_int    <= {packet_data[23:16], packet_data[31:24], packet_data[39:32], packet_data[47:40],
                                                 packet_data[55:48], packet_data[63:56],pkt_len[7:0],pkt_len[15:8]};
            DATA               : tdata_int    <= {packet_data[23:16], packet_data[31:24],    packet_data[39:32],    packet_data[47:40],
                                                  packet_data[55:48], packet_data[63:56], data_leftovers[ 7:0 ], data_leftovers[15:8 ]};
            LAST_DATA         : tdata_int    <= {48'h00000000, data_leftovers[7:0], data_leftovers[15:8]};                                      
         endcase
      end
       
//       wire [88:0] probe0;
       
//       assign probe0[63:0]  =  mac_tx_tdata;
//       assign probe0[71:64] =  mac_tx_tkeep;
//       assign probe0[72]    =  mac_tx_tvalid;
//       assign probe0[73]    =  mac_tx_tlast;
//       assign probe0[74]    =  mac_tx_tready;
//       assign probe0[82:75] = pcspma_status;
//       assign probe0[83] = app_tx_afull;
//       assign probe0[84] = tx_trig;
//       assign probe0[88:85] = gen_state;
       
       
//      ila_2 debug_10GbE_transmitter (
//             .clk(mac_clk), // input wire clk
         
         
//             .probe0(probe0) // input wire [1023:0] probe0
//         ); 
       
endmodule
