import os
import numpy as np

# FIXME: HARDCODED DIR!!
scene_dir = '../../2R_test/SCENE'


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
    
    

def parse_animation_file(u2_bin, file_name):

# FIXME: should this be a list instead?
    animation_per_frame = {}
    
# FIXME: this should be the initial values?
    object_pos_per_frame = {
        0 : { 'x' : 0, 'y' : 0, 'z' : 0, 'm' : [ [ 0, 0, 0 ], [ 0, 0, 0 ], [ 0, 0, 0 ] ] },
# FIXME! HARDCODED!
        28 : { 'x' : 0, 'y' : 0, 'z' : 0, 'm' : [ [ 0, 0, 0 ], [ 0, 0, 0 ], [ 0, 0, 0 ] ] }
    }
    
    pos = 0
    
    finished = False
    frame_nr = 0
    a = 0
    while(pos < len(u2_bin) and not finished):
    
        #print('===============FRAME '+ str(frame_nr) + '=======================')
            
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
                    fov = a << 8
                    # fov = (a << 8) / 360
                    # print('fov: ' + str(fov))
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
            
            if (a&0xc0 == 0x80):
                # object is *on*
                #print("object is on")
                pass
            elif (a&0xc0 == 0x40):
                # object is *off*
                #print("object is off")
                pass
            else:
                #print("object is neither on or off")
                pass
                
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
            
            if (onum in object_pos_per_frame):
                if delta['x'] is not None:
                    object_pos_per_frame[onum]['x'] += delta['x']
                if delta['y'] is not None:
                    object_pos_per_frame[onum]['y'] += delta['y']
                if delta['z'] is not None:
                    object_pos_per_frame[onum]['z'] += delta['z']
                for b in range(9):
                    if (delta['m'][b%3][b//3] is not None):
                        object_pos_per_frame[onum]['m'][b//3][b%3] += delta['m'][b%3][b//3]


            # FIXME: get the relevant object xyz and matrix and matrix MULTIPLY!
            # FIXME: get the relevant object xyz and matrix and matrix MULTIPLY!
            # FIXME: get the relevant object xyz and matrix and matrix MULTIPLY!
            
            if onum == 0:
                # Decompose matrix: get camera location from view matrix
                # https://stackoverflow.com/questions/39280104/how-to-get-current-camera-position-from-view-matrix
                # https://gamedev.stackexchange.com/questions/138208/extract-eye-camera-position-from-a-view-matrix
                # https://community.khronos.org/t/extracting-camera-position-from-a-modelview-matrix/68031
                pass
            else:
                pass
            
            if onum == 28:
                #print('object: ' + str(onum) + str(object_pos_per_frame[onum]))
                # TODO: 33fps?
                '''
                print('t:' + str("{:.2f}".format(frame_nr/33)) # + ' o: ' + str(onum) 
                                 + ' x:' + str("{:.2f}".format(object_pos_per_frame[onum]['x']))
                                 + ' y:' + str("{:.2f}".format(object_pos_per_frame[onum]['y']))
                                 + ' z:' + str("{:.2f}".format(object_pos_per_frame[onum]['z']))
                                 + '  [' + str("{:.2f}".format(object_pos_per_frame[onum]['m'][0][0])) + ', ' + str("{:.2f}".format(object_pos_per_frame[onum]['m'][0][1])) + ', ' + str("{:.2f}".format(object_pos_per_frame[onum]['m'][0][2])) + '], '
                                 + ' [' + str("{:.2f}".format(object_pos_per_frame[onum]['m'][1][0])) + ', ' + str("{:.2f}".format(object_pos_per_frame[onum]['m'][1][1])) + ', ' + str("{:.2f}".format(object_pos_per_frame[onum]['m'][1][2])) + '], '
                                 + ' [' + str("{:.2f}".format(object_pos_per_frame[onum]['m'][2][0])) + ', ' + str("{:.2f}".format(object_pos_per_frame[onum]['m'][2][1])) + ', ' + str("{:.2f}".format(object_pos_per_frame[onum]['m'][2][2])) + ']'
                                 )
                '''                 
                            
                # https://help.autodesk.com/view/3DSMAX/2023/ENU/?guid=GUID-BEADCF00-3BBA-4722-9D7D-C07C15F8A33B
                r3_m = object_pos_per_frame[onum]['m']
                r_xyz = object_pos_per_frame[onum]
                r_matrix = np.array([
                    [ r3_m[0][0], r3_m[1][0], r3_m[2][0], r_xyz['x'] ],
                    [ r3_m[0][1], r3_m[1][1], r3_m[2][1], r_xyz['y'] ],
                    [ r3_m[0][2], r3_m[1][2], r3_m[2][2], r_xyz['z'] ],
                    [          0,          0,          0,          1 ],
                ])

                # FIXME: HARDCODED!
                # org: {'x': -107.04296875, 'y': -125.140625, 'z': 4.98046875 }
                ship_coords = np.array([ -107.04296875, -125.140625, 4.98046875, 1 ])
                
                new_ship_coords = r_matrix.dot(ship_coords)
                
                print('t:' + str("{:.2f} ".format(frame_nr/33)) + str(new_ship_coords.tolist()[0:3]))
                


            #print('---')

        frame_nr += 1
            
    # FIXME: REMOVE!        
        #if (frame_nr > 22*30):
        #    break


    return animation_per_frame

def parse_object_file(u2_bin, file_name):

    u2_object = {
        'file_name' : file_name,
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
            print('NAME: ' + name)
            u2_object['name'] = name
        elif (u2_bin[pos0:pos0+4] == b'VERT'):
            nr_of_vertices = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
            pos += 2
            # Dummy word
            pos += 2
            
            vertices = []
            for vert_index in range(nr_of_vertices):
            
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
                x = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)/16384
                pos += 2
                y = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)/16384
                pos += 2
                z = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)/16384
                pos += 2
                # RESERVED not retrieved
                pos += 2
                
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
                # FIXME: we probably want to extract the individual bits from this flag-byte!
                flags = int.from_bytes(u2_bin[pos:pos+1], byteorder='little' )
                pos += 1
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
            
            # FIXME: WHAT IS THIS???? -> a way to quickly sort polygons of an object given a certain camera position/angle, maybe?
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

def generate_obj_text_for_u2_object(u2_object, vertex_index_start):
    obj_text = ""
    
    obj_text += "o " + u2_object['name'] + "\n"
    for vertex in u2_object['vertices']:
        obj_text += "v "
        obj_text += str(vertex['x'])
        # Note: we are flipping the Z and Y axis here (and negating Y), since Blender has the axis in a different way!
        obj_text += " "
        obj_text += str(vertex['z'])
        obj_text += " "
        obj_text += str(-vertex['y'])
        obj_text += "\n"
        
    
    for data_pos in u2_object['polygon_data_by_pos']:
        polygon_data = u2_object['polygon_data_by_pos'][data_pos]
        
        #print(polygon_data)
        obj_text += "f "
        obj_text += ' '.join(str(vertex_index+vertex_index_start) for vertex_index in polygon_data['vertex_indices'])
        obj_text += "\n"
        
    nr_of_vertices = len(u2_object['vertices'])
    
    return (obj_text, nr_of_vertices)


file_list = []
for filename in os.listdir(scene_dir):
    file_list.append((filename, os.path.join(scene_dir, filename)))

objs_text = ""
objs_text += "#\n"
objs_text += "# Generated for use in 2R X16 demo\n"
objs_text += "#\n"
objs_text += "s off\n"
    
    
scene_name = 'U2E'
vertex_index_start = 1

for (file_name, full_file_name) in file_list:
    if (file_name.startswith(scene_name + '.0')):
    
        if (file_name.startswith(scene_name + '.0A')):
            # FIXME: we need to load/parse the ANIMATION files!
            
            if file_name.startswith(scene_name + '.0AB'):
                u2_animation_file = open(full_file_name, 'rb')
                u2_animation_binary = u2_animation_file.read()
                u2_animation_file.close()
            
                animation_data = parse_animation_file(u2_animation_binary, file_name)
                
                #print(animation_data)
                
#                print('skipping: ' + file_name)
#                continue
            else:
                print('skipping: ' + file_name)
                continue
            
        elif (file_name.startswith(scene_name + '.00M')):
            # FIXME: we need to load/parse the MATERIAL files!
            print('skipping: ' + file_name)
            continue
        else:
        
#FIXME!
#FIXME!
#FIXME!
#FIXME!
            print('skipping: ' + file_name)
            continue
            
            # We are assuming its an object file
            
            print('- ' + file_name + ' -')
            u2_object_file = open(full_file_name, 'rb')
            u2_object_binary = u2_object_file.read()
            u2_object_file.close()
            
            u2_object = parse_object_file(u2_object_binary, file_name)
            
            
            #if (u2_object['name'] == '"s01"'):
            #    print(u2_object['vertices'])
            
            
            # FIXME: use this: normal_index_start = 0
            (obj_text, nr_of_vertices) = generate_obj_text_for_u2_object(u2_object, vertex_index_start)
            objs_text += obj_text
            vertex_index_start += nr_of_vertices
            
            #print(u2_object_binary)
            #print(u2_object)
            
            # FIXME: remove this!
            #break
            
# print(objs_text)

#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#FIXME!
#with open("../assets/3d_scene/" + scene_name + ".obj", "w") as obj_file:
#    obj_file.write(objs_text)










