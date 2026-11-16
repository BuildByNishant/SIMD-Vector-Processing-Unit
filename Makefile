.PHONY: sim wave synth figures clean
sim:      ; bash scripts/run_all.sh
wave:     ; bash scripts/make_waveform.sh
synth:    ; bash scripts/synth_yosys.sh
figures:  ; python3 scripts/make_figures.py
clean:    ; rm -rf build
