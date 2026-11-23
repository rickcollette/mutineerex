# Serial drivers

`RS232.COM` is the 127-byte Atari 850 bootstrap loader from the root of
`FoReM XEP CLEAN 012722.atr`. It is copied unchanged to the Mutineer-eX work disk.
It is retained as a legacy, post-boot option. It is not one of the converted
REMMS 1.10 EOS drivers and is intentionally excluded from
`tools/exos_remms_test.py`: under the current exOS/Altirra Full-850 test it
does not reach the subsequent REMMS load. Prefer `RVRFULL.sys`, `RVRTWOW.sys`,
`NHAND.sys`, or an emulator-provided R: handler for verified configurations.

SHA-256: `471D0A5580AC61A09B6367B6A90F192A1D056D71161E356462DCF15838B4BB60`
