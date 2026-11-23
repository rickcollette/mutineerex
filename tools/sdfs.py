#!/usr/bin/env python3
"""SpartaDOS file system (SDFS 2.0 / 2.1) reader and consistency checker.

Covers what SpartaDOS X 4.5 writes (User Guide ch. 7): 128, 256 and 512 byte
sectors, SDFS 2.1 header fields, hidden/archived/symlink status bits, sparse
files, directories up to 1423 entries.

usage: sdfs.py check image.atr          exit 1 on errors
       sdfs.py ls image.atr             recursive listing with attributes
       sdfs.py extract image.atr dir    extract all files (hidden ones too)
       sdfs.py build image.atr sectors seclen dir   SDFS 2.1 image of a tree
"""
import struct
import sys
from pathlib import Path

ST_PROT, ST_HIDDEN, ST_ARCH, ST_USED, ST_DEL, ST_DIR, ST_LINK, ST_OPEN = (
    1, 2, 4, 8, 16, 32, 64, 128)
SDFS_ENTRY = 23
EOSFS_ENTRY = 44
EOSFS_NAME_MAX = 31
EOSFS_CLEAN = 0x47
EOSFS_DIRTY = 0x48

# Three boot sectors emitted by exOS 0.7's EOS FORMAT command.  Header fields
# in the first sector are replaced by build(); the remaining bytes are the
# real EOSFS boot loader.  Keeping this here also makes every EOSFS image made
# by the test helpers boot-identical to one formatted by EOS itself.
EOSFS_BOOTCODE = bytes.fromhex(
    '00030030e0074c60300000000000000000000000000000000000000000000000'
    '000000000000000000000000000000003101524000000700000048a009b93030'
    '9900038810f7688d0503a5498d0803d003ee09032059e4300160ae2d309a3860'
    'ba8e2d30a9608de007ad28308d2a30ad29308d2b30ad1f30854985488d2c30ee'
    '2c30a95f8de002a9308de102a20020ea30b04c9543e8e002d00c2543c9fff0ec'
    'a5430544f039e004d0e4a545c543a546e544902ba95f8de202a9308de30220ea'
    '30b01ca0009143a543c545a544e546b008e643d0e9e644d0e520e4304c8c3020'
    'e73018606ce2026ce002ad2c30f07cad2e300d2f30f021ee0a03d003ee0b03a9'
    '2e203a30ad2e30d003ce2f30ce2e30a90085478d2c30f053a448c449d024ad2a'
    '308d0a03ad2b308d0b030d0a03f04da92f203a30ad002f8d2a30ad012f8d2b30'
    'a004b9002f8d0a03c8b9002f8d0b03c8b9002f8d2e30c8b9002f8d2f30c88448'
    'ad2e300d2f30f0144cff30a447b9002ec88447c449d003ee2c30186038600000'
)


class SdfsError(Exception):
    pass


class Image:
    def __init__(self, path):
        with open(path, 'rb') as f:
            raw = f.read()
        if raw[:2] != b'\x96\x02':
            raise SdfsError('not an ATR image')
        self.path = path
        self.atr_seclen = struct.unpack('<H', raw[4:6])[0]
        size = (struct.unpack('<H', raw[2:4])[0] | raw[6] << 16) * 16
        self.data = bytearray(raw[16:16 + size])
        if self.atr_seclen <= 256:
            short = 3 * 128
            self.nsec = 3 + (len(self.data) - short) // self.atr_seclen
        else:
            self.nsec = len(self.data) // self.atr_seclen

    def sector(self, n):
        if n < 1 or n > self.nsec:
            raise SdfsError('sector %d out of range 1..%d' % (n, self.nsec))
        if self.atr_seclen <= 256:
            if n <= 3:
                return bytes(self.data[(n - 1) * 128:n * 128])
            o = 384 + (n - 4) * self.atr_seclen
        else:
            o = (n - 1) * self.atr_seclen
        return bytes(self.data[o:o + self.atr_seclen])


