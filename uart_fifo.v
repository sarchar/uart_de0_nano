
//`define USE_TEST_RAM

module uart_fifo
	#(parameter TX_RAM_ADDRESS_BITS = 10,
	            RX_RAM_ADDRESS_BITS = 10)
	(input reset,
	 input sys_clk,

	
	 input tx_wren, // When this goes high, there's new data for the fifo
	 input [7:0] tx_data,
	 input tx_accept, // UART signals when it can accepted tx data
	 
	 input [7:0] rx_data,
	 input rx_data_ready,
	 input rx_accept, // User signal describes when it accepted rx data
	 
	 output reg tx_out_wren, // High to tell UART that there's data. UART responds by pulsing tx_accept
	 
	 output tx_fifo_full,
	 output reg tx_fifo_ram_wren, // pulled high to write new data into the fifo ram
	 
	 output reg [7:0] tx_data_out,
	 output reg [TX_RAM_ADDRESS_BITS-1:0] tx_fifo_ram_read_address,
	 output reg [TX_RAM_ADDRESS_BITS-1:0] tx_fifo_ram_write_address,
	 
	 output reg [7:0] rx_data_out,
	 output reg [RX_RAM_ADDRESS_BITS-1:0] rx_fifo_ram_read_address,
	 output reg [RX_RAM_ADDRESS_BITS-1:0] rx_fifo_ram_write_address,
	 output rx_fifo_full,
	 output reg rx_fifo_ram_wren,
	 output reg rx_data_out_ready
	);
	
	localparam FIFO_TX_SIZE = 1 << TX_RAM_ADDRESS_BITS;
	localparam FIFO_RX_SIZE = 1 << RX_RAM_ADDRESS_BITS;
	
	// Ring buffer content usage...need 1 extra bit for when the buffer is full
	reg [TX_RAM_ADDRESS_BITS:0] tx_count;
	assign tx_fifo_full = (tx_count == FIFO_TX_SIZE);
	
	reg [RX_RAM_ADDRESS_BITS:0] rx_count;
	assign rx_fifo_full = (rx_count == FIFO_RX_SIZE);
	
	localparam TX_IDLE=2'd0, TX_WAIT_MEM=2'd1, TX_WAIT_UART=2'd2;
	reg [1:0] tx_state;
	
	wire write_tx_ram = tx_wren && ~tx_fifo_full;
	
	reg rx_data_ready_wait;
	wire write_rx_ram = rx_data_ready && ~rx_data_ready_wait && ~rx_fifo_full;
	
	localparam RX_IDLE=2'd0, RX_WAIT_MEM1=2'd1, RX_WAIT_MEM2=2'd2, RX_WAIT_ACCEPT=2'd3;
	reg [1:0] rx_state;

	////////////////////////////////////////////////////////////////////////////////
	// TX protocol	
	always @(posedge sys_clk or posedge reset)
	begin
		if(reset) begin
			tx_fifo_ram_read_address <= {TX_RAM_ADDRESS_BITS{1'b0}};
`ifdef USE_TEST_RAM
			tx_count <= FIFO_TX_SIZE;
			tx_fifo_ram_write_address <= FIFO_TX_SIZE;
`else
			tx_count <= 'b0;
			tx_fifo_ram_write_address <= {TX_RAM_ADDRESS_BITS{1'b0}};
`endif
			tx_fifo_ram_wren <= 'b0;
			tx_data_out <= 8'b0;
			tx_out_wren <= 'b0;
			tx_state <= TX_IDLE;
		end else begin
			// Allow a write to memory as long as the fifo isn't full
			tx_fifo_ram_wren <= write_tx_ram;
			if(write_tx_ram)
				tx_data_out <= tx_data;
				
			// write_address will move only after written to it in the last cycle, so tx_fifo_ram_wren is used instead of the write_tx_ram wire
			tx_fifo_ram_write_address <= tx_fifo_ram_write_address + (tx_fifo_ram_wren ? 1 : 0);

			// tx_count will go down when the UART accepts data, and up when incoming data is received
			// this logic allows for both to happen simultaneously:
			tx_count <= tx_count + (((tx_state == TX_WAIT_UART) && tx_accept) ? -1 : 0) + ((write_tx_ram) ? 1 : 0);
						
			case(tx_state)
				TX_IDLE: begin
					// This uses the previous value of tx_count
					if((| tx_count) && ~tx_accept) begin
						// There's data to send, and rdaddress is already on the line, 
						// so waiting 1 clock cycle (to make sure RAM is ready) should be good, then flip tx_out_wren high
						tx_state <= TX_WAIT_MEM;
					end
				end
				TX_WAIT_MEM: begin
					// Byte is on the line, so tell UART it's ready and wait for accept
					tx_out_wren <= 1'b1;
					tx_state <= TX_WAIT_UART;
				end
				TX_WAIT_UART: begin
					if(tx_accept) begin
						tx_out_wren <= 1'b0;
						
						// free up space now that the UART has taken the data
						tx_fifo_ram_read_address <= tx_fifo_ram_read_address + 1'b1;
						
						// wait for the UART to be ready again
						tx_state <= TX_IDLE;
					end
				end
				default: begin
					tx_out_wren <= 1'b0;
					tx_state <= TX_IDLE;
				end
			endcase
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////
	// RX protocol
	always @(posedge sys_clk or posedge reset)
	begin
		if(reset) begin
			rx_fifo_ram_read_address <= {RX_RAM_ADDRESS_BITS{1'b0}};
			rx_fifo_ram_write_address <= {RX_RAM_ADDRESS_BITS{1'b0}};
			rx_count <= 'b0;
			rx_fifo_ram_wren <= 'b0;
			rx_data_out <= 8'b0;
			rx_data_out_ready <= 1'b0;
			rx_data_ready_wait <= 1'b0;
			rx_state <= RX_IDLE;
		end else begin
			// Allow a write to memory as long as the fifo isn't full but only once when data_ready is high
			rx_fifo_ram_wren <= write_rx_ram;
			if(write_rx_ram) begin
				rx_data_out <= rx_data;
				rx_data_ready_wait <= 1'b1;
			end else if(~rx_data_ready && rx_data_ready_wait) begin
				rx_data_ready_wait <= 1'b0;
			end
				
			// write_address will move only after it was written to it in the last cycle, so rx_fifo_ram_wren is used instead of the write_rx_ram wire
			rx_fifo_ram_write_address <= rx_fifo_ram_write_address + (rx_fifo_ram_wren ? 1 : 0);

			// rx_count will go down when the user accepts data, and up when UART data is received.
			// this logic allows for both to happen simultaneously:
			rx_count <= rx_count + (((rx_state == RX_WAIT_ACCEPT) && rx_accept) ? -1 : 0) + ((write_rx_ram) ? 1 : 0);
			
			case(rx_state)
				RX_IDLE: begin
					if((| rx_count) && ~rx_accept) begin
						// read address is already on the line this cycle,
						// If the data out of q is being registered, another clock cycle 
						// must occur, so waiting two cycles seems safer
						rx_state <= RX_WAIT_MEM1;
					end
				end
				RX_WAIT_MEM1: begin
					rx_state <= RX_WAIT_MEM2;
				end
				RX_WAIT_MEM2: begin
					// data is ready, trigger to user
					rx_data_out_ready <= 1'b1;
					rx_state <= RX_WAIT_ACCEPT;
				end
				RX_WAIT_ACCEPT: begin
					if(rx_accept) begin
						rx_data_out_ready <= 1'b0;
						rx_fifo_ram_read_address <= rx_fifo_ram_read_address + 1'b1;
						rx_state <= RX_IDLE;
					end
				end
				default: begin
					rx_data_out_ready <= 1'b0;
					rx_state <= RX_IDLE;
				end
			endcase
		end
	end

endmodule