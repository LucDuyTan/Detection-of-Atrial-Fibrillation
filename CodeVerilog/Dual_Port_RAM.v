`timescale 1ns/1ns
`include "common.vh"
module Dual_Port_RAM #(
    parameter DATA_WIDTH = 16, 
    parameter ADDR_WIDTH = 6   
)(
    input  wire                    clk,       

    // PORT A
    input  wire                    ena, 
    input  wire                    wea,         
    input  wire [ADDR_WIDTH-1:0]   addra,       
    input  wire [DATA_WIDTH-1:0]   dina,        
    output reg  [DATA_WIDTH-1:0]   douta,       

    // PORT B
    input  wire                    enb,        
    input  wire                    web,        
    input  wire [ADDR_WIDTH-1:0]   addrb,       
    input  wire [DATA_WIDTH-1:0]   dinb,        
    output reg  [DATA_WIDTH-1:0]   doutb        
);

    reg [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];

    always @(posedge clk) begin
        // Port A
        if (ena) begin
            if (wea)
                mem[addra] <= dina;
            douta <= mem[addra];
        end

        // Port B
        if (enb) begin
            if (web)
                mem[addrb] <= dinb;
            doutb <= mem[addrb];
        end
    end

endmodule
