module vga_top (clk,rst,h_sync,v_sync,rgb);
input  wire clk;
input  wire  rst;
output wire  h_sync;
output wire v_sync;
output wire [11:0] rgb;


// internal wires to connect modules
wire clk_d;
wire [9:0]h_cnt;
wire [9:0]v_cnt;
wire video;

clk_divider u_clk (
    .clk(clk),
    .rst(rst),
    .clk_d(clk_d)
);

vga u_vga (
    .clk(clk_d),    // <-- 25MHz divided clock goes here
    .rst(rst),
    .h_cnt(h_cnt),
    .v_cnt(v_cnt),
    .h_sync(h_sync),
    .v_sync(v_sync),
    .video(video)
);

pattern_generator u_pattern (
    .h_cnt(h_cnt),
    .v_cnt(v_cnt),
    .video(video),
    .rgb(rgb)
);

endmodule
