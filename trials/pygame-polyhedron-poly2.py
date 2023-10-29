#/usr/bin/env python3

import pygame
from pygame.locals import *
import math
from enum import Enum
import copy
import time
from shapely.geometry import Polygon, GeometryCollection, LineString, MultiLineString, JOIN_STYLE
from shapely.validation import make_valid
import numpy as np
from scipy.spatial import Delaunay
from shapely.ops import split

# Initialize Pygame
pygame.init()

# Define colors
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
BLUE  = (64, 64, 255)
RED  = (255, 64, 64)
GREEN = (64, 255, 64)
CYAN = (64, 255, 255)
MAGENTA = (255, 64, 255)
YELLOW = (255, 255, 64)
PINK = (255, 224, 224)
LIME = (224, 255, 224)
LAVENDER = (255, 224, 255)
ORANGE = (255, 224, 0)
SKYBLUE = (224, 224, 255)
GRAY = (128, 128, 128)

IDX0 = (0, 0, 0)
IDX1 = (255, 128, 128)
IDX2 = (255, 0, 0)
IDX3 = (224, 96, 96)
IDX4 = (128, 64, 64)
IDX5 = (128, 0, 0)
IDX6 = (187, 187, 187)
IDX7 = (0, 0, 153)
IDX8 = (153, 153, 153)
IDX9 = (0, 0, 119)
IDXA = (119, 119, 119)
IDXB = (0, 0, 85)
IDXC = (85, 85, 85)
IDXD = (0, 0, 51)
IDXE = (51, 51, 51)
IDXF = (0, 0, 0)

colors = [
    IDX1,
    IDX2,
    IDX3,
    IDX4,
    IDX5,
    IDX6,
    IDX7,
    IDX8,
    IDX9,
    IDXA,
    IDXB,
    IDXC,
    IDXD,
    IDXE,
    IDXF
]

WORKSPLIT1 = 10
WORKSPLIT2 = 42

clock=pygame.time.Clock()

# Set up the display
width, height = 320, 200
screen = pygame.display.set_mode((width, height))
pygame.display.set_caption("Tetrakis Hexahedron")

# Define the vertices of the Tetrakis hexahedron
vertices = [
    (   0,    0, -3/2), #0
    (   0,    0,  3/2), #1
    (   0, -3/2,    0), #2
    (   0,  3/2,    0), #3
    (-3/2,    0,    0), #4
    ( 3/2,    0,    0), #5
    (-1, -1, -1), #6
    (-1, -1,  1), #7
    (-1,  1, -1), #8
    (-1,  1,  1), #9
    ( 1, -1, -1), #10
    ( 1, -1,  1), #11
    ( 1,  1, -1), #12
    ( 1,  1,  1), #13
]

# Define the faces by specifying the vertex indices
faces = [
    ( 0, 10,  6, 0),
    ( 1,  9, 13, 0),
    ( 0,  6,  8, 1),
    ( 1, 11, 13, 1),
    ( 0,  8, 12, 2),
    ( 1,  7, 11, 2),
    ( 0, 12, 10, 3),
    ( 1,  9,  7, 3),
    ( 2,  7,  6, 4),
    ( 3, 13, 12, 4),
    ( 2, 11,  7, 5),
    ( 3, 12,  8, 5),
    ( 2, 10, 11, 6),
    ( 3,  8,  9, 6),
    ( 2,  6, 10, 7),
    ( 3,  9, 13, 7),
    ( 5, 13, 11, 8),
    ( 4,  8,  6, 8),
    ( 5, 11, 10, 9),
    ( 4,  9,  8, 9),
    ( 5, 10, 12, 10),
    ( 4,  7,  9, 10),
    ( 5, 12, 13, 11),
    ( 4,  6,  7, 11),
]


