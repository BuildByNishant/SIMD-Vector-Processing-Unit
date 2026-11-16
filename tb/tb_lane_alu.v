// Directed unit test of one SIMD lane (corner cases for every opcode)
`timescale 1ns/1ps
module tb_lane_alu;
    reg  [3:0]  op;
    reg  [31:0] a, b;
    wire [31:0] y;
    integer errors = 0, tests = 0;

    simd_lane_alu #(.DW(32)) dut (.op(op), .a(a), .b(b), .y(y));

    task check(input [3:0] o, input [31:0] x, input [31:0] z, input [31:0] exp);
        begin
            op = o; a = x; b = z; #1; tests = tests + 1;
            if (y !== exp) begin
                errors = errors + 1;
                $display("FAIL op=%0d a=%h b=%h got=%h exp=%h", o, x, z, y, exp);
            end
        end
    endtask

    initial begin
        check(4'd1, 32'h7FFFFFFF, 32'h1,        32'h80000000);   // ADD overflow wrap
        check(4'd1, 32'hFFFFFFFF, 32'h1,        32'h0);          // ADD carry out
        check(4'd2, 32'h0,        32'h1,        32'hFFFFFFFF);   // SUB borrow
        check(4'd2, 32'h80000000, 32'h1,        32'h7FFFFFFF);
        check(4'd3, 32'hF0F0F0F0, 32'h0FF00FF0, 32'h00F000F0);   // AND
        check(4'd4, 32'hF0F0F0F0, 32'h0FF00FF0, 32'hFFF0FFF0);   // OR
        check(4'd5, 32'hAAAAAAAA, 32'hFFFFFFFF, 32'h55555555);   // XOR
        check(4'd6, 32'h1,        32'd31,       32'h80000000);   // SLL by 31
        check(4'd6, 32'h1,        32'd32,       32'h1);          // shamt uses b[4:0]
        check(4'd7, 32'h80000000, 32'd31,       32'h1);          // SRL logical
        check(4'd8, 32'd1000,     32'd1000,     32'd1000000);    // MUL
        check(4'd8, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'h1);          // (-1)*(-1) low word
        check(4'd8, 32'h10000,    32'h10000,    32'h0);          // overflow wraps to 0
        check(4'd9, 32'h1234,     32'h1234,     32'hFFFFFFFF);   // CMPEQ true
        check(4'd9, 32'h1234,     32'h1235,     32'h0);          // CMPEQ false
        check(4'd10, 32'hFFFFFFFF, 32'h1,       32'hFFFFFFFF);   // CMPLT signed: -1 < 1
        check(4'd10, 32'h1,        32'hFFFFFFFF, 32'h0);         // 1 < -1 false
        check(4'd10, 32'h80000000, 32'h7FFFFFFF, 32'hFFFFFFFF);  // INT_MIN < INT_MAX
        check(4'd0,  32'h5,        32'h5,        32'h0);         // NOP/default -> 0
        $display("LANE_ALU_TEST tests=%0d errors=%0d %s", tests, errors, errors==0 ? "PASS" : "FAIL");
        $finish;
    end
endmodule
