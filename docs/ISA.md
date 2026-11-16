# SIMD VPU – Instruction Set

32-bit fixed format: `[31:28] opcode | [27:25] vd | [24:22] vs1 | [21:19] vs2 | [18:0] imm`

| Op | Mnemonic | Operation (per lane i) |
|----|----------|------------------------|
| 0  | NOP      | no operation |
| 1  | VADD     | vd[i] = vs1[i] + vs2[i] |
| 2  | VSUB     | vd[i] = vs1[i] - vs2[i] |
| 3  | VAND     | vd[i] = vs1[i] & vs2[i] |
| 4  | VOR      | vd[i] = vs1[i] \| vs2[i] |
| 5  | VXOR     | vd[i] = vs1[i] ^ vs2[i] |
| 6  | VSLL     | vd[i] = vs1[i] << vs2[i][4:0] |
| 7  | VSRL     | vd[i] = vs1[i] >> vs2[i][4:0] (logical) |
| 8  | VMUL     | vd[i] = low 32 bits of vs1[i] * vs2[i] |
| 9  | VCMPEQ   | vd[i] = (vs1[i] == vs2[i]) ? 0xFFFFFFFF : 0 |
| 10 | VCMPLT   | vd[i] = (signed vs1[i] < vs2[i]) ? 0xFFFFFFFF : 0 |
| 11 | VLD vd, imm   | vd = LANES words from dmem[ptr + imm] |
| 12 | VST vs1, imm  | dmem[ptr + imm .. +LANES-1] = vs1 |
| 13 | VSPLAT vd, imm | vd[i] = sign-extended imm (broadcast) |
| 14 | LOOP label, limit | imm[18:10]=target, imm[9:0]=limit. ptr += LANES; if ptr < limit: pc = target, else pc++ and ptr = 0 |
| 15 | HALT     | stop, freeze cycle/instruction counters |

* 8 vector registers v0..v7, each LANES x 32 bits (no hard-wired zero register).
* Execution is single-cycle (CPI = 1); cycles == executed instructions.
* Memory addresses are word addresses; VLD/VST addresses must be LANES-aligned (true for the supplied programs).
