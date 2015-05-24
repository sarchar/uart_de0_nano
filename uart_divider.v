
module uart_divider
	#(parameter COUNT = 0, CLK2_MUL = 5)
	(input sys_clk,
	 input reset,
	 output reg outclk,
	 output reg outclk2);
	 
	 
	// COUNT values:
	//   2.88MHz:
	//      Input @ 144MHz, COUNT = 25
	//   576kHz:
	//      Input @ 144MHz, COUNT = 125
	//   115.2kHz:
	//      Input @ 28.8MHz, COUNT = 125
	//      Input @ 144MHz, COUNT = 625
	//   57.6kHz:
	//      Input @ 144MHz, COUNT = 1250
	// TODO test:
	//   Input @ 28.8MHz, Output @ 57.6kHz, COUNT = 250
	//   Input @ 28.8MHz, Output @ 28.8kHz, COUNT = 500
	//   Input @ 144MHz, Output @ 115.2kHz, COUNT = 625
	// TODO values:
	//   1200, 2400, 4800, 9600, 19200, 28800, 38400, 57600, and 115200.
	localparam BITS  = $clog2(COUNT);
	reg [(BITS-1):0] counter;
	
	always @(posedge sys_clk or posedge reset)
	begin
		if(reset) begin
			counter <= 'b0;
			outclk <= 'b0;
		end else begin
			if(counter == (COUNT - 1)) begin
				counter <= 'b0;
				outclk <= ~outclk;
			end else
				counter <= counter + 1'b1;
		end
	end

	// counter2 produces a clock that is a multiple of the uart clock.
	// this clock is used to oversample the rx line
	localparam COUNT2 = COUNT / CLK2_MUL;
	localparam BITS2 = $clog2(COUNT2);
	reg [(BITS2-1):0] counter2;
		
	always @(posedge sys_clk or posedge reset)
	begin
		if(reset) begin
			counter2 <= 'b0;
			outclk2 <= 'b0;
		end else begin
			if(counter2 == (COUNT2 - 1)) begin
				counter2 <= 'b0;
				outclk2 <= ~outclk2;
			end else
				counter2 <= counter2 + 1'b1;
		end
	end
		
endmodule 
