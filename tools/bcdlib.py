"""bcdlib.py: numbers in the formats of the Math-Pack, for the test generators."""
from decimal import Decimal


def bcd(text, digits=14):
    """The 8 bytes of a real number: sign / excess-64 exponent, then the digits."""
    d = Decimal(text)
    if d == 0:
        return [0] * 8
    sign = 0x80 if d < 0 else 0
    t = d.copy_abs().as_tuple()
    ds = list(t.digits)
    while ds and ds[0] == 0:
        ds.pop(0)
    exponent = len(ds) + t.exponent         # 0.ds * 10^exponent
    ds = (ds + [0] * digits)[:digits]
    ds += [0] * (14 - len(ds))
    out = [sign | (exponent + 64)]
    for i in range(0, 14, 2):
        out.append(ds[i] * 16 + ds[i + 1])
    return out

def integer(v):
    v &= 0xFFFF
    return [0, 0, v & 0xFF, v >> 8, 0, 0, 0, 0]
