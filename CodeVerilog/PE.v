`timescale 1ns/1ns
`include "common.vh"

module PE (
    input  wire                                 CLK,
    input  wire                                 RST,
    
    input  wire                                 ctrl_clear,
    input  wire                                 ctrl_en, 
    input  wire [`ALU_CFG_BITS-1:0]             ctrl_cfg_alu,
    input  wire [3:0]                           ctrl_phase,
    input  wire                                 ctrl_is_last,
    
    input  wire                                 ctrl_pp_sel,    
    input  wire [`RRI_ADDR_BITS-1:0]            ctrl_pp_rd_addr,
        
    input  wire                                 ctrl_uni_we,        
    input  wire [`RES_ADDR_BITS-1:0]            ctrl_uni_addr_a,    
    input  wire [`RES_ADDR_BITS-1:0]            ctrl_uni_addr_b,
        
    input  wire [2:0]                           ctrl_perm_rd_addr,  
            
    output wire signed [63:0]                   pe_out,
    output wire                                 pe_valid_out,
    output wire                                 done_phase,
    output wire [`WORD_BITS_X2-1:0]             ldm_pp_data_out
    
);
    
    wire [15:0]                                 w_ldm_nn50_out;
    wire [15:0]                                 w_ldm_perm_rd_data_out;
    wire signed [`WORD_BITS_X2-1:0]             w_ldm_pp_data_out;
    wire signed [`WORD_BITS_X2-1:0]             w_ldm_uni_data_out_a;
    wire signed [`WORD_BITS_X2-1:0]             w_ldm_uni_data_out_b;
    wire signed [`WORD_BITS_X2-1:0]             w_lsu_uni_data_out;
    wire                                        w_lsu_nn50_inc;
    wire                                        w_lsu_perm_inc;
    wire [2:0]                                  w_lsu_perm_code_out;
    wire                                        w_done_phase;

    wire [`WORD_BITS_X2-1:0]                    w_lsu_x_out;
    wire signed [31:0]                          w_lut_inv;
    wire signed [31:0]                          w_lut_log2;
    wire signed [31:0]                          w_lut_xlog2x;

    wire                                        w_s0_valid;
    wire signed [`WORD_BITS_X2-1:0]             w_alu_s0;
    wire                                        w_s1_valid;
    wire signed [`WORD_BITS_X2-1:0]             w_alu_s1;
    wire signed [63:0]                          w_alu_d0;
    wire                                        w_alu_valid;
    wire                                        w_lsu_is_last_to_alu;
    wire                                        w_alu_is_last_to_lsu;

    assign pe_out       = w_alu_d0;
    assign pe_valid_out = w_alu_valid;
    assign ldm_pp_data_out = w_ldm_pp_data_out;
    assign done_phase      = w_done_phase;

    LDM u_ldm (
        .CLK                    (CLK),
        .RST                    (RST),
        
        .ctrl_clear             (ctrl_clear),
        .ctrl_pp_sel            (ctrl_pp_sel),
        .ctrl_pp_rd_addr        (ctrl_pp_rd_addr),
        .ctrl_pp_wr_addr        ({`RRI_ADDR_BITS{1'b0}}),
        .ctrl_uni_we            (ctrl_uni_we),
        .ctrl_uni_addr_a        (ctrl_uni_addr_a),
        .ctrl_uni_addr_b        (ctrl_uni_addr_b),
        .ctrl_perm_rd_addr      (ctrl_perm_rd_addr),
        
        .ldm_nn50_out           (w_ldm_nn50_out),
        .ldm_perm_rd_data_out   (w_ldm_perm_rd_data_out),
        
        .lsu_uni_data_in        (w_lsu_uni_data_out),
        .lsu_nn50_inc           (w_lsu_nn50_inc),
        .lsu_perm_inc           (w_lsu_perm_inc),
        .lsu_perm_code_in       (w_lsu_perm_code_out),
        
        .ldm_pp_data_out        (w_ldm_pp_data_out),
        .ldm_uni_data_out_a     (w_ldm_uni_data_out_a),
        .ldm_uni_data_out_b     (w_ldm_uni_data_out_b)
    );

    LSU u_lsu (
        .CLK                    (CLK),
        .RST                    (RST),
        .ctrl_clear             (ctrl_clear),
        .ctrl_en                (ctrl_en),
        
        .ctrl_phase             (ctrl_phase),
        .ctrl_is_last           (ctrl_is_last),
        
        .ldm_pp_data_in         (w_ldm_pp_data_out),
        .ldm_perm_rd_data_in    (w_ldm_perm_rd_data_out),
        .ldm_uni_data_a_in      (w_ldm_uni_data_out_a),
        .ldm_uni_data_b_in      (w_ldm_uni_data_out_b),
        .ldm_nn50_in            (w_ldm_nn50_out),
        
        .lsu_uni_data_out       (w_lsu_uni_data_out),
        
        .lsu_x_out              (w_lsu_x_out),
        .lut_inv_in             (w_lut_inv),       
        .lut_log2_in            (w_lut_log2),     
        .lut_xlog2x_in          (w_lut_xlog2x), 
        
        .alu_d0_in              (w_alu_d0),
        .alu_valid_in           (w_alu_valid),
        .alu_is_last_in         (w_alu_is_last_to_lsu),
        
        .lsu_s0_valid_out       (w_s0_valid),
        .lsu_s0_out             (w_alu_s0),
        .lsu_s1_valid_out       (w_s1_valid),
        .lsu_s1_out             (w_alu_s1),  
        .lsu_is_last_out        (w_lsu_is_last_to_alu),
        
        .lsu_nn50_inc           (w_lsu_nn50_inc),
        .lsu_perm_inc           (w_lsu_perm_inc),
        .lsu_perm_code_out      (w_lsu_perm_code_out),
        
        .done_phase             (w_done_phase) 
    );

    LUT u_lut (
        .x_in                   (w_lsu_x_out[31:0]),  
        .inv_out                (w_lut_inv),
        .log2_out               (w_lut_log2),
        .xlog2x_out             (w_lut_xlog2x)
    );
    
    ALU u_alu (
        .CLK                    (CLK),
        .RST                    (RST), 
        .ctrl_en                (ctrl_en),
        .ctrl_clear             (ctrl_clear),
        .ctrl_cfg               (ctrl_cfg_alu), 
        
        .s0_valid_in            (w_s0_valid),
        .s0_in                  (w_alu_s0),
        .s1_valid_in            (w_s1_valid),
        .s1_in                  (w_alu_s1),
        .is_last_in             (w_lsu_is_last_to_alu),
        
        .d0_out                 (w_alu_d0),
        .valid_out              (w_alu_valid),
        .is_last_out            (w_alu_is_last_to_lsu)
    );

endmodule
