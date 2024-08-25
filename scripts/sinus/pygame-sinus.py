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
import pprint

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def list_to_dotbyte_strings(lst):
    result = []
    for chunk in chunks(lst, 16):
        result.append("\t.byte " + ','.join(['${:02x}'.format(int(x)) for x in chunk]) + "\n")
    return result

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

lowy = 400
highy = 0

tiles = []


while running:
    for event in pygame.event.get():
        if event.type == QUIT:
            running = False

    # Define wave parameters
    amplitude = 25      # Wave height
    frequency = 2*math.pi/640    # Wave frequency
    phase_shift = 0     # Wave phase shift
    base_height = height // 2  # Base height of the wave
    wave_speed = 0.20

    for p in range(16):
        screen.fill(BLACK)

        ps = math.sin(1+(p*math.pi*2/16))
        amp = amplitude*ps

        # Draw the wave
        points = []
        for x in range(width):
            ms = (math.sin(frequency * x + phase_shift * math.pi*2) + 0.1) ** 2 / 4
            if ms < 0:
                ms /= 2
            y = round(base_height + amp * ms + 0.2)
            if y < lowy:
                lowy = y
            if y > highy:
                highy = y
            points.append((x, y))

        # Add points for filling the area below the wave
        points.append((width, height))  # Bottom-right corner
        points.append((0, height))      # Bottom-left corner

        # Draw filled wave
        pygame.draw.polygon(screen, BLUE, points)

        # Update the display
        pygame.display.flip()

        # Update the wave's phase shift to animate
        #phase_shift += wave_speed

        for trow in range(3):
            for tcol in range(16):
                tile = []
                for crow in range(8):
                    for ccol in range(8):
                        xx = round(((tcol * 8) + ccol) * (width/128))
                        yy = round((height//2)-8) + (trow * 8) + crow
                        color = screen.get_at([xx, yy])
                        if color == BLACK:
                            p = 0
                        else:
                            dist_from_black = 1
                            while True:
                                color = screen.get_at([xx, yy-dist_from_black])
                                if color == BLACK:
                                    break
                                else:
                                    dist_from_black += 1
                            p = dist_from_black
                            if p > 5:
                                p = 5
                        tile.append(p)
                tiles.append(tile)

        clock.tick(6)
    running = False

utiles = [[0] * 64] # empty tile
utiles.append([5] * 64) # ocean tile

maps = []

for a in range(16):
    for rpt in range(2):
        for t in range(a*48,a*48+16):
            try:
                i = utiles.index(tiles[t])
            except ValueError:
                i = len(utiles)
                utiles.append(tiles[t])
            maps.append(i)
    for rpt in range(2):
        for t in range(a*48+16,a*48+32):
            try:
                i = utiles.index(tiles[t])
            except ValueError:
                i = len(utiles)
                utiles.append(tiles[t])
            maps.append(i)
    for rpt in range(2):
        for t in range(a*48+32,a*48+48):
            try:
                i = utiles.index(tiles[t])
            except ValueError:
                i = len(utiles)
                utiles.append(tiles[t])
            maps.append(i)
    for rpt in range(29*32 + 32*32):
        maps.append(1)


with open("SINUSTILES.DAT", mode="wb") as file:
    for t in utiles:
        for c in range(0,len(t),2):
            b = (t[c] << 4) | t[c+1]
            file.write(bytes([b]))

with open("SINUSMAP.DAT", mode="wb") as file:
    for b in maps:
        file.write(bytes([b]))


#pprint.pprint(tiles, width=26, compact=True)
unique_lists = set(tuple(lst) for lst in tiles)

# Count of unique lists
unique_count = len(unique_lists)

print(lowy)
print(highy)
print(f"Unique count: {unique_count} out of {len(tiles)}")




print("sintbls:")
for section in range(6):
    sintbl = []

    for i in range(256):
        s = 1+math.cos((i*math.pi/256)+math.pi)
        s /= 2
        s *= (256 * ((section+1)/6))
        sintbl.append(s)

    print("".join(list_to_dotbyte_strings([int(i * 2048) & 0xff for i in sintbl])))

    print("".join(list_to_dotbyte_strings([int(i * 8) & 0xff for i in sintbl])))


print("addr_l_start:")

for section in range(6):
    tbl = []
    for i in range(16):
        s = math.sin(i*math.pi*2/16 + math.pi)
        if section < 4:
            s *= (section/3+1)
        else:
            s = 13
        y = 50+(section * 6)+s+(4-section * 4)
        tbl.append(round(y))

    print("".join(list_to_dotbyte_strings([int(i * 160) & 0xff for i in tbl])))


print("addr_m_start:")

for section in range(6):
    tbl = []
    for i in range(16):
        s = math.sin(i*math.pi*2/16 + math.pi)
        if section < 4:
            s *= (section/3+1)
        else:
            s = 13
        y = 50+(section * 6)+s+(4-section * 4)
        tbl.append(round(y))

    print("".join(list_to_dotbyte_strings([int((i * 160) >> 8) & 0xff for i in tbl])))

