# To install pygame: pip install pygame      (my version: pygame-2.1.2)
import pygame
import math
import time

# This is a implementation to simulate the FX polygon filler as accurately as possible in Python.

screen_width = 320
screen_height = 240

scale = 2

pygame.init()

# Quick and dirty (debug) colors here (somewhat akin to VERA's first 16 colors0
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED  = (255, 64, 64)
CYAN = (64, 255, 255)
MAGENTA = (125, 34, 125)
GREEN = (64, 255, 64)
BLUE  = (64, 64, 255)
YELLOW = (255, 255, 64)

ORANGE = (255, 224, 0)
BROWN = (165, 42, 42)
PINK = (255, 224, 224)
DARKGRAY = (64, 64, 64)
GRAY = (128, 128, 128)
LIME = (224, 255, 224)
SKYBLUE = (224, 224, 255)
LIGHTGRAY = (192, 192, 192)

debug_colors = [
    BLACK,
    WHITE,
    RED,
    CYAN,
    MAGENTA,
    GREEN,
    BLUE,
    YELLOW,

    ORANGE,
    BROWN,
    PINK,
    DARKGRAY,
    GRAY,
    LIME,
    SKYBLUE,
    LIGHTGRAY,
]

frame_buffer = pygame.Surface((screen_width, screen_height), depth = 8)

pygame.display.set_caption('X16 FX Polygon filler simulator')

pygame_screen_size = (screen_width*scale, screen_height*scale)

screen = pygame.display.set_mode(pygame_screen_size)
clock = pygame.time.Clock()


def run():

    running = True
    
    screen.fill(YELLOW)

    while running:
        # TODO: We might want to set this to max?
        clock.tick(60)
        
        for event in pygame.event.get():

            if event.type == pygame.QUIT: 
                running = False

            #if event.type == pygame.KEYDOWN:
                    
                #if event.key == pygame.K_LEFT:
                #if event.key == pygame.K_RIGHT:
                #if event.key == pygame.K_COMMA:
                #if event.key == pygame.K_PERIOD:
                #if event.key == pygame.K_UP:
                #if event.key == pygame.K_DOWN:
                
            #if event.type == pygame.MOUSEMOTION: 
                # newrect.center = event.pos
            
        
        frame_buffer.fill(MAGENTA)

        # FIXME: we are using a starting position that has INTEGERS for now. We want to be able to use SUBPIXELS instead!
        x_top = 90
        y_top = 20
        
        # FIXME: we want to calculate our two slopes from the top vs left and top vs right points instead!
        #         and also the number of lines to draw
        #x_left = ..
        #y_left = ..
        #x_right = ..
        #y_right = ..
        
        # These half slopes are 6.9 fixed point signed values. This means you have to take the real number and multiply by 512 (eg 256 is 0.5)
        #   Or in other words: take the 6.9 signed value and divide by 512 to get the real value
        x1_half_slope = -110   # this moves -0.21484375 pixels for each half step (minus means: to the left)
        x2_half_slope = +380  # this moves  0.7421875  pixels for each half step (plus means: to the right)
        
        nr_of_lines_to_draw = 150
            
        # FIXME: we need to calculate the ACTUAL x1 and x2 values (with SUBPIXEL precsion!)
        x1 = int(x_top) + 0.5
        x2 = int(x_top) + 0.5
        
# FIXME: is this CORRECT?
        y_start = int(y_top) + 0.5
            
        line_color = (0xFF, 0xFF, 0xFF)
        
        for y_in_part in range(nr_of_lines_to_draw):
            y_screen = y_start + y_in_part
            
# FIXME: x1 and x2 are NOT ACCURATE!
            x1 += x1_half_slope / 512
            x2 += x2_half_slope / 512
            pygame.draw.line(frame_buffer, line_color, (x1,y_screen), (x2-1,y_screen), 1)
            
# FIXME: x1 and x2 are NOT ACCURATE!
            x1 += x1_half_slope / 512
            x2 += x2_half_slope / 512
        
        y_start = y_start + nr_of_lines_to_draw
        x2_half_slope = -1590  # this moves 3.10546875  pixels for each half step (minus means: to the left)
        nr_of_lines_to_draw = 50
        x2 = int(x2) + 0.5

        for y_in_part in range(nr_of_lines_to_draw):
            y_screen = y_start + y_in_part
            
# FIXME: x1 and x2 are NOT ACCURATE!
            x1 += x1_half_slope / 512
            x2 += x2_half_slope / 512
            pygame.draw.line(frame_buffer, line_color, (x1,y_screen), (x2-1,y_screen), 1)
            
# FIXME: x1 and x2 are NOT ACCURATE!
            x1 += x1_half_slope / 512
            x2 += x2_half_slope / 512

        
        screen.blit(pygame.transform.scale(frame_buffer, (screen_width*scale, screen_height*scale)), (0, 0))
        
        pygame.display.update()
        
        
    pygame.quit()


    
run()
