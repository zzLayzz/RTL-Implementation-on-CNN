module conv3x3_core #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 24,
    parameter QUANT      = 0
)(
    input                              clk,
    input                              rst_n,
    // window pixels
    input                              valid_in,
    input  signed [DATA_WIDTH-1:0]     p00, p01, p02,
    input  signed [DATA_WIDTH-1:0]     p10, p11, p12,
    input  signed [DATA_WIDTH-1:0]     p20, p21, p22,
    // window weights
    input  signed [DATA_WIDTH-1:0]     w00, w01, w02,
    input  signed [DATA_WIDTH-1:0]     w10, w11, w12,
    input  signed [DATA_WIDTH-1:0]     w20, w21, w22,
    input  signed [DATA_WIDTH-1:0]     bias,
    // output pixel
    output reg                         valid_out,
    output reg signed [DATA_WIDTH-1:0] pixel_out
);

    // Partial products
    wire signed [ACC_WIDTH-1:0] m00 = p00 * w00;
    wire signed [ACC_WIDTH-1:0] m01 = p01 * w01;
    wire signed [ACC_WIDTH-1:0] m02 = p02 * w02;
    wire signed [ACC_WIDTH-1:0] m10 = p10 * w10;
    wire signed [ACC_WIDTH-1:0] m11 = p11 * w11;
    wire signed [ACC_WIDTH-1:0] m12 = p12 * w12;
    wire signed [ACC_WIDTH-1:0] m20 = p20 * w20;
    wire signed [ACC_WIDTH-1:0] m21 = p21 * w21;
    wire signed [ACC_WIDTH-1:0] m22 = p22 * w22;

    // Sum all products + bias
    wire signed [ACC_WIDTH-1:0] sum =
          m00 + m01 + m02
        + m10 + m11 + m12
        + m20 + m21 + m22
        + bias;

    // Quantization register
    reg signed [ACC_WIDTH-1:0] qreg;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            qreg      <= {ACC_WIDTH{1'b0}};
            pixel_out <= {DATA_WIDTH{1'b0}};
        end else begin
            if (valid_in) begin
                // Apply quantization shift, register result
                qreg      <= sum >>> QUANT;
                pixel_out <= qreg[DATA_WIDTH-1:0];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule
