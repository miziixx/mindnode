"""Float32 WAV 입출력. 저장값 == 분석에 쓴 PCM(무손실 IEEE float)."""
from __future__ import annotations
import struct
import numpy as np


def write_wav_float32(path: str, channels, sr: int):
    """channels: mono면 1D array, stereo면 (L, R) 튜플. WAVE_FORMAT_IEEE_FLOAT."""
    if isinstance(channels, tuple):
        l, r = channels
        n = min(len(l), len(r))
        inter = np.empty(n * 2, dtype=np.float32)
        inter[0::2] = np.asarray(l[:n], np.float32)
        inter[1::2] = np.asarray(r[:n], np.float32)
        nch = 2
        data = inter
    else:
        data = np.asarray(channels, np.float32)
        nch = 1
        n = len(data)

    raw = data.tobytes()
    byte_rate = sr * nch * 4
    block_align = nch * 4
    with open(path, 'wb') as f:
        f.write(b'RIFF')
        f.write(struct.pack('<I', 36 + len(raw)))
        f.write(b'WAVE')
        f.write(b'fmt ')
        f.write(struct.pack('<I', 16))
        f.write(struct.pack('<H', 3))  # 3 = IEEE float
        f.write(struct.pack('<H', nch))
        f.write(struct.pack('<I', sr))
        f.write(struct.pack('<I', byte_rate))
        f.write(struct.pack('<H', block_align))
        f.write(struct.pack('<H', 32))  # bits
        f.write(b'data')
        f.write(struct.pack('<I', len(raw)))
        f.write(raw)


def read_wav_float32(path: str):
    """(data, sr, nch) 반환. float32 또는 int16 지원(int16은 정규화)."""
    with open(path, 'rb') as f:
        b = f.read()
    assert b[:4] == b'RIFF' and b[8:12] == b'WAVE'
    pos = 12
    fmt = None
    sr = 0
    nch = 1
    bits = 32
    data = None
    while pos + 8 <= len(b):
        cid = b[pos:pos + 4]
        size = struct.unpack('<I', b[pos + 4:pos + 8])[0]
        body = b[pos + 8:pos + 8 + size]
        if cid == b'fmt ':
            fmt, nch, sr, _, _, bits = struct.unpack('<HHIIHH', body[:16])
        elif cid == b'data':
            if fmt == 3:
                data = np.frombuffer(body, dtype=np.float32)
            else:
                data = np.frombuffer(body, dtype=np.int16).astype(
                    np.float32) / 32768.0
        pos += 8 + size + (size & 1)
    return data, sr, nch
