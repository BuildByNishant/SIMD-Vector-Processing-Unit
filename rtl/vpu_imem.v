// -----------------------------------------------------------------------------
// vpu_imem.v : instruction memory (Harvard-style, separate from data memory)
// Written through the host programming port (simulation may also use $readmemh).
// -----------------------------------------------------------------------------
module vpu_imem #(
    parameter DEPTH = 256
)(
    input  wire        clk,
    input  wire [31:0] addr,
    output wire [31:0] instr,
    // host programming port
    input  wire        prog_we,
    input  wire [31:0] prog_addr,
    input  wire [31:0] prog_data
);
    reg [31:0] mem [0:DEPTH-1];
    integer k;
    initial for (k = 0; k < DEPTH; k = k + 1) mem[k] = 32'h0;   // NOP fill
    always @(posedge clk)
        if (prog_we) mem[prog_addr[$clog2(DEPTH)-1:0]] <= prog_data;

    assign instr = mem[addr[$clog2(DEPTH)-1:0]];
endmodule
