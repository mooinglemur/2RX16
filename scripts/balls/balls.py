#!/usr/bin/env python3

# The original demo would rotate the field of balls about the center Y axis
# Thus our balls demo uses polar coordinates and a y-scaling lookup, which is
# fast and gives very reasonable lookup table sizes
#
# In ASM, the ball locations are specified as original angle (theta) and
# magnitude (radius), along with an internal Y coordinate, which is translated
# by these lookup tables to output X and Y coordinates, along with the Y
# coordinate where the shadow shall be placed (at the same X coordinate as
# the ball itself).

# The choreography output looks like this
#
# $nn - number of extra frames to delay before placing this ball, when zero,
#       this ball is placed on the frame immediately following the previous one
# $tt - theta angle
# $mm - magnitude, or radius ($A0-$BF, where $A0 is center and $BF is the outer edge)
#                             ^-- corresponds to the high RAM page for the lookup table
# $yy - starting internal Y value
# $pp - momentum (fractional)
# $qq - momentum (integer)

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
# scale table = 0-n
# y value = 0-255

# OUTPUT
# y value on screen

def isin(deg):
	return math.sin(math.pi * deg / 512) * 255

def icos(deg):
	return math.cos(math.pi * deg / 512) * 255

sin1024 = [0,1,3,4,6,7,9,10,12,14,15,17,18,20,21,23,25,26,28,29,31,32,34,36,37,39,40,42,43,45,46,48,
	49,51,53,54,56,57,59,60,62,63,65,66,68,69,71,72,74,75,77,78,80,81,83,84,86,87,89,90,92,93,95,96,
	97,99,100,102,103,105,106,108,109,110,112,113,115,116,117,119,120,122,123,124,126,127,128,130,131,132,134,135,136,138,139,140,
	142,143,144,146,147,148,149,151,152,153,155,156,157,158,159,161,162,163,164,166,167,168,169,170,171,173,174,175,176,177,178,179,
	181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,211,
	212,213,214,215,216,217,217,218,219,220,221,221,222,223,224,225,225,226,227,227,228,229,230,230,231,232,232,233,234,234,235,235,
	236,237,237,238,238,239,239,240,241,241,242,242,243,243,244,244,244,245,245,246,246,247,247,247,248,248,249,249,249,250,250,250,
	251,251,251,251,252,252,252,252,253,253,253,253,254,254,254,254,254,254,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
	256,255,255,255,255,255,255,255,255,255,255,255,255,255,255,254,254,254,254,254,254,253,253,253,253,252,252,252,252,251,251,251,
	251,250,250,250,249,249,249,248,248,247,247,247,246,246,245,245,244,244,244,243,243,242,242,241,241,240,239,239,238,238,237,237,
	236,235,235,234,234,233,232,232,231,230,230,229,228,227,227,226,225,225,224,223,222,221,221,220,219,218,217,217,216,215,214,213,
	212,211,211,210,209,208,207,206,205,204,203,202,201,200,199,198,197,196,195,194,193,192,191,190,189,188,187,186,185,184,183,182,
	181,179,178,177,176,175,174,173,171,170,169,168,167,166,164,163,162,161,159,158,157,156,155,153,152,151,149,148,147,146,144,143,
	142,140,139,138,136,135,134,132,131,130,128,127,126,124,123,122,120,119,117,116,115,113,112,110,109,108,106,105,103,102,100,99,
	97,96,95,93,92,90,89,87,86,84,83,81,80,78,77,75,74,72,71,69,68,66,65,63,62,60,59,57,56,54,53,51,
	49,48,46,45,43,42,40,39,37,36,34,32,31,29,28,26,25,23,21,20,18,17,15,14,12,10,9,7,6,4,3,1,
	0,-1,-3,-4,-6,-7,-9,-10,-12,-14,-15,-17,-18,-20,-21,-23,-25,-26,-28,-29,-31,-32,-34,-36,-37,-39,-40,-42,-43,-45,-46,-48,
	-49,-51,-53,-54,-56,-57,-59,-60,-62,-63,-65,-66,-68,-69,-71,-72,-74,-75,-77,-78,-80,-81,-83,-84,-86,-87,-89,-90,-92,-93,-95,-96,
	-97,-99,-100,-102,-103,-105,-106,-108,-109,-110,-112,-113,-115,-116,-117,-119,-120,-122,-123,-124,-126,-127,-128,-130,-131,-132,-134,-135,-136,-138,-139,-140,
	-142,-143,-144,-146,-147,-148,-149,-151,-152,-153,-155,-156,-157,-158,-159,-161,-162,-163,-164,-166,-167,-168,-169,-170,-171,-173,-174,-175,-176,-177,-178,-179,
	-181,-182,-183,-184,-185,-186,-187,-188,-189,-190,-191,-192,-193,-194,-195,-196,-197,-198,-199,-200,-201,-202,-203,-204,-205,-206,-207,-208,-209,-210,-211,-211,
	-212,-213,-214,-215,-216,-217,-217,-218,-219,-220,-221,-221,-222,-223,-224,-225,-225,-226,-227,-227,-228,-229,-230,-230,-231,-232,-232,-233,-234,-234,-235,-235,
	-236,-237,-237,-238,-238,-239,-239,-240,-241,-241,-242,-242,-243,-243,-244,-244,-244,-245,-245,-246,-246,-247,-247,-247,-248,-248,-249,-249,-249,-250,-250,-250,
	-251,-251,-251,-251,-252,-252,-252,-252,-253,-253,-253,-253,-254,-254,-254,-254,-254,-254,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,
	-256,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,-255,-254,-254,-254,-254,-254,-254,-253,-253,-253,-253,-252,-252,-252,-252,-251,-251,-251,
	-251,-250,-250,-250,-249,-249,-249,-248,-248,-247,-247,-247,-246,-246,-245,-245,-244,-244,-244,-243,-243,-242,-242,-241,-241,-240,-239,-239,-238,-238,-237,-237,
	-236,-235,-235,-234,-234,-233,-232,-232,-231,-230,-230,-229,-228,-227,-227,-226,-225,-225,-224,-223,-222,-221,-221,-220,-219,-218,-217,-217,-216,-215,-214,-213,
	-212,-211,-211,-210,-209,-208,-207,-206,-205,-204,-203,-202,-201,-200,-199,-198,-197,-196,-195,-194,-193,-192,-191,-190,-189,-188,-187,-186,-185,-184,-183,-182,
	-181,-179,-178,-177,-176,-175,-174,-173,-171,-170,-169,-168,-167,-166,-164,-163,-162,-161,-159,-158,-157,-156,-155,-153,-152,-151,-149,-148,-147,-146,-144,-143,
	-142,-140,-139,-138,-136,-135,-134,-132,-131,-130,-128,-127,-126,-124,-123,-122,-120,-119,-117,-116,-115,-113,-112,-110,-109,-108,-106,-105,-103,-102,-100,-99,
	-97,-96,-95,-93,-92,-90,-89,-87,-86,-84,-83,-81,-80,-78,-77,-75,-74,-72,-71,-69,-68,-66,-65,-63,-62,-60,-59,-57,-56,-54,-53,-51,
	-49,-48,-46,-45,-43,-42,-40,-39,-37,-36,-34,-32,-31,-29,-28,-26,-25,-23,-21,-20,-18,-17,-15,-14,-12,-10,-9,-7,-6,-4,-3,-1]

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

