// -----------------------------------------------------------------------------
// vpu_control.v : vector control unit (combinational instruction decoder)
// -----------------------------------------------------------------------------
module vpu_control (
    input  wire [3:0] op,
    output reg        reg_we,     // write vector register file
    output reg        is_vld,     // vector load
    output reg        is_vst,     // vector store
    output reg        is_splat,   // broadcast immediate
    output reg        is_loop,    // strip-mining loop branch
    output reg        is_halt
);
    localparam OP_NOP = 4'd0, OP_VLD = 4'd11, OP_VST = 4'd12,
               OP_VSPLAT = 4'd13, OP_LOOP = 4'd14, OP_HALT = 4'd15;

    always @(*) begin
        reg_we = 1'b0; is_vld = 1'b0; is_vst = 1'b0;
        is_splat = 1'b0; is_loop = 1'b0; is_halt = 1'b0;
        case (op)
            OP_NOP   : ;
            OP_VLD   : begin reg_we = 1'b1; is_vld   = 1'b1; end
            OP_VST   : begin is_vst = 1'b1; end
            OP_VSPLAT: begin reg_we = 1'b1; is_splat = 1'b1; end
            OP_LOOP  : begin is_loop = 1'b1; end
            OP_HALT  : begin is_halt = 1'b1; end
            default  : reg_we = 1'b1;          // opcodes 1..10 : vector ALU ops
        endcase
    end
endmodule
