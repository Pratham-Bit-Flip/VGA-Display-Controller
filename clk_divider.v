
module clk_divider (clk, rst, clk_d);
input clk;
input  rst;
output clk_d;

reg [1:0] cnt;

always @(posedge clk or posedge rst) begin
    if (rst)
        cnt <= 0;
    else
        cnt <= cnt + 1;
end

assign clk_d = cnt[1];

endmodule
