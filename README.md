# SIMD Vector Processing Unit

**Design and Verification of a Parameterized SIMD Vector Processing Unit in Verilog**
Modern Computer Architecture (CSA-222) – MCA project demonstration

A parameterized SIMD Vector Processing Unit (VPU) with `LANES` parallel 32-bit ALUs, an 8-entry vector
register file, a 16-instruction vector ISA and a hardware strip-mining `LOOP` instruction.
`LANES = 1` is the scalar baseline; 1, 2, 4, 8 and 16 lanes are verified in simulation.

The repository also includes a polished local web dashboard for exploring the architecture, running the
real Icarus Verilog testbench, comparing measured performance and inspecting generated synthesis and
waveform artifacts.

## Highlights

- Parameterized 1, 2, 4, 8 and 16-lane SIMD datapath.
- Fixed-width 32-bit vector ISA with 16 opcodes and hardware strip-mining.
- Four verified workloads: VADD, SAXPY, Threshold and OPCOVER.
- 20 passing system configurations and 19 passing lane-ALU corner cases.
- Up to 15.29x measured cycle speedup at 16 lanes over the scalar baseline.
- Interactive local dashboard backed by real repository results and allowlisted tool execution.

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
web/       FastAPI backend and responsive local engineering dashboard
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

For the interactive demonstration, install the small web dependency set and run `make web`; complete
instructions are provided in [Local web dashboard](#local-web-dashboard).

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

## Local web dashboard

The `web/` directory contains a local FastAPI application and a dependency-free frontend for presenting and operating the project. It reads the repository's measured CSV data, synthesis reports, logs, figures, and VCD artifacts. The Simulation Lab invokes the existing assembler and testbench with an allowlisted workload and lane count; it never accepts an arbitrary command from the browser.

### Setup

Prerequisites are Python 3, Icarus Verilog (`iverilog` and `vvp`), and the tools already listed above. Yosys is optional unless you want to regenerate synthesis reports.

```bash
python3 -m venv .venv
.venv/bin/pip install -r web/requirements.txt
```

### Launch

```bash
make web
```

Open [http://127.0.0.1:8000](http://127.0.0.1:8000). Keep this process running while using the dashboard.

The pages provide:

- Overview metrics parsed from `results/` and `synth/`.
- An interactive RTL-accurate architecture view for 1, 2, 4, 8, and 16 lanes.
- Real workload/lane simulation with captured compiler and testbench output.
- Measured cycles and speedup charts from `results/results.csv`.
- Stored Yosys resource summaries and actual synthesis logs.
- Generated figures, raw VCD waveforms, reports, and result downloads.

### Verify from the terminal

```bash
make sim                 # 19 lane-ALU cases + 20 system configurations
make wave                # regenerate build/vadd_L4.vcd and report figures
make figures             # regenerate charts from current measured results
```

`make synth` requires Yosys. If it is unavailable, the dashboard reports the real dependency error and continues to show the existing stored `stat_*.txt` resource estimates without presenting them as a new synthesis run.

### Troubleshooting

- If `make wave` reports `No module named 'matplotlib'`, rerun `.venv/bin/pip install -r web/requirements.txt`. Figure generation automatically uses the project virtual environment when it exists.
- On macOS, install Yosys with `brew install yosys` before running `make synth`.
- Simulation and Make operations are serialized by the local backend. If requests arrive together, they wait and run safely in order rather than modifying shared build artifacts concurrently.
