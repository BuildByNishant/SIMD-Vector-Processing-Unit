// -----------------------------------------------------------------------------
// tb_vpu_top.v : self-checking system testbench for the SIMD VPU
// Plusargs: +WL=<0 vadd | 1 saxpy | 2 threshold | 3 opcover>  +HEX=<hexfile>  [+VCD=<file>]
// Override lane count with:  iverilog -P tb_vpu_top.LANES=8
// Prints one machine-readable line:  RESULT,<workload>,<LANES>,<cycles>,<instrs>,<errors>
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_vpu_top;
    parameter LANES = 4;

    reg clk = 0, rst_n = 0;
    wire halted;
    wire [31:0] cycles, instrs;

    reg         prog_we = 0, h_we = 0;
    reg  [31:0] prog_addr = 0, prog_data = 0, h_addr = 0, h_wdata = 0;
    wire [31:0] h_rdata;
    reg  [31:0] got;

    vpu_top #(.LANES(LANES)) dut (.clk(clk), .rst_n(rst_n),
        .prog_we(prog_we), .prog_addr(prog_addr), .prog_data(prog_data),
        .h_we(h_we), .h_addr(h_addr), .h_wdata(h_wdata), .h_rdata(h_rdata),
        .halted(halted), .cycle_count(cycles), .instr_count(instrs));

    // host-side helpers (drive the real host ports, as a CPU/DMA would)
    reg [31:0] prog_img [0:255];
    initial begin : init_img integer q; for (q=0;q<256;q=q+1) prog_img[q] = 32'hx; end
    task host_write_mem(input integer a, input [31:0] d);
        begin @(negedge clk); h_we = 1; h_addr = a; h_wdata = d; @(negedge clk); h_we = 0; end
    endtask
    task host_load_prog(input integer a, input [31:0] d);
        begin @(negedge clk); prog_we = 1; prog_addr = a; prog_data = d; @(negedge clk); prog_we = 0; end
    endtask
    task host_read_mem(input integer a);
        begin h_addr = a; #1; got = h_rdata; end
    endtask

    always #5 clk = ~clk;

    integer WL, N, i, errors, seed;
    reg [8*128-1:0] hexfile, vcdfile, wlname;
    reg [31:0] A [0:63];
    reg [31:0] B [0:63];
    reg [31:0] exp;

    task chk(input integer addr, input [31:0] e);
        begin
            host_read_mem(addr);
            if (got !== e) begin
                errors = errors + 1;
                if (errors <= 5) $display("MISMATCH wl=%0d mem[%0d] got=%h exp=%h", WL, addr, got, e);
            end
        end
    endtask

    initial begin
        if ($value$plusargs("VCD=%s", vcdfile)) begin
            $dumpfile(vcdfile); $dumpvars(0, tb_vpu_top);
        end
        if (!$value$plusargs("WL=%d", WL))   WL = 0;
        if (!$value$plusargs("HEX=%s", hexfile)) begin $display("need +HEX"); $finish; end
        N = (WL == 3) ? 16 : 64;
        seed = 32'hC0FFEE;
        errors = 0;

        #20;
        // 1) host loads the program through the programming port
        $readmemh(hexfile, prog_img);
        for (i = 0; i < 256; i = i + 1)
            if (^prog_img[i] !== 1'bx) host_load_prog(i, prog_img[i]);
        // 2) host loads operands through the data-memory host port
        for (i = 0; i < N; i = i + 1) begin
            A[i] = (WL == 2) ? ($random(seed) % 2001) : $random(seed);
            B[i] = (WL == 3 && (i % 2 == 0)) ? A[i] : $random(seed);
            host_write_mem(i, A[i]);
            host_write_mem(64 + i, B[i]);
        end
        // 3) release reset -> core runs until HALT
        @(negedge clk) rst_n = 1;
        begin : run
            integer guard; guard = 0;
            while (!halted && guard < 100000) begin @(posedge clk); guard = guard + 1; end
            if (!halted) begin errors = errors + 1; $display("TIMEOUT"); end
        end
        #1;

        for (i = 0; i < N; i = i + 1) begin
            case (WL)
                0: chk(128+i, A[i] + B[i]);
                1: chk(128+i, 32'd3 * A[i] + B[i]);
                2: chk(128+i, ($signed(A[i]) < 1000) ? A[i] : 32'h0);
                3: begin
                    chk(128+i, A[i] - B[i]);
                    chk(144+i, A[i] | B[i]);
                    chk(160+i, A[i] ^ B[i]);
                    chk(176+i, A[i] << B[i][4:0]);
                    chk(192+i, A[i] >> B[i][4:0]);
                    chk(208+i, (A[i] == B[i]) ? 32'hFFFFFFFF : 32'h0);
                end
            endcase
        end

        if ($test$plusargs("VERBOSE")) begin
            $display("  i |    A (in) |    B (in) |   C (DUT) | C (expected)");
            for (i = 0; i < 8; i = i + 1) begin
                host_read_mem(128 + i);
                case (WL)
                    0: exp = A[i] + B[i];
                    1: exp = 32'd3 * A[i] + B[i];
                    2: exp = ($signed(A[i]) < 1000) ? A[i] : 32'h0;
                    default: exp = A[i] - B[i];
                endcase
                $display(" %2d | %h  | %h  | %h  | %h", i, A[i], B[i], got, exp);
            end
        end

        case (WL) 0: wlname="vadd"; 1: wlname="saxpy"; 2: wlname="threshold"; default: wlname="opcover"; endcase
        $display("RESULT,%0s,%0d,%0d,%0d,%0d", wlname, LANES, cycles, instrs, errors);
        $finish;
    end
endmodule
