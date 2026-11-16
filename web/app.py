"""Local-only dashboard API for the SIMD VPU project.

The process runner is intentionally closed: callers choose from enumerated actions,
workloads, and lane counts. No request value is ever evaluated as a shell command.
"""
from __future__ import annotations

import asyncio
import csv
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

ROOT = Path(__file__).resolve().parents[1]
STATIC = Path(__file__).resolve().parent / "static"
LANES = (1, 2, 4, 8, 16)
WORKLOADS = {"vadd": 0, "saxpy": 1, "threshold": 2, "opcover": 3}
ARTIFACT_ROOTS = {"results": ROOT / "results", "synth": ROOT / "synth", "build": ROOT / "build", "figures": ROOT / "docs" / "figures"}
RUN_LOCK = asyncio.Lock()

app = FastAPI(title="SIMD Vector Processing Unit", version="1.0.0")


class SimulationRequest(BaseModel):
    workload: str
    lanes: int


class ActionRequest(BaseModel):
    action: str


def read_text(path: Path, limit: int = 250_000) -> str:
    try:
        return path.read_text(errors="replace")[:limit]
    except FileNotFoundError:
        return ""


def benchmark_rows() -> list[dict[str, Any]]:
    path = ROOT / "results" / "results.csv"
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    return [
        {
            "workload": row["workload"],
            "lanes": int(row["lanes"]),
            "cycles": int(row["cycles"]),
            "instructions": int(row["instrs"]),
            "errors": int(row["errors"]),
            "source": "measured",
        }
        for row in rows
    ]


def parse_lane_test() -> dict[str, Any]:
    text = read_text(ROOT / "results" / "lane_alu_test.log")
    match = re.search(r"tests=(\d+) errors=(\d+)\s+(PASS|FAIL)", text)
    if not match:
        return {"tests": 0, "errors": None, "status": "UNKNOWN"}
    return {"tests": int(match.group(1)), "errors": int(match.group(2)), "status": match.group(3)}


CELL_RE = re.compile(r"^\s+([A-Z][A-Z0-9_]+)\s+(\d+)\s*$", re.MULTILINE)


def parse_synthesis_file(path: Path) -> dict[str, Any]:
    text = read_text(path)
    module = re.search(r"===\s+([^=\n]+?)\s+===", text)
    total = re.search(r"Number of cells:\s+(\d+)", text)
    cells = {name: int(value) for name, value in CELL_RE.findall(text)}
    return {
        "name": path.stem.replace("stat_", ""),
        "module": module.group(1) if module else path.stem,
        "total_cells": int(total.group(1)) if total else 0,
        "cells": cells,
        "report": f"synth/{path.name}",
    }


def synthesis_data() -> dict[str, Any]:
    reports = [parse_synthesis_file(path) for path in sorted((ROOT / "synth").glob("stat_*.txt"))]
    logs: list[dict[str, Any]] = []
    for path in sorted((ROOT / "synth").glob("yosys_*.log")):
        content = read_text(path)
        logs.append({
            "name": path.name,
            "path": f"synth/{path.name}",
            "available": bool(content),
            "dependency_error": "command not found" in content,
            "tail": "\n".join(content.splitlines()[-30:]),
        })
    return {"reports": reports, "logs": logs, "scope_note": "Preliminary Xilinx 7-series estimates. Behavioral memories are excluded from these reports."}


def architecture_data() -> dict[str, Any]:
    return {
        "data_width": 32,
        "registers": 8,
        "instruction_width": 32,
        "imem_depth": 256,
        "dmem_depth": 512,
        "cpi": 1,
        "lanes": list(LANES),
        "blocks": ["Program Counter", "Instruction Memory", "Vector Control Unit", "Vector Register File", "Parallel ALU Lanes", "Data Memory"],
        "loop_behavior": "ptr_next = ptr + LANES; branch while ptr_next < loop_limit",
        "memory_model": "One LANES-word-wide vector access per VLD/VST (idealized memory).",
    }


def artifacts() -> list[dict[str, Any]]:
    allowed_suffixes = {".csv", ".log", ".txt", ".vcd", ".png", ".lst", ".hex"}
    items: list[dict[str, Any]] = []
    for key, base in ARTIFACT_ROOTS.items():
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if path.is_file() and path.suffix.lower() in allowed_suffixes:
                rel = path.relative_to(base)
                items.append({
                    "name": path.name,
                    "kind": key,
                    "path": f"{key}/{rel.as_posix()}",
                    "size": path.stat().st_size,
                    "modified": path.stat().st_mtime,
                })
    return items


@app.get("/api/status")
def status() -> dict[str, Any]:
    rows = benchmark_rows()
    lane_test = parse_lane_test()
    errors = sum(row["errors"] for row in rows)
    successful_system = sum(1 for row in rows if row["errors"] == 0)
    newest = max((ROOT / "results" / name for name in ("results.csv", "sim.log", "lane_alu_test.log")), key=lambda p: p.stat().st_mtime if p.exists() else 0)
    return {
        "project": "SIMD Vector Processing Unit",
        "lanes": list(LANES),
        "workloads": list(WORKLOADS),
        "latest_simulation": "PASS" if rows and errors == 0 and lane_test["status"] == "PASS" else "UNKNOWN" if not rows else "FAIL",
        "successful_tests": successful_system + (lane_test["tests"] if lane_test["status"] == "PASS" else 0),
        "system_tests": len(rows),
        "lane_tests": lane_test,
        "updated_at": newest.stat().st_mtime if newest.exists() else None,
        "architecture": architecture_data(),
    }


