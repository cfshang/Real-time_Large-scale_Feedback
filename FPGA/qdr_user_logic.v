`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/06/14 16:28:58
// Design Name: 
// Module Name: user_logic
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module user_logic
#(
   parameter                                     picture_size       =524288, //以128 bit为单位
	parameter                                     A1023       =20'h3ff00, 
	parameter                                     A1024       =20'h40000 
)	
(
    output                             app_wr_cmd0,
	output  reg [19:0]                 app_wr_addr0,
    output  [143:0]                    app_wr_data0,
	 
	 //output  [15:0]                     app_wr_bw_n0,
    output                             app_rd_cmd0,
    output  reg [19:0]                 app_rd_addr0,
    input                              app_rd_valid0,
    input   [143:0]                    app_rd_data0,
	input                              qdr_user_clk,
	 
	input                              qdr_fifoin_wr_en,
	input   [63:0]                     qdr_fifoin_wr_data,
    output                             qdr_fifoin_prog_full,
	input                              qdr_fifoin_wr_clk,
    
    output  [63:0]                     qdr_fifoout_rd_data,
    output                             qdr_fifoout_rd_data_valid,
    input                              qdr_fifoout_rd_clk,
    
    input                              emc_fifo_almost_full,
    input                              rst,
    input                              phy_init_done,
	//output  [199:0]                    trig
	
	input    [4:0]               frame_cal_num_in,
    output   reg [4:0]           frame_cal_num_out
    	 
    );
	 
	   wire             fifoin_rd;
	   wire  [127:0]    fifoin_dout;
       wire             fifoin_empty;
       wire             fifoin_valid;
       wire  [127:0]    fifoout_din;
       wire             fifoout_wr;
       wire             fifoout_rd;	
       wire             fifoout_empty;
       wire             fifoout_prog_full;

       wire  [63:0]     qdr_fifoout_rd_data_ori;		 
	 
	 qdr_in_fifo qdr_in_fifo (
		  .rst                  (rst), // input rst
		  .wr_clk               (qdr_fifoin_wr_clk), // input wr_clk
		  .rd_clk               (qdr_user_clk), // input rd_clk
		  .din                  (qdr_fifoin_wr_data), // input [63 : 0] din
		  .wr_en                (qdr_fifoin_wr_en), // input wr_en
		  .rd_en                (fifoin_rd), // input rd_en
		  .dout                 (fifoin_dout), // output [127 : 0] dout
		  .full                 (), // output full
		  .almost_full          (), // output almost_full
		  .empty                (fifoin_empty), // output empty
		  .valid                (fifoin_valid), // output valid
		  .prog_full            (qdr_fifoin_prog_full) // output prog_full
);
    qdr_out_fifo qdr_out_fifo (
		  .rst                  (rst), // input rst
		  .wr_clk               (qdr_user_clk), // input wr_clk
		  .rd_clk               (qdr_fifoout_rd_clk), // input rd_clk
		  .din                  (fifoout_din), // input [127 : 0] din
		  .wr_en                (fifoout_wr), // input wr_en
		  .rd_en                (fifoout_rd), // input rd_en
		  .dout                 (qdr_fifoout_rd_data_ori), // output [63 : 0] dout
		  .full                 (), // output full
		  .empty                (fifoout_empty), // output empty
		  .valid                (qdr_fifoout_rd_data_valid), // output valid
		  .prog_full            (fifoout_prog_full) // output prog_full
);
reg [19:0]                    low_addr;//低地址
reg [19:0]                    high_addr;//高地址
reg [19:0]                    linestart_addr;//高地址
reg                           low_flag;
//reg [19:0]                    wr_last_addr;//低地址

reg  [19:0]                   wr_cnt;
(*keep="true"*)
reg  [1:0]                    state;
reg                           ping;




always @(posedge qdr_user_clk)begin
    if(rst)begin
	    state<=2'b00;
		 app_wr_addr0<=20'h0;
		 //wr_last_addr<=20'h0;
		 wr_cnt<=20'h0;
		 low_addr<=20'h0;
		 high_addr<=20'h0;
		 linestart_addr<=20'h0;
		 low_flag<=1'b1;//从低地址开始，v1023
		 ping<=1'b0;
		 
		
	 end else begin
	    case(state)
		    0:begin
			      if(phy_init_done & (~fifoin_empty))begin 
					   state<=2'b01;					   
						if(!ping)begin   //ping
						   low_addr<=A1023;
						   high_addr<=A1024;
						end else begin  //pong
						   low_addr<=A1023+20'h80000;
						   high_addr<=A1024+20'h80000;
						end
					end
				end
			 1:begin
			      low_flag<=~low_flag;
					state<=2'b10;
			      if(low_flag==0)begin //高地址
					   app_wr_addr0<=high_addr;
					   linestart_addr<=high_addr; 
                  high_addr<=high_addr+256;						
					end else begin	   //低地址
						app_wr_addr0<=low_addr;
						linestart_addr<=low_addr;
						low_addr<=low_addr-256;
					end
				 end
			 2:begin  //写qdr
			      if(app_wr_cmd0)begin
						  
						  if(wr_cnt==(picture_size-1))begin //写完成
						     wr_cnt<=20'h0;
							  state<=2'b00;//跳转到0
						     app_wr_addr0<=20'h0;
						     //wr_last_addr<=app_wr_addr0;
							  ping<=~ping;
						  end else if(app_wr_addr0==linestart_addr+256-1)begin //一行写完
						     wr_cnt<=wr_cnt+1;
							  state<=2'b01;//一行写完,跳转到1
						  end else begin
						     wr_cnt<=wr_cnt+1;
						     app_wr_addr0<=app_wr_addr0+1;
					     end
					end
				 end

		 endcase
	 end
end
					   

assign fifoin_rd=(state==2'b10)& phy_init_done & (~fifoin_empty);

assign app_wr_cmd0=fifoin_rd;
assign app_wr_data0={16'h0,fifoin_dout};

(*keep="true"*)
reg           rd_state;
//reg           rd_ping;
reg  [1:0]    wr_state_reg;
reg  [19:0]   rd_cnt;
always @(posedge qdr_user_clk)begin
    if(rst)begin
	    rd_state<=1'b0;
		// rd_ping<=1'b0;
		 wr_state_reg<=2'b00;
		 app_rd_addr0<=20'h0;
		 rd_cnt<=20'h0;
		 
		 frame_cal_num_out<=5'h0;
	 end else begin
	   case(rd_state)
         0:begin
              wr_state_reg<=state;
              if((state==0) & (wr_state_reg==2))begin
				      rd_state<=1'b1;
				      frame_cal_num_out<=frame_cal_num_in;
                  if(ping)	app_rd_addr0<=20'h0;
                  else 	app_rd_addr0<=20'h80000;
              end
           end
         1:begin
             if(app_rd_cmd0)begin
					   if(rd_cnt==picture_size-1)begin //读完
						   rd_state<=0;
					      app_rd_addr0<=20'h0;
							//ddr_rd_done<=1'b1;
							rd_cnt<=20'h0;
						end else begin
					      app_rd_addr0<=app_rd_addr0+1;
							rd_cnt<=rd_cnt+1;
                  end							
				  end
			  end 
        endcase
    end
end	 
assign app_rd_cmd0=(rd_state==1)& (~fifoout_prog_full) & phy_init_done;
assign fifoout_wr=app_rd_valid0;
assign fifoout_din=app_rd_data0[127:0];
assign fifoout_rd=(~emc_fifo_almost_full) & (~fifoout_empty);

assign qdr_fifoout_rd_data={qdr_fifoout_rd_data_ori[55:48],
                            qdr_fifoout_rd_data_ori[63:56],
									 qdr_fifoout_rd_data_ori[39:32],
									 qdr_fifoout_rd_data_ori[47:40],
									 qdr_fifoout_rd_data_ori[23:16],
									 qdr_fifoout_rd_data_ori[31:24],
									 qdr_fifoout_rd_data_ori[7:0],
									 qdr_fifoout_rd_data_ori[15:8]};

////------test----////
reg    [31:0] wr_num;
reg    [31:0] rd_num;
reg    rd_state_reg;

always @(posedge qdr_user_clk)begin
    if(rst)begin
      wr_num<=32'h0;
		rd_num<=32'h0;
		rd_state_reg<=1'b0;
	 end else begin
	   rd_state_reg<=rd_state;
      if((state==0) & (wr_state_reg==2))begin		
        wr_num<=wr_num+1;
		end 
		if((rd_state==1)&(rd_state_reg==1'b0))begin
		  rd_num<=rd_num+1;
		end
	 end
end



/////trig/////
//assign trig[0]=app_wr_cmd0;
//assign trig[20:1]=app_wr_addr0;
//assign trig[52:21]=wr_num;
//assign trig[54:53]=state;
//assign trig[55]=app_rd_cmd0;
//assign trig[75:56]=app_rd_addr0;
//assign trig[76]=app_rd_valid0;
//assign trig[108:77]=rd_num;
//assign trig[109]=rd_state;
//assign trig[110]=qdr_fifoin_wr_en;
//assign trig[111]=qdr_fifoin_prog_full;
//assign trig[112]=fifoin_rd;
//assign trig[113]=fifoin_empty;
//assign trig[114]=fifoin_valid;
//assign trig[146:115]=fifoin_dout[31:0];
//assign trig[147]=fifoout_wr;
//assign trig[148]=fifoout_rd;
//assign trig[149]=fifoout_empty;
//assign trig[150]=fifoout_prog_full;
//assign trig[170:151]=rd_cnt;
//assign trig[183]=phy_init_done;
//assign trig[184]=emc_fifo_almost_full;

endmodule

