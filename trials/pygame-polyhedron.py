#/usr/bin/env python3

import pygame
from pygame.locals import *
import math
from enum import Enum

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

colors = [
    WHITE,
    BLUE,
    WHITE,
    BLUE,
    WHITE,
    BLUE,
    WHITE,
    BLUE,
    WHITE,
    BLUE,
    WHITE,
    BLUE
]


clock=pygame.time.Clock()

# Set up the display
width, height = 320, 200
screen = pygame.display.set_mode((width, height))
pygame.display.set_caption("Tetrakis Hexahedron")

# Define the vertices of the Tetrakis hexahedron
vertices = [
    (   0,    0, -3/2),
    (   0,    0,  3/2),
    (   0, -3/2,    0),
    (   0,  3/2,    0),
    (-3/2,    0,    0),
    ( 3/2,    0,    0),
    (-1, -1, -1),
    (-1, -1,  1),
    (-1,  1, -1),
    (-1,  1,  1),
    ( 1, -1, -1),
    ( 1, -1,  1),
    ( 1,  1, -1),
    ( 1,  1,  1),
]

# Define the faces by specifying the vertex indices
faces = [
    ( 0,  6, 10, 0), 
    ( 1,  9, 13, 0),
    ( 0,  8,  6, 1),
    ( 1, 11, 13, 1),
    ( 0, 12,  8, 2),
    ( 1,  7, 11, 2),
    ( 0, 10, 12, 3),
    ( 1,  9,  7, 3),
    ( 2,  6,  7, 4),
    ( 3, 12, 13, 4),
    ( 2,  7, 11, 5),
    ( 3, 12,  8, 5),
    ( 2, 10, 11, 6),
    ( 3,  8,  9, 6),
    ( 2, 10,  6, 7),
    ( 3,  9, 13, 7),
    ( 5, 11, 13, 8),
    ( 4,  8,  6, 8),
    ( 5, 10, 11, 9),
    ( 4,  9,  8, 9),
    ( 5, 10, 12, 10),
    ( 4,  7,  9, 10),
    ( 5, 13, 12, 11),
    ( 4,  6,  7, 11),
]


# Define the size and position of the polyhedron
scale = 20
center_offset = (width // 2, height // 2)

# Define rotation parameters
angle_x = 0
angle_y = 1
rotation_speed_x = 0.017
rotation_speed_y = -0.051
squishy_phase = 0
squishy_increment = 0.18
squishy_max_amplitude = 0.30
squishy_dampening = 0.0015
squishy_amplitude = 0

vertical_offset = -10
momentum = 0
gravity = 0.001

camera = (0, 0, 6)

def face_sorter(item):
    return zees[item[0]]+zees[item[1]]+zees[item[2]]

def advance_cube():
    global angle_x
    global angle_y
    global squishy_phase
    global squishy_amplitude
    global squishy_max_amplitude
    global zees

    # Apply rotation
    angle_x += rotation_speed_x
    angle_y += rotation_speed_y

    squishy_phase += squishy_increment
    squishy_amplitude -= squishy_dampening
    if squishy_amplitude < 0:
        squishy_amplitude = 0


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

        # Do squishy things
        squish_amount = 1+(math.sin(squishy_phase) * squishy_amplitude)
        
        new_y *= squish_amount
        new_x *= 1/(squish_amount**0.6)


        z_ratio = (1-camera[2]) / (new_z + camera[2]) # camera position

        new_x *= z_ratio
        new_y *= z_ratio

        # calculate offset
        new_y += vertical_offset


        x_proj = new_x * scale + center_offset[0]
        y_proj = new_y * scale + center_offset[1]

        rotated_vertices.append((x_proj, y_proj))
        
        zees.append(new_z)
    
    sorted_faces = sorted(faces, key=face_sorter, reverse=True)


    for face in sorted_faces[12:24]:
        color_idx = face[3]
        pygame.draw.polygon(screen, colors[color_idx], [rotated_vertices[i] for i in face[0:3]], 0)


States = Enum('States', ['FALLING', 'SQUISHING', 'BOUNCING', 'RISING', 'STEADY'])

# Main game loop
running = True
hedron_state = States.FALLING

bounces = 0

while running:
    for event in pygame.event.get():
        if event.type == QUIT:
            running = False

    if hedron_state == States.FALLING:
        momentum += gravity
        vertical_offset += momentum
        if vertical_offset >= 2:
            print("SQUISHING")
            hedron_state = States.SQUISHING

    elif hedron_state == States.SQUISHING:
        squishy_amplitude = squishy_max_amplitude
        squishy_phase = math.pi
        hedron_state = States.BOUNCING
        bounces += 1
        print("BOUNCING")

    elif hedron_state == States.BOUNCING:
        hedron_state = States.RISING
        if bounces >= 3:
            momentum = 0.075
        else:
            momentum = 0.12
        print("RISING")
        
    elif hedron_state == States.RISING:
        momentum -= gravity
        if momentum < 0:
            momentum = 0
            if bounces >= 3:
                hedron_state = States.STEADY
                print("STEADY")
            else:    
                hedron_state = States.FALLING
                print("FALLING")
        vertical_offset -= momentum





    screen.fill(BLACK)
    advance_cube()

    pygame.display.flip()
    clock.tick(60)

# Quit Pygame
pygame.quit()

