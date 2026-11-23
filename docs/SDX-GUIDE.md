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
shared `BBS.CFG`. RDCONF detects `SDX.ENV` and writes an SDX-native
`AUTOEXEC.BAT`; it does not write EOS startup files. With RAM cache enabled,
every selected `RAMCACHE.CFG` source has an explicit `DO:` runtime target.
AUTOEXEC copies it to shell drive `O:`, displays the copy, and starts the
selected `.COM` backend, REMMS, and WFC from their configured disk or RAM
locations.

Build both platform images without changing the current product version:

```powershell
python tools/build_all.py --bump none
```

The build validates both filesystems. The automated cold-boot and REMMS
runtime suites execute against both images; the SDX image receives
structural SDFS validation and contains the same compiled program binaries.
