from PIL import Image
from PIL import Image
import pygame
import hashlib
import math

PRINT_MAP_AS_ASM = False  # otherwise write to DAT file
PRINT_TILEDATA_AS_ASM = False  # otherwise write to DAT file
SHOW_TILE_MAP = False

source_image_filename = "assets/bounce/ICEKNGDM_320x200.png"
source_image_width = 320
source_image_height = 200
source_left_padding = 70  # on the left of the source image there is a black 'padding' columns, we should exclude this


tile_map_filename = "scripts/bounce/BOUNCE-TILEMAP.DAT"
tile_pixel_data_filename = "scripts/bounce/BOUNCE-TILEDATA.DAT"
# FIXME:
# pos_and_bend_filename = "scripts/bounce/BOUNCE-POS-BEND.DAT"

# We set the affine helper to a 32x32 map. 
map_width = 32
map_height = 32
content_map_width = 23 # There are 23 8x8 tiles with actual content, the 24th contains a white line at the left, the rest is black.
content_map_height = 25

# FIXME: hardcoded indexes! (works for now)
BLACK = 0
WHITE = 14

# creating a image object for the background
im = Image.open(source_image_filename)
# TODO: is this correct?
im = im.convert('P', palette=Image.ADAPTIVE, colors=256)
px = im.load()
palette_bytes = im.getpalette()


# We first convert to 12-bit COLORS (this is used by the BOUNCE part of the demo, so we need to preserve this!
colors_12bit = []

byte_index = 0


# IMPORTANT: we ONLY take the first 32 colors
# FIXME!?
# FIXME!?
# FIXME!?
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


tile_index = 0
unique_tiles = {}
tile_map = []
tiles_pixel_data = []

# We create a map of 32x32. 
# Every 8 rows the tile_indexes start at 0 again: in the asm we set the 'FX Tile Base Address' to a new series of tile data
# Each row of tiles contains 23 unique tiles (tile indexes 2-24, 25-47, 48-60, etc) + 1 non-unique tile (tile index 1, which has a border on the left) + 8 black tiles (tile index 0)
#   After 8 rows the tile_index is reset to 2 again
#   for the FOUR tile_pixel_data's, each time a 0 and 1 tile is added initially
#   The FOURTH tile_pixel_data contains only 1 row (3*8 rows + 1 row = 25 rows = 200 pixels high)
# The rest of the 32x32 map is filled with 0's

# Adding the black tile data
black_tile_pixel_data = []
tile_pixels_as_string = ""
for y_in_tile in range(8):
    for x_in_tile in range(8):
        pixel_color = 0 # BLACK
        tile_pixels_as_string += str(pixel_color)
        black_tile_pixel_data.append(pixel_color)
        
tiles_pixel_data.append(black_tile_pixel_data)
unique_tiles[tile_pixels_as_string] = tile_index
tile_index += 1

# Adding the black tile with white border data
border_tile_pixel_data = []
tile_pixels_as_string = ""
for y_in_tile in range(8):
    for x_in_tile in range(8):
        if (x_in_tile == 0):
            pixel_color = WHITE
        else:
            pixel_color = BLACK
        tile_pixels_as_string += str(pixel_color)
        border_tile_pixel_data.append(pixel_color)
        
tiles_pixel_data.append(border_tile_pixel_data)
unique_tiles[tile_pixels_as_string] = tile_index
tile_index += 1

for tile_y in range(content_map_height):
    tile_map.append([])
    for tile_x in range(content_map_width):
        tile_map[tile_y].append([])
        tile_pixels_as_string = ""
        tile_pixel_data = []
        for y_in_tile in range(8):
            for x_in_tile in range(8):
                pixel_color = px[source_left_padding + tile_x*8+x_in_tile, tile_y*8+y_in_tile]
                tile_pixels_as_string += str(pixel_color)
                tile_pixel_data.append(pixel_color)
        if (tile_pixels_as_string in unique_tiles):
            tile_map[tile_y][tile_x] = unique_tiles.get(tile_pixels_as_string)
        else:
            unique_tiles[tile_pixels_as_string] = tile_index
            tiles_pixel_data.append(tile_pixel_data)
            tile_map[tile_y][tile_x] = tile_index
            tile_index += 1
            
    # We add one tile to the row with left border
    tile_map[tile_y].append([])
    tile_map[tile_y][content_map_width] = 1  # tile index of the left-border tile
    
    # We fill the row with black tiles
    for tile_x in range(content_map_width+1, map_width):
        tile_map[tile_y].append([])
        tile_map[tile_y][tile_x] = 0  # tile index of the black tile

    if (tile_y % 8 == 7):
        # At the last row of each 8-rows we need to do the following:
        
        # We need to add 6 dummy tiles_pixel_data to fill up to % 2048 bytes
        tiles_pixel_data.append(black_tile_pixel_data)
        tiles_pixel_data.append(black_tile_pixel_data)
        tiles_pixel_data.append(black_tile_pixel_data)
        tiles_pixel_data.append(black_tile_pixel_data)
        tiles_pixel_data.append(black_tile_pixel_data)
        tiles_pixel_data.append(black_tile_pixel_data)
        
        # We add the black and border tile to the tiles_pixel_data
        tiles_pixel_data.append(black_tile_pixel_data)
        tiles_pixel_data.append(border_tile_pixel_data)
        # We reset tile_index to 2
        tile_index = 2


