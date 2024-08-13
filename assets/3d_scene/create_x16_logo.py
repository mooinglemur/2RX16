# To install pygame: pip install pygame      (my version: pygame-2.1.2)
import pygame
import math
import time

background_color = (100,0,100)

scale = 2
screen_width = 320*scale
screen_height = 240*scale

white_color = (200,200,200)
black_color = (20,20,20)
blue_color = (20,20,200)
red_color = (200,20,20)
green_color = (20,200,20)
yellow_color = (200,200,20)
purple_color = (200,0,200)
orange_color = (200,100,0)

color_by_index = [ black_color, white_color, blue_color, red_color, green_color, yellow_color, purple_color, orange_color ]

all_colors = []


pygame.init()

pygame.display.set_caption('X16 generate butterfly triangles')
screen = pygame.display.set_mode((screen_width, screen_height))
clock = pygame.time.Clock()


def run():

    screen.fill(background_color)

    '''
    colors_hex = [
        '#cd9ac6', # 16 : violet
        '#7581c0', # 17 : violet/blue
        '#4392cd', # 18 : blue
        '#88cff0', # 19 : light blue
        '#5fcabe', # 20 : green/blue
        '#36c082', # 21 : green (middle)
        '#a2c651', # 22 : green/yellow
        '#ebcc57', # 23 : yellow
        '#fa9d56', # 24 : orange
        '#f5544c', # 25 : red
    ]

    # Note: we dont want to touch the first 16 colors, so we start at color index 16
    color_index = 16
    for color_hex in colors_hex:
        color_string_raw = color_hex.split('#',1)[1]
        # We only take the higher nibble of each color byte
        color_string = color_string_raw[0] + color_string_raw[2] + color_string_raw[4]
        
        for color_sub_index in range(16):
            red = int(int('0x'+color_string[0], 0)*16 * (color_sub_index/15))
            green = int(int('0x'+color_string[1], 0)*16 * (color_sub_index/15))
            blue = int(int('0x'+color_string[2], 0)*16 * (color_sub_index/15))
            
            color = ( red, green, blue)
            
            color_data = {"color_str" : color_string, "index" : color_index, "color": color}
            all_colors.append(color_data)
            #clr_index = color_data["index"]
            #all_colors_by_str[color_string] = color_data
            
            color_index += 1
        
        
    # print(all_colors)
    '''

    # These are taken from x16_logo_measurements.png
    base_points = [
        [   0,   0 ],  # 0
        [  40, 135 ],  # 1
        [ 159, 135 ],  # 2
        [ 128, 159 ],  # 3
        [ 128, 192 ],  # 4
        [  55, 216 ],  # 5
        [ 159, 216 ],  # 6
        [  32, 326 ]   # 7
    ]
    
    points = []
    
    '''
    # 0
    points.append({ "x" : base_points[0][0], "y" : base_points[0][1], "z" : 0 })
    points.append({ "x" : (base_points[1][0] - base_points[0][0]) * 1/4, "y" : (base_points[1][1] - base_points[0][1]) * 1/4, "z" : 0 })
    points.append({ "x" : (base_points[2][0] - base_points[0][0]) * 1/4, "y" : (base_points[2][1] - base_points[0][1]) * 1/4, "z" : 0 })
    points.append({ "x" : (base_points[1][0] - base_points[0][0]) * 2/4, "y" : (base_points[1][1] - base_points[0][1]) * 2/4, "z" : 0 })
    points.append({ "x" : (base_points[2][0] - base_points[0][0]) * 2/4, "y" : (base_points[2][1] - base_points[0][1]) * 2/4, "z" : 0 })
    points.append({ "x" : (base_points[1][0] - base_points[0][0]) * 3/4, "y" : (base_points[1][1] - base_points[0][1]) * 3/4, "z" : 0 })
    points.append({ "x" : (base_points[2][0] - base_points[0][0]) * 3/4, "y" : (base_points[2][1] - base_points[0][1]) * 3/4, "z" : 0 })
    points.append({ "x" : (base_points[1][0] - base_points[0][0]) * 4/4, "y" : (base_points[1][1] - base_points[0][1]) * 4/4, "z" : 0 })
    points.append({ "x" : (base_points[2][0] - base_points[0][0]) * 4/4, "y" : (base_points[2][1] - base_points[0][1]) * 4/4, "z" : 0 })
    # 9
    points.append({ "x" : base_points[3][0], "y" : base_points[3][1], "z" : 0 })
    points.append({ "x" : base_points[2][0], "y" : base_points[3][1], "z" : 0 })
    # 11
    points.append({ "x" : base_points[4][0], "y" : base_points[4][1], "z" : 0 })
    points.append({ "x" : base_points[2][0], "y" : base_points[4][1], "z" : 0 })
    # 13
    points.append({ "x" : base_points[5][0], "y" : base_points[5][1], "z" : 0 })
    points.append({ "x" : base_points[6][0], "y" : base_points[6][1], "z" : 0 })
    # 15
    points.append({ "x" : base_points[5][0] + (base_points[7][0] - base_points[5][0]) * 1/3, "y" : base_points[5][1] + (base_points[7][1] - base_points[5][1]) * 1/3, "z" : 0 })
    points.append({ "x" : base_points[6][0] + (base_points[7][0] - base_points[6][0]) * 1/3, "y" : base_points[6][1] + (base_points[7][1] - base_points[6][1]) * 1/3, "z" : 0 })
    # 17
    points.append({ "x" : base_points[5][0] + (base_points[7][0] - base_points[5][0]) * 2/3, "y" : base_points[5][1] + (base_points[7][1] - base_points[5][1]) * 2/3, "z" : 0 })
    points.append({ "x" : base_points[6][0] + (base_points[7][0] - base_points[6][0]) * 2/3, "y" : base_points[6][1] + (base_points[7][1] - base_points[6][1]) * 2/3, "z" : 0 })
    # 19
    points.append({ "x" : base_points[7][0], "y" : base_points[7][1], "z" : 0 })
    '''
    
    points.append({ "x" : base_points[0][0], "y" : base_points[0][1], "z" : 0 })
    points.append({ "x" : base_points[1][0], "y" : base_points[1][1], "z" : 0 })
    points.append({ "x" : base_points[2][0], "y" : base_points[2][1], "z" : 0 })
    points.append({ "x" : base_points[3][0], "y" : base_points[3][1], "z" : 0 })
    points.append({ "x" : base_points[4][0], "y" : base_points[4][1], "z" : 0 })
    points.append({ "x" : base_points[5][0], "y" : base_points[5][1], "z" : 0 })
    points.append({ "x" : base_points[6][0], "y" : base_points[6][1], "z" : 0 })
    points.append({ "x" : base_points[7][0], "y" : base_points[7][1], "z" : 0 })
    
    # FIXME: extrude these points!
    
    
    
    nr_of_points_in_one_wing = len(points)

    # Translate origin
    translate_x = - base_points[2][0] - 18 # the full width + some margin between the wings
    translate_y = - base_points[7][1] / 2 # half of the full height
    translate_z = 0
    for point_index, point in enumerate(points):
        point["x"] += translate_x
        point["y"] += translate_y
        point["z"] += translate_z
    
    # We need the points to be smaller in the engine, so we divide by
    scale_down = 47
    for point_index, point in enumerate(points):
        point["x"] /= scale_down
        point["y"] /= scale_down
        point["z"] /= scale_down
        
    # We duplicate all points to be used for the second wing
    new_points = []
    for point_index, point in enumerate(points):
        new_point = point.copy()
        new_point["x"] = -point["x"]
        new_points.append(new_point)
        
    points = points + new_points
    
    # print(points)
    
    '''
    triangles_raw_one_side = [
        # note that index 3 = color index / 16
        [ 1,  0,  2,   1],
        [ 1,  2,  3,   2],
        [ 3,  2,  4,   2],
        [ 3,  4,  5,   3],
        [ 5,  4,  6,   3],
        [ 5,  6,  7,   4],
        [ 7,  6,  8,   4],
        [ 7,  8,  9,   5],
        [ 9,  8, 10,   5],
        [ 9, 10, 11,   6],
        [11, 10, 12,   6],
        [11, 12, 13,   7],
        [13, 12, 14,   7],
        [13, 14, 15,   8],
        [15, 14, 16,   8],
        [15, 16, 17,   9],
        [17, 16, 18,   9],
        [17, 18, 19,   10],
    ]
    '''

    triangles_raw_one_side = [
        [ 1,  0,  2,   1],
        [ 1,  2,  3,   2],
        [ 3,  2,  6,   3],
        [ 4,  3,  6,   4],
        [ 5,  4,  6,   5],
        [ 5,  6,  7,   6],
    ]
    
    triangles_raw = []
    for triangle_raw in triangles_raw_one_side:
        triangles_raw.append(triangle_raw)
        
    for triangle_raw in triangles_raw_one_side:
        # Adding the triangle on the other side (by changing the order of the points)
        triangles_raw.append([triangle_raw[0], triangle_raw[2], triangle_raw[1], triangle_raw[3]]) # note that triangle_raw[3] = color index / 16

        
    # We duplicate all triangles to be used for the second wing
    new_triangles_raw = []
    for triangle_raw_index, triangle_raw in enumerate(triangles_raw):
        new_triangle_raw = triangle_raw.copy()
        new_triangle_raw[0] += nr_of_points_in_one_wing
        new_triangle_raw[1] += nr_of_points_in_one_wing
        new_triangle_raw[2] += nr_of_points_in_one_wing
        new_triangles_raw.append(new_triangle_raw)
        
    triangles_raw = triangles_raw + new_triangles_raw
    
    
    triangles = []
    color_index = 0
    for triangle_point_indexes in triangles_raw:
        pt1 = points[triangle_point_indexes[0]]
        pt2 = points[triangle_point_indexes[1]]
        pt3 = points[triangle_point_indexes[2]]
        color_index = triangle_point_indexes[3] * 16

        # Calculate the normal of the points using the CROSS PRODUCT
        
        a = { "x": pt3['x'] - pt1['x'], "y": pt3['y'] - pt1['y'], "z": pt3['z'] - pt1['z'] }
        b = { "x": pt2['x'] - pt1['x'], "y": pt2['y'] - pt1['y'], "z": pt2['z'] - pt1['z'] }
        
        cross_product = { 'x': a['y'] * b['z'] - a['z'] * b['y'], 
                          'y': a['z'] * b['x'] - a['x'] * b['z'], 
                          'z': a['x'] * b['y'] - a['y'] * b['x'] }
        
        # We NORMALIZE the result of the CROSS PRODUCT
        length_normal = math.sqrt((cross_product['x'] ** 2) + (cross_product['y'] ** 2) + (cross_product['z'] ** 2))
        
        if (length_normal == 0):
            print("ERROR: the length of the normal is 0!")
            print(pt1)
            print(pt2)
            print(pt3)
            #print(a)
            #print(b)
            #print(length_normal)
            # FIXME: what to do in this case??
            normal_vector = { 'x' : 0,
                              'y' : 0,
                              'z' : 0 }
        else:
            normal_vector = { 'x' : cross_product['x'] / length_normal,
                              'y' : cross_product['y'] / length_normal,
                              'z' : cross_product['z'] / length_normal }
        
        
        # FIXME: We should reverse the order of the points in order to create a clockwise winding
        triangle_points = [pt2, pt1, pt3, normal_vector ]
        triangles.append({ "triangle_points" : triangle_points, "clr" : color_index})
            
    # print(points)
    # print(triangles)
    
    
    for triangle_index in range(0, len(triangles)):
        tri = triangles[triangle_index]
        tri_points = tri["triangle_points"]
        triangle_color = color_by_index[(tri["clr"]//16) % 8] 
        
        sc = 1.2 * 30 # scale (approximating z ~ 8)
        
        pygame.draw.polygon(screen, triangle_color, [
            [tri_points[0]["x"]*sc+screen_width/2, tri_points[0]["y"]*sc+screen_height/2], 
            [tri_points[1]["x"]*sc+screen_width/2, tri_points[1]["y"]*sc+screen_height/2], 
            [tri_points[2]["x"]*sc+screen_width/2, tri_points[2]["y"]*sc+screen_height/2]], 0)
            
            # print('slope:' + str(x) + ":"+ str(y) + " -> " +str(slope_high) + "." + str(slope_low))
                
            #pygame.display.update()
            
        pygame.display.update()
            
    '''
    # Triangles
            
    print('NR_OF_TRIANGLES = ' + str(len(triangles)))
    print('triangle_3d_data:')
    print('    ; Note: the normal is a normal point relative to 0.0 (with a length of $100)')
    print('    ;       x1,    y1,    z1,    x2,    y2,    z2,    x3,    y3,    z3,    xn,    yn,    zn,   cl')
    
    for triangle in triangles:
        single_triangle_data = []
        for triangle_point in triangle["triangle_points"]:
            single_triangle_data.append(float_to_word(triangle_point["x"]))
            single_triangle_data.append(float_to_word(triangle_point["y"]))
            single_triangle_data.append(float_to_word(triangle_point["z"]))
        
        single_triangle_data.append(triangle["clr"])
        
        print('    .word ' + ', '.join('$' + str(format(x,"04X")).ljust(4, ' ') for x in single_triangle_data))
      

    # Palette
    
    paletteString = ""
    print('')
    print('palette_data:')
    # We want to colors 16-127 into "palette_data". We always skip the first 16 colors, so we need to put up to 128-16 = 112 colors here
    for color in all_colors[:112]:
        blue = color["color"][2]
        blue = blue & 0xF0
        blue = blue >> 4
        # print(hex(blue))
        
        green = color["color"][1]
        green = green & 0xF0
        # print(hex(green))
        # print(format(blue | green,"02x"))
        
        red = color["color"][0]
        red = red & 0xF0
        red = red >> 4
        # print(format(red,"02x"))
        paletteString += "    .byte "
        paletteString += "$" + format(green | blue,"02x") + ", "
        paletteString += "$" + format(red,"02x")
        paletteString += "  ; palette index " + str(color["index"])
        paletteString += "\n"
    paletteString += "end_of_palette_data:\n"
    print(paletteString)
    print('')
            
    paletteString = ""
    print('palette_data_128:')
    # We want to colors 128-255 into "palette_data_128". We always skip the first 128 colors here, so we need to put up to 256-128 = 128 colors here
    for color in all_colors[112:]:
        blue = color["color"][2]
        blue = blue & 0xF0
        blue = blue >> 4
        # print(hex(blue))
        
        green = color["color"][1]
        green = green & 0xF0
        # print(hex(green))
        # print(format(blue | green,"02x"))
        
        red = color["color"][0]
        red = red & 0xF0
        red = red >> 4
        # print(format(red,"02x"))
        paletteString += "    .byte "
        paletteString += "$" + format(green | blue,"02x") + ", "
        paletteString += "$" + format(red,"02x")
        paletteString += "  ; palette index " + str(color["index"])
        paletteString += "\n"
    paletteString += "end_of_palette_data_128:\n"
    print(paletteString)
    print('')
    '''
    
        
    running = True
    while running:
        # TODO: We might want to set this to max?
        clock.tick(60)
        
        for event in pygame.event.get():

            if event.type == pygame.QUIT: 
                running = False
                
        time.sleep(0.5)
    
        
    pygame.quit()

'''    
def float_to_word(float_value):
    if float_value >= 256:
        print("ERROR: float value is greater than 256!")
    if float_value <= -256:
        print("ERROR: float value is smaller than -256!")
    
    if float_value >= 0:
        value_int = int(float_value * 256)
    else:
        value_int = 256*256 + int(float_value * 256)
    
    return value_int
'''

run()