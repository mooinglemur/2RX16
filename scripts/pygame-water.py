# To install pygame: pip install pygame      (my scrollsword_image_heightversion: pygame-2.1.2)
from PIL import Image
import pygame
import math
# FIXME: remove this
import time
import random
import os

screen_width = 320
screen_height = 200
scale = 2

# FIXME: rename to .DAT files?!
# FIXME: rename to .DAT files?!
# FIXME: rename to .DAT files?!

# FIXME: we should place this file in ROOT/ at some point!
bitmap_filename = "WATER.BIN"
scrollsword_filename = "SCROLLSWORD.BIN"
scroll_copy_code_filename = "SCROLLCOPY.BIN"
bitmap_image_width = 320
bitmap_image_height = 200
scrollsword_image_width = 400
# FIXME: is this correct?
scrollsword_image_height = 34

SCROLLER_BUFFER_ADDRESS = 0x6000

DEBUG_POS_COLORS = False
DRAW_ORIG_PALETTE = False
DRAW_NEW_PALETTE = False
DO_SCROLL = True

'''
From reverse engineering DEMO.PAS:

  - MIEKKA.SCI contains the scroll sword
    - 10 + 768 bytes for palette = 778 bytes --> This is NOT used!
    - 400 * 35 for pixels = 14000 bytes
    - total is: 14778 bytes

  - BKG.CLX contains the background image (320x200)
  - MAKEOB.BAT creates BKG.OBJ using BKG.CLX and makes it available tausta (or _tausta)
  - BKR.PAS 'includes' this BKG.OBJ
  - This is compiled into BGR.TPU
  - DEMO.PAS uses bkr (meaning: BKR.TPU). This becomes implicitily available as 'tausta' in the code
  - The palette inside tausta (first 10 dummy + 768 palette bytes) is actually used!

'''


# FIXME: change this!
base_dir = 'assets/water/'

background_image_filename = 'BKG.CLX'
source_image_width = 320
source_image_height = 200

scroll_sword_image_filename = 'MIEKKA.SCI'

def parse_sci_file(sci_bin):

    # The file essentially starts at position 10
    pos = 10
    
    # Note: we IGNORE the palette of the scroll sword in this file!
    pos += 768
    
    pixels = []
    for pixel_byte_index in range(400*35):
        
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

# FIXME!?
# FIXME!?
# FIXME!?
    nr_of_positions_to_read = 158*34
    
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

full_pos1_file_name = os.path.join(base_dir, 'WAT1.DAT')
pos1_file = open(full_pos1_file_name, 'rb')
pos1_binary = pos1_file.read()
pos1_file.close()
positions_info[0] = parse_pos_file(pos1_binary)

full_pos2_file_name = os.path.join(base_dir, 'WAT2.DAT')
pos2_file = open(full_pos2_file_name, 'rb')
pos2_binary = pos2_file.read()
pos2_file.close()
positions_info[1] = parse_pos_file(pos2_binary)

full_pos3_file_name = os.path.join(base_dir, 'WAT3.DAT')
pos3_file = open(full_pos3_file_name, 'rb')
pos3_binary = pos3_file.read()
pos3_file.close()
positions_info[2] = parse_pos_file(pos3_binary)

# FIXME! WHAT ABOUT WAT4.DAT??
# FIXME! WHAT ABOUT WAT4.DAT??
# FIXME! WHAT ABOUT WAT4.DAT??
# FIXME! WHAT ABOUT WAT4.DAT??
# FIXME! WHAT ABOUT WAT4.DAT??


full_bgr_file_name = os.path.join(base_dir, background_image_filename)
bgr_file = open(full_bgr_file_name, 'rb')
bgr_binary = bgr_file.read()
bgr_file.close()
(palette_bytes, pixels) = parse_clx_file(bgr_binary)

full_scroll_sword_file_name = os.path.join(base_dir, scroll_sword_image_filename)
scroll_sword_file = open(full_scroll_sword_file_name, 'rb')
scroll_sword_binary = scroll_sword_file.read()
scroll_sword_file.close()
scroll_sword_pixels = parse_sci_file(scroll_sword_binary)

# We first determine all unique 12-bit COLORS, so we can re-index the image (pixels) with the new color indexes

colors_12bit = []

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
    
    colors_12bit.append((red, green, blue))

'''
bitmap_data = []
for source_y in range(bitmap_image_height):

    for source_x in range(bitmap_image_width):

        clr_idx = pixels[source_x + source_y * 320]
        
        bitmap_data.append(clr_idx)
        
bitmapFile = open(bitmap_filename, "wb")
bitmapFile.write(bytearray(bitmap_data))
bitmapFile.close()
print("bitmap written to file: " + bitmap_filename)
'''


