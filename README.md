# SIMD Vector Processing Unit in Verilog

**Design and Verification of a Parameterized SIMD Vector Processing Unit in Verilog**
Modern Computer Architecture (CSA-222) – B.Tech (CS&AI) – Phase I submission

A parameterized SIMD Vector Processing Unit (VPU) with `LANES` parallel 32-bit ALUs, an 8-entry vector
register file, a 16-instruction vector ISA and a hardware strip-mining `LOOP` instruction.
`LANES = 1` is the scalar baseline; 1, 2, 4, 8 and 16 lanes are verified in simulation.

## Team

| Member | Roll No. |
|--------|----------|
| Mohammed Yaseen | 2401010281 |
| Palwai Tejaswini | 2401010314 |
| Nishant Ranjan Singh | 2401010301 |
| Sankalp M Tellur | 2401010416 |


## Phase I deliverables
| Deliverable | Where |
|-------------|-------|
| IEEE report (PDF) | [`docs/report/IEEE_Report_SIMD_VPU_Phase1.pdf`](docs/report/IEEE_Report_SIMD_VPU_Phase1.pdf) |
| IEEE report (LaTeX source) | [`docs/report/latex/`](docs/report/latex/) |
| Prototype video | [`Google Drive Link`](https://drive.google.com/drive/folders/1ta-me6U4gf9heQOJn9Y5u-gFhXVNLl5k?usp=drive_link) |
| Prototype (RTL, testbenches, assembler, scripts) | `rtl/`, `tb/`, `asm/`, `scripts/` |

## Repository layout
```
rtl/       simd_lane_alu.v  vector_regfile.v  vpu_control.v  vpu_imem.v  vpu_dmem.v  vpu_top.v
tb/        tb_lane_alu.v (directed unit test)   tb_vpu_top.v (self-checking system testbench)
asm/       assembler.py, vadd.asm  saxpy.asm  threshold.asm  opcover.asm, hex/ (assembled output)
scripts/   run_all.sh  demo.sh  make_waveform.sh  make_figures.py  synth_yosys.sh
results/   results.csv  speedup.csv  lane_alu_test.log  sim.log
synth/     preliminary Yosys resource reports
docs/      report/ (PDF + LaTeX), figures/, ISA.md
.github/   CI workflow (runs all simulations on every push)
```

## Quick start
Requires Icarus Verilog (`iverilog`, `vvp`), Python 3 and matplotlib. Optional: GTKWave, Yosys.
```bash
make sim                      # unit test + 4 workloads x 5 lane counts -> results/results.csv ("ALL TESTS PASSED")
bash scripts/demo.sh vadd     # step-by-step demo: assemble, run on 1/4/8 lanes, results + speed-up table
bash scripts/make_waveform.sh # writes build/vadd_L4.vcd and regenerates figures (open VCD in GTKWave)
bash scripts/synth_yosys.sh   # preliminary Xilinx 7-series estimates for the datapath blocks
```

## Phase I results (simulation, cycles)
| Workload | 1 lane | 2 | 4 | 8 | 16 |
|----------|-------:|--:|--:|--:|---:|
| vadd | 321 | 161 | 81 | 41 | 21 |
| saxpy | 386 | 194 | 98 | 50 | 26 |
| threshold | 322 | 162 | 82 | 42 | 22 |
| opcover | 241 | 121 | 61 | 31 | 16 |

Speed-up over the 1-lane baseline: ~2.0x (2 lanes), 3.9–4.0x (4), 7.7–7.8x (8), 14.6–15.3x (16).
All 20 system simulations and 19 lane-ALU corner cases pass. Results assume an ideal LANES-word-wide memory.

## Status
- [x] Vector ISA, RTL, assembler, directed + system testbenches, fault-injection check, CI
- [x] Scalar-vs-SIMD cycle comparison, preliminary Yosys resource estimates
- [ ] Phase II: Vivado utilization + Fmax, banked BRAM memory, masking / sub-word elements, more kernels
