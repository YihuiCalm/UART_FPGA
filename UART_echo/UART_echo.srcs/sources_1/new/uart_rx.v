//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yihui Wang
// 
// Create Date: 04/13/2023 06:27:33 PM
// Design Name: 
// Module Name: uart_rx
// Project Name: 
// Target Devices: ARTIX-7 35T
// Tool Versions: 
// Description: Receive module of UART protocol.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_rx(
    input uart_txd_in,
    input CLK100MHZ,
    input reset,
    output done,
    output [7:0] data,
    output test,
    output test1
    );
    
     
    parameter idle = 2'b01;
    parameter transmit = 2'b10;
    
    reg [1:0] state=idle, next=idle;
    reg stop=0;
    reg [3:0] counter=0;
    reg [8:0] rx_data=0;
    
    //Baudrate clock generation
    parameter baudrate = 115200;
    parameter clk_frequence = 100000000;
    parameter clk_per_bit = clk_frequence/baudrate;
    reg [31:0] counter_bps=0;
    wire baudrate_pulse;
    
    always @(posedge CLK100MHZ, posedge reset) begin
        if (reset) begin
            counter_bps <= 32'd0;
        end
        else if (state == transmit) begin
            if (counter_bps==clk_per_bit) begin
                counter_bps <= 32'd0;
            end
            else begin 
                counter_bps <= counter_bps + 32'd1;
            end
        end
        else begin 
            counter_bps <= 32'd0;
        end
    end     
    assign baudrate_pulse = (counter_bps==clk_per_bit/2);
    
    //Terminate metastable
    reg [3:0] uart_rx_reg=0;
    always @(posedge CLK100MHZ, posedge reset) begin
        if (reset) uart_rx_reg <= 4'd0;
        else uart_rx_reg <= {uart_rx_reg[2:0], uart_txd_in};
    end

    //States table.
    always @(*) begin
        case (state)
            idle: next = (uart_rx_reg[3:2]==2'b10)? transmit: idle;
            transmit: next = stop? idle: transmit;
        endcase
    end
    
    //State transitions.
    always @(posedge CLK100MHZ, posedge reset) begin
        if (reset) begin
            state <= idle;
        end
        else state <= next;
    end
    
    //Data counter.
    always @(posedge CLK100MHZ, posedge reset) begin
        if (reset) begin
            counter <= 4'd0;
            stop <= 1'b0;
        end
        else if (state==transmit & baudrate_pulse) begin
            if (counter == 4'd8) begin
                    stop <= 1'b1;
                    counter <= 4'd0;
            end
            else begin
                    counter <= counter + 4'd1;
                    stop <= 1'b0;
            end
        end
        else stop <= 1'b0;        
    end
        
    //Data organize.   
    always @(posedge CLK100MHZ, posedge reset) begin
        if (reset) begin
            rx_data <= 9'd0;
        end
        else begin
            case (state)
                idle: rx_data = (next==transmit)? 9'd0: rx_data;
                transmit: rx_data = baudrate_pulse? {uart_txd_in,rx_data[8:1]}: rx_data;
            endcase
        end
    end
    
    assign data = rx_data[8:1];
    assign done = stop;
        
endmodule