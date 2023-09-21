module camera_top (
    cam_clk,
    rst,
    camera_xin,
    camera_yin,
    camera_zin,
    camera_clkxin,
    camera_clkyin,
    camera_clkzin,

    cam_wdata,
    cam_wvalid,
   // bus_clk,
    interrupt_flag
);                  

input cam_clk;
input rst;
input [27:0]  camera_xin;
input [27:0]  camera_yin;
input [27:0]  camera_zin;
input         camera_clkxin;
input         camera_clkyin;
input         camera_clkzin;
output [63:0] cam_wdata;
output        cam_wvalid;

    
//input                  bus_clk;
output  reg          interrupt_flag;


 (* KEEP="TRUE" *) /* synthesis syn_keep = 1 */     wire [15:0] cam_d0;
 (* KEEP="TRUE" *)/* synthesis syn_keep = 1 */      wire [15:0] cam_d1;
 (* KEEP="TRUE" *)/* synthesis syn_keep = 1 */      wire [15:0] cam_d2;
 (* KEEP="TRUE" *)/* synthesis syn_keep = 1 */      wire [15:0] cam_d3;
 (* KEEP="TRUE" *) /* synthesis syn_keep = 1 */     wire [15:0] cam_d4; 
 
// wire rd_x;
// wire rd_y;
// wire rd_z;
 wire rd_en1;
 wire rd_en;
 wire  [27:0]  cam_xout;
 wire empty_x; 
 wire  [27:0]  cam_yout;
 wire empty_y;
 wire  [27:0]  cam_zout;
 wire empty_z;
 
 wire  [27:0]  cam_xout1;
  wire empty_x1; 
  wire  [27:0]  cam_yout1;
  wire empty_y1;
  wire  [27:0]  cam_zout1;
  wire empty_z1;
  (* KEEP="TRUE" *)wire rd_x1;
  (* KEEP="TRUE" *)wire rd_y1;
 (* KEEP="TRUE" *) wire rd_z1;
 
 reg [1:0]  burst_cnt;
 reg [63:0] wdata;
  reg        w_valid;
 reg        last_flag;
 
 reg  [9:0]   piex_cnt;
 reg  [10:0]  v_cnt;
 (*keep = "true" *) reg   line_end;
 
  IBUF #(
      .IBUF_LOW_PWR("TRUE"),  // Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards 
      .IOSTANDARD("DEFAULT")  // Specify the input I/O standard
   ) IBUF_instx (
      .O(camera_clkxin_bufo),     // Buffer output
      .I(camera_clkxin)      // Buffer input (connect directly to top-level port)
   );
    BUFG BUFG_instx (
        .O(clkxin), // 1-bit output: Clock output
        .I(camera_clkxin_bufo)  // 1-bit input: Clock input
     );
    IBUF #(
        .IBUF_LOW_PWR("TRUE"),  // Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards 
        .IOSTANDARD("DEFAULT")  // Specify the input I/O standard
     ) IBUF_insty (
        .O(camera_clkyin_bufo),     // Buffer output
        .I(camera_clkyin)      // Buffer input (connect directly to top-level port)
     );
      BUFG BUFG_insty (
            .O(clkyin), // 1-bit output: Clock output
            .I(camera_clkyin_bufo)  // 1-bit input: Clock input
         );
      IBUF #(
          .IBUF_LOW_PWR("TRUE"),  // Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards 
          .IOSTANDARD("DEFAULT")  // Specify the input I/O standard
       ) IBUF_instz (
          .O(camera_clkzin_bufo),     // Buffer output
          .I(camera_clkzin)      // Buffer input (connect directly to top-level port)
       );
        BUFG BUFG_instz (
              .O(clkzin), // 1-bit output: Clock output
              .I(camera_clkzin_bufo)  // 1-bit input: Clock input
           );

 //depth=16 80bitx16=64bitx20 burst
 fifo  fifo_x1(
  .rst     (rst),
  .wr_clk  (clkxin),
  .rd_clk  (cam_clk),
  .din     (camera_xin),
  .wr_en   (1'b1),
  .rd_en   (rd_x1),
  .dout    (cam_xout1),
  .full    (),
  .empty   (empty_x1)
);

 fifo  fifo_y1(
  .rst     (rst),
  .wr_clk  (clkyin),
  .rd_clk  (cam_clk),
  .din     (camera_yin),
  .wr_en   (1'b1),//cam_xin_r[25]),
  .rd_en   (rd_y1),
  .dout    (cam_yout1),
  .full    (),
  .empty   (empty_y1)
);

 fifo  fifo_z1(
  .rst     (rst),
  .wr_clk  (clkzin),
  .rd_clk  (cam_clk),
  .din     (camera_zin),
  .wr_en   (1'b1),//cam_xin_r[25]),
  .rd_en   (rd_z1),
  .dout    (cam_zout1),
  .full    (),
  .empty   (empty_z1)
);
assign  rd_x1=~empty_x1;
assign  rd_y1=~empty_y1;
assign  rd_z1=~empty_z1;
 fifo  fifo_x(
 .rst     (rst),
 .wr_clk  (cam_clk),
 .rd_clk  (cam_clk),
 .din     (cam_xout1),
 .wr_en   (cam_xout1[24]&rd_x1),
 .rd_en   (rd_en),
 .dout    (cam_xout),
 .full    (),
 .empty   (empty_x)
);

fifo  fifo_y(
 .rst     (rst),
 .wr_clk  (cam_clk),
 .rd_clk  (cam_clk),
 .din     (cam_yout1),
 .wr_en   (cam_yout1[27]&rd_y1),//cam_xin_r[25]),
 .rd_en   (rd_en),
 .dout    (cam_yout),
 .full    (),
 .empty   (empty_y)
);

fifo  fifo_z(
 .rst     (rst),
 .wr_clk  (cam_clk),
 .rd_clk  (cam_clk),
 .din     (cam_zout1),
 .wr_en   (cam_zout1[27]&rd_z1),//cam_xin_r[25]),
 .rd_en   (rd_en),
 .dout    (cam_zout),
 .full    (),
 .empty   (empty_z)
);
assign rd_en1=(~empty_x) & (~empty_y) & (~empty_z);
assign rd_en=rd_en1  & (~last_flag);
(*keep = "true" *)wire fval;
(*keep = "true" *)wire lval_x;
(*keep = "true" *)wire lval_y;
(*keep = "true" *)wire lval_z;
(*keep = "true" *)wire lval;

assign fval  =cam_xout[25];
assign lval_x=cam_xout[24];
assign lval_y=cam_yout[27];
assign lval_z=cam_zout[27];

assign lval=lval_x && lval_y && lval_z;

//assign cam_d0[15:0]=  cam_xout[15:0];
//assign cam_d1[15:0]=  {cam_yout[5:0],cam_xout[27:26],cam_xout[23:16]};
//assign cam_d2[15:0]=  cam_yout[21:6];
//assign cam_d3[15:0]=  {cam_zout[10:0],cam_yout[26:22]};
//assign cam_d4[15:0]=  cam_zout[26:11];
assign cam_d0[15:0]=  cam_xout[15:0];
assign cam_d1[15:0]=  {cam_yout[5:0],cam_xout[27:26],cam_xout[23:16]};
assign cam_d2[15:0]=  cam_yout[21:6];
assign cam_d3[15:0]=  {cam_zout[10:0],cam_yout[26:22]};
assign cam_d4[15:0]=  cam_zout[26:11];

  reg [15:0] cam_d0_r;
  reg [15:0] cam_d1_r;
  reg [15:0] cam_d2_r;
  reg [15:0] cam_d3_r;
  reg [15:0] cam_d4_r; 
//reg  fval_r1;
//reg start;
//reg  lval_r1;
//reg  fval_r2;
//reg  lval_r2;
always @(posedge cam_clk)begin
   if(rst)begin
//      fval_r1<=1'b0;
//      start<=1'b0;
      cam_d0_r<=16'h0;
      cam_d1_r<=16'h0;
      cam_d2_r<=16'h0;
      cam_d3_r<=16'h0;
      cam_d4_r<=16'h0;
//      fval_r1<=1'b0;
//      fval_r2<=1'b0;
//      lval_r1<=1'b0;
//      lval_r2<=1'b0;
   end else begin
//      fval_r1<=fval;
//      if(fval_r1 &(!fval))begin
//        start<=1'b1;
//      end
      if( fval & lval & rd_en)begin
        cam_d0_r<=cam_d0;
        cam_d1_r<=cam_d1;
        cam_d2_r<=cam_d2;
        cam_d3_r<=cam_d3;
        cam_d4_r<=cam_d4;
      end
//      fval_r1<=fval;
//      fval_r2<=fval_r1;
//      lval_r1<=lval;
//      lval_r2<=lval_r1;
//      if( fval & lval)begin
//         data_buf[159:80]<=data_buf[79:0];
//         data_buf[79:0]<={cam_d0,cam_d1,cam_d2,cam_d3,cam_d4};
//      end
   end
end


always @(posedge cam_clk)begin
   if(rst)begin
      burst_cnt<=2'b00;
      last_flag<=1'b0;
      wdata<=64'h0;
      w_valid<=1'b0;
   end else begin
     if(last_flag)begin
         burst_cnt<=0;
         w_valid<=1'b1;
         wdata<={cam_d1_r,cam_d2_r,cam_d3_r,cam_d4_r}; 
         last_flag<=1'b0;
     end else if( fval & lval & rd_en)begin
        if(burst_cnt==0)begin
           burst_cnt<=1;
           w_valid<=1'b1;
           wdata<={cam_d0,cam_d1,cam_d2,cam_d3};
        end else if(burst_cnt==1)begin
           w_valid<=1'b1;
           wdata<={cam_d4_r,cam_d0,cam_d1,cam_d2};
           if(line_end)begin
             burst_cnt<=0; 
           end else begin
             burst_cnt<=2;
           end         
        end else if(burst_cnt==2)begin
            burst_cnt<=3;
            w_valid<=1'b1;
            wdata<={cam_d3_r,cam_d4_r,cam_d0,cam_d1};
        end else if(burst_cnt==3)begin
            burst_cnt<=0;
            w_valid<=1'b1;
            wdata<={cam_d2_r,cam_d3_r,cam_d4_r,cam_d0};
            last_flag<=1'b1;
//        end else if(burst_cnt==4)begin
//            burst_cnt<=0;
//            w_valid<=1'b1;
//            wdata<={cam_d1,cam_d2,cam_d3,cam_d4}; 
//            last_flag<=1'b0;
        end
     end else begin
         w_valid<=1'b0;
         last_flag<=1'b0;
     end
  end
  end
  
 
  always @(posedge cam_clk)begin
     if(rst)begin
       piex_cnt<=10'h0;
       v_cnt<=11'h0;
       interrupt_flag<=1'b0;
       line_end<=1'b0;
     end else begin
       if(fval & lval & rd_en)begin
          if(piex_cnt==10'h199)begin //410
             piex_cnt<=10'h0;
             line_end<=1'b0;
             if(v_cnt==11'h7ff)begin
               v_cnt<=11'h0;
               interrupt_flag<=1'b1;
             end else begin
               v_cnt<=v_cnt+1;
             end
          end else if(piex_cnt==10'h198)begin
             line_end<=1'b1;
             piex_cnt<=piex_cnt+1;
          end else begin
             piex_cnt<=piex_cnt+1;
          end
        end else begin
           interrupt_flag<=1'b0;
        end
     end
  end
    reg [63:0] wdata;
   reg        w_valid;
   assign cam_wvalid=  w_valid;
   assign cam_wdata=wdata;    
endmodule