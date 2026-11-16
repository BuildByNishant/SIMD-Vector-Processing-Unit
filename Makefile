.PHONY: sim wave synth figures web clean
sim:      ; bash scripts/run_all.sh
wave:     ; bash scripts/make_waveform.sh
synth:    ; bash scripts/synth_yosys.sh
figures:  ; python3 scripts/make_figures.py
web:      ; .venv/bin/uvicorn web.app:app --host 127.0.0.1 --port 8000
clean:    ; rm -rf build
