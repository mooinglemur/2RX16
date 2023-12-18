# To install pygame: pip install pygame      (my version: pygame-2.1.2)
from PIL import Image
import pygame
import math
import time
import random

random.seed(10)

DO_MOVE_LENS = True
DRAW_NEW_PALETTE = False
SHOW_LENS_SHIFTS = False
SHOW_LENS_SOURCE_USAGE = True

# TODO: we should *ALSO* use the LENS.png image! (with the 'glaring' of the lens)

lens_image_filename = "assets/lens/LENS.png"       # This is a picture of the lens itself
lens_source_image_width = 320
lens_source_image_height = 200

source_image_filename = "assets/lens/LENSPIC.png"  # This is the background picture (the monster)
source_image_width = 320
source_image_height = 200
bitmap_filename = "scripts/lens/BACKGROUND.DAT"
lens_positions_filename = "scripts/lens/LENS-POS.DAT"
download_code_filename = "scripts/lens/DOWNLOAD?.DAT"  # The question mark will be filled in later
upload_code_filename = "scripts/lens/UPLOAD?-?.DAT"    # The question marks will be filled in later

screen_width = 320
screen_height = 200

BITMAP_QUADRANT_BUFFER = 0x6000
half_lens_width = 59 # 117 total width, 1 pixel overlapping so 117 // 2 + 1 = 59 (or 118 // 2 if you will)
half_lens_height = 52 # 103 total height, 1 pixel overlapping so 103 // 2 + 1 = 52 (or 104 // 2 if you will)
lens_zoom = 16
scale = 2

# creating a image object for the background
im = Image.open(source_image_filename)
px = im.load()
palette_bytes = im.getpalette()

# creating a image object for the lens
im_lens = Image.open(lens_image_filename)
lens_px = im_lens.load()
lens_palette_bytes = im_lens.getpalette()

# We first convert to 12-bit COLORS
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

offset_blue_colors = 64
for clr_idx in range(0, offset_blue_colors):
    new_color = colors_12bit[clr_idx]

    red = new_color[0]
    green = new_color[1]
    blue = new_color[2]

    red_dark = red // 2
    green_dark = green // 2

    new_blue_dark = 256 - int((256 - blue) / 1.2)
    new_blue_normal = 256 - int((256 - blue) / 1.5)
    new_blue_light = 256 - int((256 - blue) / 2.0)
    
    red_dark = red_dark & 0xF0
    green_dark = green_dark & 0xF0
    
    new_blue_dark = new_blue_dark & 0xF0
    new_blue_normal = new_blue_normal & 0xF0
    new_blue_light = new_blue_light & 0xF0
    
    # colors 64 through 127 are going to be dark blue-ish
    blue_ish_color_dark = (red_dark, green_dark, new_blue_dark)
    colors_12bit[clr_idx+offset_blue_colors*1] = blue_ish_color_dark
    
    # colors 128 through 191 are going to be normal blue-ish
    blue_ish_color_normal = (red_dark, green_dark, new_blue_normal)
    colors_12bit[clr_idx+offset_blue_colors*2] = blue_ish_color_normal
    
    # colors 192 through 255 are going to be light blue-ish
    blue_ish_color_light = (red_dark, green_dark, new_blue_light)
    colors_12bit[clr_idx+offset_blue_colors*3] = blue_ish_color_light
    

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

# x,y offsets
lens_offsets = []

# DEBUG array (to know/understand which bitmap pixels are being sampled when the lens is on top of it
lens_source_pixels = []

# black/transparent + 3 shades of blue for each pixel in the lens
lens_pixels = []

