#!/usr/bin/env python3

import pygame
from pygame.locals import *
from shapely.geometry import Polygon, MultiPolygon
from shapely.ops import unary_union
from shapely.validation import make_valid
from shapely import equals
import math

BLACK = (0, 0, 0)
BLUE  = (64, 64, 255)
RED  = (255, 64, 64)
GREEN = (64, 255, 64)

colors = [BLUE, GREEN, RED]

# Cube!
vertices = [
    (-1, -1, -1), #0
    (-1, -1,  1), #1
    (-1,  1, -1), #2
    (-1,  1,  1), #3
    ( 1, -1, -1), #4
    ( 1, -1,  1), #5
    ( 1,  1, -1), #6
    ( 1,  1,  1), #7
]

# Cube faces!
# index 4 of each one is the color index of the face
faces = [
    (2, 0, 4, 6, 0), # front
    (7, 5, 1, 3, 0), # back
    (0, 1, 5, 4, 1), # top
    (6, 7, 3, 2, 1), # bottom
    (3, 1, 0, 2, 2), # left
    (6, 4, 5, 7, 2), # right
]

clock=pygame.time.Clock()

# Set up the display
width, height = 160, 120
screen = pygame.display.set_mode((width, height))
pygame.display.set_caption("2R Cube")

# Define the size and position of the polyhedron
scale = 22
center_offset = (width // 2, height // 2)

vertical_offset = 0

camera = (0, 0, 6)

# Face output
# - Type or frame terminator (which affine color map?)
# - Y
# - X
# - Global Affine Y Increment Fractional
# - Global Affine Y Increment Integer
# - Global Affine X Increment Fractional
# - Global Affine X Increment Integer
# - Affine Y start
# - Affine X start

# - Section marker
# - Linewise Affine Y Increment Fractional
# - Linewise Affine Y Increment Integer
# - Linewise Affine X Increment Fractional
# - Linewise Affine X Increment Integer
# - Left slope fractional
# - Left slope integer
# - Length Increment Fractional
# - Length Increment Integer
# - Line count

# - Section marker or terminator

def big_enough(polygon, tolerance=4):
    return polygon.area >= tolerance

def rotate_cube(step):
    angle_x = step*2*math.pi/360/7
    angle_y = step*2*math.pi/360

    rotated_vertices = []
    zees = []
    for vertex in vertices:
        x, y, z = vertex

        # Rotate around the x-axis
        new_y = y * math.cos(angle_x) - z * math.sin(angle_x)
        new_z = y * math.sin(angle_x) + z * math.cos(angle_x)

        # Rotate around the y-axis
        new_x = x * math.cos(angle_y) - new_z * math.sin(angle_y)
        new_z = x * math.sin(angle_y) + new_z * math.cos(angle_y)

        z_ratio = (1-camera[2]) / (new_z + camera[2]) # camera position

        new_x *= z_ratio
        new_y *= z_ratio

        new_y += vertical_offset


        x_proj = new_x * scale + center_offset[0]
        y_proj = new_y * scale + center_offset[1]
        z_proj = new_z * scale

        rotated_vertices.append((round(x_proj), round(y_proj)))
        zees.append(z_proj)

    sorted_faces = sorted(faces, key=lambda x: zees[x[0]]+zees[x[1]]+zees[x[2]]+zees[x[3]], reverse=False)

    visible_faces = []
    visible_polys = []

    for face in sorted_faces:
        fc = Polygon([rotated_vertices[i] for i in face[0:4]])
        if not fc.is_valid:
            continue
        covers = False

        if len(visible_faces) > 0:
            u = visible_polys[0]
            if not u.is_valid:
                continue
            for p in visible_polys[1:]:
                if not p.is_valid:
                    continue
                u = u.union(p)
            if u.contains(fc):
                covers = True

        if not covers:
            visible_faces.append(face)
            visible_polys.append(fc)

    sorted_visible_faces = sorted(visible_faces, key=lambda x: zees[x[0]]+zees[x[1]]+zees[x[2]]+zees[x[3]], reverse=True)

    polys = []
    pcolors = []

    for face in sorted_visible_faces:
        polys.append(Polygon([rotated_vertices[i] for i in face[0:4]]))
        pcolors.append(face[4])

    return polys, pcolors


running = True
step = 0

while running:
    for event in pygame.event.get():
        if event.type == QUIT:
            running = False

    screen.fill(BLACK)
    polys, pcolors = rotate_cube(step)

    for p in range(len(polys)):
        pygame.draw.polygon(screen, colors[pcolors[p]], polys[p].exterior.coords, 0)

    pygame.display.flip()
    clock.tick(60)

    step += 1

