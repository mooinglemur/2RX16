import os
import numpy as np
import sys
import copy
import json

scene_dir = 'assets/3d_scene/SCENE'
scene_name = 'U2E'
#scene_name = 'U2A'

def lsget (f, u2_bin, pos):
    value = None
    incr_pos = None
    
    if(f&3 == 0):
        value = None
        incr_pos = 0
    elif(f&3 == 1):
        # Signed byte value
        value = int.from_bytes(u2_bin[pos:pos+1], byteorder='little', signed=True)
        incr_pos = 1
    elif(f&3 == 2):
        # Signed word value
        value = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)
        incr_pos = 2
    elif(f&3 == 3):
        # Signed long value
        value = int.from_bytes(u2_bin[pos:pos+4], byteorder='little', signed=True)
        incr_pos = 4
    
    return (value, incr_pos)


def parse_animation_file(u2_bin, nr_of_objects):

    
    default_invisible_object = { 
        'visible' : False,
        'x' : 0, 
        'y' : 0, 
        'z' : 0, 
        'm' : [ 
            [ 0, 0, 0 ], 
            [ 0, 0, 0 ], 
            [ 0, 0, 0 ]
        ] 
    }
    
    
    # We need to keep track of the ORIGINAL matrices and xyz
    objects_in_u2_engine = {}
    for i in range(nr_of_objects):
        objects_in_u2_engine[i] = copy.deepcopy(default_invisible_object)

    # We also need to keep track of the OUTPUT object matrices and xyz's. We do this for each frame! (and only when something changes)
    objects_xyz_and_matrix_per_frame = {}
    
    
    pos = 0
    
    finished = False
    frame_nr = 1
    a = 0
    while(pos < len(u2_bin) and not finished):
    
        print('===============FRAME '+ str(frame_nr) + '=======================')
            
        objects_xyz_and_matrix_per_frame[frame_nr] = {}
        objects_xyz_and_matrix = objects_xyz_and_matrix_per_frame[frame_nr]
        
        if (True):
            # For frame 1 we set all objects to invisible
            if (frame_nr == 1):
                # Note: +1 because of the camera at index 0
                for i in range(nr_of_objects+1):
                    objects_xyz_and_matrix[i] = default_invisible_object
            
        onum = 0
        while(pos < len(u2_bin) and not finished):
            a = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
            #print('first byte: ' + hex(a))
            pos+=1
            
            if (a == 0xFF):
                a = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
                #print(hex(a))
                pos+=1
                
                if(a <= 0x7F):
# FIXME: this value does seem right! 0-65538 = 0-360?
                    half_fov = a << 8
                    half_fov = (a << 8) / 360
                    #print('half_fov: ' + str(half_fov))
                    #print('frame done')
                    break
                elif(a == 0xFF):
                    print('all frames done')
                    finished = True
                    continue
            
            
            if ((a&0xc0) == 0xc0):
                onum = ((a&0x3f)<<4)
                a = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
                #print(hex(a))
                pos+=1
            onum = (onum & 0xff0)|(a&0xf)
            
            #print("object number: " + str(onum))
            
            objects_xyz_and_matrix[onum] = {}
            
            if (a&0xc0 == 0x80):
                # object is *on*
                objects_in_u2_engine[onum]['visible'] = True
                #print("object is turned on")
                pass
            elif (a&0xc0 == 0x40):
                # object is *off*
                objects_in_u2_engine[onum]['visible'] = False
                #print("object is turned off")
                pass
            else:
                #print("object is neither turned on or off")
                pass
                
            objects_xyz_and_matrix[onum]['visible'] = objects_in_u2_engine[onum]['visible']
                
            pflag = 0
            if ((a&0x30) == 0x00):
                #print('no pflag for object')
                pass # nothing to do here (maybe just on/off setting of this object, but no change)
            elif ((a&0x30) == 0x10):
                byte_value = u2_bin[pos:pos+1]
                #print(byte_value)
                pos+=1
                pflag |= byte_value[0]
            elif ((a&0x30) == 0x20):
                double_byte_value = u2_bin[pos:pos+2]
                #print(double_byte_value)
                pos+=2
                pflag |= double_byte_value[0]
                pflag |= double_byte_value[1] << 8
            elif ((a&0x30) == 0x30):
                triple_byte_value = u2_bin[pos:pos+3]
                #print(triple_byte_value)
                pos+=3
                pflag |= triple_byte_value[0]
                pflag |= triple_byte_value[1] << 8
                pflag |= triple_byte_value[2] << 16
                
                
            #print('pflag: ' + str(hex(pflag)))

            delta = {
                'x' : None,
                'y' : None,
                'z' : None,
                'm' : [
                    [ None, None, None ],
                    [ None, None, None ],
                    [ None, None, None ] 
                ]
            }
            
            # TODO: by how MUCH do we have to divide here? /256?
# FIXME: we might USE THE ORIGINAL int values here, to increase PRECISION!            
            divider_pos = 256

            (x_delta, incr_pos) = lsget (pflag, u2_bin, pos)
            if incr_pos:
                pos += incr_pos
                delta['x'] = x_delta/divider_pos
            
            (y_delta, incr_pos) = lsget (pflag>>2, u2_bin, pos)
            if incr_pos:
                pos += incr_pos
                delta['y'] = y_delta/divider_pos
            
            (z_delta, incr_pos) = lsget (pflag>>4, u2_bin, pos)
            if incr_pos:
                pos += incr_pos
                delta['z'] = z_delta/divider_pos

# FIXME: we might USE THE ORIGINAL int values here, to increase PRECISION!            
            divider_matrix = 256*64
            
            if(pflag&0x40):
                # word matrix
                for b in range(9):
                    if (pflag&(0x80<<b)):
                        (m_delta, incr_pos) = lsget(2, u2_bin, pos)
                        delta['m'][b//3][b%3] = m_delta/divider_matrix
                        pos += incr_pos
                        
            else:
                # byte matrix
                for b in range(9):
                    if (pflag&(0x80<<b)):
                        (m_delta, incr_pos) = lsget(1, u2_bin, pos)
                        delta['m'][b//3][b%3] = m_delta/divider_matrix
                        pos += incr_pos
            
            object_xyz_or_m_has_changed = False
            if (onum in objects_in_u2_engine):
                if delta['x'] is not None:
                    objects_in_u2_engine[onum]['x'] += delta['x']
                    object_xyz_or_m_has_changed = True
                if delta['y'] is not None:
                    objects_in_u2_engine[onum]['y'] += delta['y']
                    object_xyz_or_m_has_changed = True
                if delta['z'] is not None:
                    objects_in_u2_engine[onum]['z'] += delta['z']
                    object_xyz_or_m_has_changed = True
                for b in range(9):
                    if (delta['m'][b%3][b//3] is not None):
                        objects_in_u2_engine[onum]['m'][b//3][b%3] += delta['m'][b%3][b//3]
                    object_xyz_or_m_has_changed = True
            else:
                print('ERROR: unkown object number! ' + str(onum))
                sys.exit()


            if (object_xyz_or_m_has_changed):
                objects_xyz_and_matrix[onum]['x'] = objects_in_u2_engine[onum]['x']
                objects_xyz_and_matrix[onum]['y'] = objects_in_u2_engine[onum]['y']
                objects_xyz_and_matrix[onum]['z'] = objects_in_u2_engine[onum]['z']
                objects_xyz_and_matrix[onum]['m'] = copy.deepcopy(objects_in_u2_engine[onum]['m'])
            

            #print('---')

        frame_nr += 1
            
    # FIXME: REMOVE!        
        #if (frame_nr > 22*30):
        #    break

    return objects_xyz_and_matrix_per_frame
    
    

def parse_object_file(u2_bin):

    u2_object = {
        'polygon_lists' : [],
    }

    pos = 0
    
    while(pos < len(u2_bin)):
        pos0 = pos
        pos += 8
        nr_of_bytes = int.from_bytes(u2_bin[pos0+4:pos0+8], byteorder='little')
        
        if (u2_bin[pos0:pos0+4] == b'VERS'):
            version = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
            #print('VERS: ' + str(version/256))
            # We dont really care about the version, so we dont keep it
        
        elif (u2_bin[pos0:pos0+4] == b'NAME'):
            # Note: a little dirty way to deal with NUL termination here...
            name = u2_bin[pos:pos+nr_of_bytes].decode("utf-8").split('\0')[0]
            name = name.strip('\"')
            print('NAME: ' + name)
            u2_object['name'] = name
        elif (u2_bin[pos0:pos0+4] == b'VERT'):
            nr_of_vertices = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
            pos += 2
            # Dummy word
            pos += 2
            
            vertices = []
            for vert_index in range(nr_of_vertices):
            
# FIXME: we might USE THE ORIGINAL int values here, to increase PRECISION!            
                # FIXME: by what do we have to divide this? -> if we compare the ship.obj with the city.obj (which we generate here) maybe 300-350?
                x = int.from_bytes(u2_bin[pos:pos+4], byteorder='little', signed=True)/256
                pos += 4
                y = int.from_bytes(u2_bin[pos:pos+4], byteorder='little', signed=True)/256
                pos += 4
                z = int.from_bytes(u2_bin[pos:pos+4], byteorder='little', signed=True)/256
                pos += 4
                normal_index = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)
                pos += 2
                # RESERVED not retrieved
                pos += 2
                
                # FIXME: HACK! For some reason the large ship in U2A ('Sippi') is about twice as wide as in the object files. So we just widen it here.
                if (u2_object['name'] == 'Sippi'):
                    x = x * 2
                
                vertex = { 'x' : x, 'y': y, 'z': z, 'normal_index': normal_index }
                vertices.append(vertex)
            
            #print('VERT: ' + str(nr_of_vertices))
            #print(vertices)
            u2_object['vertices'] = vertices
            
        elif (u2_bin[pos0:pos0+4] == b'NORM'):
            nr_of_normals = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
            pos += 2
            # FIXME: nnum1 is NOT extracted here!
            pos += 2
            
            normals = []
            for norm_index in range(nr_of_normals):
# FIXME: we might USE THE ORIGINAL int values here, to increase PRECISION!            
                x = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)/16384
                pos += 2
                y = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)/16384
                pos += 2
                z = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)/16384
                pos += 2
                # RESERVED not retrieved
                pos += 2
                
                # FIXME: We widen the ship 'Sippi' (see HACK above) but we dont adjust its normals...
                
                normal = { 'x' : x, 'y': y, 'z': z }
                normals.append(normal)
            
            #print('NORM: ' + str(nr_of_normals))
            #print(normals)
            u2_object['normals'] = normals
            
        elif (u2_bin[pos0:pos0+4] == b'POLY'):
        
            polygon_index = 0
            polygon_data_by_pos = {}
            
            end_of_section = pos + nr_of_bytes
            start_of_section = pos
            
            # Zero word
            pos += 2
            
            # FIXME: arbritary -4 here, to prevent going too far...
            while(pos < end_of_section-4):
                # FIXME: remember the POSITION this polygon START!
                start_polygon_data_pos = pos
                
                sides = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
                pos += 1
                flags = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
                pos += 1
                
                # FIXME: we probably want to extract the individual bits from this flag-byte!
                # flags for objects & faces (lower 8 bits in face flags are the side number) */
                    #define F_DEFAULT	0xf001	/* for objects only - all enabled, visible */
                    #define F_VISIBLE	0x0001	/* object visible */
                    #define F_FLIP		0x0100
                    #define F_2SIDE		0x0200
                    #define F_SHADE8	0x0400	/* only one shade can be selected at a time */
                    #define F_SHADE16	0x0800
                    #define F_SHADE32	0x0C00
                    #define F_GOURAUD	0x1000
                    #define F_TEXTURE	0x2000
                
                # FIXME: We might need to implement FLIPPING an object?
                
                nr_of_shades = None
                if (flags & 0x0C == 0x0C):
                    nr_of_shades = 32
                elif (flags & 0x08 == 0x08):
                    nr_of_shades = 16
                elif (flags & 0x04 == 0x04):
                    nr_of_shades = 8
                else:
                    print('WARNING: invalid nr of shades!')
                
                color_index = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
                pos += 1
                # RESERVED
                pos += 1

                normal_index = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)
                pos += 2
                
                vertex_indices = []
                for side_index in range(sides):
                    vertex_index = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)
                    pos += 2
                    vertex_indices.append(vertex_index)
                
                polygon_data = {
                    'sides' : sides,
                    'flags' : flags,
                    'color_index' : color_index,
                    'nr_of_shades' : nr_of_shades,
                    'normal_index' : normal_index,
                    'vertex_indices' : vertex_indices
                }
                
                #print('POLY: s:' + str(sides) + ' f:' + str(flags) + ' c:' + str(color_index)+ ' n:' + str(normal_index) + ' v:' + str(vertex_indices))
                #print(polygon_data)
                polygon_data_by_pos[start_polygon_data_pos-start_of_section] = polygon_data
                polygon_index += 1
                
            # TODO: do we really want to add this polygon datas to the object here?
            u2_object['polygon_data_by_pos'] = polygon_data_by_pos
            
            # print(polygon_data_by_pos)
            
            
        elif (u2_bin[pos0:pos0+3] == b'ORD'):
            #print('ORD')
            
            # Note: we are ignoring the 4th character after 'ORD' (which contains either a '0' or an 'E'). We dont really need it in Python.

            # This includes the last 0 (and THIS number)
            nr_of_words_in_list = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
            pos += 2
            
            # TODO: WHAT IS THIS???? -> a way to quickly sort polygons of an object given a certain camera position/angle, maybe?
            sort_polygon_for_this_list = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
            pos += 2
            
            polygon_pointers = []
            # Note: we remove 3 from nr_of_words_in_list: the last word (=0) and the first word and sort_polygon_for_this_list
            for polygon_index_in_polygon_list in range(nr_of_words_in_list-3):
                polygon_pointer = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)
                pos += 2
                polygon_pointers.append(polygon_pointer)
                
            polygon_list = {
                'sort_polygon_for_this_list' : sort_polygon_for_this_list,
                'polygon_pointers' : polygon_pointers,
            }
            
            # print(polygon_list)
            
            u2_object['polygon_lists'].append(polygon_list)
            
            
        pos = pos0 + nr_of_bytes + 8
    


    return u2_object
    

