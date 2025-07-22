`timescale 1ns/1ps

module cnn #(
    parameter DATA_WIDTH        = 8,
    parameter ACC_WIDTH         = 24,
    parameter IMG_WIDTH         = 28,
    parameter NUM_FILTERS1      = 32,
    parameter NUM_FILTERS2      = 64,
    parameter FC1_OUT_SIZE      = 64,
    parameter FC2_OUT_SIZE      = 64,
    parameter QUANT             = 0
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          valid_in,
    input  wire [DATA_WIDTH-1:0]         pixel_in,
    output wire                          valid_out,
    output wire [3:0]                    class_out
);

    // --- First Conv Block ---
    wire conv1_valid, relu1_valid, pool1_valid;
    wire signed [DATA_WIDTH-1:0] conv1_out, relu1_out, pool1_out;

    conv3x3_time_multiplex #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .QUANT(QUANT),
        .IMG_WIDTH(IMG_WIDTH),
        .NUM_FILTERS(NUM_FILTERS1)
    ) conv1 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .pixel_in(pixel_in),
        .valid_out(conv1_valid), .pixel_out(conv1_out)
    );

    relu #( .DATA_WIDTH(DATA_WIDTH) ) relu1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(conv1_valid), .data_in(conv1_out),
        .valid_out(relu1_valid), .data_out(relu1_out)
    );

    maxpool2x2 #( .DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH-2) ) pool1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(relu1_valid), .pixel_in(relu1_out),
        .valid_out(pool1_valid), .pixel_out(pool1_out)
    );

    // --- Second Conv Block ---
    localparam IMG_WIDTH2 = ((IMG_WIDTH-2)/2);
    wire conv2_valid, relu2_valid, pool2_valid;
    wire signed [DATA_WIDTH-1:0] conv2_out, relu2_out, pool2_out;

    conv3x3_time_multiplex2 #(
        .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .QUANT(QUANT),
        .IMG_WIDTH(IMG_WIDTH2), .NUM_FILTERS(NUM_FILTERS2)
    ) conv2 (
        .clk(clk), .rst_n(rst_n), .valid_in(pool1_valid), .pixel_in(pool1_out),
        .valid_out(conv2_valid), .pixel_out(conv2_out)
    );

    relu #( .DATA_WIDTH(DATA_WIDTH) ) relu2 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(conv2_valid), .data_in(conv2_out),
        .valid_out(relu2_valid), .data_out(relu2_out)
    );

    maxpool2x2 #( .DATA_WIDTH(DATA_WIDTH), .IMG_WIDTH(IMG_WIDTH2-2) ) pool2 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(relu2_valid), .pixel_in(relu2_out),
        .valid_out(pool2_valid), .pixel_out(pool2_out)
    );
	 
	 localparam FC1_IN_SIZE = ((IMG_WIDTH2-2)/2) * ((IMG_WIDTH2-2)/2) * NUM_FILTERS2; // Confirm this math matches your actual feature count

	 // --- Flattening buffer/feeder ---
		reg [DATA_WIDTH-1:0] flatten_buf [0:FC1_IN_SIZE-1];
		reg [$clog2(FC1_IN_SIZE):0] flatten_wr_ptr = 0;
		reg [$clog2(FC1_IN_SIZE):0] flatten_rd_ptr = 0;
		reg collecting = 1'b1, feeding = 1'b0;
		reg flatten_fc1_valid_in = 1'b0;
		reg [DATA_WIDTH-1:0] flatten_fc1_data_in = 0;
		reg flatten_fc1_start = 1'b0;

		always @(posedge clk or negedge rst_n) begin
			 if (!rst_n) begin
				  flatten_wr_ptr <= 0;
				  flatten_rd_ptr <= 0;
				  collecting    <= 1'b1;
				  feeding       <= 1'b0;
				  flatten_fc1_valid_in <= 0;
				  flatten_fc1_start    <= 0;
			 end else begin
				  flatten_fc1_valid_in <= 0; // default

				  // 1. Collect outputs from pool2
				  if (collecting) begin
						if (pool2_valid) begin
							 flatten_buf[flatten_wr_ptr] <= pool2_out;
							 flatten_wr_ptr <= flatten_wr_ptr + 1;
							 if (flatten_wr_ptr == FC1_IN_SIZE-1) begin
								  collecting <= 1'b0;
								  feeding <= 1'b1;
								  flatten_rd_ptr <= 0;
								  flatten_fc1_start <= 1'b1; // Pulse start for FC1
							 end else begin
								  flatten_fc1_start <= 1'b0;
							 end
						end else begin
							 flatten_fc1_start <= 1'b0;
						end
				  end

				  // 2. Feed data to FC1
				  else if (feeding) begin
						flatten_fc1_data_in <= flatten_buf[flatten_rd_ptr];
						flatten_fc1_valid_in <= 1'b1;
						flatten_rd_ptr <= flatten_rd_ptr + 1;
						flatten_fc1_start <= 1'b0;

						if (flatten_rd_ptr == FC1_IN_SIZE-1) begin
							 feeding <= 1'b0;
							 collecting <= 1'b1;
							 flatten_wr_ptr <= 0;
						end
				  end else begin
						flatten_fc1_start <= 1'b0;
				  end
			 end
		end

    wire fc1_ready = 1'b1;
    wire fc1_valid;
    wire signed [FC2_OUT_SIZE*ACC_WIDTH-1:0] fc1_out;
    wire [DATA_WIDTH-1:0] fc1_weight_din;
    wire [DATA_WIDTH-1:0] fc1_bias_din;
	 wire [16:0] fc1_weight_addr; // likely 17 bits
    wire [$clog2(FC1_OUT_SIZE)-1:0] fc1_bias_addr;
    wire fc1_weight_en;
    wire [$clog2(FC1_OUT_SIZE)-1:0] fc1_idx;

    fc1w weight_fc1_rom (
        .rdaddress(fc1_weight_addr[15:0]),
        .wraddress(16'b0),
        .clock(clk),
        .data({DATA_WIDTH{1'b0}}),
        .wren(1'b0),
        .q(fc1_weight_din)
    );

    fc1b bias_fc1_rom (
        .clock(clk),
        .data(8'b0),
        .rdaddress(fc1_bias_addr[5:0]),
        .wraddress(6'b0),
        .wren(1'b0),
        .q(fc1_bias_din)
    );

    fc_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .IN_SIZE(((IMG_WIDTH2-2)/2) * ((IMG_WIDTH2-2)/2) * NUM_FILTERS2),
        .OUT_SIZE(FC1_OUT_SIZE)
    ) fc1 (
        .clk(clk),
        .reset(rst_n),
        .start(flatten_fc1_start),
        .valid_in(flatten_fc1_valid_in),
        .data_in(flatten_fc1_data_in),
        .weight_addr(fc1_weight_addr),
        .weight_din(fc1_weight_din),
        .weight_en(fc1_weight_en),
        .bias_addr(fc1_bias_addr),
        .bias_din(fc1_bias_din),
        .valid_out(fc1_valid),
        .out_data(fc1_out),
        .out_idx(fc1_idx),
        .ready_in(fc1_ready)
    );

    // --- Unpack and ReLU on FC1 output ---
    wire signed [ACC_WIDTH-1:0] fc1_out_array [0:FC1_OUT_SIZE-1];
    genvar i;
    generate
        for (i = 0; i < FC1_OUT_SIZE; i = i + 1) begin: fc1_unpack
            assign fc1_out_array[i] = fc1_out[i*ACC_WIDTH +: ACC_WIDTH];
        end
    endgenerate

    wire signed [ACC_WIDTH-1:0] fc1_relu [0:FC1_OUT_SIZE-1];
    generate
        for (i = 0; i < FC1_OUT_SIZE; i = i + 1) begin: relu_fc1
            assign fc1_relu[i] = (fc1_out_array[i] > 0) ? fc1_out_array[i] : 0;
        end
    endgenerate

    // --- FC2 Setup ---
    wire fc2_start = fc1_valid;
    wire fc2_ready = 1'b1;
    reg [$clog2(FC1_OUT_SIZE)-1:0] fc2_in_idx = 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) fc2_in_idx <= 0;
        else if (fc1_valid)
            fc2_in_idx <= (fc2_in_idx == FC1_OUT_SIZE-1) ? 0 : fc2_in_idx + 1;
    end

    wire fc2_valid;
    wire signed [FC2_OUT_SIZE*ACC_WIDTH-1:0] fc2_out;
    wire [DATA_WIDTH-1:0] fc2_weight_din;
    wire [DATA_WIDTH-1:0] fc2_bias_din;
    wire [11:0] fc2_weight_addr;
    wire [5:0] fc2_bias_addr;
    wire fc2_weight_en;
    wire [$clog2(FC2_OUT_SIZE)-1:0] fc2_idx;

    fc2w weight_fc2_rom (
        .rdaddress(fc2_weight_addr[9:0]),
        .wraddress(10'b0),
        .clock(clk),
        .data({DATA_WIDTH{1'b0}}),
        .wren(1'b0),
        .q(fc2_weight_din)
    );

    fc2b bias_fc2_rom (
        .clock(clk),
        .data({DATA_WIDTH{1'b0}}),
        .rdaddress(fc2_bias_addr[3:0]),
        .wraddress(4'b0),
        .wren(1'b0),
        .q(fc2_bias_din)
    );

    fc_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .IN_SIZE(FC1_OUT_SIZE),
        .OUT_SIZE(FC2_OUT_SIZE)
    ) fc2 (
        .clk(clk),
        .reset(rst_n),
        .start(fc2_start),
        .valid_in(fc1_valid),
        .data_in(fc1_relu[fc2_in_idx][7:0]),
        .weight_addr(fc2_weight_addr),
        .weight_din(fc2_weight_din),
        .weight_en(fc2_weight_en),
        .bias_addr(fc2_bias_addr),
        .bias_din(fc2_bias_din),
        .valid_out(fc2_valid),
        .out_data(fc2_out),
        .out_idx(fc2_idx),
        .ready_in(fc2_ready)
    );


    // --- Argmax ---
    wire signed [ACC_WIDTH-1:0] fc2_out_array [0:FC2_OUT_SIZE-1];
    generate
        for (i = 0; i < FC2_OUT_SIZE; i = i + 1) begin: fc2_unpack
            assign fc2_out_array[i] = fc2_out[i*ACC_WIDTH +: ACC_WIDTH];
        end
    endgenerate

    reg [3:0] class_idx;
    integer j;
    always @(*) begin
        class_idx = 0;
        for (j = 1; j < FC2_OUT_SIZE; j = j + 1) begin
            if (fc2_out_array[j] > fc2_out_array[class_idx])
                class_idx = j[3:0];
        end
    end

    assign class_out = class_idx;
    assign valid_out = fc2_valid;

endmodule
