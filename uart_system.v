module uart_system
	#(
	  // SYSTEM_CLOCK must be set to the frequency of the sys_clk input
	  parameter SYSTEM_CLOCK = 144000000,
	  
	  // UART_CLOCK can technically be anything that evenly divides the system clock
	  // but the receiving end needs to support that frequency. Standard speeds are
	  // 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, and 115200
	  parameter UART_CLOCK = 115200,
	  
	  // UART_CLOCK_MUL is the number of times the RX line is sampled, and should be
	  // a number 4 or larger.  SYSTEM_CLOCK / (2 * UART_CLOCK * UART_CLOCK_MUL)
	  // must be a whole number to avoid any RX errors
	  parameter UART_CLOCK_MUL = 5,
	  
	  // UART_INIT_DELAY specifies the number of UART_CLOCK cycles to keep the TX line 
	  // idle after reset before sending any data. this number can probably be 0, but
	  // higher numbers make it easier for the other send to synchronise
	  parameter UART_INIT_DELAY = 200,
	  
	  // STOPBITS can be 1 (1 stop bit), or 2 (2 stop bits). any other values will
	  // likely break things
	  parameter STOPBITS = 1,
	  
	  // PARITY can be 0 (none), 1 (odd), or 2 (even).
	  parameter PARITY = 0,
	  
	  // BITSIZE can be 5, 6, 7, or 8. the data buses remain 8 bits, but
	  // the least significant bits are used for bit sizes less than 8
	  parameter BITSIZE = 8
	  )
	(
	  input reset_n,
	  input sys_clk,
	  output wire uart_clock,
	  
	  // TX control
	  input [7:0] tx_data,
	  input tx_wren,
	  
	  // RX control
	  input rx_accept,
	  output wire [7:0] rx_data,
	  output wire rx_data_ready,
	  
	  // UART wires
	  input rx,
	  output wire tx,
	  
	  // Status wires
	  output wire tx_led,
	  output wire rx_led,
	  output wire tx_fifo_full,
	  output wire rx_fifo_full
	);
	
	// These must be set to define the size of the two M9K RAM blocks
	localparam RX_RAM_ADDRESS_BITS = 10;
	localparam TX_RAM_ADDRESS_BITS = 10;
	
	wire reset = ~reset_n;
	
	wire uart_rx_clock;
	
	uart_divider #(SYSTEM_CLOCK/(2*UART_CLOCK), UART_CLOCK_MUL) divider(
					.reset(reset), 
					.sys_clk(sys_clk), 
					.outclk(uart_clock), 
					.outclk2(uart_rx_clock)
	);
	
	wire [7:0] tx_uart_data;
	wire tx_uart_wren;
	wire tx_accept;
	wire [7:0] rx_uart_data;
	wire rx_uart_data_ready;
	
	uart #(UART_INIT_DELAY, UART_CLOCK_MUL, STOPBITS, PARITY, BITSIZE) u1(
					.reset(reset),
					.uart_clock(uart_clock), 
					.rx_clock(uart_rx_clock),
					
					.tx_data(tx_uart_data),
					.tx_wren(tx_uart_wren),
					.tx_accept(tx_accept),
					
					.tx(tx),
					.tx_led(tx_led),
					
					.rx_data(rx_uart_data),
					.rx_data_ready(rx_uart_data_ready),
					
					.rx(rx),
					.rx_led(rx_led)
	);
	
	wire [7:0] tx_data_out;
	wire tx_fifo_ram_wren;
	wire [TX_RAM_ADDRESS_BITS-1:0] tx_fifo_ram_read_address;
	wire [TX_RAM_ADDRESS_BITS-1:0] tx_fifo_ram_write_address;

	wire [7:0] rx_data_out;
	wire rx_fifo_ram_wren;
	wire [RX_RAM_ADDRESS_BITS-1:0] rx_fifo_ram_read_address;
	wire [RX_RAM_ADDRESS_BITS-1:0] rx_fifo_ram_write_address;
		
	uart_fifo #(TX_RAM_ADDRESS_BITS, RX_RAM_ADDRESS_BITS) f1(
					.reset(reset),
					.sys_clk(sys_clk),

					// FIFO input
					.tx_wren(tx_wren),
					.tx_data(tx_data),
					
					.tx_out_wren(tx_uart_wren),
					.tx_accept(tx_accept),
	
					.rx_data(rx_uart_data),
					.rx_data_ready(rx_uart_data_ready),
					.rx_data_out_ready(rx_data_ready),
					.rx_accept(rx_accept),
					
					// TX ram
					.tx_data_out(tx_data_out),
					.tx_fifo_ram_read_address(tx_fifo_ram_read_address),
					.tx_fifo_ram_write_address(tx_fifo_ram_write_address),
					.tx_fifo_ram_wren(tx_fifo_ram_wren),
					
					// RX ram
					.rx_data_out(rx_data_out),
					.rx_fifo_ram_read_address(rx_fifo_ram_read_address),
					.rx_fifo_ram_write_address(rx_fifo_ram_write_address),
					.rx_fifo_ram_wren(rx_fifo_ram_wren),

					.tx_fifo_full(tx_fifo_full),
					.rx_fifo_full(rx_fifo_full)
	);
	
	uart_fifo_dual_port_ram tx_ram(
					.clock(sys_clk),
					.data(tx_data_out),
					.rdaddress(tx_fifo_ram_read_address),
					.wraddress(tx_fifo_ram_write_address),
					.wren(tx_fifo_ram_wren),
					.q(tx_uart_data)
	);
	
	uart_fifo_dual_port_ram rx_ram(
					.clock(sys_clk),
					.data(rx_data_out),
					.rdaddress(rx_fifo_ram_read_address),
					.wraddress(rx_fifo_ram_write_address),
					.wren(rx_fifo_ram_wren),
					.q(rx_data)
	);
		
endmodule