def parse_material_file(u2_material_binary):

    objects_and_material_info = {}
    
    u2_bin = u2_material_binary


    # At position 4 there is an index to the start of the object list
    pos = 4
    object_list_pos = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
    
    pos = object_list_pos
    nr_of_objects = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
    pos+=2
    
    objects_and_material_info['nr_of_objects'] = nr_of_objects
    
    object_file_indexes = []
    # Object index 0 is the camera, but this doesnt have a file index, so we set it to None
    object_file_indexes.append(None)
    object_index = 1 # Since we added the camera, we start at index 1
    while (object_index < nr_of_objects):
        object_file_index = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
        pos+=2
        object_file_indexes.append(object_file_index)
        object_index += 1
        
    objects_and_material_info['object_file_indexes'] = object_file_indexes
    
    # Read the palette (3 * 256 bytes: each byte contains 6-bits of R, G and B)
    pos = 16
    palette_colors = []
    for color_index in range(256):
        
        red = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
        pos += 1
        green = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
        pos += 1
        blue = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
        pos += 1

        # FIXME: should we convert the 6-bits to 4-bits here ALREADY? Or do we do this later?
        rgb_color = { 'r': red, 'g': green, 'b': blue }
        
        # FIXME: the last FOUR colors (252, 253, 254 and 255) are WHITE and BLACK! (see U2E.C)
        
        palette_colors.append(rgb_color)
    
    objects_and_material_info['palette_colors'] = palette_colors
    
    return objects_and_material_info


