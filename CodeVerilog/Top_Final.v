`timescale 1ns/1ns
`include "common.vh"

module Controller_Final (
    input  wire        CLK,
    input  wire        RST,
    input  wire        start,

    input  wire [11:0] lane_done,
    input  wire [11:0] lane_phase_done,

    output reg  [11:0] lane_start,
    output wire        phase_advance,
    output reg         busy,
    output reg         done
);

    wire all_phase_done;
    wire all_lane_done;
    wire any_lane_done;

    localparam FINAL_IDLE       = 2'd0;
    localparam FINAL_START      = 2'd1;
    localparam FINAL_WAIT_CLEAR = 2'd2;
    localparam FINAL_RUN        = 2'd3;

    reg [1:0] current_state;

    assign all_phase_done = lane_phase_done[0]  & lane_phase_done[1]  &
                            lane_phase_done[2]  & lane_phase_done[3]  &
                            lane_phase_done[4]  & lane_phase_done[5]  &
                            lane_phase_done[6]  & lane_phase_done[7]  &
                            lane_phase_done[8]  & lane_phase_done[9]  &
                            lane_phase_done[10] & lane_phase_done[11];

    assign all_lane_done = lane_done[0]  & lane_done[1]  &
                           lane_done[2]  & lane_done[3]  &
                           lane_done[4]  & lane_done[5]  &
                           lane_done[6]  & lane_done[7]  &
                           lane_done[8]  & lane_done[9]  &
                           lane_done[10] & lane_done[11];

    assign any_lane_done = lane_done[0]  | lane_done[1]  |
                           lane_done[2]  | lane_done[3]  |
                           lane_done[4]  | lane_done[5]  |
                           lane_done[6]  | lane_done[7]  |
                           lane_done[8]  | lane_done[9]  |
                           lane_done[10] | lane_done[11];

    assign phase_advance = (current_state == FINAL_RUN) & all_phase_done;

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            lane_start <= 12'b0;
            busy       <= 1'b0;
            done       <= 1'b0;
            current_state <= FINAL_IDLE;
        end else begin
            lane_start <= 12'b0;
            case (current_state)
                FINAL_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        lane_start    <= 12'b1111_1111_1111;
                        busy          <= 1'b1;
                        done          <= 1'b0;
                        current_state <= FINAL_START;
                    end
                end

                FINAL_START: begin
                    busy          <= 1'b1;
                    current_state <= FINAL_WAIT_CLEAR;
                end

                FINAL_WAIT_CLEAR: begin
                    busy <= 1'b1;
                    if (!any_lane_done) begin
                        current_state <= FINAL_RUN;
                    end
                end

                FINAL_RUN: begin
                    busy <= 1'b1;
                    if (all_lane_done) begin
                        busy          <= 1'b0;
                        done          <= 1'b1;
                        current_state <= FINAL_IDLE;
                    end
                end

                default: begin
                    lane_start    <= 12'b0;
                    busy          <= 1'b0;
                    done          <= 1'b0;
                    current_state <= FINAL_IDLE;
                end
            endcase
        end
    end

endmodule

