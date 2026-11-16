#!/usr/bin/env python3
"""Generate report figures: waveform (from VCD), speed-up plots and block diagram."""
import csv, re, sys, os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Polygon

ROOT = os.path.join(os.path.dirname(__file__), "..")
FIG  = os.path.join(ROOT, "docs", "figures")
os.makedirs(FIG, exist_ok=True)
plt.rcParams.update({"font.family": "serif", "font.size": 8})

# ------------------------------------------------------------------ VCD parsing
def parse_vcd(path, want_scope="tb_vpu_top.dut"):
    ids, scope, vals, t = {}, [], {}, 0
    changes = []
    with open(path) as f:
        header = True
        for line in f:
            line = line.strip()
            if header:
                if line.startswith("$scope"):   scope.append(line.split()[2])
                elif line.startswith("$upscope"): scope.pop()
                elif line.startswith("$var"):
                    p = line.split(); code, name = p[3], p[4]
                    if ".".join(scope) == want_scope and name not in ids.values():
                        ids[code] = name
                elif line.startswith("$enddefinitions"): header = False
                continue
            if not line: continue
            if line[0] == "#": t = int(line[1:]); continue
            if line[0] in "01xz" and len(line) > 1 and line[1:] in ids:
                changes.append((t, ids[line[1:]], line[0]))
            elif line[0] == "b":
                v, code = line[1:].split()
                if code in ids: changes.append((t, ids[code], v))
    return changes

def sample(changes, names, times):
    state = {n: "x" for n in names}; out = []; ci = 0
    for tt in times:
        while ci < len(changes) and changes[ci][0] <= tt:
            if changes[ci][1] in state: state[changes[ci][1]] = changes[ci][2]
            ci += 1
        out.append(dict(state))
    return out

MN = {0:"NOP",1:"VADD",2:"VSUB",3:"VAND",4:"VOR",5:"VXOR",6:"VSLL",7:"VSRL",8:"VMUL",
      9:"VCMPEQ",10:"VCMPLT",11:"VLD",12:"VST",13:"VSPLAT",14:"LOOP",15:"HALT"}

def hexs(b, lo=0, w=32):
    if "x" in b: return "x"
    v = int(b, 2); return f"{(v >> lo) & ((1 << w) - 1):08X}"

def waveform():
    vcd = os.path.join(ROOT, "build", "vadd_L4.vcd")
    ch = parse_vcd(vcd)
    # find reset release time, then sample just before each following rising edge
    rel = next(t for t, n, v in ch if n == "rst_n" and v == "1")
    period = 10000                        # VCD time unit is 1 ps (timescale 1ns/1ps)
    start = rel + 4000                    # just before the first rising edge after reset release
    cyc = [start + period * k for k in range(11)]
    names = ["pc","op","ptr","rd1","rd2","alu_out","wb_data"]
    S = sample(ch, names, cyc)
    fig, ax = plt.subplots(figsize=(7.0, 3.3))
    rows = ["clk","cycle","pc","opcode","ptr","V1[0] (rd1 lane0)","V2[0] (rd2 lane0)","alu_out lane0","alu_out lane1","alu_out lane2","alu_out lane3"]
    n = len(cyc); H = 0.6
    def y(i): return len(rows) - 1 - i
    # clock
    for k in range(n):
        x0 = k
        ax.plot([x0, x0, x0+0.5, x0+0.5, x0+1], [y(0), y(0)+H, y(0)+H, y(0), y(0)], "k", lw=0.8)
    def bus(r, labels, fc="#e8f0fe"):
        prev = None
        for k, lab in enumerate(labels):
            ax.add_patch(plt.Polygon([[k+0.05,y(r)+H/2],[k+0.12,y(r)+H],[k+0.88,y(r)+H],[k+0.95,y(r)+H/2],[k+0.88,y(r)],[k+0.12,y(r)]],
                         closed=True, fc=fc, ec="k", lw=0.5))
            ax.text(k+0.5, y(r)+H/2, lab, ha="center", va="center", fontsize=5.9)
    bus(1, [str(k) for k in range(n)], "#f5f5f5")
    bus(2, [str(int(s["pc"],2)) if "x" not in s["pc"] else "x" for s in S])
    bus(3, [MN[int(s["op"],2)] for s in S], "#fff4d6")
    bus(4, [str(int(s["ptr"],2)) for s in S])
    bus(5, [hexs(s["rd1"],0) for s in S])
    bus(6, [hexs(s["rd2"],0) for s in S])
    for l in range(4):
        bus(7+l, [hexs(s["alu_out"], 32*l) for s in S], "#e6f4ea")
    ax.set_yticks([y(i)+H/2 for i in range(len(rows))]); ax.set_yticklabels(rows, fontsize=8)
    ax.set_xticks([]); ax.set_xlim(0, n); ax.set_ylim(-0.3, len(rows))
    for s in ("top","right","bottom"): ax.spines[s].set_visible(False)
    plt.tight_layout(); plt.savefig(os.path.join(FIG, "waveform.png"), dpi=300); plt.close()

# ------------------------------------------------------------------ results
def results():
    rows = list(csv.DictReader(open(os.path.join(ROOT, "results", "results.csv"))))
    wl = ["vadd","saxpy","threshold","opcover"]
    lanes = sorted({int(r["lanes"]) for r in rows})
    cyc = {(r["workload"], int(r["lanes"])): int(r["cycles"]) for r in rows}
    sp  = {(w, l): cyc[(w,1)] / cyc[(w,l)] for w in wl for l in lanes}
    # speed-up
    fig, ax = plt.subplots(figsize=(3.4, 2.4))
    for w, m in zip(wl, "osd^"):
        ax.plot(lanes, [sp[(w,l)] for l in lanes], marker=m, ms=3.5, lw=1, label=w)
    ax.plot(lanes, lanes, "k--", lw=0.8, label="ideal")
    ax.set_xscale("log", base=2); ax.set_yscale("log", base=2)
    ax.set_xticks(lanes); ax.set_xticklabels(lanes); ax.set_yticks(lanes); ax.set_yticklabels(lanes)
    ax.set_xlabel("SIMD lanes"); ax.set_ylabel("Speed-up vs. 1 lane")
    ax.grid(alpha=0.3); ax.legend(fontsize=6, loc="upper left")
    plt.tight_layout(); plt.savefig(os.path.join(FIG, "speedup.png"), dpi=300); plt.close()
    # cycles
    fig, ax = plt.subplots(figsize=(3.4, 2.3))
    wd = 0.2
    for i, w in enumerate(wl):
        ax.bar([j + (i-1.5)*wd for j in range(len(lanes))], [cyc[(w,l)] for l in lanes], wd, label=w)
    ax.set_yscale("log"); ax.set_xticks(range(len(lanes))); ax.set_xticklabels(lanes)
    ax.set_xlabel("SIMD lanes"); ax.set_ylabel("Execution cycles"); ax.legend(fontsize=6)
    ax.grid(alpha=0.3, axis="y"); plt.tight_layout(); plt.savefig(os.path.join(FIG, "cycles.png"), dpi=300); plt.close()
    with open(os.path.join(ROOT, "results", "speedup.csv"), "w") as f:
        f.write("workload," + ",".join(f"L{l}" for l in lanes) + "\n")
        for w in wl: f.write(w + "," + ",".join(f"{sp[(w,l)]:.2f}" for l in lanes) + "\n")
    print(open(os.path.join(ROOT, "results", "speedup.csv")).read())

# ------------------------------------------------------------------ block diagram
def block_diagram():
    fig, ax = plt.subplots(figsize=(7.0, 3.9)); ax.set_xlim(0, 102); ax.set_ylim(0, 64); ax.axis("off")
    def box(x, y, w, h, t, fc="#e8f0fe", fs=7):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.2,rounding_size=0.8", fc=fc, ec="k", lw=0.8))
        ax.text(x+w/2, y+h/2, t, ha="center", va="center", fontsize=fs)
    def arr(x1, y1, x2, y2, t=None, ls="-", tx=None, ty=None, ha="center"):
        ax.add_patch(FancyArrowPatch((x1,y1),(x2,y2), arrowstyle="-|>", mutation_scale=7, lw=0.8, ls=ls, color="k"))
        if t: ax.text(tx if tx is not None else (x1+x2)/2, ty if ty is not None else (y1+y2)/2+1.2, t, fontsize=5.8, ha=ha)
    def line(xs, ys, ls="-"): ax.plot(xs, ys, "k", lw=0.8, ls=ls)
    # fetch
    box(2, 46, 16, 10, "PC / ptr\n(loop index)", "#fff4d6")
    box(30, 46, 16, 10, "Instruction\nMemory", "#fff4d6")
    box(50, 46, 18, 10, "Vector Control\nUnit (decoder)", "#fde7e9")
    arr(18, 51, 30, 51, "pc", tx=24)
    arr(46, 51, 50, 51)
    # host
    box(2, 26, 16, 10, "Host interface\n(program, operands,\nresults)", "#f0e6ff", fs=6.2)
    line([18, 26], [31, 31]); arr(26, 31, 26, 46)
    ax.text(21.5, 40, "program\nload", fontsize=5.6, ha="center")
    # regfile
    box(30, 16, 16, 18, "Vector\nRegister File\n8 x (LANES*32)b\n2 read / 1 write", "#e8f0fe", fs=6.4)
    arr(38, 46, 38, 34, "vs1, vs2, vd, imm", tx=39.5, ty=39.5, ha="left")
    # lanes
    ax.add_patch(FancyBboxPatch((52, 12), 22, 30, boxstyle="round,pad=0.2,rounding_size=1", fc="#f3fbf4", ec="#2e7d32", lw=1.2, ls="--"))
    ax.text(53, 43.4, "SIMD datapath", ha="left", fontsize=6.5, color="#2e7d32")
    for i, yy in enumerate([34.5, 26.5, 18.5]):
        box(55, yy, 16, 5.5, f"Lane {i}: 32-bit ALU" if i < 2 else "Lane 2: 32-bit ALU", "#e6f4ea", fs=6.3)
    box(55, 13, 16, 4, "Lane N-1: 32-bit ALU", "#e6f4ea", fs=6.0)
    ax.text(63, 17.9, "...", ha="center", fontsize=8)
    arr(46, 27, 52, 27, "A, B", tx=49, ty=28.2)
    arr(59, 46, 59, 42, "alu_op", tx=63, ty=43.8, ha="left") if False else None
    arr(70, 46, 70, 42.4, "alu_op", ls="--", tx=71.5, ty=44, ha="left")
    # write-back
    box(82, 21, 15, 11, "Write-back MUX\nALU / VLD / SPLAT", "#fde7e9", fs=6.2)
    arr(74, 27, 82, 27)
    line([89.5, 89.5, 38], [21, 9, 9]); arr(38, 9, 38, 16)
    ax.text(64, 7.4, "wb_data -> vd (vector register write-back)", fontsize=5.8, ha="center")
    # data memory
    box(82, 44, 15, 12, "Data Memory\n(LANES-word wide\nport + host port)", "#fff4d6", fs=6.0)
    arr(89.5, 44, 89.5, 32, "VLD", tx=92, ty=38, ha="left")
    line([42, 42, 100, 100], [16, 3.5, 3.5, 50]); arr(100, 50, 97, 50)
    ax.text(64, 1.8, "VST: vs1 -> data memory", fontsize=5.8, ha="center")
    # loop control
    line([59, 59, 10], [56, 60, 60], ls="--"); arr(10, 60, 10, 56, ls="--")
    ax.text(34, 61.2, "LOOP: ptr += LANES, branch to target while ptr < limit", fontsize=5.8, ha="center")
    plt.tight_layout(); plt.savefig(os.path.join(FIG, "block_diagram.png"), dpi=300); plt.close()


def concept():
    fig, ax = plt.subplots(figsize=(7.0, 3.2)); ax.set_xlim(0, 100); ax.set_ylim(0, 46); ax.axis("off")
    def box(x, y, w, h, t, fc, fs=7.5, ec="k"):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.2,rounding_size=0.8", fc=fc, ec=ec, lw=0.9))
        ax.text(x+w/2, y+h/2, t, ha="center", va="center", fontsize=fs)
    ax.text(24, 43, "Scalar: 1 element per instruction", ha="center", fontsize=9, fontweight="bold")
    for i in range(4):
        box(2, 31 - i*8, 17, 6, f"ADD  a[{i}] + b[{i}]", "#fde7e9")
        ax.text(21, 34 - i*8, f"cycle {i+1}", fontsize=7, va="center")
    ax.text(24, 3, "4 instructions, 4 cycles", ha="center", fontsize=8.5)
    ax.plot([50, 50], [2, 44], "k", lw=0.6, ls=":")
    ax.text(75, 43, "SIMD (4 lanes): 4 elements per instruction", ha="center", fontsize=9, fontweight="bold")
    box(53, 34, 44, 6, "VADD v3, v1, v2      (ONE instruction)", "#fff4d6", fs=8)
    for i in range(4):
        x = 53 + i*11.3
        ax.add_patch(FancyArrowPatch((x+5, 34), (x+5, 27), arrowstyle="-|>", mutation_scale=7, lw=0.8))
        box(x, 19, 10, 8, f"Lane {i}\nALU", "#e6f4ea", fs=7)
        ax.text(x+5, 16, f"a[{i}]+b[{i}]", ha="center", fontsize=6.8)
    ax.text(75, 9.5, "all lanes work in the same clock cycle", ha="center", fontsize=8, color="#2e7d32")
    ax.text(75, 3, "1 instruction, 1 cycle  ->  up to 4x faster", ha="center", fontsize=8.5)
    plt.tight_layout(); plt.savefig(os.path.join(FIG, "simd_concept.png"), dpi=300); plt.close()

if __name__ == "__main__":
    waveform(); results(); block_diagram(); concept()
