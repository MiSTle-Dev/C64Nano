/*
    hid.v
 
    hid (keyboard, mouse etc) interface to the IO MCU

    c64 core specific variant of hid
  */

module hid (
  input               clk,
  input               reset,

  input               data_in_strobe,
  input               data_in_start,
  input [7:0]         data_in,
  output reg [7:0]    data_out,

  // input local db9 port events to be sent to MCU
  input  [5:0]        db9_port,
  output reg          irq,
  input               iack,
  output reg [7:0]    usb_kbd,
  output reg          kbd_strobe,

  // output HID data received from USB
  output reg [7:0]    joystick0,
  output reg [7:0]    joystick1,
  output reg [7:0]    numpad,
  output reg [1:0]    mouse_btns,
  output reg [7:0]    mouse_x,
  output reg [7:0]    mouse_y,
  output reg          mouse_strobe,
  output reg [7:0]    joystick0ax,
  output reg [7:0]    joystick0ay,
  output reg [7:0]    joystick1ax,
  output reg [7:0]    joystick1ay,
  output reg          joystick_strobe,
  output reg [7:0]    extra_button0,
  output reg [7:0]    extra_button1
);


reg [3:0] state;
reg [7:0] command;
reg [7:0] device;   // used for joystick
reg irq_enable;
reg [5:0] db9_portD;
reg [5:0] db9_portD2;

always @(posedge clk) begin
   if(reset) begin
      numpad <= 8'h00;
   end else begin
    if (usb_kbd[7])
        numpad <= 8'h00;
    else
        numpad <=
        (usb_kbd[6:0] == 7'h5e)?numpad | 8'h01:
        (usb_kbd[6:0] == 7'h5c)?numpad | 8'h02:
        (usb_kbd[6:0] == 7'h5a)?numpad | 8'h04:
        (usb_kbd[6:0] == 7'h60)?numpad | 8'h08:
        (usb_kbd[6:0] == 7'h62)?numpad | 8'h10:
        (usb_kbd[6:0] == 7'h63)?numpad | 8'h20:8'h00;
    end
end

// process mouse events
always @(posedge clk) begin
   if(reset) begin
      state <= 4'd0;
      mouse_strobe <=1'b0;
      irq <= 1'b0;
      irq_enable <= 1'b0;
      joystick_strobe <= 1'b0; 
      usb_kbd <= 8'h00;
      kbd_strobe <= 1'b0;

   end else begin
      db9_portD <= db9_port;
      db9_portD2 <= db9_portD;

      // monitor db9 port for changes and raise interrupt
      if(irq_enable) begin
        if(db9_portD2 != db9_portD) begin
            // irq_enable prevents further interrupts until
            // the db9 state has actually been read by the MCU
            irq <= 1'b1;
            irq_enable <= 1'b0;
        end
      end

      if(iack) irq <= 1'b0;      // iack clears interrupt

      mouse_strobe <=1'b0;
      joystick_strobe <=1'b0; 
      if(data_in_strobe) begin      
        if(data_in_start) begin
            state <= 4'd0;
            command <= data_in;
        end else begin
            if(state != 4'd15) state <= state + 4'd1;

            // CMD 0: status data
            if(command == 8'd0) begin
                if(state == 4'd0) data_out <= 8'h01;
                if(state == 4'd1) data_out <= 8'h00;
            end

            // CMD 1: keyboard data
            if(command == 8'd1) begin
            // kbd_column and kbd_row are derived from data_in
               if(state == 4'd0) begin
                    usb_kbd <= data_in;
                    kbd_strobe <= ~kbd_strobe;
                end
            end
            // CMD 2: mouse data
            if(command == 8'd2) begin
                if(state == 4'd0) mouse_btns <= data_in[1:0];
                if(state == 4'd1) mouse_x <= data_in;
                if(state == 4'd2) begin
                    mouse_y <= data_in;
                    mouse_strobe <=1'b1;
                end
            end

            // CMD 3: receive digital joystick data
            if(command == 8'd3) begin
                if(state == 4'd0) device <= data_in;
                if(state == 4'd1) begin
                    if(device == 8'd0) joystick0 <= data_in;
                    if(device == 8'd1) joystick1 <= data_in;
                end
                if(state == 4'd2) begin
                        if(device == 8'd0) joystick0ax <= data_in;
                        if(device == 8'd1) joystick1ax <= data_in;
                end
                if(state == 4'd3) begin
                        if(device == 8'd0) joystick0ay <= data_in;
                        if(device == 8'd1) joystick1ay <= data_in;
                end
                if(state == 4'd4) begin
                        if(device == 8'd0) extra_button0 <= data_in;
                        if(device == 8'd1) begin
                            extra_button1 <= data_in;
                            joystick_strobe <= 1'b1; 
                        end
                end
            end

            // CMD 4: send digital joystick data to MCU
            if(command == 8'd4) begin
                if(state == 4'd0) irq_enable <= 1'b1;    // (re-)enable interrupt
                data_out <= {2'b00, db9_portD };
            end
        end
      end
   end
end

endmodule
