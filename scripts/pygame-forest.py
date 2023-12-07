# To install pygame: pip install pygame      (my version: pygame-2.1.2)
from PIL import Image
import pygame
import math
# FIXME: remove this
import time
import random
import os

screen_width = 320
screen_height = 200
scale = 3

DEBUG = False
DEBUG_SHIFT_PALETTE = False  # FIXME: remove this!
DEBUG_POS_COLORS = True
DRAW_ORIG_PALETTE = False
DRAW_NEW_PALETTE = False
DO_SCROLL = False

'''
From reverse engineering READ2.PAS:

  - O2.SCI contains the scroll text
    - 10 + 768 bytes for palette = 778 bytes --> This is NOT used!
    - 640 * 32 for pixels = 20480 bytes
    - total is: 21258 bytes
    - Note: font pixels get a +128 on their color index!

  - HILLBACK.CLX contains the background image 
  - MAKEOBJ.BAT creates HILLBACK.OBJ using HILLBACK.CLX and makes it available hback (or hillback)
  - BGR.PAS 'includes' this HILLBACK.OBJ
  - This is compiled into BGR.TPU
  - READ2.PAS uses bgr (meaning: BGR.TPU). This becomes implicitily available as 'hback' in the code
  - The palette inside hback (first 10 dummy + 768 palette bytes) is actually used!

  -> IMPORTANT: we should *REMOVE* the mappings of pixels that are not <16 in color_index! (so basicly NOT include them in the reverse-mapping)

'''

'''

    - Palette shrinking from 1-18 colors to 1-16 colors: (note: original color 0 is never overwritten)

        RGB (hex)
        000  <- REMOVE: never overwritten
        001  -> 002   -> REMOVE: hardly noticable
        002
        113
        114  -> 113   <- REMOVE same blue value as next one, same red and green as previous one
        124
        225
        236
        247
        348
        358
        469
        47a
        57c
        58d
        69f
        79f
        7af
        8bf

   --> BUT: how do we deal with the CORRESPONDING scroll text colors?
       - For now: just remove the SAME corresponding indexes...
       
       
   New palette chart:
   
        - first 32 colors are not used -> 0 is black (IS BLACK USED?)
        - next 96 colors: forest/green colors (like now)
        
        - Normal 'blue' colors start with 0x80: 16 colors from 128-143
        - Next 7*16 colors add more 'light' according to the 3-bit value coming from the scroll text
   
'''

# FIXME: change this!
base_dir = 'assets/forest/'

background_image_filename = 'HILLBACK.CLX'
source_image_width = 320
source_image_height = 200

scroll_text_image_filename = 'O2.SCI'

def parse_sci_file(sci_bin):

    # The file essentially starts at position 10
    pos = 10
    
    # Note: we IGNORE the palette of the scroll text in this file!
    pos += 768
    
    pixels = []
    for pixel_byte_index in range(640*32):
        
        pixel_byte = int.from_bytes(sci_bin[pos:pos+1], byteorder='little')
        pos+=1
        pixels.append(pixel_byte)

    return pixels

def parse_clx_file(clx_bin):

    # The file essentially starts at position 10
    pos = 10
    
    palette_bytes = []
    for palette_byte_index in range(768):
        
        palette_byte = int.from_bytes(clx_bin[pos:pos+1], byteorder='little')
        pos+=1
        # Note: the RGB is 6-bits (0-63) and must be multiplied by 4 here
        palette_bytes.append(palette_byte*4)
        
        
    pixels = []
    for pixel_byte_index in range(320*200):
        
        pixel_byte = int.from_bytes(clx_bin[pos:pos+1], byteorder='little')
        pos+=1
        pixels.append(pixel_byte)
        
    return (palette_bytes, pixels)


def parse_pos_file(pos_bin):

    positions_info = []

    nr_of_positions_to_read = 237*31
    
    pos = 0
    for position_index in range(nr_of_positions_to_read):
    
        pos_info = {}
        pos_info['destinations'] = []
    
        nr_of_dest_pixels = int.from_bytes(pos_bin[pos:pos+2], byteorder='little')
        pos+=2
       
        for dest_pixel_index in range(nr_of_dest_pixels):
            dest_address = int.from_bytes(pos_bin[pos:pos+2], byteorder='little')
            pos+=2
            
            destination_info = {}
            #destination_info['address'] = dest_address
            destination_info['x'] = dest_address % 320
            destination_info['y'] = dest_address // 320
            
            pos_info['destinations'].append(destination_info)
        
        pos_info['nr_of_dest_pixels'] = nr_of_dest_pixels
        
        positions_info.append(pos_info)


    return positions_info


positions_info = [ None, None, None ]

full_pos1_file_name = os.path.join(base_dir, 'POS1.DAT')
pos1_file = open(full_pos1_file_name, 'rb')
pos1_binary = pos1_file.read()
pos1_file.close()
positions_info[0] = parse_pos_file(pos1_binary)