def generate_obj_text_for_u2_object(u2_object, vertex_index_start, mat_info):
    obj_text = ""
    
    obj_text += "o " + u2_object['name'] + "\n"
    for vertex in u2_object['vertices']:
        obj_text += "v "
        obj_text += str(vertex['x'])
        obj_text += " "
        obj_text += str(vertex['y'])
        obj_text += " "
        obj_text += str(vertex['z'])
        obj_text += "\n"
        
    previous_material_name = 'None'
    for data_pos in u2_object['polygon_data_by_pos']:
        polygon_data = u2_object['polygon_data_by_pos'][data_pos]
        
        color_index = polygon_data['color_index']
        nr_of_shades = polygon_data['nr_of_shades']
        
        material_name = None
        if (color_index in mat_info and nr_of_shades in mat_info[color_index]):
            material_name = mat_info[color_index][nr_of_shades]['name']
        else:
            print('WARNING: unknown combination of color_index and nr_of_shades!')
        
        if (material_name != previous_material_name):
            obj_text += "usemtl " 
            obj_text += material_name
            obj_text += "\n"
        
            previous_material_name = material_name
        
        #print(polygon_data)
        obj_text += "f "
        obj_text += ' '.join(str(vertex_index+vertex_index_start) for vertex_index in polygon_data['vertex_indices'])
        obj_text += "\n"
        
    nr_of_vertices = len(u2_object['vertices'])
    
    return (obj_text, nr_of_vertices)



