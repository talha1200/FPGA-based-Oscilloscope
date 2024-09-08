///////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024 Talha Mahboob
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
///////////////////////////////////////////////////////////////////////////////

module oscilloscope (
  input  logic       clk         , // FPGA MAIN CLOCK 50MHz
  input  logic [7:0] addata      , // ADC MAIN DATA
  input  logic       AC_DC_Select, // AC/DC Selector
  input  logic [7:0] Trigger     , // Trigger Data from Knob
  input  logic [3:0] TimeperDiv  , // Time/Division Data from Knob
  input  logic [3:0] VoltperDiv  , // Volt/Division Data from Knob
  output logic       red0        , // VGA Output
  output logic       red1        , // VGA Output
  output logic       red2        , // VGA Output
  output logic       red3        , // VGA Output
  output logic       red4        , // VGA Output
  output logic       green0      , // VGA Output
  output logic       green1      , // VGA Output
  output logic       green2      , // VGA Output
  output logic       green3      , // VGA Output
  output logic       green4      , // VGA Output
  output logic       green5      , // VGA Output
  output logic       blue0       , // VGA Output
  output logic       blue1       , // VGA Output
  output logic       blue2       , // VGA Output
  output logic       blue3       , // VGA Output
  output logic       blue4       , // VGA Output
  output logic       hsync       , // VGA Output Horizontal Sync Pulse
  output logic       vsync       , // VGA Output Vertical Sync Pulse
  output logic       ADC_clk       // ADC CLOCK 25MHz
);

  //-----------------------
  // local parameter
  //-----------------------
  // 640 x 480p
  localparam hpixel_end = 10'd799; //End of Horizontal pixel for 640x480 Display
  localparam vline_end  = 10'd524; //End of Vertical pixel for 640x480 Display
  localparam hsync_end  = 10'd95 ; // End Point of Horizontal Sync Signal
  localparam hdat_begin = 10'd143; // Start Of Horizontal Active Pixels
  localparam hdat_end   = 10'd783; // End Of Horizontal Active Pixels
  localparam vsync_end  = 10'd1  ; // End Point of Vertical Sync Signal
  localparam vdat_begin = 10'd34 ; // Start Of Vertical Active Pixels
  localparam vdat_end   = 10'd514; // End Of Vertical Active Pixels

  //------------------------
  // internal wires & regs
  //------------------------

  //----- vga pixel + counters
  reg [ 9:0] hcount;
  reg [ 9:0] vcount;
  reg [15:0] data  ;

  // Defining of Variables
  // To be used in Grid Displying
  integer h1 = 175;
  integer v1 = 46 ;
  integer v  = 364;
  integer h  = 163;

  wire hcount_ov;
  wire vcount_ov;
  wire dat_act  ;
  wire hsync    ;
  wire vsync    ;

  //--Internal Signals for Time per Division Knob

  //////////////////////////////////////////////////////////////

  //////////
  reg     [3:0] Time      ;
  integer       Multiplier;
  //////////////////////////////////////////////////////////

  /////////--Internal Signals for Volt per Division Knob
  reg     [3:0] Volt   ;
  integer       out_min;
  integer       out_max;
////////////////////////////////////////////////////////
/////////////////--Internal Siganls for ADC
  reg [7:0] ad_data ;
  reg [7:0] adc_data;
///////////////////////////////////////////

/////////////////--Internal signals for Trigger
  reg     [7:0] trigger_level      ;
  reg           Triggered          ;
  reg     [7:0] Bram         [19:0];
  reg           ENBram             ;
  integer       i                  ;
////////////////////////////////////////////////

/////////--Internal Signal For AC/DC selector
  reg Select;
//Select = 1 ==> DC Signal
//Select = 0 ==> AC Signal
/////////////////////////////////////////////////////////////////

/////////////////--Internal Signals for BRAM Xilinx Core Generator
  integer       ENA       = 1;
  integer       ENB       = 0;
  integer       AddressA  = 0;
  integer       AddressB  = 0;
  wire    [7:0] data_outb    ;
  wire    [7:0] data_outa    ;
///////////////////////////////////////////////////////////////////

////////////////////--Main Data for Signal Output
  reg [8:0] data_main;
//////////////////////////////////////////////////

//--Clock Signals
  wire Clk_25M; // VGA 25MHz Clock for 640x480 Display
  wire Clk_16M; // 16MHZ Clock for Atmega328
//////////////////

///////////////////////--Defining ADC Clock
  assign ADC_clk = Clk_25M;
////////////////////////////////////////////

/////////////////////--Instantiation of Clock Generator(Xilinx Core Generaor)
  Clock ClockGEN (
    // Clock in ports
    .CLK_IN1 (clk    ), // IN
    // Clock out ports
    .CLK_OUT1(Clk_25M), // OUT
    .CLK_OUT2(Clk_16M)
  );    // OUT
