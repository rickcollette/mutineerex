# Serial drivers

`RHND850.COM` is Altirra's disk-based Atari 850 R: handler. On SpartaDOS X it
is the supported choice for a real Atari 850 (including an attached WiModem232/32) and for
Altirra's full 850 emulation. It is loaded before `REMMS.COM` and has SHA-256
`8EBD203619683481A1B546F9E1A794F2FF1FC9A8BE95C21249447C0F550887D7`.

The handler is distributed under the notice in `RHND850-LICENSE.txt`.

`RS232.COM` is the 127-byte Atari 850 bootstrap loader from the root of
`FoReM XEP CLEAN 012722.atr`. It is copied unchanged to the Mutineer-eX work disk.
It is retained as a legacy, post-boot option. It is not one of the converted
REMMS 1.10 EOS drivers and is intentionally excluded from
`tools/exos_remms_test.py`: under the current exOS/Altirra Full-850 test it
does not reach the subsequent REMMS load. Prefer `RVRFULL.sys`, `RVRTWOW.sys`,
`NHAND.sys`, or an emulator-provided R: handler for verified configurations.

SHA-256: `471D0A5580AC61A09B6367B6A90F192A1D056D71161E356462DCF15838B4BB60`