class Volume:
    """Parsed SDFS volume; .errors and .warnings are filled by check()."""

    def __init__(self, path):
        self.img = Image(path)
        h = self.img.sector(1)
        self.boot = h
        w = lambda o: h[o] | h[o + 1] << 8
        self.version = h[32]
        # EOSFS v2 has extents, long case-sensitive names and 44-byte entries.
        self.eosfs = self.version in (EOSFS_CLEAN, EOSFS_DIRTY)
        if self.version not in (0x20, 0x21, EOSFS_CLEAN, EOSFS_DIRTY):
            raise SdfsError('not SDFS 2.x (revision byte $%02X)' % self.version)
        self.entry_size = EOSFS_ENTRY if self.eosfs else SDFS_ENTRY
        self.main = w(9)
        self.total = w(11)
        self.free = w(13)
        self.nbmp = h[15]
        self.bmap = w(16)
        self.name = h[22:30].decode('latin-1').rstrip()
        if self.version in (0x21, EOSFS_CLEAN, EOSFS_DIRTY):
            self.seclen = w(33)
            self.header_mapents = w(35)
            self.mapents = (self.seclen - 4) // 4 if self.eosfs else self.header_mapents
        else:
            self.seclen = 128 if h[31] == 0x80 else 256
            self.mapents = (self.seclen - 4) // 2
            self.header_mapents = self.mapents
        self.boot_map = w(40)
        self.errors = []
        self.warnings = []

    def sec(self, n):
        return self.img.sector(n)

    # ---- maps -------------------------------------------------------------
    def chain(self, first, what):
        """Return (map sectors, data sector list incl. 0 for sparse)."""
        maps, data, seen = [], [], set()
        prev, cur = 0, first
        while cur:
            if cur in seen:
                self.errors.append('%s: sector map loop at %d' % (what, cur))
                break
            seen.add(cur)
            m = self.sec(cur)
            nxt, back = struct.unpack('<HH', m[:4])
            if back != prev:
                self.errors.append('%s: map %d back link %d, expected %d' % (what, cur, back, prev))
            maps.append(cur)
            if self.eosfs:             # extents: start, count (0 ends; start 0: a gap)
                for k in range(self.mapents):
                    st, cnt = struct.unpack('<HH', m[4 + 4 * k:8 + 4 * k])
                    if not cnt:
                        break
                    data += [st + i if st else 0 for i in range(cnt)]
            else:
                data += list(struct.unpack('<%dH' % self.mapents, m[4:4 + 2 * self.mapents]))
            prev, cur = cur, nxt
        while data and data[-1] == 0:
            data.pop()
        return maps, data

    def read_chain(self, first, length, what):
        maps, data = self.chain(first, what)
        out = bytearray()
        for s in data:
            out += self.sec(s)[:self.seclen] if s else bytes(self.seclen)
        if length > len(out):
            self.errors.append('%s: length %d beyond %d allocated bytes' % (what, length, len(out)))
        return maps, data, bytes(out[:length])

    # ---- directories --------------------------------------------------------
    def walk(self):
        """Yield (path, entry dict) for every live entry, depth first."""
        root = {'name': 'main', 'status': ST_USED | ST_DIR, 'map': self.main,
                'length': None, 'path': ''}
        self.owner = {}
        yield from self._walk_dir(root, 0)

    def _walk_dir(self, d, parent_map):
        what = d['path'] or '/'
        maps, data = self.chain(d['map'], what)
        raw = bytearray()
        for s in data:
            raw += self.sec(s)[:self.seclen] if s else bytes(self.seclen)
        self._own(maps + [s for s in data if s], what)
        entry_size = self.entry_size
        hdr = raw[:entry_size]
        if len(hdr) < entry_size:
            self.errors.append('%s: empty directory file' % what)
            return
        hparent = hdr[1] | hdr[2] << 8
        dlen = hdr[3] | hdr[4] << 8 | hdr[5] << 16
        if hparent != parent_map:
            self.errors.append('%s: parent link %d, expected %d' % (what, hparent, parent_map))
        if dlen % entry_size or dlen > len(raw):
            self.errors.append('%s: directory length %d invalid' % (what, dlen))
        # the parent's entry length of a subdirectory is not maintained (SDX: 23, BW-DOS: 0)
        d['dirlen'] = dlen
        if not self.eosfs and dlen > 1424 * entry_size:
            self.warnings.append('%s: %d entries exceed SDX limit' %
                                 (what, dlen // entry_size - 1))
        hname = self._entry_name(hdr)
        if hname != d['name']:
            self.warnings.append('%s: header name %r' % (what, hname))
        names = set()
        for o in range(entry_size, min(dlen, len(raw)), entry_size):
            e = raw[o:o + entry_size]
            st = e[0]
            if st == 0:
                break
            if st & ST_DEL or not st & ST_USED:
                continue
            name = self._entry_name(e)
            path = d['path'] + '/' + name
            ent = {'name': name, 'status': st, 'map': e[1] | e[2] << 8,
                   'length': e[3] | e[4] << 8 | e[5] << 16, 'path': path,
                   'date': tuple(e[38:41] if self.eosfs else e[17:20]),
                   'time': tuple(e[41:44] if self.eosfs else e[20:23])}
            if st & ST_DIR and st & ST_LINK:
                self.errors.append('%s: both subdir and symlink bits' % path)
            if st & ST_OPEN:
                self.errors.append('%s: left open for write' % path)
            if name in names:
                self.errors.append('%s: duplicate name' % path)
            names.add(name)
            if (not name or '/' in name or
                    not all(0x20 <= ord(c) < 0x7F for c in name)):
                self.errors.append('%s: invalid name %r' % (path, name))
            if st & ST_DIR:
                yield path, ent
                yield from self._walk_dir(ent, d['map'])
            else:
                if ent['map']:
                    fmaps, fdata, ent['data'] = self.read_chain(ent['map'], ent['length'], path)
                    self._own(fmaps + [s for s in fdata if s], path)
                    need = -(-ent['length'] // self.seclen)
                    if len(fdata) > need:
                        self.warnings.append('%s: %d sectors allocated past end' % (path, len(fdata) - need))
                else:
                    ent['data'] = b''
                    if ent['length']:
                        self.errors.append('%s: length %d but no sector map' % (path, ent['length']))
                yield path, ent

    def _entry_name_bytes(self, e):
        if self.eosfs:
            n = e[6]
            if n > EOSFS_NAME_MAX:
                return bytes(e[7:7 + EOSFS_NAME_MAX])
            return bytes(e[7:7 + n])
        fn = bytes(e[6:14]).rstrip(b' ')
        ext = bytes(e[14:17]).rstrip(b' ')
        return fn + (b'.' + ext if ext else b'')

    def _entry_name(self, e):
        return self._entry_name_bytes(e).decode('latin-1')

    def _own(self, sectors, what):
        for s in sectors:
            if s < 1 or s > self.total:
                self.errors.append('%s: sector %d out of range' % (what, s))
            elif s in self.owner:
                self.errors.append('%s: sector %d cross-linked with %s' % (what, s, self.owner[s]))
            else:
                self.owner[s] = what

    # ---- bitmap -------------------------------------------------------------
    def bitmap_used(self):
        bits = bytearray()
        for i in range(self.nbmp):
            bits += self.sec(self.bmap + i)[:self.seclen]
        used = set()
        for s in range(1, self.total + 1):
            # SDX sizes the bitmap for sectors 0..total-1 when total is a
            # multiple of its bit capacity; a sector without a bit is never free
            if s >> 3 >= len(bits) or not bits[s >> 3] & (0x80 >> (s & 7)):
                used.add(s)
        return used

    def check(self):
        h = self.boot
        if self.total > self.img.nsec:
            self.errors.append('header total %d > image %d sectors' % (self.total, self.img.nsec))
        if self.seclen != (self.img.atr_seclen if self.img.atr_seclen > 128 or self.version == 0x21 else 128) \
                and self.seclen != self.img.atr_seclen:
            self.errors.append('sector size %d != image %d' % (self.seclen, self.img.atr_seclen))
        if self.nbmp * self.seclen * 8 < self.total:
            self.errors.append('%d bitmap sectors too few for %d sectors' % (self.nbmp, self.total))
        if self.version == 0x21 and self.mapents != (self.seclen - 4) // 2:
            self.errors.append('SDFS 2.1 map entries %d, expected %d' % (self.mapents, (self.seclen - 4) // 2))
        entries = list(self.walk())
        reserved = set(range(1, 4 if self.seclen < 512 else 2)) | \
            set(range(self.bmap, self.bmap + self.nbmp))
        for s in reserved:
            if s in self.owner:
                self.errors.append('sector %d reserved but used by %s' % (s, self.owner[s]))
        used = self.bitmap_used()
        referenced = set(self.owner) | reserved
        for s in sorted(referenced - used):
            self.errors.append('sector %d in use (%s) but free in bitmap' % (s, self.owner.get(s, 'system')))
        nobit = set(range(self.nbmp * self.seclen * 8, self.total + 1))
        lost = sorted(used - referenced - nobit)
        if lost:
            # space leak, not corruption
            self.warnings.append('%d sectors allocated but unreferenced (first %s)' % (len(lost), lost[:8]))
        nfree = self.total - len(used)
        if nfree != self.free:
            self.errors.append('free count %d in header, bitmap says %d' % (self.free, nfree))
        if self.boot_map and self.boot_map not in self.owner:
            self.warnings.append('boot file map %d not a file' % self.boot_map)
        return entries


def ixhash(name11):
    """EOSFS directory index: a name's (8 + 3 bytes, blank padded) hash, 1-255
    (rotate left, exclusive or; 0 means a free slot, so 0 becomes 1)."""
    h = 0
    for b in name11:
        h = (((h << 1) | (h >> 7)) & 0xFF) ^ b
    return h or 1


def build(path, total, seclen, files, volname='EOS', eosfs=False,
          boot=None, bootcode=None):
    """Write an SDFS 2.1 image. files maps 'DIR/NAME.EXT' to bytes (a value
    of None makes an empty directory), or to (bytes, stamp, status bits):
    stamp = 6 bytes day, month, year, hour, minute, second; status bits
    ST_PROT, ST_HIDDEN, ST_ARCH added to the entry's. Directories come first,
    then files, in the order given. Layout as SDX FORMAT: boot sectors, bitmap, main
    directory, then the rest. boot names the boot file; bootcode contains the
    three 128 byte boot sectors."""
    if eosfs and bootcode is None:
        bootcode = EOSFS_BOOTCODE
    if bootcode is not None:
        if seclen >= 512:
            raise SdfsError('stock Atari OS cannot boot 512-byte sectors')
        if len(bootcode) != 384 or bootcode[:2] != b'\x00\x03':
            raise SdfsError('bootcode must be 384 bytes and three sectors')
    if boot is not None:
        boot = boot.replace('>', '/').replace('\\', '/').strip('/')
        if bootcode is None:
            raise SdfsError('a boot file requires bootcode')
    mapents = (seclen - 4) // 2
    xents = (seclen - 4) // 4
    nboot = 3 if seclen < 512 else 1
    nbmp = -(-(total + 1) // (seclen * 8))
    img = {}
    used = set(range(1, nboot + 1 + nbmp))
    nxt = [nboot + nbmp + 1]

    def alloc():
        while nxt[0] in used:
            nxt[0] += 1
        if nxt[0] > total:
            raise SdfsError('image full')
        used.add(nxt[0])
        return nxt[0]

    def store(data):
        """Sector map chain for data; returns the first map (0 if empty)."""
        secs = []
        for o in range(0, len(data), seclen):
            s = alloc()
            img[s] = data[o:o + seclen]
            secs.append(s)
        if not secs:
            return 0
        if eosfs:
            return xlist(secs)
        maps = [alloc() for _ in range(-(-len(secs) // mapents))]
        for i, m in enumerate(maps):
            chunk = secs[i * mapents:(i + 1) * mapents]
            img[m] = struct.pack('<HH', maps[i + 1] if i + 1 < len(maps) else 0,
                                 maps[i - 1] if i else 0) + struct.pack('<%dH' % len(chunk), *chunk)
        return maps[0]

    def xlist(secs):
        """EOSFS: the extent list sectors for data sectors secs."""
        runs = []
        for x in secs:
            if runs and runs[-1][0] + runs[-1][1] == x:
                runs[-1][1] += 1
            else:
                runs.append([x, 1])
        lists = [alloc() for _ in range(max(1, -(-len(runs) // xents)))]
        for i, m in enumerate(lists):
            chunk = runs[i * xents:(i + 1) * xents]
            img[m] = struct.pack('<HH', lists[i + 1] if i + 1 < len(lists) else 0,
                                 lists[i - 1] if i else 0) + b''.join(struct.pack('<HH', a, c) for a, c in chunk)
        return lists[0]

    def name83(n):
        b, _, e = n.partition('.')
        return b.ljust(8).encode()[:8] + e.ljust(3).encode()[:3]

    def eos_name(n):
        try:
            raw = n.encode('ascii')
        except UnicodeEncodeError:
            raise SdfsError('EOSFS name is not ASCII: %r' % n)
        if not raw or len(raw) > EOSFS_NAME_MAX:
            raise SdfsError('EOSFS name must be 1..%d bytes: %r' %
                            (EOSFS_NAME_MAX, n))
        if any(c in b'/*?' for c in raw) or any(c < 0x20 or c >= 0x7F for c in raw):
            raise SdfsError('invalid EOSFS name: %r' % n)
        return bytes([len(raw)]) + raw.ljust(EOSFS_NAME_MAX, b'\0')

    def entry(status, fmap, length, n, st):
        if eosfs:
            return (bytes([status]) + struct.pack('<H', fmap) +
                    struct.pack('<I', length)[:3] + eos_name(n) + bytes(st))
        return (bytes([status]) + struct.pack('<H', fmap) +
                struct.pack('<I', length)[:3] + name83(n) + bytes(st))

    stamp = bytes([1, 1, 25, 12, 0, 0])
    tree = {'': []}
    for p, d in files.items():
        if eosfs:
            try:
                plen = len(('/' + p).encode('ascii'))
            except UnicodeEncodeError:
                raise SdfsError('EOSFS path is not ASCII: %r' % p)
            if plen > 127:
                raise SdfsError('EOSFS path exceeds 127 bytes: %r' % p)
        parts = p.split('/')
        if eosfs and (not all(parts) or any(x in ('.', '..') for x in parts)):
            raise SdfsError('invalid EOSFS path: %r' % p)
        if eosfs:
            for part in parts:
                eos_name(part)
        for i in range(1, len(parts)):
            d_ = '/'.join(parts[:i])
            if d_ not in tree:
                tree[d_] = []
                tree['/'.join(parts[:i - 1])].append((parts[i - 1], None))
        if d is None:
            if p not in tree:
                tree[p] = []
                tree['/'.join(parts[:-1])].append((parts[-1], None))
        else:
            tree['/'.join(parts[:-1])].append((parts[-1], d))
    maps = {}
    filemaps = {}

    def mkdir(d, parent):
        # the directory's map first, so it is known to its entries' parents
        entries = []
        for n, data in tree[d]:
            if data is None:
                continue
            st, extra = stamp, 0
            if isinstance(data, tuple):
                data, st, extra = data
            name = d + '/' + n if d else n
            fmap = store(data)
            maps[name] = fmap
            filemaps[name] = fmap
            entries.append(entry(ST_USED | extra, fmap, len(data), n, st))
        entry_size = EOSFS_ENTRY if eosfs else SDFS_ENTRY
        hdr_len = entry_size * (1 + len(tree[d]))
        own = (d.split('/')[-1] if d else 'main')
        subs = []
        for n, data in tree[d]:
            if data is None:
                sub = (d + '/' + n) if d else n
                subs.append((n, sub))
        # reserve this directory's sectors now, contents later
        body_secs = [alloc() for _ in range(-(-hdr_len // seclen))]
        dmap = alloc()
        maps[d] = dmap
        for n, sub in subs:
            mkdir(sub, dmap)
            entries.append(entry(ST_USED | ST_DIR, maps[sub], entry_size, n, stamp))
        body = entry(ST_USED | ST_DIR, parent, hdr_len, own, stamp) + b''.join(entries)
        for i, sec in enumerate(body_secs):
            img[sec] = body[i * seclen:(i + 1) * seclen]
        if eosfs:
            runs = []
            for x in body_secs:
                if runs and runs[-1][0] + runs[-1][1] == x:
                    runs[-1][1] += 1
                else:
                    runs.append([x, 1])
            img[dmap] = struct.pack('<HH', 0, 0) + b''.join(struct.pack('<HH', a, c) for a, c in runs)
        else:
            img[dmap] = struct.pack('<HH', 0, 0) + struct.pack('<%dH' % len(body_secs), *body_secs)

    mkdir('', 0)
    free = total - len(used)
    bits = bytearray(nbmp * seclen)
    for sec in range(1, total + 1):
        if sec not in used and sec < len(bits) * 8:
            bits[sec >> 3] |= 0x80 >> (sec & 7)
    for i in range(nbmp):
        img[nboot + 1 + i] = bytes(bits[i * seclen:(i + 1) * seclen])
    hdr = bytearray(128 if seclen < 512 else seclen)
    if bootcode is not None:
        hdr[:128] = bootcode[:128]
        img[2] = bootcode[128:256]
        img[3] = bootcode[256:384]
    # With no loader, write the header SDX FORMAT uses; no code follows it.
    if bootcode is None:
        hdr[0:9] = bytes.fromhex('000300 30e007 4c8030' if seclen < 512 else '000100 04e007 4c4004')
    alloc_hint = nxt[0]
    while alloc_hint <= total and alloc_hint in used:
        alloc_hint += 1
    if alloc_hint > total:
        alloc_hint = 0
    struct.pack_into('<HHHBHHH', hdr, 9, maps[''], total, free, nbmp,
                     nboot + 1, alloc_hint, 0)
    hdr[22:30] = volname.ljust(8).encode()[:8]
    # tracks, $80 double sided: 40 for 720 sectors, 80 x 2 for 1440 x 512
    hdr[30] = 0x28 if total == 720 else 0xD0 if (total, seclen) == (1440, 512) else 1
    hdr[37] = 1
    hdr[31] = {128: 0x80, 256: 0x00, 512: 0x01}[seclen]
    hdr[32] = EOSFS_CLEAN if eosfs else 0x21
    struct.pack_into('<HH', hdr, 33, seclen, xents if eosfs else mapents)
    if eosfs:
        # EOS FORMAT defaults: no allocation optimizer and skew $42.
        hdr[38], hdr[39] = 0, 0x42
    else:
        hdr[38], hdr[39] = 1, 0x5A
    if boot is not None:
        if boot not in filemaps:
            raise SdfsError('boot file not found: ' + boot)
        if not filemaps[boot]:
            raise SdfsError('boot file is empty: ' + boot)
        struct.pack_into('<H', hdr, 40, filemaps[boot])
    img[1] = bytes(hdr)
    # ATR: 128/256 byte images have three 128 byte boot sectors
    size = total * seclen - (3 * (seclen - 128) if seclen == 256 else 0)
    data = bytearray(size)
    for sec, d in img.items():
        if seclen <= 256 and sec <= 3:
            o = (sec - 1) * 128
            data[o:o + 128] = d[:128].ljust(128, b'\0')
        else:
            o = (384 + (sec - 4) * seclen) if seclen == 256 else (sec - 1) * seclen
            data[o:o + seclen] = d[:seclen].ljust(seclen, b'\0')
    h = bytes([0x96, 0x02, (size >> 4) & 0xFF, (size >> 12) & 0xFF,
               seclen & 0xFF, seclen >> 8, size >> 20]) + bytes(9)
    with open(path, 'wb') as f:
        f.write(h + data)



def overwrite(path, name, data, newname=None):
    """Replace the contents of file `name` in the main directory of image
    `path` in place: the new data must fit the sectors the file holds; its
    length in the directory entry is set to len(data). With newname the
    entry is renamed too."""
    v = Volume(path)
    raw = bytearray(Path(path).read_bytes())

    def off(sec):
        if v.img.atr_seclen <= 256:
            return 16 + ((sec - 1) * 128 if sec <= 3 else 384 + (sec - 4) * v.img.atr_seclen)
        return 16 + (sec - 1) * v.img.atr_seclen
    _, dsecs = v.chain(v.main, '/')
    pos = [off(sec) + k for sec in dsecs for k in range(v.seclen)]   # directory byte -> image
    entry_size = v.entry_size
    want = name.strip('/') if v.eosfs else name.upper()
    for o in range(entry_size, len(pos) - entry_size + 1, entry_size):
        e = bytes(raw[pos[o + k]] for k in range(entry_size))
        if e[0] == 0:
            break
        if e[0] & ST_DEL or not e[0] & ST_USED:
            continue
        if v.eosfs:
            found = e[7:7 + e[6]].decode('ascii')
        else:
            fn = e[6:14].decode('latin-1').rstrip()
            ext = e[14:17].decode('latin-1').rstrip()
            found = fn + ('.' + ext if ext else '')
        if found != want:
            continue
        _, fdata = v.chain(e[1] | e[2] << 8, name)
        if len(data) > len(fdata) * v.seclen:
            raise SdfsError('%s: %d bytes do not fit %d sectors' % (name, len(data), len(fdata)))
        for k, fs in enumerate(fdata):
            chunk = data[k * v.seclen:(k + 1) * v.seclen]
            raw[off(fs):off(fs) + len(chunk)] = chunk
        for k, b in enumerate((len(data) & 0xFF, len(data) >> 8 & 0xFF, len(data) >> 16)):
            raw[pos[o + 3 + k]] = b
        if newname:
            if v.eosfs:
                try:
                    nb = newname.encode('ascii')
                except UnicodeEncodeError:
                    raise SdfsError('EOSFS name is not ASCII: %r' % newname)
                if (not nb or len(nb) > EOSFS_NAME_MAX or any(c in b'/*?' for c in nb) or
                        any(c < 0x20 or c >= 0x7F for c in nb)):
                    raise SdfsError('invalid EOSFS name: %r' % newname)
                raw[pos[o + 6]] = len(nb)
                for k in range(EOSFS_NAME_MAX):
                    raw[pos[o + 7 + k]] = nb[k] if k < len(nb) else 0
            else:
                b, _, ext = newname.upper().partition('.')
                nb = b.ljust(8).encode()[:8] + ext.ljust(3).encode()[:3]
                for k in range(11):
                    raw[pos[o + 6 + k]] = nb[k]
        Path(path).write_bytes(raw)
        return
    raise SdfsError('%s: not in the main directory' % name)

def attrs(st):
    return ''.join(c if st & b else '-' for c, b in
                   (('d', ST_DIR), ('l', ST_LINK), ('p', ST_PROT), ('h', ST_HIDDEN), ('a', ST_ARCH)))


def main():
    cmd, path = sys.argv[1:3]
    if cmd == 'build':
        import os
        total, seclen, root = int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
        files = {}
        for dp, dn, fn in os.walk(root):
            for n in sorted(fn):
                full = os.path.join(dp, n)
                files[os.path.relpath(full, root).replace(os.sep, '/')] = open(full, 'rb').read()
        build(path, total, seclen, files)
        return
    v = Volume(path)
    entries = v.check()
    if cmd == 'ls':
        print('%s: SDFS %d.%d, %d x %d, volume %r, free %d' % (
            path, v.version >> 4, v.version & 15, v.total, v.seclen, v.name, v.free))
        for p, e in entries:
            print('%s %8d  %s' % (attrs(e['status']), e.get('dirlen', e['length']), p))
    elif cmd == 'extract':
        import os
        dest = sys.argv[3]
        for p, e in entries:
            t = os.path.join(dest, p.lstrip('/'))
            if e['status'] & ST_DIR:
                os.makedirs(t, exist_ok=True)
            else:
                os.makedirs(os.path.dirname(t), exist_ok=True)
                open(t, 'wb').write(e['data'])
    for w in v.warnings:
        print('warning:', w)
    for e in v.errors:
        print('error:', e)
    if cmd == 'check':
        print('%s: %d entries, %d errors, %d warnings' % (path, len(entries), len(v.errors), len(v.warnings)))
    sys.exit(1 if v.errors else 0)


if __name__ == '__main__':
    main()
