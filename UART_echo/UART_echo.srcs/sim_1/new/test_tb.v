`timescale 1us / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/02/2023 11:51:16 AM
// Design Name: 
// Module Name: test_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_tb(
    );
    
    reg CLK100MHZ = 0;
    reg reset = 0;
    wire uart_rxd_out;
    wire led0_b;
    wire led1_b;
    wire led2_b;
    wire led3_b;
    
    uart_top inst(
        .uart_txd_in(uart_in_reg[0]),
        .CLK100MHZ(CLK100MHZ),
        .btn(reset),
        .uart_rxd_out(uart_rxd_out),
        .led0_b(led0_b),
        .led1_b(led1_b),
        .led2_b(led2_b),
        .led3_b(led3_b)
        );
        
    always #1 CLK100MHZ = ~CLK100MHZ;
    

    
    parameter baudrate = 115200;
    parameter clk_frequence = 100000000;
    parameter clk_per_bit = clk_frequence/baudrate;
    reg [31:0] counter_bps=0;
    reg clk = 0;
    
    always @(posedge CLK100MHZ, posedge reset) begin
        if (reset) counter_bps <= 32'd0;
        else begin
            if (counter_bps==clk_per_bit/2) begin
                clk <= ~clk;
                counter_bps <= 32'd0;
            end
            else counter_bps <= counter_bps + 32'd1;
        end
    end
    
    reg [9:0] uart_in_reg = {8'haa,2'b01};
    
    always @(posedge clk, posedge reset)begin
        if (reset) uart_in_reg <= {8'haa,2'b01};
        else if(uart_in_reg!={10{1'b1}}) uart_in_reg <= {1'b1,uart_in_reg[9:1]};
        else #10000 uart_in_reg <= {8'haa,2'b01};
    end
//    reg CLK100MHZ=0;
//    reg btn=0;
//    wire out;
    
//    always #1 CLK100MHZ = ~CLK100MHZ;
    
//    initial begin
//        #10
//        btn = 1;
//        #10
//        btn = 0;
//    end
    
//    top_uart inst(
//        .CLK100MHZ(CLK100MHZ),
//        .btn(btn),
//        .uart_rxd_out(out));
        
   
   
    

    
endmodule
