import os

# FIXME: HARDCODED DIR!!
scene_dir = '../../2R_test/SCENE'



def parse_object_file(u2_bin, file_name):

    u2_object = {
        'file_name' : file_name,
        'nr_of_vertices' : 0,
        'vertices' : [],
    }

    pos = 0
    
    while(pos < len(u2_bin)):
        pos0 = pos
        pos += 8
        nr_of_bytes = int.from_bytes(u2_bin[pos0+4:pos0+8], byteorder='little')
        
        if (u2_bin[pos0:pos0+4] == b'VERS'):
            # We dont really care about the version, so we dont keep it
            version = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
            print('VERS: ' + str(version/256))
        
        elif (u2_bin[pos0:pos0+4] == b'NAME'):
            # FIXME: we need to check for NUL termination!
            name = u2_bin[pos:pos+nr_of_bytes].decode("utf-8")
            print('NAME: ' + name)
            u2_object['name'] = name
        elif (u2_bin[pos0:pos0+4] == b'VERT'):
            nr_of_vertices = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
            
            pos += 4
            vertices = []
            for vert_index in range(nr_of_vertices):
                x = int.from_bytes(u2_bin[pos:pos+4], byteorder='little', signed=True)/10
                y = int.from_bytes(u2_bin[pos+4:pos+8], byteorder='little', signed=True)/10
                z = int.from_bytes(u2_bin[pos+8:pos+12], byteorder='little', signed=True)/10
                normal = int.from_bytes(u2_bin[pos+12:pos+14], byteorder='little', signed=True)
                # RESERVED not retrieved
                
                vertex = { 'x' : x, 'y': y, 'z': z, 'normal': normal }
                vertices.append(vertex)
                
                pos += 16 # x:4, y:4, z:4, normal:2, RESERVED:2
            
            print('VERT: ' + str(nr_of_vertices))
            print(vertices)
            
            
        elif (u2_bin[pos0:pos0+4] == b'NORM'):
            nr_of_normals = int.from_bytes(u2_bin[pos:pos+2], byteorder='little')
            
            pos += 4
            normals = []
            for norm_index in range(nr_of_normals):
                x = int.from_bytes(u2_bin[pos:pos+2], byteorder='little', signed=True)/16384
                y = int.from_bytes(u2_bin[pos+2:pos+4], byteorder='little', signed=True)/16384
                z = int.from_bytes(u2_bin[pos+4:pos+6], byteorder='little', signed=True)/16384
                # RESERVED not retrieved
                
                normal = { 'x' : x, 'y': y, 'z': z }
                normals.append(normal)
                
                pos += 8 # x:2, y:2, z:2, RESERVED:2
            
            print('NORM: ' + str(nr_of_normals))
            print(normals)
            
        elif (u2_bin[pos0:pos0+4] == b'POLY'):
            print('POLY')
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