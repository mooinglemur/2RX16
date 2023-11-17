import bpy
import os
import json
import mathutils
import numpy as np
import math

base_dir = bpy.path.abspath("//")

def cls():
    os.system('cls' if os.name=='nt' else 'clear')

def dump(obj):
    print(json.dumps(obj, indent=4))    
        
def clean_scene():
    # FIXME: do this more thouroughly, like here:
    #   https://github.com/CGArtPython/bpy_building_blocks_examples/blob/main/clean_scene/clean_scene_example_1.py
    
    if bpy.context.active_object and bpy.context.active_object.mode == "EDIT":
        bpy.ops.object.editmode_toggle()
        
    for obj in bpy.data.objects:
        obj.hide_set(False)
        obj.hide_select = False
        obj.hide_viewport = False
        
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()    

    collection_names = [col.name for col in bpy.data.collections]
    for name in collection_names:
        bpy.data.collections.remove(bpy.data.collections[name])
    
    camera_data = bpy.data.cameras.new(name='Camera')
    camera_object = bpy.data.objects.new('Camera', camera_data)
    bpy.context.scene.collection.objects.link(camera_object)

        
def load_city_object_file():

    print('- Cleaning the scene')
    clean_scene()

    file_to_import = "U2E.obj"
    print('- Importing the obj file: ' + file_to_import)
    bpy.ops.wm.obj_import(
        filepath=file_to_import, 
        directory=base_dir, 
        files=[{"name":file_to_import, "name":file_to_import}], 
        forward_axis='Y', 
        up_axis='Z')


def load_animation_file():
    animation_file_to_import = "U2E_animation.json"
    print('- Importing the animation file: ' + animation_file_to_import)
    anim_file_name = os.path.join(base_dir, animation_file_to_import)
    anim_file = open(anim_file_name, mode='r')
    objects_xyz_and_matrix_per_frame = json.loads(anim_file.read())
    anim_file.close()

    # FIXME: get this from a source!
    object_nr_to_name = {
        '0' : 'Camera',
        '28' : '"s01"',
    }
    
    return (object_nr_to_name, objects_xyz_and_matrix_per_frame)

cls()

clean_scene()
load_city_object_file()
(object_nr_to_name, objects_xyz_and_matrix_per_frame) = load_animation_file()

nr_of_frames = 1800
bpy.context.scene.frame_end = nr_of_frames

for frame_nr in range(1,nr_of_frames+1):
    
    # Camera
    object_nr = 0
    if (str(object_nr) in objects_xyz_and_matrix_per_frame[str(frame_nr)]):
        
        object_xyz_and_matrix = objects_xyz_and_matrix_per_frame[str(frame_nr)][str(object_nr)]
        object_name = object_nr_to_name[str(object_nr)]
        obj = bpy.data.objects[object_name]

        # https://help.autodesk.com/view/3DSMAX/2023/ENU/?guid=GUID-BEADCF00-3BBA-4722-9D7D-C07C15F8A33B
        r3_m = object_xyz_and_matrix['m']
        r_xyz = object_xyz_and_matrix
        r_matrix = [
            [ r3_m[0][0], r3_m[1][0], r3_m[2][0], r_xyz['x'] ],
            [ r3_m[0][1], r3_m[1][1], r3_m[2][1], r_xyz['y'] ],
            [ r3_m[0][2], r3_m[1][2], r3_m[2][2], r_xyz['z'] ],
            [          0,          0,          0,          1 ],
        ]
        
        r_inv = np.linalg.inv(r_matrix).tolist()
        
        #dump(r_inv)

        #r_matrix = [
        #    [ r3_m[0][0], r3_m[0][1], r3_m[0][2], r_inv[0][3] ],
        #    [ r3_m[1][0], r3_m[1][1], r3_m[1][2], r_inv[1][3] ],
        #    [ r3_m[2][0], r3_m[2][1], r3_m[2][2], r_inv[2][3] ],
        #    [           0,           0,           0,              1 ],
        #]
        #r_matrix = [
        #    [ -r_inv[0][0], -r_inv[0][1], -r_inv[0][2], r_inv[0][3] ],
        #    [ -r_inv[1][0], -r_inv[1][1], -r_inv[1][2], r_inv[1][3] ],
        #    [ -r_inv[2][0], -r_inv[2][1], -r_inv[2][2], r_inv[2][3] ],
        #    [           0,           0,           0,              1 ],
        #]
        r_matrix = [
            [ r_inv[0][0], r_inv[0][1], r_inv[0][2], r_inv[0][3] ],
            [ r_inv[1][0], r_inv[1][1], r_inv[1][2], r_inv[1][3] ],
            [ r_inv[2][0], r_inv[2][1], r_inv[2][2], r_inv[2][3] ],
            [           0,           0,           0,              1 ],
        ]
        #r_matrix = r_inv

        obj.matrix_world = mathutils.Matrix(r_matrix)
        
        #if (frame_nr == 10):
        #    print(obj.matrix_world)
        #    break

                
        #rot_angles = obj.matrix_world.to_euler()
        #rot = obj.rotation_euler
        #rot.x = math.pi - rot.x
        #obj.rotation_euler = rot
        #print()

        obj.keyframe_insert(data_path="location", frame=frame_nr)
        obj.keyframe_insert(data_path="rotation_euler", frame=frame_nr)
        

    # All other objects
    for object_nr in range(28,29):

        #dump(objects_xyz_and_matrix_per_frame[str(frame_nr)])

        if (str(object_nr) not in objects_xyz_and_matrix_per_frame[str(frame_nr)]):
            # There is no change for this object
            continue
        
        object_xyz_and_matrix = objects_xyz_and_matrix_per_frame[str(frame_nr)][str(object_nr)]
        object_name = object_nr_to_name[str(object_nr)]
        obj = bpy.data.objects[object_name]
        
        # https://help.autodesk.com/view/3DSMAX/2023/ENU/?guid=GUID-BEADCF00-3BBA-4722-9D7D-C07C15F8A33B
        r3_m = object_xyz_and_matrix['m']
        r_xyz = object_xyz_and_matrix
        r_matrix = [
            [ r3_m[0][0], r3_m[1][0], r3_m[2][0], r_xyz['x'] ],
            [ r3_m[0][1], r3_m[1][1], r3_m[2][1], r_xyz['y'] ],
            [ r3_m[0][2], r3_m[1][2], r3_m[2][2], r_xyz['z'] ],
            [          0,          0,          0,          1 ],
        ]
        
        obj.matrix_world = mathutils.Matrix(r_matrix)

        obj.keyframe_insert(data_path="location", frame=frame_nr)
        obj.keyframe_insert(data_path="rotation_euler", frame=frame_nr)