def generate_obj_text_for_manual_object(u2_object, vertex_index_start):
    obj_text = ""
    
    obj_text += "o " + u2_object['name'] + "\n"
    for vertex_raw in u2_object['vertices_raw']:
        vertex_x = vertex_raw[0] / 256
        vertex_y = vertex_raw[1] / 256
        if (u2_object['type'] == 'ground'):
# FIXME: make this a value per type? Is this the correct value?
            vertex_z = 35 / 256
        
        obj_text += "v "
        obj_text += str(vertex_x)
        obj_text += " "
        obj_text += str(vertex_y)
        obj_text += " "
        obj_text += str(vertex_z)
        obj_text += "\n"
    
    obj_text += "usemtl " 
    obj_text += "SKY_BLACK"
    obj_text += "\n"
    
    nr_of_vertices = len(u2_object['vertices_raw'])
    
# FIXME: right now, we can have only ONE face in manual objects!    
    obj_text += "f "
    obj_text += ' '.join(str(vertex_index+vertex_index_start) for vertex_index in range(nr_of_vertices))
    obj_text += "\n"
        
    return (obj_text, nr_of_vertices)


def parse_mat_file(u2_mat_file):

    #  Note: U2E uses these starting-color-indexes (based on color_index of parsed objects):
    #        0, 8, 16, 32, 64, 96, 128, 192, 208
    #  Note: U2A uses these starting-color-indexes (based on color_index of parsed objects):
    #        0, 4?, 32, 64, 96, 128
    
    materials_by_color_index = {}
    
    lines = u2_mat_file.readlines()
    
    for line_raw in lines:
        line = line_raw.strip()
        
        if (line == ''):
            continue
        elif line.startswith(';'):
            continue
        else:
            line_parts = line.split()
            
            name = line_parts[0]
            start_color_index = int(line_parts[1])
            fade_length = int(line_parts[2][1:])
            # FIXME: check if line_parts[3] exists: gouraud = line_parts[3]

            if (start_color_index not in materials_by_color_index):
                materials_by_color_index[start_color_index] = {}
    
            materials_by_color_index[start_color_index][fade_length] = {
                'name' : name
            }
                
    return materials_by_color_index
    

# ------------------ MATERIAL --------------------

full_material_file_name = os.path.join(scene_dir, scene_name +'.00M')
u2_material_file = open(full_material_file_name, 'rb')
u2_material_binary = u2_material_file.read()
u2_material_file.close()
objects_and_material_info = parse_material_file(u2_material_binary)

nr_of_objects = objects_and_material_info['nr_of_objects']  # This includes the camera!

# Note the original engine knew long the color range would be (16 or 32) using flags of the objects
# We try to use the contents of the .MAT file instead
full_mat_file_name = os.path.join(scene_dir, scene_name +'.MAT')
u2_mat_file = open(full_mat_file_name, 'r')
mat_info = parse_mat_file(u2_mat_file)
u2_mat_file.close()

objects_and_material_info['mat_info'] = mat_info

#print(objects_and_material_info)

with open("assets/3d_scene/" + scene_name + "_material.json", "w") as material_file:
    material_file.write(json.dumps(objects_and_material_info, indent=4))


# ------------------ OBJECT DATA --------------------

objs_text = ""
objs_text += "#\n"
objs_text += "# Generated for use in 2R X16 demo\n"
objs_text += "#\n"
objs_text += "s off\n"

vertex_index_start = 1

subnr_per_object_file_index = {}
object_nr_to_name = {}
objects_by_name = {}
objects = []

for (object_index, object_file_index) in enumerate(objects_and_material_info['object_file_indexes']):
    
    if object_file_index is None:
        # The camera has no file, so we skip it
        object_nr_to_name[str(object_index)] = 'Camera'
        continue
    
    object_file_name = scene_name +'.' + "{:03d}".format(object_file_index)
    full_object_file_name = os.path.join(scene_dir, object_file_name)
    
    print(str(object_index) + ': ' + object_file_name)

    u2_object_file = open(full_object_file_name, 'rb')
    u2_object_binary = u2_object_file.read()
    u2_object_file.close()
    
