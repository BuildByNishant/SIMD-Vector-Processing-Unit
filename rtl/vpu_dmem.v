// -----------------------------------------------------------------------------
// vpu_dmem.v : data memory with a LANES-word wide port
// Reads / writes LANES consecutive 32-bit words starting at 'addr'
// (one full vector per access).
// -----------------------------------------------------------------------------
module vpu_dmem #(
    parameter LANES = 4,
    parameter DEPTH = 512,
    parameter DW    = 32
)(
    input  wire                  clk,
    input  wire                  we,
    input  wire [31:0]           addr,
    input  wire [LANES*DW-1:0]   wdata,
    output wire [LANES*DW-1:0]   rdata,
    // host port (single 32-bit word) : load operands / read back results
    input  wire                  h_we,
    input  wire [31:0]           h_addr,
    input  wire [DW-1:0]         h_wdata,
    output wire [DW-1:0]         h_rdata
);
    localparam AW = $clog2(DEPTH);
    reg [DW-1:0] mem [0:DEPTH-1];

    integer k;
    initial for (k = 0; k < DEPTH; k = k + 1) mem[k] = {DW{1'b0}};

    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : g_rd
            assign rdata[i*DW +: DW] = mem[(addr[AW-1:0] + i) % DEPTH];
        end
    endgenerate

    integer j;
    assign h_rdata = mem[h_addr[AW-1:0]];

    always @(posedge clk)
        if (we)                                   // vector store (core)
            for (j = 0; j < LANES; j = j + 1)
                mem[(addr[AW-1:0] + j) % DEPTH] <= wdata[j*DW +: DW];
        else if (h_we)                            // host write (core idle/halted)
            mem[h_addr[AW-1:0]] <= h_wdata;
endmodule
