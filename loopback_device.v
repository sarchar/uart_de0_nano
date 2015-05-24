
module loopback_Device
	(input reset_n,
	 input sys_clk,
	 input pause_n,
	 
	 output reg wren,
	 output reg [7:0] tx_data,
	 
	 input [7:0] rx_data,
	 input rx_data_ready,
	 output reg rx_data_accept
	 
	 );
	 
	localparam WAIT=1'd0, WAIT1=1'd1;
	reg [1:0] state;
	//assign tx_data = rx_data;
	
	always @(posedge sys_clk or negedge reset_n)
	begin
		if(~reset_n)
		begin
			tx_data <= 8'b0;
			wren <= 1'b0;
			rx_data_accept <= 1'b0;
			state <= WAIT;
		end else if(~pause_n) begin
			// nop
		end else begin
			case(state)
				WAIT: begin
					if(rx_data_ready) begin
						tx_data <= rx_data;
						wren <= 1'b1;
						rx_data_accept <= 1'b1;
						state <= WAIT1;
					end
				end
				WAIT1: begin
					rx_data_accept <= 1'b0;
					wren <= 1'b0;
					state <= WAIT;
				end
				default: begin
					wren <= 1'b0;
					rx_data_accept <= 1'b0;
					tx_data <= 8'b0;
					state <= WAIT;
				end
			endcase
		end
	end
endmodule
