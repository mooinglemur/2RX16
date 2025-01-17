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
    (0, 4, 6, 2, 0), # front
    (5, 1, 3, 7, 0), # back
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

vertical_offset = -0.2

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

def min_y_coordinate(shape):
    return min(y for _, y in shape.exterior.coords)


def calculate_texture_increments(vertices):
    if len(vertices) < 3:
        raise ValueError("At least three vertices are required.")

    # Calculate the vectors between adjacent vertices
    vector_h1 = vertices[1] - vertices[0]
    vector_h2 = vertices[2] - vertices[3]

    vector_v1 = vertices[3] - vertices[0]
    vector_v2 = vertices[2] - vertices[1]

    # Get the average of each vector in light of the face skew
    vector_h = (vector_h1 + vector_h2) / 2
    vector_v = (vector_v1 + vector_v2) / 2

    vector_h_len = math.sqrt(vector_h[0]**2 + vector_h[1]**2)
    vector_v_len = math.sqrt(vector_v[0]**2 + vector_v[1]**2)

    vector_h_ratio = scale*2/vector_h_len
    vector_v_ratio = scale*2/vector_v_len

    scale_ratio_h = 46/scale
    scale_ratio_v = 24/scale

    # normalize the two vectors
    normal_h = (vector_h[0] / vector_h_len, vector_h[1] / vector_h_len)
    normal_v = (vector_v[0] / vector_v_len, vector_v[1] / vector_v_len)

    # turn the vectors into angles
    angle_h = math.atan2(normal_h[1], normal_h[0])
    angle_v = math.atan2(normal_v[1], normal_v[0])

    # How much does the V vector deviate from 90°?
    skew_angle = angle_v - (math.pi/2) - angle_h

    print(f"skew {skew_angle} angle {angle_h} sin {math.sin(angle_h)} cos {math.cos(angle_h)}")

    global_x_inc = scale_ratio_h*vector_h_ratio*math.cos(angle_h + skew_angle)
    global_y_inc = scale_ratio_v*vector_v_ratio*-math.sin(angle_h)

    linewise_x_inc = scale_ratio_h*vector_h_ratio*math.sin(angle_h + skew_angle)
    linewise_y_inc = scale_ratio_v*vector_v_ratio*math.cos(angle_h)

    return [global_x_inc, global_y_inc, linewise_x_inc, linewise_y_inc]

def rotate_cube(step):
    global scale
    # WARNING: changing these values could lead to the choreo exceeding the max of 256K!

    sx = math.sin(step/280)*259
    sy = math.sin(step/360)*330

    angle_x = sx*2*math.pi/360
#    angle_x = 0
    angle_y = sy*2*math.pi/360
#    angle_y = 0
#    angle_x = angle_y
    if step > 64:
        angle_z = (step-64)*2*math.pi/360/21
    else:
        angle_z = 0
