module relu #(
    parameter DATA_WIDTH = 8
)(
    input clk, rst_n,
    input valid_in,
    input signed [DATA_WIDTH-1:0] data_in,
    output reg valid_out,
    output reg [DATA_WIDTH-1:0] data_out
);
    always @(posedge clk) begin
        if (rst_n) begin valid_out<=0; data_out<=0; end
        else begin
            valid_out <= valid_in;
            data_out  <= (data_in[DATA_WIDTH-1]?0:data_in);
        end
    end
endmodule