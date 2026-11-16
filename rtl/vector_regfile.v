// -----------------------------------------------------------------------------
// vector_regfile.v : 8 vector registers, each LANES x 32 bits wide
// 2 asynchronous read ports, 1 synchronous write port.
// -----------------------------------------------------------------------------
module vector_regfile #(
    parameter LANES = 4,
    parameter DW    = 32
)(
    input  wire                  clk,
    input  wire                  we,
    input  wire [2:0]            waddr,
    input  wire [LANES*DW-1:0]   wdata,
    input  wire [2:0]            raddr1,
    input  wire [2:0]            raddr2,
    output wire [LANES*DW-1:0]   rdata1,
    output wire [LANES*DW-1:0]   rdata2
);
    reg [LANES*DW-1:0] regs [0:7];

    integer k;
    initial for (k = 0; k < 8; k = k + 1) regs[k] = {LANES*DW{1'b0}};

    always @(posedge clk)
        if (we) regs[waddr] <= wdata;

    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];
endmodule
