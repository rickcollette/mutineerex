import sys, os
atr, out = sys.argv[1], sys.argv[2]
d = open(atr,'rb').read()
hdr = d[:16]
secsize = hdr[4] | hdr[5]<<8
body = d[16:]
def sec(n):
    # first 3 sectors always 128 bytes
    if secsize == 128 or n <= 3:
        off = (n-1)*128
        return body[off:off+128]
    off = 3*128 + (n-4)*secsize
    return body[off:off+secsize]
print("sector size", secsize, "sectors", (len(body))//128)
os.makedirs(out, exist_ok=True)
for ds in range(361, 369):
    s = sec(ds)
    for i in range(8):
        e = s[i*16:(i+1)*16]
        flag = e[0]
        if flag == 0 or not all(0x20<=c<0x7f for c in e[5:16]): continue
        cnt = e[1]|e[2]<<8; start = e[3]|e[4]<<8
        name = e[5:13].decode('latin1').strip(); ext = e[13:16].decode('latin1').strip()
        fn = name + ('.'+ext if ext else '')
        fileno = (ds-361)*8+i
        print(f"{fn:14s} flag={flag:02x} sectors={cnt} start={start} deleted={bool(flag&0x80)}")
        if flag & 0x80: continue
        data = bytearray(); n = start; seen=0
        while n and n <= 1040 and seen < 2000:
            s2 = sec(n); ln = len(s2)
            data += s2[:s2[ln-1]] if secsize==128 else s2[:s2[ln-1]]
            n = ((s2[ln-3]&3)<<8) | s2[ln-2]
            seen += 1
        if os.path.exists(os.path.join(out, fn)): fn += '_' + str(fileno)
        open(os.path.join(out, fn),'wb').write(data)
        print("   ->", len(data), "bytes")
