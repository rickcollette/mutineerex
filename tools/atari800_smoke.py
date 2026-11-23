"""Drive the bundled headless Atari800 JSON helper for repeatable smoke tests."""
import argparse
import base64
import json
import os
import subprocess
import sys

from PIL import Image


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_EMU_CANDIDATES = (
    os.path.join(r"C:\Program Files\exBASIC Studio Contributors\exBASIC Studio",
                 "tools", "atari800-studio.exe"),
    os.path.expandvars(
        r"%LOCALAPPDATA%\Programs\exBASIC Studio\tools\atari800-studio.exe"),
    os.path.expandvars(
        r"%LOCALAPPDATA%\Programs\exBASIC Studio personal-rick\tools\atari800-studio.exe"),
)
EMU = next((candidate for candidate in _EMU_CANDIDATES
            if os.path.isfile(candidate)), _EMU_CANDIDATES[0])


class Emulator:
    def __init__(self, image, memory=64):
        args = [EMU, "-machine", "xl", "-memory", str(memory), "-ntsc",
                "-nobasic", "-eos", os.path.join(ROOT, "EOS.car"),
                "-drive1", image, "-turbo"]
        self.process = subprocess.Popen(
            args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
        self.ident = 0
        self.rgb = None

    def request(self, op):
        self.ident += 1
        op["id"] = self.ident
        # The helper's keyboard parser looks for the compact literal
        # `"key":"..."`; default json.dumps spaces make it silently map to 0.
        self.process.stdin.write(json.dumps(op, separators=(",", ":")) + "\n")
        self.process.stdin.flush()
        while True:
            line = self.process.stdout.readline()
            if not line:
                raise RuntimeError("emulator JSON helper stopped")
            try:
                reply = json.loads(line)
                break
            except json.JSONDecodeError:
                continue
        pending = [reply]
        while pending:
            payload = pending.pop()
            if isinstance(payload, dict):
                pending.extend(payload.values())
                continue
            if isinstance(payload, list):
                pending.extend(payload)
                continue
            if not isinstance(payload, str):
                continue
            try:
                raw = base64.b64decode(payload)
                if len(raw) == 336 * 240 * 3:
                    self.rgb = raw
                    break
            except ValueError:
                pass
        if reply.get("ok") is False or "error" in reply:
            print(reply, file=sys.stderr)
        return reply

    def frames(self, count):
        for _ in range(count):
            self.request({"op": "frame"})

    def key(self, name):
        self.request({"op": "key", "key": name, "down": True})
        self.frames(2)
        self.request({"op": "key", "key": name, "down": False})
        self.frames(3)

    def text(self, value):
        for char in value:
            self.key(char.upper())

    def save(self, output):
        if self.rgb is None:
            raise RuntimeError("no RGB frame received")
        Image.frombytes("RGB", (336, 240), self.rgb).save(output)

    def close(self):
        self.process.terminate()
        self.process.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("output")
    parser.add_argument("--boot-frames", type=int, default=360)
    parser.add_argument("--memory", type=int, default=64,
                        help="Atari RAM in KB (use 320 for EOS RAMDISK tests)")
    parser.add_argument("--command")
    parser.add_argument("--after-frames", type=int, default=240)
    args = parser.parse_args()

    emu = Emulator(os.path.abspath(args.image), args.memory)
    try:
        emu.frames(args.boot_frames)
        if args.command:
            emu.text(args.command)
            emu.key("Enter")
            emu.frames(args.after_frames)
        emu.save(args.output)
    finally:
        emu.close()


if __name__ == "__main__":
    main()