module Top_Final (
    input  wire                       CLK,
    input  wire                       RST,
    input  wire                       start,

    output wire                       done,
    output wire                       busy,
    output wire [11:0]                lane_done,
    output wire [11:0]                lane_phase_done,
    output wire [11:0]                pe_valid_out,

    output wire signed [63:0]         pe0_out,
    output wire signed [63:0]         pe1_out,
    output wire signed [63:0]         pe2_out,
    output wire signed [63:0]         pe3_out,
    output wire signed [63:0]         pe4_out,
    output wire signed [63:0]         pe5_out,
    output wire signed [63:0]         pe6_out,
    output wire signed [63:0]         pe7_out,
    output wire signed [63:0]         pe8_out,
    output wire signed [63:0]         pe9_out,
    output wire signed [63:0]         pe10_out,
    output wire signed [63:0]         pe11_out
);

    wire [11:0]                     w_lane_start;
    wire                            w_phase_advance;

    wire [11:0]                     w_ctrl_clear;
    wire [11:0]                     w_ctrl_en;
    wire [11:0]                     w_ctrl_is_last;
    wire [11:0]                     w_ctrl_pp_sel;
    wire [11:0]                     w_ctrl_uni_we;
    wire [11:0]                     w_done_phase;

    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu0;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu1;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu2;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu3;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu4;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu5;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu6;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu7;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu8;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu9;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu10;
    wire [`ALU_CFG_BITS-1:0]        w_ctrl_cfg_alu11;

    wire [3:0]                      w_ctrl_phase0;
    wire [3:0]                      w_ctrl_phase1;
    wire [3:0]                      w_ctrl_phase2;
    wire [3:0]                      w_ctrl_phase3;
    wire [3:0]                      w_ctrl_phase4;
    wire [3:0]                      w_ctrl_phase5;
    wire [3:0]                      w_ctrl_phase6;
    wire [3:0]                      w_ctrl_phase7;
    wire [3:0]                      w_ctrl_phase8;
    wire [3:0]                      w_ctrl_phase9;
    wire [3:0]                      w_ctrl_phase10;
    wire [3:0]                      w_ctrl_phase11;

    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr0;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr1;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr2;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr3;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr4;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr5;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr6;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr7;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr8;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr9;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr10;
    wire [`RRI_ADDR_BITS-1:0]       w_ctrl_pp_rd_addr11;

    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a0;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a1;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a2;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a3;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a4;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a5;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a6;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a7;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a8;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a9;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a10;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_a11;

    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b0;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b1;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b2;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b3;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b4;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b5;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b6;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b7;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b8;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b9;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b10;
    wire [`RES_ADDR_BITS-1:0]       w_ctrl_uni_addr_b11;

    wire [2:0]                      w_ctrl_perm_rd_addr0;
    wire [2:0]                      w_ctrl_perm_rd_addr1;
    wire [2:0]                      w_ctrl_perm_rd_addr2;
    wire [2:0]                      w_ctrl_perm_rd_addr3;
    wire [2:0]                      w_ctrl_perm_rd_addr4;
    wire [2:0]                      w_ctrl_perm_rd_addr5;
    wire [2:0]                      w_ctrl_perm_rd_addr6;
    wire [2:0]                      w_ctrl_perm_rd_addr7;
    wire [2:0]                      w_ctrl_perm_rd_addr8;
    wire [2:0]                      w_ctrl_perm_rd_addr9;
    wire [2:0]                      w_ctrl_perm_rd_addr10;
    wire [2:0]                      w_ctrl_perm_rd_addr11;

    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out0;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out1;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out2;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out3;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out4;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out5;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out6;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out7;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out8;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out9;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out10;
    wire [`WORD_BITS_X2-1:0]        w_ldm_pp_data_out11;

    Controller_Final u_controller_final (
        .CLK             (CLK),
        .RST             (RST),
        .start           (start),
        .lane_done       (lane_done),
        .lane_phase_done (lane_phase_done),
        .lane_start      (w_lane_start),
        .phase_advance   (w_phase_advance),
        .busy            (busy),
        .done            (done)
    );

    Controller u_controller0 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out0), .alu_valid(pe_valid_out[0]),
        .start(w_lane_start[0]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[0]),
        .done(lane_done[0]), .phase_done(lane_phase_done[0]), .ctrl_clear(w_ctrl_clear[0]),
        .ctrl_en(w_ctrl_en[0]), .ctrl_cfg_alu(w_ctrl_cfg_alu0), .ctrl_phase(w_ctrl_phase0),
        .ctrl_is_last(w_ctrl_is_last[0]), .ctrl_pp_sel(w_ctrl_pp_sel[0]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr0),
        .ctrl_uni_we(w_ctrl_uni_we[0]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a0), .ctrl_uni_addr_b(w_ctrl_uni_addr_b0),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr0)
    );
    PE u_pe0 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[0]), .ctrl_en(w_ctrl_en[0]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu0), .ctrl_phase(w_ctrl_phase0), .ctrl_is_last(w_ctrl_is_last[0]),
        .ctrl_pp_sel(w_ctrl_pp_sel[0]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr0),
        .ctrl_uni_we(w_ctrl_uni_we[0]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a0), .ctrl_uni_addr_b(w_ctrl_uni_addr_b0),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr0), .pe_out(pe0_out), .pe_valid_out(pe_valid_out[0]),
        .done_phase(w_done_phase[0]), .ldm_pp_data_out(w_ldm_pp_data_out0)
    );

    Controller u_controller1 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out1), .alu_valid(pe_valid_out[1]),
        .start(w_lane_start[1]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[1]),
        .done(lane_done[1]), .phase_done(lane_phase_done[1]), .ctrl_clear(w_ctrl_clear[1]),
        .ctrl_en(w_ctrl_en[1]), .ctrl_cfg_alu(w_ctrl_cfg_alu1), .ctrl_phase(w_ctrl_phase1),
        .ctrl_is_last(w_ctrl_is_last[1]), .ctrl_pp_sel(w_ctrl_pp_sel[1]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr1),
        .ctrl_uni_we(w_ctrl_uni_we[1]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a1), .ctrl_uni_addr_b(w_ctrl_uni_addr_b1),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr1)
    );
    PE u_pe1 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[1]), .ctrl_en(w_ctrl_en[1]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu1), .ctrl_phase(w_ctrl_phase1), .ctrl_is_last(w_ctrl_is_last[1]),
        .ctrl_pp_sel(w_ctrl_pp_sel[1]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr1),
        .ctrl_uni_we(w_ctrl_uni_we[1]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a1), .ctrl_uni_addr_b(w_ctrl_uni_addr_b1),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr1), .pe_out(pe1_out), .pe_valid_out(pe_valid_out[1]),
        .done_phase(w_done_phase[1]), .ldm_pp_data_out(w_ldm_pp_data_out1)
    );

    Controller u_controller2 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out2), .alu_valid(pe_valid_out[2]),
        .start(w_lane_start[2]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[2]),
        .done(lane_done[2]), .phase_done(lane_phase_done[2]), .ctrl_clear(w_ctrl_clear[2]),
        .ctrl_en(w_ctrl_en[2]), .ctrl_cfg_alu(w_ctrl_cfg_alu2), .ctrl_phase(w_ctrl_phase2),
        .ctrl_is_last(w_ctrl_is_last[2]), .ctrl_pp_sel(w_ctrl_pp_sel[2]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr2),
        .ctrl_uni_we(w_ctrl_uni_we[2]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a2), .ctrl_uni_addr_b(w_ctrl_uni_addr_b2),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr2)
    );
    PE u_pe2 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[2]), .ctrl_en(w_ctrl_en[2]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu2), .ctrl_phase(w_ctrl_phase2), .ctrl_is_last(w_ctrl_is_last[2]),
        .ctrl_pp_sel(w_ctrl_pp_sel[2]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr2),
        .ctrl_uni_we(w_ctrl_uni_we[2]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a2), .ctrl_uni_addr_b(w_ctrl_uni_addr_b2),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr2), .pe_out(pe2_out), .pe_valid_out(pe_valid_out[2]),
        .done_phase(w_done_phase[2]), .ldm_pp_data_out(w_ldm_pp_data_out2)
    );

    Controller u_controller3 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out3), .alu_valid(pe_valid_out[3]),
        .start(w_lane_start[3]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[3]),
        .done(lane_done[3]), .phase_done(lane_phase_done[3]), .ctrl_clear(w_ctrl_clear[3]),
        .ctrl_en(w_ctrl_en[3]), .ctrl_cfg_alu(w_ctrl_cfg_alu3), .ctrl_phase(w_ctrl_phase3),
        .ctrl_is_last(w_ctrl_is_last[3]), .ctrl_pp_sel(w_ctrl_pp_sel[3]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr3),
        .ctrl_uni_we(w_ctrl_uni_we[3]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a3), .ctrl_uni_addr_b(w_ctrl_uni_addr_b3),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr3)
    );
    PE u_pe3 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[3]), .ctrl_en(w_ctrl_en[3]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu3), .ctrl_phase(w_ctrl_phase3), .ctrl_is_last(w_ctrl_is_last[3]),
        .ctrl_pp_sel(w_ctrl_pp_sel[3]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr3),
        .ctrl_uni_we(w_ctrl_uni_we[3]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a3), .ctrl_uni_addr_b(w_ctrl_uni_addr_b3),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr3), .pe_out(pe3_out), .pe_valid_out(pe_valid_out[3]),
        .done_phase(w_done_phase[3]), .ldm_pp_data_out(w_ldm_pp_data_out3)
    );

    Controller u_controller4 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out4), .alu_valid(pe_valid_out[4]),
        .start(w_lane_start[4]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[4]),
        .done(lane_done[4]), .phase_done(lane_phase_done[4]), .ctrl_clear(w_ctrl_clear[4]),
        .ctrl_en(w_ctrl_en[4]), .ctrl_cfg_alu(w_ctrl_cfg_alu4), .ctrl_phase(w_ctrl_phase4),
        .ctrl_is_last(w_ctrl_is_last[4]), .ctrl_pp_sel(w_ctrl_pp_sel[4]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr4),
        .ctrl_uni_we(w_ctrl_uni_we[4]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a4), .ctrl_uni_addr_b(w_ctrl_uni_addr_b4),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr4)
    );
    PE u_pe4 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[4]), .ctrl_en(w_ctrl_en[4]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu4), .ctrl_phase(w_ctrl_phase4), .ctrl_is_last(w_ctrl_is_last[4]),
        .ctrl_pp_sel(w_ctrl_pp_sel[4]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr4),
        .ctrl_uni_we(w_ctrl_uni_we[4]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a4), .ctrl_uni_addr_b(w_ctrl_uni_addr_b4),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr4), .pe_out(pe4_out), .pe_valid_out(pe_valid_out[4]),
        .done_phase(w_done_phase[4]), .ldm_pp_data_out(w_ldm_pp_data_out4)
    );

    Controller u_controller5 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out5), .alu_valid(pe_valid_out[5]),
        .start(w_lane_start[5]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[5]),
        .done(lane_done[5]), .phase_done(lane_phase_done[5]), .ctrl_clear(w_ctrl_clear[5]),
        .ctrl_en(w_ctrl_en[5]), .ctrl_cfg_alu(w_ctrl_cfg_alu5), .ctrl_phase(w_ctrl_phase5),
        .ctrl_is_last(w_ctrl_is_last[5]), .ctrl_pp_sel(w_ctrl_pp_sel[5]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr5),
        .ctrl_uni_we(w_ctrl_uni_we[5]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a5), .ctrl_uni_addr_b(w_ctrl_uni_addr_b5),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr5)
    );
    PE u_pe5 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[5]), .ctrl_en(w_ctrl_en[5]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu5), .ctrl_phase(w_ctrl_phase5), .ctrl_is_last(w_ctrl_is_last[5]),
        .ctrl_pp_sel(w_ctrl_pp_sel[5]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr5),
        .ctrl_uni_we(w_ctrl_uni_we[5]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a5), .ctrl_uni_addr_b(w_ctrl_uni_addr_b5),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr5), .pe_out(pe5_out), .pe_valid_out(pe_valid_out[5]),
        .done_phase(w_done_phase[5]), .ldm_pp_data_out(w_ldm_pp_data_out5)
    );

    Controller u_controller6 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out6), .alu_valid(pe_valid_out[6]),
        .start(w_lane_start[6]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[6]),
        .done(lane_done[6]), .phase_done(lane_phase_done[6]), .ctrl_clear(w_ctrl_clear[6]),
        .ctrl_en(w_ctrl_en[6]), .ctrl_cfg_alu(w_ctrl_cfg_alu6), .ctrl_phase(w_ctrl_phase6),
        .ctrl_is_last(w_ctrl_is_last[6]), .ctrl_pp_sel(w_ctrl_pp_sel[6]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr6),
        .ctrl_uni_we(w_ctrl_uni_we[6]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a6), .ctrl_uni_addr_b(w_ctrl_uni_addr_b6),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr6)
    );
    PE u_pe6 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[6]), .ctrl_en(w_ctrl_en[6]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu6), .ctrl_phase(w_ctrl_phase6), .ctrl_is_last(w_ctrl_is_last[6]),
        .ctrl_pp_sel(w_ctrl_pp_sel[6]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr6),
        .ctrl_uni_we(w_ctrl_uni_we[6]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a6), .ctrl_uni_addr_b(w_ctrl_uni_addr_b6),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr6), .pe_out(pe6_out), .pe_valid_out(pe_valid_out[6]),
        .done_phase(w_done_phase[6]), .ldm_pp_data_out(w_ldm_pp_data_out6)
    );

    Controller u_controller7 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out7), .alu_valid(pe_valid_out[7]),
        .start(w_lane_start[7]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[7]),
        .done(lane_done[7]), .phase_done(lane_phase_done[7]), .ctrl_clear(w_ctrl_clear[7]),
        .ctrl_en(w_ctrl_en[7]), .ctrl_cfg_alu(w_ctrl_cfg_alu7), .ctrl_phase(w_ctrl_phase7),
        .ctrl_is_last(w_ctrl_is_last[7]), .ctrl_pp_sel(w_ctrl_pp_sel[7]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr7),
        .ctrl_uni_we(w_ctrl_uni_we[7]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a7), .ctrl_uni_addr_b(w_ctrl_uni_addr_b7),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr7)
    );
    PE u_pe7 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[7]), .ctrl_en(w_ctrl_en[7]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu7), .ctrl_phase(w_ctrl_phase7), .ctrl_is_last(w_ctrl_is_last[7]),
        .ctrl_pp_sel(w_ctrl_pp_sel[7]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr7),
        .ctrl_uni_we(w_ctrl_uni_we[7]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a7), .ctrl_uni_addr_b(w_ctrl_uni_addr_b7),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr7), .pe_out(pe7_out), .pe_valid_out(pe_valid_out[7]),
        .done_phase(w_done_phase[7]), .ldm_pp_data_out(w_ldm_pp_data_out7)
    );

    Controller u_controller8 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out8), .alu_valid(pe_valid_out[8]),
        .start(w_lane_start[8]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[8]),
        .done(lane_done[8]), .phase_done(lane_phase_done[8]), .ctrl_clear(w_ctrl_clear[8]),
        .ctrl_en(w_ctrl_en[8]), .ctrl_cfg_alu(w_ctrl_cfg_alu8), .ctrl_phase(w_ctrl_phase8),
        .ctrl_is_last(w_ctrl_is_last[8]), .ctrl_pp_sel(w_ctrl_pp_sel[8]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr8),
        .ctrl_uni_we(w_ctrl_uni_we[8]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a8), .ctrl_uni_addr_b(w_ctrl_uni_addr_b8),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr8)
    );
    PE u_pe8 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[8]), .ctrl_en(w_ctrl_en[8]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu8), .ctrl_phase(w_ctrl_phase8), .ctrl_is_last(w_ctrl_is_last[8]),
        .ctrl_pp_sel(w_ctrl_pp_sel[8]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr8),
        .ctrl_uni_we(w_ctrl_uni_we[8]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a8), .ctrl_uni_addr_b(w_ctrl_uni_addr_b8),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr8), .pe_out(pe8_out), .pe_valid_out(pe_valid_out[8]),
        .done_phase(w_done_phase[8]), .ldm_pp_data_out(w_ldm_pp_data_out8)
    );

    Controller u_controller9 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out9), .alu_valid(pe_valid_out[9]),
        .start(w_lane_start[9]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[9]),
        .done(lane_done[9]), .phase_done(lane_phase_done[9]), .ctrl_clear(w_ctrl_clear[9]),
        .ctrl_en(w_ctrl_en[9]), .ctrl_cfg_alu(w_ctrl_cfg_alu9), .ctrl_phase(w_ctrl_phase9),
        .ctrl_is_last(w_ctrl_is_last[9]), .ctrl_pp_sel(w_ctrl_pp_sel[9]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr9),
        .ctrl_uni_we(w_ctrl_uni_we[9]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a9), .ctrl_uni_addr_b(w_ctrl_uni_addr_b9),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr9)
    );
    PE u_pe9 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[9]), .ctrl_en(w_ctrl_en[9]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu9), .ctrl_phase(w_ctrl_phase9), .ctrl_is_last(w_ctrl_is_last[9]),
        .ctrl_pp_sel(w_ctrl_pp_sel[9]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr9),
        .ctrl_uni_we(w_ctrl_uni_we[9]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a9), .ctrl_uni_addr_b(w_ctrl_uni_addr_b9),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr9), .pe_out(pe9_out), .pe_valid_out(pe_valid_out[9]),
        .done_phase(w_done_phase[9]), .ldm_pp_data_out(w_ldm_pp_data_out9)
    );

    Controller u_controller10 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out10), .alu_valid(pe_valid_out[10]),
        .start(w_lane_start[10]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[10]),
        .done(lane_done[10]), .phase_done(lane_phase_done[10]), .ctrl_clear(w_ctrl_clear[10]),
        .ctrl_en(w_ctrl_en[10]), .ctrl_cfg_alu(w_ctrl_cfg_alu10), .ctrl_phase(w_ctrl_phase10),
        .ctrl_is_last(w_ctrl_is_last[10]), .ctrl_pp_sel(w_ctrl_pp_sel[10]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr10),
        .ctrl_uni_we(w_ctrl_uni_we[10]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a10), .ctrl_uni_addr_b(w_ctrl_uni_addr_b10),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr10)
    );
    PE u_pe10 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[10]), .ctrl_en(w_ctrl_en[10]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu10), .ctrl_phase(w_ctrl_phase10), .ctrl_is_last(w_ctrl_is_last[10]),
        .ctrl_pp_sel(w_ctrl_pp_sel[10]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr10),
        .ctrl_uni_we(w_ctrl_uni_we[10]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a10), .ctrl_uni_addr_b(w_ctrl_uni_addr_b10),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr10), .pe_out(pe10_out), .pe_valid_out(pe_valid_out[10]),
        .done_phase(w_done_phase[10]), .ldm_pp_data_out(w_ldm_pp_data_out10)
    );

    Controller u_controller11 (
        .CLK(CLK), .RST(RST), .ram_pp_N(w_ldm_pp_data_out11), .alu_valid(pe_valid_out[11]),
        .start(w_lane_start[11]), .phase_advance(w_phase_advance), .done_phase(w_done_phase[11]),
        .done(lane_done[11]), .phase_done(lane_phase_done[11]), .ctrl_clear(w_ctrl_clear[11]),
        .ctrl_en(w_ctrl_en[11]), .ctrl_cfg_alu(w_ctrl_cfg_alu11), .ctrl_phase(w_ctrl_phase11),
        .ctrl_is_last(w_ctrl_is_last[11]), .ctrl_pp_sel(w_ctrl_pp_sel[11]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr11),
        .ctrl_uni_we(w_ctrl_uni_we[11]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a11), .ctrl_uni_addr_b(w_ctrl_uni_addr_b11),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr11)
    );
    PE u_pe11 (
        .CLK(CLK), .RST(RST), .ctrl_clear(w_ctrl_clear[11]), .ctrl_en(w_ctrl_en[11]),
        .ctrl_cfg_alu(w_ctrl_cfg_alu11), .ctrl_phase(w_ctrl_phase11), .ctrl_is_last(w_ctrl_is_last[11]),
        .ctrl_pp_sel(w_ctrl_pp_sel[11]), .ctrl_pp_rd_addr(w_ctrl_pp_rd_addr11),
        .ctrl_uni_we(w_ctrl_uni_we[11]), .ctrl_uni_addr_a(w_ctrl_uni_addr_a11), .ctrl_uni_addr_b(w_ctrl_uni_addr_b11),
        .ctrl_perm_rd_addr(w_ctrl_perm_rd_addr11), .pe_out(pe11_out), .pe_valid_out(pe_valid_out[11]),
        .done_phase(w_done_phase[11]), .ldm_pp_data_out(w_ldm_pp_data_out11)
    );

endmodule