'''
# Note: we store the scrollsword pixels in a different way: column by column (from left to right)
scrollsword_data = []
for source_x in range(scrollsword_image_width):

    for source_y in range(scrollsword_image_height):

        clr_idx = scroll_sword_pixels[source_x + source_y * 400]
        
        # We want to this be nicely divided into 8kB chunks, we *for now* we store 256 * 32 pixels in each RAM bank
        # There is no real need to actually split this file (for now) since the LOAD kernal function on the X16 does
        # the spliting for us.
        
# FIXME!        
# FIXME!        
# FIXME!        
        # But note: only 34*158 are going to be copied into the scroller buffer!
        
        scrollsword_data.append(clr_idx)
        
scrollSwordFile = open(scrollsword_filename, "wb")
scrollSwordFile.write(bytearray(scrollsword_data))
scrollSwordFile.close()
print("scroll sword written to file: " + scrollsword_filename)
'''


'''
# Using the WATx.DAT info, we determine which pixels should be in the first 16 colors.
# Also: reversing the mapping: source_pos -> screen_x/y ==> screen_x/y -> source_pos
background_colors_overwritten_by_scroller = {}
nr_of_pixels_overdrawn_by_scroller = 0
screen_xy_to_source_pos = {}
for pos_file_nr in range(3):
    
    for pos_index, pos_info in enumerate(positions_info[pos_file_nr]):
    
        for destination in pos_info['destinations']:
        
            x_screen = destination['x']
            y_screen = destination['y']
            
            clr_idx = pixels[x_screen + y_screen * 320]
            
# FIXME!
            # Note: We should only change pixels that are blue-ish (so they should be >=128)
            if (clr_idx >= 128):
            
                nr_of_pixels_overdrawn_by_scroller += 1
                background_colors_overwritten_by_scroller[clr_idx] = True
                
                if (not (y_screen in screen_xy_to_source_pos)):
                    screen_xy_to_source_pos[y_screen] = {}
                    
                screen_xy_to_source_pos[y_screen][x_screen] = pos_index
            

print('nr of pixels overdrawn by scroller: ' + str(nr_of_pixels_overdrawn_by_scroller))

#print(len(background_colors_overwritten_by_scroller.keys()))
#print(nr_of_pixels_overdrawn_by_scroller)

'''



