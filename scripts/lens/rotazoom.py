from PIL import Image
import hashlib
import math

PRINT_MAP_AS_ASM = 0  # otherwise write to DAT file
PRINT_TILEDATA_AS_ASM = 0  # otherwise write to DAT file

source_image_filename = "assets/lens/LENSPIC.png"  # This is the background picture (the monster)
source_image_width = 320
source_image_height = 200

# FIXME: these .bin files are currently not used!! (the data is copied as asm-text in the .s file)
tile_map_filename = "scripts/lens/ROTAZOOM-TILEMAP.DAT"
tile_pixel_data_filename = "scripts/lens/ROTAZOOM-TILEDATA.DAT"
# Note: we want to end up with a 32x32 tile map, so we first create a 16x16 tile map and replicate it four times!
# A full 32x32 tile map (256x256 pixels) is not possible, due to the amount of unique tiles that requires.
half_map_width = 16
half_map_height = 16


# creating a image object for the background
im = Image.open(source_image_filename)
px = im.load()
palette_bytes = im.getpalette()


# We first convert to 12-bit COLORS (this is used by the LENS part of the demo, so we need to preserve this!
colors_12bit = []
unique_12bit_colors = {}

byte_index = 0
new_color_index = 0
# IMPORTANT: we ONLY take the first 32 colors
nr_of_palette_bytes = 3*32
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
    
    # TODO: technically we dont know whether there are duplicate colors in the original palette.
    color_str = format(red, "02x") + format(green, "02x") + format(blue, "02x") 
    unique_12bit_colors[color_str] = new_color_index
    
    new_color_index += 1



def get_average_12bit_color(four_pixels):
    avg_r = 0
    avg_g = 0
    avg_b = 0
    
    # TODO: is there a better way to average 4 colors?
    for clr_idx in four_pixels:
        avg_r += palette_bytes[clr_idx*3]
        avg_g += palette_bytes[clr_idx*3+1]
        avg_b += palette_bytes[clr_idx*3+2]
        
    avg_r = int(avg_r/4) & 0xF0
    avg_g = int(avg_g/4) & 0xF0
    avg_b = int(avg_b/4) & 0xF0
    
    return (avg_r, avg_g, avg_b)
        
        
def get_new_or_existing_color(average_12bit_color):
    new_clr_idx = None
    
    red = average_12bit_color[0]
    green = average_12bit_color[1]
    blue = average_12bit_color[2]
    
    color_str = format(red, "02x") + format(green, "02x") + format(blue, "02x") 
    if color_str in unique_12bit_colors:
        new_clr_idx = unique_12bit_colors[color_str]
    else:
        new_clr_idx = len(colors_12bit)
        colors_12bit.append((red, green, blue))
        unique_12bit_colors[color_str] = new_clr_idx
    
    return new_clr_idx

# We need to crop the image to 256x256 and shrink/scale down to 128x128 (we do that in one go)

new_pixels = []
for y in range(128):
    new_pixels.append([])
    for x in range(128):
        new_pixels[y].append(None)


for x in range(128):
    for y in range(128):
        
        # The original picture is 320x200. We downscale from 256x256 to 128x128, so we are missing 56 horizontal lines (at the bottom). We make them black.
        source_x = 32 + x*2
        source_y = 0 + y*2
        
        new_clr_idx = None
        if (source_y < 0 or source_y >= 200):
            # TODO: We assume color 0 is black. Is this true?
            new_clr_idx = 0
        else:
            four_pixels = []
            four_pixels.append(px[source_x  , source_y  ])
            four_pixels.append(px[source_x+1, source_y  ])
            four_pixels.append(px[source_x  , source_y+1])
            four_pixels.append(px[source_x+1, source_y+1])
            
            average_12bit_color = get_average_12bit_color(four_pixels)
            
            new_clr_idx = get_new_or_existing_color(average_12bit_color)

        new_pixels[y][x] = new_clr_idx

    
''' Original rotation + position:

		d1=0;
		d2=0.00007654321;
		d3=0;
		scale=2;
		scalea=-0.01;
		frame=0;
        
        /* frame loop */
        
            x=70.0*sin(d1)-30;
			y=70.0*cos(d1)+60;
			d1-=.005;
			xa=-1024.0*sin(d2)*scale;
			ya=1024.0*cos(d2)*scale;
			x-=xa/16;
			y-=ya/16;
			d2+=d3;
			putw(x,fp);
			putw(y,fp);
			putw(xa,fp);
			putw(ya,fp);
			rotate(x,y,xa,ya);
			scale+=scalea;
			if(frame>25)
			{
				if(d3<.02) d3+=0.00005;
			}
			if(frame<270)
			{
				if(scale<.9)
				{
					if(scalea<1) scalea+=0.0001;
				}
			}
			else if(frame<400)
			{
				if(scalea>0.001) scalea-=0.0001;
			}
			else if(frame>1600)
			{
				if(scalea>-.1) scalea-=0.001;
			}
			else if(frame>1100)
			{
				a=frame-900; if(a>100) a=100;
				if(scalea<256) scalea+=0.000001*a;
			}    
'''


