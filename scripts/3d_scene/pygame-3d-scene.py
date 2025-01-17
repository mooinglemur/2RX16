#!/usr/bin/env python3

import pygame
from pygame.locals import *
import math
from enum import Enum
import copy
import time
from shapely.geometry import Polygon, GeometryCollection
import numpy as np
import json
import random
from functools import cmp_to_key

# Before running this script first (in Blender 3.6) do:
#  - Open U2A.blend/U2E.blend
#  - Go to scripting tab, run script ("play"-button or Alt-P)
#  - Go to layout tab (not needed, but you can check if everything looks ok (you usually see the last frame, you can rewind and play animation if desired)
# Export files (needed for this sctipt to run):
#  - Go to File->Export->Wavefront (obj)
#  - Forward Axis: Y
#  - Upward Axis: Z
#  - Select: Normals, Materials->Export  (do NOT triangulate mesh!)
#  - Select: Animation->Export, 1-100 (or 1-1802*4 for U2E or 1-522*2 for U2A)
#  - Filename: U2E_anim.obj/U2A_anim.obj  (this will genarate files with names: U2E_anim<frame_nr>.obj and U2E_anim<frame_nr>.mtl)
# Before actually running this script: 
#  - change the SCENE variable below
#  - run from root repo directory: python .\scripts\3d_scene\pygame-3d-scene.py

SCENE = 'U2E'
#SCENE = 'U2A'


polygon_data_file = 'scripts/3d_scene/' + SCENE + '-POLYGONS.DAT'

COLOR_IDX_SKY_BLACK = 254

random.seed(10)

REMOVE_INVISIBLE_FACES = True
MERGE_FACES = True
CONVERT_COLORS_TO_12BITS = True
PATCH_COLORS_MANUALLY = True
USE_FX_POLY_FILLER_SIM = True
PRINT_PALETTE = False

# FIXME!
# FIXME!
# FIXME!
# FIXME!
ALLOW_PAUSING_AND_REVERSE_PLAYBACK = False # When turned on, this will not automatically turn off playback so no output file will be written!
# FIXME!
PRINT_ERRORS = False
PRINT_WARNINGS = False
PRINT_PALETTE_FOR_MANUAL_EDIT = False

PRINT_FRAME_TRIANGLES = True
PRINT_PROGRESS = False
DRAW_PALETTE = False
DRAW_BLACK_PIXELS = True
DEBUG_SORTING = False
DEBUG_DRAW_TRIANGLE_BOUNDARIES = False # Very informative!
DEBUG_SHOW_MERGED_FACES = False
DEBUG_SHOW_VERTEX_NRS = False
DEBUG_COUNT_REDRAWS = False  # VERY slow! -> use R-key to toggle!
DEBUG_COLORS = False
DEBUG_SORTING_LIMIT_OBJECTS = False
DEBUG_COLOR_PER_ORIG_TRIANGLE = False
DEBUG_CLIP_COLORS = False
DEBUG_RESERSE_SORTING = False
DRAW_INTERSECTION_POINTS = False

screen_width = 320
screen_height = 150
scale = 3          # this is only used to scale up the screen in pygame

fx_state = {}

# FIXME: we took the FOV from U2E.INF (which might not be completely accurate, since its converted to a 16bit number first)
if SCENE == 'U2E':
    fov_degrees = 40
else:
    fov_degrees = 48
    
# We put the ASPECT RATIO in here for clipping against the camera sides
LEFT_EDGE_X = -1
RIGHT_EDGE_X = +1
BOTTOM_EDGE_Y = -1 * (150/320)
TOP_EDGE_Y = +1 * (150/320)

Z_EDGE = -1.0   # this is the near plane

