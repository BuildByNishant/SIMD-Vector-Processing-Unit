; C[i] = A[i] + B[i], N = 64      A@0  B@64  C@128
loop:
    VLD   v1, 0
    VLD   v2, 64
    VADD  v3, v1, v2
    VST   v3, 128
    LOOP  loop, 64
    HALT
