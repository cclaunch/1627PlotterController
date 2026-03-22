`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Carl V Claunch
// 
// Create Date: 03/13/2026 01:05:10 PM
// Design Name: plottercard 
// Module Name: plottercard
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Driver for 1627 plotter added to IBM 1130, a double SMS card
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module plottercard(
    input clk,
    input XIOW,
    input XIOS,
    input XIOS15,
    input Area5,
    input T6,
    input DCreset,
    input B0,
    input B1,
    input B2,
    input B3,
    input B4,
    input B5,
    output reg down,
    output reg up,
    output reg left,
    output reg right,
    output reg penup,
    output reg pendown,
    input attached,
    output reg DSW0,
    output reg DSW14,
    output reg DSW15,
    output reg IntLvl3
    );
    
//============================ Internal Connections ==================================

// state definitions and values for the read state
`define P0 4'd0 // 0 - off
`define P1 4'd1 // 1 - latch movements
`define P2 4'd2 // 2 - wait 1.9 ms holding movement signals
`define P3 4'd3 // 3 - drop left, right, up and down signals
`define P4 4'd4 // 4 - wait another 1.9 ms
`define P5 4'd5 // 5 - go to end unless pen movement commands
`define P6 4'd6 // 6 - wait remainder of 50 ms for pen movement
`define P7 4'd7 // 7 - drop pen movement signals
`define P8 4'd8 // 8 - wait another 50 ms
`define P9 4'd9 // 9 - drop busy state and end machine
reg [3:0] plotter_state; // read state machine state variable

reg [3:0]  metagateXIOW; // de-metastable flops for XIO Write signal
reg [3:0]  metagateXIOS; // de-metastable flops for XIO Sense DSW signal
reg [3:0]  metagateXIOS15; // de-metastable flops for XIO Sense DSW Reset 15 signal
reg [3:0]  metagateArea5; // de-metastable flops for Area code 5 signal
reg [3:0]  metagateT6; // de-metastable flops for T6 signal
reg [3:0]  metagatereset = 4'b0000; // de-metastable flops for reset signal
reg [3:0]  metagateB0; // de-metastable flops for B Bit 0 signal
reg [3:0]  metagateB1; // de-metastable flops for B Bit 1 signal
reg [3:0]  metagateB2; // de-metastable flops for B Bit 2 signal
reg [3:0]  metagateB3; // de-metastable flops for B Bit 3 signal
reg [3:0]  metagateB4; // de-metastable flops for B Bit 4 signal
reg [3:0]  metagateB5; // de-metastable flops for B Bit 5 signal
reg [3:0]  metagateattached; // de-metastable flops for plotter attached signal
reg        goup;
reg        godown;
reg        goleft;
reg        goright;
reg        downpen;
reg        raisepen;
reg        busy;
reg [19:0]  timer;


//============================ Start of Code =========================================

// clocked logic
always @ (posedge clk)
begin

  // handle clock domain crossing
  metagatereset[3:0] <= {metagatereset[2:0],DCreset};

  // reset before startup
  if(metagatereset[3]==1'b0) begin
    metagateXIOW     <= 4'b0000;
    metagateXIOS     <= 4'b0000;
    metagateXIOS15   <= 4'b0000;
    metagateArea5    <= 4'b0000;
    metagateT6       <= 4'b0000;
    metagateB0       <= 4'b0000;
    metagateB1       <= 4'b0000;
    metagateB2       <= 4'b0000;
    metagateB3       <= 4'b0000;
    metagateB4       <= 4'b0000;
    metagateB5       <= 4'b0000;
    metagateattached <= 4'b0000;
    goleft           <= 1'b0;
    goright          <= 1'b0;
    goup             <= 1'b0;
    godown           <= 1'b0;
    downpen          <= 1'b0;
    raisepen         <= 1'b0;
    up               <= 1'b1;
    down             <= 1'b1;
    left             <= 1'b1;
    right            <= 1'b1;
    penup            <= 1'b1;
    pendown          <= 1'b1;
    timer            <= 20'd0;
    busy             <= 1'b0;
    IntLvl3          <= 1'b1;
    DSW0             <= 1'b1;
    DSW14            <= 1'b1;
    DSW15            <= 1'b1;
    plotter_state    <= `P0;
  end
  else begin
  
    // handle clock domain crossing
    metagateXIOW[3:0]     <= {metagateXIOW[2:0],XIOW};
    metagateXIOS[3:0]     <= {metagateXIOS[2:0],XIOS};
    metagateXIOS15[3:0]   <= {metagateXIOS15[2:0],XIOS15};
    metagateArea5[3:0]    <= {metagateArea5[2:0],Area5};
    metagateT6[3:0]       <= {metagateT6[2:0],T6};
    metagateB0[3:0]       <= {metagateB0[2:0],B0};
    metagateB1[3:0]       <= {metagateB1[2:0],B1};
    metagateB2[3:0]       <= {metagateB2[2:0],B2};
    metagateB3[3:0]       <= {metagateB3[2:0],B3};
    metagateB4[3:0]       <= {metagateB4[2:0],B4};
    metagateB5[3:0]       <= {metagateB5[2:0],B5};
    metagateattached[3:0] <= {metagateattached[2:0],attached};

    case(plotter_state)
    
    // plotter is inactive, waiting for the XIO Write to the plotter (Area 5)
    `P0: begin     
      // when to move out of idle state (read gate on, sector pulse over and we saw a read or clock bit)
      plotter_state <= (metagateXIOW[3] == 1'b1) && (metagateArea5[3] == 1'b1) && (metagateT6[3] == 1'b1) 
                        ? `P1 
                        : `P0;
     end

    // latch up the movement requests
    `P1: begin 
      goleft          <= ~metagateB4[3];
      goright         <= ~metagateB3[3];
      goup            <= ~metagateB2[3];
      godown          <= ~metagateB1[3];
      downpen         <= ~metagateB0[3];
      raisepen        <= ~metagateB5[3];
      left            <= metagateB4[3];
      right           <= metagateB3[3];
      up              <= metagateB2[3];
      down            <= metagateB1[3];
      penup           <= metagateB5[3];
      pendown         <= metagateB0[3];
      // if device not powered on and connected, immediate completion of request
      plotter_state   <= metagateattached[3] == 1'b0
                         ? `P9
                         : `P2;
      timer           <= 20'd22800;  // 1.9 ms at 12.5 MHz clock rate
      busy            <= 1'b1;
     end

    // hold up, down, left or right signals for 1.9 milliseconds
    `P2: begin     
      timer           <= timer - 1;
      plotter_state   <= (timer == 0)
                         ?  `P3
                         :  `P2;
     end

    // drop up, down, left or right signals
    `P3: begin     
      goleft           <= 1'b0;
      goright          <= 1'b0;
      goup             <= 1'b0;
      godown           <= 1'b0;
      up               <= 1'b1;
      down             <= 1'b1;
      left             <= 1'b1;
      right            <= 1'b1;
      plotter_state    <= `P4;
      timer            <= 20'd22800;  // 1.9 ms at 12.5 MHz clock rate
     end

    // wait another 1.9 ms before dropping busy
    `P4: begin     
      timer            <= timer - 1;
      plotter_state    <= (timer == 0)
                          ?  `P5
                          :  `P4;
     end

    // exit if no pen movements else wait total of 50 milliseconds
    `P5: begin     
      plotter_state    <= (downpen == 1'b0 && raisepen == 1'b0)
                          ?  `P9
                          :  `P6;
      timer            <= 20'd554400;
     end
     
    // wait for remainder of 50 ms before dropping pen mvoements
    `P6: begin     
      timer            <= timer - 1;
      plotter_state    <= (timer == 0)
                          ?  `P7
                          :  `P6;
     end

    // drop pen raise or down command then wait another 50ms
    `P7: begin     
      downpen          <= 1'b0;
      raisepen         <= 1'b0;
      penup            <= 1'b1;
      pendown          <= 1'b1;
      plotter_state    <= `P8;
      timer            <= 20'd600000;  // 50 ms at 12.5 MHz clock rate
     end

    // wait for another 50 ms before dropping busy
    `P8: begin     
      timer            <= timer - 1;
      plotter_state    <= (timer == 0)
                          ?  `P9
                          :  `P8;
     end

    // drop busy state and wait for another XIO
    `P9: begin     
      busy              <= 1'b0;
      timer             <= 20'd0;  
      plotter_state     <= `P0;
     end

    default: begin
      plotter_state    <= `P0;
    end

    endcase
    
    // emit DSW 15 signal during XIO Sense Device on Area 5 (attached and ready to work)
    DSW15 <= (metagateXIOS[3] == 1'b1 && metagateArea5[3] == 1'b1 && metagateattached[3] == 1'b1)
             ?  1'b0       // turn on bit 15 of DSW
             :  1'b1;      // not ready
             
    // emit DSW 14 signal during XIO Sense Device on Area 5 (busy)
    DSW14 <= (metagateXIOS[3] == 1'b1 && metagateArea5[3] == 1'b1 && busy == 1'b1)
             ?  1'b0       // turn on bit 14 of DSW
             :  1'b1;      // not busy
             
    // emit DSW 0 signal during XIO Sense Device on Area 5 (completed - plotter response set
    DSW0 <= (metagateXIOS[3] == 1'b1 && metagateArea5[3] == 1'b1 && metagateattached[3] == 1'b1)
             ?  1'b0       // turn on bit 0 of DSW
             :  1'b1;      // not requesting IntLvl3
             
    // turn on Interrupt request when state machine ends
    // turn off when XIO Sense Device for Area 5 with Reset bit 15 set
    // otherwise retain previous state
    IntLvl3 <= (plotter_state == `P9)
               ?  1'b0
               :  (metagateXIOS[3] == 1'b1 && metagateArea5[3] == 1'b1 && metagateXIOS15 == 1'b1 && IntLvl3 == 1'b0)
                  ?  1'b1
                  :  IntLvl3;
   end
end // End of Block   

endmodule
