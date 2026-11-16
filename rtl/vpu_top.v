// -----------------------------------------------------------------------------
// vpu_top.v : SIMD Vector Processing Unit (top level)
//
//  - LANES parallel 32-bit ALUs (LANES = 1 gives the scalar baseline)
//  - 8 x (LANES*32)-bit vector register file
//  - single-cycle execution (CPI = 1), separate I/D memories
//  - hardware strip-mining loop (LOOP) driven by an element pointer 'ptr'
//
// Instruction format (32 bit):
//   [31:28] opcode | [27:25] vd | [24:22] vs1 | [21:19] vs2 | [18:0] imm
// -----------------------------------------------------------------------------
module vpu_top #(
    parameter LANES      = 4,
    parameter DW         = 32,
    parameter IMEM_DEPTH = 256,
    parameter DMEM_DEPTH = 512
)(
    input  wire        clk,
    input  wire        rst_n,
    // host interface (program load, operand load, result read-back)
    input  wire        prog_we,
    input  wire [31:0] prog_addr,
    input  wire [31:0] prog_data,
    input  wire        h_we,
    input  wire [31:0] h_addr,
    input  wire [DW-1:0] h_wdata,
    output wire [DW-1:0] h_rdata,
    output reg         halted,
    output reg  [31:0] cycle_count,
    output reg  [31:0] instr_count
);
    localparam VW = LANES*DW;

    // ------------------------------------------------------------ fetch
    reg  [31:0] pc;
    reg  [31:0] ptr;                       // element pointer (loop index)
    wire [31:0] instr;

    vpu_imem #(.DEPTH(IMEM_DEPTH)) u_imem (.clk(clk), .addr(pc), .instr(instr),
        .prog_we(prog_we), .prog_addr(prog_addr), .prog_data(prog_data));

    // ------------------------------------------------------------ decode
    wire [3:0]  op  = instr[31:28];
    wire [2:0]  vd  = instr[27:25];
    wire [2:0]  vs1 = instr[24:22];
    wire [2:0]  vs2 = instr[21:19];
    wire [18:0] imm = instr[18:0];

    wire reg_we, is_vld, is_vst, is_splat, is_loop, is_halt;
    vpu_control u_ctrl (.op(op), .reg_we(reg_we), .is_vld(is_vld), .is_vst(is_vst),
                        .is_splat(is_splat), .is_loop(is_loop), .is_halt(is_halt));

    // ------------------------------------------------------------ register file
    wire [VW-1:0] rd1, rd2, wb_data, alu_out, ld_data;

    vector_regfile #(.LANES(LANES), .DW(DW)) u_vrf (
        .clk(clk), .we(reg_we & ~halted & rst_n), .waddr(vd), .wdata(wb_data),
        .raddr1(vs1), .raddr2(vs2), .rdata1(rd1), .rdata2(rd2));

    // ------------------------------------------------------------ SIMD lanes
    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : g_lane
            simd_lane_alu #(.DW(DW)) u_alu (
                .op(op), .a(rd1[i*DW +: DW]), .b(rd2[i*DW +: DW]),
                .y(alu_out[i*DW +: DW]));
        end
    endgenerate

    // ------------------------------------------------------------ memory
    wire [31:0] mem_addr = ptr + {13'b0, imm};
    vpu_dmem #(.LANES(LANES), .DEPTH(DMEM_DEPTH), .DW(DW)) u_dmem (
        .clk(clk), .we(is_vst & ~halted & rst_n), .addr(mem_addr),
        .wdata(rd1), .rdata(ld_data),
        .h_we(h_we), .h_addr(h_addr), .h_wdata(h_wdata), .h_rdata(h_rdata));

    // ------------------------------------------------------------ write-back
    wire [DW-1:0] imm_sext = {{(DW-19){imm[18]}}, imm};
    wire [VW-1:0] splat    = {LANES{imm_sext}};
    assign wb_data = is_vld ? ld_data : (is_splat ? splat : alu_out);

    // ------------------------------------------------------------ PC / loop
    wire [9:0]  loop_limit  = imm[9:0];
    wire [8:0]  loop_target = imm[18:10];
    wire [31:0] ptr_next    = ptr + LANES;
    wire        loop_taken  = is_loop & (ptr_next < {22'b0, loop_limit});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'd0; ptr <= 32'd0; halted <= 1'b0;
            cycle_count <= 32'd0; instr_count <= 32'd0;
        end else if (!halted) begin
            cycle_count <= cycle_count + 1;
            instr_count <= instr_count + 1;
            if (is_halt)         halted <= 1'b1;
            else if (loop_taken) begin pc <= {23'b0, loop_target}; ptr <= ptr_next; end
            else if (is_loop)    begin pc <= pc + 1;               ptr <= 32'd0;   end
            else                 pc <= pc + 1;
        end
    end
endmodule
