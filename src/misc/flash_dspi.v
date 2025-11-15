//
// flash_dspi.v - reading W25Q64FV, 64MBit spi flash
//
// This module runs a SPI flash in DSPI/IO mode. In this mode the
// flash uses 2 bit IO for address and data. 
//
// modified for 8 bit data read 

module flash
(
 input		   clk,
 input		   resetn,
 output		   ready, 

 // chipset read interface
 input [23:0]	   address, // 8 bit word address
 input		   cs, 
 output reg [7:0] dout,
 
 // interface to the chip
 output			mspi_cs,
 inout			mspi_di, // data in into flash chip
 output			mspi_hold,
 output			mspi_wp,
 inout			mspi_do, // data out from flash chip
 
`ifdef VERILATOR		
 input [1:0]	   mspi_din, 
`endif
 
 output reg	   busy
);

reg		   dspi_mode;

wire [1:0]	   dspi_out;

reg mspi_hold_i;
reg mspi_wp_i;
reg mspi_cs_i;

// drive hold and wp to their static default
assign mspi_hold = !resetn?1'bz:mspi_hold_i;
assign mspi_wp   = !resetn?1'bz:mspi_wp_i;
assign mspi_cs   = !resetn?1'bz:mspi_cs_i;

wire [1:0] output_en = { 
    dspi_mode?(state<=6'd22):1'b0,    // io1 is do in SPI mode and thus never driven
    dspi_mode?(state<=6'd22):1'b1     // io0 is di in SPI mode and thus always driven
};
      
wire [1:0] data_out = {
    dspi_mode?dspi_out[1]:1'bx,      // never driven in SPI mode
    dspi_mode?dspi_out[0]:spi_di       
};

assign mspi_do   = !resetn?1'bz:output_en[1]?data_out[1]:1'bz;
assign mspi_di   = !resetn?1'bz:output_en[0]?data_out[0]:1'bz;

// use "fast read dual IO" command
wire [7:0]   CMD_RD_DIO = 8'hbb;  

// M(5:4) = 1,0 -> “Continuous Read Mode”
wire [7:0] M = 8'b0010_0000;
     
reg [5:0] state;
reg [4:0] init;

// flash is ready when init phase has ended
assign ready = (init == 5'd0);  
   
// send 16 1's during init on IO0 to make sure M4 = 1 and dspi is left
wire spi_di = (init>1)?1'b1:CMD_RD_DIO[3'd7-state[2:0]];  // the command is sent in spi mode
   
assign dspi_out = 
		  (state==6'd8)?address[23:22]:
		  (state==6'd9)?address[21:20]:
		  (state==6'd10)?address[19:18]:
		  (state==6'd11)?address[17:16]:
		  (state==6'd12)?address[15:14]:
		  (state==6'd13)?address[13:12]:
		  (state==6'd14)?address[11:10]:
		  (state==6'd15)?address[9:8]:
		  (state==6'd16)?address[7:6]:
		  (state==6'd17)?address[5:4]:
		  (state==6'd18)?address[3:2]:
		  (state==6'd19)?address[1:0]:
		  (state==6'd20)?M[7:6]:
		  (state==6'd21)?M[5:4]:
		  (state==6'd22)?M[3:2]:
		  (state==6'd23)?M[1:0]:
		  2'bzz;   
   
`ifdef VERILATOR
wire [1:0] dspi_in = mspi_din;  
`else
wire [1:0] dspi_in = { mspi_do, mspi_di };  
`endif
   
always @(posedge clk or negedge resetn) begin
   reg csD, csD2;
   
   if(!resetn) begin
      // initially assume regular spi mode
      dspi_mode <= 1'b0;
      mspi_cs_i <= 1'b1;
      busy <= 1'b0;
      init <= 5'd20;
      csD <= 1'b0;
   end else begin
      csD <= cs;     // bring cs into local clock domain
      csD2 <= csD;   // delay to detect rising edge

      // send 16 1's on IO0 to make sure M4 = 1 and dspi is left and we are in a known state
      if(init != 5'd0) begin
        if(init == 5'd20) mspi_cs_i <= 1'b0;  // select flash chip at begin of 16 1's	 
        if(init == 5'd4)  mspi_cs_i <= 1'b1;  // de-select flash chip at end of 16 1's
	 
        if(init != 5'd1 || !busy)
            init <= init - 5'd1;
      end
	 
      // wait for rising edge of cs or end of init phase
      if((csD && !csD2 && !busy)||(init == 5'd2)) begin
        mspi_cs_i <= 1'b0;	  // select flash chip	 
        busy <= 1'b1;

        // skip sending command if already in DSPI mode and M(5:4) == (1:0) sent
        if(dspi_mode) state <= 6'd8;
        else	      state <= 6'd0;
      end 

      // run state machine
      if(busy) begin
        state <= state + 6'd1;

        // enter dspi mode after command has been sent
        if(state == 6'd7)
            dspi_mode <= 1'b1;

        // latch output
        // latch output and shift into 16 bit register
	if(state >= 6'd24 && state <= 6'd27)
	  dout <= { dout[5:0], dspi_in};

//        if(state == 6'd25) dout[7:6] <= dspi_in;
//        if(state == 6'd26) dout[5:4] <= dspi_in;
//        if(state == 6'd27) dout[3:2] <= dspi_in;
//        if(state == 6'd28) dout[1:0] <= dspi_in;
        // signal that the transfer is done
        if(state == 6'd27) begin
            state <= 6'd0;	    
            busy <= 1'b0;
            mspi_cs_i <= 1'b1;	// deselect flash chip	 
        end
      end
   end
end
   
endmodule
