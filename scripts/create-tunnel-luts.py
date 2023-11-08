#!/usr/bin/env python3

import math
import numpy as np

SIN_SIZE = 256
COS_OFF = 64

LEVELS = 128
POINTS = 64

LISS_SCALE_X = 15
LISS_SCALE_Y = 10
SCALE_X = 25
SCALE_Y = 35

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def list_to_dotbyte_strings(lst, size=16):
    result = []
    for chunk in chunks(lst, size):
        result.append("\t.byte " + ','.join(['${:02x}'.format(int(x)) for x in chunk]) + "\n")
    return result


tun_coords_x_l = [[None for _ in range(POINTS)] for _ in range(LEVELS)]
tun_coords_x_h = [[None for _ in range(POINTS)] for _ in range(LEVELS)]
tun_coords_y_l = [[None for _ in range(POINTS)] for _ in range(LEVELS)]
tun_coords_y_h = [[None for _ in range(POINTS)] for _ in range(LEVELS)]

tun_coords = []

# Create the sin/cos tables
sincosx = []
sincosy = []
sincosf = []

for i in range(SIN_SIZE + COS_OFF):
    v = math.sin(2.0 * math.pi * i / SIN_SIZE)
    twos_x = (round(v * LISS_SCALE_X) + 65536) % 65536
    twos_y = (round(v * LISS_SCALE_Y) + 65536) % 65536
    sincosx.append(twos_x & 0xff)
    sincosy.append(twos_y & 0xff)
    sincosf.append(v)

# Create tunnel coords

for i in range(LEVELS):
    proj = (i+1) / LEVELS
    for j in range(POINTS):
        xx = round((sincosf[int(j * SIN_SIZE/POINTS) + COS_OFF] * SCALE_X) / proj) + 80
        if xx > 200:
            xx = 200
        if xx < -40:
            xx = -40
        yy = round((sincosf[int(j * SIN_SIZE/POINTS)] * SCALE_Y) / proj) + 100
        if yy > 225:
            yy = 225
        if yy < -25:
            yy = -25

        twos_x = (xx + 65536) % 65536
        tun_coords_x_l[i][j] = (twos_x & 0xff)
        tun_coords_x_h[i][j] = (twos_x >> 8)
        twos_y = (yy + 65536) % 65536
        tun_coords_y_l[i][j] = (twos_y & 0xff)
        tun_coords_y_h[i][j] = (twos_y >> 8)

        tun_coords.append(tun_coords_y_l[i][j])
        tun_coords.append(tun_coords_x_l[i][j])
        

print("cosmtbl_x := sinmtbl_x+64")
print("sinmtbl_x:")
print("".join(list_to_dotbyte_strings(sincosx, 8)))

print("cosmtbl_y := sinmtbl_y+64")
print("sinmtbl_y:")
print("".join(list_to_dotbyte_strings(sincosy, 8)))

print("times2p32:")
print("".join(list_to_dotbyte_strings([((_*2+32) % 256) for _ in range(256)], 8)))

print("times3:")
print("".join(list_to_dotbyte_strings([((_*3) % 256) for _ in range(256)], 8)))

print("times4:")
print("".join(list_to_dotbyte_strings([((_*4) % 256) for _ in range(256)], 8)))

print("level2color:")
print("".join(list_to_dotbyte_strings([int((LEVELS - _ - 1) / 8.5) + (int((LEVELS - _ - 1) / 8.5)*16) + 17 for _ in range(LEVELS)], 8)))


print(".segment \"TUNCOORDS\"")

print("".join(list_to_dotbyte_strings(tun_coords, 8)))

