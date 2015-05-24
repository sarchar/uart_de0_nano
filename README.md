# UART on DE0-Nano

The goal of this project was to create a UART/serial black box that can be
added to any project easily on the DE0-Nano. The only extra required hardware
is a serial interface. I am using a CP2102 USB to UART bridge
(http://www.silabs.com/Support%20Documents/TechnicalDocs/CP2102-9.pdf), but
anything should work.

## Getting started

The project contains a sample application called loopback_test, which just sends all data it receives. 

To use this in your own project, you will require the files uart.v,
uart_fifo_dual_port_ram.qip, and uart_fifo.v.  To make your life easier, also
include uart_system.v and use uart_system as if it were the black box serial
system. All parameters can be specified on uart_system.v.  See the top of
uart_system.v for details on what each parameter means.

The loopback_test block diagram is here:

![Loopback Test](https://github.com/sarchar/uart_de0_nano/blob/master/block_diagram.png)

## Clocks

I found the most convenient clock speed to work with to be 144MHz, which is
easily produceable from a PLL. The UART divider can then produce most standard
UART speeds. I succesfully tested up to 576kHz, but higher speeds should be
possible.

## Features

Other features include:

* 1 / 2 stop bits
* None / Even / Odd parity
* 5- / 6- / 7- / 8-Bit Data
* TX/RX activity signals
* RX and TX FIFOs (default to 1kB each)

