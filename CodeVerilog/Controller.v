`timescale 1ns/1ns
`include "common.vh"

module Controller (
    input  wire CLK,
    input  wire RST,
    
    input  wire [31:0] ram_pp_N,
    input  wire alu_valid,
    input  wire start, 
    input  wire phase_advance,
    input  wire done_phase,   
             
    output reg  done,
    output reg  phase_done,
    

    output reg  ctrl_clear,
    output reg  ctrl_en,
    output reg  [`ALU_CFG_BITS-1:0] ctrl_cfg_alu,
    output reg  [3:0] ctrl_phase,
    output reg  ctrl_is_last,
    
    output reg  ctrl_pp_sel,    
    output reg  [`RRI_ADDR_BITS-1:0] ctrl_pp_rd_addr,
        
    output reg  ctrl_uni_we,        
    output reg  [`RES_ADDR_BITS-1:0] ctrl_uni_addr_a,  
    output reg  [`RES_ADDR_BITS-1:0] ctrl_uni_addr_b, 
        
    output reg  [2:0] ctrl_perm_rd_addr  
);

    reg [31:0] N;
    reg [31:0] counter;
    reg        alu_valid_q;
    reg        done_phase_q;
    
    reg        allow_ram_write; 

    reg        load_new_write_addr;
    reg [`RES_ADDR_BITS-1:0] fsm_base_write_addr;

    localparam STATE_IDLE   = 5'd0;
    localparam STATE_1      = 5'd1;
    localparam STATE_2      = 5'd2;
    localparam STATE_3      = 5'd3;
    localparam STATE_4      = 5'd4;
    localparam STATE_5      = 5'd5;
    localparam STATE_6      = 5'd6;
    localparam STATE_7      = 5'd7;
    localparam STATE_8      = 5'd8;
    localparam STATE_9      = 5'd9;
    localparam STATE_10     = 5'd10;
    localparam STATE_DONE   = 5'd11;
    localparam STATE_WAIT_N = 5'd12; 
    localparam STATE_PRE_1a  = 5'd13;
    localparam STATE_PRE_1b  = 5'd14;  
    localparam STATE_INIT   = 5'd15;
    localparam STATE_PRE_2a  = 5'd16;
    localparam STATE_PRE_2b  = 5'd17;
    localparam STATE_PRE_3a  = 5'd18;
    localparam STATE_PRE_3b  = 5'd19;
    localparam STATE_PRE_4a  = 5'd20;
    localparam STATE_PRE_4b  = 5'd21;
    localparam STATE_PRE_5a  = 5'd22; 
    localparam STATE_PRE_5b  = 5'd23;
    localparam STATE_PRE_5c  = 5'd24;
    localparam STATE_PRE_6a  = 5'd25;
    localparam STATE_PRE_6b  = 5'd26;
    localparam STATE_PRE_9  =  5'd27; 
    localparam STATE_PRE_10a = 5'd28;
    localparam STATE_PRE_10b = 5'd29;
    localparam STATE_PRE_10c = 5'd30;

    reg [4:0] current_state, next_state;
    

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

always @(*) begin
        next_state = current_state;
        case (current_state)
            STATE_IDLE:   if (start)      next_state = STATE_WAIT_N;
            STATE_WAIT_N:                 next_state = STATE_INIT;            
            STATE_INIT:                   next_state = STATE_PRE_1a;
            STATE_PRE_1a:                 next_state = STATE_PRE_1b;
            STATE_PRE_1b:                 next_state = STATE_1;            
            STATE_1:      if (phase_done && phase_advance) next_state = STATE_PRE_2a;
            STATE_PRE_2a:                 next_state = STATE_PRE_2b;
            STATE_PRE_2b:                 next_state = STATE_2;
            STATE_2:      if (phase_done && phase_advance) next_state = STATE_PRE_3a;
            STATE_PRE_3a:                 next_state = STATE_PRE_3b;
            STATE_PRE_3b:                 next_state = STATE_3;
            STATE_3:      if (phase_done && phase_advance) next_state = STATE_PRE_4a;
            STATE_PRE_4a:                 next_state = STATE_PRE_4b;
            STATE_PRE_4b:                 next_state = STATE_4;
            STATE_4:      if (phase_done && phase_advance) next_state = STATE_PRE_5a; 
            STATE_PRE_5a:                 next_state = STATE_PRE_5b; 
            STATE_PRE_5b:                 next_state = STATE_PRE_5c;
            STATE_PRE_5c:                 next_state = STATE_5;            
            STATE_5:      if (phase_done && phase_advance) next_state = STATE_PRE_6a;
            STATE_PRE_6a:                 next_state = STATE_PRE_6b; 
            STATE_PRE_6b:                 next_state = STATE_6;
            STATE_6:      if (phase_done && phase_advance) next_state = STATE_7;
            STATE_7:      if (phase_done && phase_advance) next_state = STATE_8;
            STATE_8:      if (phase_done && phase_advance) next_state = STATE_PRE_9;
            STATE_PRE_9:                  next_state = STATE_9;              
            STATE_9:      if (phase_done && phase_advance) next_state = STATE_PRE_10a;              
            STATE_PRE_10a:                next_state = STATE_PRE_10b;
            STATE_PRE_10b:                next_state = STATE_PRE_10c;  
            STATE_PRE_10c:                next_state = STATE_10;  
            STATE_10:     if (phase_done && phase_advance) next_state = STATE_IDLE;                
            default: next_state = STATE_IDLE;
        endcase
    end
            always @(posedge CLK or posedge RST) begin
                if (RST) begin
                    ctrl_uni_we     <= 1'b0;
                    ctrl_uni_addr_a <= 6'b0;
                    alu_valid_q     <= 1'b0;
                    done_phase_q    <= 1'b0;
                end else begin
                    alu_valid_q  <= alu_valid;
                    done_phase_q <= done_phase;
                    
                    if (phase_done) begin
                        ctrl_uni_we <= 1'b0;
                    end else begin
                        ctrl_uni_we  <= (alu_valid | (current_state == STATE_9)) & allow_ram_write; 
                        
                        if (current_state == STATE_PRE_10a) begin
                            ctrl_uni_addr_a <= 6'd40;
                        end
                        else if (current_state == STATE_PRE_10b) begin
                            ctrl_uni_addr_a <= 6'd43;
                        end
                        else if (current_state == STATE_PRE_10c) begin
                            ctrl_uni_addr_a <= 6'd41;
                        end
                        else if (current_state == STATE_10) begin
                            ctrl_uni_addr_a <= 6'd42;
                        end
                        else if (load_new_write_addr) begin
                            ctrl_uni_addr_a <= fsm_base_write_addr;
                        end 
                        else if (alu_valid_q && allow_ram_write ) begin
                            ctrl_uni_addr_a <= ctrl_uni_addr_a + 1'b1;
                        end
                    end
                end
            end 

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            done              <= 1'b0;
            phase_done        <= 1'b0;
            ctrl_clear        <= 1'b0;
            ctrl_en           <= 1'b0;
            ctrl_cfg_alu      <= `EXE_NOP; 
            ctrl_phase        <= 4'd0;
            ctrl_is_last      <= 1'b0;
            ctrl_pp_sel       <= 1'b0;
            ctrl_pp_rd_addr   <= 0;
            ctrl_uni_addr_b   <= 0; 
            ctrl_perm_rd_addr <= 3'd0;
            N                 <= 32'b0;
            counter           <= 32'b0;
            
            load_new_write_addr     <= 1'b0;
            fsm_base_write_addr     <= 6'd0;
            allow_ram_write   <= 1'b0; 
        end else begin
            ctrl_clear <= 1'b0;

            if (phase_done) begin
                if (phase_advance) begin
                    phase_done <= 1'b0;
                end
            end else begin
            case (current_state)
                    STATE_IDLE: begin
                        ctrl_phase      <= 4'd0;
                        allow_ram_write <= 1'b0;
                        ctrl_en         <= 1'b0;
                        ctrl_cfg_alu    <= `EXE_NOP;
                        ctrl_is_last    <= 1'b0;
                        if (start) begin
                            done            <= 1'b0;
                            phase_done      <= 1'b0;
                            ctrl_clear      <= 1'b1;
                            ctrl_pp_sel     <= 1'b1;
                            ctrl_pp_rd_addr <= 6'd0;
                        end
                    end
                    STATE_WAIT_N: begin 
                        ctrl_clear      <= 1'b1;
                        ctrl_pp_rd_addr <= 6'd1;
                    end
                    STATE_INIT: begin
                        ctrl_phase      <= 4'd0;
                        N               <= ram_pp_N;
                        counter         <= ram_pp_N;
                        ctrl_pp_rd_addr <= 6'd2;
                        ctrl_en         <= 1'b1;                                      
                    end  
                    STATE_PRE_1a: begin
                        load_new_write_addr <= 1'b1;
                        fsm_base_write_addr <= 6'd0;
                        ctrl_pp_rd_addr <= 6'd3;    
                    end
                    STATE_PRE_1b: begin
                        ctrl_pp_rd_addr <= 6'd4;    
                        allow_ram_write <= 1'b1;
                        load_new_write_addr <= 1'b0;
                        ctrl_phase      <= 4'd1;
                        ctrl_cfg_alu    <= `EXE_SUB;
                    end
                    STATE_1: begin
                    if (done_phase) begin
                            phase_done <= 1'b1;
                            end
                    if (counter == 0) begin
                            ctrl_phase <= 4'd0;
                            end  
                        else if (counter > 0) begin
                            ctrl_pp_rd_addr <= ctrl_pp_rd_addr + 1'b1; 
                            counter         <= counter - 1'b1;
                        end
                        ctrl_is_last <= (counter == 1) ? 1'b1 : 1'b0;
                    end
                    STATE_PRE_2a: begin 
                    counter         <= N - 31'd2; 
                    ctrl_uni_addr_b <= 6'd1;
                    end
                    STATE_PRE_2b: begin
                        ctrl_phase      <= 4'd2;
                        ctrl_cfg_alu    <= `EXE_MAC;
                        ctrl_uni_addr_b <= 6'd2;
                        allow_ram_write <= 1'b0;                
                    end
                    STATE_2: begin
                    if (done_phase) begin
                           phase_done <= 1'b1;
                           end
                    if (counter == 0) begin
                           ctrl_phase <= 4'd0;
                           end          
                      else if (counter > 0) begin
                            ctrl_uni_addr_b <= ctrl_uni_addr_b + 1'b1; 
                            counter         <= counter - 1'b1;
                        end
                        ctrl_is_last <= (counter == 1) ? 1'b1 : 1'b0;
                    end
                    STATE_PRE_3a: begin
                        load_new_write_addr <= 1'b1;
                        fsm_base_write_addr <= 6'd40; 
                        ctrl_pp_rd_addr <= 6'd0;
                    end
                    STATE_PRE_3b: begin
                        allow_ram_write <= 1'b1;
                        load_new_write_addr <= 1'b0;                
                        counter         <= 31'd1;        
                    end                
                    STATE_3: begin 
                    if (done_phase) begin
                            phase_done <= 1'b1;
                            end
                    if (counter == 0) begin
                            ctrl_phase   <= 4'd0;
                            ctrl_uni_addr_b <= 6'd0;
                            end 
                                            
                       else if (counter > 0) begin
                            ctrl_phase      <= 4'd3;
                            ctrl_cfg_alu    <= `EXE_MULT;
                            counter         <= counter - 1'b1;
                        end
                        ctrl_is_last <= (counter == 1) ? 1'b1 : 1'b0;
                    end 
                    STATE_PRE_4a: begin 
                    counter         <= N - 31'd2; 
                    ctrl_uni_addr_b <= 6'd1;
                    end
                    STATE_PRE_4b: begin
                        ctrl_phase      <= 4'd4;
                        ctrl_cfg_alu    <= `EXE_ABS_CMP;
                        ctrl_uni_addr_b <= 6'd2;
                        allow_ram_write <= 1'b0;                
                    end
                    STATE_4: begin
                    if (done_phase) begin
                           phase_done <= 1'b1;
                           end
                    if (counter == 0) begin
                           ctrl_phase <= 4'd0;
                           ctrl_uni_addr_b <= 6'd0;
                           end          
                      else if (counter > 0) begin
                            ctrl_uni_addr_b <= ctrl_uni_addr_b + 1'b1; 
                            counter         <= counter - 1'b1;
                        end
                        ctrl_is_last <= (counter == 1) ? 1'b1 : 1'b0;
                    end
                 STATE_PRE_5a: begin
                 ctrl_uni_addr_b <= 6'd1;
                 end                   
                 STATE_PRE_5b: begin
                    ctrl_uni_addr_b <= 6'd2; 
                    counter         <= N - 31'd1; 
                end
                STATE_PRE_5c: begin
                    ctrl_uni_addr_b <= 6'd3; 
                    ctrl_phase      <= 4'd5;
                    allow_ram_write <= 1'b0;
                end
                STATE_5: begin
                    if (done_phase) begin
                        phase_done <= 1'b1;
                    end
                    ctrl_cfg_alu    <= `EXE_ADD;         
                    if (counter == 0) begin
                        ctrl_phase <= 4'd0; 
                    end                    
                    else if (counter > 0) begin
                        ctrl_uni_addr_b <= ctrl_uni_addr_b + 1'b1; 
                        counter         <= counter - 1'b1;
                    end
                    ctrl_is_last <= (counter == 1) ? 1'b1 : 1'b0;
                end             
                STATE_PRE_6a: begin 
                    ctrl_perm_rd_addr <= 3'd1; 
                    counter           <= 32'd6; 
                    allow_ram_write   <= 1'b0;
                end
                STATE_PRE_6b: begin
                    ctrl_phase        <= 4'd6;
                    ctrl_cfg_alu      <= `EXE_ACC;
                    ctrl_perm_rd_addr <= 3'd2; 
                end
                STATE_6: begin  
                    if (done_phase) begin
                        phase_done <= 1'b1;
                        ctrl_phase <= 4'd0;
                        counter         <= 31'd1;  
                    end
                    else if (counter > 0) begin
                        ctrl_perm_rd_addr <= ctrl_perm_rd_addr + 1'b1;
                        counter           <= counter - 1'b1;
                    end
                  ctrl_is_last <= (counter == 1) ? 1'b1 : 1'b0; 
                end
                STATE_7: begin  
                    if (done_phase) begin
                    phase_done <= 1'b1;
                    ctrl_phase <= 4'd0;
                    counter         <= 31'd1; 
                    end
                    else if (counter > 0) begin
                        ctrl_phase      <= 4'd7;
                        ctrl_cfg_alu    <= `EXE_MULT;
                        counter         <= counter - 1'b1;
                    end
                    else begin ctrl_phase <= 4'd0;
                    end
                    ctrl_is_last <= (counter == 1) ? 1'b1 : 1'b0; 
                end
                STATE_8: begin  
                    if (done_phase) begin
                        phase_done <= 1'b1;
                        ctrl_phase      <= 4'd0;
                        allow_ram_write <= 1'b0; 
                    end
                    else if (counter > 0) begin
                        ctrl_phase      <= 4'd8;
                        ctrl_cfg_alu    <= `EXE_SUB;
                        counter         <= counter - 1'b1;
                        load_new_write_addr <= 1'b1;
                        fsm_base_write_addr <= 6'd41;
                        allow_ram_write     <= 1'b1; 
                    end
                    else begin 
                        ctrl_phase          <= 4'd0;
                        load_new_write_addr <= 1'b0; 
                    end
                    ctrl_is_last <= (counter == 1) ? 1'b1 : 1'b0; 
                end 
              STATE_PRE_9: begin
                    load_new_write_addr <= 1'b1;
                    fsm_base_write_addr <= 6'd43;
                    allow_ram_write     <= 1'b1; 
                    ctrl_phase          <= 4'd9; 

                end
                STATE_9: begin  
                    if (!phase_done) begin
                        phase_done <= 1'b1;
                    end
                    load_new_write_addr <= 1'b0; 
                    allow_ram_write     <= 1'b0; 
                end
                   STATE_PRE_10a: begin
                        ctrl_uni_addr_b <= 6'd44;
                        allow_ram_write <= 1'b0;
                    end
                    STATE_PRE_10b: begin
                        ctrl_uni_addr_b <= 6'd45;
                    end
                    STATE_PRE_10c: begin
                        ctrl_uni_addr_b <= 6'd46;
                        ctrl_phase      <= 4'd10; 
                        ctrl_cfg_alu    <= `EXE_MAC;
                        counter         <= 32'd3; 
                    end
                    STATE_10: begin  
                        if (done_phase) begin
                            phase_done <= 1'b1;
                            done       <= 1'b1;
                        end
                        if (counter > 0) begin
                            ctrl_uni_addr_b <= 6'd47; 
                            counter         <= counter - 1'b1;
                        end
                        ctrl_is_last <= (counter == 1) ? 1'b1 : 1'b0; 
                        if (done_phase) begin
                            ctrl_phase <= 4'd0;
                        end
                    end                                    
            endcase
            end
        end
    end

endmodule
