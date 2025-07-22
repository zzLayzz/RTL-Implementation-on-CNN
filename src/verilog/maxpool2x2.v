module maxpool2x2 #(
    parameter DATA_WIDTH=8,
    parameter IMG_WIDTH=28
)(
    input clk, rst_n,
    input valid_in,
    input [DATA_WIDTH-1:0] pixel_in,
    output reg valid_out,
    output reg [DATA_WIDTH-1:0] pixel_out
);
    reg [DATA_WIDTH-1:0] linebuf [0:IMG_WIDTH-1];
    integer i; reg [8:0] col_cnt;
    reg [DATA_WIDTH-1:0] ul,ur,dl,dr;
    always @(posedge clk) begin
        if (rst_n) begin
            col_cnt<=0; valid_out<=0;
            for(i=0;i<IMG_WIDTH;i=i+1) linebuf[i]<=0;
        end else if (valid_in) begin
            ul <= linebuf[col_cnt];
            ur <= linebuf[col_cnt+1];
            dl <= pixel_in;
            linebuf[col_cnt] <= pixel_in;
            col_cnt <= (col_cnt==IMG_WIDTH-1)?0:col_cnt+1;
            valid_out <= valid_in;
            pixel_out <= (ul>ur && ul>dl && ul>dr)?ul:
                        (ur>dl && ur>dr)?ur:
                        (dl>dr)?dl:dr;
        end
    end
endmodule