full_pos2_file_name = os.path.join(base_dir, 'POS2.DAT')
pos2_file = open(full_pos2_file_name, 'rb')
pos2_binary = pos2_file.read()
pos2_file.close()
positions_info[1] = parse_pos_file(pos2_binary)

full_pos3_file_name = os.path.join(base_dir, 'POS3.DAT')
pos3_file = open(full_pos3_file_name, 'rb')
pos3_binary = pos3_file.read()
pos3_file.close()
positions_info[2] = parse_pos_file(pos3_binary)


full_bgr_file_name = os.path.join(base_dir, background_image_filename)
bgr_file = open(full_bgr_file_name, 'rb')
bgr_binary = bgr_file.read()
bgr_file.close()
(palette_bytes, pixels) = parse_clx_file(bgr_binary)

full_scroll_text_file_name = os.path.join(base_dir, scroll_text_image_filename)
scroll_text_file = open(full_scroll_text_file_name, 'rb')
scroll_text_binary = scroll_text_file.read()
scroll_text_file.close()
scroll_text_pixels = parse_sci_file(scroll_text_binary)



# We first determine all unique 12-bit COLORS, so we can re-index the image (pixels) with the new color indexes

new_colors = []
new_colors_with_old_index = []
unique_12bit_colors = {}
old_color_index_to_new_color_index = []

old_color_index = 0
new_color_index_offset = 0    # We  start at index 0! (NOT preserving the first 16 colors)
new_color_index = new_color_index_offset
byte_index = 0

nr_of_palette_bytes = 3*256

while (byte_index < nr_of_palette_bytes):
    
    red = palette_bytes[byte_index]
    byte_index += 1
    green = palette_bytes[byte_index]
    byte_index += 1
    blue = palette_bytes[byte_index]
    byte_index += 1
    
    red = red & 0xF0
    green = green & 0xF0
    blue = blue & 0xF0
    
    color_str = format(red, "02x") + format(green, "02x") + format(blue, "02x") 
    
    if color_str in unique_12bit_colors:
        old_color_index_to_new_color_index.append(unique_12bit_colors.get(color_str))
    else:
        old_color_index_to_new_color_index.append(new_color_index)
        unique_12bit_colors[color_str] = new_color_index
        new_colors.append((red, green, blue))
        new_color_index += 1
    
    new_colors_with_old_index.append((red, green, blue))
    
    old_color_index += 1


# Using the POSx.DAT info, we determine which pixels should be in the first 16 colors.
background_colors_overwritten_by_scroller = {}
background_new_colors_overwritten_by_scroller = {}
nr_of_pixels_overdrawn_by_scroller = 0
for pos_file_nr in range(3):
    
    for pos_index, pos_info in enumerate(positions_info[pos_file_nr]):
    
        for destination in pos_info['destinations']:
        
            x_screen = destination['x']
            y_screen = destination['y']
            
            clr_idx = pixels[x_screen + y_screen * 320]
            
            nr_of_pixels_overdrawn_by_scroller += 1
            
            background_colors_overwritten_by_scroller[clr_idx] = True
            new_clr_idx = old_color_index_to_new_color_index[clr_idx]
            background_new_colors_overwritten_by_scroller[new_clr_idx] = True
            
#print(len(background_colors_overwritten_by_scroller.keys()))

#print(len(background_new_colors_overwritten_by_scroller.keys()))

#print(nr_of_pixels_overdrawn_by_scroller)

    
# Printing out asm for palette:

# FIXME: THIS IS WRONG! We need to use the new_colors_with_old_index-array!
# FIXME: THIS IS WRONG! We need to use the new_colors_with_old_index-array!
# FIXME: THIS IS WRONG! We need to use the new_colors_with_old_index-array!
palette_string = ""
for new_color in new_colors:
    red = new_color[0]
    green = new_color[1]
    blue = new_color[2]

    red = red >> 4
    blue = blue >> 4
    
    palette_string += "  .byte "
    palette_string += "$" + format(green | blue,"02x") + ", "
    palette_string += "$" + format(red,"02x")
    palette_string += "\n"

print(palette_string)


background_color = (0,0,0)



pygame.init()

pygame.display.set_caption('X16 2R Forest test')
screen = pygame.display.set_mode((screen_width*scale, screen_height*scale))
clock = pygame.time.Clock()