def init_lens(lens_px):

    d = lens_zoom
    d2 = lens_zoom*lens_zoom
    
    hlfh = half_lens_height
    hlfw = half_lens_width
    
    full = hlfw*hlfw + hlfh*hlfh

    for y in range(int((half_lens_height * 2) - 1)):
        lens_offsets.append([])
        lens_pixels.append([])
        lens_source_pixels.append([])
        for x in range(int((half_lens_width * 2) - 1)):
            lens_offsets[y].append(None)
            lens_pixels[y].append(None)
            lens_source_pixels[y].append(0)
            
    # We use the lens image to fill lens_pixels with the values 0 (black/transparent), 1, 2 and 3 (shades of blue)

    lens_source_image_start_x = 19
    lens_source_image_start_y = 8
    
    for lens_source_y in range(lens_source_image_start_y, lens_source_image_start_y + (half_lens_height * 2) - 1):
        for lens_source_x in range(lens_source_image_start_x, lens_source_image_start_x + (half_lens_width * 2) - 1):
            lens_pixel_color_index = lens_px[lens_source_x, lens_source_y]
            
            # Map from colors 0-4 to 0-3 
            if (lens_pixel_color_index == 1):
                lens_pixel_color_index = 0
            elif (lens_pixel_color_index > 0):
                lens_pixel_color_index -= 1
                
            lens_pixels[lens_source_y - lens_source_image_start_y][lens_source_x - lens_source_image_start_x] = lens_pixel_color_index
            

    # 2R analysis: https://fabiensanglard.net/second_reality/
            
    # Original: https://github.com/mtuomi/SecondReality/blob/master/LENS/CALC.C
    
    # full=59*59+50*50;
    
    # void	lenscalc(int x,int y,int *px,int *py)
    # {
    #     double	now,new,fx,fy;
    #     now=full-(double)(x*x+(y*9/8)*(y*9/8));
    #     if(now<1.0) now=1.0;
    #     new=250.0/pow(now,0.69);
    #     fx=(double)(rand()-16384)/30000.0;
    #     fy=(double)(rand()-16384)/30000.0;
    #     *px=(int)(((double)x+fx)*new);
    #     *py=(int)(((double)y+fy)*new);
    # }
       
    min_y_shift = 0
    max_y_shift = 0
       
    for y in range(half_lens_height):
        # TODO: we need to adjust y by 9/8 or by something else?
        y2 = (y*9/8)*(y*9/8)
        for x in range(half_lens_width):
            x2 = x*x
            if (lens_pixels[hlfh-1+y][hlfw-1+x] != 0):
            
                now = full - (x2 + y2)
                if now < 1:
                    now = 1
                    
                # higher than 240 creates bad pixels at the borders right now...
                new = 240 / (now**0.69)
                fx = (random.random() - 0.5) * 1.2
                fy = (random.random() - 0.5) * 1.2
                px = int((x+fx)*new)
                py = int((y+fy)*new)
                
                x_shift = px - x
                y_shift = py - y
                
                if y_shift < min_y_shift:
                    min_y_shift = y_shift
                if y_shift > max_y_shift:
                    max_y_shift = y_shift
                
# FIXME: this now OVERLAPS! CHECK IT!
                # Inside the lens the pixel gets shifted according to the quadrant it is in
                lens_offsets[ hlfh-1 + y][ hlfw-1 + x] = (  x_shift,  y_shift)
                lens_offsets[ hlfh-1 - y][ hlfw-1 + x] = (  x_shift, -y_shift)
                lens_offsets[ hlfh-1 + y][ hlfw-1 - x] = ( -x_shift,  y_shift)
                lens_offsets[ hlfh-1 - y][ hlfw-1 - x] = ( -x_shift, -y_shift)
            else:
# FIXME: this now OVERLAPS! CHECK IT!
                # Outside the lens there is no distortion/shift
                lens_offsets[ hlfh-1 + y][ hlfw-1 + x] = (None,None)
                lens_offsets[ hlfh-1 - y][ hlfw-1 + x] = (None,None)
                lens_offsets[ hlfh-1 + y][ hlfw-1 - x] = (None,None)
                lens_offsets[ hlfh-1 - y][ hlfw-1 - x] = (None,None)

    #print("min_y_shift: " + str(min_y_shift))
    #print("max_y_shift: " + str(max_y_shift))

# Generate 'download' code (to copy quarter of a cirle from VRAM to Fixed RAM)
#
# Preconditions to run this code:
#
#  - Normal addr1-mode
#  - DCSEL=2
#  - ADDR0-increment should be set 1-pixel vertically (+320/-320 according to quadrant)
#  - ADDR1-increment should be set 1-pixel horizontally (+1/-1 according to quadrant)
#  - ADDR0 set to address of first pixel in quadrant
#  - X1-increment is 0
#  - X1-position is 0
#  - Free memory at address BITMAP_QUADRANT_BUFFER (half_lens_width*half_lens_height in size)
#

def add_upl_code(upload_codes, upl_idx, code):
    upload_codes[0][upl_idx].append(code)
    upload_codes[1][upl_idx].append(code)
    upload_codes[2][upl_idx].append(code)
    upload_codes[3][upl_idx].append(code)
    

