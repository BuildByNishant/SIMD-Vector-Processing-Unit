# SIMD Vector Processing Unit

Design and verification of a parameterized SIMD vector processing unit in Verilog.

This repository contains the RTL, assembler, vector workloads, simulation testbenches, saved results, synthesis reports, waveform evidence, local dashboard, and IEEE-format project report. The design runs with 1, 2, 4, 8, or 16 32-bit lanes; the one-lane configuration is used as the scalar cycle-count baseline.

## Team

| Member | Roll number |
|---|---:|
| Mohammed Yaseen | 2401010281 |
| Palwai Tejaswini | 2401010314 |
| Nishant Ranjan Singh | 2401010301 |
| Sankalp M Tellur | 2401010416 |

## Repository contents

```text
rtl/                  Verilog VPU, lane ALU, control, register file and memories
tb/                   Lane-level and system-level testbenches
asm/                  Assembler, vector programs and assembled machine code
scripts/              Simulation, demonstration, waveform and synthesis scripts
results/              Saved simulation results and logs
synth/                Saved selected-module Yosys reports
docs/ISA.md           Instruction-set reference
docs/evidence/        Four-lane vector-add waveform and GTKWave layout
docs/figures/         Architecture and result figures
docs/report/          Final IEEE report PDF and editable LaTeX source
web/                  Optional local project dashboard
```

## Report

- [Final IEEE report (PDF)](docs/report/IEEE_Report_SIMD_VPU_Final.pdf)
- [Editable LaTeX source, bibliography, IEEE class/style files, and figures](docs/report/latex/)

The report includes the contribution matrix.

Build the PDF from the repository root with:

```sh
make -C docs/report/latex
```

The build requires `pdflatex` and `bibtex`.

## Verification and recorded results

The saved logs record 19 passing directed lane-ALU cases and 20 system simulations across four workloads and five lane counts, all with zero output errors.

| Workload | 1 lane | 2 lanes | 4 lanes | 8 lanes | 16 lanes |
|---|---:|---:|---:|---:|---:|
| Vector add | 321 | 161 | 81 | 41 | 21 |
| SAXPY | 386 | 194 | 98 | 50 | 26 |
| Threshold | 322 | 162 | 82 | 42 | 22 |
| Opcode coverage | 241 | 121 | 61 | 31 | 16 |

For vector addition, four lanes complete in 81 cycles versus 321 cycles for one lane, a 3.96x cycle-count speed-up in the saved simulation. These counts use the behavioral vector-wide memory model and do not represent FPGA clock time.

The Yosys files contain mapping statistics for selected modules. They are not a combined top-level utilization report, and no FPGA place-and-route or maximum-frequency result is included.

## Run the project

Install Icarus Verilog (`iverilog` and `vvp`) and Python 3. From the repository root:

```sh
make sim
bash scripts/demo.sh vadd
bash scripts/make_waveform.sh
```

The waveform script creates `build/vadd_L4.vcd`. Open it in GTKWave with:

```sh
gtkwave build/vadd_L4.vcd
```

To open the saved waveform evidence with its signal layout, run:

```sh
gtkwave docs/evidence/vadd_L4.vcd docs/evidence/vadd_L4.gtkw
```

To regenerate the selected-module Yosys reports, install Yosys and run:

```sh
bash scripts/synth_yosys.sh
```

## Local dashboard

The optional dashboard uses Python dependencies from `web/requirements.txt` and the simulation tools listed above:

```sh
python3 -m venv .venv
.venv/bin/pip install -r web/requirements.txt
make web
```

Then open [http://127.0.0.1:8000](http://127.0.0.1:8000).

## Demonstration

[Project demonstration video](https://drive.google.com/drive/folders/1ta-me6U4gf9heQOJn9Y5u-gFhXVNLl5k?usp=drive_link)
