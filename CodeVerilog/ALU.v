`timescale 1ns/1ns
`include "common.vh"

module ALU
(
    input  wire                                 CLK,
    input  wire                                 RST, 
    
    input  wire                                 ctrl_en,
    input  wire                                 ctrl_clear,   
    input  wire [`ALU_CFG_BITS-1:0]             ctrl_cfg,     
    
    input  wire                                 s0_valid_in,
    input  wire signed [31:0]                   s0_in,
    input  wire                                 s1_valid_in,
    input  wire signed [31:0]                   s1_in,
    
    input  wire                                 is_last_in,

    output wire signed [63:0]                   d0_out,       
    output wire                                 valid_out,
    output wire                                 is_last_out
);

    wire signed [63:0]                  MULT_out_wr;
    wire                                MULT_valid_wr;

    wire signed [31:0]                  abs_S0;
    wire signed [31:0]                  add_wr;
    wire signed [31:0]                  sub_wr;
    wire signed [31:0]                  abs_cmp_wr;
    wire signed [31:0]                  sra_wr;    

    wire signed [63:0]                  mac_next;
    wire signed [63:0]                  acc_next;

    reg signed [31:0]                   op_st1, op_st2, op_st3, op_st4, op_st5, op_st6;
    reg                                 val_st1, val_st2, val_st3, val_st4, val_st5, val_st6; 

    reg                                 last_st1, last_st2, last_st3, last_st4, last_st5, last_st6;

    reg signed [31:0]                   acc_s0_st1, acc_s0_st2, acc_s0_st3, acc_s0_st4, acc_s0_st5, acc_s0_st6;
    reg                                 acc_val_st1, acc_val_st2, acc_val_st3, acc_val_st4, acc_val_st5, acc_val_st6;

    reg signed [63:0]                   mac_accum; 
    reg signed [63:0]                   acc_accum; 

    reg [`ALU_CFG_BITS-1:0]             cfg_st1, cfg_st2, cfg_st3, cfg_st4, cfg_st5, cfg_st6;
    reg                                 en_st1,  en_st2,  en_st3,  en_st4,  en_st5,  en_st6;

    reg signed [63:0]                   d0_mux;
    reg                                 valid_mux;

    assign abs_S0     = (s0_in < 0) ? -s0_in : s0_in;
    assign add_wr     = s0_in + s1_in;
    assign sub_wr     = s0_in - s1_in;
    assign abs_cmp_wr = (abs_S0 > s1_in) ? 32'sd1 : 32'sd0;
    assign sra_wr     = s0_in >>> s1_in; 
    assign mac_next   = mac_accum + MULT_out_wr;
    assign acc_next   = acc_accum + { {32{acc_s0_st6[31]}}, acc_s0_st6 }; 

    MULT mult (
        .CLK(CLK),
        .RST(RST), 
        .ctrl_clear(ctrl_clear),
        .ctrl_en(ctrl_en),
        .S0_valid_in(s0_valid_in & ((ctrl_cfg == `EXE_MULT) || (ctrl_cfg == `EXE_MAC))), 
        .S0_in(s0_in),
        .S1_valid_in(s1_valid_in & ((ctrl_cfg == `EXE_MULT) || (ctrl_cfg == `EXE_MAC))), 
        .S1_in(s1_in),
        .D0_valid(MULT_valid_wr),
        .D0_out(MULT_out_wr) 
    );

    always @(posedge CLK or posedge RST) begin
        if (RST) begin 
            mac_accum   <= 0;  acc_accum   <= 0;
            op_st1      <= 0; op_st2 <= 0; op_st3 <= 0; op_st4 <= 0; op_st5 <= 0; op_st6 <= 0;
            val_st1     <= 0; val_st2 <= 0; val_st3 <= 0; val_st4 <= 0; val_st5 <= 0; val_st6 <= 0;
            last_st1    <= 0; last_st2 <= 0; last_st3 <= 0; last_st4 <= 0; last_st5 <= 0; last_st6 <= 0;
            cfg_st1     <= 0; cfg_st2 <= 0; cfg_st3 <= 0; cfg_st4 <= 0; cfg_st5 <= 0; cfg_st6 <= 0;
            en_st1      <= 0; en_st2  <= 0; en_st3  <= 0; en_st4  <= 0; en_st5  <= 0; en_st6  <= 0;
            acc_s0_st1  <= 0; acc_s0_st2 <= 0; acc_s0_st3 <= 0; acc_s0_st4 <= 0; acc_s0_st5 <= 0; acc_s0_st6 <= 0;
            acc_val_st1 <= 0; acc_val_st2 <= 0; acc_val_st3 <= 0; acc_val_st4 <= 0; acc_val_st5 <= 0; acc_val_st6 <= 0;
        end 
        else begin
            if (ctrl_clear) begin
                mac_accum   <= 0; acc_accum   <= 0;
                op_st1      <= 0; op_st2 <= 0; op_st3 <= 0; op_st4 <= 0; op_st5 <= 0; op_st6 <= 0;
                val_st1     <= 0; val_st2 <= 0; val_st3 <= 0; val_st4 <= 0; val_st5 <= 0; val_st6 <= 0;
                last_st1    <= 0; last_st2 <= 0; last_st3 <= 0; last_st4 <= 0; last_st5 <= 0; last_st6 <= 0;
                cfg_st1     <= 0; cfg_st2 <= 0; cfg_st3 <= 0; cfg_st4 <= 0; cfg_st5 <= 0; cfg_st6 <= 0;
                en_st1      <= 0; en_st2  <= 0; en_st3  <= 0; en_st4  <= 0; en_st5  <= 0; en_st6  <= 0;
                acc_s0_st1  <= 0; acc_s0_st2 <= 0; acc_s0_st3 <= 0; acc_s0_st4 <= 0; acc_s0_st5 <= 0; acc_s0_st6 <= 0;
                acc_val_st1 <= 0; acc_val_st2 <= 0; acc_val_st3 <= 0; acc_val_st4 <= 0; acc_val_st5 <= 0; acc_val_st6 <= 0;
            end 
            else if (ctrl_en) begin
                cfg_st1 <= ctrl_cfg; cfg_st2 <= cfg_st1; cfg_st3 <= cfg_st2; cfg_st4 <= cfg_st3; cfg_st5 <= cfg_st4; cfg_st6 <= cfg_st5;
                en_st1  <= ctrl_en;  en_st2  <= en_st1;  en_st3  <= en_st2;  en_st4  <= en_st3;  en_st5  <= en_st4;  en_st6  <= en_st5;
                
                // Dịch cờ is_last
                last_st1 <= is_last_in;
                last_st2 <= last_st1; last_st3 <= last_st2; last_st4 <= last_st3; last_st5 <= last_st4; last_st6 <= last_st5;
                
                if ((ctrl_cfg == `EXE_ADD) || (ctrl_cfg == `EXE_SUB) || (ctrl_cfg == `EXE_ABS_CMP) || (ctrl_cfg == `EXE_SRA)) begin
                    val_st1 <= s0_valid_in & s1_valid_in;
                end else begin
                    val_st1 <= 1'b0; 
                end

                case (ctrl_cfg)
                    `EXE_ADD:     op_st1 <= add_wr;
                    `EXE_SUB:     op_st1 <= sub_wr;
                    `EXE_ABS_CMP: op_st1 <= abs_cmp_wr;
                    `EXE_SRA:     op_st1 <= sra_wr;
                    default:      op_st1 <= 32'sd0;
                endcase

                op_st2 <= op_st1; op_st3 <= op_st2; op_st4 <= op_st3; op_st5 <= op_st4; op_st6 <= op_st5;
                val_st2 <= val_st1; val_st3 <= val_st2; val_st4 <= val_st3; val_st5 <= val_st4; val_st6 <= val_st5;
                
                acc_s0_st1  <= s0_in;      acc_s0_st2  <= acc_s0_st1;  acc_s0_st3  <= acc_s0_st2;  acc_s0_st4  <= acc_s0_st3;  acc_s0_st5  <= acc_s0_st4;  acc_s0_st6  <= acc_s0_st5;
                acc_val_st1 <= s0_valid_in & (ctrl_cfg == `EXE_ACC);
                acc_val_st2 <= acc_val_st1; acc_val_st3 <= acc_val_st2; acc_val_st4 <= acc_val_st3; acc_val_st5 <= acc_val_st4; acc_val_st6 <= acc_val_st5;

                if ((cfg_st6 == `EXE_MAC) && MULT_valid_wr) begin
                    if (last_st6) mac_accum <= 64'd0;      
                    else          mac_accum <= mac_next;    
                end                
                if (acc_val_st6) begin
                    if (last_st6) acc_accum <= 64'd0;       
                    else          acc_accum <= acc_next; 
                end
            end
        end
    end 
    wire mac_finish = (cfg_st6 == `EXE_MAC) && MULT_valid_wr && last_st6;
    wire acc_finish = acc_val_st6 && last_st6;

    always @(*) begin
        d0_mux    = 64'd0;
        valid_mux = 1'b0;
        if (mac_finish) begin
            d0_mux    = mac_next; 
            valid_mux = 1'b1;
        end
        else if (acc_finish) begin
            d0_mux    = acc_next; 
            valid_mux = 1'b1;
        end
        else begin
            case (cfg_st6)
                `EXE_NOP: begin
                    d0_mux    = 64'd0;
                    valid_mux = 1'b0;
                end
                `EXE_MULT: begin
                    d0_mux    = MULT_out_wr;
                    valid_mux = MULT_valid_wr;
                end
                `EXE_MAC: begin
                    d0_mux    = 64'd0;     
                    valid_mux = 1'b0;
                end
                `EXE_ACC: begin
                    d0_mux    = 64'd0;     
                    valid_mux = 1'b0;
                end
                `EXE_ADD, `EXE_SUB, `EXE_ABS_CMP, `EXE_SRA: begin
                    d0_mux    = { {32{op_st6[31]}}, op_st6 };
                    valid_mux = val_st6;
                end
                default: begin
                    d0_mux    = 64'd0;
                    valid_mux = 1'b0;
                end
            endcase
        end
    end

    assign d0_out      = (en_st6 == 1'b1) ? d0_mux    : 64'd0;
    assign valid_out   = (en_st6 == 1'b1) ? valid_mux : 1'b0;
    assign is_last_out = valid_out & last_st6;

endmodule
