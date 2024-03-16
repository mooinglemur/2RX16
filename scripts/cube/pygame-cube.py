#!/usr/bin/env python3

import pygame
from pygame.locals import *
from shapely.geometry import Polygon, MultiPolygon
from shapely.ops import unary_union
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
# - Starting Length
# - Line count

# - Section marker or terminator

def calculate_texture_increments(vertices):
    if len(vertices) < 3:
        raise ValueError("At least three vertices are required.")

    # Calculate the vectors between adjacent vertices
    vector_y = vertices[1] - vertices[0]
    vector_x = vertices[2] - vertices[1]

    global_x_inc = (scale*2)/vector_x[0]
    global_y_inc = vector_x[1]/(scale*2)
    linewise_x_inc = vector_y[0]/(scale*2)
    linewise_y_inc = (scale*2)/vector_y[1]

    return [global_x_inc, global_y_inc, linewise_x_inc, linewise_y_inc]

def rotate_cube(step):
    # Temporary rotation choreography
    # This will eventually determine the entire sequence
    # based on the step (frame) number
    angle_x = step*2*math.pi/360/7
    angle_y = step*2*math.pi/360

    rotated_2d_vertices = []
    rotated_3d_vertices = []
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

        rotated_2d_vertices.append((round(x_proj), round(y_proj)))
        rotated_3d_vertices.append(np.array([x_proj, y_proj, z_proj]))
        zees.append(z_proj)

    sorted_faces = sorted(faces, key=lambda x: zees[x[0]]+zees[x[1]]+zees[x[2]]+zees[x[3]], reverse=False)

    visible_faces = []
    visible_polys = []

    for face in sorted_faces:
        fc = Polygon([rotated_2d_vertices[i] for i in face[0:4]])
        if not fc.is_valid:
            continue
        covers = False

        if len(visible_faces) > 0:
            u = visible_polys[0]
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
    increments = []

    for face in sorted_visible_faces:
        polys.append(Polygon([rotated_2d_vertices[i] for i in face[0:4]]))
        pcolors.append(face[4])
        incr = calculate_texture_increments([rotated_3d_vertices[i] for i in face[0:3]])

        increments.append(incr)

    return polys, pcolors, increments



running = True
step = 0

texture_filename = "cube-texture.png"
with Image.open(texture_filename) as img:
    texture = img.load()

while running:
    for event in pygame.event.get():
        if event.type == QUIT:
            running = False

    screen.fill(BLACK)
    polys, pcolors, increments = rotate_cube(step)

    for p in range(len(polys)):
        poly = polys[p]
        # sorted vertically
        sorted_vertices = sorted(poly.exterior.coords[:-1], key=lambda x: [x[1], x[0]], reverse=False)
        print(sorted_vertices)
        top_y = sorted_vertices[0][1]
        top_x = sorted_vertices[0][0]
        #global_affine_y_incr_frac = int(increments[1] * 256) & 0xff
        #global_affine_y_incr = int(increments[1]) & 0xff
        #global_affine_x_incr_frac = int(increments[0] * 256) & 0xff
        #global_affine_x_incr = int(increments[0]) & 0xff
        affine_y_start = 0
        affine_x_start = 0

        sections = []

        x1, y1 = sorted_vertices[0]
        x2, y2 = sorted_vertices[1]
        x3, y3 = sorted_vertices[2]
        x4, y4 = sorted_vertices[3]

        if y1 == y2: # Flat top (x2 > x1)
            if (x1 > x2):
                raise RuntimeError("x1 was not expected to be > x2")
            starting_len = x2 - x1
            if x3 > x4: # Right side changes first
                right_slope = (x3 - x2) / (y3 - y2)
                left_slope = (x4 - x1) / (y4 - y1)
                lines = y3 - y2 # lines to follow
                left_at_x3 = x1 + (left_slope * lines)
                length_incr = ((x3 - left_at_x3) - starting_len) / lines
                sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines})
                if y3 == y4: # Flat bottom
                    pass
                else: # Triangular section
                    right_slope = (x4 - x3) / (y4 - y3)
                    lines = y4 - y3
                    # should this be 0 or 1?
                    length_incr = (0 - (x3 - left_at_x3)) / lines
                    sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines})
            elif x4 > x3: # Left side changes first
                left_slope = (x3 - x1) / (y3 - y1)
                right_slope = (x4 - x2) / (y4 - y2)
                lines = y3 - y1 # lines to follow
                right_at_x3 = x2 + (right_slope * lines)
                length_incr = ((right_at_x3 - x3) - starting_len) / lines
                sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines})
                if y3 == y4: # Flat bottom
                    pass
                else: # Triangular section
                    left_slope = (x4 - x3) / (y4 - y3)
                    lines = y4 - y3
                    # should this be 0 or 1?
                    length_incr = (0 - (right_at_x3 - x3)) / lines
                    sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines})
            else: # Weird vertical arrangement
                raise RuntimeError("Add code for stacked vertices 3 and 4")
        elif x1 < x2:
            
                




        pygame.draw.polygon(screen, colors[pcolors[p]], poly.exterior.coords, 0)

    pygame.display.flip()
    clock.tick(1)

    step += 1

