#!/usr/bin/env python3

import math
import numpy as np

camera = 4
scale = 100
vertex_x = 1
vertex_y = 0
vertex_z = 0

# TABLE 1: 40K

# INPUTS:
# theta angle = 0-255
# magnitude = 0-31

# OUTPUTS:
# x LSB
# x MSB
# y of shadow
# page for scale table for y
# bank for scale table for y

# TABLE 2: up to 64K

# INPUTS
# scale table = 0-255
# y value = 0-255

# OUTPUT
# y value on screen

resolved_x = []
shadow_y = []
scale_amount = []
scale_lookup = []

with open("BALLTABLE1.DAT", mode="wb") as file:
    for magnitude in range(32):
        for theta in range(256):
            angle_y = (theta*2*math.pi)/256
            scaled_x = vertex_x * (magnitude / 31)

            # Rotate around the y-axis
            new_x = scaled_x * math.cos(angle_y) - vertex_z * math.sin(angle_y)
            new_z = scaled_x * math.sin(angle_y) + vertex_z * math.cos(angle_y)

            z_ratio = (camera) / (new_z + camera) # camera position

            new_x *= z_ratio
            scaled_x = round(new_x*scale*1.3)+160
            if scaled_x < 0:
                scaled_x += 65536

            resolved_x.append(scaled_x)

            ysh = round(z_ratio*scale)+50+3
            if ysh < 0 or ysh >= 200:
                raise RuntimeError(f"ysh {ysh}")
            shadow_y.append(ysh)
            scale_amount.append(round(z_ratio,2))

    uniq_scales = np.unique(np.array(scale_amount))
    print(shadow_y)
    print(uniq_scales)
    print(len(uniq_scales))

    for sa in scale_amount:
        scale_lookup.append(np.where(uniq_scales == sa)[0][0])

    for x in resolved_x:
        # Low X
        file.write(bytes([x & 0xff]))
    for x in resolved_x:
        # High X
        file.write(bytes([(x >> 8) & 0xff]))
    for y in shadow_y:
        # Shadow for Y
        file.write(bytes([y & 0xff]))
    for s in scale_lookup:
        # Scale table lookup, page address
        page = (s & 0x1f) + 0xa0
        file.write(bytes([page & 0xff]))
    for s in scale_lookup:
        # Scale table lookup, bank address
        bank = (s // 32) + 0x20
        file.write(bytes([bank & 0xff]))

if len(uniq_scales) > 256:
    raise RuntimeError(f"Uniq scales count {len(uniq_scales)} > 256")

with open("BALLTABLE2.DAT", mode="wb") as file:
    for us in uniq_scales:
        for y in range(256):
            ty = round(us*scale*(y-128)/128)+50
            if ty <= 0:
                ty = 255
            elif ty >= 200:
                raise RuntimeError(f"ty {ty}")
            file.write(bytes([ty & 0xff]))
