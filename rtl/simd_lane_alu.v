// -----------------------------------------------------------------------------
// simd_lane_alu.v : one 32-bit SIMD lane (integer ALU)
// Opcode numbering is shared with the VPU ISA (see docs/ISA.md).
// -----------------------------------------------------------------------------
module simd_lane_alu #(
    parameter DW = 32
)(
    input  wire [3:0]       op,
    input  wire [DW-1:0]    a,
    input  wire [DW-1:0]    b,
    output reg  [DW-1:0]    y
);
    localparam OP_VADD   = 4'd1,  OP_VSUB   = 4'd2,  OP_VAND   = 4'd3,
               OP_VOR    = 4'd4,  OP_VXOR   = 4'd5,  OP_VSLL   = 4'd6,
               OP_VSRL   = 4'd7,  OP_VMUL   = 4'd8,  OP_VCMPEQ = 4'd9,
               OP_VCMPLT = 4'd10;

    wire [2*DW-1:0] mul_full = a * b;              // low half kept (wrap-around)

    always @(*) begin
        case (op)
            OP_VADD  : y = a + b;
            OP_VSUB  : y = a - b;
            OP_VAND  : y = a & b;
            OP_VOR   : y = a | b;
            OP_VXOR  : y = a ^ b;
            OP_VSLL  : y = a << b[4:0];
            OP_VSRL  : y = a >> b[4:0];
            OP_VMUL  : y = mul_full[DW-1:0];
            OP_VCMPEQ: y = (a == b)                  ? {DW{1'b1}} : {DW{1'b0}};
            OP_VCMPLT: y = ($signed(a) < $signed(b)) ? {DW{1'b1}} : {DW{1'b0}};
            default  : y = {DW{1'b0}};
        endcase
    end
endmodule
