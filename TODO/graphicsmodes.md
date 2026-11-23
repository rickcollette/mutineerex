Serve those graphics formats from an Atari 8-bit BASIC BBS by storing each screen in separate terminal-suffixed files (.ATA, .ANS, .VT5, .RIP, .IGS), detecting the caller's terminal type at login, and streaming the matching file raw over R: without ATASCII translation. Because all five protocols rely on standard ASCII/8-bit byte streams, your Atari 8-bit host does not need to render them—it simply acts as a file server sending raw bytes to the caller's terminal.

1. File Naming & Directory Structure

Keep your menus and artwork modular by storing one version per protocol using a standard extension scheme on your disk or virtual drive:

Protocol	Suffix	Line Endings	Notes for Atari 8-Bit Hosting
ATASCII	.ATA	$9B (EOL)	Native Atari 8-bit text/graphics. Send with normal ATASCII mode.
ANSI	.ANS	CR/LF ($0D $0A)	Requires raw binary send so ESC ($1B) and IBM CP437 characters pass untouched.
VT-52	.VT5	CR/LF ($0D $0A)	Used by Atari ST terminals; uses ESC ($1B) cursor codes.
RIPscrip	.RIP	CR/LF ($0D $0A)	Lines start with `!
IGS	.IGS	CR/LF ($0D $0A)	Lines start with G#. Must be sent raw with no $9B EOLs injected.


2. Terminal Detection at Login

When a user connects, prompt them to select their emulation (or auto-detect) and store their chosen extension in a string variable (EXT$).
• Manual Menu Selection (Most Reliable): Present a plain ASCII prompt first (using standard 7-bit ASCII and CR/LF so every terminal can read it):text
Select Terminal: [1] ATASCII  [2] ANSI  [3] VT-52  [4] RIPscrip  [5] Atari ST IGS
Use code with caution.
• Auto-Detection Probes (Optional):
	• ANSI / VT-52: Send CHR$(27)+"Z" (VT-52 identify) or CHR$(27)+"[c" (ANSI Device Attributes) and check the R: input buffer with STATUS for an escape response within ~1 second.
	• IGS: Send G#?0 (IGS version query). An IGS terminal replies with a G# version string, whereas non-IGS terminals ignore it or print four characters.
	• RIPscrip: Send CHR$(27)+"[!" (RIPscrip query); RIPterm responds with its version ID.

3. Streaming Raw Files in Atari BASIC

The biggest pitfall in Atari BASIC is that PRINT #2 automatically converts CR/LF to ATASCII $9B and can mangle control characters ($1B, $0D, $0A) depending on your R: handler's translation mode.
1. Disable R: Translation: Configure your R: driver (e.g., Atari 850, P:R: Connection, FujiNet, or Atari800/Altirra virtual R:) for raw / no translation via XIO before serving non-ATASCII files:basic
REM SET R: TO NO TRANSLATION (ATARI 850 / COMPATIBLE)
XIO 38,#2,32,0,"R:"
Use code with caution.
(Note: Check your specific R: handler manual—for example, BobTerm/Ice-T/FujiNet handlers use XIO 38 with AUX1=32 for no translation and AUX1=0 for light ATASCII translation.)
2. Use BGET / BPUT (Burst I/O) Instead of GET/PUT Loops:
In standard Atari BASIC, reading and sending byte-by-byte with GET #1,A : PUT #2,A runs at roughly 30–50 characters per second (300–450 baud), which makes large .ANS, .RIP, or .IGS files painfully slow. Instead, invoke CIO burst I/O (COMMAND = 7 for block get, COMMAND = 11 for block put) via a tiny USR() machine-language routine, or use Turbo-BASIC XL's built-in BGET and BPUT:basic
100 REM TURBO-BASIC XL FAST FILE STREAMER
110 DIM BUF$(256)
120 OPEN #1,4,0,"D1:WELCOME"+EXT$
130 TRAP 200
140 BGET #1,ADR(BUF$),256
150 BPUT #2,ADR(BUF$),256
160 GOTO 140
200 REM HANDLE PARTIAL FINAL BLOCK ON EOF (ERROR 136)
210 LEN=DPEEK(840) : REM IOCB #1 ACTUAL BYTES READ ($0348)
220 IF LEN>0 THEN BPUT #2,ADR(BUF$),LEN
230 CLOSE #1
240 RETURN
Use code with caution.
(If you are using standard Atari BASIC without Turbo-BASIC XL, a 20-byte USR routine calling $E456 (CIOV) achieves full 9600+ baud line speed.)

4. Practical Caveats for Multi-Protocol Hosting

• Strip ATASCII EOLs when creating non-ATASCII files: Do not edit .ANS, .RIP, or .IGS files in an Atari ATASCII text editor without stripping $9B bytes, as a stray $9B will break IGS command parsing and corrupt ANSI layouts. Author them on a PC (using tools like Moebius for ANSI, PabloDraw for RIP, or IGDEV/JoshDraw for IGS) and transfer them to your Atari disk/FujiNet image in binary mode.
• Dynamic Variables (Usernames, Stats): Keep dynamic BBS text (like caller lists or message headers) in plain 7-bit ASCII or build small protocol-specific header templates so you don't have to maintain five separate message-reader engines.
• Flow Control (XON/XOFF): IGS scripts frequently use G#t (timed pause), which sends XOFF ($13) and XON ($11) to the host. Make sure your R: handler either respects software flow control or doesn't drop incoming bytes during pauses.
Would you like the 20-byte USR machine-language CIO burst routine for standard Atari BASIC, or specific XIO translation commands for the exact R: interface/hardware you are using (such as FujiNet, Atari 850, or an emulator)?