with open("BALLCHOREO.DAT", mode="wb") as file:
    f = 0
    frame = 0
    dropper = 22000
    fskipped = 0
    rot = 0
    rotcos=icos(rot)*64
    rotsin=isin(rot)*64

    while frame < 1700:
        if frame == 500:
            f = 0
        if frame < 500:
            dx = isin(f*11)*40
            dy = icos(f*13)*10-dropper
            dz = isin(f*17)*40
            yadd = 0
        elif frame < 900:
            dx = icos(f*15)*55
            dy = dropper
            dz = isin(f*15)*55
            yadd = -260
        elif frame < 1700:
            a = sin1024[frame&1023]/8
            dx = icos(f*66)*a
            dy = 8000
            dz = isin(f*66)*a
            yadd=-300

        if dropper>4000:
            dropper-=100

        if frame < 256:
            fskip = 1
        else:
            fskip = 2

        # translate to polar coords
        a = math.atan2(dz,dx)+math.pi
        r = math.sqrt(dx**2 + dz**2)

        # scale to our demo's range
        a = round(256*a/(2*math.pi))
        r = round(r*31/14025.0)

        # scale y down
        y = dy/8000

        if y < -1:
            addl_accel = 0 - (y+1)
            y = -1
        else:
            addl_accel = 0

        yadd /= 50

        y = round((y + 1)*127.5)

        m = addl_accel + yadd

        m = round(65536+(m * 256)) & 0xffff

        if r > 31:
            r = 31

        print([frame,a,r,y,m])
        if fskipped >= fskip:
            file.write(bytes([fskipped,a & 0xff,r+0xa0,y,m & 0xff,(m >> 8) & 0xff]))
            fskipped = 0
        else:
            print("skipped")
            fskipped += 1

        frame += 1
        f += 1
