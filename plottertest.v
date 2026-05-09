`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/06/2026 04:09:32 PM
// Design Name: 
// Module Name: 1627test
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

`define XIOWoff XIOW       = 1'b0
`define XIOWon  XIOW       = 1'b1
`define XIOSoff XIOS       = 1'b0
`define XIOSon XIOS        = 1'b1
`define XIOS15off XIOS15   = 1'b0
`define XIOS15on XIOS15    = 1'b1
`define DCRESETon DCreset  = 1'b0
`define DCRESEToff DCreset = 1'b1
`define AREA5on Area5      = 1'b1
`define AREA5off Area5     = 1'b0
`define T6on T6            = 1'b1
`define T6off T6           = 1'b1
`define B0on B0            = 1'b0
`define B0off B0           = 1'b1
`define B1on B1            = 1'b0
`define B1off B1           = 1'b1
`define B2on B2            = 1'b0
`define B2off B2           = 1'b1
`define B3on B3            = 1'b0
`define B3off B3           = 1'b1
`define B4on B4            = 1'b0
`define B4off B4           = 1'b1
`define B5on B5            = 1'b0
`define B5off B5           = 1'b1



module plottertest(
    );

     reg clk;        // 12 MHz clock from board
     reg XIOW;    // high if 12V supply and Usage is on
     reg XIOS;   // high during read cycle
     reg XIOS15;  // high during write cycle
     reg DCreset;      // high at power on for 1.2sS
     reg Area5;         // put MRAM in write mode when low 
     reg T6;         // enable chip for read or write when low
     reg attached;         // output contents on MRAM data lines when low
     reg B0;        // enable output if logic high on bit 0
     reg B1;        // enable output if logic high on bit 1
     reg B2;        // enable output if logic high on bit 2
     reg B3;        // enable output if logic high on bit 3
     reg B4;        // enable output if logic high on bit 4
     reg B5;        // enable output if logic high on bit 5
     wire up;        // enable output if logic high on bit 7
     wire down;        // enable output if logic high on bit 8
     wire left;        // enable output if logic high on bit 9
     wire right;       // enable output if logic high on bit 10
     wire penup;       // enable output if logic high on bit 11
     wire pendown;       // enable output if logic high on bit 12
     wire DSW0;       // enable output if logic high on bit 13
     wire DSW14;       // enable output if logic high on bit 14
     wire DSW15;       // enable output if logic high on bit 15
     wire IntLvl3;        // enable output if logic high on parity bit P1
     reg model1;       // on for model 1

plottercard DUT (
    .clk(clk),        // 12 MHz clock from board
    .XIOW(XIOW),    // high if 12V supply and Usage is on
    .XIOS(XIOS),   // high during read cycle
    .XIOS15(XIOS15),  // high during write cycle
    .DCreset(DCreset),      // high at power on for 1.2sS
    .Area5(Area5),         // put MRAM in write mode when low 
    .T6(T6),         // enable chip for read or write when low
    .model1(model1), // on if model 1, off if model 2
    .down(down),         // output contents on MRAM data lines when low
    .up(up),      // pass SBR to MRAM data lines when low
    .B0(B0),        // enable output if logic high on bit 0
    .B1(B1),        // enable output if logic high on bit 1
    .B2(B2),        // enable output if logic high on bit 2
    .B3(B3),        // enable output if logic high on bit 3
    .B4(B4),        // enable output if logic high on bit 4
    .B5(B5),        // enable output if logic high on bit 5
    .left(left),        // enable output if logic high on bit 6
    .right(right),        // enable output if logic high on bit 7
    .penup(penup),        // enable output if logic high on bit 8
    .pendown(pendown),        // enable output if logic high on bit 9
    .DSW0(DSW0),       // enable output if logic high on bit 10
    .DSW14(DSW14),       // enable output if logic high on bit 11
    .DSW15(DSW15),       // enable output if logic high on bit 12
    .IntLvl3(IntLvl3),       // enable output if logic high on bit 13
    .attached(attached)       // enable output if logic high on bit 14
    );

// clock and reset
  initial begin
    clk = 1'b0;
    model1 = 1'b1;
    forever #41.65 clk = ~clk;
  end
 
  initial begin
   `DCRESETon;
    #3000
   `DCRESEToff;
    #1000000
    #1000000
    #1000000
    #1000000
    `DCRESEToff;  
    #3000
    `DCRESEToff;
  end

// drive the 1130 signals
    initial begin
      `XIOWoff;
      `XIOSoff;
      `XIOS15off;
      `AREA5off;
      `T6off;
      attached = 1'b1;
      `B0off;
      `B1off;
      `B2off;
      `B3off;
      `B4off;
      `B5off;
      #24197
      `AREA5on;
      `XIOWon;
      `B2on;
      #330
      `T6on;
      #100000
      `XIOWoff;
      `XIOSoff;
      `XIOS15off;
      `AREA5off;
      `T6off;
      #1000000
      `B0off;
      `B1off;
      `B2off;
      `B3off;
      `B4off;
      `B5off;
      #2000000
      `XIOSon;
      `AREA5on;
      #3600
      `XIOSoff;
      `AREA5off;
      #2000000
      `XIOS15on;
      `AREA5on;
      #600
      `XIOSon;
      #3600
      `XIOS15off;
      `XIOSoff;
      `AREA5off;
      #500000
      `XIOSon;
      `AREA5on;
      #3600
      `XIOSoff;
      `AREA5off;
//      forever begin
//         #1832
//         #1832
//       end
     end
     
endmodule
