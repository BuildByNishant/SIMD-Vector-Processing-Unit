; Exercises every remaining ALU opcode, N = 16. A@0 B@64
; outputs: SUB@128 OR@144 XOR@160 SLL@176 SRL@192 CMPEQ@208 (see tb)
loop:
    VLD    v1, 0
    VLD    v2, 64
    VSUB   v3, v1, v2
    VST    v3, 128
    VOR    v3, v1, v2
    VST    v3, 144
    VXOR   v3, v1, v2
    VST    v3, 160
    VSLL   v3, v1, v2
    VST    v3, 176
    VSRL   v3, v1, v2
    VST    v3, 192
    VCMPEQ v3, v1, v2
    VST    v3, 208
    LOOP   loop, 16
    HALT
