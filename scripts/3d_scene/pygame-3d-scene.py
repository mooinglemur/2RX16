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

DRAW_PALETTE = True

scale = 3

# Initialize Pygame
pygame.init()

'''
# FIXME: quick and dirty colors here (somewhat akin to VERA's first 16 colors0
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

colors = [
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
'''

clock=pygame.time.Clock()

# Set up the display
screen_width, screen_height = 320, 200
screen = pygame.display.set_mode((screen_width*scale, screen_height*scale))
pygame.display.set_caption("3D Scene")

DEBUG_COLORS = False

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
    material_file_to_import = "U2E_material.json"
    material_file = open('assets/3d_scene/' + material_file_to_import, 'r')
    material_info = json.loads(material_file.read())
    material_file.close()
    return material_info

def load_vertices_and_faces(frame_nr):

    # In Blender do:
    #  - File->Export->Wavefront (obj)
    #  - Forward Axis: Y
    #  - Upward Axis: Z
    #  - Select: Normals, Triangulated Mesh, Materials->Export
    #  - TODO: also export Animation
    
    # obj_file = open('assets/3d_scene/test_cube.obj', 'r')
    # obj_file = open('assets/3d_scene/test_cube_straight.obj', 'r')
    obj_file = open('assets/3d_scene/U2E_anim/U2E_anim' + str(frame_nr) + '.obj', 'r')
    # obj_file = open('assets/3d_scene/test_cube1.obj', 'r')
    # obj_file = open('assets/3d_scene/test_cube50.obj', 'r')
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
                # Note: we overwrite the normal index, since we assume this is a triangle and has ONE normal for each face
                normal_index = int(line_part.split('//')[1])-1   
                
            
            if current_material_name in mat_name_to_index_and_shades:
                color_index_and_shades = mat_name_to_index_and_shades[current_material_name]
                color_index = color_index_and_shades['color_index']
                nr_of_shades = color_index_and_shades['nr_of_shades']
            else:
                # FIXME: These materials should never be shown, so we set the to None for now, but this isnt really correct
                color_index = None
                nr_of_shades = None
                print("Unknown material: " + current_material_name)
                #exit()
                
            # FIXME: this is ASSUMING there are EXACTLY 3 vertex indices! Make sure this is the case!
            # FIXME?: right now, we convert a global vertex (and normal) index into an object-vertex (and normal) index. Is this actually a good idea?
            objects[current_object_name]['faces'].append({
                'vertex_indices' : [ 
                    vertex_indices[0] - object_start_vertex_index,
                    vertex_indices[1] - object_start_vertex_index,
                    vertex_indices[2] - object_start_vertex_index 
                ],
                'normal_index' : normal_index - object_start_normal_index,
                'color_index' : color_index,
                'nr_of_shades' : nr_of_shades,
                'material_name' : current_material_name
            })
            
    # FIXME: we should do another pass and add the *bounding boxes* of these objects! (to SPEED UP the clipping!)
            
    return objects


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

    # We transform all vertices by the view_matrix
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
    
    
def cull_faces_of_objects(view_objects):

    culled_view_objects = {}
    
    for current_object_name in view_objects:
    
        view_object = view_objects[current_object_name]
        culled_view_object = copy.deepcopy(view_object)
        
        culled_view_object['faces'] = []
        
        for face in view_object['faces']:
           
            # We need to check whether a face of an object is facing away from the camera. If it is, we should remove it.
            # We do this check by doing the dot-product with the normal of the face and the direction of any vertex of that face (from the camera, which is at 0,0,0)
            face_normal = np.array(view_object['normals'][face['normal_index']])
            first_vertex = np.array(view_object['vertices'][face['vertex_indices'][0]])
            normalized_vector_towards_first_vertex = first_vertex / np.linalg.norm(first_vertex)
            dot_product = np.dot(normalized_vector_towards_first_vertex, face_normal)
            
            # When it is facing away form the camera, we cull it
            if dot_product > 0:
                continue
        
            culled_view_object['faces'].append(face)
        
        culled_view_objects[current_object_name] = culled_view_object
    
    return culled_view_objects

Z_EDGE = -1.0

def is_vertex_inside_z_edge(vertex):

    z = vertex[2]
    
    vertex_is_inside = True

    if z > Z_EDGE:
        vertex_is_inside = False
            
    return vertex_is_inside
    

