module sliding_window_3x3 #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 28,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH)
)(
    input                          clk,
    input                          rst_n,
    // pixel stream in
    input                          valid_in,
    input      [DATA_WIDTH-1:0]    pixel_in,
    // window out
    output reg                     valid_out,
    output reg [DATA_WIDTH-1:0]    w00, w01, w02,
    output reg [DATA_WIDTH-1:0]    w10, w11, w12,
    output reg [DATA_WIDTH-1:0]    w20, w21, w22
);

    // two line buffers for previous two rows
    reg [DATA_WIDTH-1:0] rowbuf2 [0:IMG_WIDTH-1];
    reg [DATA_WIDTH-1:0] rowbuf1 [0:IMG_WIDTH-1];
    // shift-registers for current row
    reg [DATA_WIDTH-1:0] sr1, sr0;
    // column pointer
    reg [ADDR_WIDTH-1:0] col_cnt;
    integer              i;

    // compute wrap-around indices for circular buffer
    wire [ADDR_WIDTH-1:0] idx_m1 = (col_cnt + IMG_WIDTH - 1) % IMG_WIDTH;
    wire [ADDR_WIDTH-1:0] idx_m2 = (col_cnt + IMG_WIDTH - 2) % IMG_WIDTH;

    always @(posedge clk) begin
        if (!rst_n) begin
            col_cnt   <= 0;
            sr0       <= 0;
            sr1       <= 0;
            valid_out <= 0;
            for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                rowbuf1[i] <= 0;
                rowbuf2[i] <= 0;
            end
        end else if (valid_in) begin
            // rotate line buffers
            rowbuf2[col_cnt] <= rowbuf1[col_cnt];
            rowbuf1[col_cnt] <= pixel_in;
            // update shift regs
            sr1 <= sr0;
            sr0 <= pixel_in;
            // capture the 3×3 window
            w00 <= rowbuf2[idx_m2];  w01 <= rowbuf2[idx_m1];  w02 <= rowbuf2[col_cnt];
            w10 <= rowbuf1[idx_m2];  w11 <= rowbuf1[idx_m1];  w12 <= rowbuf1[col_cnt];
            w20 <= sr1;              w21 <= sr0;              w22 <= pixel_in;
            // assert valid
            valid_out <= 1;
            // advance column pointer
            col_cnt   <= (col_cnt == IMG_WIDTH-1) ? 0 : col_cnt + 1;
        end else begin
            valid_out <= 0;
        end
    end
endmodule