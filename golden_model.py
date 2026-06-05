#!/usr/bin/env python3
import argparse
import math
import struct
from typing import Tuple

try:
    import numpy as np
except ImportError as exc:
    raise SystemExit("numpy is required. Run: pip install numpy") from exc


def f32(x: float) -> np.float32:
    return np.float32(x)


def f32_bits(x: np.float32) -> int:
    return struct.unpack(">I", struct.pack(">f", float(x)))[0]


def bits_to_f32(bits: int) -> np.float32:
    return np.float32(struct.unpack(">f", struct.pack(">I", bits & 0xFFFFFFFF))[0])


LOG2_M0 = [
    bits_to_f32(0x3d35d69c), bits_to_f32(0x3e0462c4), bits_to_f32(0x3e567af1), bits_to_f32(0x3e92203d),
    bits_to_f32(0x3eb7110e), bits_to_f32(0x3eda3f60), bits_to_f32(0x3efbd42b), bits_to_f32(0x3f0df989),
    bits_to_f32(0x3f1d5da0), bits_to_f32(0x3f2c2411), bits_to_f32(0x3f3a58ff), bits_to_f32(0x3f480731),
    bits_to_f32(0x3f553848), bits_to_f32(0x3f61f4e5), bits_to_f32(0x3f6e44cd), bits_to_f32(0x3f7a2f04),
]
INV_M0 = [
    bits_to_f32(0x3f783e10), bits_to_f32(0x3f6a0ea1), bits_to_f32(0x3f5d67c9), bits_to_f32(0x3f520d21),
    bits_to_f32(0x3f47ce0c), bits_to_f32(0x3f3e82fa), bits_to_f32(0x3f360b61), bits_to_f32(0x3f2e4c41),
    bits_to_f32(0x3f272f05), bits_to_f32(0x3f20a0a1), bits_to_f32(0x3f1a90e8), bits_to_f32(0x3f14f209),
    bits_to_f32(0x3f0fb824), bits_to_f32(0x3f0ad8f3), bits_to_f32(0x3f064b8a), bits_to_f32(0x3f020821),
]
EXP2_BASE = [
    bits_to_f32(0x3f800000), bits_to_f32(0x3f85aac3), bits_to_f32(0x3f8b95c2), bits_to_f32(0x3f91c3d3),
    bits_to_f32(0x3f9837f0), bits_to_f32(0x3f9ef532), bits_to_f32(0x3fa5fed7), bits_to_f32(0x3fad583f),
    bits_to_f32(0x3fb504f3), bits_to_f32(0x3fbd08a4), bits_to_f32(0x3fc5672a), bits_to_f32(0x3fce248c),
    bits_to_f32(0x3fd744fd), bits_to_f32(0x3fe0ccdf), bits_to_f32(0x3feac0c7), bits_to_f32(0x3ff5257d),
]
K_OVER_16 = [
    bits_to_f32(0x00000000), bits_to_f32(0x3d800000), bits_to_f32(0x3e000000), bits_to_f32(0x3e400000),
    bits_to_f32(0x3e800000), bits_to_f32(0x3ea00000), bits_to_f32(0x3ec00000), bits_to_f32(0x3ee00000),
    bits_to_f32(0x3f000000), bits_to_f32(0x3f100000), bits_to_f32(0x3f200000), bits_to_f32(0x3f300000),
    bits_to_f32(0x3f400000), bits_to_f32(0x3f500000), bits_to_f32(0x3f600000), bits_to_f32(0x3f700000),
]

LN2 = f32(math.log(2.0))
INV_LN2 = f32(1.0 / math.log(2.0))
PI = f32(math.pi)
PI_OVER_2 = f32(math.pi / 2.0)
TWO_PI_OVER_3 = f32(2.0 * math.pi / 3.0)
FOUR_PI_OVER_3 = f32(4.0 * math.pi / 3.0)
SQRT3_OVER_2 = f32(math.sqrt(3.0) / 2.0)


