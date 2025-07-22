`timescale 1ns/1ps

module tb_weight_bias_roms;

  reg clk;
  reg [8:0] weight_addr;   // 9 bits for up to 512 weights
  reg [4:0] bias_addr;     // 5 bits for up to 32 biases

  wire [7:0] weight_q;
  wire [7:0] bias_q;

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  // Instantiate your RAMs
  weight weight_rom_inst (
    .address (weight_addr),
    .clock   (clk),
    .data    (8'b0),
    .wren    (1'b0),
    .q       (weight_q)
  );

  bias bias_rom_inst (
    .clock      (clk),
    .data       (8'b0),
    .rdaddress  (bias_addr),
    .wraddress  (5'b0),
    .wren       (1'b0),
    .q          (bias_q)
  );

  integer i;
  initial begin
    // Wait for the first clock edge
    weight_addr = 0;
    bias_addr   = 0;
    #10;

    $display("\n=== Testing WEIGHT ROM ===");
    // Show the first 20 weights
    for (i = 0; i < 20; i = i + 1) begin
      weight_addr = i;
      #10;
      $display("weight_addr = %0d, weight_q = 0x%02h", weight_addr, weight_q);
    end

    $display("\n=== Testing BIAS ROM ===");
    // Show all 32 bias values
    for (i = 0; i < 32; i = i + 1) begin
      bias_addr = i;
      #10;
      $display("bias_addr = %0d, bias_q = 0x%02h", bias_addr, bias_q);
    end

    $finish;
  end

endmodule