def generate_pos_and_rotation_frames():

    d1 = 0
    d2 = 0.00007654321
    d3 = 0
    scale = 2
    scalea = -0.01
    frame = 0
    
    pos_and_rotation_data  = "pos_and_rotation_data:\n  .byte "
    
    first_number_added = False
    for frame in range(2000):
    
        x = 70.0 * math.sin(d1) - 30
        y = 70.0 * math.cos(d1) + 60
        d1 -= 0.005
        xa = -1024.0 * math.sin(d2) * scale
        ya = 1024.0 * math.cos(d2) * scale
        x -= xa/16
        y -= ya/16
        d2 += d3
        
        #putw(x,fp);
        #putw(y,fp);
        #putw(xa,fp);
        #putw(ya,fp);
        #rotate(x,y,xa,ya);
        
        # IMPORTANT: y has to be NEGATED!
        
        print('frame: '+str(frame)+' x: '+str(x)+' y: '+str(y)+' xa: '+str(xa)+' ya: '+str(ya)+' sc: '+str(scale))

        comma = ", "
        if (not first_number_added):
            comma = ""
            first_number_added = True
        
        # == cosine_rotate is +ya / 8 ==
        # == sine_rotate is   -xa / 8 ==
        # == x_position is     +x / 2 ==
        # == y_position is     +y / 2 ==
        
        cosine_rotate = int(ya / 8)
        sine_rotate = int(-xa / 8)
        x_sub_position = int(x*256 / 2)
        y_sub_position = int(y*256 / 2)
        x_position = int(x / 2)
        y_position = int(y / 2)
        
        if cosine_rotate < 0:
            cosine_rotate = cosine_rotate+256*256
        if sine_rotate < 0:
            sine_rotate = sine_rotate+256*256
        if x_position < 0:
            x_position = x_position+256*256
            x_sub_position = x_sub_position+256*256*256
        if y_position < 0:
            y_position = y_position+256*256
            y_sub_position = y_sub_position+256*256*256
        
        pos_and_rotation_data += comma + str(cosine_rotate % 256)
        pos_and_rotation_data += ", " + str(cosine_rotate // 256)
        
        pos_and_rotation_data += ", " + str(sine_rotate % 256)
        pos_and_rotation_data += ", " + str(sine_rotate // 256)
        
        pos_and_rotation_data += ", " + str(x_sub_position % 256)
        pos_and_rotation_data += ", " + str(x_position % 256)
        pos_and_rotation_data += ", " + str(x_position // 256)
        
        pos_and_rotation_data += ", " + str(y_sub_position % 256)
        pos_and_rotation_data += ", " + str(y_position % 256)
        pos_and_rotation_data += ", " + str(y_position // 256)
        
        if (frame % 32 == 31):
            pos_and_rotation_data += "\n  .byte "
            first_number_added = False
        
        scale += scalea

        if (frame > 25):
            if(d3 < 0.02):
                d3 += 0.00005
                
        if (frame < 270):
            if (scale < 0.9):
                if (scalea<1):
                    scalea += 0.0001
        elif (frame < 400):
            if (scalea > 0.001):
                scalea -= 0.0001
        elif (frame > 1600):
            if (scalea > -0.1):
                scalea -= 0.001
        elif (frame > 1100): 
            a = frame - 900
            if (a > 100):
                a = 100
            if(scalea < 256):
                scalea += 0.000001 * a


    print(pos_and_rotation_data)


# FIXME: we need to store the output into a FILE!
# FIXME: we need to store the output into a FILE!
# FIXME: we need to store the output into a FILE!
generate_pos_and_rotation_frames()


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

for tile_y in range(half_map_height):
    tile_map.append([])
    for tile_x in range(half_map_width):
        tile_map[tile_y].append([])
        tile_pixels_as_string = ""
        tile_pixel_data = []
        for y_in_tile in range(8):
            for x_in_tile in range(8):
                new_pixel_color = new_pixels[tile_y*8+y_in_tile][tile_x*8+x_in_tile]
                tile_pixels_as_string += str(new_pixel_color)
                tile_pixel_data.append(new_pixel_color)
        if (tile_pixels_as_string in unique_tiles):
            tile_map[tile_y][tile_x] = unique_tiles.get(tile_pixels_as_string)
        else:
            unique_tiles[tile_pixels_as_string] = tile_index
            tiles_pixel_data.append(tile_pixel_data)
            tile_map[tile_y][tile_x] = tile_index
            tile_index += 1


tilemap_asm_string = ""
tile_map_flat = []
for tile_y in range(half_map_height):
    tilemap_asm_string += "  .byte "
    for tile_x in range(half_map_width):
        tile_index = tile_map[tile_y][tile_x]
        tile_map_flat.append(tile_index)
        tilemap_asm_string += "$" + format(tile_index,"02x") + ", "
    for tile_x in range(half_map_width):
        tile_index = tile_map[tile_y][tile_x]
        tile_map_flat.append(tile_index)
        tilemap_asm_string += "$" + format(tile_index,"02x") + ", "
    tilemap_asm_string += "\n"
for tile_y in range(half_map_height):
    tilemap_asm_string += "  .byte "
    for tile_x in range(half_map_width):
        tile_index = tile_map[tile_y][tile_x]
        tile_map_flat.append(tile_index)
        tilemap_asm_string += "$" + format(tile_index,"02x") + ", "
    for tile_x in range(half_map_width):
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
