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
            # We dont care about the version
            
            # ?? pos += 4
            pass
        
        elif (u2_bin[pos0:pos0+4] == b'NAME'):
# FIXME: we need to check for NUL termination!
            name = u2_bin[pos:pos+nr_of_bytes].decode("utf-8")
            
            print('NAME: ' + name)
            #name = 'X'
            #u2_object['name'] = name
        elif (u2_bin[pos0:pos0+4] == b'VERT'):
            print('VERT')
        elif (u2_bin[pos0:pos0+4] == b'NORM'):
            print('NORM')
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
        
            print('- ' + file_name + ' -')
            u2_object_file = open(full_file_name, 'rb')
            u2_object_binary = u2_object_file.read()
            u2_object_file.close()
            
            u2_object = parse_object_file(u2_object_binary, file_name)
            
            #print(u2_object_binary)
            print(u2_object)
            
            # FIXME: remove this!
            # break