#projection_to_screen_scale = 280/2
projection_to_screen_scale = 320/2  # projected coordinates go from -1.0 to +1.0 and since that is 2.0 total, we need to divide the width of our screen by 2
center_offset = (screen_width // 2, screen_height // 2)


# Initialize Pygame
pygame.init()

# Set up the display
screen = pygame.display.set_mode((screen_width*scale, screen_height*scale))
pygame.display.set_caption("3D Scene")
clock = pygame.time.Clock()
font = pygame.font.SysFont("monospace", 14)

# This buffer is used to see if a face(_index) gets (completely) overwritten)
check_triangle_visibility_buffer = pygame.Surface((screen_width, screen_height), depth = 16)

# This buffer is used to draw a face individually to count the number of redraws
face_buffer = pygame.Surface((screen_width, screen_height), depth = 8)

frame_buffer = pygame.Surface((screen_width, screen_height))
# FIXME: we want to use a frame_buffer that has indexed colors. We can blit that to the pygame screen (enlarged).
# frame_buffer = pygame.Surface((screen_width, screen_height), depth = 8)


# Quick and dirty (debug) colors here (somewhat akin to VERA's first 16 colors0
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED  = (255, 64, 64)
CYAN = (64, 255, 255)
MAGENTA = (255, 64, 255)
GREEN = (64, 255, 64)
BLUE  = (64, 64, 255)
YELLOW = (255, 255, 64)

ORANGE = (255, 224, 0)
BROWN = (165, 42, 42)
PINK = (255, 224, 224)
DARKGRAY = (64, 64, 64)
GRAY = (128, 128, 128)
LIME = (224, 255, 224)
SKYBLUE = (224, 224, 255)
LIGHTGRAY = (192, 192, 192)

debug_colors = [
    BLACK,
    WHITE,
    RED,
    CYAN,
    MAGENTA,
    GREEN,
    BLUE,
    YELLOW,

    ORANGE,
    BROWN,
    PINK,
    DARKGRAY,
    GRAY,
    LIME,
    SKYBLUE,
    LIGHTGRAY,
]


debug_vertex_colors = [
    RED,
    GREEN,
    BLUE,
    CYAN,
    MAGENTA,
    YELLOW,
    ORANGE,
    BROWN,
    
    PINK,
    DARKGRAY,
    GRAY,
    LIME,
    SKYBLUE,
    LIGHTGRAY,
    WHITE,
    MAGENTA,  # duplicate!
]

# Adding 48 more random colors
for i in range(48):
    r = random.randint(0, 255)
    g = random.randint(0, 255)
    b = random.randint(0, 255)
    random_color = (r, g, b)
    debug_colors.append(random_color)

'''
material_name_to_color_index = {
    None : 0,
    'None' : 1,
    'LookingDir' : 1,
    'UpDir' : 1,
    'Red' : 2,
    'Green' : 5,
    'Blue' : 6,
    'Yellow' : 7,
}
'''

def load_material_info():
    material_file_to_import = SCENE + "_material.json"
    material_file = open('assets/3d_scene/' + material_file_to_import, 'r')
    material_info = json.loads(material_file.read())
    material_file.close()
    return material_info

def load_vertices_and_faces(frame_nr):

    obj_file = open('assets/3d_scene/'+SCENE+'_anim/'+SCENE+'_anim' + str(frame_nr) + '.obj', 'r')
    lines = obj_file.readlines()
    
    objects = {}
    
    current_object_name = None
    current_material_name = None
    
    current_vertex_index = 0
    object_start_vertex_index = None
    
    current_normal_index = 0
    object_start_normal_index = None
    
    for line_raw in lines:
        line = line_raw.strip()
        
        if line.startswith('#'):
            continue
        
        elif line.startswith('o '):
            line_parts = line.split()
            current_object_name = line_parts[1]
            objects[current_object_name] = {
                'vertices' : [],
                'normals' : [],
                'faces' : [],
            }
            current_material_name = None # Each object has its own material assignments. We only reset the current_material_name at the start of an object
            object_start_vertex_index = current_vertex_index
            object_start_normal_index = current_normal_index
            
        elif line.startswith('usemtl '):
            line_parts = line.split()
            current_material_name = line_parts[1]
            # FIXME: HACK to fix the material name when importing manually edited objects in Blender!
            if (current_material_name == 'RED_HOUSE.001' or current_material_name == 'RED_HOUSE.002' or current_material_name == 'RED_HOUSE.003'):
                current_material_name = 'RED_HOUSE'
            
        elif line.startswith('vn '):
            line_parts = line.split()
            line_parts.pop(0)  # first element contains the 'vn '
            coordinates = [float(line_part) for line_part in line_parts]
            
            normal = [ coordinates[0], coordinates[1], coordinates[2] ]
            objects[current_object_name]['normals'].append(normal)
            current_normal_index += 1
        
        elif line.startswith('v '):
            line_parts = line.split()
            line_parts.pop(0)  # first element contains the 'v '
            coordinates = [float(line_part) for line_part in line_parts]
            
            vertex = [ coordinates[0], coordinates[1], coordinates[2] ]
            objects[current_object_name]['vertices'].append(vertex)
            current_vertex_index += 1

        elif line.startswith('f '):
            line_parts = line.split()
            line_parts.pop(0)  # first element contains the 'f '
            vertex_indices = []
            normal_index = None
            for line_part in line_parts:
                # There are in fact two indexes: one for the vertex and one for the normal.
                vertex_index = int(line_part.split('//')[0])-1   
                vertex_indices.append(vertex_index)
                # Note: we overwrite the normal index, since we assume this is a polygon that has ONE normal for each face
                normal_index = int(line_part.split('//')[1])-1   
                
            
            if current_material_name in mat_name_to_index_and_shades:
                color_index_and_shades = mat_name_to_index_and_shades[current_material_name]
                color_index = color_index_and_shades['color_index']
                nr_of_shades = color_index_and_shades['nr_of_shades']
            elif current_material_name == 'SKY_BLACK':
                color_index = COLOR_IDX_SKY_BLACK
                nr_of_shades = 0
            else:
                # TODO: These materials should never be shown, so we set the to None for now, but this isnt really correct
                color_index = None
                nr_of_shades = None
                if (current_object_name != 'CameraBox'):
                    print("Unknown material: " + current_material_name)
                    #exit()
                
            # TODO?: right now, we convert a global vertex (and normal) index into an object-vertex (and normal) index. Is this actually a good idea?
            for vertex_index in range(len(vertex_indices)):
                vertex_indices[vertex_index] -= object_start_vertex_index

            objects[current_object_name]['faces'].append({
                'vertex_indices' : vertex_indices,
                'normal_index' : normal_index - object_start_normal_index,
                'color_index' : color_index,
                'nr_of_shades' : nr_of_shades,
                'material_name' : current_material_name
            })
            
    # TODO: we should do another pass and add the *bounding boxes* of these objects! (to SPEED UP the clipping!)
            
    return objects


def triangulate_faces(world_objects):

    triangulated_world_objects = world_objects
    
    orig_global_face_index = 0
    
    for current_object_name in world_objects:
        
        object_faces = world_objects[current_object_name]['faces']
        
        triangulated_object_faces = []
        
        for object_face_index, object_face in enumerate(object_faces):
        
            # This template face will inheret the normals and the vertices of the original face
            new_template_face = copy.deepcopy(object_face)
            new_template_face['vertex_indices'] = []
            
            orig_vertex_indices = copy.deepcopy(object_face['vertex_indices'])
        
# FIXME: there are SOME concave faces in the original data! (most notable the two half-moon shapes on the back of the ship).
#        We need to make sure we triangulate them in a specific way!
#        So we need to make it possible to MANUALLY triangulate some of the faces!
        
            # https://stackoverflow.com/questions/5247994/simple-2d-polygon-triangulation
            # This is when you want to handle simple polygons like rectangles, pentagons, hexagons and so on. 
            # Here you just take a starting point and connect it to all other vertices. 
            for third_index_of_triangle in range(2, len(orig_vertex_indices)):
            
                new_object_face = copy.deepcopy(new_template_face)
                
                second_index_of_triangle = third_index_of_triangle - 1
                
                # We take the first three vertices as our new triangle face
                new_object_face['vertex_indices'].append(orig_vertex_indices[0])
                new_object_face['vertex_indices'].append(orig_vertex_indices[second_index_of_triangle])
                new_object_face['vertex_indices'].append(orig_vertex_indices[third_index_of_triangle])
                
                new_object_face['orig_face_index'] = orig_global_face_index
                if (len(orig_vertex_indices) == 4):
                    new_object_face['was_quad_originally'] = True
                triangulated_object_faces.append(new_object_face)
        
            orig_global_face_index += 1
            
        triangulated_world_objects[current_object_name]['faces'] = triangulated_object_faces
    

    return triangulated_world_objects

def get_longest_edge_of_two_triangles(face, vertices):
    # We want the diagonal of the (triangle) face. So the longest edge.
    
    vertex1 = vertices[face['vertex_indices'][0]]
    vertex2 = vertices[face['vertex_indices'][1]]
    vertex3 = vertices[face['vertex_indices'][2]]
    
    edge1_len = np.linalg.norm(np.subtract(vertex1, vertex2))
    edge2_len = np.linalg.norm(np.subtract(vertex2, vertex3))
    edge3_len = np.linalg.norm(np.subtract(vertex3, vertex1))
    
    if (edge1_len > edge2_len and edge1_len > edge3_len):
        return (vertex1, vertex2)
    elif (edge2_len > edge1_len and edge2_len > edge3_len):
        return (vertex2, vertex3)
    else:
        return (vertex3, vertex1)


def get_camera_info_from_camera_box(camera_box):

    # We need to take the world position of the camera (which is HALF-way of the diagonal of the looking dir face)
    # We also have to use the normal of the looking face to determine the camera pointing/looking direction (in world space)
    # We also have to use the normal of the up face to determine the up direction of the camera (in world space)

    camera_box_looking_dir_face = None
    camera_box_up_dir_faces = None
    for camera_face_triangle in camera_box['faces']:
        if camera_face_triangle['material_name'] == 'LookingDir':
            # To determine the camera position and looking dir 
            camera_box_looking_dir_face = camera_face_triangle
        if camera_face_triangle['material_name'] == 'UpDir':
            # For the look up dir we need only one of the face triangles (that refers to a normal)
            camera_box_up_dir_face = camera_face_triangle

    (looking_face_diagonal_vertex_1, looking_face_diagonal_vertex_2) = get_longest_edge_of_two_triangles(camera_box_looking_dir_face, camera_box['vertices'])

    x = (looking_face_diagonal_vertex_1[0] + looking_face_diagonal_vertex_2[0])/2
    y = (looking_face_diagonal_vertex_1[1] + looking_face_diagonal_vertex_2[1])/2
    z = (looking_face_diagonal_vertex_1[2] + looking_face_diagonal_vertex_2[2])/2
    camera_pos = [x, y, z]
    looking_dir = camera_box['normals'][camera_box_looking_dir_face['normal_index']]
    
    up_dir = camera_box['normals'][camera_box_up_dir_face['normal_index']]
    
    camera_info = {
        'pos' : camera_pos, # Coordinate in world space
        'looking_dir' : looking_dir, # Normalized value, in world space
        'up_dir' : up_dir, # Normalized value, in world space
    }
    
    return camera_info


def transform_objects_into_view_space(world_objects, camera_info):

    # More info on: Model space, World space, View/Camera space, Projection Space:
    #   http://www.codinglabs.net/article_world_view_projection_matrix.aspx

    # We get World space data from Blender (in the .obj files)
    # In order for this to be processed, we need to know every coordinate *relative to the camera* (and where it points: negative Z direction)
    # For that we need to transform every vertex coordinate from World Space to View Space first.
    # We can do that with a "World to View/Camera"-Matrix (aka "View Matrix" or "Camera Matrix"). This is what we constuct here.
    #   More info on this: https://www.mauriciopoppe.com/notes/computer-graphics/viewing/view-transform/
    #     Explanation of example code in this video: https://www.youtube.com/watch?v=HXSuNxpCzdM&t=1560s
    #     Actual example code: https://github.com/OneLoneCoder/Javidx9/blob/54b26051d0fd1491c325ae09f50a7fc3f25030e8/ConsoleGameEngine/BiggerProjects/Engine3D/OneLoneCoder_olcEngine3D_Part3.cpp#L228

    # Then we need to translate and rotate all vertices so they become into Camera/View space.

    # Careful with numpy issues: https://stackoverflow.com/questions/21562986/numpy-matrix-vector-multiplication
    
    # -
    
    # Note: we are a bit lazy here and do this in two steps (not efficient)
    #       we first translate (aka move) the vertices (*not* the normals btw) so that the camera is at 0,0
    #       then we only have to rotate all world_objects so the camera points in the negative Z direction.
    #       this simplifies our view-matrix
    
    cam_x = camera_info['pos'][0]
    cam_y = camera_info['pos'][1]
    cam_z = camera_info['pos'][2]
    
    for current_object_name in world_objects:
        current_object = world_objects[current_object_name]
        for idx, vertex in enumerate(current_object['vertices']):
            old_x = current_object['vertices'][idx][0]
            old_y = current_object['vertices'][idx][1]
            old_z = current_object['vertices'][idx][2]
            current_object['vertices'][idx] = (old_x - cam_x, old_y - cam_y, old_z - cam_z)
            
            
    # We now construct a view-matrix (but without the translation part, making it a bit simpler)
    #  (See Javidx9 video #3 about this)
    
    up_dir = camera_info['up_dir']
    looking_dir = camera_info['looking_dir']
    #print('====> LOOKING DIR:' + str(looking_dir))
    #print('====> UP DIR:' + str(up_dir))
    new_forward = np.negative(looking_dir)  # I think we need to negate because we want the forward direction (of the camera) to be *negative* Z
    
    up_dot_forward = np.dot(np.array(up_dir), np.array(new_forward))
    a = np.array(new_forward) * up_dot_forward
    new_up = np.subtract(up_dir, a)
    new_up = new_up / np.linalg.norm(new_up)
    
    new_right = np.cross(new_up, new_forward)
    
    view_matrix = np.array([
        [   new_right[0],   new_right[1], new_right[2]],
        [      new_up[0],      new_up[1],    new_up[2]],
        [ new_forward[0], new_forward[1], new_forward[2]],
    ])

    # We transform all vertices and normals by the view_matrix
    view_objects = {}
    for current_object_name in world_objects:
        world_object = world_objects[current_object_name]
        view_object = copy.deepcopy(world_objects[current_object_name])
        
        # Vertices
        for idx, vertex in enumerate(world_object['vertices']):
            world_vertex = np.array(world_object['vertices'][idx])
            view_object['vertices'][idx] = view_matrix.dot(world_vertex)
            
        # Normals
        for idx, normal in enumerate(world_object['normals']):
            world_normal = np.array(world_object['normals'][idx])
            view_object['normals'][idx] = view_matrix.dot(world_normal)
            
        view_objects[current_object_name] = view_object
        
    return view_objects
    
    
def cull_faces_of_objects(view_faces, view_vertices, view_normals):

    culled_view_faces = []
    culled_view_vertices = view_vertices
    
    for face in view_faces:
       
        # We need to check whether a face is facing away from the camera. If it is, we should remove it.
        # We do this check by doing the dot-product with the normal of the face and the direction of any vertex of that face (from the camera, which is at 0,0,0)
        face_normal = np.array(view_normals[face['normal_index']])
        first_vertex = np.array(view_vertices[face['vertex_indices'][0]])
        normalized_vector_towards_first_vertex = first_vertex / np.linalg.norm(first_vertex)
        dot_product = np.dot(normalized_vector_towards_first_vertex, face_normal)
        
        # When it is facing away form the camera, we cull it
        if dot_product > 0:
            continue
    
        culled_view_faces.append(face)
        
    return (culled_view_faces, culled_view_vertices)

def is_vertex_inside_z_edge(combined_vertices, vertex_index):

    vertex = combined_vertices[vertex_index]
    
    z = vertex[2]
    
    vertex_is_inside = True

    if z > Z_EDGE:
        vertex_is_inside = False
            
    return vertex_is_inside
    

def clip_vertex_against_z_edge(combined_vertices, inside_vertex_index, outside_vertex_index, created_vertices_by_code):

    lookup_code = str(inside_vertex_index) + '::' + str(outside_vertex_index)
    
    clipped_vertex_index = None
    if (lookup_code in created_vertices_by_code):
        # We already clipped this vertex against the z-edge, so we re-use that vertex
        clipped_vertex_index = created_vertices_by_code[lookup_code]
    else:
        # We have not yet clipped this vertex against the z-edge, so we create a new vertex
        
        inside_vertex = combined_vertices[inside_vertex_index]
        outside_vertex = combined_vertices[outside_vertex_index]

        percentage_to_keep = (inside_vertex[2] - Z_EDGE) / (inside_vertex[2] - outside_vertex[2])
        x_clipped = inside_vertex[0] + (outside_vertex[0] - inside_vertex[0]) * percentage_to_keep
        y_clipped = inside_vertex[1] + (outside_vertex[1] - inside_vertex[1]) * percentage_to_keep
        clipped_vertex = (x_clipped, y_clipped, Z_EDGE)
        
        clipped_vertex_index = len(combined_vertices)
        combined_vertices.append(clipped_vertex)
        
        created_vertices_by_code[lookup_code] = clipped_vertex_index
    
    return clipped_vertex_index


def clip_face_against_z_edge(non_clipped_face, combined_vertices, created_vertices_by_code):
    clipped_faces = []

    # We need to check which of these vertices are INSIDE and OUTSIDE of the plane/edge we are clipping against
    
    inside_vertex_nrs = []
    outside_vertex_nrs = []
    inside_vertex_indices = []
    outside_vertex_indices = []
    for vertex_nr in range(3):
        non_clipped_vertex_index = non_clipped_face['vertex_indices'][vertex_nr]
        
        vertex_is_inside = is_vertex_inside_z_edge(combined_vertices, non_clipped_vertex_index)
        
        if vertex_is_inside:
            # Since this is an inside vertex, there is no need to clip it, so we just copy it
            inside_vertex_nrs.append(vertex_nr)
            inside_vertex_indices.append(non_clipped_vertex_index)
        else:
            # We clip the vertex against the edge
            outside_vertex_nrs.append(vertex_nr)
            outside_vertex_indices.append(non_clipped_vertex_index)
    
    if (len(inside_vertex_indices) == 0):
        # The triangle is completely outside the edge, we dont add it
        pass
    elif (len(inside_vertex_indices) == 3):
        # The triangle is completely inside the edge, we add it as-is
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_faces.append(clipped_face)
    elif (len(inside_vertex_indices) == 1):
        # Out triangle gets shorter, so we return one smaller triangle

        if (outside_vertex_nrs[0] == 0 and outside_vertex_nrs[1] == 2):
            # We need to switch the outside vertices to preserve the order
            outside_vertex_indices.reverse()
            outside_vertex_nrs.reverse()
            
        clipped_vertex_index_0 = clip_vertex_against_z_edge(combined_vertices, inside_vertex_indices[0], outside_vertex_indices[0], created_vertices_by_code)
        clipped_vertex_index_1 = clip_vertex_against_z_edge(combined_vertices, inside_vertex_indices[0], outside_vertex_indices[1], created_vertices_by_code)
        
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_face['vertex_indices'] = [inside_vertex_indices[0], clipped_vertex_index_0, clipped_vertex_index_1]
        clipped_face['is_clipped'] = True
        if (DEBUG_CLIP_COLORS):
            clipped_face['color_index'] = 3
        clipped_faces.append(clipped_face)
    elif (len(inside_vertex_indices) == 2):
        # We have a quad we have to split into two triangles
        
        if (inside_vertex_nrs[0] == 0 and inside_vertex_nrs[1] == 2):
            # We need to switch the inside vertices to preserve the order
            inside_vertex_indices.reverse()
            inside_vertex_nrs.reverse()
            
        # First triangle
        clipped_vertex_index_1 = clip_vertex_against_z_edge(combined_vertices, inside_vertex_indices[1], outside_vertex_indices[0], created_vertices_by_code)
        
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_face['vertex_indices'] = [clipped_vertex_index_1, inside_vertex_indices[0], inside_vertex_indices[1]]
        clipped_face['is_clipped'] = True
        if (DEBUG_CLIP_COLORS):
            clipped_face['color_index'] = 2
        clipped_faces.append(clipped_face)
        
        # Second triangle
        clipped_vertex_index_0 = clip_vertex_against_z_edge(combined_vertices, inside_vertex_indices[0], outside_vertex_indices[0], created_vertices_by_code)
        
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_face['vertex_indices'] = [clipped_vertex_index_0, inside_vertex_indices[0], clipped_vertex_index_1]
        clipped_face['is_clipped'] = True
        if (DEBUG_CLIP_COLORS):
            clipped_face['color_index'] = 4
        clipped_faces.append(clipped_face)

    return clipped_faces


def z_clip_faces (view_faces, view_vertices):

    z_clipped_view_faces = []
    z_clipped_view_vertices = copy.deepcopy(view_vertices)
    
    # We keep track of all clipped vertices being created
    combined_vertices = z_clipped_view_vertices
    
    # This is a dict where we record all vertices we created by a deterministic 'code': "<inside_vertex_index>::<outside_vertex_index>" which maps to the created_vertex_index
    # That way we can find already created vertices and therefore re-use them
    created_vertices_by_code = {}

    # We determine -for each face- whether it should be clipped against the edges of the screen
    for non_clipped_face in view_faces:

        # The clipped_vertices is an OUPUT vertex-array!
        clipped_faces_against_z_edge = clip_face_against_z_edge(non_clipped_face, combined_vertices, created_vertices_by_code)

        # After clipping against the Z-edge we are left with only clipped faces
        z_clipped_view_faces += clipped_faces_against_z_edge

    return (z_clipped_view_faces, z_clipped_view_vertices)


def apply_light_to_faces(view_faces, view_vertices, view_normals):

    # for each face we change the dot-product with the camera light
    for face in view_faces:
        normal_index = face['normal_index']
        normal = view_normals[normal_index]
        
        # Note: in ADRAW.ASM there is a routine called 'calclight' which in turn calls 'normallight'. This uses the following data:
        #
        #   newlight dw	12118,10603,3030
        #
        # This seems to be the x,y and z direction (as a vector) of the light source, relative to the *camera*!
        #
        # Assuming these are signed 16-bit fixed point numbers, this is (roughly): 0.37, 0.32, 0.09
        # We also asumme that Y is flipped in the original engine. Since it is not here, we have to negate it.

# FIXME: some colors still seem complete off (like the purple)!
#        FOR EXAMPLE: look at 'Building20'!
        
        #camera_light = [0.408248, -0.408248, 0.816497]
        camera_light = [0.37, -0.32, 0.09]
        
        light_dot = np.dot(np.array(camera_light), np.array(normal))
        
        # CHECK: Is this equivalent to the "add	ax,128" in the orginal?
        light_dot += 0.5
        #print(light_dot)
        if light_dot > 1:
            light_dot = 1
        if light_dot < 0:
            light_dot = 0
        
        # FIXME! HACK to approximate: note that if we raise this above 0.5 the '45degree-ceiling-of-the-tunnel' becomes grey. We probably dont want that!
        light_dot = light_dot * 0.50
        
        #if (current_object_name == 'talojota'):
        #    print( str(face['color_index']) + ':' + str(face['nr_of_shades']))
        
        face['color_index'] = int((light_dot) * face['nr_of_shades']) + face['color_index']
    
    return (view_faces, view_vertices)



def project_triangles(view_faces, view_vertices):

    projected_faces = copy.deepcopy(view_faces)
    projected_vertices = []
    
    # We calculate the sum of z for every face
    for face in projected_faces:
        face_vertex_indices = face['vertex_indices']
        
        vertex1 = view_vertices[face_vertex_indices[0]]
        vertex2 = view_vertices[face_vertex_indices[1]]
        vertex3 = view_vertices[face_vertex_indices[2]]
        
        sum_of_z = vertex1[2] + vertex2[2] + vertex3[2]
        face['sum_of_z'] = sum_of_z
    
    # Projection of the vertices of the visible faces
    for vertex in view_vertices:
        x_view = vertex[0]
        y_view = vertex[1]
        z_view = vertex[2]
        
        fov_mult = math.tan(fov_degrees/2 * math.pi/180)
        
        # Note: since 'forward' is negative Z -for the object in front of the camera- we want to divide by negative z 
        x_proj = x_view / (-z_view*fov_mult)
        y_proj = y_view / (-z_view*fov_mult)
        
        projected_vertices.append((x_proj, y_proj))
        
    return (projected_faces, projected_vertices)

'''    
def intersection_point(vi1, vi2, vi3, vi4, pv):
    v1 = pv[vi1]
    v2 = pv[vi2]
    v3 = pv[vi3]
    v4 = pv[vi4]
    
    # judge if line (v1,v2) intersects with line(v3,v4)
    
    d = (v4[1]-v3[1])*(v2[0]-v1[0])-(v4[0]-v3[0])*(v2[1]-v1[1])
    n_a = (v4[0]-v3[0])*(v1[1]-v3[1])-(v4[1]-v3[1])*(v1[0]-v3[0])
    n_b = (v2[0]-v1[0])*(v1[1]-v3[1])-(v2[1]-v1[1])*(v1[0]-v3[0])

    if (d != 0):
        # The line segments are *not* parallel
        u_a = n_a / d
        u_b = n_b / d
    
        if (u_a >= 0 and u_a <= 1) and (u_b >= 0 and u_b <= 1):
            point_x = (u_a * (v2[0]-v1[0])) + v1[0]
            point_y = (u_a * (v2[1]-v1[1])) + v1[1]
            point = (point_x, point_y)
            
            # print("intersection: " + str(v1) + "->" + str(v2) + "  " + str(v3) + "->" + str(v4) + "(" + str(u_a) + ',' + str(u_b) + ') ==> ' + str(point))
            
            return point
    else:
        # The line segments are parallel
        # FIXME: check if n_a and n_b are both 0, if so: the line segments are coincident! -> but we need to know where the start/end
        return None
    
    return None
    
def determine_triangle_2d_intersections_and_split(projected_faces, projected_vertices, lit_view_faces, lit_view_vertices, camera_info):

    # Background: Splitting overlapping triangles: 
    # 
    # We want to split triangles when they overlap (in camera view) with another triangle. The one in the BACK will have to be split.
    # The tricky part is that knowing which triangle is in the BACK is hard to do when you are in 2D projected space.
    # We need to know (for each pair of triangles) if there are overlapping points, and if there are, which point is closer.
    #
    # We can choose any overlapping point really (IMPORTANT: we are ASSUMING the triangles DONT intersect in 3D space!).
    # In projected space, its easier to know the *intersection points* of the two triangles. But we somehow need to calculate the
    # world coordinates of these intersection points. We know at which (x/y) *ANGLE* of the camera-view these intersection points lie.
    # We can determine a 3D vector/DIRECTION (given the camera focal length) for each intersection point.
    # If we regard the two triangles as *3D planes* we can calculate the intersection point in 3D for both trianles/planes.
    
    # Split 2D triangles on overlap: https://stackoverflow.com/questions/5654831/split-triangles-on-overlap
    # Detect triangle-trianle intersections: https://stackoverflow.com/questions/1585459/whats-the-most-efficient-way-to-detect-triangle-triangle-intersections
    # Point between line and polygon in 3D: https://stackoverflow.com/questions/47359985/shapely-intersection-point-between-line-and-polygon-in-3d

    debug_intersection_points = []
    pv = projected_vertices
    for i, face1 in enumerate(projected_faces):
        for j, face2 in enumerate(projected_faces):
        
            # FIXME: CHECK: is it really better if we do not try to find intersection of faces that are part of the *SAME* object?
            #         What if an object is not convex? Like the trees? Will sum_of_z be good enough?

            if j > i and face1['obj_name'] != face2['obj_name']:
                f1_v = face1['vertex_indices']
                f2_v = face2['vertex_indices']
                pt = None
                if pt is None: pt = intersection_point(f1_v[0],f1_v[1], f2_v[0],f2_v[1], pv)
                if pt is None: pt = intersection_point(f1_v[0],f1_v[1], f2_v[0],f2_v[2], pv)
                if pt is None: pt = intersection_point(f1_v[0],f1_v[1], f2_v[1],f2_v[2], pv)
                
                if pt is None: pt = intersection_point(f1_v[0],f1_v[2], f2_v[0],f2_v[1], pv)
                if pt is None: pt = intersection_point(f1_v[0],f1_v[2], f2_v[0],f2_v[2], pv)
                if pt is None: pt = intersection_point(f1_v[0],f1_v[2], f2_v[1],f2_v[2], pv)

                if pt is None: pt = intersection_point(f1_v[1],f1_v[2], f2_v[0],f2_v[1], pv)
                if pt is None: pt = intersection_point(f1_v[1],f1_v[2], f2_v[0],f2_v[2], pv)
                if pt is None: pt = intersection_point(f1_v[1],f1_v[2], f2_v[1],f2_v[2], pv)
                
                if (pt is not None):
                    #print(face1['obj_name'] + '(' + str(i) + ') > ' + face2['obj_name'] + '(' + str(j) +  '):' + str(pt))
                    
                    if (DRAW_INTERSECTION_POINTS):
                        debug_intersection_points.append(pt)
                    
                    # Now that we know there is a 2D-point of intersection between the two faces, we need to calculate the corresponding TWO 3D-points
                    
                    # FIXME: implement this!

                    #     - calculate the 3D intersection POINTS (2x) between this 3D-direction and the two PLANES of the two triangles
                    #     - mark the relationship between the two triangles (one in front of the other)
                    #     - MAYBE: already split the triangles?


                    #    for face in projected_faces:
                    #        # if face['orig_face_index'] == 3:  # Bottom floor triangle
                    #            
                    #        if (False and DEBUG_SORTING):
                    #            if face['orig_face_index'] == 11:  # Front wall of building
                    #                if ('in_front_of' not in face):
                    #                    face['in_front_of'] = {}
                    #                face['in_front_of'][3] = True

    # FIXME: we are NOT SPLITTING YET!
    # - DONT split triangles from: WINDOWS, SHIP and maybe TREES!
    
    split_projected_faces = projected_faces
    split_projected_verticed = projected_vertices

    return (split_projected_faces, split_projected_verticed, debug_intersection_points)
'''

def is_2d_vertex_inside_edge(combined_vertices, vertex_index, edge_name):

    vertex = combined_vertices[vertex_index]

    x = vertex[0]
    y = vertex[1]
    
    vertex_is_inside = True
    
    if edge_name == 'LEFT':
        if x < LEFT_EDGE_X:
            vertex_is_inside = False
    elif edge_name == 'RIGHT':
        if x > RIGHT_EDGE_X:
            vertex_is_inside = False
    elif edge_name == 'BOTTOM':
        if y < BOTTOM_EDGE_Y:
            vertex_is_inside = False
    elif edge_name == 'TOP':
        if y > TOP_EDGE_Y:
            vertex_is_inside = False
            
    return vertex_is_inside
    

def clip_2d_vertex_against_edge(combined_vertices, inside_vertex_index, outside_vertex_index, edge_name, created_vertices_by_code):

    lookup_code = str(inside_vertex_index) + '::' + str(outside_vertex_index) + '::' + edge_name
    
    clipped_vertex_index = None
    if (lookup_code in created_vertices_by_code):
        # We already clipped this vertex against this edge, so we re-use that vertex
        clipped_vertex_index = created_vertices_by_code[lookup_code]
    else:
        # We have not yet clipped this vertex against this edge, so we create a new vertex
        
        inside_vertex = combined_vertices[inside_vertex_index]
        outside_vertex = combined_vertices[outside_vertex_index]

        if edge_name == 'LEFT':
            percentage_to_keep = (inside_vertex[0] - LEFT_EDGE_X) / (inside_vertex[0] - outside_vertex[0])
            y_clipped = inside_vertex[1] + (outside_vertex[1] - inside_vertex[1]) * percentage_to_keep
            clipped_vertex = (LEFT_EDGE_X, y_clipped)
        elif edge_name == 'RIGHT':
            percentage_to_keep = (RIGHT_EDGE_X - inside_vertex[0]) / (outside_vertex[0] - inside_vertex[0])
            y_clipped = inside_vertex[1] + (outside_vertex[1] - inside_vertex[1]) * percentage_to_keep
            clipped_vertex = (RIGHT_EDGE_X, y_clipped)
        elif edge_name == 'BOTTOM':
            percentage_to_keep = (inside_vertex[1] - BOTTOM_EDGE_Y) / (inside_vertex[1] - outside_vertex[1])
            x_clipped = inside_vertex[0] + (outside_vertex[0] - inside_vertex[0]) * percentage_to_keep
            clipped_vertex = (x_clipped, BOTTOM_EDGE_Y)
        elif edge_name == 'TOP':
            percentage_to_keep = (TOP_EDGE_Y - inside_vertex[1]) / (outside_vertex[1] - inside_vertex[1])
            x_clipped = inside_vertex[0] + (outside_vertex[0] - inside_vertex[0]) * percentage_to_keep
            clipped_vertex = (x_clipped, TOP_EDGE_Y)
        
        clipped_vertex_index = len(combined_vertices)
        combined_vertices.append(clipped_vertex)
    
        created_vertices_by_code[lookup_code] = clipped_vertex_index
        
    return clipped_vertex_index
    
    
def clip_face_against_edge(non_clipped_face, combined_vertices, edge_name, created_vertices_by_code):
    clipped_faces = []

    # We need to check which of these vertices are INSIDE and OUTSIDE of the plane/edge we are clipping against
    
    inside_vertex_nrs = []
    outside_vertex_nrs = []
    inside_vertex_indices = []
    outside_vertex_indices = []
    for vertex_nr in range(3):
        non_clipped_vertex_index = non_clipped_face['vertex_indices'][vertex_nr]
        
        vertex_is_inside = is_2d_vertex_inside_edge(combined_vertices, non_clipped_vertex_index, edge_name)

        if vertex_is_inside:
            # Since this is an inside vertex, there is no need to clip it, so we just copy it
            inside_vertex_nrs.append(vertex_nr)
            inside_vertex_indices.append(non_clipped_vertex_index)
        else:
            # We clip the 2d vertex against the edge
            outside_vertex_nrs.append(vertex_nr)
            outside_vertex_indices.append(non_clipped_vertex_index)
    
    
    if (len(inside_vertex_indices) == 0):
        # The triangle is completely outside the edge, we dont add it
        pass
    elif (len(inside_vertex_indices) == 3):
        # The triangle is completely inside the edge, we add it as-is
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_faces.append(clipped_face)
    elif (len(inside_vertex_indices) == 1):
        # Out triangle gets shorter, so we return one smaller triangle
        
        if (outside_vertex_nrs[0] == 0 and outside_vertex_nrs[1] == 2):
            # We need to switch the outside vertices to preserve the order
            outside_vertex_indices.reverse()
            outside_vertex_nrs.reverse()
            
        clipped_vertex_index_0 = clip_2d_vertex_against_edge(combined_vertices, inside_vertex_indices[0], outside_vertex_indices[0], edge_name, created_vertices_by_code)
        clipped_vertex_index_1 = clip_2d_vertex_against_edge(combined_vertices, inside_vertex_indices[0], outside_vertex_indices[1], edge_name, created_vertices_by_code)
        
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_face['vertex_indices'] = [inside_vertex_indices[0], clipped_vertex_index_0, clipped_vertex_index_1]
        clipped_face['is_clipped'] = True
        if (DEBUG_CLIP_COLORS):
            clipped_face['color_index'] = 8
        clipped_faces.append(clipped_face)
    elif (len(inside_vertex_indices) == 2):
        # We have a quad we have to split into two triangles
        
        if (inside_vertex_nrs[0] == 0 and inside_vertex_nrs[1] == 2):
            # We need to switch the inside vertices to preserve the order
            inside_vertex_indices.reverse()
            inside_vertex_nrs.reverse()
            
        # First triangle
        clipped_vertex_index_1 = clip_2d_vertex_against_edge(combined_vertices, inside_vertex_indices[1], outside_vertex_indices[0], edge_name, created_vertices_by_code)
        
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_face['vertex_indices'] = [clipped_vertex_index_1, inside_vertex_indices[0], inside_vertex_indices[1]]
        clipped_face['is_clipped'] = True
        if (DEBUG_CLIP_COLORS):
            clipped_face['color_index'] = 9
        clipped_faces.append(clipped_face)
        
        # Second triangle
        clipped_vertex_index_0 = clip_2d_vertex_against_edge(combined_vertices, inside_vertex_indices[0], outside_vertex_indices[0], edge_name, created_vertices_by_code)
        
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_face['vertex_indices'] = [clipped_vertex_index_0, inside_vertex_indices[0], clipped_vertex_index_1]
        clipped_face['is_clipped'] = True
        if (DEBUG_CLIP_COLORS):
            clipped_face['color_index'] = 10
        clipped_faces.append(clipped_face)

    return clipped_faces


def camera_clip_projected_triangles(projected_faces, projected_vertices):

    camera_clipped_projected_faces = []
    
    camera_clipped_projected_vertices = []
    for projected_vertex in projected_vertices:
        camera_clipped_projected_vertices.append((projected_vertex[0], projected_vertex[1]))
    # REMOVE OLD: camera_clipped_projected_vertices = copy.deepcopy(projected_vertices)
    
    edge_names = ['LEFT', 'TOP', 'RIGHT', 'BOTTOM']

    # We KEEP the old vertices! (even though they are all not being used at the end!
    combined_vertices = camera_clipped_projected_vertices

    # This is a dict where we record all vertices we created by a deterministic 'code':
    #    "<inside_vertex_index>::<outside_vertex_index>::<EDGENAME>" which maps to the created_vertex_index
    # That way we can find already created vertices and therefore re-use them
    created_vertices_by_code = {}
    
    # We determine -for each face- whether it should be clipped against the edges of the screen
    for non_clipped_face in projected_faces:

        # We start with the non-clipped face we want to clip along all 4 edges
        queue_faces = [ non_clipped_face ]
        
        for edge_name in edge_names:
        
            #if (edge_name == 'BOTTOM'):
            #    continue
            
            clipped_faces_against_this_edge = []
            for queue_face in queue_faces:
                
                # The clipped_vertices is an OUPUT vertex-array that gets extended each time!
                # We *extend* clipped_faces_against_this_edge here
                clipped_faces_against_this_edge += clip_face_against_edge(queue_face, combined_vertices, edge_name, created_vertices_by_code)

            # The output faces (left over after clipping) become the input faces for the next edge
            queue_faces = clipped_faces_against_this_edge
            # print('After clipping against ' + edge_name + ':' + str(json.dumps(queue_faces,indent=4)))
    
            
        
        # After clipping against all 4 edges we are left with only clipped faces in the queue
        camera_clipped_projected_faces += queue_faces
                
    return (camera_clipped_projected_faces, camera_clipped_projected_vertices)
    

def slope2bytes(slope):
    x1 = (slope / 2)
    x32 = 0x00
    if x1 >= 32 or x1 < -32:
        x1 /= 32
        x32 = 0x80
    x1 *= 512 # move significant fractional part to whole number
    #print(round(x1))
    b1 = bytearray(round(x1).to_bytes(2, 'little', signed=True))
    b1[1] &= 0x7f
    b1[1] |= x32
    return b1


# TODO: in the end we (ideally) dont want to do ANY sorting! So this should evenually be removed!
def compare_faces(face_a, face_b):
    
    result = None

    #if ('in_front_of' in face_a):
    #    if (face_b['orig_face_index'] in face_a['in_front_of']):
    #        return -1
            
    #if ('in_front_of' in face_b):
    #    if (face_a['orig_face_index'] in face_b['in_front_of']):
    #        return 1

    obj_name_a = face_a['obj_name']
    obj_name_b = face_b['obj_name']
    if (obj_name_a != obj_name_b):
        avg_z_a = avg_z_per_object[obj_name_a]
        avg_z_b = avg_z_per_object[obj_name_b]        
        if avg_z_a == avg_z_b:
            result = 0
        if avg_z_a < avg_z_b:
            result = 1
        if avg_z_a > avg_z_b:
            result = -1
    else:
        # FIXME: HACK! This is a workaround for sorting the underside of the large ship ('Sippi'). We first look at the material name to sort (POHJA always trumps COLOR00).
        if (obj_name_a == 'Sippi'):
        
            if (face_a['material_name'] == 'POHJA') and (face_b['material_name'] == 'COLOR00'):
                return -1
            elif (face_a['material_name'] == 'COLOR00') and (face_b['material_name'] == 'POHJA'):
                return 1
            else:
                if face_a['sum_of_z'] == face_b['sum_of_z']:
                    result = 0
                if face_a['sum_of_z'] < face_b['sum_of_z']:
                    result = 1
                if face_a['sum_of_z'] > face_b['sum_of_z']:
                    result = -1
        else:
            # TODO: this is our 'fallback' method: within an object we look at the sum_of_z of each face (better to use the original (ordered) polygon lists
            if face_a['sum_of_z'] == face_b['sum_of_z']:
                result = 0
            if face_a['sum_of_z'] < face_b['sum_of_z']:
                result = 1
            if face_a['sum_of_z'] > face_b['sum_of_z']:
                result = -1
            
    if (DEBUG_RESERSE_SORTING):
        result = -result
            
    return result
 
compare_key = cmp_to_key(compare_faces)

def projected_to_screen(projected_x, projected_y):
    screen_x = round(projected_x*projection_to_screen_scale + center_offset[0])
    screen_y = round(projected_y*projection_to_screen_scale + center_offset[1])
    # Note: we also flip the y here!
    screen_y = screen_height - screen_y
    return (screen_x, screen_y)
    

def sort_faces_scale_to_screen_and_check_visibility(projected_vertices, faces):

    # The vertices are scaled up for the (pygame) screen
    screen_vertices = []
    for projected_vertex in projected_vertices:
        (screen_x, screen_y) = projected_to_screen(projected_vertex[0], projected_vertex[1])
        screen_vertex = [
            screen_x,
            screen_y,
        ]
        screen_vertices.append(screen_vertex)
    
    sorted_faces = sorted(faces, key=compare_key, reverse=True)

    # TODO: CHECK: is this the correct way of clearing an indexed color buffer?
    check_triangle_visibility_buffer.fill(255*256)
    for face_index, face in enumerate(sorted_faces):

        # We add the first vertex at the end, since pygame wants polygon to draw back to the beginning point
        face_vertex_indices = face['vertex_indices'] + [face['vertex_indices'][0]]
        
        # We use the face_index as 'color'. So we can later on check whether a triangle has effectively changed any pixels (aka is visible)
        if (USE_FX_POLY_FILLER_SIM):
            fx_sim_draw_polygon(check_triangle_visibility_buffer, face_index, face['vertex_indices'], screen_vertices, {}, None)
        else:
            pygame.draw.polygon(check_triangle_visibility_buffer, face_index, [screen_vertices[i] for i in face_vertex_indices], 0)
        
    # Checking all pixels in the check_triangle_visibility_buffer and see which face_indexes are still in there. We should ONLY draw these!
    visible_face_indexes = {}
    
    black_pixels = 320*150*[0]
    
    check_pxarray = pygame.PixelArray(check_triangle_visibility_buffer)
    
    nr_of_black_pixels_found = 0
    for y in range(screen_height):
        for x in range(screen_width):
            visible_face_index = check_pxarray[x,y]
            visible_face_indexes[visible_face_index] = True
            if (visible_face_index == 255*256):
                nr_of_black_pixels_found += 1
                black_pixels[y*320+x] = 1
                
    if nr_of_black_pixels_found > 0:
        if (PRINT_WARNINGS):
            print("WARNING: FOUND BLACK PIXELS: " + str(nr_of_black_pixels_found))
        
    check_pxarray.close()
    
    return (screen_vertices, sorted_faces, visible_face_indexes, black_pixels)

def faces_share_edge(face_a, face_b):

    vertex_indices_a = face_a['vertex_indices']
    vertex_indices_b = face_b['vertex_indices']
    
    if (vertex_indices_a[0] in vertex_indices_b and vertex_indices_a[1] in vertex_indices_b):
        return True
    if (vertex_indices_a[0] in vertex_indices_b and vertex_indices_a[2] in vertex_indices_b):
        return True
    if (vertex_indices_a[1] in vertex_indices_b and vertex_indices_a[2] in vertex_indices_b):
        return True

    return False



def find_connected_faces_and_put_in_cluster(face, cluster, sorted_faces):

    # We mark this face as in this cluster and it to the cluster
    face['cluster_id'] = cluster['id']
    cluster['faces'].append(face)

    if ('merge_with_faces' in face):
        for face_index in face['merge_with_faces']:
            
            face_to_merge_with = sorted_faces[face_index]
            
            if ('cluster_id' not in face_to_merge_with):
                find_connected_faces_and_put_in_cluster(face_to_merge_with, cluster, sorted_faces)

def create_edge(from_vertex_index, to_vertex_index):
 
    edge_identifier = None
    if (from_vertex_index < to_vertex_index):   
        edge_identifier = str(from_vertex_index) + '::' + str(to_vertex_index)
    else:
        edge_identifier = str(to_vertex_index) + '::' + str(from_vertex_index)
 
    edge = {
        'identifier' : edge_identifier,
        'from_vertex_index' : from_vertex_index,
        'to_vertex_index' : to_vertex_index,
    }
    return edge


def second_vertex_can_be_removed(vertex_indices, lies_on_screen_edges_by_vertex_index):

    nr_of_vertices_per_edge = {}
    # Loop through the first 3 vertices
    for vertex_nr in range(3):
        vertex_index = vertex_indices[vertex_nr]
        # screen_vertex = screen_vertices[]
        
        if (vertex_index in lies_on_screen_edges_by_vertex_index):
            for edge_name in lies_on_screen_edges_by_vertex_index[vertex_index]:
                if (edge_name not in nr_of_vertices_per_edge):
                    nr_of_vertices_per_edge[edge_name] = 0
                nr_of_vertices_per_edge[edge_name] += 1
                
                # If all three vertices lie on the same edge, we assume we can remove the middle (= second) one
                if nr_of_vertices_per_edge[edge_name] == 3:
                    return True
        else:
            # One of the three first vertices does not lie at all on a screen edge, so we cant remove the second vertex
            return False
            
    return False

    
def first_and_second_vertex_have_same_x_and_y(vertex_indices, screen_vertices):

    first_vertex = screen_vertices[vertex_indices[0]]
    second_vertex = screen_vertices[vertex_indices[1]]
    
    if (first_vertex[0] == second_vertex[0] and first_vertex[1] == second_vertex[1]):
        #print(str(first_vertex) + '-->' + str(second_vertex))
        return True
    else:
        return False

def combine_faces (screen_vertices, sorted_faces):


# FIXME: what if somehow the SORTING of the to-be-combined faces is DIFFERENT?

    # For each face we try to find another face (for now only triangles) to see if shares an edge with another face
    # Both faces have to be:
    #   - Not been marked as merged already
    #   - Are not the same face
    #   - Have the same color_index
    #   - Have the same orig_face_index (and therefore the same normal_index!)
    #   - Share an edge (two vertices are the same)
    
    for face_a_index, face_a in enumerate(sorted_faces):
        
        # FIXME: this can be done much FASTER! (for example by keeping a map/dict per vertex_index of all triangles that use that vertex)
        for face_b_index, face_b in enumerate(sorted_faces):
            if face_a_index >= face_b_index:
                continue
                
            if (face_a['color_index'] != face_b['color_index']):
                continue

            # The orig_face_index indicates the original face we got from Blender/the original demo files. We want these to be the same. 
            # We might not need this restriction, but its an easy way to know that two triangles "belong toghether".
            if (face_a['orig_face_index'] != face_b['orig_face_index']):
                continue
                
            if (not faces_share_edge(face_a, face_b)):
                continue
            
            # print("Found mergable faces!")
            
            if ('merge_with_faces' not in face_a):
                face_a['merge_with_faces'] = []
            if ('merge_with_faces' not in face_b):
                face_b['merge_with_faces'] = []
                
            face_a['merge_with_faces'].append(face_b_index)
            face_b['merge_with_faces'].append(face_a_index)
    
    # Search for clusters of faces to be merged
    #   All triangles that are directly or indirectly connected below to a 'cluster': they have to be joined to form a new (larger) polygon
    cluster_id = 0   # The cluster_id is going to be the new (and combined) polygon id
    clusters = []
    for face_index, face in enumerate(sorted_faces):
        
        if ('cluster_id' not in face):
            cluster = {
                'id' : cluster_id,
                'faces' : [],                
                'edges' : {},
            }
            # IMPORTANT: if a triangle is not connected to anything it becomes its own cluster (of *one* triangle)
            find_connected_faces_and_put_in_cluster(face, cluster, sorted_faces)
            
            clusters.append(cluster)
            cluster_id += 1
            

    merged_faces = []
    for cluster in clusters:
        edges = cluster['edges']
        for face in cluster['faces']:
            vertex_indices = face['vertex_indices']
            
            from_vertex_index = vertex_indices[0]
            to_vertex_index = vertex_indices[1]
            edge = create_edge(from_vertex_index, to_vertex_index)
            if (edge['identifier'] not in edges):
                edges[edge['identifier']] = edge
            else:
                # If an edge is already in the cluster and we see it again, it means its an inner-edge and we should remove it
                del edges[edge['identifier']]
    
            from_vertex_index = vertex_indices[1]
            to_vertex_index = vertex_indices[2]
            edge = create_edge(from_vertex_index, to_vertex_index)
            if (edge['identifier'] not in edges):
                edges[edge['identifier']] = edge
            else:
                # If an edge is already in the cluster and we see it again, it means its an inner-edge and we should remove it
                del edges[edge['identifier']]
            
            from_vertex_index = vertex_indices[2]
            to_vertex_index = vertex_indices[0]
            edge = create_edge(from_vertex_index, to_vertex_index)
            if (edge['identifier'] not in edges):
                edges[edge['identifier']] = edge
            else:
                # If an edge is already in the cluster and we see it again, it means its an inner-edge and we should remove it
                del edges[edge['identifier']]
    
        #print('>==========')
            
        #print(json.dumps(cluster['faces'], indent = 4))
        #print(json.dumps(cluster['edges'], indent = 4))
        
        edges_by_from_vertex_index = {}
        for edge_identifier in edges:
            edge = edges[edge_identifier]
            from_vertex_index = edge['from_vertex_index']
            edges_by_from_vertex_index[from_vertex_index] = edge
            
        #print(json.dumps(edges_by_from_vertex_index, indent = 4))
        
# FIXME: CHECK is it correct that we take the first face in the cluster (as our base for the new face)? What about sorting?
        merged_face = copy.deepcopy(cluster['faces'][0])
        merged_face['vertex_indices'] = []
        
        # We just take the first edge as our starting
        starting_edge_identifier = list(edges.keys())[0]
        starting_edge = edges[starting_edge_identifier]
        current_edge = starting_edge
        
        # We keep on adding vertices until we reach the start again
        while(current_edge['to_vertex_index'] != starting_edge['from_vertex_index']):
            #print('current_edge' + str(current_edge))
        
            merged_face['vertex_indices'].append(current_edge['from_vertex_index'])

            # We go to the edge that starts with the vertex where the currect edge ends
            current_edge = edges_by_from_vertex_index[current_edge['to_vertex_index']]
            
        # We add the last vertex
        merged_face['vertex_indices'].append(current_edge['from_vertex_index'])
        
        #print(merged_face['vertex_indices'])
        
        merged_faces.append(merged_face)
        
        #print('<==========')
            
            
    # After merging there will be many faces that have 'redundant' vertices: vertices that lie in-line of each other
    # We want to remove any unneeded vertices: when 3 (or more) lie on the same screen-edge we can remove all but the first and last

# REMOVE/EDIT COMMENT!    
    # Important: sometimes a vertex has been clipped against TWO screen-edges! We keep track of this in vertex[2] (=dict containing lies_on_screen_edges) so we need to take this into account!
    
    lies_on_screen_edges_by_vertex_index = {}
    
    for merged_face in merged_faces:
        face_min_x = None
        face_max_x = None
        face_min_y = None
        face_max_y = None
        for vertex_index in merged_face['vertex_indices']:
            screen_vertex = screen_vertices[vertex_index]
            vertex_is_lying_on_edges = []
            
            x = screen_vertex[0]
            y = screen_vertex[1]
            
            if (face_max_x is None or x > face_max_x):
                face_max_x = x
            if (face_min_x is None or x < face_min_x):
                face_min_x = x
                
            if (face_max_y is None or y > face_max_y):
                face_max_y = y
            if (face_min_y is None or y < face_min_y):
                face_min_y = y
#  FIXME: HARDCODED COORDINATES!
            if (x == 0):
                vertex_is_lying_on_edges.append('LEFT')
            if (x == 320):
                vertex_is_lying_on_edges.append('RIGHT')
            if (y == 0):
                vertex_is_lying_on_edges.append('TOP')
            if (y == 150):
                vertex_is_lying_on_edges.append('BOTTOM')
                
            if (len(vertex_is_lying_on_edges) > 0):
                lies_on_screen_edges_by_vertex_index[vertex_index] = {}
                for edge_name in vertex_is_lying_on_edges:
                    lies_on_screen_edges_by_vertex_index[vertex_index][edge_name] = True
                    
        if (face_min_x == face_max_x) or (face_min_y == face_max_y):
            if (PRINT_ERRORS):
                print("ERROR: face is invalid because it has no width or height!")
            merged_face['invalid'] = True
    
    cleaned_merged_faces = []
    for merged_face in merged_faces:
        if ('invalid' in merged_face):
            continue
    
        cleaned_merged_face = copy.deepcopy(merged_face)

        # We first check if there are any vertices that lie on any screen edge at all for this face
        there_are_vertices_that_lie_on_any_screen_edge = False
        first_edge_name_found = None
        merged_vertex_indices = merged_face['vertex_indices']
        for vertex_index in merged_vertex_indices:
            if (vertex_index in lies_on_screen_edges_by_vertex_index):
                there_are_vertices_that_lie_on_any_screen_edge = True
                first_edge_name_found = list(lies_on_screen_edges_by_vertex_index[vertex_index].keys())[0]
                break
        
        if (there_are_vertices_that_lie_on_any_screen_edge):
            # There are vertices on the screen edges, so we need to cleanup up this face
            
            cleaned_vertex_indices = copy.deepcopy(merged_vertex_indices)
            
            # First we rotate the vertex list so we know that there is a vertex at the start of the list that is the first in a series of vertices that lie on the same screen edge

            while(True):

                first_screen_vertex_index = cleaned_vertex_indices[0]
                last_screen_vertex_index = cleaned_vertex_indices[-1]
                
                if (first_screen_vertex_index in lies_on_screen_edges_by_vertex_index and first_edge_name_found in lies_on_screen_edges_by_vertex_index[first_screen_vertex_index] and
                    not (last_screen_vertex_index in lies_on_screen_edges_by_vertex_index and first_edge_name_found in lies_on_screen_edges_by_vertex_index[last_screen_vertex_index])):
                    # We rotated enough so that the first vertex lies on the edge but the last vertex doesnt, meaning: our list starts with a vertex that is the first in a series of vertices that lie on the same screen edge
                    break
                else:
                    cleaned_vertex_indices = cleaned_vertex_indices[1:] + cleaned_vertex_indices[:1]
                    
            # Look ahead 3 vertices: if the second can be removed, then we remove it. Otherwise we rotate. We do this until you reach the first vertex index one again
# FIXME: POSSIBLE ISSUE: 2 vertices AND 2 edges in SEQUENCE! (TOP, RIGHT) -> (TOP, RIGHT) -> (TOP, RIGHT) ?
            #print(cleaned_vertex_indices)
            #print_vertices(cleaned_vertex_indices, screen_vertices)
            
            first_screen_vertex_index = cleaned_vertex_indices[0]
            while(True):
                
                if (second_vertex_can_be_removed(cleaned_vertex_indices, lies_on_screen_edges_by_vertex_index)):
                    cleaned_vertex_indices.pop(1)
                elif (first_and_second_vertex_have_same_x_and_y(cleaned_vertex_indices, screen_vertices)):
                    if (PRINT_WARNINGS):
                        print("WARNING: screen vertices have the same x AND y coordinate!")
                    cleaned_vertex_indices.pop(1)
                    if (len(cleaned_vertex_indices) < 3):
                        if (PRINT_ERRORS):
                            print("ERROR: not enough vertices in face anymore!")
                        cleaned_merged_face['invalid'] = True
                        break
                else:
                    cleaned_vertex_indices = cleaned_vertex_indices[1:] + cleaned_vertex_indices[:1]
                    if (cleaned_vertex_indices[0] == first_screen_vertex_index):
                        break
            
            cleaned_merged_face['vertex_indices'] = cleaned_vertex_indices
            
        else:
            # There are no vertices on the screen edges, so nothting to cleanup up for this face
            pass

        if ('invalid' not in cleaned_merged_faces):
            cleaned_merged_faces.append(cleaned_merged_face)
            
    
    return cleaned_merged_faces
    

def add_face_with_frame_buffer(face_surface, frame_buffer):

    face_pxarray = pygame.PixelArray(face_surface)
    frame_pxarray = pygame.PixelArray(frame_buffer)
    
    for y in range(screen_height):
        for x in range(screen_width):
            face_pixel_idx = face_pxarray[x,y]
            
            frame_pixel_idx = frame_pxarray[x,y]
            
            frame_pxarray[x,y] = frame_pixel_idx + face_pixel_idx*64

    frame_pxarray.close()
    face_pxarray.close()


def top_vertices_are_at_the_start(top_vertex_indices, vertex_indices):
    
    # We check of all of the top vertex indices are in the first vertex indices
    for vertex_nr in range(len(top_vertex_indices)):
        if (top_vertex_indices[vertex_nr] not in vertex_indices[0:len(top_vertex_indices)]):
            return False
            
    return True
'''
    if len(top_vertex_indices) == 1:
        if top_vertex_indices[0] in vertex_indices[0:1]:
            return True
        else:
            return False
    elif len(top_vertex_indices) == 2:
        if (top_vertex_indices[0] in vertex_indices[0:2]) and (top_vertex_indices[1] in vertex_indices[0:2]):
            return True
        else:
            return False
        
    else:
        print("ERROR: we have more than TWO top vertices!!")
        return None
'''

def reset_fx_state(fx_state):
    fx_state = {
        'x1_pos' : int(256),  # This is a 11.9 fixed point value (so you should divide by 512 to get the real value)
        'x2_pos' : int(256),  # This is a 11.9 fixed point value (so you should divide by 512 to get the real value)
        'x1_incr' : int(0),   # This is a 6.9 fixed point value (so you should divide by 512 to get the real value)
        'x2_incr' : int(0),   # This is a 6.9 fixed point value (so you should divide by 512 to get the real value)
    }

def draw_fx_polygon_part(fx_state, frame_buffer, line_color, y_start, nr_of_lines_to_draw):

    for y_in_part in range(nr_of_lines_to_draw):
        y_screen = y_start + y_in_part

        # This is 'equivalent' of what happens when reading from DATA1
        fx_state['x1_pos'] += fx_state['x1_incr']
        fx_state['x2_pos'] += fx_state['x2_incr']
        
        x1 = int(fx_state['x1_pos'] / 512)
        x2 = int(fx_state['x2_pos'] / 512)
        
        if (x2-x1 < 0):
            if (PRINT_ERRORS):
                print("ERROR: NEGATIVE fill length!")
            return False
        
# FIXME: what if x2 and x1 are the same? Wont that result in a draw -of one pixel- IN REVERSE?
        pygame.draw.line(frame_buffer, line_color, (x1, y_screen), (x2-1, y_screen), 1)
        
        # This is 'equivalent' of what happens when reading from DATA0 (this (effectively) also increments y_in_part)
        fx_state['x1_pos'] += fx_state['x1_incr']
        fx_state['x2_pos'] += fx_state['x2_incr']
        
    return True


def print_vertices(vertex_indices, screen_vertices):
    to_print = []
    str_vertex_indices = []
    for vertex_index in vertex_indices:
        screen_vertex = screen_vertices[vertex_index]
        to_print.append(str(screen_vertex))
        str_vertex_indices.append(str(vertex_index))
    print(', '.join(to_print)+' - ('+','.join(str_vertex_indices)+')')



def convert_increment_to_incr_components(increment):
    # The incoming increment is a signed integer number 
    
    # We can only store 15 bit signed numbers. BUT we can multiply by 32 if it doesnt fit.
    
    # In other words: 
    # if the incremnt is smaller than -16384 or larger than +16383, we should divide the number by 32
    x32_or = 0x00
    incr_less_accurate = increment
    if (increment < -16384 or increment > 16383):
        increment = increment // 32
        x32_or = 0x80
        # The resulting (less accurate) signed number should be returned as incr_less_accurate
        incr_less_accurate = increment * 32

    incr_16bit = increment # this value has (potentially) been divided by 32
    if incr_16bit < 0:
        incr_16bit = 256*256 + incr_16bit
    incr_packed_low = incr_16bit % 256
    incr_packed_high = ((incr_16bit // 256) & 0x7f) | x32_or

    return (incr_less_accurate, incr_packed_low, incr_packed_high)


def fx_sim_draw_polygon(draw_buffer, line_color_index, vertex_indices, screen_vertices, polygon_type_stats, colors):

    # FIXME: this is a bit of an ugly workaround!
    line_color = None
    if (colors is not None):
        line_color = colors[line_color_index]
    else:
        line_color = line_color_index
        
    polygon_bytes = []

    # == Setup left and right lists ==
    # - Get top vertex (index)
    # - Get bottom vertex (index)
    # - Create left and right list
    #   - If there is one top vertex both lists share it, if not they have a separate one
    #   - If there is one bottom vertex both lists share it, if not they have a separate one
    
    top_y = None
    bottom_y = None
    
    # There can be 1-2 top and bottom vertices. We keep a record of them.
    top_vertex_indices = None
    bottom_vertex_indices = None
    
    for vertex_index in vertex_indices:
        screen_vertex = screen_vertices[vertex_index]
        
        vertex_y = screen_vertex[1]
        
        if (top_y is None or vertex_y < top_y):
            top_y = vertex_y
            top_vertex_indices = []  # We create a new list (removing any old candidates)
            top_vertex_indices.append(vertex_index)
        elif (vertex_y == top_y):
            top_vertex_indices.append(vertex_index)
            
        if (bottom_y is None or vertex_y > bottom_y):
            bottom_y = vertex_y
            bottom_vertex_indices = []  # We create a new list (removing any old candidates)
            bottom_vertex_indices.append(vertex_index)
        elif (vertex_y == bottom_y):
            bottom_vertex_indices.append(vertex_index)
            
    # We rotate the list of vertex indices until the top vertice(s) are at the start of the list
    done_rotating = top_vertices_are_at_the_start(top_vertex_indices, vertex_indices)
    while (not done_rotating):
        vertex_indices = vertex_indices[1:] + vertex_indices[:1]
        done_rotating = top_vertices_are_at_the_start(top_vertex_indices, vertex_indices)
        
    if (len(top_vertex_indices) > 2):
    
        #print_vertices(vertex_indices, screen_vertices)
            
        nr_of_vertices_to_remove = len(top_vertex_indices) - 2
        #print(str(vertex_indices)+'>>'+str(top_vertex_indices))
        while nr_of_vertices_to_remove > 0:
            if (PRINT_WARNINGS):
                print("WARNING: removing redundant top vertice!")
            vertex_indices.pop(1)
            nr_of_vertices_to_remove -= 1
            
        #print_vertices(vertex_indices, screen_vertices)
            
        if len(vertex_indices) < 3:
            if (PRINT_ERRORS):
                print("ERROR: less than 3 vertices left over.")
# FIXME: can we fix/prevent this?
            return None

    # If we have 2 top vertices we rotate once more (if we had more, we removed them), so the two top vertices are at either end of the list
    if (len(top_vertex_indices) >= 2):
        vertex_indices = vertex_indices[1:] + vertex_indices[:1]

    # print_vertices(vertex_indices, screen_vertices)
        
    # We create a left list and a right list of vertices (that contain the vertices that are that side of the polygon)
    left_vertices = []
    for vertex_index in vertex_indices:
        screen_vertex = screen_vertices[vertex_index]
        left_vertices.append(screen_vertex)
        # We keep adding vertices until we reach the (first) bottom vertex
        if (vertex_index in bottom_vertex_indices):
            break

    # If we have 1 top vertex we rotate once more, so the top vertex it at the end of the list
    if (len(top_vertex_indices) == 1):
        vertex_indices = vertex_indices[1:] + vertex_indices[:1]
        
    right_vertices = []
    vertex_indices.reverse()
    for vertex_index in vertex_indices:
        screen_vertex = screen_vertices[vertex_index]
        right_vertices.append(screen_vertex)
        # We keep adding vertices until we reach the (first) bottom vertex
        if (vertex_index in bottom_vertex_indices):
            break
    
    
    # == Drawing algo ==
    #  - Set x1 and x2 according to first in left/right list (NOTE: if the same we only have to export ONE in the data!)
    #  - set left and right indexes to 0 (n and m)
    #  - Calculate x1/x2 slopes by left[n+1]-left[n] and right[m+1]-right[m]
    #  - Calculate how many lines have to be drawn (is left[n+1] or right[n+1] top?)
    #  - draw the polygon part
    #  - increment n or m
    #  - set x1 or x2 position accordingly
    #  - set x1 incr or x2 incr accordingly
    #  - Calculate how many lines have to be drawn (is left[n+1] or right[n+1] top?)
    #  - Stop until left and right reach the end
    
    current_left_index = 0
    current_right_index = 0

    next_side_to_change_slope = None
    left_half_slope = None
    right_half_slope = None
    
    next_left_vertex = left_vertices[current_left_index+1]
    next_right_vertex = right_vertices[current_right_index+1]
    current_left_vertex = left_vertices[current_left_index]
    current_right_vertex = right_vertices[current_right_index]
    
    left_half_slope = int((next_left_vertex[0] - current_left_vertex[0]) / (next_left_vertex[1] - current_left_vertex[1]) * 256)
    right_half_slope = int((next_right_vertex[0] - current_right_vertex[0]) / (next_right_vertex[1] - current_right_vertex[1]) * 256)
    
    
    SINGLE_TOP_FREE_FORM_TYPE = 0x00
    DOUBLE_TOP_FREE_FORM_TYPE = 0x80
    
    # We take the top y as starting y position
    current_y_position = top_y

    left_pos = current_left_vertex[0]
    right_pos = current_right_vertex[0]
    
    fx_state['x1_pos'] = int(left_pos) * 512 + 256
    fx_state['x2_pos'] = int(right_pos) * 512 + 256
    
    polygon_type_identifier = ''
    if (len(top_vertex_indices) == 1):
        polygon_type_identifier += 'SINGLE_TOP'
        
# FIXME: for now we are ONLY doing free form types!
        polygon_bytes.append(SINGLE_TOP_FREE_FORM_TYPE)
        polygon_bytes.append(line_color_index)
        polygon_bytes.append(current_y_position)
        x1_pos_int = int(left_pos)
        polygon_bytes.append(x1_pos_int % 256)
        polygon_bytes.append(x1_pos_int // 256)
    else:
        polygon_type_identifier += 'DOUBLE_TOP'
        
# FIXME: for now we are ONLY doing free form types!
        polygon_bytes.append(DOUBLE_TOP_FREE_FORM_TYPE)
        polygon_bytes.append(line_color_index)
        polygon_bytes.append(current_y_position)
        x1_pos_int = int(left_pos)
        polygon_bytes.append(x1_pos_int % 256)
        polygon_bytes.append(x1_pos_int // 256)
        x2_pos_int = int(right_pos)
        polygon_bytes.append(x2_pos_int % 256)
        polygon_bytes.append(x2_pos_int // 256)

    (x1_incr, x1_incr_low, x1_incr_high) = convert_increment_to_incr_components(left_half_slope)
    fx_state['x1_incr'] = x1_incr
    polygon_bytes.append(x1_incr_low)
    polygon_bytes.append(x1_incr_high)
    
    (x2_incr, x2_incr_low, x2_incr_high) = convert_increment_to_incr_components(right_half_slope)
    fx_state['x2_incr'] = x2_incr
    polygon_bytes.append(x2_incr_low)
    polygon_bytes.append(x2_incr_high)
    
    nr_of_lines_to_draw_larger_than_63 = False
    
# FIXME!
#    do_print = False
#    if (line_color_index == 197 and current_y_position == 108):
#        do_print = True
        
# FIXME!
#    if (do_print):
#        return None
    
    #if (do_print):
    #    print("This is the one!")
    #    #print_vertices(vertex_indices, screen_vertices)
    #    print(left_vertices)
    #    print(right_vertices)
    
    while (True):
    
        # Check which vertex is next in line to change (looking at the y-coordinate): we have to draw until that y-line
        if (next_left_vertex[1] < next_right_vertex[1]):
            next_side_to_change_slope = 'left'
            nr_of_lines_to_draw = next_left_vertex[1] - current_y_position
        elif (next_left_vertex[1] > next_right_vertex[1]):
            next_side_to_change_slope = 'right'
            nr_of_lines_to_draw = next_right_vertex[1] - current_y_position
        else:
            # Both are at the same y, so they both have to change
            next_side_to_change_slope = 'both'
            nr_of_lines_to_draw = next_left_vertex[1] - current_y_position
            
        if (nr_of_lines_to_draw > 63):
            nr_of_lines_to_draw_larger_than_63 = True

        polygon_bytes.append(nr_of_lines_to_draw)

        if (not draw_fx_polygon_part(fx_state, draw_buffer, line_color, current_y_position, nr_of_lines_to_draw)):
            if (PRINT_ERRORS):
                print("ERROR: not adding polygon to polygon stream since it encountered an error during drawing!")
# FIXME: can we fix/prevent this?
            return None
        current_y_position += nr_of_lines_to_draw
        
        if ((current_right_index+1 == len(right_vertices)-1) and (current_left_index+1 == len(left_vertices)-1)):
            polygon_bytes.append(0x00)
            break

        if next_side_to_change_slope == 'right':
            polygon_type_identifier += '-CHANGE_RIGHT'
            polygon_bytes.append(0x02)
            
            # Change *right* slope
            current_right_index += 1
            
            next_right_vertex = right_vertices[current_right_index+1]
            current_right_vertex = right_vertices[current_right_index]
            
            #print(current_right_vertex)
            #print(next_right_vertex)

            polygon_part_height = next_right_vertex[1] - current_right_vertex[1]
            if (polygon_part_height <= 0):
                if (PRINT_ERRORS):
                    print("ERROR: not adding polygon to polygon stream since has a part with a zero or negative height!")
# FIXME: can we fix/prevent this?
                return None
            
            right_half_slope = int((next_right_vertex[0] - current_right_vertex[0]) / (polygon_part_height) * 256)
            
            (x2_incr, x2_incr_low, x2_incr_high) = convert_increment_to_incr_components(right_half_slope)
            fx_state['x2_incr'] = x2_incr
            polygon_bytes.append(x2_incr_low)
            polygon_bytes.append(x2_incr_high)
    
            # This is equivalent of what happens when setting the new x2_incr
            fx_state['x2_pos'] = int(fx_state['x2_pos'] / 512) * 512 + 256
            
        elif next_side_to_change_slope == 'left':
            polygon_type_identifier += '-CHANGE_LEFT'
            polygon_bytes.append(0x01)
            
            # Change *left* slope
            current_left_index += 1
            
            next_left_vertex = left_vertices[current_left_index+1]
            current_left_vertex = left_vertices[current_left_index]
            
            polygon_part_height = next_left_vertex[1] - current_left_vertex[1]
            if (polygon_part_height <= 0):
                if (PRINT_ERRORS):
                    print("ERROR: not adding polygon to polygon stream since has a part with a zero or negative height!")
# FIXME: can we fix/prevent this?
                return None
                
            left_half_slope = int((next_left_vertex[0] - current_left_vertex[0]) / (polygon_part_height) * 256)
            
            (x1_incr, x1_incr_low, x1_incr_high) = convert_increment_to_incr_components(left_half_slope)
            fx_state['x1_incr'] = x1_incr
            polygon_bytes.append(x1_incr_low)
            polygon_bytes.append(x1_incr_high)
            
            # This is equivalent of what happens when setting the new x1_incr
            fx_state['x1_pos'] = int(fx_state['x1_pos'] / 512) * 512 + 256
                        
        else:  # both
            polygon_type_identifier += '-CHANGE_BOTH'
            polygon_bytes.append(0x03)
            
            # -- Change *left* slope --
            current_left_index += 1
            
            next_left_vertex = left_vertices[current_left_index+1]
            current_left_vertex = left_vertices[current_left_index]

            polygon_part_height = next_left_vertex[1] - current_left_vertex[1]
            if (polygon_part_height <= 0):
                if (PRINT_ERRORS):
                    print("ERROR: not adding polygon to polygon stream since has a part with a zero or negative height!")
# FIXME: can we fix/prevent this?
                return None
                
            left_half_slope = int((next_left_vertex[0] - current_left_vertex[0]) / (polygon_part_height) * 256)
            
            (x1_incr, x1_incr_low, x1_incr_high) = convert_increment_to_incr_components(left_half_slope)
            fx_state['x1_incr'] = x1_incr
            polygon_bytes.append(x1_incr_low)
            polygon_bytes.append(x1_incr_high)
            
            # This is equivalent of what happens when setting the new x1_incr
            fx_state['x1_pos'] = int(fx_state['x1_pos'] / 512) * 512 + 256

            
            # -- Change *right* slope --
            current_right_index += 1
            
            next_right_vertex = right_vertices[current_right_index+1]
            current_right_vertex = right_vertices[current_right_index]
            
            polygon_part_height = next_right_vertex[1] - current_right_vertex[1]
            if (polygon_part_height <= 0):
                if (PRINT_ERRORS):
                    print("ERROR: not adding polygon to polygon stream since has a part with a zero or negative height!")
# FIXME: can we fix/prevent this?
                return None
                
            right_half_slope = int((next_right_vertex[0] - current_right_vertex[0]) / (polygon_part_height) * 256)
            
            (x2_incr, x2_incr_low, x2_incr_high) = convert_increment_to_incr_components(right_half_slope)
            fx_state['x2_incr'] = x2_incr
            polygon_bytes.append(x2_incr_low)
            polygon_bytes.append(x2_incr_high)
            
            # This is equivalent of what happens when setting the new x2_incr
            fx_state['x2_pos'] = int(fx_state['x2_pos'] / 512) * 512 + 256

#        print(str(fx_state['x1_incr'])+'..'+str(fx_state['x2_incr']))
            
    # -- TODO: This MAY beinteresting --
    # If all nr_of_lines_to_draw in the polygon are below 64, we can use the two higest bits (of the nr_of_lines_to_draw) to mark whether we should do L/R/Both/None for the next polygon part
    # So we want to know how many times it happens that we need more than 6 bit (>=64 lines to draw)
    #if (nr_of_lines_to_draw_larger_than_63):
    #    polygon_type_identifier += '-64+'
            
    if (polygon_type_identifier not in polygon_type_stats):
        polygon_type_stats[polygon_type_identifier] = 0
        
    polygon_type_stats[polygon_type_identifier] += 1
    
    return polygon_bytes

    

def draw_and_export(screen_vertices, sorted_faces, polygon_type_stats):

# FIXME: this sorter is probably the wrong way around now, since y is not flipped anymore in the projected_vertices!
    def y_sorter(item):
        return projected_vertices[item][1]

    # check_buffer_on_screen_x = 0
    # check_buffer_on_screen_y = 0
    # screen.blit(pygame.transform.scale(check_triangle_visibility_buffer, (screen_width*scale, screen_height*scale)), (check_buffer_on_screen_x, check_buffer_on_screen_y))
    
    '''
    # The vertices are scaled up for the (pygame) screen
    scaled_up_vertices = []
    for screen_vertex in screen_vertices:
        screen_x = screen_vertex[0]
        screen_y = screen_vertex[1]
        scaled_up_vertex = [
            screen_x*scale,
            screen_y*scale,
        ]
        scaled_up_vertices.append(scaled_up_vertex)
    '''
        
# FIXME: do we need to this this for each frame?
    reset_fx_state(fx_state)
    
    frame_bytes = []
    nr_of_polygons_in_frame = 0
    
    frame_buffer.fill((0,0,0))
    for face_index, face in enumerate(sorted_faces):
 
        color_idx = face['color_index']
        
        if (DEBUG_COLORS and not DEBUG_CLIP_COLORS):
            if DEBUG_COLOR_PER_ORIG_TRIANGLE:
                color_idx = face['orig_face_index'] % 64
            else:
                color_idx = face_index % 64
        
        if (DEBUG_SHOW_MERGED_FACES):
            if ('merge_with_faces' in face):
                color_idx = 250
                
        # We add the first vertex at the end, since pygame wants polygon to draw back to the beginning point
        face_vertex_indices = face['vertex_indices'] + [face['vertex_indices'][0]]
    
        if (DEBUG_COUNT_REDRAWS):
            # We draw the polygon to the face_buffer
            face_buffer.fill((0,0,0))
            
            if (USE_FX_POLY_FILLER_SIM):
                fx_sim_draw_polygon(face_buffer, 1, face['vertex_indices'], screen_vertices, {}, None)
            else:
                pygame.draw.polygon(face_buffer, 1, [screen_vertices[i] for i in face_vertex_indices], 0)
            add_face_with_frame_buffer(face_buffer, frame_buffer)
        else:
            # We draw the polygon to the screen
            if (USE_FX_POLY_FILLER_SIM):
            
# FIXME!
#                print_vertices(face['vertex_indices'], screen_vertices)
            
                polygon_bytes = fx_sim_draw_polygon(frame_buffer, color_idx, face['vertex_indices'], screen_vertices, polygon_type_stats, colors)
                # FIXME: do something REAL with the file_data!
                if polygon_bytes is None:
                    if (PRINT_WARNINGS):
                        print('WARNING: face did not result in polygon bytes!')
                        print(face)
                else:
                    nr_of_polygons_in_frame += 1
                    frame_bytes += polygon_bytes
# FIXME!
#                    print(polygon_bytes)
#                    pass
            else:
                pygame.draw.polygon(frame_buffer, colors[color_idx], [screen_vertices[i] for i in face_vertex_indices], 0)
            
        if (DEBUG_DRAW_TRIANGLE_BOUNDARIES):
            pygame.draw.polygon(frame_buffer, (0xFF, 0xFF,0x00), [screen_vertices[i] for i in face_vertex_indices], 1)
        
                
        
        if (DEBUG_SHOW_VERTEX_NRS):
            # FIXME: HACK: quick and dirty way of getting the 'center point' of a triangle/polygon
            center_point_x = 0
            center_point_y = 0
            for vertex_index in face['vertex_indices']:
                screen_vertex = screen_vertices[vertex_index]
                
                center_point_x += screen_vertex[0]
                center_point_y += screen_vertex[1]
                
            center_point_x = center_point_x /  len(face['vertex_indices'])
            center_point_y = center_point_y /  len(face['vertex_indices'])
            
            img = font.render(str(face_index), False, WHITE)
            frame_buffer.blit(img, (center_point_x, center_point_y))
            
            for vertex_nr, vertex_index in enumerate(face['vertex_indices']):
                screen_vertex = screen_vertices[vertex_index]
                
                vertex_color = debug_vertex_colors[vertex_nr]
                
                vertex_nr_point_x = (screen_vertex[0] - center_point_x) * 0.7 + center_point_x
                vertex_nr_point_y = (screen_vertex[1] - center_point_y) * 0.7 + center_point_y
                
                pygame.draw.rect(frame_buffer, vertex_color, pygame.Rect(vertex_nr_point_x, vertex_nr_point_y, 2, 2))
                
                img = font.render(str(vertex_index), False, WHITE)
                frame_buffer.blit(img, (vertex_nr_point_x, vertex_nr_point_y))
                
                
    frame_buffer_on_screen_x = 0
    frame_buffer_on_screen_y = 0
    screen.fill((0,0,0))
    screen.blit(pygame.transform.scale(frame_buffer, (screen_width*scale, screen_height*scale)), (frame_buffer_on_screen_x, frame_buffer_on_screen_y))
    
    # We add the number actual drawn polygons to the beginning of the frame_bytes
    frame_bytes.insert(0, nr_of_polygons_in_frame)
    
    return frame_bytes
    
    

# Main game loop
running = True


frame_nr = 1
# FIXME: we need proper interpolation! (now just dropping every other frame!
org_increment_frame_by = 2

# IMPORTANT: by taking every 7th frame (and exporting 4 times as much frames in Blender) we are effectively converting the 35fps frames to 20fps frames!
if SCENE == 'U2E':
    max_frame_nr = 1802*5
    org_increment_frame_by = 9
    
else:
    max_frame_nr = 522*2
    org_increment_frame_by = 7
    
increment_frame_by = org_increment_frame_by

if DEBUG_SORTING:
    #frame_nr = 1000
    #increment_frame_by = 1
#    frame_nr = 421            #  frame 421 is showing a large overdraw due to a large building in the background
#    frame_nr = 1      # ALWAYS *ODD*!!
    frame_nr = 944*17      # ALWAYS *ODD*!!
    # IMPORTANT: by taking every 7th frame (and exporting 4 times as much frames in Blender) we are effectively converting the 35fps frames to 20fps frames!
    max_frame_nr = 1802*17
#    max_frame_nr = 1802*4
#    increment_frame_by = 7

material_info = load_material_info()
mat_info = material_info['mat_info']
palette_colors = material_info['palette_colors']
colors = []

# HACK: see comment below
avg_z_per_object = {}

colors_12bit = []

for clr_idx, rgb64 in enumerate(palette_colors):

    # Color depth conversion: https://threadlocalmutex.com/?p=48
    
    r = rgb64['r']
    g = rgb64['g']
    b = rgb64['b']
    
    new_8bit_color = (None,None,None)
    
    if (CONVERT_COLORS_TO_12BITS):
    
        #if(FOCUS_ON_COLOR_TONE):  # This didnt give a good result
        if(False):
            
            if (r == 0 and g == 0 and b == 0):
                # Black is black anyway, we dont want to divide by 0
                best_4bit_color = (0,0,0)
                pass
            else:
                orig_color = (r,g,b)
                orig_color_brightness = np.linalg.norm(orig_color)
                orig_color_normalized = orig_color / np.linalg.norm(orig_color)
                
                best_score = None
                best_4bit_color = (None,None,None)
                
                for new_r in range(16):
                    for new_g in range(16):
                        for new_b in range(16):
                            if (new_r == 0 and new_g == 0 and new_b == 0):
                                # FIXME: we do not conside black as a valid option (due to dividing by zero). But sometimes we might want it as the color, maybe?
                                continue
                        
                            new_4bit_color = (new_r, new_g, new_b)
                            new_4bit_color_brightness = np.linalg.norm(new_4bit_color) * 4
                            new_4bit_color_normalized = new_4bit_color / np.linalg.norm(new_4bit_color)
                            
                            color_similarity = np.dot(np.array(orig_color_normalized), np.array(new_4bit_color_normalized))
                            
                            brightness_similarity = None
                            if (orig_color_brightness > new_4bit_color_brightness):
                                brightness_similarity = new_4bit_color_brightness / orig_color_brightness
                            else:
                                brightness_similarity = orig_color_brightness / new_4bit_color_brightness
                            
                            score = color_similarity**5 * brightness_similarity
                            
                            if (best_score is None) or (score > best_score):
                                best_score = score
                                best_4bit_color = new_4bit_color
        
            # 4 bit to 8 bit
            r = best_4bit_color[0] * 17
            g = best_4bit_color[1] * 17
            b = best_4bit_color[2] * 17
            
            new_8bit_color = (r,g,b)
        
        else:
            # 6 bit to 4 bit conversion
            r = (r * 61 + 128) >> 8
            g = (g * 61 + 128) >> 8
            b = (b * 61 + 128) >> 8
            
            if (PATCH_COLORS_MANUALLY):
                if (SCENE == 'U2E'):
                
                    manual_colors_raw = [
                        # DEFAULT (32), BLACK (16),                             GREY (16)
                        0x000, 0x433, 0x433, 0x433, 0x433, 0x544, 0x544, 0x655, 0x655, 0x655, 0x766, 0x766, 0x877, 0x877, 0x988, 0x988,
                        # WHITE#NEON (16)
                        0x999, 0x999, 0xaaa, 0xaaa, 0xaaa, 0xbbb, 0xbbb, 0xccc, 0xccc, 0xddd, 0xddd, 0xddd, 0xeee, 0xeee, 0xfff, 0xfff,
                        # GREENGRASS (32)
                        0x232, 0x232, 0x242, 0x343, 0x343, 0x353, 0x353, 0x353, 0x464, 0x464, 0x464, 0x474, 0x474, 0x474, 0x485, 0x485,
                        0x485, 0x595, 0x595, 0x595, 0x5a5, 0x5a5, 0x5a5, 0x5b6, 0x5b6, 0x5b6, 0x5c6, 0x5c6, 0x5c6, 0x5d6, 0x5d6, 0x5d7,
                        # BLUE#PLASTIC (32)
                        0x123, 0x123, 0x234, 0x234, 0x234, 0x345, 0x345, 0x345, 0x456, 0x456, 0x456, 0x567, 0x567, 0x567, 0x679, 0x679,
                        0x679, 0x77a, 0x77a, 0x77a, 0x88b, 0x88b, 0x88b, 0x99c, 0x99c, 0x99c, 0xaad, 0xaad, 0xbae, 0xbae, 0xcbf, 0xcbf,
                        # TALO1 (32)
                        0x234, 0x345, 0x345, 0x345, 0x456, 0x456, 0x456, 0x467, 0x567, 0x567, 0x678, 0x678, 0x678, 0x788, 0x788, 0x788,
                        0x899, 0x899, 0x899, 0x9aa, 0x9aa, 0x9aa, 0xabb, 0xabb, 0xabb, 0xbcc, 0xbcc, 0xbcc, 0xcdd, 0xcdd, 0xdde, 0xdde,
                        # RED_HOUSE (32)
                        0x322, 0x322, 0x433, 0x433, 0x544, 0x544, 0x655, 0x655, 0x655, 0x766, 0x766, 0x766, 0x877, 0x877, 0x877, 0x988,
                        0x988, 0x988, 0xa99, 0xa99, 0xa99, 0xbaa, 0xbaa, 0xcbb, 0xcbb, 0xcbb, 0xdcc, 0xdcc, 0xdcc, 0xedd, 0xedd, 0xfee,
                        # ORANGE (32)
                        0xa40, 0xa40, 0xa50, 0xa50, 0xa50, 0xb60, 0xb60, 0xb60, 0xb70, 0xc70, 0xc80, 0xc80, 0xc90, 0xc90, 0xd90, 0xda0,
                        0xda0, 0xdb0, 0xdb0, 0xec0, 0xec0, 0xed0, 0xed0, 0xfe0, 0xfe0, 0xff0, 0xff2, 0xff5, 0xff7, 0xffa, 0xffc, 0xfff,
                        # LIGHT_BLUE (32)
                        0x334, 0x445, 0x445, 0x445, 0x556, 0x556, 0x556, 0x667, 0x667, 0x667, 0x779, 0x779, 0x779, 0x88a, 0x88a, 0x88a,
                        # C_GROUND (16)
                        0x99b, 0x99b, 0x99b, 0xaac, 0xaac, 0xaac, 0xbbe, 0xbbe, 0xbbd, 0xbbd, 0xcce, 0xcce, 0xddf, 0xddf, 0xeef, 0xeef,
                        
                        0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5,
                        0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0xeb5, 0x000, 0xeb5,                
                    ]
                    
                    manual_color_raw = manual_colors_raw[clr_idx]
                    r = (manual_color_raw >> 8) % 16
                    g = (manual_color_raw >> 4) % 16
                    b = (manual_color_raw >> 0) % 16
                        
                else:
                    # TODO: are there any colors to patch for the U2A scene?
                    pass
            

            new_12bit_color = (r,g,b)
            colors_12bit.append(new_12bit_color)

            # 4 bit to 8 bit
            r = r * 17
            g = g * 17
            b = b * 17
            
            new_8bit_color = (r,g,b)
    else:
        # 6 bit to 8 bit conversion
        r = (r * 259 + 33) >> 6
        g = (g * 259 + 33) >> 6
        b = (b * 259 + 33) >> 6
        
        new_8bit_color = (r,g,b)
        
    
    colors.append(new_8bit_color)
    

if (DEBUG_COLORS):
    colors = debug_colors

mat_name_to_index_and_shades = {}
for color_index in mat_info:
    for nr_of_shades in mat_info[color_index]:
        mat_name = mat_info[color_index][nr_of_shades]['name']
        mat_name_to_index_and_shades[mat_name] = {
            'color_index' : int(color_index),
            'nr_of_shades' : int(nr_of_shades)
        }


if (PRINT_PALETTE_FOR_MANUAL_EDIT):
    # Printing out asm for palette:
    palette_string = ""
    for color_index, new_color in enumerate(colors_12bit):
        red = new_color[0]
        green = new_color[1]
        blue = new_color[2]
        
        if (color_index % 16 == 0 and color_index != 0):
            palette_string += "\n"

        palette_string += "0x" + format(red,"01x")
        palette_string += format(green,"01x")
        palette_string += format(blue,"01x") + ", "
        
    print(palette_string)
    
    exit()



if (PRINT_PALETTE):
    # Printing out asm for palette:
    palette_string = ""
    for new_color in colors_12bit:
        red = new_color[0]
        green = new_color[1]
        blue = new_color[2]
        
        green = green << 4
        
        palette_string += "  .byte "
        palette_string += "$" + format(green | blue,"02x") + ", "
        palette_string += "$" + format(red,"02x")
        palette_string += "\n"

    print(palette_string)
    
    exit()
    
polygon_type_stats = {}


all_frame_bytes = []
bank_bytes = []

while running:
    for event in pygame.event.get():
        if event.type == QUIT:
            running = False

        if event.type == pygame.KEYDOWN:
            if ALLOW_PAUSING_AND_REVERSE_PLAYBACK:
                if event.key == pygame.K_RIGHT:
                    increment_frame_by = org_increment_frame_by
                if event.key == pygame.K_LEFT:
                    increment_frame_by = -org_increment_frame_by
                if event.key == pygame.K_SPACE:
                    increment_frame_by = 0
                if event.key == pygame.K_PERIOD:
                    frame_nr += 100
                if event.key == pygame.K_COMMA:
                    frame_nr -= 100
                if event.key == pygame.K_RIGHTBRACKET:
                    frame_nr += 1
                if event.key == pygame.K_LEFTBRACKET:
                    frame_nr -= 1
                    
                    
                    
                if frame_nr < 1:
                    frame_nr = 1
                if frame_nr > max_frame_nr:
                    frame_nr = max_frame_nr

            if event.key == pygame.K_r:
                DEBUG_COUNT_REDRAWS = not DEBUG_COUNT_REDRAWS

        '''
        if event.type == pygame.MOUSEBUTTONUP:
            pos = pygame.mouse.get_pos()
            source_x = pos[0] // scale
            source_y = pos[1] // scale
            
            screen_pxarray = pygame.PixelArray(screen)
            pick_color = screen_pxarray[source_x,source_y]
            screen_pxarray.close()
            
            # clr_idx = pixels[source_x + source_y * 320]
            # pick_color = colors_12bit[clr_idx]
            
            print((source_x,source_y))
            print(pick_color)
        '''

    if PRINT_PROGRESS: print("Loading vertices and faces")
    world_objects = load_vertices_and_faces(frame_nr)

    filtered_world_objects = None
    if (DEBUG_SORTING_LIMIT_OBJECTS):
        filtered_world_objects = {}
        
        # We always want the CameraBox
        filtered_world_objects['CameraBox'] = world_objects['CameraBox']
        
        for current_object_name in world_objects:
            # FIXME: HARDCODED!
            if (current_object_name != 's01'):
                continue
                
            filtered_world_objects[current_object_name] = world_objects[current_object_name]
        
            object_faces = filtered_world_objects[current_object_name]['faces']
            
            filtered_object_faces = []
            for object_face_index, object_face in enumerate(object_faces):

# FIXME: HARDCODED: Problematic face on ship
# FIXME: HARDCODED: Problematic face on ship
# FIXME: HARDCODED: Problematic face on ship
                if (object_face_index != 36):  
                    continue
                    
                filtered_object_faces.append(object_face)
                
            filtered_world_objects[current_object_name]['faces'] = filtered_object_faces
            
    else:
        filtered_world_objects = world_objects

    if PRINT_PROGRESS: print("Triangulate faces")
    triangulated_world_objects = triangulate_faces(filtered_world_objects)
    
    if PRINT_PROGRESS: print("Getting camera info")
    camera_box = triangulated_world_objects['CameraBox']
    camera_info = get_camera_info_from_camera_box(camera_box)
    del triangulated_world_objects['CameraBox']

    
    if PRINT_PROGRESS: print("Transform into view space")
    # Rotate and translate all vertices in the world so camera position becomes 0,0,0 and forward direction becomes 0,0,-1 (+up = 0,1,0)
    view_objects = transform_objects_into_view_space(triangulated_world_objects, camera_info)

# FIXME: put this in a function!
    if PRINT_PROGRESS: print("Calculating average z of objects")
    for current_object_name in view_objects:
        
        if (current_object_name == 'CameraBox'):
            continue

        object_vertices = view_objects[current_object_name]['vertices']
        
        # FIXME: this is a HACK! We try to use the average z of all the vertices in an object to do sorting
        #         we should INSTEAD use the 'center vertex' (which is pl[0][1] in the original code: see 'ORD'-part in each object file)
        
        avg_z_for_object = 0
        if (False):
            for object_vertex in object_vertices:
                avg_z_for_object += object_vertex[2]
            
            avg_z_for_object = avg_z_for_object / len(object_vertices)
        else:
            min_z = None
            max_z = None
            for v_idx, object_vertex in enumerate(object_vertices):
            
                # HACK: the last 8 vertices of the 'b4' building are completely somewhere different (its a separate building). As a workaround, we ignore those 8.
                if (current_object_name == 'b4') and (v_idx >= len(object_vertices) - 8):
                    continue
            
                vertex_z = object_vertex[2]
                if ((min_z is None) or vertex_z < min_z):
                    min_z = vertex_z
                if ((max_z is None) or vertex_z > max_z):
                    max_z = vertex_z
                
            avg_z_for_object = (min_z + max_z) / 2
        
        # The original engine has a little trick: when an object starts with an underscore (usually the platforms on the ground) then consider it very far away (meaning: always draw first)
        #    See: VISU/C/U2E.C (lines 401-431)
        if current_object_name.startswith('_'):
            avg_z_for_object -= 1000000
        if current_object_name.startswith('__'):  # For our own SKY_BLACK an extra offset
            avg_z_for_object -= 1000000
        
        avg_z_per_object[current_object_name] = avg_z_for_object

# FIXME: put this in a function!
    if PRINT_PROGRESS: print("Assemble all objects into one list of faces/vertices/normals")
    view_faces = []
    view_vertices = []
    view_normals = []
    for current_object_name in view_objects:
        # We assemble all objects but the camera(box) here
        
        if (current_object_name == 'CameraBox'):
            continue
            
        object_vertices = view_objects[current_object_name]['vertices']
        object_faces = view_objects[current_object_name]['faces']
        object_normals = view_objects[current_object_name]['normals']
        
        start_vertex_index = len(view_vertices)
        start_normal_index = len(view_normals)
        view_vertices += object_vertices
        view_normals += object_normals
        for object_face in object_faces:
            object_face['vertex_indices'][0] += start_vertex_index
            object_face['vertex_indices'][1] += start_vertex_index
            object_face['vertex_indices'][2] += start_vertex_index
            
            object_face['normal_index'] += start_normal_index
            
            object_face['obj_name'] = current_object_name
            
            view_faces.append(object_face)
        
    
    if PRINT_PROGRESS: print("Backface cull")
    # Backface cull where face/triangle-normal points away from camera
    (culled_view_faces, culled_view_vertices) = cull_faces_of_objects(view_faces, view_vertices, view_normals)
    
    # TODO:
    # - maybe THINK about re-using vertices that are CREATED during z-clipping and camera-side-clipping! (and maybe when splitting triangles, if we were to do that)
    #   - One option is to determine if the (2D/3D) point already exists as a vertex
    #     - By comparing coordinates (with an EPSILON) of all known vertices, so can find the closely-matching one -- SLOW!
    #   - Another option is to semantically store new vertices: "v[1]->v[2]->CLIP_RIGHT", "v[4]->v[17]->CLIP_Z", "v[38]->v[97]->INTERSECTION->v[21]->v[53]"
    #     - ISSUE: how do you determine in which ORDER you have to create these identifiers? 
    #          SOLUTION: -> simply by vertex_index? 
    #             - And which EDGE of the INTERSECTION should go first?
    #               SOLUTION:  -> Simply the lowest vertex_index again?
    #     - ISSUE: how to deal with 2D vs 3D faces/vertices? 
    #         SOLUTION:  are these identifiers only needed *DURING* CLIPPING/SPLITTING? (and can be thrown away afterwards)

# FIXME!
# FIXME!
# FIXME!
#    culled_view_faces = culled_view_faces[1:2]
    #print(len(culled_view_faces))
    
    if PRINT_PROGRESS: print("Z clipping")
    # Clip/remove where Z > -1 (behind or very close to camera)
# FIXME: dont we need the normals for this? To CORRECT the ORDERING after clipping?
    (z_clipped_view_faces, z_clipped_view_vertices) = z_clip_faces(culled_view_faces, culled_view_vertices)

    # print(str(len(culled_view_vertices))+'->'+str(len(z_clipped_view_vertices)))
    
    if PRINT_PROGRESS: print("Applying light")
    # Change color of faces/triangles according to the amount of light they get
    (lit_view_faces, lit_view_vertices) = apply_light_to_faces(z_clipped_view_faces, z_clipped_view_vertices, view_normals)   
    
    if PRINT_PROGRESS: print("Projection")
    # Project all vertices to screen-space
    (projected_faces, projected_vertices) = project_triangles(lit_view_faces, lit_view_vertices)
    
    # TODO: should we remove this?
    # if PRINT_PROGRESS: print("Determine 2D intersections and split")
    #    (split_projected_faces, split_projected_vertices, debug_intersection_points) = determine_triangle_2d_intersections_and_split(projected_faces, projected_vertices, lit_view_faces, lit_view_vertices, camera_info)
    
    if PRINT_PROGRESS: print("Camera clipping")
    # Clip 4 sides of the camera -> creating NEW triangles!
    (camera_clipped_projected_faces, camera_clipped_projected_vertices) = camera_clip_projected_triangles(projected_faces, projected_vertices)
    
    
    # print(str(len(projected_vertices))+'=>'+str(len(camera_clipped_projected_vertices)))


    '''
     === Implement this ===

    # Shrink triangles when overdrawn
    minimized_projected_triangles = shrink_triangles_when_overdrawn(projected_triangles)
    
    # Maybe: Combine projected triangles (with *same* color+light) into larger polygons
    larger_polygons = combine_triangles_into_larger_polygons(minimized_projected_triangles)

    # Draw in pygame
    draw_projected_triangles(minimized_projected_triangles)
    
    # Create trilist files for the X16
    export_projected_triangles(minimized_projected_triangles)
    '''
    
    if PRINT_PROGRESS: print("Sort, scale to screen and check visibility")
    (screen_vertices, sorted_faces, visible_face_indexes, black_pixels) = sort_faces_scale_to_screen_and_check_visibility(camera_clipped_projected_vertices, camera_clipped_projected_faces)

    visible_sorted_faces = []
    for face_index, face in enumerate(sorted_faces):
        if REMOVE_INVISIBLE_FACES:
            if (face_index not in visible_face_indexes):    
                # We skip faces that are not visible (aka that are overdrawn completely)
                continue
        visible_sorted_faces.append(face)
    
    if (MERGE_FACES):
        if PRINT_PROGRESS: print("Merging/joining faces")
        merged_faces = combine_faces(screen_vertices, visible_sorted_faces)
        
        #print(json.dumps(merged_faces, indent=4))
        
        if PRINT_PROGRESS: print("Draw and export")
        frame_bytes = draw_and_export(screen_vertices, merged_faces, polygon_type_stats)
        
        # print(frame_bytes)
        
        if (len(bank_bytes) + len(frame_bytes) >= 8192):
            # We add a polygon count of 255 as a marker that we have to switch to the next RAM Bank
            bank_bytes.append(255)
            fill_ln = 8192 - len(bank_bytes)
            all_frame_bytes += bank_bytes
            all_frame_bytes += fill_ln * [0]
            bank_bytes = []
            
        bank_bytes += frame_bytes
        
        if (PRINT_FRAME_TRIANGLES):
            print(str(frame_nr) + ":" +str(len(camera_clipped_projected_faces))+':'+str(len(visible_sorted_faces))+':'+str(len(merged_faces)))
    else:   
        if PRINT_PROGRESS: print("Draw and export")
        frame_bytes = draw_and_export(screen_vertices, visible_sorted_faces, polygon_type_stats)
        
        if (PRINT_FRAME_TRIANGLES):
            print(str(frame_nr) + ":" +str(len(camera_clipped_projected_faces))+':'+str(len(visible_sorted_faces)))
    
        
        
    #print(json.dumps(polygon_type_stats, indent=4))
        
    

    if (DRAW_BLACK_PIXELS):
        for y in range(150):
            for x in range(320):
                if (black_pixels[y*320+x] == 1):
                    pixel_color = (0xFF, 0xFF, 0x00)
                    pygame.draw.rect(screen, pixel_color, pygame.Rect(x*scale, y*scale, 1*scale, 1*scale))
                else:
                    pixel_color = (0x00, 0x00, 0x00)
                    # pygame.draw.rect(screen, pixel_color, pygame.Rect(x*scale, y*scale, 1*scale, 1*scale))

    if (DRAW_PALETTE):
        
        x = 0
        y = 0
        
        for clr_idx in range(256):
        
            if clr_idx >= len(colors):
                continue
        
            pixel_color = colors[clr_idx]
            
            pygame.draw.rect(screen, pixel_color, pygame.Rect(x*scale, y*scale, 8*scale, 8*scale))
            
            # if (byte_index % 16 == 0 and byte_index != 0):
            if (clr_idx % 16 == 15):
                y += 8
                x = 0
            else:
                x += 8


    if (DRAW_INTERSECTION_POINTS):
        pixel_color = (255,0,0)
        for pt_idx, pt in enumerate(debug_intersection_points):
            (screen_x, screen_y) = projected_to_screen(pt[0], pt[1])
        
            pygame.draw.rect(screen, pixel_color, pygame.Rect(screen_x*scale, screen_y*scale, 1*scale, 1*scale))


    pygame.display.flip()
    
    frame_nr += increment_frame_by
    
    if ALLOW_PAUSING_AND_REVERSE_PLAYBACK:
        if frame_nr > max_frame_nr:
            frame_nr = max_frame_nr
        if frame_nr < 1:
            frame_nr = 1
    else:
        if frame_nr > max_frame_nr:
            running = False
    
    clock.tick(60)

# We add the left-over frame bytes
if (len(bank_bytes) > 0): 
    all_frame_bytes += bank_bytes

polygonDataFile = open(polygon_data_file, "wb")
polygonDataFile.write(bytearray(all_frame_bytes))
polygonDataFile.close()


# Quit Pygame
pygame.quit()

