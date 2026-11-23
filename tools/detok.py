import sys
from decimal import Decimal
STMT = ["REM","DATA","INPUT","COLOR","LIST","ENTER","LET","IF","FOR","NEXT","GOTO","GO TO","GOSUB","TRAP","BYE","CONT","COM","CLOSE","CLR","DEG","DIM","END","NEW","OPEN","LOAD","SAVE","STATUS","NOTE","POINT","XIO","ON","POKE","PRINT","RAD","READ","RESTORE","RETURN","RUN","STOP","POP","?","GET","PUT","GRAPHICS","PLOT","POSITION","DOS","DRAWTO","SETCOLOR","LOCATE","SOUND","LPRINT","CSAVE","CLOAD","","ERROR -"]
OPS = {0x12:",",0x13:"$",0x14:":",0x15:";",0x16:"",0x17:" GOTO ",0x18:" GOSUB ",0x19:" TO ",0x1A:" STEP ",0x1B:" THEN ",0x1C:"#",
0x1D:"<=",0x1E:"<>",0x1F:">=",0x20:"<",0x21:">",0x22:"=",0x23:"^",0x24:"*",0x25:"+",0x26:"-",0x27:"/",0x28:" NOT ",0x29:" OR ",0x2A:" AND ",
0x2B:"(",0x2C:")",0x2D:"=",0x2E:"=",0x2F:"<=",0x30:"<>",0x31:">=",0x32:"<",0x33:">",0x34:"=",0x35:"+",0x36:"-",0x37:"(",0x38:"(",0x39:"(",0x3A:"(",0x3B:"(",0x3C:",",
0x3D:"STR$",0x3E:"CHR$",0x3F:"USR",0x40:"ASC",0x41:"VAL",0x42:"LEN",0x43:"ADR",0x44:"ATN",0x45:"COS",0x46:"PEEK",0x47:"SIN",0x48:"RND",0x49:"FRE",0x4A:"EXP",0x4B:"LOG",0x4C:"CLOG",0x4D:"SQR",0x4E:"SGN",0x4F:"ABS",0x50:"INT",0x51:"PADDLE",0x52:"STICK",0x53:"PTRIG",0x54:"STRIG"}
def ch(c, quoted):
    if 0x20 <= c < 0x7f and not (quoted and c in (0x7b,0x7d)) and c not in (0x60,0x7b,0x7d) : return chr(c)
    return "{%02X}" % c
def fp(b):
    e = b[0]
    if e == 0: return "0"
    sign = -1 if e & 0x80 else 1
    e = (e & 0x7f) - 64
    m = Decimal(0)
    for i,x in enumerate(b[1:6]):
        m += Decimal((x>>4)*10 + (x&15)) * (Decimal(100) ** (-i))
    v = sign * m * (Decimal(100) ** e)
    s = format(v.normalize(), 'f')
    return s
d = open(sys.argv[1],'rb').read()
w = lambda o: d[o] | d[o+1]<<8
lomem,vntp,vntd,vvtp,stmtab,stmcur,starp = [w(i*2) for i in range(7)]
off = lambda a: a - vntp + 14
# variable names
names=[]; cur=""
for c in d[off(vntp):off(vvtp)]:
    if c == 0: break
    if c & 0x80:
        names.append(cur + chr(c & 0x7f)); cur=""
    else: cur += chr(c)
p = off(stmtab); end = off(stmcur)
out=[]
while p < end:
    ln = w(p); ll = d[p+2]
    if ln >= 32768: break
    line = d[p:p+ll]
    q = 3; text = "%d " % ln; first=True
    while q < ll:
        so = line[q]; tok = line[q+1]; q += 2
        first=False
        kw = STMT[tok] if tok < len(STMT) else "?TOK%02X" % tok
        if tok in (0,1,55):
            raw = line[q:so]
            text += kw + " " + "".join(ch(c,True) for c in raw if c != 0x9b) if tok==0 else kw + " " + "".join(ch(c,True) for c in raw if c!=0x9b)
            q = so; continue
        last=None
        text += (kw + " ") if kw else ""
        while q < so:
            t = line[q]; q += 1
            if t == 0x14: text += ":"; continue
            if t == 0x0E: text += fp(line[q:q+6]); q += 6
            elif t == 0x0F:
                n = line[q]; text += '"' + "".join(ch(c,True) for c in line[q+1:q+1+n]) + '"'; q += 1+n
            elif t >= 0x80:
                i = t - 0x80
                text += names[i] if i < len(names) else "V%d" % i
            elif t == 0x1B: text += " THEN "
            elif t in OPS: text += OPS[t]
            else: text += "{op%02X}" % t
    out.append(text.rstrip())
    p += ll
print("\n".join(out))
