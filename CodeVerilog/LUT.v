`timescale 1ns/1ns

module LUT (
    input  wire [31:0] x_in,              // Dau vao x (tu 1 den 32)
    output reg signed [31:0] inv_out,     // Ket qua 1/x chuan Signed Q16.16 (y * 65536)
    output reg signed [31:0] log2_out,    // Ket qua log2(x) chuan Signed Q16.16 (y * 65536)
    output reg signed [31:0] xlog2x_out   // Ket qua x*log2(x) chuan Signed Q16.16 (y * 65536)
);
    always @(*) begin
        inv_out    = 32'sd0;
        log2_out   = 32'sd0;
        xlog2x_out = 32'sd0;

        case (x_in)
            32'd1:  begin inv_out = 32'sd65536; log2_out = 32'sd0;    xlog2x_out = 32'sd0;     end
            32'd2:  begin inv_out = 32'sd32768; log2_out = 32'sd65536;  xlog2x_out = 32'sd131072; end
            32'd3:  begin inv_out = 32'sd21845; log2_out = 32'sd103874; xlog2x_out = 32'sd311621; end
            32'd4:  begin inv_out = 32'sd16384; log2_out = 32'sd131072; xlog2x_out = 32'sd524288; end
            32'd5:  begin inv_out = 32'sd13107; log2_out = 32'sd152168; xlog2x_out = 32'sd760840; end
            32'd6:  begin inv_out = 32'sd10923; log2_out = 32'sd169410; xlog2x_out = 32'sd1016459;end
            32'd7:  begin inv_out = 32'sd9362;  log2_out = 32'sd183992; xlog2x_out = 32'sd1287942;end
            32'd8:  begin inv_out = 32'sd8192;  log2_out = 32'sd196608; xlog2x_out = 32'sd1572864;end
            32'd9:  begin inv_out = 32'sd7282;  log2_out = 32'sd207748; xlog2x_out = 32'sd1869729;end
            32'd10: begin inv_out = 32'sd6554;  log2_out = 32'sd217704; xlog2x_out = 32'sd2177040;end
            32'd11: begin inv_out = 32'sd5958;  log2_out = 32'sd226713; xlog2x_out = 32'sd2493847;end
            32'd12: begin inv_out = 32'sd5461;  log2_out = 32'sd234946; xlog2x_out = 32'sd2819350;end
            32'd13: begin inv_out = 32'sd5041;  log2_out = 32'sd242512; xlog2x_out = 32'sd3152657;end
            32'd14: begin inv_out = 32'sd4681;  log2_out = 32'sd249528; xlog2x_out = 32'sd3493388;end
            32'd15: begin inv_out = 32'sd4369;  log2_out = 32'sd256040; xlog2x_out = 32'sd3840597;end
            32'd16: begin inv_out = 32'sd4096;  log2_out = 32'sd262144; xlog2x_out = 32'sd4194304;end
            32'd17: begin inv_out = 32'sd3855;  log2_out = 32'sd267874; xlog2x_out = 32'sd4553860;end
            32'd18: begin inv_out = 32'sd3641;  log2_out = 32'sd273284; xlog2x_out = 32'sd4919105;end
            32'd19: begin inv_out = 32'sd3449;  log2_out = 32'sd278394; xlog2x_out = 32'sd5289482;end
            32'd20: begin inv_out = 32'sd3277;  log2_out = 32'sd283240; xlog2x_out = 32'sd5664801;end
            32'd21: begin inv_out = 32'sd3121;  log2_out = 32'sd287851; xlog2x_out = 32'sd6044861;end
            32'd22: begin inv_out = 32'sd2979;  log2_out = 32'sd292249; xlog2x_out = 32'sd6429487;end
            32'd23: begin inv_out = 32'sd2849;  log2_out = 32'sd296450; xlog2x_out = 32'sd6818340;end
            32'd24: begin inv_out = 32'sd2731;  log2_out = 32'sd300482; xlog2x_out = 32'sd7211563;end
            32'd25: begin inv_out = 32'sd2621;  log2_out = 32'sd304340; xlog2x_out = 32'sd7608501;end
            32'd26: begin inv_out = 32'sd2521;  log2_out = 32'sd308048; xlog2x_out = 32'sd8009251;end
            32'd27: begin inv_out = 32'sd2427;  log2_out = 32'sd311615; xlog2x_out = 32'sd8413608;end
            32'd28: begin inv_out = 32'sd2341;  log2_out = 32'sd315054; xlog2x_out = 32'sd8821504;end
            32'd29: begin inv_out = 32'sd2260;  log2_out = 32'sd318371; xlog2x_out = 32'sd9232771;end
            32'd30: begin inv_out = 32'sd2185;  log2_out = 32'sd321576; xlog2x_out = 32'sd9647274;end
            32'd31: begin inv_out = 32'sd2114;  log2_out = 32'sd324677; xlog2x_out = 32'sd10064975;end
            32'd32: begin inv_out = 32'sd2048;  log2_out = 32'sd327680; xlog2x_out = 32'sd10485760;end
            
            default: begin
                inv_out    = 32'sd0;
                log2_out   = 32'sd0;
                xlog2x_out = 32'sd0;
            end
        endcase
    end
endmodule