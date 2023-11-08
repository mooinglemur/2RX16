#!/usr/bin/env python3

import math
import numpy as np

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def list_to_dotbyte_strings(lst, size=16):
    result = []
    for chunk in chunks(lst, size):
        result.append("\t.byte " + ','.join(['${:02x}'.format(int(x)) for x in chunk]) + "\n")
    return result

map1xl = []
map1yl = []
map2xl = []
map2yl = []

SCALE = 50

for i in range(256):
    yy = -math.sin(2.0 * math.pi * i / 256)
    xx = math.cos(2.0 * math.pi * i / 256)
    twos_x = (SCALE + round(xx * SCALE) + 65536) % 65536
    twos_y = (SCALE + round(yy * SCALE) + 65536) % 65536
    map1xl.append(twos_x & 0xff)
    map1yl.append(twos_y & 0xff)

for i in range(199):
    yy = -math.sin(2.0 * math.pi * i / 199)
    xx = math.cos(2.0 * math.pi * i / 199)
    twos_x = (SCALE + round(xx * SCALE) + 65536) % 65536
    twos_y = (SCALE + round(yy * SCALE) + 65536) % 65536
    map2xl.append(twos_x & 0xff)
    map2yl.append(twos_y & 0xff)

print("sinmap1_x:")
print("".join(list_to_dotbyte_strings(map1xl, 16)))
print("sinmap1_y:")
print("".join(list_to_dotbyte_strings(map1yl, 16)))

print("sinmap2_x:")
print("".join(list_to_dotbyte_strings(map2xl, 16)))
print("sinmap2_y:")
print("".join(list_to_dotbyte_strings(map2yl, 16)))


