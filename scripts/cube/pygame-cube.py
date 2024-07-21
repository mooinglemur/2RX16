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
# - Type (which affine color map?, high bit clear)
# - Raster Y start
# - Raster X start
# - Global Affine Y Increment Fractional
# - Global Affine Y Increment Integer
# - Global Affine X Increment Fractional
# - Global Affine X Increment Integer
# - Affine Y start Fractional
# - Affine X start Fractional
# - Affine Y start Integer
# - Affine X start Integer

# - Frame terminator (high bit set)
# - top_y
# - bottom_y

# Section
# - Section marker (high bit clear)
# - Linewise Affine Y Increment Fractional
# - Linewise Affine Y Increment Integer
# - Linewise Affine X Increment Fractional
# - Linewise Affine X Increment Integer
# - Left slope fractional
# - Left slope integer
# - Length Increment Fractional
# - Length Increment Integer
# - Line count
# - Starting Length Fractional
# - Starting Length Integer

# - Section terminator (high bit set)

def calculate_texture_increments(vertices):
    if len(vertices) < 3:
        raise ValueError("At least three vertices are required.")

    # Calculate the vectors between adjacent vertices
    vector_y = vertices[1] - vertices[0]
    vector_x = vertices[2] - vertices[1]

    global_x_inc   = -1 * vector_x[0]/(scale)
    global_y_inc   = -1 * vector_x[1]/(scale)
    linewise_x_inc =      vector_y[0]/(scale)
    linewise_y_inc =      vector_y[1]/(scale)

    # XXX
    global_x_inc = 1
    global_y_inc = 0
    linewise_x_inc = 0
    linewise_y_inc = 1

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
    vertex0 = []

    for face in sorted_visible_faces:
        polys.append(Polygon([rotated_2d_vertices[i] for i in face[0:4]]))
        pcolors.append(face[4])
        incr = calculate_texture_increments([rotated_3d_vertices[i] for i in face[0:3]])
        vertex0.append(rotated_2d_vertices[face[0]])

        increments.append(incr)

    return polys, pcolors, increments, vertex0



running = True
step = 0

texture_filename = "cube-texture.png"
with Image.open(texture_filename) as img:

    with open("CUBETILES.DAT", mode="wb") as file:
        for trow in range(24):
            for tcol in range(16):
                for crow in range(8):
                    for ccol in range(8):
                        yy = (trow*8)+crow
                        xx = (tcol*8)+ccol
                        px = img.getpixel([xx,yy])
                        file.write(bytes([px]))

    with open("CUBETILES.PAL", mode="wb") as file:
        pal = img.getpalette('RGB')

        for idx in range(0, len(pal), 3):
            r = (pal[idx] * 15 + 135) >> 8
            g = (pal[idx+1] * 15 + 135) >> 8
            b = (pal[idx+2] * 15 + 135) >> 8

            gb = g << 4 | b
            file.write(bytes([gb, r]))

