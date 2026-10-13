module pattern_generator(h_cnt ,v_cnt,video,rgb);
input [9:0]h_cnt;
input [9:0]v_cnt;
input video;
output reg [11:0]rgb;

always@(*)
begin
    if(!video)
     rgb <= 12'h000; // blank
	
	else if (h_cnt < 80) 
	rgb = 12'hF00;  // red
	else if (h_cnt < 160)
	rgb = 12'h0F0;  // green
	else if (h_cnt < 240)
	rgb = 12'h00F;  // blue
	else if (h_cnt < 320)
	rgb = 12'hFF0;  // yellow
	else if (h_cnt < 400)
	rgb = 12'hF0F;  // magenta
	else if (h_cnt < 480)
	rgb = 12'h0FF;  // cyan
	else if (h_cnt < 560)
	rgb = 12'hFFF;  // white
	else                  
	rgb = 12'h888;  // greyelse

     end
endmodule
