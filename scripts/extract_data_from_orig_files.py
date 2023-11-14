import os

# FIXME: HARDCODED DIR!!
scene_dir = '../../2R_test/SCENE'



def parse_object_file(u2_bin, file_name):

    u2_object = {
        'file_name' : file_name,
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
                x = int.from_bytes(u2_bin[pos:pos+4], byteorder='little', signed=True)/10
                pos += 4
                y = int.from_bytes(u2_bin[pos:pos+4], byteorder='little', signed=True)/10
                pos += 4
                z = int.from_bytes(u2_bin[pos:pos+4], byteorder='little', signed=True)/10
                pos += 4
                normal_index = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)
                pos += 2
                # RESERVED not retrieved
                pos += 2
                
                vertex = { 'x' : x, 'y': y, 'z': z, 'normal_index': normal_index }
                vertices.append(vertex)
            
            print('VERT: ' + str(nr_of_vertices))
            print(vertices)
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
            print(normals)
            u2_object['normals'] = normals
            
        elif (u2_bin[pos0:pos0+4] == b'POLY'):
        
            # Zero word
            pos += 2
            
            polygon_index = 0
            polygon_data_by_pos = {}
            
            end_of_section = pos + nr_of_bytes
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
                polygon_data_by_pos[start_polygon_data_pos] = polygon_data
                polygon_index += 1
                
            # TODO: do we really want to add this polygon datas to the object here?
            u2_object['polygon_data_by_pos'] = polygon_data_by_pos
            
            
        elif (u2_bin[pos0:pos0+3] == b'ORD'):
            print('ORD')
            
        # break
         

        pos = pos0 + nr_of_bytes + 8
    


    return u2_object


file_list = []
for filename in os.listdir(scene_dir):
    file_list.append((filename, os.path.join(scene_dir, filename)))

for (file_name, full_file_name) in file_list:
    if (file_name.startswith('U2E.0')):
    
        if (file_name.startswith('U2E.0A')):
            # FIXME: we need to load/parse the ANIMATION files!
            print('skipping: ' + file_name)
            pass
        else:
            # We are assuming its an object file
            
            # FIXME: remove this!
            if (file_name != 'U2E.004'):  # Building08
                continue
        
            print('- ' + file_name + ' -')
            u2_object_file = open(full_file_name, 'rb')
            u2_object_binary = u2_object_file.read()
            u2_object_file.close()
            
            u2_object = parse_object_file(u2_object_binary, file_name)
            
            #print(u2_object_binary)
            print(u2_object)
            
            # FIXME: remove this!
            # break