# FIXME: pass the MATERIAL names and the PALETTE here?
    u2_object = parse_object_file(u2_object_binary)
    
    if (object_file_index not in subnr_per_object_file_index):
        subnr_per_object_file_index[object_file_index] = 0
    else:
        # The object file has already be used, so we create a new unique name
        subnr_per_object_file_index[object_file_index] += 1
        u2_object['name'] = u2_object['name'] + '_' + str(subnr_per_object_file_index[object_file_index])
    
    object_nr_to_name[str(object_index)] = u2_object['name']
    objects_by_name[u2_object['name']] = u2_object
    objects.append(u2_object)
    
    #if (u2_object['name'] == '"s01"'):
    #    print(u2_object['vertices'])

# Adding manual objects (to fill in the sky- and ground- gaps)
if (scene_name == 'U2E'):
    
    objects_to_add = [
    {
        'name' : '__start_east_road_1',
        'type' : 'ground',
        'vertices_raw' : [
            (-20000, -32000),  # 0: NE
            (-30000, -32000),  # 1: NW
            (-30000, -33000),  # 2: SW
            (-20000, -33000),  # 3: SE
        ],
    },
    {
        'name' : '__start_east_road_2',
        'type' : 'ground',
        'vertices_raw' : [
            ( -8000, -32000),  # 0: NE
            (-19000, -32000),  # 1: NW
            (-19000, -33000),  # 2: SW
            ( -8000, -33000),  # 3: SE
        ],
    },
    {
        'name' : '__start_south_road',
        'type' : 'ground',
        'vertices_raw' : [
            (-25000, -33000),  # 0: NE
            (-26000, -33000),  # 1: NW
            (-26000, -37000),  # 2: SW
            (-25000, -37000),  # 3: SE
        ],
    },
    {
        'name' : '__upper_east_road_1',
        'type' : 'ground',
        'vertices_raw' : [
            ( 10000,  -2000),  # 0: NE
            (-26000,  -2000),  # 1: NW
            (-26000,  -3000),  # 2: SW
            ( 10000,  -3000),  # 3: SE
        ],
    },
    {
        'name' : '__flyover_east_road_1',
        'type' : 'ground',
        'vertices_raw' : [
            ( -8100,  -8000),  # 0: NE
            (-30000,  -8000),  # 1: NW
            (-30000,  -8983),  # 2: SW
            ( -8100,  -8983),  # 3: SE
        ],
    },
    {
        'name' : '__2nd_south_road',
        'type' : 'ground',
        'vertices_raw' : [
            (-19000,  -8983),  # 0: NE
            (-20000,  -8983),  # 1: NW
            (-20000, -38000),  # 2: SW
            (-19000, -38000),  # 3: SE
        ],
    },
    {
        'name' : '__main_east_road_1',
        'type' : 'ground',
        'vertices_raw' : [
            (-17000, -14000),  # 0: NE
            (-25000, -14000),  # 1: NW
            (-25000, -15000),  # 2: SW
            (-17000, -15000),  # 3: SE
        ],
    },
    {
        'name' : '__main_east_road_2',
        'type' : 'ground',
        'vertices_raw' : [
            ( 10000, -13860),  # 0: NE
            (-13000, -13860),  # 1: NW
            (-13000, -15000),  # 2: SW
            ( 10000, -15000),  # 3: SE
        ],
    },
    {
        'name' : '__3nd_south_road_1',
        'type' : 'ground',
        'vertices_raw' : [
            (-13000,  -8983),  # 0: NE
            (-14000,  -8983),  # 1: NW
            (-14000, -12000),  # 2: SW
            (-13000, -12000),  # 3: SE
        ],
    },
    {
        'name' : '__3rd_south_road_2',
        'type' : 'ground',
        'vertices_raw' : [
            (-13000, -20000),  # 0: NE
            (-14000, -20000),  # 1: NW
            (-14000, -26000),  # 2: SW
            (-13000, -26000),  # 3: SE
        ],
    },
    {
        'name' : '__4th_north_road',
        'type' : 'ground',
        'vertices_raw' : [
            (-7000,  -3000),  # 0: NE
            (-8100,  -3000),  # 1: NW
            (-8100, -13860),  # 2: SW
            (-7000, -13860),  # 3: SE
        ],
    },
    {
        'name' : '__4th_south_road_1',
        'type' : 'ground',
        'vertices_raw' : [
            (-7000, -15000),  # 0: NE
            (-8000, -15000),  # 1: NW
            (-8000, -26000),  # 2: SW
            (-7000, -26000),  # 3: SE
        ],
    },
    {
        'name' : '__4th_south_road_2',
        'type' : 'ground',
        'vertices_raw' : [
            (-7000, -27000),  # 0: NE
            (-8000, -27000),  # 1: NW
            (-8000, -33000),  # 2: SW
            (-7000, -33000),  # 3: SE
        ],
    },
    {
        'name' : '__3rd_4th_east_road',
        'type' : 'ground',
        'vertices_raw' : [
            ( -2000, -26000),  # 0: NE
            (-14000, -26000),  # 1: NW
            (-14000, -27000),  # 2: SW
            ( -2000, -27000),  # 3: SE
        ],
    },
    {
        'name' : '__1st_2nd_east_road_1',
        'type' : 'ground',
        'vertices_raw' : [
            (-20000, -19983),  # 0: NE
            (-22000, -19983),  # 1: NW
            (-22000, -20983),  # 2: SW
            (-20000, -20983),  # 3: SE
        ],
    },
    {
        'name' : '__1st_2nd_east_road_2',
        'type' : 'ground',
        'vertices_raw' : [
            (-20000, -26000),  # 0: NE
            (-22000, -26000),  # 1: NW
            (-22000, -27000),  # 2: SW
            (-20000, -27000),  # 3: SE
        ],
    },
    {
        'name' : '__5th_south_road_1',
        'type' : 'ground',
        'vertices_raw' : [
            (-1000, -15000),  # 0: NE
            (-2000, -15000),  # 1: NW
            (-2000, -22000),  # 2: SW
            (-1000, -22000),  # 3: SE
        ],
    },
    {
        'name' : '__5th_south_road_2',
        'type' : 'ground',
        'vertices_raw' : [
            (-1188, -25000),  # 0: NE
            (-2000, -25000),  # 1: NW
            (-2000, -30000),  # 2: SW
            (-1188, -30000),  # 3: SE
        ],
    },
    {
        'name' : '__6th_south_road_1',
        'type' : 'ground',
        'vertices_raw' : [
            ( 4000, -15000),  # 0: NE
            ( 5000, -15000),  # 1: NW
            ( 5000, -18000),  # 2: SW
            ( 4000, -18000),  # 3: SE
        ],
    },
    ]
    objects += objects_to_add

    
