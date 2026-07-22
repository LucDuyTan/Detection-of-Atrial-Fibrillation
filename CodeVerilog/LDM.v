    `timescale 1ns/1ns
    `include "common.vh"
    
    module LDM
    (
        input  wire                                CLK,
        input  wire                                RST,                
        input  wire                                ctrl_clear,   

        input  wire                                ctrl_pp_sel,
        input  wire [`RRI_ADDR_BITS-1:0]           ctrl_pp_rd_addr,
        input  wire [`RRI_ADDR_BITS-1:0]           ctrl_pp_wr_addr,
          
        input  wire                                ctrl_uni_we,      
        input  wire [`RES_ADDR_BITS-1:0]           ctrl_uni_addr_a,  
        input  wire [`RES_ADDR_BITS-1:0]           ctrl_uni_addr_b,    
    
        input  wire [2:0]                          ctrl_perm_rd_addr,  
        
 
     
        input  wire signed [`WORD_BITS_X2-1:0]     lsu_uni_data_in,  
        
        input  wire                                lsu_nn50_inc,       
        input  wire                                lsu_perm_inc,       
        input  wire [2:0]                          lsu_perm_code_in,   
    
        output wire signed [`WORD_BITS_X2-1:0]     ldm_pp_data_out,  
        output wire signed [`WORD_BITS_X2-1:0]     ldm_uni_data_out_a, 
        output wire signed [`WORD_BITS_X2-1:0]     ldm_uni_data_out_b,
        output wire signed [`WORD_BITS_X2-1:0]     ldm_perm_rd_data_out,
        output wire signed [`WORD_BITS_X2-1:0]     ldm_nn50_out 
 

    );
    
        wire [`RRI_ADDR_BITS:0] ram_wr_addr = {ctrl_pp_sel, ctrl_pp_wr_addr};
        wire [`RRI_ADDR_BITS:0] ram_rd_addr = {~ctrl_pp_sel, ctrl_pp_rd_addr};
    
        Dual_Port_RAM #(
            .DATA_WIDTH(`WORD_BITS_X2),         
            .ADDR_WIDTH(`RRI_ADDR_BITS)  
        ) ram_ping_pong (
            .clk(CLK),
            .ena(1'b1),
            .wea(1'b0),       
            .addra(ram_wr_addr),         
            .dina(1'b0),  
            .douta(),
            .enb(1'b1),       
            .web(1'b0),                     
            .addrb(ram_rd_addr),         
            .dinb({`WORD_BITS_X2{1'b0}}),  
            .doutb(ldm_pp_data_out)  
        );
    
        Dual_Port_RAM #(
            .DATA_WIDTH(`WORD_BITS_X2),     
            .ADDR_WIDTH(`RES_ADDR_BITS)      
        ) ram_uni (
            .clk(CLK),
            .ena(1'b1),
            .wea(ctrl_uni_we),     
            .addra(ctrl_uni_addr_a),
            .dina(lsu_uni_data_in),   
            .douta(ldm_uni_data_out_a),  
            .enb(1'b1),
            .web(1'b0),                     
            .addrb(ctrl_uni_addr_b),
            .dinb({`WORD_BITS_X2{1'b0}}),   
            .doutb(ldm_uni_data_out_b)  
        );
        reg [15:0] nn50_counter;
    
        always @(posedge CLK or posedge RST) begin
            if (RST) begin
                nn50_counter <= 16'd0;
            end else if (ctrl_clear) begin
                nn50_counter <= 16'd0;
            end else if (lsu_nn50_inc) begin
                nn50_counter <= nn50_counter + 16'd1;
            end
        end
    
        assign ldm_nn50_out = nn50_counter;
    
        reg [15:0] perm_count [0:7]; 
    
        always @(posedge CLK or posedge RST) begin
            if (RST) begin
                perm_count[0] <= 16'd0;
                perm_count[1] <= 16'd0;
                perm_count[2] <= 16'd0;
                perm_count[3] <= 16'd0;
                perm_count[4] <= 16'd0;
                perm_count[5] <= 16'd0;
                perm_count[6] <= 16'd0;
                perm_count[7] <= 16'd0;
            end else if (ctrl_clear) begin
                perm_count[0] <= 16'd0;
                perm_count[1] <= 16'd0;
                perm_count[2] <= 16'd0;
                perm_count[3] <= 16'd0;
                perm_count[4] <= 16'd0;
                perm_count[5] <= 16'd0;
                perm_count[6] <= 16'd0;
                perm_count[7] <= 16'd0;
            end else if (lsu_perm_inc) begin
                perm_count[lsu_perm_code_in] <= perm_count[lsu_perm_code_in] + 16'd1;
            end
        end
        assign ldm_perm_rd_data_out = perm_count[ctrl_perm_rd_addr];
    
    endmodule
