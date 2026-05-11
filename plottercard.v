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
//              jumper between pins 25 and 26 to specify 1627 model 2 or Calcomp 563
//              outputs on serial at 9600 baud, 8 bit no parity 1 stop bit
//              sends ascii chars 0 or 1 for each of the six command bits
//              e.g. 010010 cr nl draws both pen left and drum up
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
    input uart_rx,
    input attached,
    input model1,
    output reg down,
    output reg up,
    output reg left,
    output reg right,
    output reg penup,
    output reg pendown,
    output reg DSW0,
    output reg DSW14,
    output reg DSW15,
    output wire IntLvl3,
    output wire uart_tx
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

// states for the UART data pump
`define U0  6'd0  // 0 idle waiting for command from main 12.5 state machine
`define U1  6'd1  // send first character
`define U2  6'd2  // wait for first to end
`define U3  6'd3  // send second character
`define U4  6'd4  // wait for second to end
`define U5  6'd5  // send third character
`define U6  6'd6  // wait for first to end
`define U7  6'd7  // send fourth character
`define U8  6'd8  // wait for fourth to end
`define U9  6'd9  // send fifth character
`define U10 6'd10  // wait for fifth to end
`define U11 6'd11  // send sixth character
`define U12 6'd12  // wait for sixth to end
`define U13 6'd13  // send CR character
`define U14 6'd14  // wait for CR to end
`define U15 6'd15  // send NL character
`define U16 6'd16  // wait for NL to end
reg [5:0] pump_state; // state machine for data pump

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
reg [3:0]  metafastreset = 4'b0000; // de-metastable flops for reset signal
reg        downpen;
reg        uppen;
reg        busy;
reg [19:0]  timer;
reg        IntLvl3R;

reg        uart_send;
wire       uart_ready;
wire        uart_clk;
reg [7:0]   uart_data;
wire [7:0]  pump_data;
wire       uart_locked;      
wire       fifo_full;
wire       fifo_empty;
wire       fifo_valid;
reg [7:0]  send_data;
reg        get_data = 1'b0;
reg        push_data = 1'b0;
reg        fifo_reset = 1'b1;
reg [7:0]  reset_count;
reg        emit_one;

//============================ Start of Code =========================================

// emit request for interrupt level 3 based on 
assign IntLvl3  =    IntLvl3R;

// clocked logic at 12.5MHz
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
    up               <= 1'b1;
    down             <= 1'b1;
    left             <= 1'b1;
    right            <= 1'b1;
    penup            <= 1'b1;
    pendown          <= 1'b1;
    downpen          <= 1'b0;
    uppen            <= 1'b0;
    timer            <= 20'd0;
    busy             <= 1'b0;
    IntLvl3R         <= 1'b0;
    DSW0             <= 1'b0;
    DSW14            <= 1'b0;
    DSW15            <= 1'b0;
    plotter_state    <= `P0;
    push_data        <= 1'b0;
    send_data        <= 8'b0;
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
                         ? (metagateattached[3] == 1'b0)
                           // if device not powered on and connected, immediate completion of request
                           ?  `P9
                           :  `P1 
                         : `P0;
      send_data        <= 8'b0;
      push_data        <= 1'b0;
     end

    // latch up the movement requests
    `P1: begin 
      left             <= metagateB4[3];
      right            <= metagateB3[3];
      up               <= metagateB2[3];
      down             <= metagateB1[3];
      penup            <= metagateB5[3];
      pendown          <= metagateB0[3];
      uppen            <= ~metagateB5[3];
      downpen          <= ~metagateB0[3];
      plotter_state    <= `P2;
      timer            <= model1 == 1'b1
                         ? 20'd22800  // 1.9 ms at 12.5 MHz clock rate
                         : 20'd34800;  // 2.9 ms at 12.5 MHz clock rate
      busy             <= 1'b1;
      send_data        <= {~metagateB0[3] , ~metagateB1[3] , ~metagateB2[3] , ~metagateB3[3] , ~metagateB4[3] , ~metagateB5[3] , 1'b0 , 1'b0};
      push_data        <= 1'b1;
     end

    // hold all signals 
    // model 1 for 1.9 milliseconds
    // model 2 for 2.9 milliseconds
    `P2: begin     
      timer            <= timer - 1;
      plotter_state    <= (timer == 0)
                         ?  `P3
                         :  `P2;
      push_data        <= 1'b0;
     end

    // drop up, down, left or right signals
    `P3: begin     
      up               <= 1'b1;
      down             <= 1'b1;
      left             <= 1'b1;
      right            <= 1'b1;
      plotter_state    <= `P4;
      timer            <= model1 == 1'b1
                         ? 20'd22800  // 1.9 ms at 12.5 MHz clock rate
                         : 20'd34800;  // 2.9 ms at 12.5 MHz clock rate
      push_data        <= 1'b0;
     end

    // wait before dropping busy
    // model 1 for 1.9 milliseconds
    // model 2 for 2.9 milliseconds
    `P4: begin     
      timer            <= timer - 1;
      plotter_state    <= (timer == 0)
                         ?  `P5
                         :  `P4;
      push_data        <= 1'b0;
     end

    // exit if no pen movements else wait total of 50 milliseconds
    `P5: begin     
      plotter_state    <= (downpen == 1'b0 && uppen == 1'b0)
                         ?  `P9
                         :  `P6;
      timer            <= 20'd554400;
      push_data        <= 1'b0;
     end
     
    // wait for remainder of 50 ms before dropping pen mvoements
    `P6: begin     
      timer            <= timer - 1;
      plotter_state    <= (timer == 0)
                         ?  `P7
                         :  `P6;
      push_data        <= 1'b0;
     end

    // drop pen raise or down command then wait another 50ms
    `P7: begin     
      downpen          <= 1'b0;
      uppen            <= 1'b0;
      penup            <= 1'b1;
      pendown          <= 1'b1;
      plotter_state    <= `P8;
      timer            <= 20'd600000;  // 50 ms at 12.5 MHz clock rate
      push_data        <= 1'b0;
     end

    // wait for another 50 ms before dropping busy
    `P8: begin     
      timer            <= timer - 1;
      plotter_state    <= (timer == 0)
                          ?  `P9
                          :  `P8;
      push_data        <= 1'b0;
     end

    // drop busy state and wait for another XIO
    `P9: begin     
      up                <= 1'b1;
      down              <= 1'b1;
      left              <= 1'b1;
      right             <= 1'b1;
      penup             <= 1'b1;
      pendown           <= 1'b1;
      downpen           <= 1'b0;
      uppen             <= 1'b0;
      busy              <= 1'b0;
      timer             <= 20'd0;  
      plotter_state     <= `P0;
      push_data         <= 1'b0;
     end

    default: begin
      plotter_state    <= `P0;
      push_data        <= 1'b0;
    end

    endcase
    
    // emit DSW 15 signal during XIO Sense Device on Area 5 (attached and ready to work)
    DSW15 <= (metagateXIOS[3] == 1'b1 && metagateArea5[3] == 1'b1 && metagateattached[3] == 1'b0)
             ?  1'b1       // not ready turn on bit 15 of DSW
             :  1'b0;      // attached, bit 15 is off
             
    // emit DSW 14 signal during XIO Sense Device on Area 5 (busy)
    DSW14 <= (metagateXIOS[3] == 1'b1 && metagateArea5[3] == 1'b1 && busy == 1'b1)
             ?  1'b1       // turn on bit 14 of DSW
             :  1'b0;      // not busy
             
    // emit DSW 0 signal during XIO Sense Device on Area 5 (completed - plotter response set
    DSW0 <= (metagateXIOS[3] == 1'b1 && metagateArea5[3] == 1'b1 && IntLvl3R == 1'b1)
             ?  1'b1       // turn on bit 0 of DSW
             :  1'b0;      // not requesting IntLvl3
             
    // turn on Interrupt request when state machine ends
    // turn off when XIO Sense Device for Area 5 with Reset bit 15 set
    // otherwise retain previous state
    IntLvl3R <= (plotter_state == `P9)
               ?  1'b1
               :  (metagateXIOS[3] == 1'b1 && metagateArea5[3] == 1'b1 && metagateXIOS15[3] == 1'b1)
                  ?  1'b0
                  :  IntLvl3R;
   end
end // End of 12.5 MHz Block   

// clocked logic at 100MHz
always @ (posedge uart_clk)
begin

  // reset before startup
  if (uart_locked == 1'b0) begin
    uart_send <= 1'b0;
    uart_data <= 8'b0;
    pump_state <= `U0;
    get_data <= 1'b0;
    fifo_reset <= 1'b1;
    reset_count <= 8'd124;
    emit_one <= 1'b1;
  end 
  else begin
  
    fifo_reset <= (reset_count > 8'd64 && reset_count < 8'd116)
               ? 1'b1
               : 1'b0;

    reset_count <= reset_count == 8'd0
                ? 0
                : reset_count - 1;
                
    case(pump_state)
    
    // waiting for data from the FIFO (from XIO Write in 12.5MHz machine)
    `U0: begin     
      uart_send <= 1'b0;
      uart_data <= 8'b0;
      get_data <= reset_count == 8'd0
                  ? 1'b1
                  : 1'b0;
      emit_one <= 1'b1;
      pump_state <= (fifo_valid == 1'b1)
                 ? `U1
                 : `U0;
    end
    
    // send ASCII 1 or 0 based on first bit of data from 1130
    `U1: begin
      uart_send <= emit_one;
      uart_data <= (pump_data[7] == 1'b1)
                ?  8'b00110001
                :  8'b00110000;
      get_data <= 1'b0;
      emit_one <= 1'b0;
      pump_state <= uart_ready == 1'b0
                 ? `U2
                 : `U1;
    end
    
    // wait until the UART has transmitted this character
    `U2: begin
      uart_send <= 1'b0;
      get_data <= 1'b0;
      emit_one <= 1'b1;
      pump_state <= (uart_ready == 1'b1)
                 ? `U3
                 : `U2;
    end
     
    // send ASCII 1 or 0 based on second bit of data from 1130
    `U3: begin
      uart_send <= emit_one;
      get_data <= 1'b0;
      uart_data <= (pump_data[6] == 1'b1)
                ?  8'b00110001
                :  8'b00110000;
      emit_one <= 1'b0;
      pump_state <= uart_ready == 1'b0
                 ? `U4
                 : `U3;
    end
    
    // wait until the UART has transmitted this character
    `U4: begin
      uart_send <= 1'b0;
      get_data <= 1'b0;
      emit_one <= 1'b1;
      pump_state <= (uart_ready == 1'b1)
                 ? `U5
                 : `U4;
    end
     
    // send ASCII 1 or 0 based on third bit of data from 1130
    `U5: begin
      uart_send <= emit_one;
      get_data <= 1'b0;
      uart_data <= (pump_data[5] == 1'b1)
                ?  8'b00110001
                :  8'b00110000;
      emit_one <= 1'b0;
      pump_state <= uart_ready == 1'b0
                 ? `U6
                 : `U5;
    end
    
    // wait until the UART has transmitted this character
    `U6: begin
      uart_send <= 1'b0;
      get_data <= 1'b0;
      emit_one <= 1'b1;
      pump_state <= (uart_ready == 1'b1)
                 ? `U7
                 : `U6;
    end
     
    // send ASCII 1 or 0 based on fourth bit of data from 1130
    `U7: begin
      uart_send <= emit_one;
      uart_data <= (pump_data[4] == 1'b1)
                ?  8'b00110001
                :  8'b00110000;
      get_data <= 1'b0;
      emit_one <= 1'b0;
      pump_state <= uart_ready == 1'b0
                 ? `U8
                 : `U7;
    end
    
    // wait until the UART has transmitted this character
    `U8: begin
      uart_send <= 1'b0;
      get_data <= 1'b0;
      emit_one <= 1'b1;
      pump_state <= (uart_ready == 1'b1)
                 ? `U9
                 : `U8;
    end
     
    // send ASCII 1 or 0 based on fifth bit of data from 1130
    `U9: begin
      uart_send <= emit_one;
      uart_data <= (pump_data[3] == 1'b1)
                ?  8'b00110001
                :  8'b00110000;
      get_data <= 1'b0;
      emit_one <= 1'b0;
      pump_state <=uart_ready == 1'b0
                 ?  `U10
                 :  `U9;
    end
    
    // wait until the UART has transmitted this character
    `U10: begin
      uart_send <= 1'b0;
      get_data <= 1'b0;
      emit_one <= 1'b1;
      pump_state <= (uart_ready == 1'b1)
                 ? `U11
                 : `U10;
    end
     
    // send ASCII 1 or 0 based on sixth bit of data from 1130
    `U11: begin
      uart_send <= emit_one;
      get_data <= 1'b0;
      uart_data <= (pump_data[2] == 1'b1)
                ?  8'b00110001
                :  8'b00110000;
      emit_one <= 1'b0;
      pump_state <= uart_ready == 1'b0
                 ? `U12
                 : `U11;
    end
    
    // wait until the UART has transmitted this character
    `U12: begin
      uart_send <= 1'b0;
      get_data <= 1'b0;
      emit_one <= 1'b1;
      pump_state <= (uart_ready == 1'b1)
                 ? `U13
                 : `U12;
    end
     
    // send ASCII CR
    `U13: begin
      uart_send <= emit_one;
      uart_data <= 8'b00001101;
      get_data <= 1'b0;
      emit_one <= 1'b0;
      pump_state <= uart_ready == 1'b0
                 ? `U14
                 : `U13;
    end
    
    // wait until the UART has transmitted this character
    `U14: begin
      uart_send <= 1'b0;
      get_data <= 1'b0;
      emit_one <= 1'b1;
      pump_state <= (uart_ready == 1'b1)
                 ? `U15
                 : `U14;
    end
     
    // send ASCII NL character
    `U15: begin
      uart_send <= emit_one;
      uart_data <= 8'b00001010;
      get_data <= 1'b0;
      emit_one <= 1'b0;
      pump_state <= uart_ready == 1'b0
                 ? `U16
                 : `U15;
    end
    
    // wait until the UART has transmitted this character
    `U16: begin
      uart_send <= 1'b0;
      get_data <= 1'b0;
      emit_one <= 1'b1;
      pump_state <= (uart_ready == 1'b1)
                 ? `U0
                 : `U16;
    end
     
    default: begin
      get_data <= 1'b0;
      uart_send <= 1'b0;    
      emit_one <= 1'b1;
      pump_state <= `U0;
    end
     
    endcase
  end
end // end of 100 MHz block

UART_TX_CTRL uart (
.SEND (uart_send),
.DATA (uart_data),
.CLK (uart_clk),
.READY (uart_ready),
.UART_TX (uart_tx)
);

// generate 100MHz clock for serial port implementation
clk_wiz_0 myclk (
  // Clock out ports  
  .clk_out1(uart_clk),
  // Status and control signals               
  .resetn(DCreset), 
  .locked(uart_locked),
 // Clock in ports
  .clk_in1(clk)
  );

// FIFO to connect clock domains for serial
fifo_generator_0 myfifi (
.rst (fifo_reset),
.wr_clk (clk),
.rd_clk (uart_clk),
.din (send_data),
.dout (pump_data),
.rd_en(get_data),
.wr_en(push_data),
.full (fifo_full),
.empty (fifo_empty),
.valid (fifo_valid)
);

endmodule
