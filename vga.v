module vga (clk,rst,h_cnt,v_cnt,h_sync,v_sync,video);

input clk;
input rst;
output reg[9:0]h_cnt;  // H denotes horizontal
output reg [9:0]v_cnt; // V denotes vertical
output h_sync;
output v_sync;
output video;

//Total Values
localparam H_Total = 800;  // this values are obotained using => visible + front porch + sync + back porch
localparam V_Total = 525; //same as H_total
//Horzontal
localparam H_P = 640; //P for visible
localparam H_FP = 16; 
localparam H_SYNC = 96;
//Vertical
localparam V_P = 480;
localparam V_FP = 10;
localparam V_SYNC = 2;

//Horizontal Count
always@(posedge clk or posedge rst)
begin
	if(rst)
	 h_cnt <= 0;
	else if (h_cnt == H_Total - 1)
	h_cnt <= 0;
	else
	h_cnt <= h_cnt + 1;
end

// Vertical Conut
always@(posedge clk or posedge rst)
begin
	if(rst)begin
	 v_cnt <= 0;
	end else if (h_cnt == H_Total - 1)begin
		if(v_cnt == V_Total - 1)
		    v_cnt <= 0;
		else
		    v_cnt <= v_cnt + 1;
end
end

// Sync Singal logic 
assign h_sync = ~(h_cnt >= H_P + H_FP && h_cnt < H_P + H_FP + H_SYNC);
assign v_sync = ~(v_cnt >= V_P + V_FP && v_cnt < V_P + V_FP + V_SYNC);

assign video = (h_cnt < H_P) && (v_cnt <V_P);

endmodule 

	
