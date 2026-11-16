#!/usr/bin/env python3
"""Tiny assembler for the SIMD VPU ISA.  Usage: assembler.py prog.asm out.hex"""
import sys, re

OPS = {"NOP":0,"VADD":1,"VSUB":2,"VAND":3,"VOR":4,"VXOR":5,"VSLL":6,"VSRL":7,
       "VMUL":8,"VCMPEQ":9,"VCMPLT":10,"VLD":11,"VST":12,"VSPLAT":13,"LOOP":14,"HALT":15}
ALU = {"VADD","VSUB","VAND","VOR","VXOR","VSLL","VSRL","VMUL","VCMPEQ","VCMPLT"}

def reg(tok):
    m = re.fullmatch(r"[vV]([0-7])", tok.strip())
    if not m: raise ValueError(f"bad register '{tok}'")
    return int(m.group(1))

def assemble(lines):
    # pass 1: labels
    labels, prog, pc = {}, [], 0
    for raw in lines:
        line = re.split(r"[;#]", raw)[0].strip()
        if not line: continue
        if line.endswith(":"):
            labels[line[:-1]] = pc; continue
        prog.append(line); pc += 1
    words, listing = [], []
    for pc, line in enumerate(prog):
        mn, _, rest = line.partition(" ")
        mn = mn.upper(); args = [a.strip() for a in rest.split(",")] if rest.strip() else []
        op = OPS[mn]; vd = vs1 = vs2 = imm = 0
        if mn in ALU:
            vd, vs1, vs2 = reg(args[0]), reg(args[1]), reg(args[2])
        elif mn == "VLD":
            vd, imm = reg(args[0]), int(args[1], 0)
        elif mn == "VST":
            vs1, imm = reg(args[0]), int(args[1], 0)
        elif mn == "VSPLAT":
            vd, imm = reg(args[0]), int(args[1], 0) & 0x7FFFF
        elif mn == "LOOP":
            tgt = labels[args[0]]; lim = int(args[1], 0)
            assert tgt < 512 and lim < 1024
            imm = (tgt << 10) | lim
        w = (op << 28) | (vd << 25) | (vs1 << 22) | (vs2 << 19) | (imm & 0x7FFFF)
        words.append(w); listing.append(f"{pc:03d}: {w:08x}  {line}")
    return words, listing

if __name__ == "__main__":
    src, out = sys.argv[1], sys.argv[2]
    words, listing = assemble(open(src).read().splitlines())
    open(out, "w").write("\n".join(f"{w:08x}" for w in words) + "\n")
    open(out.replace(".hex", ".lst"), "w").write("\n".join(listing) + "\n")
    print(f"{src}: {len(words)} instructions -> {out}")
