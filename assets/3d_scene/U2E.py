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
     
def purge_orphans():
    if bpy.app.version >= (3, 0, 0):
        bpy.ops.outliner.orphans_purge(
            do_local_ids=True, do_linked_ids=True, do_recursive=True
        )
    else:
        # call purge_orphans() recursively until there are no more orphan data blocks to purge
        result = bpy.ops.outliner.orphans_purge()
        if result.pop() != "CANCELLED":
            purge_orphans()
               
def clean_scene():
    
    print('- Cleaning the scene')
    
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
    
    purge_orphans()
    
    
def create_camera():
    print('- Creating the camera')
    
    camera_data = bpy.data.cameras.new(name='Camera')
    camera_object = bpy.data.objects.new('Camera', camera_data)
    bpy.context.scene.collection.objects.link(camera_object)
    
    bpy.ops.mesh.primitive_cube_add(size=0.2, enter_editmode=False, align='WORLD', location=(0, 0, 0.1), scale=(1, 1, 1))
    cube_obj = bpy.data.objects[bpy.context.active_object.name]
    cube_obj.parent = camera_object
    cube_obj.name = 'CameraBox'

    mat_none = bpy.data.materials.new("None")
    mat_up = bpy.data.materials.new("UpDir")
    mat_up.diffuse_color = (0,1,0,0.8)
    mat_look = bpy.data.materials.new("LookingDir")
    mat_look.diffuse_color = (1,0,0,0.8)

    cube_obj.active_material = mat_none
    cube_obj.data.materials.append(bpy.data.materials['UpDir'])
    cube_obj.data.materials.append(bpy.data.materials['LookingDir'])
    
    cube_obj.data.polygons[1].material_index = 1
    cube_obj.data.polygons[4].material_index = 2

        
def load_city_object_file():

    file_to_import = "U2E.obj"
    print('- Importing the obj file: ' + file_to_import)
    bpy.ops.wm.obj_import(
        filepath=file_to_import, 
        directory=base_dir, 
        files=[{"name":file_to_import, "name":file_to_import}], 
        forward_axis='Y', 
        up_axis='Z')
        
        
def load_kdetail04_object_file():

    # Removing the old/original object
    objs = [bpy.context.scene.objects['KDETAIL04']]
    with bpy.context.temp_override(selected_objects=objs):
        bpy.ops.object.delete()
        
    # Importing the new object
    file_to_import = "KDETAIL04.obj"
    print('- Importing the obj file: ' + file_to_import)
    bpy.ops.wm.obj_import(
        filepath=file_to_import, 
        directory=base_dir, 
        files=[{"name":file_to_import, "name":file_to_import}], 
        forward_axis='Y', 
        up_axis='Z')
        

def load_logo_object_file():

    # Removing the old/original object
    objs = [bpy.context.scene.objects['logo']]
    with bpy.context.temp_override(selected_objects=objs):
        bpy.ops.object.delete()

    objs = [bpy.context.scene.objects['fcirto']]
    with bpy.context.temp_override(selected_objects=objs):
        bpy.ops.object.delete()
        
    # Importing the new object
    file_to_import = "X16_logo.obj"
    print('- Importing the obj file: ' + file_to_import)
    bpy.ops.wm.obj_import(
        filepath=file_to_import, 
        directory=base_dir, 
        files=[{"name":file_to_import, "name":file_to_import}], 
        forward_axis='Y', 
        up_axis='Z')

def load_kdetail12_object_file():

    # Removing the old/original object
    objs = [bpy.context.scene.objects['KDETAIL12']]
    with bpy.context.temp_override(selected_objects=objs):
        bpy.ops.object.delete()
        
    # Importing the new object
    file_to_import = "KDETAIL12.obj"
    print('- Importing the obj file: ' + file_to_import)
    bpy.ops.wm.obj_import(
        filepath=file_to_import, 
        directory=base_dir, 
        files=[{"name":file_to_import, "name":file_to_import}], 
        forward_axis='Y', 
        up_axis='Z')


