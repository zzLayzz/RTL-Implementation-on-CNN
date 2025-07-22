`timescale 1ns / 1ps

module tb_fc_layer;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 24;
    parameter IN_SIZE = 4;
    parameter OUT_SIZE = 2;

    reg clk = 0, reset = 1, start = 0, valid_in = 0, ready_in = 1;
    reg signed [DATA_WIDTH-1:0] data_in;
    wire [$clog2(OUT_SIZE*IN_SIZE)-1:0] weight_addr;
    reg signed [DATA_WIDTH-1:0] weight_din;
    wire weight_en;
    wire [$clog2(OUT_SIZE)-1:0] bias_addr;
    reg signed [ACC_WIDTH-1:0] bias_din;
    wire valid_out;
    wire signed [ACC_WIDTH-1:0] out_data;
    wire [$clog2(OUT_SIZE)-1:0] out_idx;

    // Instantiate DUT
    fc_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .IN_SIZE(IN_SIZE),
        .OUT_SIZE(OUT_SIZE)
    ) dut (
        .clk(clk), .reset(reset), .start(start), .valid_in(valid_in),
        .data_in(data_in), .weight_addr(weight_addr), .weight_din(weight_din),
        .weight_en(weight_en), .bias_addr(bias_addr), .bias_din(bias_din),
        .valid_out(valid_out), .out_data(out_data), .out_idx(out_idx),
        .ready_in(ready_in)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Test Vectors
    reg signed [DATA_WIDTH-1:0] input_data [0:IN_SIZE-1];
    reg signed [DATA_WIDTH-1:0] weight_data [0:OUT_SIZE*IN_SIZE-1];
    reg signed [ACC_WIDTH-1:0] bias_data [0:OUT_SIZE-1];

    integer i;

    initial begin
        // Initialize input, weights, biases
        input_data[0] = 8'sd1; input_data[1] = 8'sd2;
        input_data[2] = 8'sd3; input_data[3] = 8'sd4;

        // weights for OUT neuron 0
        weight_data[0] = 8'sd1; weight_data[1] = 8'sd1;
        weight_data[2] = 8'sd1; weight_data[3] = 8'sd1;

        // weights for OUT neuron 1
        weight_data[4] = 8'sd2; weight_data[5] = 8'sd0;
        weight_data[6] = 8'sd1; weight_data[7] = 8'sd-1;

        bias_data[0] = 24'sd0;
        bias_data[1] = 24'sd10;

        // Apply reset
        #10 reset = 0;

        // Start operation
        #10 start = 1;
        #10 start = 0;

        // Feed input data
        for (i = 0; i < IN_SIZE; i = i + 1) begin
            valid_in = 1;
            data_in = input_data[i];
            #10;
        end
        valid_in = 0;

        // Wait and feed weights & biases as needed
        forever begin
            if (weight_en) begin
                weight_din = weight_data[weight_addr];
            end
            bias_din = bias_data[bias_addr];

            // Print output when ready
            if (valid_out) begin
                $display("OUT[%0d] = %0d", out_idx, out_data);
            end
            #10;
        end
    end

endmodule