def clip_vertex_against_z_edge(inside_vertex, outside_vertex):

    percentage_to_keep = (inside_vertex[2] - Z_EDGE) / (inside_vertex[2] - outside_vertex[2])
    x_clipped = inside_vertex[0] + (outside_vertex[0] - inside_vertex[0]) * percentage_to_keep
    y_clipped = inside_vertex[1] + (outside_vertex[1] - inside_vertex[1]) * percentage_to_keep
    clipped_vertex = (x_clipped, y_clipped, Z_EDGE)
    
    return clipped_vertex


def clip_face_against_z_edge(non_clipped_face, combined_vertices):
    clipped_faces = []

# FIXME: we should try to REUSE vertices!
    start_vertex_index = len(combined_vertices)
    svi = start_vertex_index

    # We need to check which of these vertices are INSIDE and OUTSIDE of the plane/edge we are clipping against
    
    inside_vertices = []
    outside_vertices = []
    for vertex_index in range(3):
        non_clipped_vertex = combined_vertices[non_clipped_face['vertex_indices'][vertex_index]]
        
        vertex_is_inside = is_vertex_inside_z_edge(non_clipped_vertex)
        
        if vertex_is_inside:
            # Since this is an inside vertex, there is no need to clip it, so we just copy it
            inside_vertices.append(copy.deepcopy(non_clipped_vertex))
        else:
            # We clip the vertex against the edge
            outside_vertices.append(non_clipped_vertex)
    
    if (len(inside_vertices) == 0):
        # The triangle is completely outside the edge, we dont add it
        pass
    elif (len(inside_vertices) == 3):
        # The triangle is completely inside the edge, we add it as-is
        combined_vertices += inside_vertices
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_face['vertex_indices'] = [0+svi,1+svi,2+svi]
        clipped_faces.append(clipped_face)
    elif (len(inside_vertices) == 1):
        # Out triangle gets shorter, so we return one smaller triangle
        combined_vertices.append(inside_vertices[0])
        clipped_vertex_0 = clip_vertex_against_z_edge(inside_vertices[0], outside_vertices[0])
        combined_vertices.append(clipped_vertex_0)
        clipped_vertex_1 = clip_vertex_against_z_edge(inside_vertices[0], outside_vertices[1])
        combined_vertices.append(clipped_vertex_1)
        clipped_face = copy.deepcopy(non_clipped_face)
# FIXME: we are NOT keeping the CORRECT ORDER of the vertices here!
        clipped_face['vertex_indices'] = [0+svi,1+svi,2+svi]
        if (DEBUG_COLORS):
            clipped_face['color_index'] = 3
        clipped_faces.append(clipped_face)
    elif (len(inside_vertices) == 2):
        # We have a quad we have to split into two triangles
        
        # First triangle
        combined_vertices.append(inside_vertices[0])
        clipped_vertex_1 = clip_vertex_against_z_edge(inside_vertices[1], outside_vertices[0])
        combined_vertices.append(clipped_vertex_1)
        combined_vertices.append(inside_vertices[1])
        
        clipped_face = copy.deepcopy(non_clipped_face)
# FIXME: we are NOT keeping the CORRECT ORDER of the vertices here!
        clipped_face['vertex_indices'] = [0+svi,1+svi,2+svi]
        if (DEBUG_COLORS):
            clipped_face['color_index'] = 2
        clipped_faces.append(clipped_face)
        
        # Second triangle
        clipped_vertex_0 = clip_vertex_against_z_edge(inside_vertices[0], outside_vertices[0])
        combined_vertices.append(clipped_vertex_0)
        
        clipped_face = copy.deepcopy(non_clipped_face)
# FIXME: we are NOT keeping the CORRECT ORDER of the vertices here!
        clipped_face['vertex_indices'] = [0+svi,3+svi,1+svi]
        if (DEBUG_COLORS):
            clipped_face['color_index'] = 4
        clipped_faces.append(clipped_face)

    return clipped_faces


def z_clip_faces_of_objects (view_objects):

    z_clipped_view_objects = {}
    
    for current_object_name in view_objects:
        view_object = view_objects[current_object_name]
        z_clipped_view_object = copy.deepcopy(view_object)
        
        z_clipped_view_object['faces'] = []
       
        # For this object we keep track of all clipped vertices being created
        combined_vertices = z_clipped_view_object['vertices']

        # We determine -for each face in the object- whether it should be clipped against the edges of the screen
        for non_clipped_face in view_object['faces']:

            # FIXME: we create many *DUPLICATE* vertices using this technique! Is there a SMARTER way?
            
            # The clipped_vertices is an OUPUT vertex-array!
            clipped_faces_against_z_edge = clip_face_against_z_edge(non_clipped_face, combined_vertices)

            # After clipping against the Z-edge we are left with only clipped faces
            z_clipped_view_object['faces'] += clipped_faces_against_z_edge
        
        
        z_clipped_view_objects[current_object_name] = z_clipped_view_object

    return z_clipped_view_objects


