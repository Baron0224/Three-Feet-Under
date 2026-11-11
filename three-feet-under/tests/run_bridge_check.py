"""Run the live curved bridge regression with a strict process timeout."""
import os, pathlib, subprocess, sys
project = pathlib.Path(__file__).resolve().parents[1]
exe = os.environ.get("GODOT_BIN", r"D:\Codex\three feet under\Godot\Godot_v4.7.2-stable_win64_console.exe")
try:
    result = subprocess.run([exe, "--headless", "--path", str(project), "--fixed-fps", "60", "--script", "res://tests/bridge_arch_check.gd"], timeout=45)
    sys.exit(result.returncode)
except subprocess.TimeoutExpired:
    print("Bridge test timed out; process terminated")
    sys.exit(2)
