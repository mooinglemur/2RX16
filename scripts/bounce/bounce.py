from PIL import Image
import pygame
import hashlib
import math

PRINT_MAP_AS_ASM = False  # otherwise write to DAT file
PRINT_TILEDATA_AS_ASM = False  # otherwise write to DAT file

source_image_filename = "assets/bounce/ICEKNGDM_320x200.png"
source_image_width = 320
source_image_height = 200

tile_map_filename = "scripts/bounce/BOUNCE-TILEMAP.DAT"
tile_pixel_data_filename = "scripts/bounce/BOUNCE-TILEDATA.DAT"
# FIXME:
# pos_and_rotate_filename = "scripts/bounce/BOUNCE-POS-ROTATE.DAT"

# Note: we want to end up with a 32x32 tile map, so we first create a 16x16 tile map and replicate it four times!
# A full 32x32 tile map (256x256 pixels) is not possible, due to the amount of unique tiles that requires.
# FIXME!
map_width = 32
map_height = 25


# creating a image object for the background
im = Image.open(source_image_filename)
# FIXME: is this correct?
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


for tile_y in range(map_height):
    tile_map.append([])
    for tile_x in range(map_width):
        tile_map[tile_y].append([])
        tile_pixels_as_string = ""
        tile_pixel_data = []
        for y_in_tile in range(8):
            for x_in_tile in range(8):
                pixel_color = px[tile_x*8+x_in_tile, tile_y*8+y_in_tile]
                tile_pixels_as_string += str(pixel_color)
                tile_pixel_data.append(pixel_color)
        if (tile_pixels_as_string in unique_tiles):
            tile_map[tile_y][tile_x] = unique_tiles.get(tile_pixels_as_string)
        else:
            unique_tiles[tile_pixels_as_string] = tile_index
            tiles_pixel_data.append(tile_pixel_data)
            tile_map[tile_y][tile_x] = tile_index
            tile_index += 1


'''
tilemap_asm_string = ""
tile_map_flat = []
for tile_y in range(map_height):
    tilemap_asm_string += "  .byte "
    for tile_x in range(map_width):
        tile_index = tile_map[tile_y][tile_x]
        tile_map_flat.append(tile_index)
        tilemap_asm_string += "$" + format(tile_index,"02x") + ", "
    for tile_x in range(map_width):
        tile_index = tile_map[tile_y][tile_x]
        tile_map_flat.append(tile_index)
        tilemap_asm_string += "$" + format(tile_index,"02x") + ", "
    tilemap_asm_string += "\n"
for tile_y in range(map_height):
    tilemap_asm_string += "  .byte "
    for tile_x in range(map_width):
        tile_index = tile_map[tile_y][tile_x]
        tile_map_flat.append(tile_index)
        tilemap_asm_string += "$" + format(tile_index,"02x") + ", "
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
'''

'''
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


screen_width = 320
screen_height = 200
scale = 3

background_color = (0,0,0)

pygame.init()

pygame.display.set_caption('X16 2R Bounce/tilemap test')
screen = pygame.display.set_mode((screen_width*scale, screen_height*scale))
clock = pygame.time.Clock()

def run():

    running = True
    
    frame_nr = 0
    
    screen.fill(background_color)
    
    '''
    for source_y in range(128):
        for source_x in range(128):

            y_screen = source_y
            x_screen = source_x
            
            pixel_color = colors_12bit[new_pixels[source_y][source_x]]
            
            pygame.draw.rect(screen, pixel_color, pygame.Rect(x_screen*scale*2, y_screen*scale*2, scale*2, scale*2))
    '''

    # black_tile_string = '0' * 64
    # empty_tile_index = unique_tiles[black_tile_string]

    for tile_y in range(map_height):
        for tile_x in range(map_width):
            
            tile_index = tile_map[tile_y][tile_x]
            tile_data = tiles_pixel_data[tile_index]
            
            '''
            if (tile_index != empty_tile_index):
                tile_bg_color = (0x33, 0x00, 0x33)
                pygame.draw.rect(screen, tile_bg_color, pygame.Rect(tile_x*8*scale, tile_y*8*scale, 8*scale, 8*scale))
            
            grid_color = (0x33, 0x33, 0x33)
            pygame.draw.rect(screen, grid_color, pygame.Rect(tile_x*8*scale, tile_y*8*scale, 8*scale, 8*scale), 1)
            '''
            
            for y_in_tile in range(8):
                for x_in_tile in range(8):
                    clr_idx = tile_data[y_in_tile*8+x_in_tile]
                    if clr_idx != 0:
                        pixel_color = colors_12bit[tile_data[y_in_tile*8+x_in_tile]]
                        
                        x_screen = tile_x*8 + x_in_tile
                        y_screen = tile_y*8 + y_in_tile
                        
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
            

        
        pygame.display.update()
        
        #time.sleep(0.01)
   
        
    pygame.quit()


    
run()
