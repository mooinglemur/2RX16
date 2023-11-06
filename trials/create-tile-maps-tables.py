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

map1 = []
map2 = []

for tile in range(1024):
    if tile < 512:
        if (tile & 0x10):
            idx = ((tile & 0xfe0) + 0x1f) - (tile - ((tile & 0xfe0) >> 1))
            flip = 0x04
            map2t = 0x01
        else:
            idx = tile - ((tile & 0xfe0) >> 1)
            flip = 0x00
            map2t = 0x00
    else:
        if (tile & 0x10):
            idx = ((tile & 0xfe0) + 0x1f) - (tile - ((tile & 0xfe0) >> 1)) - ((tile & 0xfe0) - 0x1f0)
            flip = 0x0c
            map2t = 0x00
        else:
            idx = (tile - ((tile & 0xfe0) >> 1)) - ((tile & 0xfe0) - 0x1f0)
            flip = 0x08
            map2t = 0x01
    map1.append(idx)
    map2.append(idx)
    map1.append(flip | 0x00)
    map2.append(flip | 0x10 | map2t)



print("map1tbl:")
print("".join(list_to_dotbyte_strings(map1, 16)))
print("map2tbl:")
print("".join(list_to_dotbyte_strings(map2, 16)))