def generate_download_and_upload_code():

    download_code = ([],[])
    upload_codes = [
        ([],[],[]),
        ([],[],[]),
        ([],[],[]),
        ([],[],[])
    ]

    dwn_idx = 0
    upl_idx = 0
    
    hlfh = half_lens_height
    hlfw = half_lens_width

    # FIXME: we download and upload the PIXELS on the AXIS **TWICE**! This is somewhat inefficient!

    for y in range(hlfh):
        for x in range(hlfw):
            
            # If the lens_pixel color not is black/transparent, we keep downloading this row
            if (lens_pixels[hlfh-1 + y][hlfw-1 + x] != 0):
            
                # -- download --
                
                # We need to download a byte from VRAM into Fixed RAM

                # lda VERA_DATA1 ($9F24)  -> this loads a byte from VRAM
                download_code[dwn_idx].append(0xAD)  # lda ....
                download_code[dwn_idx].append(0x24)  # $24
                download_code[dwn_idx].append(0x9F)  # $9F
                
                address_to_write_to = BITMAP_QUADRANT_BUFFER + y * hlfw + x
                
                # sta $6... 
                download_code[dwn_idx].append(0x8D)  # sta ....
                download_code[dwn_idx].append(address_to_write_to % 256)  # low part of address
                download_code[dwn_idx].append(address_to_write_to // 256)  # high part of address
                
            
            if (((lens_pixels[hlfh-1 + y][hlfw-1 + x] == 0) or x == hlfw-1) and (y != hlfh-1)):
            
                # We reached the end of this row, so we have to move to the next one (unless its the last row)
            
                # -- download --
                
                # lda #%00000010  (polygon mode = 1)
                download_code[dwn_idx].append(0xA9)  # lda #..
                download_code[dwn_idx].append(0x02)  # #%00000010  (polygon mode = 1)
                
                # sta VERA_CTRL ($9F29)
                download_code[dwn_idx].append(0x8D)  # sta ....
                download_code[dwn_idx].append(0x29)  # $29
                download_code[dwn_idx].append(0x9F)  # $9F
                
                # lda VERA_DATA0 ($9F23)  -> this increments ADDR0 one pixel vertically
                download_code[dwn_idx].append(0xAD)  # lda ....
                download_code[dwn_idx].append(0x23)  # $23
                download_code[dwn_idx].append(0x9F)  # $9F
                
                # lda VERA_DATA1 ($9F24)  -> this sets ADDR1 to DATA0 + x1 (note: x1 is 0)
                download_code[dwn_idx].append(0xAD)  # lda ....
                download_code[dwn_idx].append(0x24)  # $24
                download_code[dwn_idx].append(0x9F)  # $9F
                
                # stz VERA_CTRL ($9F29)  (polygon mode = 0)
                download_code[dwn_idx].append(0x9C)  # stz ....
                download_code[dwn_idx].append(0x29)  # $29
                download_code[dwn_idx].append(0x9F)  # $9F
                
                # -- download row end --
                
                # Note: dividing by 2.5 divides the two files in roughly equal size
                if (y == int(hlfh/2.5)):
                    # We are halfway, we need to add an rts and continue in the other array
                    download_code[dwn_idx].append(0x60)  # rts
                    dwn_idx += 1

                # We break from the x-loop
                break
                
        if (y == hlfh-1):
            # We are done, we need to add an rts
            download_code[dwn_idx].append(0x60)  # rts


    for y in range(hlfh):
        for x in range(hlfw):
            (x_shift, y_shift) = lens_offsets[ hlfh-1 + y][ hlfw-1 + x]
            
            # If the lens_pixel color not is black/transparent, we keep downloading this row
            lens_pixel = lens_pixels[hlfh-1 + y][hlfw-1 + x]
            
            lens_pixel_0 = lens_pixels[hlfh-1 + y][hlfw-1 + x]
            lens_pixel_1 = lens_pixels[hlfh-1 + y][hlfw-1 - x]
            lens_pixel_2 = lens_pixels[hlfh-1 - y][hlfw-1 - x]
            lens_pixel_3 = lens_pixels[hlfh-1 - y][hlfw-1 + x]

            if (lens_pixel != 0):
            
                # -- upload --

                address_to_read_from = BITMAP_QUADRANT_BUFFER + (y+y_shift) * hlfw + (x+x_shift)
                
                # DEBUG: marking a source pixel as being read
                lens_source_pixels[hlfh-1 + y+y_shift][hlfw-1 + x+x_shift] += 1
                if (y+y_shift != 0 and x+x_shift != 0):
                    lens_source_pixels[hlfh-1 + y+y_shift][hlfw-1 - (x+x_shift)] += 1
                if (y+y_shift != 0 and x+x_shift != 0):
                    lens_source_pixels[hlfh-1 - (y+y_shift)][hlfw-1 + x+x_shift] += 1
                if (not (y+y_shift == 0 and x+x_shift == 0)):
                    lens_source_pixels[hlfh-1 - (y+y_shift)][hlfw-1 - (x+x_shift)] += 1
                
                # lda $6....
                add_upl_code(upload_codes, upl_idx, 0xAD)  # lda ....
                add_upl_code(upload_codes, upl_idx, address_to_read_from % 256)  # low part of address
                add_upl_code(upload_codes, upl_idx, address_to_read_from // 256)  # high part of address
                
                # adc #64/128/192
                
                add_upl_code(upload_codes, upl_idx, 0x69)  # adc #...
                upload_codes[0][upl_idx].append(lens_pixel_0*0x40)
                upload_codes[1][upl_idx].append(lens_pixel_1*0x40)
                upload_codes[2][upl_idx].append(lens_pixel_2*0x40)
                upload_codes[3][upl_idx].append(lens_pixel_3*0x40)
                
                # sta VERA_DATA1 ($9F24)  -> this writes a byte to VRAM
                add_upl_code(upload_codes, upl_idx, 0x8D)  # sta ....
                add_upl_code(upload_codes, upl_idx, 0x24)  # $24
                add_upl_code(upload_codes, upl_idx, 0x9F)  # $9F
                
            
            if (((lens_pixel == 0) or x == hlfw-1) and (y != hlfh-1)):
            
                # We reached the end of this row, so we have to move to the next one (unless its the last row)
            
                # -- upload --

                # lda VERA_DATA0 ($9F23)  -> this increments ADDR0 one pixel vertically
                add_upl_code(upload_codes, upl_idx, 0xAD)  # lda ....
                add_upl_code(upload_codes, upl_idx, 0x23)  # $23
                add_upl_code(upload_codes, upl_idx, 0x9F)  # $9F
                
                # lda VERA_DATA1 ($9F24)  -> this sets ADDR1 to DATA0 + x1 (note: x1 is 0)
                add_upl_code(upload_codes, upl_idx, 0xAD)  # lda ....
                add_upl_code(upload_codes, upl_idx, 0x24)  # $24
                add_upl_code(upload_codes, upl_idx, 0x9F)  # $9F

                # -- updload row end --
                
                if (y == int(hlfh*0.3)):
                    # We are at the end of the first file, we need to add an rts and continue in the other array
                    add_upl_code(upload_codes, upl_idx, 0x60)  # rts
                    upl_idx += 1
                    
                if (y == int(hlfh*0.6)):
                    # We are at the end of the second file, we need to add an rts and continue in the other array
                    add_upl_code(upload_codes, upl_idx, 0x60)  # rts
                    upl_idx += 1

                
                # We break from the x-loop
                break
                
        if (y == hlfh-1):
            # We are done, we need to add an rts
            add_upl_code(upload_codes, upl_idx, 0x60)  # rts
            upl_idx += 1
            

    return (download_code, upload_codes)


pygame.init()

pygame.display.set_caption('X16 2R Lens test')
screen = pygame.display.set_mode((screen_width*2, screen_height*2))
clock = pygame.time.Clock()

init_lens(lens_px)

(download_code, upload_codes) = generate_download_and_upload_code()

for dwn_idx in range(2):
    current_download_code_filename = download_code_filename.replace('?', str(dwn_idx), 1)
    codeFile = open(current_download_code_filename, "wb")
    codeFile.write(bytearray(download_code[dwn_idx]))
    codeFile.close()
    print("download code " + str(dwn_idx) +" written to file: " + current_download_code_filename)

for quadrant_idx in range(4):
    for upl_idx in range(3):
        current_upload_code_filename = upload_code_filename.replace('?', str(quadrant_idx), 1)
        current_upload_code_filename = current_upload_code_filename.replace('?', str(upl_idx), 1)

        codeFile = open(current_upload_code_filename, "wb")
        codeFile.write(bytearray(upload_codes[quadrant_idx][upl_idx]))
        codeFile.close()
        print("upload code " + str(quadrant_idx) +'-'+ str(upl_idx) +" written to file: " + current_upload_code_filename)


bitmap_data = []
# FIXME: we now use 0 as BLACK, but in the bitmap a DIFFERENT color index is used as BLACK!
#hor_margin_pixels = [0] * 32
for source_y in range(source_image_height):

    for source_x in range(source_image_width):

        pixel_color_index = px[source_x, source_y]
        
        bitmap_data.append(pixel_color_index)
    
tableFile = open(bitmap_filename, "wb")
tableFile.write(bytearray(bitmap_data))
tableFile.close()
print("bitmap written to file: " + bitmap_filename)


# ---- LENS POSITIONS ----
lens_pos_x = 65
lens_pos_y = -50

lens_speed_x = 1
lens_speed_y = 1

first_bounce = True

lens_positions = []
# FIXME: how many frames?? or when off screen?
for frame_nr in range(1000):

    # FIXME: should we really *start* with incrementing x and y position? Or should the FIRST entry be the actual starting position?
    lens_pos_x += lens_speed_x
    lens_pos_y += lens_speed_y
    
    if (lens_pos_x > 256 or lens_pos_x < 60):
        lens_speed_x = -lens_speed_x
        
    if (lens_pos_y > 150 and frame_nr < 600):
        lens_pos_y -= lens_speed_y
        
        if first_bounce: 
            lens_speed_y = -lens_speed_y * 2/3
            first_bounce = False
        else:
            lens_speed_y = -lens_speed_y * 9/10
            
    lens_speed_y += 2/64

    # FIXME: we now add every other frame, but we should interpolate from 70fps frames to 30fps frames instead!
    if (frame_nr % 2 == 0):
        lens_positions.append(lens_pos_x % 256)
        lens_positions.append(lens_pos_x // 256)
        if int(lens_pos_y) < 0:
            lens_pos_y_alt = 256*256+int(lens_pos_y)
            lens_positions.append(lens_pos_y_alt % 256)
            lens_positions.append(lens_pos_y_alt // 256)
        else:
            lens_positions.append(int(lens_pos_y) % 256)
            lens_positions.append(int(lens_pos_y) // 256)

        # We draw the past position off-screen, but after that we stop
        if (lens_pos_y > 200+half_lens_height and frame_nr >= 600):
            # We have reached the end
            break
            

# Marker that its the end
lens_positions.append(255)
lens_positions.append(255)
lens_positions.append(255)
lens_positions.append(255)

tableFile = open(lens_positions_filename, "wb")
tableFile.write(bytearray(lens_positions))
tableFile.close()
print("lens positions written to file: " + lens_positions_filename)

# print(len(lens_positions)//4)

def run():

    running = True
    
    frame_nr = 0
    
    lens_pos_x = lens_positions[frame_nr*4] + lens_positions[frame_nr*4+1]*256
    lens_pos_y = lens_positions[frame_nr*4+2] + lens_positions[frame_nr*4+3]*256
    
    prev_lens_pos_x = lens_pos_x
    prev_lens_pos_y = lens_pos_y
    
    screen.fill(background_color)
    
    for source_y in range(source_image_height):
        for source_x in range(source_image_width):

            y_screen = source_y
            x_screen = source_x
            
            pixel_color = colors_12bit[px[source_x, source_y]]
            
            pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))
    
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
                    
            #if event.type == pygame.MOUSEMOTION: 
                # newrect.center = event.pos
            '''
            
        if (SHOW_LENS_SHIFTS):
            screen.fill(background_color)
            
            for lens_y in range(int(half_lens_height*2-1)):
                for lens_x in range(int(half_lens_width*2-1)):
                    (x_shift, y_shift) = lens_offsets[lens_y][lens_x]
                    
                    if (x_shift is not None):
                        
                        # x shift is red
                        red = abs(x_shift)*16
                        # y shift is blue
                        blue = abs(y_shift)*16
                        
                        pixel_color = (red, 0x00, blue)
                        
                        pygame.draw.rect(screen, pixel_color, pygame.Rect(lens_x*scale, lens_y*scale, scale, scale))
                    
            pygame.display.update()
            time.sleep(0.01)
            continue
            
            
        if (SHOW_LENS_SOURCE_USAGE):
        
            screen.fill(background_color)
            
            nr_of_pixels = 0
            nr_of_used_pixels = 0
            for lens_y in range(int(half_lens_height*2-1)):
                for lens_x in range(int(half_lens_width*2-1)):
                    # Note: nr_of_usages is not entirely correct when X and Y  are both 0!
                    nr_of_usages = lens_source_pixels[lens_y][lens_x]
                    
                    value = 0
                    if (nr_of_usages > 0):
                        if(False):
                            value = nr_of_usages * 64
                            if value > 255:
                                value = 255
                        else:
                            value = 0xFF
                        nr_of_used_pixels += 1
                    nr_of_pixels += 1
                    
                    # x shift is red
                    #red = abs(nr_of_usages)*32
                    # y shift is blue
                    #blue = abs(nr_of_usages)*32
                        
                    pixel_color = (value, value, value)
                    
                    pygame.draw.rect(screen, pixel_color, pygame.Rect(lens_x*scale, lens_y*scale, scale, scale))
                    
            pygame.display.update()
            time.sleep(0.01)
            
            print(str(nr_of_pixels) + ":"  + str(nr_of_used_pixels))
            continue
        

        if (DO_MOVE_LENS):
            lens_pos_x = lens_positions[frame_nr*4] + lens_positions[frame_nr*4+1]*256
            lens_pos_y = lens_positions[frame_nr*4+2] + lens_positions[frame_nr*4+3]*256
            if (lens_pos_x > 128*256):
                lens_pos_x = lens_pos_x-256*256
            if (lens_pos_y > 128*256):
                lens_pos_y = lens_pos_y-256*256
            
            if (lens_pos_x < 0):
                # This is the marker that we reached the end
                break
                
        frame_nr += 1    
        
                
        '''
        screen.fill(background_color)

        for source_y in range(source_image_height):
            for source_x in range(source_image_width):

                y_screen = source_y
                x_screen = source_x
                
                pixel_color = colors_12bit[px[source_x, source_y]]
                
                pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))
        '''

        # Restoring from the previous draw of the lens
        for lens_y in range(int(half_lens_height*2-1)):
            for lens_x in range(int(half_lens_width*2-1)):
                # If the lens_pixel color is black/transparent, we dont do anything
                if (lens_pixels[lens_y][lens_x] == 0):
                    continue

                source_y = prev_lens_pos_y - half_lens_height + lens_y
                source_x = prev_lens_pos_x - half_lens_width + lens_x
                
                if (source_y >= 0 and source_y < source_image_height and source_x >= 0 and source_x < source_image_width):
                    y_screen = source_y
                    x_screen = source_x
                    
                    pixel_color = colors_12bit[px[source_x, source_y]]
                    
                    pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))

                
        for lens_y in range(int(half_lens_height*2-1)):
            for lens_x in range(int(half_lens_width*2-1)):
                
                # If the lens_pixel color is black/transparent, we dont do anything
                if (lens_pixels[lens_y][lens_x] == 0):
                    continue
                
                blue_shift = lens_pixels[lens_y][lens_x]
                
                (x_shift, y_shift) = lens_offsets[lens_y][lens_x]
                
                source_y = lens_pos_y - half_lens_height + lens_y + y_shift
                source_x = lens_pos_x - half_lens_width + lens_x + x_shift
                
                if (source_y >= 0 and source_y < source_image_height and source_x >= 0 and source_x < source_image_width):
                    pixel_color = colors_12bit[px[source_x, source_y] + offset_blue_colors*blue_shift]
                    
                    y_screen = lens_pos_y - half_lens_height + lens_y
                    x_screen = lens_pos_x - half_lens_width + lens_x
                    
                    pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))
                else:
                    # This is off screen, we do not draw
                    pass
                
        prev_lens_pos_x = lens_pos_x
        prev_lens_pos_y = lens_pos_y
                
        if (DRAW_NEW_PALETTE):
            # screen.fill(background_color)
            
            x = 0
            y = 0
            
            for clr_idx in range(256):
            
                #if clr_idx >= len(colors_12bit):
                #    continue
            
                pixel_color = colors_12bit[clr_idx]
                
                pygame.draw.rect(screen, pixel_color, pygame.Rect(x*scale, y*scale, 8*scale, 8*scale))
                
                # if (byte_index % 16 == 0 and byte_index != 0):
                if (clr_idx % 16 == 15):
                    y += 8
                    x = 0
                else:
                    x += 8


        
        pygame.display.update()
        
        #time.sleep(0.01)
   
        
    pygame.quit()


    
run()