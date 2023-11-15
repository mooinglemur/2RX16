import os

# FIXME: HARDCODED DIR!!
scene_dir = '../../2R_test/SCENE'



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
            print('VERS: ' + str(version/256))
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
            
            print('VERT: ' + str(nr_of_vertices))
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
            
            print('NORM: ' + str(nr_of_normals))
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
                
                print('POLY: s:' + str(sides) + ' f:' + str(flags) + ' c:' + str(color_index)+ ' n:' + str(normal_index) + ' v:' + str(vertex_indices))
                #print(polygon_data)
                polygon_data_by_pos[start_polygon_data_pos-start_of_section] = polygon_data
                polygon_index += 1
                
            # TODO: do we really want to add this polygon datas to the object here?
            u2_object['polygon_data_by_pos'] = polygon_data_by_pos
            
            # print(polygon_data_by_pos)
            
            
        elif (u2_bin[pos0:pos0+3] == b'ORD'):
            print('ORD')
            
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
            print('skipping: ' + file_name)
            continue
        if (file_name.startswith(scene_name + '.00M')):
            # FIXME: we need to load/parse the MATERIAL files!
            print('skipping: ' + file_name)
            continue
        else:
            # We are assuming its an object file
            
            print('- ' + file_name + ' -')
            u2_object_file = open(full_file_name, 'rb')
            u2_object_binary = u2_object_file.read()
            u2_object_file.close()
            
            u2_object = parse_object_file(u2_object_binary, file_name)
            
            
            # FIXME: use this: normal_index_start = 0
            (obj_text, nr_of_vertices) = generate_obj_text_for_u2_object(u2_object, vertex_index_start)
            objs_text += obj_text
            vertex_index_start += nr_of_vertices
            
            #print(u2_object_binary)
            #print(u2_object)
            
            # FIXME: remove this!
            # break
            
# print(objs_text)

with open("../assets/3d_scene/" + scene_name + ".obj", "w") as obj_file:
    obj_file.write(objs_text)