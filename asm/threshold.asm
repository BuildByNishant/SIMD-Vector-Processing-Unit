; C[i] = (A[i] < 1000) ? A[i] : 0 , N = 64   A@0  C@128  (signed compare mask)
    VSPLAT v3, 1000
loop:
    VLD   v1, 0
    VCMPLT v2, v1, v3
    VAND  v4, v1, v2
    VST   v4, 128
    LOOP  loop, 64
    HALT