with open("CUBECHOREO.DAT", mode="wb") as file:
    file.write(bytes([0x69])) # padding by one byte
    while running:
        for event in pygame.event.get():
            if event.type == QUIT:
                running = False

        screen.fill(BLACK)
        polys, pcolors, increments, vertex0 = rotate_cube(step)

        # set to extremes
        top_y = 100
        bottom_y = 0

        print(f"step {step} {step:04x}")

        for p in range(len(polys)):
            poly = polys[p]
            # sorted vertically
            sorted_vertices = sorted(poly.exterior.coords[:-1], key=lambda x: [x[1], x[0]], reverse=False)

            print(f"{p} {sorted_vertices}")

            sections = []

            x1, y1 = sorted_vertices[0]
            x2, y2 = sorted_vertices[1]
            x3, y3 = sorted_vertices[2]
            x4, y4 = sorted_vertices[3]

            if x3 < x4:
                xbl = x3
                ybl = y3
                xbr = x4
                ybr = y4
            else:
                xbl = x4
                ybl = y4
                xbr = x3
                ybr = y3

            if x1 < x2:
                xtl = x1
                ytl = y1
                xtr = x2
                ytr = y2
            else:
                xtl = x2
                ytl = y2
                xtr = x1
                ytr = y1

            left_at_x2 = x2
            right_at_x2 = x2
            left_at_x3 = x3
            right_at_x3 = x3

            # section above y2, if any

            if y1 == y2: # Flat top (x2 > x1)
                if (x1 > x2):
                    raise RuntimeError("x1 was not expected to be > x2")
                starting_len = (x2 - x1) + 1

            elif x1 < x2: # Top slants like "backslash"
                starting_len = 1
                right_slope = (x2 - x1) / (y2 - y1)
                left_slope = (xbl - x1) / (ybl - y1)
                lines = y2 - y1 # lines to follow
                left_at_x2 = x1 + (left_slope * lines)
                length_incr = ((x2 - left_at_x2) - starting_len) / lines
                sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines, "starting_len": starting_len})
                starting_len += length_incr * lines

            elif x1 > x2: # Top slants like "forward slash"
                starting_len = 1
                right_slope = (xbr - x1) / (ybr - y1)
                left_slope = (x2 - x1) / (y2 - y1)
                lines = y2 - y1 # lines to follow
                right_at_x2 = x1 + (right_slope * lines)
                length_incr = ((right_at_x2 - x2) - starting_len) / lines
                sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines, "starting_len": starting_len})
                starting_len += length_incr * lines

            else: # Top section is a point
                starting_len = 1

            # middle section

            if x3 > x4 or (x3 == x4 and x2 < x3) or (x3 == x4 and x1 < x3): # Right side changes first
                right_slope = (x3 - xtr) / (y3 - ytr)
                left_slope = (x4 - xtl) / (y4 - ytl)
                lines = y3 - y2 # lines to follow
                left_at_x3 = xtl + (left_slope * lines)
                if lines > 0:
                    length_incr = ((x3 - left_at_x3) - starting_len) / lines
                    sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines, "starting_len": starting_len})
                    starting_len += length_incr * lines
                else:
                    pass # no middle section

                if y3 == y4: # Flat bottom
                    pass
                else: # Triangular section
                    right_slope = (x4 - x3) / (y4 - y3)
                    lines = y4 - y3
                    # should this be 0 or 1?
                    length_incr = (0 - (x3 - left_at_x3)) / lines
                    sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines, "starting_len": starting_len})
                    starting_len += length_incr * lines

            elif x3 < x4 or (x3 == x4 and x2 > x3) or (x3 == x4 and x1 > x3): # Left side changes first
                left_slope = (x3 - xtl) / (y3 - ytl)
                right_slope = (x4 - xtr) / (y4 - ytr)
                lines = y3 - y2 # lines to follow
                right_at_x3 = xtr + (right_slope * lines)
                if lines > 0:
                    length_incr = ((right_at_x3 - x3) - starting_len) / lines
                    sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines, "starting_len": starting_len})
                    starting_len += length_incr * lines
                else:
                    pass # no middle section

                if y3 == y4: # Flat bottom
                    pass
                else: # Triangular section
                    left_slope = (x4 - x3) / (y4 - y3)
                    lines = y4 - y3
                    # should this be 0 or 1?
                    length_incr = (0 - (right_at_x3 - x3)) / lines
                    sections.append({"left_slope": left_slope, "length_incr": length_incr, "lines": lines, "starting_len": starting_len})
                    starting_len += length_incr * lines

            else: # Vertical arrangement of bottom points
                raise RuntimeError("Add code for stacked vertices 3 and 4")

            if y1 < top_y:
                top_y = y1
            if y4 > bottom_y:
                bottom_y = y4

            pygame.draw.polygon(screen, colors[pcolors[p]], poly.exterior.coords, 0)

            for s in sections:
                linewise_affine_y = increments[p][3]
                linewise_affine_x = increments[p][2]
                global_affine_y = increments[p][1]
                global_affine_x = increments[p][0]

                linewise_affine_y += s['left_slope'] * global_affine_y
                linewise_affine_x += s['left_slope'] * global_affine_x

                s['linewise_affine_y'] = linewise_affine_y
                s['linewise_affine_x'] = linewise_affine_x

                print(s)

            # write out face-wise parameters
            face_type = pcolors[p] # 0-2
            raster_y = y1
            raster_x = x1

            # preshifted for VERA FX's registers
            global_affine_y_incr_frac = int(increments[p][1] * 512) & 0xff
            global_affine_y_incr = int(increments[p][1] * 2) & 0x7f
            global_affine_x_incr_frac = int(increments[p][0] * 512) & 0xff
            global_affine_x_incr = int(increments[p][0] * 2) & 0x7f

            #affine_y_start = (increments[p][1] * step)
            #affine_x_start = (increments[p][0] * step)

            affine_y_start = (y1 - vertex0[p][1]) * (increments[p][3] + increments[p][1]) # + (increments[p][1] * step)
            affine_x_start = (x1 - vertex0[p][0]) * (increments[p][0] + increments[p][2]) # + (increments[p][0] * step)

            while affine_y_start < 0:
                affine_y_start += 256
            while affine_x_start < 0:
                affine_x_start += 256

            affine_y_start_frac = int(affine_y_start * 256) & 0xff
            affine_y_start_int = int(affine_y_start) & 0xff
            affine_x_start_frac = int(affine_x_start * 256) & 0xff
            affine_x_start_int = int(affine_x_start) & 0xff


            file.write(bytes([face_type, int(raster_y), int(raster_x)]))
            file.write(bytes([global_affine_y_incr_frac, global_affine_y_incr, global_affine_x_incr_frac, global_affine_x_incr]))
            file.write(bytes([affine_y_start_frac, affine_x_start_frac, affine_y_start_int, affine_x_start_int]))

            print(f"x: {raster_x} y: {raster_y} aff_x: {increments[p][0]} aff_y: {increments[p][1]}")

            for s in sections:
                file.write(bytes([0x10])) # section begin
                file.write(bytes([int((256 + s['linewise_affine_y']) * 256) & 0xff]))
                file.write(bytes([int(256 + s['linewise_affine_y']) & 0xff]))
                file.write(bytes([int((256 + s['linewise_affine_x']) * 256) & 0xff]))
                file.write(bytes([int(256 + s['linewise_affine_x']) & 0xff]))
                file.write(bytes([int((256 + s['left_slope']) * 256) & 0xff]))
                file.write(bytes([int(256 + s['left_slope']) & 0xff]))
                file.write(bytes([int((256 + s['length_incr']) * 256) & 0xff]))
                file.write(bytes([int(256 + s['length_incr']) & 0xff]))
                file.write(bytes([int(s['lines'])]))
                file.write(bytes([int((256 + s['starting_len']) * 256) & 0xff]))
                file.write(bytes([int(256 + s['starting_len']) & 0xff]))

            file.write(bytes([0xfe])) # end poly

        file.write(bytes([0xfd])) # end frame
        file.write(bytes([int(top_y)]))
        file.write(bytes([int(bottom_y)]))

        print("")
        pygame.display.flip()
#        clock.tick(10)

        step += 1

        if step > 1660:
            running = False



