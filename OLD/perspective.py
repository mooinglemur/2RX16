#!/bin/env python3

import numpy as np

viewing_angle = 80  # Example viewing angle in degrees

horizon = 120
scale = 200

for y in range(0,120):
    px = 0-(320/2)
    py = 400
    pz = y + horizon

    sx = px / pz
    sx1 = (px+1) / pz
    sy = -py / pz

    scaled_x = sx * scale
    scaled_x1 = sx1 * scale
    scaled_y = sy * scale

    x_increment = scaled_x1 - scaled_x

    print(f"Ground Pixel: {px+160} {pz} => Overhead Pixel: {scaled_x} {scaled_y}, X increment {x_increment}")