'''
# Now we go through the screen coordinates (left to right, then top to bottom)
# and for a pixel that has a source_pos we start to create hor-line-draw code
# to draw on that row. If we encounter a pixel that has no source_pos anymore
# to end that hor-line-draw code (and if it fits into 8kb) we add it to a block of code.
# And we keep doing this until we reach the end of the screen.

def hor_line_source_pixels_to_code(start_x, start_y, hor_line_source_pixels):
    hor_line_code = []
    
    # We first have to set the ADDR medium and low
    #   IMPORTANT: we *assume* that the bitmap address starts at $00000 ! (320x200@8bpp, single buffer)
    
    # Using start_x and start_y we determine the ADDRESS_LOW and ADDRESS_MED
    
    start_address = start_y * 320 + start_x
    start_address_low = start_address % 256
    start_address_med = start_address // 256
    
    # lda #ADDRESS_LOW
    hor_line_code.append(0xA9)  # lda #..
    hor_line_code.append(start_address_low)  # #ADDRESS_LOW
    
    # sta ADDRx_L ($9F20)
    hor_line_code.append(0x8D)  # sta ....
    hor_line_code.append(0x20)  # $20
    hor_line_code.append(0x9F)  # $9F
    
    # lda #ADDRESS_MED
    hor_line_code.append(0xA9)  # lda #..
    hor_line_code.append(start_address_med)  # #ADDRESS_MED
    
    # sta ADDRx_M ($9F21)
    hor_line_code.append(0x8D)  # sta ....
    hor_line_code.append(0x21)  # $21
    hor_line_code.append(0x9F)  # $9F
    
    # We then load and store store each consecutive pixel
    
    for source_pixel_pos in hor_line_source_pixels:
        # The source pixel position assumes 158 wide, 34 high. We need to convert this to 34 high, 158 wide
        source_pixel_pos_x = source_pixel_pos % 158
        source_pixel_pos_y = source_pixel_pos // 158
        source_pixel_address = SCROLLER_BUFFER_ADDRESS + source_pixel_pos_x*34 + source_pixel_pos_y
        
        source_pixel_address_low = source_pixel_address % 256
        source_pixel_address_high = source_pixel_address // 256
        
        # lda SOURCE_PIXEL_ADDRESS
        hor_line_code.append(0xAD)  # lda ....
        hor_line_code.append(source_pixel_address_low)   # SOURCE_PIXEL_ADDRESS_LOW
        hor_line_code.append(source_pixel_address_high)  # SOURCE_PIXEL_ADDRESS_HIGH
        
        # sta VERA_DATA0 ($9F23)  -> this increments ADDR0 one pixel horizontally
        hor_line_code.append(0x8D)  # sta ....
        hor_line_code.append(0x23)  # $23
        hor_line_code.append(0x9F)  # $9F
    

    return hor_line_code

current_hor_line_source_pixels = []
current_start_x = None
current_start_y = None

code_chunks = []
current_code_chunk = []

for y_screen in range(200):
    
    for x_screen in range(320):
        
        hor_line_ended = False
        if (y_screen in screen_xy_to_source_pos and x_screen in screen_xy_to_source_pos[y_screen]):
            if (len(current_hor_line_source_pixels) == 0):
                current_start_x = x_screen
                current_start_y = y_screen
            current_hor_line_source_pixels.append(screen_xy_to_source_pos[y_screen][x_screen])
        else:
            hor_line_ended = True

        if (x_screen == 200-1) or (hor_line_ended):
        
            if (len(current_hor_line_source_pixels) > 0):
                #print((current_start_x, current_start_y, current_hor_line_source_pixels))
            
                hor_line_code = hor_line_source_pixels_to_code(current_start_x, current_start_y, current_hor_line_source_pixels)
                
                if (len(current_code_chunk) + len(hor_line_code) + 1 > 8*1024):  # +1 for the 'rts'
                    # This hor line code does not fit into 8kB anymore, so we need to create a new chunk
                    current_code_chunk.append(0x60)  # rts
                    nr_of_padding_zeros = 8*1024 - len(current_code_chunk)
                    current_code_chunk += [0] * nr_of_padding_zeros
                    code_chunks.append(current_code_chunk)
                    current_code_chunk = []
                    
                # We add the hor line code to the current chunk of code
                current_code_chunk += hor_line_code
                
                # Starting a new hor line
                current_hor_line_source_pixels = []
                current_start_x = None
                current_start_y = None

if (len(current_code_chunk) > 0):
    current_code_chunk.append(0x60)  # rts
    nr_of_padding_zeros = 8*1024 - len(current_code_chunk)
    # There is no need to add padding here
    code_chunks.append(current_code_chunk)
    
    
scroll_copy_code = []
for code_chunk in code_chunks:
    scroll_copy_code += code_chunk


scroll_copy_file = open(scroll_copy_code_filename, "wb")
scroll_copy_file.write(bytearray(scroll_copy_code))
scroll_copy_file.close()
print("scroll copy code written to file: " + scroll_copy_code_filename)
'''
            
    
# Printing out asm for palette:

palette_string = ""
for new_color in colors_12bit:
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
            
            pixel_color = colors_12bit[clr_idx]
            
            pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))

    pygame.display.update()


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
                    
                pick_color = colors_12bit[clr_idx]
                
                print((source_x,source_y))
                print(pick_color)
         

        for pos_file_nr in range(3):
        
            for pos_index, pos_info in enumerate(positions_info[pos_file_nr]):
            
                # FIXME: we have a source of 400 pixels here, so we convert from 158 width (which is the pos_index based on) to 400 here
                x_scroll_source = pos_index % 158
                y_scroll_source = pos_index // 158
                scroll_sword_clr_idx = scroll_sword_pixels[scroll_offset + x_scroll_source + y_scroll_source*400]
            
                destinations = pos_info['destinations']
                
                for destination in destinations:
                
                    x_screen = destination['x']
                    y_screen = destination['y']
                    
                    clr_idx = pixels[x_screen + y_screen * 320]
                    
                    pixel_color = None
                    
                    # Note: We should only overwrite pixels that not black
                    if (scroll_sword_clr_idx > 0):
                        pixel_color = colors_12bit[scroll_sword_clr_idx]
                    else:
                        pixel_color = colors_12bit[clr_idx]
                        
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
                pixel_color = colors_12bit[old_clr_idx]
                
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
            
            if (scroll_offset > 400-158):
                scroll_offset = 0
        
        time.sleep(0.01)
   
        
    pygame.quit()


    
run()