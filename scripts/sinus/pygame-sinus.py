#!/usr/bin/env python3

import pygame
from pygame.locals import *
from shapely.geometry import Polygon, MultiPolygon, LineString
from shapely.ops import unary_union, split
from shapely.validation import make_valid
from shapely import equals
import math
import numpy as np
from PIL import Image

BLACK = (0, 0, 0)
BLUE  = (64, 64, 255)
RED  = (255, 64, 64)
GREEN = (64, 255, 64)

colors = [BLUE, GREEN, RED]

clock=pygame.time.Clock()

# Set up the display
width, height = 640, 400
screen = pygame.display.set_mode((width, height))
pygame.display.set_caption("2R Sinusfield")

running = True

step = 0

maxpx = 0
minpx = 255

with open("SINUSTILES.DAT", mode="wb") as file:
    while running:
        for event in pygame.event.get():
            if event.type == QUIT:
                running = False

        screen.fill(BLACK)

        for ys in range(-1000,1000):
            for xx in range(-31,129):
                yy = ys/10
                sval = math.sin(yy*math.pi/32)*math.sin(xx*math.pi/32)*math.sin(step*math.pi/30)
                if sval < 0:
                    color = (255*-sval/3, 0, 127)
                else:
                    color = (255*sval/3, 255*sval/3, 127+(128*sval/3))

                height = ((sval+6)/8)*254
                height -= 14
                height = round(height)
                color = (height, height, height)

                zz = sval * 20
                camera = -100
                angle_x = 0
                angle_y = 0
                angle_z = 0

                angle_x = math.radians(60)

                # Rotate around the x-axis
                new_y = yy * math.cos(angle_x) - zz * math.sin(angle_x)
                new_z = yy * math.sin(angle_x) + zz * math.cos(angle_x)

                # Rotate around the y-axis
                new_x = xx * math.cos(angle_y) - new_z * math.sin(angle_y)
                new_z = xx * math.sin(angle_y) + new_z * math.cos(angle_y)

                # Rotate around the z-axis
                tmp_x = new_x * math.cos(angle_z) - new_y * math.sin(angle_z)
                new_y = new_x * math.sin(angle_z) + new_y * math.cos(angle_z)
                new_x = tmp_x

                z_ratio = camera / (new_z + camera) # camera position

                #new_x *= z_ratio
                #new_y *= z_ratio

                new_y += 100
                new_x += 320

                # remove X projection, align y projection
                new_x = xx+31
                new_y -= 36

                if new_y < 8*7:
                    screen.set_at((int(new_x), int(new_y)), color)

        # duplicate rows
        rect = pygame.Rect(0,3*8,64,32)
        sub = screen.subsurface(rect).copy()
        screen.blit(sub,(0,7*8))
        screen.blit(sub,(0,11*8))
        screen.blit(sub,(0,15*8))

        # output tiles
        # output zero tile first
        file.write(bytes([0] * 64))

        for trow in range(7):
            for tcol in range(8):
                for crow in range(8):
                    for ccol in range(8):
                        yy = (trow*8)+crow
                        xx = (tcol*8)+ccol
                        px = screen.get_at((xx, yy))[0]
                        if px > 0:
                            px -= 161
                        if minpx > px and px > 0:
                            minpx = px
                        if maxpx < px:
                            maxpx = px
                        file.write(bytes([px]))

        # output 7 more zero tiles for padding
        file.write(bytes([0] * 64 * 7))

        pygame.display.flip()
        clock.tick(60)

        step += 1

        if step >= 15:
            running = False

with open("SINUSMAP.DAT", mode="wb") as file:
    # output 16 rows of zero tiles
    file.write(bytes([0] * 16 * 32))

    for r in range(3): # first 3 rows are normal
        for c in range(32):
            t = (r * 8) + (c % 8) + 1
            file.write(bytes([t]))

    # now repeat lines 3-6 four times

    for rpt in range(4):
        for r in range(3,7):
            for c in range(32):
                t = (r * 8) + (c % 8) + 1
                file.write(bytes([t]))



print(minpx)
print(maxpx)

sintbl = []

for i in range(256):
    s = 1+math.cos((i*math.pi/256)+math.pi)
    s /= 2
    s *= 256
    sintbl.append(s)

print(".byte ", end="")

for i in sintbl:
    print(f"${int(i * 256) & 0xff:02x},", end="")

print("")

print(".byte ", end="")

for i in sintbl:
    print(f"${int(i):02x},", end="")

print("")
