# Compact REMMS R-Verter Handler

`rvrhand.asm` is the active direct-POKEY `R:` backend for REMMS. It renews the
useful low-level ideas from `third_party/RHAND1C_MADS_CONVERTED` without using
that binary's overlapping `$2000-$2700` address range or its MMS-era lifecycle
behavior.

The REMMS build produces two compact SDX-relocatable binaries:

| File | Wiring profile | Capability byte | Resident size |
| --- | --- | --- | --- |
| `RVRFULL.COM` | RX, TX, motor-control/DTR, CRX and/or DSR | `$1F` | 1,252 bytes |
| `RVRTWOW.COM` | RX and TX only | `$19` | 1,209 bytes |

Both fit inside RHND850's `$0501`-byte resident allocation. SpartaDOS X loads
the selected handler at the current `MEMLO` before fixed-address REMMS. In the
canonical test image the full profile occupies `$1002-$14E5` and the two-wire
profile `$1002-$14BA`; REMMS then remains `$1E00-$3CFE`
(`REMMS_END=$3CFF`), so the handler consumes no additional BASIC headroom.

## Build and package

```powershell
.\remms\build.ps1

python tools\package_mutineer_atr.py --no-version-bump `
  --r-handler rverter-full --out results\rverter-build\rverter-full.atr

python tools\package_mutineer_atr.py --no-version-bump `
  --r-handler rverter-two-wire --out results\rverter-build\rverter-two-wire.atr

make mutineer-atr-rverter
make mutineer-atr-universal
```

The make target writes
`source/atr/atari-mutineer-v<VERSION>-16mb-rverter.atr`. It is the complete
16MB package with bundled doors and `RVRFULL.COM` replacing `RHND850.COM`.

The default packager profile remains `850`. R-Verter images boot the selected
handler first and `REMMS.COM` second, matching RHND850's relocatable-memory
model. BASIC then calls REMMS's install API, which captures and wraps the final
physical `R:` entry.

The universal ATR contains both binaries. At its SDX prompt use `D1:STARTRVF`
for the full-handshake build or `D1:STARTRVT` for the two-wire build. Copy the
matching batch file over `AUTOEXEC.BAT` and cold-boot to persist that choice.
Never load both R-Verter binaries during the same boot.

## CIO contract

Both profiles implement the subset REMMS owns:

- `OPEN "R:"` with AUX1 `$0D`;
- XIO 38 `$20` raw transport;
- XIO 36 with the standard baud table through selector 13; selector 15 uses
  the modem's 9600-baud command/wait channel and selector 14 uses the
  negotiated 19200-baud connected channel;
- XIO 40 using the caller's external receive buffer;
- raw `GET`/`PUT`, queue-length `STATUS`, bounded transmit drain, and `CLOSE`;
- XIO 42 identification in `DVSTAT`: `R`, `V`, version 1, capability flags;
- defined errors for unsupported commands, bad state, absent monitored carrier,
  receive overflow, and bounded timeouts.

The handler keeps only a 32-byte resident transmit queue. Its receive ring is
the 128-byte buffer REMMS supplies to XIO 40, eliminating the converted
handler's redundant 256-byte resident queue.

## Profile behavior

The full-handshake build treats the SIO motor-control output as DTR. XIO 34
`$F0` asserts it and `$80` drops it. Ordinary `CLOSE` releases POKEY and its IRQ
vectors without changing DTR, which is required for REMMS disk suspend/resume
and stream rebuilds. Requested CRX/DSR inputs receive a bounded three-sample
check when monitored XIO 40 starts, which tolerates transient CA1/CB1 latch
state without hiding a genuinely missing carrier; failure returns CIO `$8B`.

The two-wire build does not claim DTR or carrier capabilities. REMMS therefore
does not perform physical carrier probes. XIO 34 `$80` uses a bounded Hayes
fallback: one-second guard, `+++`, one-second guard, then `ATH` plus carriage
return. This requires the modem's escape character and guard time to retain
their normal Hayes meanings. It cannot provide full-handshake carrier-loss
certainty.

Both profiles assert the OS motor-control gate while POKEY serial I/O is
active. On a two-wire adapter that signal is not connected; on a full adapter
it is the already asserted DTR signal.

## Verification

Static/build validation:

```powershell
python tools\rverter_handler_check.py
```

Debugger-only Altirra acceptance, after packaging both images:

```powershell
python tools\run_rverter_handler_test.py
```

The runtime test uses only `D:\ALTIRRA\Altirra64.exe`, keeps Altirra off the
interactive foreground, and records debugger/log evidence under
`results/rverter-handlers/`. It checks installation and `MEMLO`, identity and
capabilities, the required XIO sequence, status counts, close/reopen behavior,
full-profile DTR preservation/drop, and two-wire guarded hangup/transmit drain.

Altirra's modem peripheral emulates an 850 reached through SIO; it does not
emulate a modem attached directly to POKEY through an R-Verter. Consequently
the ordinary socket/telnet BBS test is not an end-to-end R-Verter test. The
dedicated debugger test proves relocation, CIO control flow, POKEY IRQ timing,
and hangup transmission, but not the missing electrical endpoint. Before
calling a physical setup supported, record its exact RX/TX/DTR/CRX/DSR wiring
and repeat wait-call, connected resume, explicit hangup, and carrier-loss tests
on that hardware.
