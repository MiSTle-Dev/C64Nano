/*
    sysctrl.v
 
    generic system control interface fro/via the MCU
*/

module sysctrl (
  input		   clk,
  input		   reset,

  input		   data_in_strobe,
  input		   data_in_start,
  input [7:0]      data_in,
  output reg [7:0] data_out,

  input  [1:0] buttons,          // S0 and S1 buttons on Tang Nano 20k

  output reg [1:0] leds,         // two leds can be controlled from the MCU
  output reg [23:0] color,       // a 24bit color to e.g. be used to drive the ws2812

  // values that can be configured by the user
  output reg [1:0] system_chipset,
  output reg system_memory,
  output reg system_video,
  output reg [1:0] system_reset,
  output reg [1:0] system_scanlines,
  output reg [1:0] system_volume
);

reg [3:0] state;
reg [7:0] command;
reg [7:0] id;
   
// reverse data byte for rgb   
wire [7:0] data_in_rev = { data_in[0], data_in[1], data_in[2], data_in[3], 
                           data_in[4], data_in[5], data_in[6], data_in[7] };

// process mouse events
always @(posedge clk) begin
   if(reset) begin
      state <= 4'd0;      
      leds <= 2'b00;        // after reset leds are off
      color <= 24'h000000;  // color black -> rgb led off

      // OSD value defaults. These should be sane defaults, but the MCU
      // will very likely override these early
      system_chipset <= 2'b0;
      system_memory <= 1'b0;
      system_video <= 1'b0;   
      system_scanlines <= 2'b00;
      system_volume <= 2'b00;   
   end else begin

      if(data_in_strobe) begin      
        if(data_in_start) begin
            state <= 4'd1;
            command <= data_in;
        end else if(state != 4'd0) begin
            if(state != 4'd15) state <= state + 4'd1;
	    
            // CMD 0: status data
            if(command == 8'd0) begin
                // return some pattern that would not appear randomly
	            // on e.g. an unprogrammed device
                if(state == 4'd1) data_out <= 8'h5c;
                if(state == 4'd2) data_out <= 8'h42;
            end
	   
            // CMD 1: there are two MCU controlled LEDs
            if(command == 8'd1) begin
                if(state == 4'd1) leds <= data_in[1:0];
            end

            // CMD 2: a 24 color value to be mapped e.g. onto the ws2812
            if(command == 8'd2) begin
                if(state == 4'd1) color[15: 8] <= data_in_rev;
                if(state == 4'd2) color[ 7: 0] <= data_in_rev;
                if(state == 4'd3) color[23:16] <= data_in_rev;
            end

            // CMD 3: return button state
            if(command == 8'd3) begin
                data_out <= { 6'b000000, buttons };;
            end

            // CMD 4: config values (e.g. set by user via OSD)
            if(command == 8'd4) begin
                // second byte can be any character which identifies the variable to set 
                if(state == 4'd1) id <= data_in;

                if(state == 4'd2) begin
                    // Value "C": chipset ST(0), MegaST(1) or STE(2)
                    if(id == "C") system_chipset <= data_in[1:0];
                    // Value "M": 4MB(0) or 8MB(1)
                    if(id == "M") system_memory <= data_in[0];
                    // Value "V": color(0) or monochrome(1)
                    if(id == "V") system_video <= data_in[0];
                    // Value "R": coldboot(3), reset(1) or run(0)
                    if(id == "R") system_reset <= data_in[1:0];
                    // Value "S": scanlines none(0), 25%(1), 50%(2) or 75%(3)
                    if(id == "S") system_scanlines <= data_in[1:0];
                    // Value "A": volume mute(0), 33%(1), 66%(2) or 100%(3)
                    if(id == "A") system_volume <= data_in[1:0];
                end
            end
         end
      end
   end
end
    
endmodule