for tile_y in range(content_map_height, map_height):
    tile_map.append([])
    for tile_x in range(map_width):
        tile_map[tile_y].append([])
        tile_map[tile_y][tile_x] = 0  # tile index of the black tile


tilemap_asm_string = ""
tile_map_flat = []
for tile_y in range(map_height):
    tilemap_asm_string += "  .byte "
    for tile_x in range(map_width):
        tile_index = tile_map[tile_y][tile_x]
        tile_map_flat.append(tile_index)
        tilemap_asm_string += "$" + format(tile_index,"02x") + ", "
    tilemap_asm_string += "\n"

    
if (PRINT_MAP_AS_ASM):
    # Printing out asm for tilemap:
    print(tilemap_asm_string)
else:    
    tableFile = open(tile_map_filename, "wb")
    tableFile.write(bytearray(tile_map_flat))
    tableFile.close()
    print("tile map written to file: " + tile_map_filename)

tiles_pixel_asm_string = ""
tile_pixel_data_flat = []
for tile_pixel_data in tiles_pixel_data:
    tiles_pixel_asm_string += "  .byte "
    for tile_pixel in tile_pixel_data:
        tile_pixel_data_flat.append(tile_pixel)
        tiles_pixel_asm_string += "$" + format(tile_pixel,"02x") + ", "
    tiles_pixel_asm_string += "\n"

if (PRINT_TILEDATA_AS_ASM):
    # Printing out tile data:
    print(tiles_pixel_asm_string)
else:
    tableFile = open(tile_pixel_data_filename, "wb")
    tableFile.write(bytearray(tile_pixel_data_flat))
    tableFile.close()
    print("tile data written to file: " + tile_pixel_data_filename)

print("nr of unique tiles: " + str(len(unique_tiles.keys())))



'''
    // Original calculation of y1 and y2 (per frame)
    
    // Scroll
a=64; y=400*64;
while(y>0)
{
y-=a;
a+=6;
if(y<0) y=0;
scrolly(y/64);
dis_waitb();
}

    // Bounce
frame=0;
ysz=400*16; ysza=-460/6;
y=0;
y1=0; y1a=500;
y2=399*16; y2a=500;
mika=1;
for(frame=0;frame<200;frame++)
{
if(!halt)
{
y1+=y1a;
y2+=y2a;

y2a+=16;
if(y2>400*16)
{
y2-=y2a;
y2a=-y2a*mika/8;
if(mika<4) mika+=3;
}

y1a+=16;

la=a;
a=(y2-y1)-400*16;
if((a&0x8000)^(la&0x8000))
{
y1a=y1a*7/8;
}
y1a+=a/8;
y2a-=a/8;
}

if(frame>90) 
{
if(y2>=399*16) 
{
y2=400*16;
halt=1;
}
else y2a=8;
y1=y2-400*16;
}

framey1[frame]=y1;
framey2[frame]=y2;
}
for(a=0;a<800;a++)
{
b=a/4;
c=a&3;
d=3-c;
framey1t[a]=(framey1[b]*d+framey1[b+1]*c)/3;
framey2t[a]=(framey2[b]*d+framey2[b+1]*c)/3;
}

'''

def generate_frames ():

    # ===== Scrolling down straight (no bending) =====

    framey1_scroll = []
    framey2_scroll = []

    # We assume the initial frame is just above the screen
    framey1_scroll.append(-400*16)
    framey2_scroll.append(0)
    
    a = 64
    y = 400 * 64
    while(y > 0):
        y -= a
        a += 6
        if(y < 0):
            y = 0
        
        y1 = - y/4
        y2 = y1 + 400*16
        
        framey1_scroll.append(y1)
        framey2_scroll.append(y2)
            
    #print(framey1_scroll)
    #print(framey2_scroll)
            

    # ===== Bouncing a few times =====

    ysz = 400*16
    ysza = -460/6

    y1 = 0
    y1a = 500

    y2 = 399*16
    y2a = 500

    mika = 1
    halt = False

    # FIXME: is this correct??
    a = 200

    framey1 = []
    framey2 = []
    for frame in range(200):
        framey1.append(None)
        framey2.append(None)

        if(not halt):
            y1 += y1a
            y2 += y2a

            y2a += 16
            if(y2 > 400*16):
                y2 -= y2a
                y2a = -y2a * mika/8
                if(mika < 4):
                    mika += 3
            y1a += 16
            
            la = int(a)
            a = int((y2-y1) - 400*16)
            if((a&0x8000)^(la&0x8000)):
                y1a = y1a * 7/8
            y1a += a/8
            y2a -= a/8
        
        if(frame > 90):
            if(y2 >= 399*16):
                y2 = 400*16
                halt = True
            else:
                y2a = 8
                
            y1 = y2 - 400*16

        framey1[frame] = y1
        framey2[frame] = y2

    # FIXME: adding a 201th entry into the framey1 and framey2 array!
    framey1.append(0)
    framey2.append(6400)

    #print(framey1)
    #print(framey2)
    
    framey1_bounce = []
    framey2_bounce = []
    for a in range(800):
        framey1_bounce.append(None)
        framey2_bounce.append(None)
        
        b = int(a/4)
        c = int(a&3)
        d = int(3-c)
        
        framey1_bounce[a] = (framey1[b]*d + framey1[b+1]*c) / 3
        framey2_bounce[a] = (framey2[b]*d + framey2[b+1]*c) / 3


    #print(framey1_bounce)
    #print(framey2_bounce)
    
    total_framey1 = framey1_scroll + framey1_bounce
    total_framey2 = framey2_scroll + framey2_bounce

    #print(total_framey1)
    #print(total_framey2)
    
    total_frames = []
    for frame_nr in  range(len(total_framey1)):
        frame_info = {
            'y1' : total_framey1[frame_nr],
            'y2' : total_framey2[frame_nr],
        }
        total_frames.append(frame_info)

    return total_frames

