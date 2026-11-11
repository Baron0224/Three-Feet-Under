"""Python stdlib runner; each Godot process has a strict 45-second timeout."""
import os, pathlib, subprocess, sys
project = pathlib.Path(__file__).resolve().parents[1]
exe = os.environ.get("GODOT_BIN", r"D:\Codex\three feet under\Godot\Godot_v4.7.2-stable_win64_console.exe")
failed = False
for test in ["footstep_surface_check", "audio_check", "player_controls_check"]:
    try:
        result = subprocess.run([exe, "--headless", "--path", str(project), "--fixed-fps", "60", "--script", "res://tests/" + test + ".gd"], capture_output=True, timeout=45)
        print(test, "EXIT", result.returncode)
        print((result.stdout + result.stderr).decode("utf-8", errors="replace"))
        failed |= result.returncode != 0
    except subprocess.TimeoutExpired:
        print(test, "TIMEOUT: process terminated")
        failed = True
sys.exit(1 if failed else 0)
