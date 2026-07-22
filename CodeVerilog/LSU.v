`timescale 1ns/1ns
`include "common.vh"

module LSU (
    input  wire                                 CLK,
    input  wire                                 RST,
    input  wire                                 ctrl_clear,
    input  wire                                 ctrl_en,            
     
    input  wire [3:0]                           ctrl_phase,      
    input  wire                                 ctrl_is_last,     

    input  wire signed [`WORD_BITS_X2-1:0]      ldm_pp_data_in, 
    input  wire signed [15:0]                   ldm_perm_rd_data_in,     
    input  wire signed [`WORD_BITS_X2-1:0]      ldm_uni_data_a_in,   
    input  wire signed [`WORD_BITS_X2-1:0]      ldm_uni_data_b_in,   
    input  wire signed [15:0]                   ldm_nn50_in,
        
    input  wire signed [`WORD_BITS_X2-1:0]      lut_inv_in,        
    input  wire signed [`WORD_BITS_X2-1:0]      lut_log2_in,      
    input  wire signed [`WORD_BITS_X2-1:0]      lut_xlog2x_in, 
          
    input  wire signed [63:0]                   alu_d0_in,        
    input  wire                                 alu_valid_in,
    input  wire                                 alu_is_last_in,
      
    output wire [`WORD_BITS_X2-1:0]             lsu_x_out, 
    output wire signed [`WORD_BITS_X2-1:0]      lsu_uni_data_out, 
    
    output reg                                  lsu_s0_valid_out,     
    output reg  signed [`WORD_BITS_X2-1:0]      lsu_s0_out, 
          
    output reg                                  lsu_s1_valid_out,     
    output reg  signed [`WORD_BITS_X2-1:0]      lsu_s1_out,
    
    output reg                                  lsu_is_last_out,  
    output wire                                 lsu_nn50_inc,        
    output wire                                 lsu_perm_inc,        
    output wire [2:0]                           lsu_perm_code_out,   
    output wire                                 done_phase         
);
    reg signed [`WORD_BITS_X2-1:0] ram_pp_reg;        
    reg signed [`WORD_BITS_X2-1:0] buffer_rri;    
    reg signed [`WORD_BITS_X2-1:0] ram_uni_reg_a;   
    reg signed [`WORD_BITS_X2-1:0] ram_uni_reg_b;
    reg signed [15:0] ram_perm_rd_reg; 
    
    reg signed [`WORD_BITS_X2-1:0] buffer_uni_reg; 

    reg signed [`WORD_BITS_X2-1:0] lut_x_out_reg;
    reg signed [63:0]              buffer_alu;        
    reg signed [`WORD_BITS_X2-1:0] sliced_alu_to_ram;
    
    
    reg [6:0] pipe_sign_ba;
    reg [6:0] pipe_sign_cb;
    reg [3:0] pipe_phase [7:0];
    
    wire [3:0] delayed_phase = pipe_phase[6];
    wire [3:0] slice_phase   = pipe_phase[7]; 
    wire sign_ba_delayed = pipe_sign_ba[6];
    wire sign_cb_delayed = pipe_sign_cb[6];
    wire sign_ca         = alu_d0_in[`WORD_BITS_X2-1];

    assign done_phase = alu_valid_in & alu_is_last_in;
    assign lsu_perm_code_out = {sign_ba_delayed, sign_cb_delayed, sign_ca};
    assign lsu_x_out = lut_x_out_reg;
    assign lsu_uni_data_out = (ctrl_phase == 4'd9) ? {ldm_nn50_in, 16'b0} : sliced_alu_to_ram;
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            pipe_phase[0] <= 4'd0; pipe_phase[1] <= 4'd0; pipe_phase[2] <= 4'd0;
            pipe_phase[3] <= 4'd0; pipe_phase[4] <= 4'd0; pipe_phase[5] <= 4'd0;
            pipe_phase[6] <= 4'd0; pipe_phase[7] <= 4'd0;
        end else if (ctrl_clear) begin
            pipe_phase[0] <= 4'd0; pipe_phase[1] <= 4'd0; pipe_phase[2] <= 4'd0;
            pipe_phase[3] <= 4'd0; pipe_phase[4] <= 4'd0; pipe_phase[5] <= 4'd0;
            pipe_phase[6] <= 4'd0; pipe_phase[7] <= 4'd0;
        end else if (ctrl_en) begin
            pipe_phase[0] <= ctrl_phase;
            pipe_phase[1] <= pipe_phase[0];
            pipe_phase[2] <= pipe_phase[1];
            pipe_phase[3] <= pipe_phase[2];
            pipe_phase[4] <= pipe_phase[3];
            pipe_phase[5] <= pipe_phase[4];
            pipe_phase[6] <= pipe_phase[5];
            pipe_phase[7] <= pipe_phase[6];
        end
    end
    
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            pipe_sign_ba <= 7'b0;
            pipe_sign_cb <= 7'b0;
        end else if (ctrl_clear) begin
            pipe_sign_ba <= 7'b0;
            pipe_sign_cb <= 7'b0;
        end else if (ctrl_en) begin 
            pipe_sign_ba <= {pipe_sign_ba[5:0], buffer_uni_reg [`WORD_BITS_X2-1]}; 
            pipe_sign_cb <= {pipe_sign_cb[5:0], ram_uni_reg_b[`WORD_BITS_X2-1]};
        end
    end
    
    always @(*) begin
        case (ctrl_phase)
            4'd3:    lut_x_out_reg =  ram_pp_reg - 32'd1;  
            4'd6:    lut_x_out_reg = {16'b0, ram_perm_rd_reg };        
            4'd7:    lut_x_out_reg =  ram_pp_reg - 32'd2;
            4'd8:    lut_x_out_reg =  ram_pp_reg - 32'd2;                
            default: lut_x_out_reg = {`WORD_BITS_X2{1'b0}};
        endcase
    end
    
    always @(*) begin
        case (slice_phase)
            4'd3, 4'd7, 4'd10: begin 
                sliced_alu_to_ram = buffer_alu[47:16]; 
            end
            default: begin
                sliced_alu_to_ram = buffer_alu[31:0];
            end
        endcase
    end 

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            ram_pp_reg     <= 0;
            ram_uni_reg_a  <= 0;
            ram_uni_reg_b  <= 0;
            buffer_uni_reg <= 0;
            ram_perm_rd_reg <= 0; 
            buffer_rri     <= 0;
        end else if (ctrl_clear) begin
            ram_pp_reg     <= 0;
            ram_uni_reg_a  <= 0;
            ram_uni_reg_b  <= 0;
            buffer_uni_reg <= 0;
            ram_perm_rd_reg <= 0;
            buffer_rri     <= 0;
        end else if (ctrl_en) begin
            ram_pp_reg     <= ldm_pp_data_in;
            ram_uni_reg_a  <= ldm_uni_data_a_in;
            ram_uni_reg_b  <= ldm_uni_data_b_in;
            ram_perm_rd_reg <= ldm_perm_rd_data_in;
            buffer_rri <= ram_pp_reg; 
            buffer_uni_reg <= ram_uni_reg_b; 
        end
    end
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            lsu_s0_out       <= 0;
            lsu_s0_valid_out <= 1'b0;
            lsu_is_last_out  <= 1'b0; 
        end else if (ctrl_clear) begin
            lsu_s0_out       <= 0;
            lsu_s0_valid_out <= 1'b0;
            lsu_is_last_out  <= 1'b0;
        end else if (ctrl_en) begin
            lsu_s0_valid_out <= 1'b1; 
            lsu_is_last_out  <= ctrl_is_last; 
            case (ctrl_phase)
                4'd1:    lsu_s0_out <= ram_pp_reg;          
                4'd2:    lsu_s0_out <= ram_uni_reg_b;  
                4'd3:    lsu_s0_out <= buffer_alu[47:16];  
                4'd4:    lsu_s0_out <= ram_uni_reg_b;  
                4'd5:    lsu_s0_out <= buffer_uni_reg;  
                
                4'd6:    lsu_s0_out <= lut_xlog2x_in;  
                4'd7:    lsu_s0_out <= buffer_alu[31:0];  
                4'd8:    lsu_s0_out <= lut_log2_in;    
                
                4'd10:   lsu_s0_out <= ram_uni_reg_a; 
                default: begin
                    lsu_s0_out       <= 0;
                    lsu_s0_valid_out <= 1'b0;
                end
            endcase
        end
    end

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            lsu_s1_out       <= 0;
            lsu_s1_valid_out <= 1'b0;
        end else if (ctrl_clear) begin
            lsu_s1_out       <= 0;
            lsu_s1_valid_out <= 1'b0;
        end else if (ctrl_en) begin
            lsu_s1_valid_out <= 1'b1;
            case (ctrl_phase)
                4'd1:    lsu_s1_out <= buffer_rri; 
                4'd2:    lsu_s1_out <= ram_uni_reg_b;  
                4'd3:    lsu_s1_out <= lut_inv_in;     
                4'd4:    lsu_s1_out <= 32'sd3277;  
                4'd5:    lsu_s1_out <= ram_uni_reg_b;  
                4'd6:    lsu_s1_out <= 32'sd0;  
                4'd7:    lsu_s1_out <= lut_inv_in;     
                4'd8:    lsu_s1_out <= buffer_alu[47:16];  
                4'd10:   lsu_s1_out <= ram_uni_reg_b;
                default: begin
                    lsu_s1_out       <= 0;
                    lsu_s1_valid_out <= 1'b0;
                end
            endcase
        end
    end

    assign lsu_nn50_inc     = ctrl_en && (delayed_phase == 4'd4 && alu_valid_in && alu_d0_in[0] == 1'b1);
    assign lsu_perm_inc     = ctrl_en && (delayed_phase == 4'd5 && alu_valid_in);
    
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            buffer_alu <= 64'd0;
        end else if (ctrl_clear) begin
            buffer_alu <= 64'd0;
        end else if (ctrl_en && alu_valid_in) begin
            buffer_alu <= alu_d0_in;
        end
    end

endmodule
