# To install pygame: pip install pygame      (my version: pygame-2.1.2)
from PIL import Image
import pygame
import math
import time
import random

DO_MOVE_LENS = True
DRAW_NEW_PALETTE = True

# TODO: we should *ALSO* use the LENS.png image! (with the 'glaring' of the lens)

lens_image_filename = "assets/lens/LENS.png"
lens_source_image_width = 320
lens_source_image_height = 200

source_image_filename = "assets/lens/LENSPIC.png"
source_image_width = 320
source_image_height = 200
bitmap_filename = "scripts/lens/LENS.BIN"
download1_code_filename = "scripts/lens/DOWNLOAD1.BIN"
download2_code_filename = "scripts/lens/DOWNLOAD2.BIN"
upload1_code_filename = "scripts/lens/UPLOAD1.BIN"
upload2_code_filename = "scripts/lens/UPLOAD2.BIN"

screen_width = 320
screen_height = 200

BITMAP_QUADRANT_BUFFER = 0x6000
lens_size = 100
lens_radius = lens_size/2
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

print(lens_palette_bytes)
#print(lens_px)

lens_colors = {}
for lens_source_y in range(lens_source_image_height):

    for lens_source_x in range(lens_source_image_width):

        lens_pixel_color_index = px[lens_source_x, lens_source_y]
        
        if (lens_pixel_color_index not in lens_colors):
            lens_colors[lens_pixel_color_index] = 0
            
        lens_colors[lens_pixel_color_index] += 1


#print(lens_colors)
#exit()
'''
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
'''


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
    
    new_blue = 256 - (256 - blue) // 2
    
    # colors 64 through 127 are going to be blue-ish
    blue_ish_color = (red, green, new_blue)
    colors_12bit[clr_idx+offset_blue_colors] = blue_ish_color
    
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