def load_object_names_file():
    object_names_file_to_import = "U2E_object_names.json"
    print('- Importing the objects names file: ' + object_names_file_to_import)
    obj_names_file_name = os.path.join(base_dir, object_names_file_to_import)
    obj_names_file = open(obj_names_file_name, mode='r')
    object_nr_to_name = json.loads(obj_names_file.read())
    obj_names_file.close()

    return object_nr_to_name

def load_animation_file():
    animation_file_to_import = "U2E_animation.json"
    print('- Importing the animation file: ' + animation_file_to_import)
    anim_file_name = os.path.join(base_dir, animation_file_to_import)
    anim_file = open(anim_file_name, mode='r')
    objects_xyz_and_matrix_per_frame = json.loads(anim_file.read())
    anim_file.close()

    return objects_xyz_and_matrix_per_frame

def create_animation_frames():
    frame_multiplier = 5
    nr_of_frames = 1802
    nr_of_frames_in_blender = nr_of_frames * frame_multiplier
    bpy.context.scene.frame_end = nr_of_frames_in_blender
    
    logo_was_turned_visible = False
    
    previous_frame_r_matrix_per_object_nr = {}

    for frame_nr in range(1,nr_of_frames+1):
        frame_nr_in_blender = (frame_nr-1)*frame_multiplier + 1
        
        current_frame_r_matrix_per_object_nr = {}
        
        # Camera
        object_nr = 0
        if (str(object_nr) in objects_xyz_and_matrix_per_frame[str(frame_nr)]):
            
            object_xyz_and_matrix = objects_xyz_and_matrix_per_frame[str(frame_nr)][str(object_nr)]

            # https://help.autodesk.com/view/3DSMAX/2023/ENU/?guid=GUID-BEADCF00-3BBA-4722-9D7D-C07C15F8A33B
            r3_m = object_xyz_and_matrix['m']
            r_xyz = object_xyz_and_matrix
            r_matrix = [
                [ r3_m[0][0], r3_m[1][0], r3_m[2][0], r_xyz['x'] ],
                [ r3_m[0][1], r3_m[1][1], r3_m[2][1], r_xyz['y'] ],
                [ r3_m[0][2], r3_m[1][2], r3_m[2][2], r_xyz['z'] ],
                [          0,          0,          0,          1 ],
            ]
            
            r_rotate_180_x_matrix = [
                [           1,           0,           0,              0 ],
                [           0,           -1,           0,              0 ],
                [           0,           0,          -1,              0 ],
                [           0,           0,           0,              1 ],
            ]
            r_matrix_corrected = np.matmul(r_rotate_180_x_matrix, r_matrix)
            
            r_inv = np.linalg.inv(r_matrix_corrected).tolist()
            
            r_matrix_new = [
                [ r_inv[0][0], r_inv[0][1], r_inv[0][2], r_inv[0][3] ],
                [ r_inv[1][0], r_inv[1][1], r_inv[1][2], r_inv[1][3] ],
                [ r_inv[2][0], r_inv[2][1], r_inv[2][2], r_inv[2][3] ],
                [           0,           0,           0,              1 ],
            ]
            #r_matrix = r_inv

            object_name = object_nr_to_name[str(object_nr)]
            obj = bpy.data.objects[object_name]

            current_frame_r_matrix_per_object_nr[str(object_nr)] = r_matrix_new
            
            
            # Interpolated locations and rotations
            if (str(object_nr) in previous_frame_r_matrix_per_object_nr):
                from_r_matrix = np.array(previous_frame_r_matrix_per_object_nr[str(object_nr)])
                to_r_matrix = np.array(current_frame_r_matrix_per_object_nr[str(object_nr)])
                interpolated_r_matrices = np.linspace(from_r_matrix, to_r_matrix, frame_multiplier)
                
                for interpolation_index in range(1, frame_multiplier):
                    interpolated_r_matrix = interpolated_r_matrices[interpolation_index]

                    obj.matrix_world = mathutils.Matrix(interpolated_r_matrix)
                    obj.keyframe_insert(data_path="location", frame=frame_nr_in_blender - frame_multiplier + interpolation_index)
                    obj.keyframe_insert(data_path="rotation_euler", frame=frame_nr_in_blender - frame_multiplier + interpolation_index)
            
            # We last of the frames is a direct copy (no need to interpolate)
            obj.matrix_world = mathutils.Matrix(r_matrix_new)
            obj.keyframe_insert(data_path="location", frame=frame_nr_in_blender)
            obj.keyframe_insert(data_path="rotation_euler", frame=frame_nr_in_blender)
            
            

        # All other objects
        for object_nr in range(1,58):

            if (str(object_nr) not in objects_xyz_and_matrix_per_frame[str(frame_nr)]):
                # There is no change for this object
                
                # We keep the same r_matrix for this object (if we had it) since it hasnt changed
                if (str(object_nr) in previous_frame_r_matrix_per_object_nr):
                    current_frame_r_matrix_per_object_nr[str(object_nr)] = previous_frame_r_matrix_per_object_nr[str(object_nr)]
                    
                # We dont change anything in blender, so we continue
                continue
            
            object_xyz_and_matrix = objects_xyz_and_matrix_per_frame[str(frame_nr)][str(object_nr)]
            
            # https://help.autodesk.com/view/3DSMAX/2023/ENU/?guid=GUID-BEADCF00-3BBA-4722-9D7D-C07C15F8A33B
            r3_m = object_xyz_and_matrix['m']
            r_xyz = object_xyz_and_matrix
            r_matrix = [
                [ r3_m[0][0], r3_m[1][0], r3_m[2][0], r_xyz['x'] ],
                [ r3_m[0][1], r3_m[1][1], r3_m[2][1], r_xyz['y'] ],
                [ r3_m[0][2], r3_m[1][2], r3_m[2][2], r_xyz['z'] ],
                [          0,          0,          0,          1 ],
            ]
            
            object_name = object_nr_to_name[str(object_nr)]
            
            if (object_name == 'fcirto'):
                object_name = 'logo'
            
            obj = bpy.data.objects[object_name]
            
            if object_xyz_and_matrix['visible']:
                obj.hide_viewport = False
                if object_name == 'logo':
                    logo_was_turned_visible = True
            else:
                if (object_name != 'logo' or not logo_was_turned_visible):
                    obj.hide_viewport = True
            
            obj.keyframe_insert('hide_viewport', frame=frame_nr_in_blender)

            current_frame_r_matrix_per_object_nr[str(object_nr)] = r_matrix
            

            # Interpolated locations and rotations
            
            if (str(object_nr) in previous_frame_r_matrix_per_object_nr):
                from_r_matrix = np.array(previous_frame_r_matrix_per_object_nr[str(object_nr)])
                to_r_matrix = np.array(current_frame_r_matrix_per_object_nr[str(object_nr)])
                interpolated_r_matrices = np.linspace(from_r_matrix, to_r_matrix, frame_multiplier)
                
                for interpolation_index in range(1, frame_multiplier):
                    interpolated_r_matrix = interpolated_r_matrices[interpolation_index]

                    obj.matrix_world = mathutils.Matrix(interpolated_r_matrix)
                    obj.keyframe_insert(data_path="location", frame=frame_nr_in_blender - frame_multiplier + interpolation_index)
                    obj.keyframe_insert(data_path="rotation_euler", frame=frame_nr_in_blender - frame_multiplier + interpolation_index)
            
            # We last of the frames is a direct copy (no need to interpolate)
            obj.matrix_world = mathutils.Matrix(r_matrix)
            obj.keyframe_insert(data_path="location", frame=frame_nr_in_blender)
            obj.keyframe_insert(data_path="rotation_euler", frame=frame_nr_in_blender)

            
        # We remember the r_matrix from all the object of this frame (to interpolate towards the next frame)
        previous_frame_r_matrix_per_object_nr = current_frame_r_matrix_per_object_nr


cls()

clean_scene()
create_camera()
load_city_object_file()
load_logo_object_file()
load_kdetail04_object_file()
load_kdetail12_object_file()
objects_xyz_and_matrix_per_frame = load_animation_file()
object_nr_to_name = load_object_names_file()
create_animation_frames()

