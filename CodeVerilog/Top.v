`timescale 1ns/1ns
`include "common.vh"

module Top (
    input  wire                         CLK,
    input  wire                         RST,
    
    input  wire                         start,
    
    output wire                         done,
    output wire signed [63:0]           pe_out,
    output wire                         pe_valid_out,
    output wire [`WORD_BITS_X2-1:0]     ldm_pp_data_out
);


    wire                                w_ctrl_en;
    wire                                w_ctrl_clear;
    wire                                w_phase_done;
    wire [`ALU_CFG_BITS-1:0]            w_ctrl_cfg_alu;
    wire [3:0]                          w_ctrl_phase;
    wire                                w_ctrl_is_last;
    
    wire                                w_ctrl_pp_sel;
    wire [`RRI_ADDR_BITS-1:0]           w_ctrl_pp_rd_addr; 
    
    wire                                w_ctrl_uni_we;
    wire [`RES_ADDR_BITS-1:0]           w_ctrl_uni_addr_a;
    wire [`RES_ADDR_BITS-1:0]           w_ctrl_uni_addr_b;
    
    wire [2:0]                          w_ctrl_perm_rd_addr;

    wire                                w_done_phase;
    wire [`WORD_BITS_X2-1:0]            w_ldm_pp_data_out;
    Controller u_controller (
        .CLK                (CLK),
        .RST                (RST),
        
        .ram_pp_N           (w_ldm_pp_data_out),
        .alu_valid          (pe_valid_out), 
        .start              (start),
        .phase_advance      (1'b1),
        .done_phase         (w_done_phase), 
        
        .done               (done),
        .phase_done         (w_phase_done),
        
        .ctrl_clear         (w_ctrl_clear),
        .ctrl_en            (w_ctrl_en),
        .ctrl_cfg_alu       (w_ctrl_cfg_alu),
        .ctrl_phase         (w_ctrl_phase),
        .ctrl_is_last       (w_ctrl_is_last),
        
        .ctrl_pp_sel        (w_ctrl_pp_sel),
        .ctrl_pp_rd_addr    (w_ctrl_pp_rd_addr),
        
        .ctrl_uni_we        (w_ctrl_uni_we),
        .ctrl_uni_addr_a    (w_ctrl_uni_addr_a),
        .ctrl_uni_addr_b    (w_ctrl_uni_addr_b),
        
        .ctrl_perm_rd_addr  (w_ctrl_perm_rd_addr)
    );

    PE u_pe (
        .CLK                (CLK),
        .RST                (RST),
        
        .ctrl_clear         (w_ctrl_clear),
        .ctrl_en            (w_ctrl_en),
        .ctrl_cfg_alu       (w_ctrl_cfg_alu),
        .ctrl_phase         (w_ctrl_phase),
        .ctrl_is_last       (w_ctrl_is_last),
        
        .ctrl_pp_sel        (w_ctrl_pp_sel),
        .ctrl_pp_rd_addr    (w_ctrl_pp_rd_addr),
        
        .ctrl_uni_we        (w_ctrl_uni_we),
        .ctrl_uni_addr_a    (w_ctrl_uni_addr_a),
        .ctrl_uni_addr_b    (w_ctrl_uni_addr_b),
        
        .ctrl_perm_rd_addr  (w_ctrl_perm_rd_addr),
        
        .pe_out             (pe_out),
        .pe_valid_out       (pe_valid_out),
        .done_phase         (w_done_phase),
        .ldm_pp_data_out    (w_ldm_pp_data_out)
    );

endmodule
