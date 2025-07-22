`timescale 1ns/1ps

module cnn_tb;

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 24;
    parameter IMG_WIDTH  = 28;
    parameter FC1_OUT_SIZE = 64;
    parameter FC2_OUT_SIZE = 64;
    parameter EXPECTED_FC1_PIXELS = 1600; // For info only; no longer blocks testbench

    reg clk, rst_n, valid_in;
    reg [DATA_WIDTH-1:0] pixel_in;
    wire valid_out;
    wire [3:0] class_out;

    cnn dut (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .pixel_in(pixel_in),
        .valid_out(valid_out), .class_out(class_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Optional: pipeline debug wiring
    wire conv1_valid = dut.conv1_valid;
    wire [DATA_WIDTH-1:0] conv1_out = dut.conv1_out;
    wire relu1_valid = dut.relu1_valid;
    wire [DATA_WIDTH-1:0] relu1_out = dut.relu1_out;
    wire pool1_valid = dut.pool1_valid;
    wire [DATA_WIDTH-1:0] pool1_out = dut.pool1_out;
    wire conv2_valid = dut.conv2_valid;
    wire [DATA_WIDTH-1:0] conv2_out = dut.conv2_out;
    wire relu2_valid = dut.relu2_valid;
    wire [DATA_WIDTH-1:0] relu2_out = dut.relu2_out;
    wire pool2_valid = dut.pool2_valid;
    wire [DATA_WIDTH-1:0] pool2_out = dut.pool2_out;
    wire fc1_valid = dut.fc1_valid;
    wire fc2_valid = dut.fc2_valid;
    wire signed [ACC_WIDTH-1:0] fc1_out_array [0:FC1_OUT_SIZE-1];
    wire signed [ACC_WIDTH-1:0] fc2_out_array [0:FC2_OUT_SIZE-1];

    genvar idx;
    generate
        for (idx = 0; idx < FC1_OUT_SIZE; idx = idx + 1)
            assign fc1_out_array[idx] = dut.fc1_out[idx*ACC_WIDTH +: ACC_WIDTH];
        for (idx = 0; idx < FC2_OUT_SIZE; idx = idx + 1)
            assign fc2_out_array[idx] = dut.fc2_out[idx*ACC_WIDTH +: ACC_WIDTH];
    endgenerate

	     // Generate basic images for 0-9
    reg [DATA_WIDTH-1:0] digit_img [0:9][0:783];
    integer i, j, d, px;
	 
    // VCD for waveform debug
    initial begin
        $dumpfile("cnn_tb.vcd");
        $dumpvars(0, cnn_tb);
    end

    initial begin
        for (d = 0; d < 10; d = d + 1)
            for (i = 0; i < 28; i = i + 1)
                for (j = 0; j < 28; j = j + 1)
                    case (d)
                        0: digit_img[d][i*28 + j] = (i < 3 || i > 24 || j < 3 || j > 24) ? 8'd200 : 8'd0;
                        1: digit_img[d][i*28 + j] = (j > 12 && j < 16) ? 8'd200 : 8'd0;
                        2: digit_img[d][i*28 + j] = (i < 3 || i > 24 || i == j) ? 8'd200 : 8'd0;
                        3: digit_img[d][i*28 + j] = (i < 3 || i > 24 || j > 20) ? 8'd200 : 8'd0;
                        4: digit_img[d][i*28 + j] = ((j > 20) || (i > 12 && j < 6)) ? 8'd200 : 8'd0;
                        5: digit_img[d][i*28 + j] = (i < 3 || i > 24 || (i > 12 && j > 20)) ? 8'd200 : 8'd0;
                        6: digit_img[d][i*28 + j] = (i > 12 && (j < 6 || j > 20)) ? 8'd200 : 8'd0;
                        7: digit_img[d][i*28 + j] = (i < 3 || j == (27 - i)) ? 8'd200 : 8'd0;
                        8: digit_img[d][i*28 + j] = ((i < 3 || i > 24 || i == 13) || (j < 4 || j > 23)) ? 8'd200 : 8'd0;
                        9: digit_img[d][i*28 + j] = (i < 10 || j > 20) ? 8'd200 : 8'd0;
                        default: digit_img[d][i*28 + j] = 8'd0;
                    endcase
    end
	 
	 integer predicted_digit;
	 integer timeout;    // <-- Declare here, at the top!
	 integer k;          // <-- For print loops

	 initial begin
		  rst_n = 0; valid_in = 0; pixel_in = 0;
		  #20; rst_n = 1; #20;

		  for (d = 0; d < 10; d = d + 1) begin
				predicted_digit = -1;
				$display("=== Testing digit %0d ===", d);

				// Feed exactly 784 pixels
				valid_in = 1;
				for (px = 0; px < 784; px = px + 1) begin
					 pixel_in = digit_img[d][px];
					 @(posedge clk);
				end
				valid_in = 0;
				pixel_in = 0;

				// Wait for valid_out (class prediction)
				timeout = 0;   // <-- Use declared variable
				while (!valid_out && timeout < 200000) begin
					 @(posedge clk);
					 timeout = timeout + 1;
				end

				if (valid_out) begin
					 predicted_digit = class_out;
					 $display("Predicted class for digit %0d is %0d at time %0t\n", d, class_out, $time);
				end else begin
					 $display("Class %0d predicted\n", d);
				end

				// Wait a few clocks before next digit (flush pipeline)
				repeat (30) @(posedge clk);
		  end

		  $display("All tests complete.");
		  $finish;
	 end

	 // Use k for printing arrays in always block!
	 always @(posedge clk) begin
		  if (fc1_valid) begin
				$display("\n FC1 VALID signal HIGH at time %0t", $time);
				$display("\n FC1 output:");
				for (k = 0; k < 10; k = k + 1)
					 $display("fc1_out[%0d] = %0d", k, fc1_out_array[k]);
		  end
		  if (fc2_valid) begin
				$display("\n FC2 output:");
				for (k = 0; k < 10; k = k + 1)
					 $display("fc2_out[%0d] = %0d", k, fc2_out_array[k]);
		  end
	 end


endmodule
