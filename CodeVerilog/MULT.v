`timescale 1ns/1ns
`include "common.vh"

module MULT (
    input  wire          CLK,                                        
    input  wire          RST,
    input  wire          ctrl_clear,
    input  wire          ctrl_en,
    input  wire          S0_valid_in,        
    input  wire signed [31:0] S0_in,   
    input  wire          S1_valid_in,        
    input  wire signed [31:0] S1_in,   
    output reg           D0_valid,  
    output reg signed [63:0] D0_out   
);
    
    wire [31:0] abs_S0     = (S0_in < 0) ? -S0_in : S0_in;
    wire [31:0] abs_S1     = (S1_in < 0) ? -S1_in : S1_in;
    wire        res_neg_wr = (S0_in[31] ^ S1_in[31]) && (S0_in != 0 && S1_in != 0);

    wire [63:0] p0_wr,  p1_wr,  p2_wr,  p3_wr,  p4_wr,  p5_wr,  p6_wr,  p7_wr;
    wire [63:0] p8_wr,  p9_wr,  p10_wr, p11_wr, p12_wr, p13_wr, p14_wr, p15_wr;
    wire [63:0] p16_wr, p17_wr, p18_wr, p19_wr, p20_wr, p21_wr, p22_wr, p23_wr;
    wire [63:0] p24_wr, p25_wr, p26_wr, p27_wr, p28_wr, p29_wr, p30_wr, p31_wr;

    assign p0_wr  = abs_S1[0]  ? ({32'd0, abs_S0} << 0)  : 64'd0; 
    assign p1_wr  = abs_S1[1]  ? ({32'd0, abs_S0} << 1)  : 64'd0;
    assign p2_wr  = abs_S1[2]  ? ({32'd0, abs_S0} << 2)  : 64'd0; 
    assign p3_wr  = abs_S1[3]  ? ({32'd0, abs_S0} << 3)  : 64'd0;
    assign p4_wr  = abs_S1[4]  ? ({32'd0, abs_S0} << 4)  : 64'd0; 
    assign p5_wr  = abs_S1[5]  ? ({32'd0, abs_S0} << 5)  : 64'd0;
    assign p6_wr  = abs_S1[6]  ? ({32'd0, abs_S0} << 6)  : 64'd0; 
    assign p7_wr  = abs_S1[7]  ? ({32'd0, abs_S0} << 7)  : 64'd0;
    assign p8_wr  = abs_S1[8]  ? ({32'd0, abs_S0} << 8)  : 64'd0; 
    assign p9_wr  = abs_S1[9]  ? ({32'd0, abs_S0} << 9)  : 64'd0;
    assign p10_wr = abs_S1[10] ? ({32'd0, abs_S0} << 10) : 64'd0; 
    assign p11_wr = abs_S1[11] ? ({32'd0, abs_S0} << 11) : 64'd0;
    assign p12_wr = abs_S1[12] ? ({32'd0, abs_S0} << 12) : 64'd0; 
    assign p13_wr = abs_S1[13] ? ({32'd0, abs_S0} << 13) : 64'd0;
    assign p14_wr = abs_S1[14] ? ({32'd0, abs_S0} << 14) : 64'd0; 
    assign p15_wr = abs_S1[15] ? ({32'd0, abs_S0} << 15) : 64'd0;
    assign p16_wr = abs_S1[16] ? ({32'd0, abs_S0} << 16) : 64'd0; 
    assign p17_wr = abs_S1[17] ? ({32'd0, abs_S0} << 17) : 64'd0;
    assign p18_wr = abs_S1[18] ? ({32'd0, abs_S0} << 18) : 64'd0; 
    assign p19_wr = abs_S1[19] ? ({32'd0, abs_S0} << 19) : 64'd0;
    assign p20_wr = abs_S1[20] ? ({32'd0, abs_S0} << 20) : 64'd0; 
    assign p21_wr = abs_S1[21] ? ({32'd0, abs_S0} << 21) : 64'd0;
    assign p22_wr = abs_S1[22] ? ({32'd0, abs_S0} << 22) : 64'd0; 
    assign p23_wr = abs_S1[23] ? ({32'd0, abs_S0} << 23) : 64'd0;
    assign p24_wr = abs_S1[24] ? ({32'd0, abs_S0} << 24) : 64'd0; 
    assign p25_wr = abs_S1[25] ? ({32'd0, abs_S0} << 25) : 64'd0;
    assign p26_wr = abs_S1[26] ? ({32'd0, abs_S0} << 26) : 64'd0; 
    assign p27_wr = abs_S1[27] ? ({32'd0, abs_S0} << 27) : 64'd0;
    assign p28_wr = abs_S1[28] ? ({32'd0, abs_S0} << 28) : 64'd0; 
    assign p29_wr = abs_S1[29] ? ({32'd0, abs_S0} << 29) : 64'd0;
    assign p30_wr = abs_S1[30] ? ({32'd0, abs_S0} << 30) : 64'd0; 
    assign p31_wr = abs_S1[31] ? ({32'd0, abs_S0} << 31) : 64'd0;

    reg [63:0] p0_rg,  p1_rg,  p2_rg,  p3_rg,  p4_rg,  p5_rg,  p6_rg,  p7_rg;
    reg [63:0] p8_rg,  p9_rg,  p10_rg, p11_rg, p12_rg, p13_rg, p14_rg, p15_rg;
    reg [63:0] p16_rg, p17_rg, p18_rg, p19_rg, p20_rg, p21_rg, p22_rg, p23_rg;
    reg [63:0] p24_rg, p25_rg, p26_rg, p27_rg, p28_rg, p29_rg, p30_rg, p31_rg;

    wire [63:0] s1_0_wr, s1_1_wr, s1_2_wr, s1_3_wr, s1_4_wr, s1_5_wr, s1_6_wr, s1_7_wr;
    wire [63:0] s1_8_wr, s1_9_wr, s1_10_wr, s1_11_wr, s1_12_wr, s1_13_wr, s1_14_wr, s1_15_wr;
    assign s1_0_wr = p0_rg  + p1_rg;   assign s1_1_wr = p2_rg  + p3_rg;
    assign s1_2_wr = p4_rg  + p5_rg;   assign s1_3_wr = p6_rg  + p7_rg;
    assign s1_4_wr = p8_rg  + p9_rg;   assign s1_5_wr = p10_rg + p11_rg;
    assign s1_6_wr = p12_rg + p13_rg;  assign s1_7_wr = p14_rg + p15_rg;
    assign s1_8_wr = p16_rg + p17_rg;  assign s1_9_wr = p18_rg + p19_rg;
    assign s1_10_wr= p20_rg + p21_rg;  assign s1_11_wr= p22_rg + p23_rg;
    assign s1_12_wr= p24_rg + p25_rg;  assign s1_13_wr= p26_rg + p27_rg;
    assign s1_14_wr= p28_rg + p29_rg;  assign s1_15_wr= p30_rg + p31_rg;

    reg [63:0] s1_0_rg, s1_1_rg, s1_2_rg, s1_3_rg, s1_4_rg, s1_5_rg, s1_6_rg, s1_7_rg;
    reg [63:0] s1_8_rg, s1_9_rg, s1_10_rg, s1_11_rg, s1_12_rg, s1_13_rg, s1_14_rg, s1_15_rg;

    wire [63:0] s2_0_wr, s2_1_wr, s2_2_wr, s2_3_wr, s2_4_wr, s2_5_wr, s2_6_wr, s2_7_wr;
    assign s2_0_wr = s1_0_rg + s1_1_rg; assign s2_1_wr = s1_2_rg + s1_3_rg;
    assign s2_2_wr = s1_4_rg + s1_5_rg; assign s2_3_wr = s1_6_rg + s1_7_rg;
    assign s2_4_wr = s1_8_rg + s1_9_rg; assign s2_5_wr = s1_10_rg + s1_11_rg;
    assign s2_6_wr = s1_12_rg + s1_13_rg; assign s2_7_wr = s1_14_rg + s1_15_rg;

    reg [63:0] s2_0_rg, s2_1_rg, s2_2_rg, s2_3_rg, s2_4_rg, s2_5_rg, s2_6_rg, s2_7_rg;

    wire [63:0] s3_0_wr, s3_1_wr, s3_2_wr, s3_3_wr;
    assign s3_0_wr = s2_0_rg + s2_1_rg; assign s3_1_wr = s2_2_rg + s2_3_rg;
    assign s3_2_wr = s2_4_rg + s2_5_rg; assign s3_3_wr = s2_6_rg + s2_7_rg;

    reg [63:0] s3_0_rg, s3_1_rg, s3_2_rg, s3_3_rg;

    wire [63:0] s4_0_wr, s4_1_wr;
    assign s4_0_wr = s3_0_rg + s3_1_rg; assign s4_1_wr = s3_2_rg + s3_3_rg;

    reg [63:0] s4_0_rg, s4_1_rg;

    wire [63:0] D0_wr = s4_0_rg + s4_1_rg;

    reg [4:0] v_shift;
    reg [4:0] n_shift;

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            p0_rg <= 0; p1_rg <= 0; p2_rg <= 0; p3_rg <= 0; p4_rg <= 0; p5_rg <= 0; p6_rg <= 0; p7_rg <= 0;
            p8_rg <= 0; p9_rg <= 0; p10_rg <= 0; p11_rg <= 0; p12_rg <= 0; p13_rg <= 0; p14_rg <= 0; p15_rg <= 0;
            p16_rg <= 0; p17_rg <= 0; p18_rg <= 0; p19_rg <= 0; p20_rg <= 0; p21_rg <= 0; p22_rg <= 0; p23_rg <= 0;
            p24_rg <= 0; p25_rg <= 0; p26_rg <= 0; p27_rg <= 0; p28_rg <= 0; p29_rg <= 0; p30_rg <= 0; p31_rg <= 0;
            s1_0_rg <= 0; s1_1_rg <= 0; s1_2_rg <= 0; s1_3_rg <= 0; s1_4_rg <= 0; s1_5_rg <= 0; s1_6_rg <= 0; s1_7_rg <= 0;
            s1_8_rg <= 0; s1_9_rg <= 0; s1_10_rg <= 0; s1_11_rg <= 0; s1_12_rg <= 0; s1_13_rg <= 0; s1_14_rg <= 0; s1_15_rg <= 0;
            s2_0_rg <= 0; s2_1_rg <= 0; s2_2_rg <= 0; s2_3_rg <= 0; s2_4_rg <= 0; s2_5_rg <= 0; s2_6_rg <= 0; s2_7_rg <= 0;
            s3_0_rg <= 0; s3_1_rg <= 0; s3_2_rg <= 0; s3_3_rg <= 0;
            s4_0_rg <= 0; s4_1_rg <= 0;
            v_shift <= 0; n_shift <= 0;
            D0_out  <= 0; D0_valid <= 0;
        end else if (ctrl_clear) begin
            p0_rg <= 0; p1_rg <= 0; p2_rg <= 0; p3_rg <= 0; p4_rg <= 0; p5_rg <= 0; p6_rg <= 0; p7_rg <= 0;
            p8_rg <= 0; p9_rg <= 0; p10_rg <= 0; p11_rg <= 0; p12_rg <= 0; p13_rg <= 0; p14_rg <= 0; p15_rg <= 0;
            p16_rg <= 0; p17_rg <= 0; p18_rg <= 0; p19_rg <= 0; p20_rg <= 0; p21_rg <= 0; p22_rg <= 0; p23_rg <= 0;
            p24_rg <= 0; p25_rg <= 0; p26_rg <= 0; p27_rg <= 0; p28_rg <= 0; p29_rg <= 0; p30_rg <= 0; p31_rg <= 0;
            s1_0_rg <= 0; s1_1_rg <= 0; s1_2_rg <= 0; s1_3_rg <= 0; s1_4_rg <= 0; s1_5_rg <= 0; s1_6_rg <= 0; s1_7_rg <= 0;
            s1_8_rg <= 0; s1_9_rg <= 0; s1_10_rg <= 0; s1_11_rg <= 0; s1_12_rg <= 0; s1_13_rg <= 0; s1_14_rg <= 0; s1_15_rg <= 0;
            s2_0_rg <= 0; s2_1_rg <= 0; s2_2_rg <= 0; s2_3_rg <= 0; s2_4_rg <= 0; s2_5_rg <= 0; s2_6_rg <= 0; s2_7_rg <= 0;
            s3_0_rg <= 0; s3_1_rg <= 0; s3_2_rg <= 0; s3_3_rg <= 0;
            s4_0_rg <= 0; s4_1_rg <= 0;
            v_shift <= 0; n_shift <= 0;
            D0_out  <= 0; D0_valid <= 0;
        end         
        else if (ctrl_en) begin      
            p0_rg  <= p0_wr;  p1_rg  <= p1_wr;  p2_rg  <= p2_wr;  p3_rg  <= p3_wr;
            p4_rg  <= p4_wr;  p5_rg  <= p5_wr;  p6_rg  <= p6_wr;  p7_rg  <= p7_wr;
            p8_rg  <= p8_wr;  p9_rg  <= p9_wr;  p10_rg <= p10_wr; p11_rg <= p11_wr;
            p12_rg <= p12_wr; p13_rg <= p13_wr; p14_rg <= p14_wr; p15_rg <= p15_wr;
            p16_rg <= p16_wr; p17_rg <= p17_wr; p18_rg <= p18_wr; p19_rg <= p19_wr;
            p20_rg <= p20_wr; p21_rg <= p21_wr; p22_rg <= p22_wr; p23_rg <= p23_wr;
            p24_rg <= p24_wr; p25_rg <= p25_wr; p26_rg <= p26_wr; p27_rg <= p27_wr;
            p28_rg <= p28_wr; p29_rg <= p29_wr; p30_rg <= p30_wr; p31_rg <= p31_wr;
            
            v_shift[0] <= S0_valid_in & S1_valid_in;
            n_shift[0] <= res_neg_wr;

            s1_0_rg <= s1_0_wr; s1_1_rg <= s1_1_wr; s1_2_rg <= s1_2_wr; s1_3_rg <= s1_3_wr;
            s1_4_rg <= s1_4_wr; s1_5_rg <= s1_5_wr; s1_6_rg <= s1_6_wr; s1_7_rg <= s1_7_wr;
            s1_8_rg <= s1_8_wr; s1_9_rg <= s1_9_wr; s1_10_rg <= s1_10_wr; s1_11_rg <= s1_11_wr;
            s1_12_rg <= s1_12_wr; s1_13_rg <= s1_13_wr; s1_14_rg <= s1_14_wr; s1_15_rg <= s1_15_wr;
            
            v_shift[1] <= v_shift[0]; n_shift[1] <= n_shift[0];

            s2_0_rg <= s2_0_wr; s2_1_rg <= s2_1_wr; s2_2_rg <= s2_2_wr; s2_3_rg <= s2_3_wr;
            s2_4_rg <= s2_4_wr; s2_5_rg <= s2_5_wr; s2_6_rg <= s2_6_wr; s2_7_rg <= s2_7_wr;
            
            v_shift[2] <= v_shift[1]; n_shift[2] <= n_shift[1];

            s3_0_rg <= s3_0_wr; s3_1_rg <= s3_1_wr; s3_2_rg <= s3_2_wr; s3_3_rg <= s3_3_wr;
            
            v_shift[3] <= v_shift[2]; n_shift[3] <= n_shift[2];

            s4_0_rg <= s4_0_wr; s4_1_rg <= s4_1_wr;
            
            v_shift[4] <= v_shift[3]; n_shift[4] <= n_shift[3];

            D0_out   <= n_shift[4] ? -D0_wr : D0_wr;
            D0_valid <= v_shift[4];
        end
    end
endmodule