def init_lens():

    d = lens_zoom
    d2 = lens_zoom*lens_zoom
    r2 = lens_radius*lens_radius
    
    hlf = int(lens_radius)
    
    full = lens_radius*lens_radius + lens_radius*lens_radius

    for y in range(int(lens_size)):
        lens_offsets.append([])
        for x in range(int(lens_size)):
            lens_offsets[y].append(None)

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
            
    for y in range(hlf):
        y2 = y*y
        for x in range(hlf):
            x2 = x*x
            if ((x2 + y2) <= r2):
                # old way:
                # shift = d / math.sqrt(d2 - (x2 + y2 - r2))
                # x_shift = shift * x - x
                # y_shift = shift * y - y
                
                '''
                if (False):
                    distance_from_center = math.sqrt(x2 + y2) / lens_radius # distance from center: 0.0 -> 1.0
                    
                    # We now use the quadratic function to create the lens effect
                    #distance_from_center *= 0.9
                    #distance_from_center += 0.1
                    
                    # FIXME: this is ALMOST correct!
                    desired_distance_from_center = distance_from_center * distance_from_center
                    
                    if distance_from_center > 0:
                        ratio = desired_distance_from_center / distance_from_center
                    else:
                        ratio = 2
                        
                    if ratio < 0:
                        ratio = 0
                    
                    # FIXME: should we round UP or DOWN here?
                    #x_shift = int(ratio * x - x) 
                    #y_shift = int(ratio * y - y) 
                    x_shift = int(ratio * x - x + random.random()*1.5 - 0.75) 
                    y_shift = int(ratio * y - y + random.random()*1.5 - 0.75)
                '''
                
                if (True):
                    now = full - (x2 + y2)
                    if now < 1:
                        now = 1
                    new = 220 / (now**0.69)
                    fx = (random.random() - 0.5) * 1.2
                    fy = (random.random() - 0.5) * 1.2
                    px = int((x+fx)*new)
                    py = int((y+fy)*new)
                    
                    x_shift = px - x
                    y_shift = py - y
                    
                
                # Inside the lens the pixel gets shifted according to the quadrant it is in
                lens_offsets[ hlf   + y][ hlf   + x] = (  x_shift,  y_shift)
                lens_offsets[ hlf-1 - y][ hlf   + x] = (  x_shift, -y_shift)
                lens_offsets[ hlf   + y][ hlf-1 - x] = ( -x_shift,  y_shift)
                lens_offsets[ hlf-1 - y][ hlf-1 - x] = ( -x_shift, -y_shift)
            else:
                # Outside the lens there is no distortion/shift
                lens_offsets[ hlf   + y][ hlf   + x] = (None,None)
                lens_offsets[ hlf-1 - y][ hlf   + x] = (None,None)
                lens_offsets[ hlf   + y][ hlf-1 - x] = (None,None)
                lens_offsets[ hlf-1 - y][ hlf-1 - x] = (None,None)

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
#  - Free memory at address BITMAP_QUADRANT_BUFFER (lens_radius*lens_radius in size)
#
def generate_download_and_upload_code():
    download1_code = []
    download2_code = []
    upload1_code = []
    upload2_code = []

    download_code = download1_code
    upload_code = upload1_code
    
    hlf = int(lens_radius)

    for y in range(hlf):
        for x in range(hlf):
            (x_shift, y_shift) = lens_offsets[ hlf   + y][ hlf   + x]
            
            if x_shift is not None:
            
                # -- download --
                
                # We need to download a byte from VRAM into Fixed RAM

                # lda VERA_DATA1 ($9F24)  -> this loads a byte from VRAM
                download_code.append(0xAD)  # lda ....
                download_code.append(0x24)  # $24
                download_code.append(0x9F)  # $9F
                
                address_to_write_to = BITMAP_QUADRANT_BUFFER + y * hlf + x
                
                # sta $6... 
                download_code.append(0x8D)  # sta ....
                download_code.append(address_to_write_to % 256)  # low part of address
                download_code.append(address_to_write_to // 256)  # high part of address

                # -- upload --

                address_to_read_from = BITMAP_QUADRANT_BUFFER + (y+y_shift) * hlf + (x+x_shift)
                
                # lda $6....
                upload_code.append(0xAD)  # lda ....
                upload_code.append(address_to_read_from % 256)  # low part of address
                upload_code.append(address_to_read_from // 256)  # high part of address
                
                # sta VERA_DATA1 ($9F24)  -> this writes a byte to VRAM
                upload_code.append(0x8D)  # sta ....
                upload_code.append(0x24)  # $24
                upload_code.append(0x9F)  # $9F
                
            
            if (((x_shift is None) or x == hlf-1) and (y != hlf-1)):
            
                # We reached the end of this row, so we have to move to the next one (unless its the last row)
            
                # -- download --
                
                # lda #%00000010  (polygon mode = 1)
                download_code.append(0xA9)  # lda #..
                download_code.append(0x02)  # #%00000010  (polygon mode = 1)
                
                # sta VERA_CTRL ($9F29)
                download_code.append(0x8D)  # sta ....
                download_code.append(0x29)  # $29
                download_code.append(0x9F)  # $9F
                
                # lda VERA_DATA0 ($9F23)  -> this increments ADDR0 one pixel vertically
                download_code.append(0xAD)  # lda ....
                download_code.append(0x23)  # $23
                download_code.append(0x9F)  # $9F
                
                # lda VERA_DATA1 ($9F24)  -> this sets ADDR1 to DATA0 + x1 (note: x1 is 0)
                download_code.append(0xAD)  # lda ....
                download_code.append(0x24)  # $24
                download_code.append(0x9F)  # $9F
                
                # stz VERA_CTRL ($9F29)  (polygon mode = 0)
                download_code.append(0x9C)  # stz ....
                download_code.append(0x29)  # $29
                download_code.append(0x9F)  # $9F
                
                # -- upload --

                # lda VERA_DATA0 ($9F23)  -> this increments ADDR0 one pixel vertically
                upload_code.append(0xAD)  # lda ....
                upload_code.append(0x23)  # $23
                upload_code.append(0x9F)  # $9F
                
                # lda VERA_DATA1 ($9F24)  -> this sets ADDR1 to DATA0 + x1 (note: x1 is 0)
                upload_code.append(0xAD)  # lda ....
                upload_code.append(0x24)  # $24
                upload_code.append(0x9F)  # $9F

                # -- updload and download --
                
                # Note: dividing by 2.5 divides the two files in roughly equal size
                if (y == int(hlf/2.5)):
                    # We are halfway, we need to add an rts and continue in the other array
                    download_code.append(0x60)  # rts
                    download_code = download2_code
                    
                    upload_code.append(0x60)  # rts
                    upload_code = upload2_code
                
                # We break from the x-loop
                break
                
        if (y == hlf-1):
            # We are done, we need to add an rts
            download_code.append(0x60)  # rts
            upload_code.append(0x60)  # rts

    return (download1_code, download2_code, upload1_code, upload2_code)


pygame.init()

pygame.display.set_caption('X16 2R Lens test')
screen = pygame.display.set_mode((screen_width*2, screen_height*2))
clock = pygame.time.Clock()

init_lens()

(download1_code, download2_code, upload1_code, upload2_code) = generate_download_and_upload_code()

tableFile = open(download1_code_filename, "wb")
tableFile.write(bytearray(download1_code))
tableFile.close()
print("download code 1 written to file: " + download1_code_filename)

tableFile = open(download2_code_filename, "wb")
tableFile.write(bytearray(download2_code))
tableFile.close()
print("download code 2 written to file: " + download2_code_filename)

tableFile = open(upload1_code_filename, "wb")
tableFile.write(bytearray(upload1_code))
tableFile.close()
print("upload code 1 written to file: " + upload1_code_filename)

tableFile = open(upload2_code_filename, "wb")
tableFile.write(bytearray(upload2_code))
tableFile.close()
print("upload code 2 written to file: " + upload2_code_filename)

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



def run():

    running = True
    
    # FIXME: right now the position of the lens if at the TOP-LEFT, which in not convenient!
    
    lens_pos_x = 65
    lens_pos_y = -50
    
    lens_speed_x = 1
    lens_speed_y = 1
    
    frame_nr = 0
    first_bounce = True
    
    while running:
        # TODO: We might want to set this to max?
        clock.tick(60)
        
        if (DO_MOVE_LENS):
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
                
        frame_nr += 1    
        
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
                
        screen.fill(background_color)

        for source_y in range(source_image_height):
            for source_x in range(source_image_width):

                y_screen = source_y
                x_screen = source_x
                
                pixel_color = colors_12bit[px[source_x, source_y]]
                
                pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))

                
        for lens_y in range(int(lens_size)):
            for lens_x in range(int(lens_size)):
                
                (x_shift, y_shift) = lens_offsets[lens_y][lens_x]
                
                if (x_shift is None):
                    continue
                
                source_y = lens_pos_y - lens_radius + lens_y + y_shift
                source_x = lens_pos_x - lens_radius + lens_x + x_shift
                
                if (source_y < source_image_height):
                    pixel_color = colors_12bit[px[source_x, source_y] + offset_blue_colors]
                    
                    y_screen = lens_pos_y - lens_radius + lens_y
                    x_screen = lens_pos_x - lens_radius + lens_x
                    
                    pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))
                else:
                    # This is off screen, we do not draw
                    pass
                
                
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