; C[i] = 3*A[i] + B[i], N = 64    A@0  B@64  C@128
    VSPLAT v3, 3
loop:
    VLD   v1, 0
    VLD   v2, 64
    VMUL  v4, v1, v3
    VADD  v5, v4, v2
    VST   v5, 128
    LOOP  loop, 64
    HALT
