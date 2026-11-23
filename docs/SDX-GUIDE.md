# SpartaDOS X build

The SDX release image is `disk/mutinrex-sdx-v<VERSION>.atr`. It uses SDFS 2.1
and contains the same BBS programs, data templates and screens as the EOS
image. The communication backends use their native SDX `.COM` names instead
of EOS `.sys` names:

| Backend | SDX command |
|---|---|
| Full-handshake R-Verter | `RVRFULL.COM` |
| Two-wire R-Verter | `RVRTWOW.COM` |
| FujiNet N: | `NHAND.COM` |

Load exactly one backend, then the matched REMMS core and WFC. For example:

```text
D1:RVRFULL.COM
D1:REMMS.COM
D1:WFC.COM
```

Use `RVRTWOW.COM` or `NHAND.COM` in the first line for those interfaces. If
the emulator or another SDX driver already provides R:, omit the first line.

Run `CONFIG.COM` and `INIT.COM` before normal operation. CONFIG writes the
shared `BBS.CFG`; its EOS startup files are not used by SDX. Put the selected
three-command sequence in the SDX startup batch only after configuration and
initialization are complete.

Build both platform images without changing the current product version:

```powershell
python tools/build_all.py --bump none
```

The build validates both filesystems. The automated cold-boot and REMMS
runtime suites currently execute against the EOS image; the SDX image receives
structural SDFS validation and contains the same compiled program binaries.