# Define the size and position of the polyhedron
scale = 22
center_offset = (width // 2, height // 2)

# Define rotation parameters
angle_x = 1
angle_y = 2
rotation_speed_x = 2*(math.pi/180)
rotation_speed_y = 2*(math.pi/90)

maxp = 0
minp = 9999

bob_x = 0
bob_y = 0

vertical_offset = 0

camera = (0, 0, 6)

tris_seen = False

def slope2bytes(slope):
    x1 = (slope / 2)
    x32 = 0x00
    if x1 >= 32 or x1 < -32:
        x1 /= 32
        x32 = 0x80
    x1 *= 512 # move significant fractional part to whole number
    print(round(x1))
    b1 = bytearray(round(x1).to_bytes(2, 'little', signed=True))
    b1[1] &= 0x7f
    b1[1] |= x32
    return b1

def is_monotonic(polygon):
    minx, miny, maxx, maxy = polygon.bounds
    
    for y in range(int(miny), int(maxy) + 1):
        line = LineString([(minx, y), (maxx, y)])
        intersection = line.intersection(polygon)

        if isinstance(intersection, GeometryCollection):
            total_coords = sum([len(sub_geom.coords) for sub_geom in geom])
        elif isinstance(intersection, MultiLineString):
            return False       
        else:
            total_coords = len(intersection.coords)
        if total_coords > 2:
            return False
    return True


def big_enough(polygon, tolerance=4):
    return polygon.area >= tolerance

def face_sorter(item):
    return zees[item[0]]+zees[item[1]]+zees[item[2]]

def y_sorter(item):
    return rotated_vertices[item][1]

def advance_cube():
    global f
    global angle_x
    global angle_y
    global zees
    global rotated_vertices
    global tris_seen
    global sprite_mode
    global maxp
    global minp
    global bob_x
    global bob_y

    # Apply rotation
    angle_x += rotation_speed_x
    angle_y += rotation_speed_y

    rotated_vertices = []
    unscaled_rotated_vertices = []
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


        x_proj = new_x * scale + center_offset[0] + bob_x
        y_proj = new_y * scale + center_offset[1] + bob_y
        z_proj = new_z * scale

        rotated_vertices.append((round(x_proj), round(y_proj)))
        zees.append(z_proj)
        unscaled_rotated_vertices.append((new_x, new_y, new_z))

    
    sorted_faces = sorted(faces, key=face_sorter, reverse=False)

    # Turn faces into polygon objects
  
    polys = []
    pcolors = []
    found_intersection = False

    for face in sorted_faces:
        polys.append(Polygon([rotated_vertices[i] for i in face[0:3]]))
        pcolors.append(face[3] % 2)

    polys2 = []
    pcolors2 = []

    for i, poly1 in enumerate(polys):
        for j, poly2 in enumerate(polys):
            if j > i:
                if not poly1.intersects(poly2):
                    continue
                overlap = poly1.intersection(poly2).buffer(0.01, join_style=JOIN_STYLE.mitre)
                overlap = overlap.simplify(0.01, preserve_topology=True)

                if type(overlap) is not Polygon or overlap.is_empty or not big_enough(overlap) or len(set(overlap.exterior.coords)) < 3:
                    continue

                rounded_coords = [(int(round(x)), int(round(y))) for x, y in overlap.exterior.coords]
                overlap = Polygon(rounded_coords)

                polys2.append(overlap)
                pcolors2.append(pcolors[i] + pcolors[j] + 2)


    for p, poly in enumerate(polys2):
        if big_enough(poly):
            coords = np.array(list(poly.exterior.coords))
            if False and is_monotonic(poly):
                print(f"Monotonic {len(coords)-1} vertex")
                polys.append(poly)
                pcolors.append(pcolors2[p])
            else:
                print(f"Nonmonotonic {len(coords)-1} vertex")
                tri = Delaunay(coords)
                for simplex in tri.simplices:
                    triangle_coords = coords[simplex]
                    polygon = Polygon(triangle_coords)
                    polys.append(polygon)
                    pcolors.append(pcolors2[p])

#    polys = polys2
#    pcolors = pcolors2


    for p, poly in enumerate(polys):
        if p > maxp:
            maxp = p
        if p == WORKSPLIT1:
            f.write(b'\xfd') # split-work
        if p == WORKSPLIT2:
            f.write(b'\xfd') # split-work
#        if p == WORKSPLIT3:
#            f.write(b'\xfd') # split-work


        print(f"color {pcolors[p]}")
        color_idx = pcolors[p]

        pygame.draw.polygon(screen, colors[color_idx], poly.exterior.coords, 0)


        # Triangle type (bit 0 is X high bit)
        #  $00 - two part, change X1
        #  $40 - two part, change X2
        #  $80 - part 1 only
        #  $C0 - part 2 only
        #     bit 1 is X2 high bit
        #  $FF - end of triangle list for this frame
        
        # Triangle type 00
        # 
        # 01 - Y
        # 02 - X
        # 03 - X1 inc low
        # 04 - X1 inc high
        # 05 - X2 inc low
        # 06 - X2 inc high
        # 07 - color index
        # 08 - row count part 1
        # 09 - new X1 inc low
        # 0a - new X1 inc high
        # 0b - row count part 2

        # Triangle type 40
        # 
        # 01 - Y
        # 02 - X
        # 03 - X1 inc low
        # 04 - X1 inc high
        # 05 - X2 inc low
        # 06 - X2 inc high
        # 07 - color index
        # 08 - row count part 1
        # 09 - new X2 inc low
        # 0a - new X2 inc high
        # 0b - row count part 2

        # Triangle type 80
        # 
        # 01 - Y
        # 02 - X
        # 03 - X1 inc low
        # 04 - X1 inc high
        # 05 - X2 inc low
        # 06 - X2 inc high
        # 07 - color index
        # 08 - row count

        # Triangle type c0
        # 
        # 01 - Y
        # 02 - X
        # 03 - X2
        # 04 - X1 inc low
        # 05 - X1 inc high
        # 06 - X2 inc low
        # 07 - X2 inc high
        # 08 - color index
        # 09 - row count

        color_idx_out = (color_idx+1) | ((color_idx+1)*16)

        polycoords = list(set(poly.exterior.coords))
        pcl = len(polycoords)

        if pcl != 3:
            print(f"Vertex count {pcl}")
            if (pcl == 2):
                continue # don't even process this
            if (pcl == 4):
                while polycoords[3][1] < polycoords[0][1]:
                    popped = polycoords.pop()
                    polycoords.insert(0, popped)
            continue


        # find top two points of triangle
        sorted_points = sorted(polycoords, key=lambda vertex: vertex[1], reverse=False)

        v0 = list(copy.deepcopy(sorted_points[0]))
        v1 = list(copy.deepcopy(sorted_points[1]))
        v2 = list(copy.deepcopy(sorted_points[2]))

        for i in range(2):
            v0[i] = round(v0[i])
            v1[i] = round(v1[i])
            v2[i] = round(v2[i])

        if v2[1] < 0:
            print("Fully offscreen")
            continue # fully offscreen

        tris_seen = True


        if v1[1] <= 0 and v0[1] < 0:
            print(f"v0 {v0[0]} {v0[1]} v1 {v1[0]} {v1[1]}")

            dx_1 = v1[0] - v0[0]
            dy_1 = v1[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v0[0]
            dy_2 = v2[1] - v0[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            v0[0] = round(v0[0] + (slope_2 * dy_1))
            v0[1] = v1[1]

            print(f"v0 {v0[0]} {v0[1]} v1 {v1[0]} {v1[1]}")

            dx_1 = v2[0] - v0[0]
            dy_1 = v2[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v1[0]
            dy_2 = v2[1] - v1[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            d0 = 0 - v0[1]

            v0[0] = round(math.copysign(1, v0[0] - v1[0]) + v0[0] + (slope_1 * d0))
            v1[0] = round(math.copysign(1, v1[0] - v0[0]) + v1[0] + (slope_2 * d0))

            v0[1] = 0
            v1[1] = 0

            print(f"v0 {v0[0]} {v0[1]} v1 {v1[0]} {v1[1]}")
            print(f"v2 {v2[0]} {v2[1]}")
            #time.sleep(2)

        if v2[1] == v1[1] and v1[1] == v0[1]:
            print(f"v0 {v0[0]} {v0[1]} v1 {v1[0]} {v1[1]}")
            print(f"v2 {v2[0]} {v2[1]}")
            #time.sleep(10)
            continue


        if (v0[1] == v1[1]): # Part 2 only
            print("Part 2 only")
            dx_1 = v2[0] - v0[0]
            dy_1 = v2[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v1[0]
            dy_2 = v2[1] - v1[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            rowcount = v2[1] - v1[1]
            if v0[0] < v1[0]:
                slope_x1 = slope_1
                slope_x2 = slope_2
                x1 = v0[0]
                x2 = v1[0]
            else:
                slope_x1 = slope_2
                slope_x2 = slope_1
                x1 = v1[0]
                x2 = v0[0]
            yy = v0[1]
            print(f"Y {yy} X1 {x1} X2 {x2} Slope X1 {slope_x1} Slope X2 {slope_x2} Count {rowcount}")
            assert x1 <= 255
            assert x2 <= 255
            f.write(b'\xc0')                  # 00 - type C0
            if (yy < 0):
                assert y > -55
                f.write(yy.to_bytes(1, 'little', signed=True)) # 01 - Y
            else:
                f.write(yy.to_bytes(1, 'little')) # 01 - Y
            f.write(x1.to_bytes(1, 'little')) # 02 - X1
            f.write(x2.to_bytes(1, 'little')) # 03 - X1
            f.write(slope2bytes(slope_x1))    # 04-05 - X1 inc
            f.write(slope2bytes(slope_x2))    # 06-07 - X2 inc
            f.write(color_idx_out.to_bytes(1, 'little')) # 08 color index
            f.write(rowcount.to_bytes(1, 'little')) # 09 row count
        elif (v1[1] == v2[1]): # Part 1 only
            print("Part 1 only")
            dx_1 = v1[0] - v0[0]
            dy_1 = v1[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v0[0]
            dy_2 = v2[1] - v0[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            rowcount = v1[1] - v0[1]
            if v1[0] < v2[0]:
                slope_x1 = slope_1
                slope_x2 = slope_2
            else:
                slope_x1 = slope_2
                slope_x2 = slope_1
            xx = v0[0]
            yy = v0[1]
            print(f"Y {yy} X {xx} Slope X1 {slope_x1} Slope X2 {slope_x2} Count {rowcount}")
            assert xx <= 255
            if v0[0] == v1[0]:
                #time.sleep(5)
                pass
            f.write(b'\x80')                  # 00 - type 80
            if (yy < 0):
                assert y > -55
                f.write(yy.to_bytes(1, 'little', signed=True)) # 01 - Y
            else:
                f.write(yy.to_bytes(1, 'little')) # 01 - Y
            f.write(xx.to_bytes(1, 'little')) # 02 - X
            f.write(slope2bytes(slope_x1))    # 03-04 - X1 inc
            f.write(slope2bytes(slope_x2))    # 05-06 - X2 inc
            f.write(color_idx_out.to_bytes(1, 'little')) # 07 color index
            f.write(rowcount.to_bytes(1, 'little')) # 08 row count

        else:
            dx_1 = v1[0] - v0[0]
            dy_1 = v1[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v0[0]
            dy_2 = v2[1] - v0[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            rowcount1 = v1[1] - v0[1]
            if (slope_1 > slope_2): # Two part, change X2
                print("Two part change X2")
                slope_x1 = slope_2
                slope_x2 = slope_1
                dx_x2_new = v2[0] - v1[0]
                dy_x2_new = v2[1] - v1[1]
                slope_x2_new = dx_x2_new / dy_x2_new if dy_x2_new != 0 else 0
                rowcount2 = v2[1] - v1[1]
                xx = v0[0]
                yy = v0[1]
                print(f"Y {yy} X {xx} Slope X1 {slope_x1} Slope X2 {slope_x2} Count {rowcount1} New X2 {slope_x2_new} Count {rowcount2}")
                assert xx <= 255
                f.write(b'\x40')                  # 00 - type 40
                if (yy < 0):
                    assert y > -55
                    f.write(yy.to_bytes(1, 'little', signed=True)) # 01 - Y
                else:
                    f.write(yy.to_bytes(1, 'little')) # 01 - Y
                f.write(xx.to_bytes(1, 'little')) # 02 - X
                f.write(slope2bytes(slope_x1))    # 03-04 - X1 inc
                f.write(slope2bytes(slope_x2))    # 05-06 - X2 inc
                f.write(color_idx_out.to_bytes(1, 'little')) # 07 color index
                f.write(rowcount1.to_bytes(1, 'little')) # 08 row count 1
                f.write(slope2bytes(slope_x2_new)) # 09-0a - new X2 inc
                f.write(rowcount2.to_bytes(1, 'little')) # 0b row count 1
            else: # Two part, change X1
                print("Two part change X1")
                slope_x1 = slope_1
                slope_x2 = slope_2
                dx_x1_new = v2[0] - v1[0]
                dy_x1_new = v2[1] - v1[1]
                slope_x1_new = dx_x1_new / dy_x1_new if dy_x1_new != 0 else 0
                rowcount2 = v2[1] - v1[1]
                xx = v0[0]
                yy = v0[1]
                assert xx <= 255
                print(f"Y {yy} X {xx} Slope X1 {slope_x1} Slope X2 {slope_x2} Count {rowcount1} New X1 {slope_x1_new} Count {rowcount2}")
                f.write(b'\x00')                  # 00 - type 00
                if (yy < 0):
                    assert y > -55
                    f.write(yy.to_bytes(1, 'little', signed=True)) # 01 - Y
                else:
                    f.write(yy.to_bytes(1, 'little')) # 01 - Y
                f.write(xx.to_bytes(1, 'little')) # 02 - X
                f.write(slope2bytes(slope_x1))    # 03-04 - X1 inc
                f.write(slope2bytes(slope_x2))    # 05-06 - X2 inc
                f.write(color_idx_out.to_bytes(1, 'little')) # 07 color index
                f.write(rowcount1.to_bytes(1, 'little')) # 08 row count 1
                f.write(slope2bytes(slope_x1_new)) # 09-0a - new X1 inc
                f.write(rowcount2.to_bytes(1, 'little')) # 0b row count 1
    if p < minp:
        minp = p
    if p < WORKSPLIT1:
        f.write(b'\xfd') # split-work
    if p < WORKSPLIT2:
        f.write(b'\xfd') # split-work
#    if p < WORKSPLIT3:
#        f.write(b'\xfd') # split-work


States = Enum('States', ['ENTERING', 'LOOPING', 'EXITING'])

# Main game loop
running = True
hedron_state = States.ENTERING

bounces = 0

f = open("trilist3.bin", "wb")

while running:
    for event in pygame.event.get():
        if event.type == QUIT:
            running = False

    if hedron_state == States.ENTERING:
        scale += 1
        if scale >= 55:
            scale = 55
            print("LOOPING")
            hedron_state = States.LOOPING
            f.write(b'\xfe') # end of list
            f.close()
            sprite_mode = True
            f = open("trilist4.bin", "wb")
#            rotation_speed_x = math.pi/180
#            rotation_speed_y = (math.pi/90)
            loop_x_start = abs(round(math.cos(angle_x),3))
            loop_y_start = abs(round(math.sin(angle_y),3))
    elif hedron_state == States.LOOPING:
        if loop_x_start == abs(round(math.cos(angle_x),3)) and loop_y_start == abs(round(math.sin(angle_y),3)):
            print("EXITING")
            print(f"maxp {maxp} minp {minp}")
            f.write(b'\xfe') # end of list
            break

    bob_x = math.sin(angle_x*8)*(scale/10)
    bob_y = math.sin(angle_x*4)*(scale/10)


    screen.fill(BLACK)
    advance_cube()
    if tris_seen:
        f.write(b'\xff') # end of frame

    pygame.display.flip()
    clock.tick(60)

# Quit Pygame
pygame.quit()