for u2_object in objects:
    # TODO: also export NORMALS and use this: normal_index_start = 0
    if ('vertices_raw' in u2_object):
        # Manually added object
        (obj_text, nr_of_vertices) = generate_obj_text_for_manual_object(u2_object, vertex_index_start)
    else:
        (obj_text, nr_of_vertices) = generate_obj_text_for_u2_object(u2_object, vertex_index_start, mat_info)
    objs_text += obj_text
    vertex_index_start += nr_of_vertices
    
with open("assets/3d_scene/" + scene_name + ".obj", "w") as obj_file:
    obj_file.write(objs_text)
    
    
# FIXME: add color_index and color_length to object_names file!
# FIXME: add color_index and color_length to object_names file!
# FIXME: add color_index and color_length to object_names file!
    
with open("assets/3d_scene/" + scene_name + "_object_names.json", "w") as object_names_file:
    object_names_file.write(json.dumps(object_nr_to_name, indent=4))

    
# ------------------ ANIMATION --------------------

# Note: we are ignoring the .0AA file here
full_animation_file_name = os.path.join(scene_dir, scene_name +'.0AB')
u2_animation_file = open(full_animation_file_name, 'rb')
u2_animation_binary = u2_animation_file.read()
u2_animation_file.close()
objects_xyz_and_matrix_per_frame = parse_animation_file(u2_animation_binary, nr_of_objects)

with open("assets/3d_scene/" + scene_name + "_animation.json", "w") as animation_file:
    animation_file.write(json.dumps(objects_xyz_and_matrix_per_frame, indent=4))