def run():



    # FIXME: we have to do this ONLY ONCE!
    screen.fill(background_color)
    
    # FIXME: we have to do this ONLY ONCE!
    for source_y in range(source_image_height):
        for source_x in range(source_image_width):

            y_screen = source_y
            x_screen = source_x
            
            clr_idx = pixels[source_x + source_y * 320]
            
            # NOT USING THIS ANYMORE: pixel_color = new_colors[old_color_index_to_new_color_index[clr_idx] - new_color_index_offset]
            pixel_color = new_colors_with_old_index[clr_idx]
            
            pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))



    scroll_offset = 0

    running = True
    
    while running:
        # TODO: We might want to set this to max?
        clock.tick(60)
        
        
        for event in pygame.event.get():

            if event.type == pygame.QUIT: 
                running = False

            '''
            # if event.type == pygame.KEYDOWN:
                    
                #if event.key == pygame.K_LEFT:
                #if event.key == pygame.K_RIGHT:
                #if event.key == pygame.K_COMMA:
                #if event.key == pygame.K_PERIOD:
                #if event.key == pygame.K_UP:
                #if event.key == pygame.K_DOWN:
            '''
                    
            if event.type == pygame.MOUSEBUTTONUP:
                pos = pygame.mouse.get_pos()
                source_x = pos[0] // scale
                source_y = pos[1] // scale
                
                clr_idx = pixels[source_x + source_y * 320]
                    
                # FIXME: use new_colors_with_old_index !!
                # FIXME: use new_colors_with_old_index !!
                # FIXME: use new_colors_with_old_index !!
                    
                pick_color = new_colors[old_color_index_to_new_color_index[clr_idx] - new_color_index_offset]
                
                print((source_x,source_y))
                print(pick_color)
                
                
        for pos_file_nr in range(3):
        
            for pos_index, pos_info in enumerate(positions_info[pos_file_nr]):
            
                # FIXME: we have a source of 640 pixels here, so we convert from 237 width (which is the pos_index based on) to 640 here
                x_scroll_source = pos_index % 237
                y_scroll_source = pos_index // 237
                scroll_text_clr_idx = scroll_text_pixels[scroll_offset + x_scroll_source + y_scroll_source*640]
            
                destinations = pos_info['destinations']
                
                for destination in destinations:
                
                    x_screen = destination['x']
                    y_screen = destination['y']
                    
                    clr_idx = pixels[x_screen + y_screen * 320]
                    
                    if (DEBUG_SHIFT_PALETTE):
                        if (clr_idx < 3):
                            clr_idx = 3
                    
                    
                    pixel_color = None
                    if (scroll_text_clr_idx > 0):
                        combined_clr_idx = clr_idx + scroll_text_clr_idx + 128
                        
                        # FIXME: WORKAROUND!! WHY IS THIS SOMETIMES @256?
                        # FIXME: WORKAROUND!! WHY IS THIS SOMETIMES @256?
                        # FIXME: WORKAROUND!! WHY IS THIS SOMETIMES @256?
                        if (combined_clr_idx > 255):
                            combined_clr_idx = 255
                        pixel_color = new_colors_with_old_index[combined_clr_idx]
                    else:
                        pixel_color = new_colors_with_old_index[clr_idx]
                        
                    if (DEBUG):
                        # Findings: only (oroginal) color index 1-18 are being overwritten by the scroller (so NOT index 0! which is black)
                        if (clr_idx == 18):
                        #if (clr_idx > 18):
                            pixel_color = (0xFF, 0xFF, 0x00)

                    if (DEBUG_POS_COLORS):
                        if (pos_file_nr == 0):
                            pixel_color = (0xFF, 0xFF, 0x00)
                        elif (pos_file_nr == 1):
                            pixel_color = (0xFF, 0x00, 0xFF)
                        elif (pos_file_nr == 2):
                            pixel_color = (0x00, 0xFF, 0xFF)
                    
                    pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))
        
        
        if (DRAW_ORIG_PALETTE):
        
            byte_index = 0

            x = 192
            y = 0
        
            while (byte_index < nr_of_palette_bytes):
                
                red = palette_bytes[byte_index]
                byte_index += 1
                green = palette_bytes[byte_index]
                byte_index += 1
                blue = palette_bytes[byte_index]
                byte_index += 1
                
                pixel_color = (red, green, blue)
        
                pygame.draw.rect(screen, pixel_color, pygame.Rect(x*scale, y*scale, 8*scale, 8*scale))
                
                if (byte_index % 16 == 0 and byte_index != 0):
                    y += 8
                    x = 192
                else:
                    x += 8
                    
        if (DRAW_NEW_PALETTE):
            # screen.fill(background_color)
            
            x = 0
            y = 0
            
            for old_clr_idx in range(256):
                pixel_color = new_colors_with_old_index[old_clr_idx]
                
                pygame.draw.rect(screen, pixel_color, pygame.Rect(x*scale, y*scale, 8*scale, 8*scale))
                
                # if (byte_index % 16 == 0 and byte_index != 0):
                if (old_clr_idx % 16 == 15):
                    y += 8
                    x = 0
                else:
                    x += 8
        
        
        pygame.display.update()
        
        if (DO_SCROLL):
            scroll_offset += 1
            
            if (scroll_offset > 640-237):
                scroll_offset = 0
        
        time.sleep(0.01)
   
        
    pygame.quit()


    
run()