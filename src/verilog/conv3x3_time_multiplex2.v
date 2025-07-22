`timescale 1ns/1ps

module conv3x3_time_multiplex2 #(
    parameter DATA_WIDTH        = 8,
    parameter ACC_WIDTH         = 24,
    parameter QUANT             = 0,
    parameter IMG_WIDTH         = 28,
    parameter NUM_FILTERS       = 32,
    parameter FILTER_ADDR_WIDTH = 5
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          valid_in,
    input  wire [DATA_WIDTH-1:0]         pixel_in,
    output wire                          valid_out,
    output wire signed [DATA_WIDTH-1:0]  pixel_out
);

    //========================================================================
    // 1) Build the sliding 3x3 window
    //========================================================================
    wire win_v;
    wire [DATA_WIDTH-1:0]
        sw00, sw01, sw02,
        sw10, sw11, sw12,
        sw20, sw21, sw22;

    sliding_window_3x3 #(
      .DATA_WIDTH(DATA_WIDTH),
      .IMG_WIDTH (IMG_WIDTH)
    ) slider (
      .clk       (clk),
      .rst_n     (rst_n),
      .valid_in  (valid_in),
      .pixel_in  (pixel_in),
      .valid_out (win_v),
      .w00       (sw00), .w01(sw01), .w02(sw02),
      .w10       (sw10), .w11(sw11), .w12(sw12),
      .w20       (sw20), .w21(sw21), .w22(sw22)
    );

    //========================================================================
    // 2) Latch window + FSM to step through filters
    //========================================================================
    reg signed [DATA_WIDTH-1:0] rp00, rp01, rp02;
    reg signed [DATA_WIDTH-1:0] rp10, rp11, rp12;
    reg signed [DATA_WIDTH-1:0] rp20, rp21, rp22;

    reg [FILTER_ADDR_WIDTH-1:0] filter_cnt;
    reg [3:0]                   weight_idx; // 0..8 for each tap
    reg                         latched;
    reg                         loading_weights;
    reg                         weights_ready;

    // These regs drive your ROMs:
    reg [14:0] weight_addr; // 9 bits for 512-deep weight ROM!
    reg [5:0] baddr;

    wire [7:0] weight_q;              // 8 bits out from RAM
    reg  [7:0] weights[0:8];          // 9-tap filter storage, 8 bits each

    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        latched         <= 1'b0;
        loading_weights <= 1'b0;
        weights_ready   <= 1'b0;
        filter_cnt      <= 0;
        weight_idx      <= 0;
        weight_addr     <= 0;
        baddr           <= 0;
      end else if (win_v && !latched) begin
        // New 3x3 patch: latch pixels and start loading filter weights
        { rp00, rp01, rp02,
          rp10, rp11, rp12,
          rp20, rp21, rp22 } <=
          { sw00, sw01, sw02,
            sw10, sw11, sw12,
            sw20, sw21, sw22 };
        latched         <= 1'b1;
        loading_weights <= 1'b1;
        weights_ready   <= 1'b0;
        filter_cnt      <= 0;
        weight_idx      <= 0;
        weight_addr     <= 0; // will set below
        baddr           <= 0;
      end else if (loading_weights) begin
        // Read 9 weights for the current filter (one per clock)
        weights[weight_idx] <= weight_q;
        if (weight_idx < 8) begin
          weight_idx  <= weight_idx + 1;
          weight_addr <= filter_cnt * 9 + (weight_idx + 1);
        end else begin
          loading_weights <= 1'b0;
          weights_ready   <= 1'b1;
          weight_idx      <= 0;
        end
      end else if (weights_ready) begin
        // After weights loaded, do convolution
        weights_ready   <= 1'b0;
        baddr          <= filter_cnt;
        if (filter_cnt < NUM_FILTERS - 1) begin
          filter_cnt   <= filter_cnt + 1;
          weight_addr  <= (filter_cnt + 1) * 9;
          loading_weights <= 1'b1;
        end else begin
          latched <= 1'b0;
        end
      end
    end

    //========================================================================
    // 3) Weight ROM: 8 bits wide data, 9 bits address
    //========================================================================
    conv2w weight_rom_inst (
        .address (weight_addr), // 9 bits!
        .clock   (clk),
        .data    (8'b0),
        .wren    (1'b0),
        .q       (weight_q)     // 8 bits!
    );

    //========================================================================
    // 4) Bias ROM: 8 bits per filter
    //========================================================================
    wire [7:0] bias_q;
    wire signed [7:0] bdata;
    assign bdata = bias_q;

    conv2b bias_rom_inst2 (
        .clock      (clk),
        .data       (8'b0),
        .rdaddress  (baddr),
        .wraddress  (6'b0),
        .wren       (1'b0),
        .q          (bias_q)
    );

    //========================================================================
    // 5) Map weights to convolution taps
    //========================================================================
    wire signed [DATA_WIDTH-1:0] kw00 = weights[0];
    wire signed [DATA_WIDTH-1:0] kw01 = weights[1];
    wire signed [DATA_WIDTH-1:0] kw02 = weights[2];
    wire signed [DATA_WIDTH-1:0] kw10 = weights[3];
    wire signed [DATA_WIDTH-1:0] kw11 = weights[4];
    wire signed [DATA_WIDTH-1:0] kw12 = weights[5];
    wire signed [DATA_WIDTH-1:0] kw20 = weights[6];
    wire signed [DATA_WIDTH-1:0] kw21 = weights[7];
    wire signed [DATA_WIDTH-1:0] kw22 = weights[8];

    //========================================================================
    // 6) Single conv3x3_core instantiation
    //========================================================================
    conv3x3_core #(
      .DATA_WIDTH(DATA_WIDTH),
      .ACC_WIDTH (ACC_WIDTH),
      .QUANT     (QUANT)
    ) core (
      .clk       (clk),
      .rst_n     (rst_n),
      .valid_in  (weights_ready), // fire convolution when weights loaded

      .p00       (rp00), .p01(rp01), .p02(rp02),
      .p10       (rp10), .p11(rp11), .p12(rp12),
      .p20       (rp20), .p21(rp21), .p22(rp22),

      .w00       (kw00), .w01(kw01), .w02(kw02),
      .w10       (kw10), .w11(kw11), .w12(kw12),
      .w20       (kw20), .w21(kw21), .w22(kw22),

      .bias      (bdata),

      .valid_out (valid_out),
      .pixel_out (pixel_out)
    );

endmodule