def log2_f32(x: np.float32) -> np.float32:
    if np.isnan(x):
        return f32(np.nan)
    if x == 0.0:
        return f32(-math.inf)
    if x < 0.0:
        return f32(np.nan)
    if np.isinf(x):
        return f32(math.inf)

    bits = f32_bits(x)
    exp = (bits >> 23) & 0xFF
    frac = bits & 0x7FFFFF
    e = int(exp) - 127
    if frac == 0 and exp != 0 and exp != 0xFF:
        return f32(e)
    m_bits = (0x7F << 23) | frac
    m = bits_to_f32(m_bits)

    idx = (frac >> 19) & 0xF
    m0 = LOG2_M0[idx]
    inv_m0 = INV_M0[idx]

    y = f32(m * inv_m0 - f32(1.0))
    num = f32(y * (f32(6.0) + y))
    den = f32(f32(6.0) + f32(4.0) * y)
    ln1p = f32(num / den)

    log2_m = f32(m0 + ln1p * INV_LN2)
    return f32(log2_m + f32(e))


def exp2_f32(x: np.float32) -> np.float32:
    if np.isnan(x):
        return f32(np.nan)
    if np.isinf(x):
        return f32(math.inf) if x > 0 else f32(0.0)

    n = math.floor(float(x))
    f = f32(x - f32(n))
    k = int(math.floor(float(f * f32(16.0))))
    if k < 0:
        k = 0
    if k > 15:
        k = 15
    f_res = f32(f - K_OVER_16[k])

    t = f32(f_res * LN2)
    t2 = f32(t * t)
    six_t = f32(f32(6.0) * t)
    num = f32(f32(12.0) + six_t + t2)
    den = f32(f32(12.0) - six_t + t2)
    exp_frac = f32(num / den)
    exp2_f = f32(EXP2_BASE[k] * exp_frac)
    return f32(math.ldexp(float(exp2_f), n))


def sqrt_f32(x: np.float32) -> np.float32:
    if np.isnan(x):
        return f32(np.nan)
    if x < 0.0:
        return f32(np.nan)
    if x == 0.0:
        return f32(0.0)
    if np.isinf(x):
        return f32(math.inf)
    return exp2_f32(f32(log2_f32(x) * f32(0.5)))


def cbrt_f32(x: np.float32) -> np.float32:
    if np.isnan(x):
        return f32(np.nan)
    if x == 0.0:
        return f32(0.0)
    if np.isinf(x):
        return f32(math.copysign(math.inf, float(x)))
    sign = f32(-1.0) if x < 0 else f32(1.0)
    return f32(sign * exp2_f32(f32(log2_f32(f32(abs(float(x)))) * f32(1.0/3.0))))


def cos_f32(x: np.float32) -> np.float32:
    if np.isnan(x):
        return f32(np.nan)
    xa = f32(abs(float(x)))
    if f32_bits(xa) == f32_bits(f32(0.0)):
        return f32(1.0)
    if f32_bits(xa) == f32_bits(PI_OVER_2):
        return f32(0.0)
    if f32_bits(xa) == f32_bits(PI):
        return f32(-1.0)
    sign_flip = False
    if xa > PI:
        xa = f32(xa - PI)
        sign_flip = not sign_flip
    if xa > PI_OVER_2:
        xa = f32(PI - xa)
        sign_flip = not sign_flip
    x2 = f32(xa * xa)
    num = f32(f32(12.0) - f32(5.0) * x2)
    den = f32(f32(12.0) + x2)
    c = f32(num / den)
    return f32(-c) if sign_flip else c


def acos_f32(x: np.float32) -> np.float32:
    if np.isnan(x):
        return f32(np.nan)
    if abs(float(x)) > 1.0:
        return f32(np.nan)
    x2 = f32(x * x)
    a = f32(-0.2833333333333333)
    b = f32(-0.45)
    num = f32(f32(1.0) + a * x2)
    den = f32(f32(1.0) + b * x2)
    asin = f32(x * (num / den))
    return f32(PI_OVER_2 - asin)