def apply_light_to_faces_of_objects(view_objects, camera_light):

    lit_view_objects = {}
    
    for current_object_name in view_objects:
        view_object = view_objects[current_object_name]
        #lit_view_object = copy.deepcopy(view_object)

        # for each face we change the dot-product with the camera light
        for face in view_object['faces']:
            normal_index = face['normal_index']
            normal = view_object['normals'][normal_index]
            
# FIXME!
            light_dot = np.dot(np.array(camera_light), np.array(normal))
            if light_dot < 0:
               light_dot = 0 
            print(light_dot)
            
# FIXME!
            light_dot = light_dot * 0.5
            
            face['color_index'] = int((light_dot) * face['nr_of_shades']) + face['color_index']
        
    
        lit_view_objects[current_object_name] = view_object
    
    #exit()
    return lit_view_objects


# FIXME: calculate the camera_scale differently!
camera_scale = 37

center_offset = (screen_width // 2, screen_height // 2)

# FIXME: REMOVE or set to 0,0,0!
camera = (0, 0, 6)

def project_objects(view_objects, camera_info):

    projected_objects = {}
    
    for current_object_name in view_objects:
        view_object = view_objects[current_object_name]
        projected_object = copy.deepcopy(view_object)
    
        view_vertices = view_object['vertices']
        
        # We calculate the sum of z for every face
        for face in projected_object['faces']:
            face_vertex_indices = face['vertex_indices']
            
            vertex1 = view_vertices[face_vertex_indices[0]]
            vertex2 = view_vertices[face_vertex_indices[1]]
            vertex3 = view_vertices[face_vertex_indices[2]]
            
            sum_of_z = vertex1[2] + vertex2[2] + vertex3[2]
            
            face['sum_of_z'] = sum_of_z
        
        projected_vertices = []
        
        # Projection of the vertices of the visible faces
        for vertex in view_object['vertices']:
            x = vertex[0]
            y = vertex[1]
            z = vertex[2]
            
            new_x = x
            new_y = y
            new_z = z

            # FIXME: we should use a ~42? degree FOV!
            # --> use camera_info for this!
            
            # Note: since 'forward' is negative Z -for the object in front of the camera- we want to divide by negative z 
            z_ratio = 1 / -new_z

            # FIXME: both SIDES of the CUBE dont look STRAIGHT (zoomed in)! There is something WRONG!
            # FIXME: both SIDES of the CUBE dont look STRAIGHT (zoomed in)! There is something WRONG!
            # FIXME: both SIDES of the CUBE dont look STRAIGHT (zoomed in)! There is something WRONG!

            new_x *= (z_ratio*6)
            new_y *= (z_ratio*6)
            
            x_proj = new_x * camera_scale + center_offset[0]
            y_proj = new_y * camera_scale + center_offset[1]
            z_proj = new_z * camera_scale

            # Note: we also flip the y here!
            projected_vertices.append((round(x_proj), screen_height - round(y_proj)))
            
        projected_object['vertices'] = projected_vertices
        
        projected_objects[current_object_name] = projected_object
        
    return projected_objects
    
LEFT_EDGE_X = 0
RIGHT_EDGE_X = 320
TOP_EDGE_Y = 0
BOTTOM_EDGE_Y = 200
    
def is_2d_vertex_inside_edge(vertex, edge_name):

    x = vertex[0]
    y = vertex[1]
    
    vertex_is_inside = True
    
    if edge_name == 'LEFT':
        if x < LEFT_EDGE_X:
            vertex_is_inside = False
    elif edge_name == 'RIGHT':
        if x >= RIGHT_EDGE_X:
            vertex_is_inside = False
    elif edge_name == 'TOP':
        if y < TOP_EDGE_Y:
            vertex_is_inside = False
    elif edge_name == 'BOTTOM':
        if y >= BOTTOM_EDGE_Y:
            vertex_is_inside = False
            
    return vertex_is_inside
    

def clip_2d_vertex_against_edge(inside_vertex, outside_vertex, edge_name):

    if edge_name == 'LEFT':
        percentage_to_keep = (inside_vertex[0] - LEFT_EDGE_X) / (inside_vertex[0] - outside_vertex[0])
        y_clipped = inside_vertex[1] + (outside_vertex[1] - inside_vertex[1]) * percentage_to_keep
        clipped_vertex = (LEFT_EDGE_X, y_clipped)
    elif edge_name == 'RIGHT':
# FIXME: should we do -1 here too?
        percentage_to_keep = (RIGHT_EDGE_X - inside_vertex[0]) / (outside_vertex[0] - inside_vertex[0])
        y_clipped = inside_vertex[1] + (outside_vertex[1] - inside_vertex[1]) * percentage_to_keep
        clipped_vertex = (RIGHT_EDGE_X-1, y_clipped)
    elif edge_name == 'TOP':
        percentage_to_keep = (inside_vertex[1] - TOP_EDGE_Y) / (inside_vertex[1] - outside_vertex[1])
        x_clipped = inside_vertex[0] + (outside_vertex[0] - inside_vertex[0]) * percentage_to_keep
        clipped_vertex = (x_clipped, TOP_EDGE_Y)
    elif edge_name == 'BOTTOM':
# FIXME: should we do -1 here too?
        percentage_to_keep = (BOTTOM_EDGE_Y - inside_vertex[1]) / (outside_vertex[1] - inside_vertex[1])
        x_clipped = inside_vertex[0] + (outside_vertex[0] - inside_vertex[0]) * percentage_to_keep
        clipped_vertex = (x_clipped, BOTTOM_EDGE_Y-1)
    
    return clipped_vertex
    
    
def clip_face_against_edge(non_clipped_face, combined_vertices, edge_name):
    clipped_faces = []

# FIXME: we should try to REUSE vertices!
    start_vertex_index = len(combined_vertices)
    svi = start_vertex_index

    # We need to check which of these vertices are INSIDE and OUTSIDE of the plane/edge we are clipping against
    
    #print(non_clipped_face['vertex_indices'])
    
    inside_vertices = []
    outside_vertices = []
    for vertex_index in range(3):
        non_clipped_vertex = combined_vertices[non_clipped_face['vertex_indices'][vertex_index]]
        
        vertex_is_inside = is_2d_vertex_inside_edge(non_clipped_vertex, edge_name)
        
        if vertex_is_inside:
            # Since this is an inside vertex, there is no need to clip it, so we just copy it
            inside_vertices.append(copy.deepcopy(non_clipped_vertex))
        else:
            # We clip the 2d vertex against the edge
            outside_vertices.append(non_clipped_vertex)
    
    
    if (len(inside_vertices) == 0):
        # The triangle is completely outside the edge, we dont add it
        pass
    elif (len(inside_vertices) == 3):
        # The triangle is completely inside the edge, we add it as-is
        combined_vertices += inside_vertices
        clipped_face = copy.deepcopy(non_clipped_face)
        clipped_face['vertex_indices'] = [0+svi,1+svi,2+svi]
        clipped_faces.append(clipped_face)
    elif (len(inside_vertices) == 1):
        # Out triangle gets shorter, so we return one smaller triangle
        combined_vertices.append(inside_vertices[0])
        clipped_vertex_0 = clip_2d_vertex_against_edge(inside_vertices[0], outside_vertices[0], edge_name)
        combined_vertices.append(clipped_vertex_0)
        clipped_vertex_1 = clip_2d_vertex_against_edge(inside_vertices[0], outside_vertices[1], edge_name)
        combined_vertices.append(clipped_vertex_1)
        clipped_face = copy.deepcopy(non_clipped_face)
# FIXME: we are NOT keeping the CORRECT ORDER of the vertices here!
        clipped_face['vertex_indices'] = [0+svi,1+svi,2+svi]
        if (DEBUG_COLORS):
            clipped_face['color_index'] = 8
        clipped_faces.append(clipped_face)
    elif (len(inside_vertices) == 2):
        # We have a quad we have to split into two triangles
        
        # First triangle
        combined_vertices.append(inside_vertices[0])
        clipped_vertex_1 = clip_2d_vertex_against_edge(inside_vertices[1], outside_vertices[0], edge_name)
        combined_vertices.append(clipped_vertex_1)
        combined_vertices.append(inside_vertices[1])
        
        clipped_face = copy.deepcopy(non_clipped_face)
# FIXME: we are NOT keeping the CORRECT ORDER of the vertices here!
        clipped_face['vertex_indices'] = [0+svi,1+svi,2+svi]
        if (DEBUG_COLORS):
            clipped_face['color_index'] = 9
        clipped_faces.append(clipped_face)
        
        # Second triangle
        clipped_vertex_0 = clip_2d_vertex_against_edge(inside_vertices[0], outside_vertices[0], edge_name)
        combined_vertices.append(clipped_vertex_0)
        
        clipped_face = copy.deepcopy(non_clipped_face)
# FIXME: we are NOT keeping the CORRECT ORDER of the vertices here!
        clipped_face['vertex_indices'] = [0+svi,3+svi,1+svi]
        if (DEBUG_COLORS):
            clipped_face['color_index'] = 10
        clipped_faces.append(clipped_face)

    return clipped_faces


def camera_clip_projected_objects(projected_objects, camera_info):

    camera_clipped_projected_objects = {}
    
    edge_names = ['LEFT', 'TOP', 'RIGHT', 'BOTTOM']
    
    for current_object_name in projected_objects:
        projected_object = projected_objects[current_object_name]
        
        camera_clipped_projected_object = copy.deepcopy(projected_object)
        camera_clipped_projected_object['faces'] = []
        # We KEEP the old vertices! (even though they are all not being used at the end!
        # camera_clipped_projected_object['vertices'] = []
       
        # For this object we keep track of all clipped vertices being created
        combined_vertices = camera_clipped_projected_object['vertices']

        #non_clipped_vertices = projected_object['vertices']
 
        # We determine -for each face in the object- whether it should be clipped against the edges of the screen
        for non_clipped_face in projected_object['faces']:

            # We start with the non-clipped face we want to clip along all 4 edges
            queue_faces = [ non_clipped_face ]
            
            #print(queue_faces)
            for edge_name in edge_names:

                clipped_faces_against_this_edge = []
                for queue_face in queue_faces:
                    
                    # FIXME: we create many *DUPLICATE* vertices using this technique! Is there a SMARTER way?
                    
                    # The clipped_vertices is an OUPUT vertex-array that gets extended each time!
                    # We *extend* clipped_faces_against_this_edge here
                    clipped_faces_against_this_edge += clip_face_against_edge(queue_face, combined_vertices, edge_name)

                # The output faces (left over after clipping) become the input faces for the next edge
                queue_faces = clipped_faces_against_this_edge
                
            
            # After clipping against all 4 edges we are left with only clipped faces in the queue
            camera_clipped_projected_object['faces'] += queue_faces
                
        
        #print(projected_object['faces'])
        #print(projected_object['vertices'])
        #print()
        #print(camera_clipped_projected_object['faces'])
        #print(camera_clipped_projected_object['vertices'])
        
        # FIXME: iterate over all SCREEN EDGE and feed it the NEW list each time!
        
        camera_clipped_projected_objects[current_object_name] = camera_clipped_projected_object
    
    return camera_clipped_projected_objects
    

def slope2bytes(slope):
    x1 = (slope / 2)
    x32 = 0x00
    if x1 >= 32 or x1 < -32:
        x1 /= 32
        x32 = 0x80
    x1 *= 512 # move significant fractional part to whole number
    print(round(x1))
    b1 = bytearray(round(x1).to_bytes(2, 'little', signed=True))
    b1[1] &= 0x7f
    b1[1] |= x32
    return b1

def sort_light_draw_and_export(projected_vertices, faces):

    def face_sorter(item):
        return -item['sum_of_z']
        
    def y_sorter(item):
        return projected_vertices[item][1]

    # The vertices are scaled up for the pygame screen
    scaled_up_vertices = []
    for projected_vertex in projected_vertices:
        scaled_up_vertex = [
            projected_vertex[0]*scale,
            projected_vertex[1]*scale,
        ]
        scaled_up_vertices.append(scaled_up_vertex)
        
    sorted_faces = sorted(faces, key=face_sorter, reverse=True)

    for face_index, face in enumerate(sorted_faces):

# FIXME: do the light calculation earlier in the pipeline!
        color_idx = face['color_index']
        
# FIXME! HACK!        
        #color_idx = face_index % 16
        
        color_idx_out = color_idx + 1
        color_idx_out += 16*color_idx_out

        # We add the first vertex at the end, since pygame wants polygon to draw back to the beginning point
        face_vertex_indices = face['vertex_indices'] + [face['vertex_indices'][0]]
        
        pygame.draw.polygon(screen, colors[color_idx], [scaled_up_vertices[i] for i in face_vertex_indices], 0)
        
# FIXME!
        continue
        
        # Triangle type (bit 0 is X high bit)
        #  $00 - two part, change X1
        #  $40 - two part, change X2
        #  $80 - part 1 only
        #  $C0 - part 2 only
        #     bit 1 is X2 high bit
        #  $FF - end of triangle list for this frame
        
        # Triangle type 00
        # 
        # 01 - Y
        # 02 - X
        # 03 - X1 inc low
        # 04 - X1 inc high
        # 05 - X2 inc low
        # 06 - X2 inc high
        # 07 - color index
        # 08 - row count part 1
        # 09 - new X1 inc low
        # 0a - new X1 inc high
        # 0b - row count part 2

        # Triangle type 40
        # 
        # 01 - Y
        # 02 - X
        # 03 - X1 inc low
        # 04 - X1 inc high
        # 05 - X2 inc low
        # 06 - X2 inc high
        # 07 - color index
        # 08 - row count part 1
        # 09 - new X2 inc low
        # 0a - new X2 inc high
        # 0b - row count part 2

        # Triangle type 80
        # 
        # 01 - Y
        # 02 - X
        # 03 - X1 inc low
        # 04 - X1 inc high
        # 05 - X2 inc low
        # 06 - X2 inc high
        # 07 - color index
        # 08 - row count

        # Triangle type c0
        # 
        # 01 - Y
        # 02 - X
        # 03 - X2
        # 04 - X1 inc low
        # 05 - X1 inc high
        # 06 - X2 inc low
        # 07 - X2 inc high
        # 08 - color index
        # 09 - row count

        color_idx_out = (color_idx+1) | ((color_idx+1)*16)

        # find top two points of triangle
        face_vertex_indices = face['vertex_indices'] + [face['vertex_indices'][0]]
        sorted_points = sorted(face_vertex_indices, key=y_sorter, reverse=False)

        v0 = list(copy.deepcopy(projected_vertices[sorted_points[0]]))
        v1 = list(copy.deepcopy(projected_vertices[sorted_points[1]]))
        v2 = list(copy.deepcopy(projected_vertices[sorted_points[2]]))

        if v2[1] < 0:
            print("Fully offscreen")
            continue # fully offscreen

        if v1[1] <= 0 and v0[1] < 0:
            print(f"v0 {v0[0]} {v0[1]} v1 {v1[0]} {v1[1]}")

            dx_1 = v1[0] - v0[0]
            dy_1 = v1[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v0[0]
            dy_2 = v2[1] - v0[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            v0[0] = round(v0[0] + (slope_2 * dy_1))
            v0[1] = v1[1]

            print(f"v0 {v0[0]} {v0[1]} v1 {v1[0]} {v1[1]}")

            dx_1 = v2[0] - v0[0]
            dy_1 = v2[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v1[0]
            dy_2 = v2[1] - v1[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            d0 = 0 - v0[1]

            v0[0] = round(math.copysign(1, v0[0] - v1[0]) + v0[0] + (slope_1 * d0))
            v1[0] = round(math.copysign(1, v1[0] - v0[0]) + v1[0] + (slope_2 * d0))

            v0[1] = 0
            v1[1] = 0

            print(f"v0 {v0[0]} {v0[1]} v1 {v1[0]} {v1[1]}")
            print(f"v2 {v2[0]} {v2[1]}")
            #time.sleep(2)

        if v2[1] == v1[1] and v1[1] == v0[1]:
            print(f"v0 {v0[0]} {v0[1]} v1 {v1[0]} {v1[1]}")
            print(f"v2 {v2[0]} {v2[1]}")
            #time.sleep(10)
            continue

        if (v0[1] == v1[1]): # Part 2 only
            print("Part 2 only")
            dx_1 = v2[0] - v0[0]
            dy_1 = v2[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v1[0]
            dy_2 = v2[1] - v1[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            rowcount = v2[1] - v1[1]
            if v0[0] < v1[0]:
                slope_x1 = slope_1
                slope_x2 = slope_2
                x1 = v0[0]
                x2 = v1[0]
            else:
                slope_x1 = slope_2
                slope_x2 = slope_1
                x1 = v1[0]
                x2 = v0[0]
            yy = v0[1]
            print(f"Y {yy} X1 {x1} X2 {x2} Slope X1 {slope_x1} Slope X2 {slope_x2} Count {rowcount}")
            f.write(b'\xc0')                  # 00 - type C0
            if (yy < 0):
                assert y > -55
                f.write(yy.to_bytes(1, 'little', signed=True)) # 01 - Y
            else:
                f.write(yy.to_bytes(1, 'little')) # 01 - Y
            f.write(x1.to_bytes(1, 'little')) # 02 - X1
            f.write(x2.to_bytes(1, 'little')) # 03 - X1
            f.write(slope2bytes(slope_x1))    # 04-05 - X1 inc
            f.write(slope2bytes(slope_x2))    # 06-07 - X2 inc
            f.write(color_idx_out.to_bytes(1, 'little')) # 08 color index
            f.write(rowcount.to_bytes(1, 'little')) # 09 row count
        elif (v1[1] == v2[1]): # Part 1 only
            print("Part 1 only")
            dx_1 = v1[0] - v0[0]
            dy_1 = v1[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v0[0]
            dy_2 = v2[1] - v0[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            rowcount = v1[1] - v0[1]
            if v1[0] < v2[0]:
                slope_x1 = slope_1
                slope_x2 = slope_2
            else:
                slope_x1 = slope_2
                slope_x2 = slope_1
            xx = v0[0]
            yy = v0[1]
            print(f"Y {yy} X {xx} Slope X1 {slope_x1} Slope X2 {slope_x2} Count {rowcount}")
            if v0[0] == v1[0]:
                #time.sleep(5)
                pass
            f.write(b'\x80')                  # 00 - type 80
            if (yy < 0):
                assert y > -55
                f.write(yy.to_bytes(1, 'little', signed=True)) # 01 - Y
            else:
                f.write(yy.to_bytes(1, 'little')) # 01 - Y
            f.write(xx.to_bytes(1, 'little')) # 02 - X
            f.write(slope2bytes(slope_x1))    # 03-04 - X1 inc
            f.write(slope2bytes(slope_x2))    # 05-06 - X2 inc
            f.write(color_idx_out.to_bytes(1, 'little')) # 07 color index
            f.write(rowcount.to_bytes(1, 'little')) # 08 row count

        else:
            dx_1 = v1[0] - v0[0]
            dy_1 = v1[1] - v0[1]
            slope_1 = dx_1 / dy_1 if dy_1 != 0 else 0
            dx_2 = v2[0] - v0[0]
            dy_2 = v2[1] - v0[1]
            slope_2 = dx_2 / dy_2 if dy_2 != 0 else 0
            rowcount1 = v1[1] - v0[1]
            if (slope_1 > slope_2): # Two part, change X2
                print("Two part change X2")
                slope_x1 = slope_2
                slope_x2 = slope_1
                dx_x2_new = v2[0] - v1[0]
                dy_x2_new = v2[1] - v1[1]
                slope_x2_new = dx_x2_new / dy_x2_new if dy_x2_new != 0 else 0
                rowcount2 = v2[1] - v1[1]
                xx = v0[0]
                yy = v0[1]
                print(f"Y {yy} X {xx} Slope X1 {slope_x1} Slope X2 {slope_x2} Count {rowcount1} New X2 {slope_x2_new} Count {rowcount2}")
                f.write(b'\x40')                  # 00 - type 40
                if (yy < 0):
                    assert y > -55
                    f.write(yy.to_bytes(1, 'little', signed=True)) # 01 - Y
                else:
                    f.write(yy.to_bytes(1, 'little')) # 01 - Y
                f.write(xx.to_bytes(1, 'little')) # 02 - X
                f.write(slope2bytes(slope_x1))    # 03-04 - X1 inc
                f.write(slope2bytes(slope_x2))    # 05-06 - X2 inc
                f.write(color_idx_out.to_bytes(1, 'little')) # 07 color index
                f.write(rowcount1.to_bytes(1, 'little')) # 08 row count 1
                f.write(slope2bytes(slope_x2_new)) # 09-0a - new X2 inc
                f.write(rowcount2.to_bytes(1, 'little')) # 0b row count 1
            else: # Two part, change X1
                print("Two part change X1")
                slope_x1 = slope_1
                slope_x2 = slope_2
                dx_x1_new = v2[0] - v1[0]
                dy_x1_new = v2[1] - v1[1]
                slope_x1_new = dx_x1_new / dy_x1_new if dy_x1_new != 0 else 0
                rowcount2 = v2[1] - v1[1]
                xx = v0[0]
                yy = v0[1]
                print(f"Y {yy} X {xx} Slope X1 {slope_x1} Slope X2 {slope_x2} Count {rowcount1} New X1 {slope_x1_new} Count {rowcount2}")
                f.write(b'\x00')                  # 00 - type 00
                if (yy < 0):
                    assert y > -55
                    f.write(yy.to_bytes(1, 'little', signed=True)) # 01 - Y
                else:
                    f.write(yy.to_bytes(1, 'little')) # 01 - Y
                f.write(xx.to_bytes(1, 'little')) # 02 - X
                f.write(slope2bytes(slope_x1))    # 03-04 - X1 inc
                f.write(slope2bytes(slope_x2))    # 05-06 - X2 inc
                f.write(color_idx_out.to_bytes(1, 'little')) # 07 color index
                f.write(rowcount1.to_bytes(1, 'little')) # 08 row count 1
                f.write(slope2bytes(slope_x1_new)) # 09-0a - new X1 inc
                f.write(rowcount2.to_bytes(1, 'little')) # 0b row count 1

# FIXME: what should we do here?
    tris_seen = True
    return tris_seen
    

# Main game loop
running = True

f = open("trilist.bin", "wb")

frame_nr = 1
#increment_frame_by = 0
increment_frame_by = 1
max_frame_nr = 100

material_info = load_material_info()
mat_info = material_info['mat_info']
palette_colors = material_info['palette_colors']

colors = []

for rgb64 in palette_colors:
    # FIXME: 63 * 4 isnt exactly 255!
    r = rgb64['r']*4
    g = rgb64['g']*4
    b = rgb64['b']*4
    colors.append((r,g,b))

mat_name_to_index_and_shades = {}
for color_index in mat_info:
    for nr_of_shades in mat_info[color_index]:
        mat_name = mat_info[color_index][nr_of_shades]['name']
        mat_name_to_index_and_shades[mat_name] = {
            'color_index' : int(color_index),
            'nr_of_shades' : int(nr_of_shades)
        }
#print(mat_name_to_index_and_shades)

while running:
    for event in pygame.event.get():
        if event.type == QUIT:
            running = False

        #if event.type == pygame.KEYDOWN:
            #if event.key == pygame.K_RIGHT:
            #    increment_frame_by = 1

    print("Loading vertices and faces")
    world_objects = load_vertices_and_faces(frame_nr)

    print("Getting camera info")
    camera_box = world_objects['CameraBox']
    camera_info = get_camera_info_from_camera_box(camera_box)
    del world_objects['CameraBox']
    
    print("Transform into view space")
    # Rotate and translate all vertices in the world so camera position becomes 0,0,0 and forward direction becomes 0,0,-1 (+up = 0,1,0)
    view_objects = transform_objects_into_view_space(world_objects, camera_info)

    print("Backface cull")
    # Backface cull where face/triangle-normal points away from camera
    culled_view_objects = cull_faces_of_objects(view_objects)
    
    print("Z clipping")
    # Clip/remove where Z < 0 (behind camera)  (we may assume faces are NOT partially visiable AND behind the camera)
# FIXME: implement this!
    z_clipped_view_objects = z_clip_faces_of_objects(culled_view_objects)
    
    print("Applying light")
    # Change color of faces/triangles according to the amount of light they get
    
# FIXME: change this!
# FIXME: change this!
# FIXME: change this!
    # camera_light = [0,0,1]
    # camera_light = [0.707107,0,0.707107]
    # camera_light = [0.666667, -0.333333, 0.666667]
    camera_light = [0.408248, -0.408248, 0.816497]
    
    lit_view_objects = apply_light_to_faces_of_objects(z_clipped_view_objects, camera_light)
    
    print("Project")
    # Project all vertices to screen-space
    projected_objects = project_objects(lit_view_objects, camera_info)
    
    print("Camera clipping")
    # Clip 4 sides of the camera -> creating NEW triangles!
    camera_clipped_projected_objects = camera_clip_projected_objects(projected_objects, camera_info)

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
    
    #print(world_objects)
# FIXME!
#    exit()

    print("Assemble all objects")
    projected_vertices = []
    faces = []
    for current_object_name in camera_clipped_projected_objects:
        # We assemble all objects but the camera(box) here
        
        if (current_object_name == 'CameraBox'):
            continue
        
        object_projected_vertices = camera_clipped_projected_objects[current_object_name]['vertices']
        object_faces = camera_clipped_projected_objects[current_object_name]['faces']
        
        start_vertex_index = len(projected_vertices)
        projected_vertices += object_projected_vertices
        for object_face in object_faces:
            object_face['vertex_indices'][0] += start_vertex_index
            object_face['vertex_indices'][1] += start_vertex_index
            object_face['vertex_indices'][2] += start_vertex_index
            
            faces.append(object_face)

    print("Sort, draw and export")
    screen.fill((0,0,0))
    tris_seen = sort_light_draw_and_export(projected_vertices, faces)
    if tris_seen:
        f.write(b'\xff') # end of frame


    if (DRAW_PALETTE):
        # screen.fill(background_color)
        
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


    pygame.display.flip()
    
    frame_nr += increment_frame_by
    
    if frame_nr > max_frame_nr:
        running = False
    
    clock.tick(60)

# Quit Pygame
pygame.quit()
