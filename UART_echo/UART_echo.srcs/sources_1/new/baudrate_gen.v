`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2023 01:38:33 AM
// Design Name: 
// Module Name: baudrate_gen
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


module baudrate_gen
(
    input   I_clk                  , // ϵͳ50MHzʱ��
    input   I_rst_n                , // ϵͳȫ�ָ�λ
    input   I_bps_tx_clk_en        , // ���ڷ���ģ�鲨����ʱ��ʹ���ź�
    input   I_bps_rx_clk_en        , // ���ڽ���ģ�鲨����ʱ��ʹ���ź�
    output  O_bps_tx_clk           , // ����ģ�鲨���ʲ���ʱ��
    output  O_bps_rx_clk             // ����ģ�鲨���ʲ���ʱ��
);

parameter       C_BPS9600         = 5207         ,    //������Ϊ9600bps
                C_BPS19200        = 2603         ,    //������Ϊ19200bps
                C_BPS38400        = 1301         ,    //������Ϊ38400bps
                C_BPS57600        = 867          ,    //������Ϊ57600bps
                C_BPS115200       = 867          ;    //������Ϊ115200bps
                
parameter       C_BPS_SELECT      = C_BPS115200  ;    //������ѡ��
                

reg [12:0]  R_bps_tx_cnt       ;
reg [12:0]  R_bps_rx_cnt       ;

///////////////////////////////////////////////////////////    
// ���ܣ����ڷ���ģ��Ĳ�����ʱ�Ӳ����߼�
///////////////////////////////////////////////////////////
always @(posedge I_clk or negedge I_rst_n)
begin
    if(!I_rst_n)
        R_bps_tx_cnt <= 13'd0 ;
    else if(I_bps_tx_clk_en == 1'b1)
        begin
            if(R_bps_tx_cnt == C_BPS_SELECT)
                R_bps_tx_cnt <= 13'd0 ;
            else
                R_bps_tx_cnt <= R_bps_tx_cnt + 1'b1 ;                 
        end    
    else
        R_bps_tx_cnt <= 13'd0 ;        
end

assign O_bps_tx_clk = (R_bps_tx_cnt == 13'd1) ? 1'b1 : 1'b0 ;

///////////////////////////////////////////////////////////    
// ���ܣ����ڽ���ģ��Ĳ�����ʱ�Ӳ����߼�
///////////////////////////////////////////////////////////
always @(posedge I_clk or negedge I_rst_n)
begin
    if(!I_rst_n)
        R_bps_rx_cnt <= 13'd0 ;
    else if(I_bps_rx_clk_en == 1'b1)
        begin
            if(R_bps_rx_cnt == C_BPS_SELECT)
                R_bps_rx_cnt <= 13'd0 ;
            else
                R_bps_rx_cnt <= R_bps_rx_cnt + 1'b1 ;                 
        end    
    else
        R_bps_rx_cnt <= 13'd0 ;        
end

assign O_bps_rx_clk = (R_bps_rx_cnt == C_BPS_SELECT >> 1'b1) ? 1'b1 : 1'b0 ;

endmodule