def solve_cubic(a: float, b: float, c: float, d: float) -> Tuple[np.complex64, np.complex64, np.complex64]:
    a = f32(a)
    b = f32(b)
    c = f32(c)
    d = f32(d)

    if a == 0.0:
        nan = np.complex64(np.nan)
        return nan, nan, nan

    A = f32(b / a)
    B = f32(c / a)
    C = f32(d / a)

    A_over3 = f32(A * f32(1.0/3.0))
    p = f32(B - f32(A * A) * f32(1.0/3.0))
    q = f32(f32(2.0/27.0) * f32(A * A * A) - f32(A * B) * f32(1.0/3.0) + C)

    q_over2 = f32(q * f32(0.5))
    p_over3 = f32(p * f32(1.0/3.0))
    disc = f32(q_over2 * q_over2 + p_over3 * p_over3 * p_over3)

    if float(disc) >= 0.0:
        sqrt_disc = sqrt_f32(disc)
        u = cbrt_f32(f32(-q_over2 + sqrt_disc))
        v = cbrt_f32(f32(-q_over2 - sqrt_disc))
        y1 = f32(u + v)
        diff = f32(u - v)
        half_sum_neg = f32(-0.5) * y1
        imag = f32(SQRT3_OVER_2 * diff)
        x0 = np.complex64(f32(y1 - A_over3))
        x1 = np.complex64(f32(half_sum_neg - A_over3)) + np.complex64(1j * float(imag))
        x2 = np.complex64(f32(half_sum_neg - A_over3)) - np.complex64(1j * float(imag))
        return x0, x1, x2

    neg_p_over3 = f32(-p_over3)
    sqrt_neg_p_over3 = sqrt_f32(neg_p_over3)
    t = f32(f32(2.0) * sqrt_neg_p_over3)
    denom = f32(sqrt_neg_p_over3 * sqrt_neg_p_over3 * sqrt_neg_p_over3)
    r = f32(f32(-q_over2) / denom)
    phi = acos_f32(r)
    phi_over3 = f32(phi * f32(1.0/3.0))
    y1 = f32(t * cos_f32(phi_over3))
    y2 = f32(t * cos_f32(f32(phi_over3 + TWO_PI_OVER_3)))
    y3 = f32(t * cos_f32(f32(phi_over3 + FOUR_PI_OVER_3)))
    x0 = np.complex64(f32(y1 - A_over3))
    x1 = np.complex64(f32(y2 - A_over3))
    x2 = np.complex64(f32(y3 - A_over3))
    return x0, x1, x2


def print_hex(label: str, x: np.float32) -> None:
    print(f"{label}: 0x{f32_bits(x):08x} ({float(x)})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--demo", action="store_true")
    parser.add_argument("--lut", action="store_true")
    parser.add_argument("--cases", action="store_true")
    args = parser.parse_args()

    if args.lut:
        print("LOG2_M0:")
        for i, v in enumerate(LOG2_M0):
            print(i, hex(f32_bits(v)))
        print("INV_M0:")
        for i, v in enumerate(INV_M0):
            print(i, hex(f32_bits(v)))
        print("EXP2_BASE:")
        for i, v in enumerate(EXP2_BASE):
            print(i, hex(f32_bits(v)))
        print("K_OVER_16:")
        for i, v in enumerate(K_OVER_16):
            print(i, hex(f32_bits(v)))

    if args.cases:
        cases = [
            (1.0, -7.0, 14.0, -8.0, "three_real"),
            (1.0, 0.0, 0.0, -1.0, "one_real_two_complex"),
            (1.0, -1.0, -8.0, 12.0, "double_root"),
        ]
        for a, b, c, d, name in cases:
            x0, x1, x2 = solve_cubic(a, b, c, d)
            print(name)
            print("x0", hex(f32_bits(x0.real)), hex(f32_bits(x0.imag)))
            print("x1", hex(f32_bits(x1.real)), hex(f32_bits(x1.imag)))
            print("x2", hex(f32_bits(x2.real)), hex(f32_bits(x2.imag)))

    if args.demo or not (args.lut or args.cases):
        x0, x1, x2 = solve_cubic(1.0, -7.0, 14.0, -8.0)
        print("demo roots:")
        print(x0, x1, x2)


if __name__ == "__main__":
    main()
