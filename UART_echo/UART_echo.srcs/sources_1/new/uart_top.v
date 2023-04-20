//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yihui Wang
// 
// Create Date: 04/13/2023 06:27:33 PM
// Design Name: 
// Module Name: uart_top
// Project Name: 
// Target Devices: ARTIX-7 35T
// Tool Versions: Vivado 2021.2
// Description: Top module of UART protocol, FPGA will send back the data it received from other
//              other client, and show the lower 4 bits using leds.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module uart_top(
    input uart_txd_in,
    input CLK100MHZ,
    input btn,
    output uart_rxd_out,
    output led0_b,
    output led1_b,
    output led2_b,
    output led3_b
    );
    
    wire done;
    wire [7:0] data;
    
    parameter baudrate = 115200;
    parameter clk_frequence = 100000000;
    
    assign {led3_b, led2_b, led1_b, led0_b} = data[3:0];    
    
    
    uart_rx #(.baudrate(baudrate), .clk_frequence(clk_frequence))
    uart_rx(
        .uart_txd_in(uart_txd_in),
        .CLK100MHZ(CLK100MHZ),
        .reset(btn),
        .done(done),
        .data(data)
        );
        
    uart_tx #(.baudrate(baudrate), .clk_frequence(clk_frequence))
    uart_tx(
        .data(data),
        .CLK100MHZ(CLK100MHZ),
        .enable(done),
        .reset(btn),
        .uart_rxd_out(uart_rxd_out)
        );
        
endmodule 