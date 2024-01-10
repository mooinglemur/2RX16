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

fx_state = {
    'x1_pos' : int(256),  # This is a 11.9 fixed point value (so you should divide by 512 to get the real value)
    'x2_pos' : int(256),  # This is a 11.9 fixed point value (so you should divide by 512 to get the real value)
    'x1_incr' : int(0),   # This is a 6.9 fixed point value (so you should divide by 512 to get the real value)
    'x2_incr' : int(0),   # This is a 6.9 fixed point value (so you should divide by 512 to get the real value)
}

def draw_fx_polygon_part(fx_state, frame_buffer, line_color, y_start, nr_of_lines_to_draw):

    for y_in_part in range(nr_of_lines_to_draw):
        y_screen = y_start + y_in_part

        # This is 'equivalent' of what happens when reading from DATA1
        fx_state['x1_pos'] += fx_state['x1_incr']
        fx_state['x2_pos'] += fx_state['x2_incr']
        
        x1 = fx_state['x1_pos'] / 512
        x2 = fx_state['x2_pos'] / 512
        
        pygame.draw.line(frame_buffer, line_color, (x1, y_screen), (x2-1, y_screen), 1)
        
        # This is 'equivalent' of what happens when reading from DATA0
        fx_state['x1_pos'] += fx_state['x1_incr']
        fx_state['x2_pos'] += fx_state['x2_incr']
    

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

        line_color = (0xFF, 0xFF, 0xFF)

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
        
        fx_state['x1_incr'] = x1_half_slope
        fx_state['x2_incr'] = x2_half_slope
        
        # FIXME: we need to calculate the ACTUAL x1 and x2 values (with SUBPIXEL precsion!)
        fx_state['x1_pos'] = int(x_top) * 512 + 256
        fx_state['x2_pos'] = int(x_top) * 512 + 256
        
        y_start = int(y_top)
        nr_of_lines_to_draw = 150
        
        draw_fx_polygon_part(fx_state, frame_buffer, line_color, y_start, nr_of_lines_to_draw)
        y_start = y_start + nr_of_lines_to_draw
        
        # Setting a new (half) slope for x2
        x2_half_slope = -1590  # this moves 3.10546875  pixels for each half step (minus means: to the left)
        fx_state['x2_incr'] = x2_half_slope
        nr_of_lines_to_draw = 50
        # This is equivalent of what happens when setting the new x2_incr
        fx_state['x2_pos'] = (fx_state['x2_pos'] // 512) * 512 + 256

        draw_fx_polygon_part(fx_state, frame_buffer, line_color, y_start, nr_of_lines_to_draw)
        
        screen.blit(pygame.transform.scale(frame_buffer, (screen_width*scale, screen_height*scale)), (0, 0))
        
        pygame.display.update()
        
        
    pygame.quit()


    
run()
