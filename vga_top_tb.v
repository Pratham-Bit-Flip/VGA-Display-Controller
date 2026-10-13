`timescale 1ns/1ps

module vga_top_tb;
reg clk;
reg rst;
wire h_sync;
wire v_sync;
wire [11:0] rgb;

// instantiate
vga_top uut (
    .clk(clk),
    .rst(rst),
    .h_sync(h_sync),
    .v_sync(v_sync),
    .rgb(rgb)
);
initial clk = 0;
always #5 clk = ~clk;

// stimulus
initial begin
    rst = 1;
    #20;
    rst = 0;
#17_000_000;  // just over 1 full frame


    $finish;
end

// dump waveforms
initial begin
    $dumpfile("vga_top_tb.vcd");
    $dumpvars(0, vga_top_tb);
end

endmodule
