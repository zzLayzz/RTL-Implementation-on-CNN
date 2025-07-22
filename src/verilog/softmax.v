module softmax #(
    parameter ACC_WIDTH=24,
    parameter IN_SIZE=10
)(
    input clk, reset, start,
    input valid_in,
    input signed [ACC_WIDTH-1:0] logit_in,
    input [$clog2(IN_SIZE)-1:0] logit_idx,
    output reg valid_out,
    output reg [$clog2(IN_SIZE)-1:0] class_idx,
    input ready_in
);
    reg signed [ACC_WIDTH-1:0] maxv;
    reg [$clog2(IN_SIZE)-1:0] maxi;
    reg [$clog2(IN_SIZE):0] cnt;
    reg [1:0] state;
    localparam IDLE=0, SCAN=1, OUTP=2;
    always @(posedge clk) begin
        if(reset) begin state<=IDLE; valid_out<=0; end
        else case(state)
          IDLE: if(start) begin cnt<=0; maxv<={1'b1,{ACC_WIDTH-1{1'b0}}}; state<=SCAN; end
          SCAN: if(valid_in && ready_in) begin
                    if(logit_in>maxv) begin maxv<=logit_in; maxi<=logit_idx; end
                    cnt<=cnt+1;
                    if(cnt+1==IN_SIZE) state<=OUTP;
                 end
          OUTP: begin class_idx<=maxi; valid_out<=1; state<=IDLE; end
        endcase
    end
endmodule
