import bpy
import os

def cls():
    # Clears the console
    os.system('cls' if os.name=='nt' else 'clear')

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
        
        
base_dir = bpy.path.abspath("//")

cls()
print('- Cleaning the scene')
clean_scene()

file_to_import = "U2E.obj"
print('- Importing the obj file: ' + file_to_import)
bpy.ops.wm.obj_import(filepath=file_to_import, directory=base_dir, files=[{"name":file_to_import, "name":file_to_import}])