@app.get("/api/benchmarks")
def benchmarks() -> dict[str, Any]:
    rows = benchmark_rows()
    for row in rows:
        baseline = next((r["cycles"] for r in rows if r["workload"] == row["workload"] and r["lanes"] == 1), None)
        row["speedup"] = round(baseline / row["cycles"], 2) if baseline else None
    return {"rows": rows, "source": "results/results.csv", "method": "Measured by the self-checking Icarus Verilog testbench; ideal LANES-word-wide memory."}


@app.get("/api/synthesis")
def synthesis() -> dict[str, Any]:
    return synthesis_data()


@app.get("/api/artifacts")
def list_artifacts() -> dict[str, Any]:
    return {"items": artifacts()}


@app.get("/api/artifact/{artifact_path:path}")
def get_artifact(artifact_path: str) -> FileResponse:
    head, _, tail = artifact_path.partition("/")
    base = ARTIFACT_ROOTS.get(head)
    if not base or not tail:
        raise HTTPException(404, "Artifact not found")
    target = (base / tail).resolve()
    if base.resolve() not in target.parents or not target.is_file():
        raise HTTPException(404, "Artifact not found")
    return FileResponse(target, filename=target.name)


async def execute(argv: list[str], timeout: int = 180) -> dict[str, Any]:
    started = time.monotonic()
    try:
        proc = await asyncio.create_subprocess_exec(
            *argv,
            cwd=ROOT,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env={**os.environ, "PYTHONUNBUFFERED": "1"},
        )
        output, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        return {"command": " ".join(argv), "exit_code": proc.returncode, "duration": round(time.monotonic() - started, 2), "output": output.decode(errors="replace")[-250_000:]}
    except FileNotFoundError as exc:
        return {"command": " ".join(argv), "exit_code": 127, "duration": round(time.monotonic() - started, 2), "output": str(exc)}
    except asyncio.TimeoutError:
        proc.kill()
        await proc.wait()
        return {"command": " ".join(argv), "exit_code": 124, "duration": round(time.monotonic() - started, 2), "output": f"Timed out after {timeout} seconds."}


@app.post("/api/simulate")
async def simulate(req: SimulationRequest) -> dict[str, Any]:
    workload = req.workload.lower()
    if workload not in WORKLOADS or req.lanes not in LANES:
        raise HTTPException(400, "Unsupported workload or lane count")
    if RUN_LOCK.locked():
        raise HTTPException(409, "Another project command is already running")
    async with RUN_LOCK:
        steps = [
            [sys.executable, "asm/assembler.py", f"asm/{workload}.asm", f"asm/hex/{workload}.hex"],
            ["iverilog", "-g2012", "-P", f"tb_vpu_top.LANES={req.lanes}", "-o", f"build/web_tb_{req.lanes}", "tb/tb_vpu_top.v", *[str(path.relative_to(ROOT)) for path in sorted((ROOT / "rtl").glob("*.v"))]],
            ["vvp", f"build/web_tb_{req.lanes}", f"+WL={WORKLOADS[workload]}", f"+HEX=asm/hex/{workload}.hex", "+VERBOSE"],
        ]
        results = []
        for argv in steps:
            result = await execute(argv, 90)
            results.append(result)
            if result["exit_code"] != 0:
                break
    log = "\n\n".join(f"$ {item['command']}\n{item['output']}" for item in results)
    match = re.search(r"RESULT,([^,]+),(\d+),(\d+),(\d+),(\d+)", log)
    parsed = None
    if match:
        parsed = {"workload": match.group(1), "lanes": int(match.group(2)), "cycles": int(match.group(3)), "instructions": int(match.group(4)), "errors": int(match.group(5))}
    ok = bool(parsed and parsed["errors"] == 0 and all(item["exit_code"] == 0 for item in results))
    return {"status": "PASS" if ok else "FAIL", "result": parsed, "steps": results, "log": log}


@app.post("/api/action")
async def action(req: ActionRequest) -> dict[str, Any]:
    commands = {
        "sim": (["make", "sim"], 240),
        "wave": (["make", "wave"], 180),
        "synth": (["make", "synth"], 240),
        "figures": (["make", "figures"], 180),
    }
    if req.action not in commands:
        raise HTTPException(400, "Unsupported action")
    if RUN_LOCK.locked():
        raise HTTPException(409, "Another project command is already running")
    argv, timeout = commands[req.action]
    async with RUN_LOCK:
        result = await execute(argv, timeout)
    return {"status": "PASS" if result["exit_code"] == 0 else "FAIL", **result}


app.mount("/", StaticFiles(directory=STATIC, html=True), name="static")

