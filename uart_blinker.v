

module uart_blinker
	#(parameter UART_CLOCK = 115200)
	(input uart_clock,
	 input reset_n,
	 output reg led);
	 
	localparam BITS = $clog2(UART_CLOCK);
	reg [BITS-1:0] counter;
	
	always @ (posedge uart_clock or negedge reset_n)	begin
		if(~reset_n) begin
			counter <= 'b0;
			led <= 'b0;
		end else begin
			if(counter == UART_CLOCK) begin
				counter <= 'b0;
				led <= ~led;
			end else begin
				counter <= counter + 1;
			end
		end
	end
	
endmodule