/////////////////////////////////////////////////////////////////////////////

///////////--Instantiation of True Port Dual Ram(Xilinx Core Generator)
  BRAM BlockRAM_GEN (
    .clka (Clk_25M  ), // input clka
    .ena  (ENA      ), // input ena
    .wea  (1'b1     ), // input [0 : 0] wea
    .addra(AddressA ), // input [13 : 0] addra
    .dina (ad_data  ), // input [7 : 0] dina
    .douta(data_outa), // output [7 : 0] douta
    .clkb (Clk_25M  ), // input clkb
    .enb  (ENB      ), // input enb
    .web  (1'b0     ), // input [0 : 0] web
    .addrb(AddressB ), // input [13 : 0] addrb
    .dinb (ad_data  ), // input [7 : 0] dinb
    .doutb(data_outb)  // output [7 : 0] doutb
  );
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
//--AD/DC Selector
  always_ff @(negedge AC_DC_Select) begin
    Select <= ~Select; //Toggles the Select
  end
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
//--This is Trigger Module
//--Use to Stabilized The Output WaveForm On the Display Unit
//Reading Trigger data from the Knob
//Storing in Temporary Block Ram some Values From ADC in order to generate trigger pulse
//////////////////////////////////////////////////////////////////////
  always_ff @ (posedge Clk_16M) begin
    trigger_level <= Trigger;
  end

  always_ff @ (posedge Clk_25M)begin
    if(i<20) begin
      Bram[i] <= adc_data;
      i       <= i+1;
      ENBram  <= 0;
    end
    else begin
      i      <= 0;
      ENBram <= 1;
    end
  end
/////////////////////////////////////////////////////////////////////

//Generating Trigger Pulse By comparing Values Stored in Temporary Block Ram
////////////////////////////////////////////////////////////////////
  always_ff @ (posedge Clk_25M) begin
    if(ENBram==1 && trigger_level>=Bram[1] && trigger_level<=Bram[19]) begin
      Triggered <= 1;
    end
    else if (vcount_ov == 1 && ENB==1) begin
      Triggered <= 0;
    end
  end
////////////////////////////////////////////////////////////////////

//Storing of Data in Block Ram (Xilinx Core Generator)
//When Trigger is achived
////////////////////////////////////////////////////////////////////
  always_ff @(posedge Clk_25M) begin
    ad_data <= adc_data;

    if(AddressA<65000 && ENA==1 && (Triggered == 1 || Select==1)) begin
      AddressA = AddressA+1;
    end
    else if(AddressA>=65000) begin
      AddressA = 0;
      ENA      = 0;
      ENB      = 1;
    end
    else if(vcount_ov == 1 && ENB==1) begin
      ENA = 1;
      ENB = 0;
    end
  end

//-------------------
//--This Module is Used to Generated Different Time scales of Output
//-------------------
//Reading Time/Division Knob
  always_ff @ (posedge Clk_16M)
    begin
      Time <= TimeperDiv;
    end

  //Genarating Time Scales

  always_ff @(posedge Clk_25M) begin
    case (Time)
      0       : Multiplier = 1;//2.4us
      1       : Multiplier = 3;//7.2us
      2       : Multiplier = 4;//9.6us
      3       : Multiplier = 8;//19.2us
      4       : Multiplier = 14;//33.6us
      5       : Multiplier = 16;//38.4us
      6       : Multiplier = 20;//48us
      7       : Multiplier = 30;//72us
      8       : Multiplier = 50;//120us
      9       : Multiplier = 60;//144us
      10      : Multiplier = 70;//168us
      default : Multiplier = 80;//192us
    endcase
  end

//-------------------
//--This Module is Used to Generated Different voltage scales of Output
//-------------------
//Reading volt/Division Knob
  always_ff @ (posedge Clk_16M) begin
    Volt <= VoltperDiv;
  end

  always_ff @ (posedge Clk_25M) begin
    if(Volt==0) begin
      out_min = 0;
      out_max = 542;
    end
    else if(Volt==1) begin
      out_min = 34;
      out_max = 508;
    end
    else if(Volt==2) begin
      out_min = 68;
      out_max = 474;
    end
    else if(Volt==3) begin
      out_min = 102;
      out_max = 440;
    end
    else if(Volt==4) begin
      out_min = 136;
      out_max = 406;
    end
    else if(Volt==5) begin
      out_min = 170;
      out_max = 372;
    end
    else begin
      out_min = 204;
      out_max = 338;
    end
  end
//--------------------

//--This is Mapping Module used to Map and Scale the data coming from ADC
//--This will map the Data coming from ADC
//+0  -->128
//+5  -->0
//-5 -->255
  always_ff @(posedge Clk_25M) begin
    adc_data <= (((addata - 0) * (0 - 255)) / (255 - 0)) + 255;
  end

//This will map the Data coming from Block Ram
//Also this will set our Volt per Division value on Display unit
  always_ff @(posedge Clk_25M) begin
    data_main <= (((data_outb - 0) * (out_max - out_min)) / (255 - 0)) + out_min;
  end
//--------------

//--This Module Will Generate Counters
//--i.e. Horizotal Counter 0 to 799
//--Vertical Counter 0 to 524
//--For 640x480 Display Resolution
//Horizotal Counter 0 to 799

  always_ff @(posedge Clk_25M) begin
    if (hcount_ov)
      hcount <= 10'd0;
    else begin
      hcount <= hcount + 10'd1;//Simple Counter
    end
  end

  always_ff @(posedge Clk_25M) begin
    if ((hcount >= 163) && (hcount <= 763)) begin
      AddressB <= (hcount-163)*Multiplier;
    end
    else begin
      AddressB <= 10'd0;
    end
  end

//Over Flow Flage which will get high whenever Hcouter reach 799
  assign hcount_ov = (hcount == hpixel_end);

//Vertical Counter 0 to 524
  always_ff @(posedge Clk_25M) begin
    if (hcount_ov) begin
      if (vcount_ov) begin
        vcount <= 10'd0;
      end
      else begin
        vcount <= vcount + 10'd1;
      end
    end
  end

//Over Flow Flage which will get high whenever Vcouter reach 524
  assign vcount_ov = (vcount == vline_end);
//////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
//--This Module will Display The Grid of Oscilloscope
//--This Module Will Also Display The Signal On The Monitor
  assign dat_act = ((hcount >= hdat_begin) && (hcount < hdat_end))
    && ((vcount >= vdat_begin) && (vcount < vdat_end)); // Defining Visible Region
  assign hsync = (hcount > hsync_end); //Horizontal Sync Signal
  assign vsync = (vcount > vsync_end); //Vertical Sync Signal

//If Visible Region Data will assign to Output otherwise 3'h00 will assign to the Output
  assign {red0,red1,red2,red3,red4,green0,green1,green2,green3,green4,green5,blue0,blue1,blue2,blue3,blue4} = (dat_act) ?  data : 3'h00;

//Assigning Data according to desire positions of Hcount And Vcount
  always_ff @(posedge Clk_25M) begin
    if(vcount==data_main &&  ENB==1) begin//Memory is full plot the Signal on vertical position
      data <= 16'b1111111111111111;//All ones mean output color is white
    end
    else if(hcount ==163) begin
      h1 <= 175;
    end
    else if(vcount == 34) begin
      v1 <= 46;
    end
    else if(hcount == 783 && vcount == v1) begin
      v1 <= v1+12;
    end
    else if(hcount == h1 && (vcount == 273 || vcount == 272 || vcount == 276 || vcount == 277)) begin
      data <= 16'b1111111111111111;
      h1   <= h1+12;
    end
    else if(vcount == v1 && (hcount == 462 || hcount == 461 || hcount == 465 || hcount == 466)) begin
      data <= 16'b1111111111111111;
    end
    else if(hcount == 223) begin
      data <= 16'b1111111111111111;
    end
    else if(hcount == 283) begin
      data <= 16'b1111111111111111;
    end
    else if(hcount == 343) begin
      data <= 16'b1111111111111111;
    end
    else if(hcount == 403) begin
      data <= 16'b1111111111111111;
    end
    else if(hcount == 463 || hcount == 464) begin
      data <= 16'b1111111111111111;
    end
    else if(hcount == 523) begin
      data <= 16'b1111111111111111;
    end
    else if(hcount == 583) begin
      data <= 16'b1111111111111111;
    end
    else if(hcount == 643) begin
      data <= 16'b1111111111111111;
    end
    else if(hcount ==703) begin
      data <= 16'b1111111111111111;
    end
    else if(vcount == 94) begin
      data <= 16'b1111111111111111;
    end
    else if(vcount == 154) begin
      data <= 16'b1111111111111111;
    end
    else if(vcount == 214) begin
      data <= 16'b1111111111111111;
    end
    else if(vcount == 274 || vcount == 275) begin
      data <= 16'b1111111111111111;
    end
    else if(vcount == 334) begin
      data <= 16'b1111111111111111;
    end
    else if(vcount == 394) begin
      data <= 16'b1111111111111111;
    end
    else if(vcount == 454) begin
      data <= 16'b1111111111111111;
    end
    else if( hcount<163) begin
      data <= 16'b1111111111111111;
    end
    else if( hcount>763) begin
      data <= 16'b1111111111111111;
    end
    else begin
      data <= 16'b0000000000000000;//All zeros mean output color is black
    end
  end
/////////////////////////////////////////////////////////////////////////////////////

endmodule : oscilloscope