#    angle_z = 0


    scale = 23+4*math.sin(step/128)

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

        # Rotate around the z-axis
        tmp_x = new_x * math.cos(angle_z) - new_y * math.sin(angle_z)
        new_y = new_x * math.sin(angle_z) + new_y * math.cos(angle_z)
        new_x = tmp_x

        z_ratio = (camera[2]) / (new_z + camera[2]) # camera position

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

    pfaces = []
    pcolors = []
    increments = []

    for face in sorted_visible_faces:
        pfaces.append([rotated_2d_vertices[i] for i in face[0:4]])
        pcolors.append(face[4])
        incr = calculate_texture_increments([rotated_3d_vertices[i] for i in face[0:4]])
        increments.append(incr)

    return pfaces, pcolors, increments


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
        pfaces, pcolors, increments = rotate_cube(step)

        # set to extremes
        top_y = 100
        bottom_y = 0

        print(f"step {step} {step:04x}: {file.tell():08x}")

        for p in range(len(pfaces)):
            poly = Polygon(pfaces[p])
            # sorted vertically
            sorted_vertices = sorted(poly.exterior.coords[:-1], key=lambda x: [x[1], x[0]], reverse=False)

            sections = []

            x1, y1 = sorted_vertices[0]
            x2, y2 = sorted_vertices[1]
            x3, y3 = sorted_vertices[2]
            x4, y4 = sorted_vertices[3]

            y_coords = sorted([y for y in set(p[1] for p in sorted_vertices) if y != y1 and y != y4])
            horizontal_lines = [LineString([(min(p[0] for p in sorted_vertices) - 1, y), (max(p[0] for p in sorted_vertices) + 1, y)]) for y in y_coords]

            split_shapes = [poly]
            for line in horizontal_lines:
                new_split_shapes = []
                for shape in split_shapes:
                    result = split(shape, line)
                    new_split_shapes.extend(result.geoms)
                split_shapes = new_split_shapes

            # Sort the split shapes by their top y-coordinate
            sorted_shapes = sorted(split_shapes, key=min_y_coordinate, reverse=False)

            print(f"{p} {pcolors[p]} {sorted_vertices} {pfaces[p]}")
            print(f"{split_shapes} {y_coords} {horizontal_lines}")

            for shape in sorted_shapes:
                section_vertices = sorted(shape.exterior.coords[:-1], key=lambda x: [x[1], x[0]], reverse=False)
                sx1 = section_vertices[0][0]
                sy1 = section_vertices[0][1]
                sx2 = section_vertices[1][0]
                sy2 = section_vertices[1][1]
                sx3 = section_vertices[2][0]
                sy3 = section_vertices[2][1]

                print(f"sv: {section_vertices}")

                if len(section_vertices) == 3: # triangle
                    if sy1 == sy2: # flat top
                        lines = sy3 - sy1
                        left_slope = (sx3 - sx1) / (sy3 - sy1)
                        right_slope = (sx3 - sx2) / (sy3 - sy2)
                        length_incr = right_slope - left_slope
                        starting_len = (sx2 - sx1) + (length_incr / 2)
                        start_x = sx1 + (left_slope / 2)
                        if lines > 0:
                            sections.append({"start_x": start_x, "left_slope": left_slope, "length_incr": length_incr, "lines": lines, "starting_len": starting_len, "type": "flat top triangle"})
                    elif sy2 == sy3: # flat bottom
                        lines = sy2 - sy1
                        left_slope = (sx2 - sx1) / (sy2 - sy1)
                        right_slope = (sx3 - sx1) / (sy3 - sy1)
                        length_incr = right_slope - left_slope
                        starting_len = length_incr / 2
                        start_x = sx1 + (left_slope / 2)
                        if lines > 0:
                            sections.append({"start_x": start_x, "left_slope": left_slope, "length_incr": length_incr, "lines": lines, "starting_len": starting_len, "type": "flat bottom triangle"})
                    else:
                        raise RuntimeError("unknown triangle type")
                elif len(section_vertices) == 4: # quad
                    sx4 = section_vertices[3][0]
                    sy4 = section_vertices[3][1]
                    if sy1 == sy2 and sy3 == sy4: # flat top and bottom
                        lines = sy3 - sy1
                        left_slope = (sx3 - sx1) / (sy3 - sy1)
                        right_slope = (sx4 - sx2) / (sy4 - sy2)
                        length_incr = right_slope - left_slope
                        starting_len = (sx2 - sx1) + (length_incr / 2)
                        start_x = sx1 + (left_slope / 2)
                        if lines > 0:
                            sections.append({"start_x": start_x, "left_slope": left_slope, "length_incr": length_incr, "lines": lines, "starting_len": starting_len, "type": "quad"})
                    else:
                        raise RuntimeError("unknown quad type")
                else:
                    raise RuntimeError("unknown shape")

            if y1 < top_y:
                top_y = y1
            if y4 > bottom_y:
                bottom_y = y4

            pygame.draw.polygon(screen, colors[pcolors[p]], poly.exterior.coords, 0)

            # write out face-wise parameters
            face_type = pcolors[p] # 0-2
            raster_y = y1
            raster_x = x1

            # preshifted for VERA FX's registers
            global_affine_y_incr_frac = int((65536 + increments[p][1]) * 512) & 0xff
            global_affine_y_incr = int((65536 + increments[p][1]) * 2) & 0x7f
            global_affine_x_incr_frac = int((65536 + increments[p][0]) * 512) & 0xff
            global_affine_x_incr = int((65536 + increments[p][0]) * 2) & 0x7f

            #affine_y_start = (increments[p][1] * step)
            #affine_x_start = (increments[p][0] * step)

            xdiff = pfaces[p][0][0] - sorted_vertices[0][0]
            ydiff = pfaces[p][0][1] - sorted_vertices[0][1]

            affine_y_start = 8 - (xdiff * increments[p][1]) - (ydiff * increments[p][3]) #+ (increments[p][1] * step)
            affine_x_start = - (xdiff * increments[p][0]) - (ydiff * increments[p][2]) + (step*1.5)

            file.write(bytes([face_type, int(raster_y)]))
            file.write(bytes([global_affine_y_incr_frac, global_affine_y_incr, global_affine_x_incr_frac, global_affine_x_incr]))

            print(f"x: {raster_x} y: {raster_y} affine_x_start: {affine_x_start} affine_y_start: {affine_y_start} aff_x: {increments[p][0]} aff_y: {increments[p][1]} base_lw_x: {increments[p][2]} base_lw_y: {increments[p][3]}")

            for s in sections:
                linewise_affine_y = increments[p][3]
                linewise_affine_x = increments[p][2]
                global_affine_y = increments[p][1]
                global_affine_x = increments[p][0]

                linewise_affine_y += s['left_slope'] * global_affine_y
                linewise_affine_x += s['left_slope'] * global_affine_x

                s['linewise_affine_y'] = linewise_affine_y
                s['linewise_affine_x'] = linewise_affine_x

                prev_affine_y_start = affine_y_start
                prev_affine_x_start = affine_x_start

                affine_y_start += linewise_affine_y / 2
                affine_x_start += linewise_affine_x / 2

                affine_y_start_frac = int(affine_y_start * 256) & 0xff
                affine_y_start_int = int(affine_y_start) & 0xff
                affine_x_start_frac = int(affine_x_start * 256) & 0xff
                affine_x_start_int = int(affine_x_start) & 0xff

                print(s)

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
                file.write(bytes([int((256 + s['start_x']) * 256) & 0xff]))
                file.write(bytes([int(256 + s['start_x']) & 0xff]))
                file.write(bytes([affine_y_start_frac, affine_x_start_frac, affine_y_start_int, affine_x_start_int]))

                affine_y_start = prev_affine_y_start + (linewise_affine_y * s['lines'])
                affine_x_start = prev_affine_x_start + (linewise_affine_x * s['lines'])

            file.write(bytes([0xfe])) # end poly

        file.write(bytes([0xfd])) # end frame
        file.write(bytes([int(top_y)]))
        file.write(bytes([int(bottom_y)]))

        print("")
        pygame.display.flip()
        #clock.tick(30)

        step += 1

        if step > 1750:
            running = False

    file.write(bytes([0x69])) # end series



