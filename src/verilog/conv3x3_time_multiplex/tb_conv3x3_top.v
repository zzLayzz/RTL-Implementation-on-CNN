`timescale 1ns/1ps

module tb_conv3x3_top;

    // Parameters (should match your design)
    parameter DATA_WIDTH = 8;
    parameter IMG_WIDTH  = 28;

    // Testbench signals
    reg clk, rst_n, valid_in;
    reg [DATA_WIDTH-1:0] pixel_in;

    wire valid_out;
    wire signed [DATA_WIDTH-1:0] pixel_out;

    // Instantiate the convolution module
    conv3x3_time_multiplex uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .pixel_out(pixel_out)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz

    integer i, total_pixels;

    initial begin
        // Initialize
        rst_n = 0;
        valid_in = 0;
        pixel_in = 0;
        total_pixels = IMG_WIDTH * IMG_WIDTH;
        #20; // Wait a bit

        // Release reset
        rst_n = 1;
        #10;

        // Send image pixels, one by one
        valid_in = 1;
        for (i = 0; i < total_pixels; i = i + 1) begin
            pixel_in = i[DATA_WIDTH-1:0];  // You can load a real image here
            #10;
        end
        valid_in = 0;

        // Wait for pipeline to flush
        #5000;

        $display("\nSimulation finished.");
        $finish;
    end

    // Capture output pixels
    always @(posedge clk) begin
        if (valid_out)
            $display("Output pixel: %d (0x%02h)", pixel_out, pixel_out[DATA_WIDTH-1:0]);
    end

endmodule