total_frames = generate_frames()
#print(total_frames)

if (SHOW_TILE_MAP):
    screen_width = map_width*8
    screen_height = map_height*8
    scale = 3
else: 
    screen_width = 320
    screen_height = 240
    scale = 2

background_color = (0,0,0)

pygame.init()

pygame.display.set_caption('X16 2R Bounce/tilemap test')
screen = pygame.display.set_mode((screen_width*scale, screen_height*scale))
clock = pygame.time.Clock()

def run():

    running = True
    
    frame_nr = 0
    
    screen.fill(background_color)
    
    if (SHOW_TILE_MAP):
        for tile_y in range(map_height):
            for tile_x in range(map_width):
            
                sub_map_index = tile_y // 8
                
                tile_index = tile_map[tile_y][tile_x]
                tile_data = tiles_pixel_data[sub_map_index*192+tile_index]
                
                for y_in_tile in range(8):
                    for x_in_tile in range(8):
                        clr_idx = tile_data[y_in_tile*8+x_in_tile]
                        if clr_idx != 0:
                            pixel_color = colors_12bit[tile_data[y_in_tile*8+x_in_tile]]
                            
                            x_screen = tile_x*8 + x_in_tile
                            y_screen = tile_y*8 + y_in_tile
                            
                            pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale, y_screen*scale, scale, scale))
    
    frame_nr = 0
    do_animate = False
    while running:
        # TODO: We might want to set this to max?
        clock.tick(60)

        screen.fill(background_color)
        
        for event in pygame.event.get():

            if event.type == pygame.QUIT: 
                running = False

            if event.type == pygame.KEYDOWN:
                    
                #if event.key == pygame.K_LEFT:
                if event.key == pygame.K_RIGHT:
                    do_animate = True
                #if event.key == pygame.K_COMMA:
                #if event.key == pygame.K_PERIOD:
                #if event.key == pygame.K_UP:
                #if event.key == pygame.K_DOWN:
                    
            #if event.type == pygame.MOUSEMOTION: 
                # newrect.center = event.pos
        
        if (not do_animate):
            continue
            
        frame_info = total_frames[frame_nr]
        
        if (frame_nr < len(total_frames)-1):
            frame_nr += 1
        
        
        pixel_color = (0xFF, 0xFF, 0x00)
        
        top_border = 20
        left_border = 70
        
        y1 = frame_info['y1']/16
        y2 = frame_info['y2']/16
        
        x_start = left_border
        x_width = 184 # approx!
        y_start = y1 / 2
        y_end = y2 / 2
        y_height = y_end - y_start
        
        xsc = (400-(y2-y1))/8
            
        # pygame.draw.rect(screen, pixel_color, pygame.Rect(x_start*scale, (y_start + top_border)*scale, x_width*scale, y_height*scale), 1*scale)
        for y_in_picture in range(int(y_height)):
            
            y = y_start + y_in_picture
            
            # Only side borders:
            #pygame.draw.rect(screen, pixel_color, pygame.Rect(x_start*scale, (y + top_border)*scale, scale, scale), 1*scale)
            #pygame.draw.rect(screen, pixel_color, pygame.Rect((x_start+x_width)*scale, (y + top_border)*scale, scale, scale), 1*scale)
            
            # Filled:
            
            b = y_in_picture / y_height
            # FIXME: +0.5?
            a = (math.sin(b*math.pi)*xsc)
            # FIXME: *even* number of pixels? a&=~1 ?

            row_width = x_width + a*2
            row_start = x_start - a
            
            pygame.draw.rect(screen, pixel_color, pygame.Rect(row_start*scale, (y + top_border)*scale, row_width*scale, scale), 1*scale)
            
            
        
        pygame.display.update()
        
        #time.sleep(0.01)
   
        
    pygame.quit()


    
run()
