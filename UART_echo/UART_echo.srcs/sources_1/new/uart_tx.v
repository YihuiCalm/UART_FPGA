//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yihui Wang
// 
// Create Date: 04/13/2023 06:27:33 PM
// Design Name: 
// Module Name: uart_tx
// Project Name: 
// Target Devices: ARTIX-7 35T
// Tool Versions: Vivado 2021.2
// Description: Transmit module of UART protocol.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module uart_tx(
    input [7:0] data,
    input CLK100MHZ,
    input enable,
    input reset,
    output done,
    output uart_rxd_out
);
     
    reg [3:0] counter=0;
    reg stop=0;
    reg [1:0] state=idle, next=idle;
    reg [9:0] tx_data=0;
    
    parameter idle = 2'b01;
    parameter transmit = 2'b10;
    
    //Baudrate clock generation.
    parameter baudrate = 115200;
    parameter clk_frequence = 100000000;
    parameter clk_per_bit = clk_frequence/baudrate;
    reg [31:0] counter_bps=0;
    reg baudrate_pulse = 0;
    
    always @(posedge CLK100MHZ, posedge reset) begin
        if (reset) begin
            counter_bps <= 32'd0;
            baudrate_pulse <= 0;
        end
        else if (state == transmit) begin
            if (counter_bps==clk_per_bit) begin
                baudrate_pulse <= 1'b1;
                counter_bps <= 32'd0;
            end
            else begin 
                counter_bps <= counter_bps + 32'd1;
                baudrate_pulse <= 0;
            end
        end
        else begin 
            counter_bps <= 32'd0;
            baudrate_pulse <= 0;
        end
    end
    
    
    //State table.
    always @(*) begin
        case (state)
            idle: next = enable? transmit: idle;
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
    
    //Data organize.
    always @(posedge CLK100MHZ, posedge reset) begin
        if (reset) begin
            tx_data <= {1'b1,8'd0,1'b0};
        end
        else if (next==transmit&state==idle) tx_data <= {1'b1,data,1'b0};
        else if (state==transmit&baudrate_pulse) tx_data <= tx_data>>1;
        else tx_data <= tx_data;
    end

    // Counter.
    always @(posedge CLK100MHZ, posedge reset) begin
        if (reset) begin
            counter <= 4'd0;
            stop <= 1'b0;
        end
        else if (state==transmit) begin
            if (baudrate_pulse) begin
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
        else stop <= 1'b0;
    end
            
    assign uart_rxd_out = state[1]? tx_data[0]: 1'b1;
    assign done = stop;
endmodule 

