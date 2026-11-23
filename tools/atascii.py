"""Convert Atari ATASCII text files to editable PC text and back.

Usage:
  python atascii.py totext  ATARI_FILE  TEXT_FILE
  python atascii.py toatari TEXT_FILE   ATARI_FILE

Text format:
  - Each ATASCII end of line (155, $9B) is a line break.
  - Printable characters (space to ~) are written as they are.
  - {i}...{/i} surrounds inverse video text (characters with bit 7 set).
  - Any other byte is written as {XX}, its code in hexadecimal,
    for example {7D} = clear screen, {FD} = buzzer, {1C} = cursor up.
  - {XX*N} is the byte XX repeated N times (N in decimal), for example
    {12*38} is a line of 38 horizontal bars.
  - The braces themselves are written {7B} and {7D}.
  - A file that does not end with an EOL ends with {NOEOL}.
"""
import re
import sys


def plain(c):
    return 0x20 <= c < 0x7F and c not in (0x7B, 0x7D)


def to_text(data):
    out = []
    inv = False
    for c in data:
        if c >= 0x80 and c != 0x9B and plain(c & 0x7F):
            if not inv:
                out.append("{i}")
                inv = True
            out.append(chr(c & 0x7F))
            continue
        if inv:
            out.append("{/i}")
            inv = False
        if c == 0x9B:
            out.append("\n")
        elif plain(c):
            out.append(chr(c))
        else:
            out.append("{%02X}" % c)
    if inv:
        out.append("{/i}")
    text = re.sub(r"(\{[0-9A-F]{2}\})\1{2,}",
                  lambda m: "%s*%d}" % (m.group(1)[:-1], len(m.group(0)) // 4),  # noqa
                  "".join(out))
    if data and data[-1] != 0x9B:
        text += "{NOEOL}"
    return text


def to_atari(text):
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    noeol = False
    if text.endswith("{NOEOL}") or text.endswith("{NOEOL}\n"):
        text = text[: text.rindex("{NOEOL}")]
        noeol = True
    out = bytearray()
    inv = False
    pos = 0
    token = re.compile(r"\{(i|/i|[0-9A-Fa-f]{2})(?:\*(\d+))?\}")
    while pos < len(text):
        m = token.match(text, pos)
        if m:
            t = m.group(1)
            if t == "i":
                inv = True
            elif t == "/i":
                inv = False
            else:
                out.extend([int(t, 16)] * int(m.group(2) or 1))
            pos = m.end()
            continue
        ch = text[pos]
        pos += 1
        if ch == "\n":
            out.append(0x9B)
            continue
        c = ord(ch)
        if c > 0x7F:
            raise ValueError("character %r is not ATASCII; use {XX}" % ch)
        out.append(c | 0x80 if inv else c)
    if noeol and out and out[-1] == 0x9B:
        out.pop()
    return bytes(out)


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("totext", "toatari"):
        print(__doc__)
        sys.exit(1)
    mode, src, dst = sys.argv[1:]
    if mode == "totext":
        data = open(src, "rb").read()
        open(dst, "w", encoding="ascii", newline="\n").write(to_text(data))
    else:
        text = open(src, "r", encoding="ascii").read()
        open(dst, "wb").write(to_atari(text))


if __name__ == "__main__":
    main()
