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

random.seed(10)

PRINT_PROGRESS = False
DRAW_PALETTE = False
DEBUG_SORTING = False
DEBUG_COLORS = False
DEBUG_COLOR_PER_ORIG_TRIANGLE = False
DEBUG_CLIP_COLORS = False
DRAW_INTERSECTION_POINTS = False

scale = 3

# Initialize Pygame
pygame.init()

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

# Adding 48 more random colors
for i in range(48):
    r = random.randint(0, 255)
    g = random.randint(0, 255)
    b = random.randint(0, 255)
    random_color = (r, g, b)
    debug_colors.append(random_color)

clock=pygame.time.Clock()

# Set up the display
screen_width, screen_height = 320, 200
screen = pygame.display.set_mode((screen_width*scale, screen_height*scale))
pygame.display.set_caption("3D Scene")

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

def load_animation_info():
    animation_file_to_import = "U2E_animation.json"
    animation_file = open('assets/3d_scene/' + animation_file_to_import, 'r')
    animation_info = json.loads(animation_file.read())
    animation_file.close()
    return animation_info

def load_vertices_and_faces(frame_nr):

    # In Blender do:
    #  - File->Export->Wavefront (obj)
    #  - Forward Axis: Y
    #  - Upward Axis: Z
    #  - Select: Normals, Triangulated Mesh, Materials->Export
    #  - Select: Animation->Export, 1-100 (or 1-1800)
    #  - Filename: U2E_anim.obj  (this will genarate files with names: U2E_anim<frame_nr>.obj and U2E_anim<frame_nr>.mtl)
    
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
                if (current_object_name != 'CameraBox'):
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
        if (DEBUG_CLIP_COLORS):
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
        if (DEBUG_CLIP_COLORS):
            clipped_face['color_index'] = 2
        clipped_faces.append(clipped_face)
        
        # Second triangle
        clipped_vertex_0 = clip_vertex_against_z_edge(inside_vertices[0], outside_vertices[0])
        combined_vertices.append(clipped_vertex_0)
        
        clipped_face = copy.deepcopy(non_clipped_face)
# FIXME: we are NOT keeping the CORRECT ORDER of the vertices here!
        clipped_face['vertex_indices'] = [0+svi,3+svi,1+svi]
        if (DEBUG_CLIP_COLORS):
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
            #print(light_dot)
            
# FIXME!
            light_dot = light_dot * 0.5
            
            face['color_index'] = int((light_dot) * face['nr_of_shades']) + face['color_index']
        
    
        lit_view_objects[current_object_name] = view_object
    
    #exit()
    return lit_view_objects


center_offset = (screen_width // 2, screen_height // 2)

# FIXME: REMOVE or set to 0,0,0!
camera = (0, 0, 6)

def project_triangles(view_faces, view_vertices, camera_info):

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
        
        # FIXME: use camera_info for getting fov_degrees!
        fov_mult = math.tan(fov_degrees/2 * math.pi/180)
        
        # Note: since 'forward' is negative Z -for the object in front of the camera- we want to divide by negative z 
        x_proj = x_view / (-z_view*fov_mult)
        y_proj = y_view / (-z_view*fov_mult)
        
        projected_vertices.append((x_proj, y_proj))
        
    return (projected_faces, projected_vertices)
    
    
def intersection_point(vi1, vi2, vi3, vi4, pv):
    v1 = pv[vi1]
    v2 = pv[vi2]
    v3 = pv[vi3]
    v4 = pv[vi4]
    
    '''
    judge if line (v1,v2) intersects with line(v3,v4)
    '''
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
                    # FIXME: implement this!
                    # FIXME: implement this!



#    for face in projected_faces:
#        # if face['orig_index'] == 3:  # Bottom floor triangle
#            
#        if (False and DEBUG_SORTING):
#            if face['orig_index'] == 11:  # Front wall of building
#                if ('in_front_of' not in face):
#                    face['in_front_of'] = {}
#                face['in_front_of'][3] = True

# FIXME: we are NOT SPLITTING YET!
# FIXME: we are NOT SPLITTING YET!
# FIXME: we are NOT SPLITTING YET!
    split_projected_faces = projected_faces
    split_projected_verticed = projected_vertices

    return (split_projected_faces, split_projected_verticed, debug_intersection_points)

# FIXME: we took the FOV from U2E.INF (which might not be completely accurate, since its converted to a 16bit number first)
# FIXME: For U2A this will be different!
fov_degrees = 40

# We put the ASPECT RATIO in here for clipping against the camera sides
LEFT_EDGE_X = -1
RIGHT_EDGE_X = +1
BOTTOM_EDGE_Y = -1 * (200/320)
TOP_EDGE_Y = +1 * (200/320)

# FIXME: calculate the camera_scale differently!
camera_scale = 320/2  # projected coordinates go from -1.0 to +1.0 and since that is 2.0 total, we need to divide the width of our screen by 2


def is_2d_vertex_inside_edge(vertex, edge_name):

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
    

def clip_2d_vertex_against_edge(inside_vertex, outside_vertex, edge_name):

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
        if (DEBUG_CLIP_COLORS):
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
        if (DEBUG_CLIP_COLORS):
            clipped_face['color_index'] = 9
        clipped_faces.append(clipped_face)
        
        # Second triangle
        clipped_vertex_0 = clip_2d_vertex_against_edge(inside_vertices[0], outside_vertices[0], edge_name)
        combined_vertices.append(clipped_vertex_0)
        
        clipped_face = copy.deepcopy(non_clipped_face)
# FIXME: we are NOT keeping the CORRECT ORDER of the vertices here!
        clipped_face['vertex_indices'] = [0+svi,3+svi,1+svi]
        if (DEBUG_CLIP_COLORS):
            clipped_face['color_index'] = 10
        clipped_faces.append(clipped_face)

    return clipped_faces


def camera_clip_projected_triangles(projected_faces, projected_vertices, camera_info):

    camera_clipped_projected_faces = []
    camera_clipped_projected_vertices = copy.deepcopy(projected_vertices)
    
    edge_names = ['LEFT', 'TOP', 'RIGHT', 'BOTTOM']

    # We KEEP the old vertices! (even though they are all not being used at the end!
    combined_vertices = camera_clipped_projected_vertices

    # We determine -for each face- whether it should be clipped against the edges of the screen
    for non_clipped_face in projected_faces:

        # We start with the non-clipped face we want to clip along all 4 edges
        queue_faces = [ non_clipped_face ]
        
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
        camera_clipped_projected_faces += queue_faces
                
    return (camera_clipped_projected_faces, camera_clipped_projected_vertices)
    

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


# FIXME: in the end we dont want to do ANY sorting! So this should evenually be REMOVED!
def compare_faces(face_a, face_b):
    
    #if ('in_front_of' in face_a):
    #    if (face_b['orig_index'] in face_a['in_front_of']):
    #        return -1
            
    #if ('in_front_of' in face_b):
    #    if (face_a['orig_index'] in face_b['in_front_of']):
    #        return 1

    obj_name_a = face_a['obj_name']
    obj_name_b = face_b['obj_name']
    if (obj_name_a != obj_name_b):
        avg_z_a = avg_z_per_object[obj_name_a]
        avg_z_b = avg_z_per_object[obj_name_b]        
        if avg_z_a == avg_z_b:
            return 0
        if avg_z_a < avg_z_b:
            return 1
        if avg_z_a > avg_z_b:
            return -1
    else:
        # TODO: this is our 'fallback' method: within an object we look at the sum_of_z of each face (better to use the original (ordered) polygon lists
        if face_a['sum_of_z'] == face_b['sum_of_z']:
            return 0
        if face_a['sum_of_z'] < face_b['sum_of_z']:
            return 1
        if face_a['sum_of_z'] > face_b['sum_of_z']:
            return -1
 
compare_key = cmp_to_key(compare_faces)

def projected_to_screen(projected_x, projected_y):
    screen_x = round(projected_x*camera_scale + center_offset[0])
    screen_y = round(projected_y*camera_scale + center_offset[1])
    # Note: we also flip the y here!
    screen_y = screen_height - screen_y
    return (screen_x, screen_y)
    

def sort_light_draw_and_export(projected_vertices, faces):

# FIXME: this sorter is probably the wrong way around now, since y is not flipped anymore in the projected_vertices!
    def y_sorter(item):
        return projected_vertices[item][1]


    # The vertices are scaled up for the (pygame) screen
    scaled_up_vertices = []
    for projected_vertex in projected_vertices:
        (screen_x, screen_y) = projected_to_screen(projected_vertex[0], projected_vertex[1])
        scaled_up_vertex = [
            screen_x*scale,
            screen_y*scale,
        ]
        scaled_up_vertices.append(scaled_up_vertex)
    
    
    sorted_faces = sorted(faces, key=compare_key, reverse=True)

    for face_index, face in enumerate(sorted_faces):

# FIXME: do the light calculation earlier in the pipeline!
        color_idx = face['color_index']
        
        if (DEBUG_COLORS and not DEBUG_CLIP_COLORS):
            if DEBUG_COLOR_PER_ORIG_TRIANGLE:
                color_idx = face['orig_index'] % 64
            else:
                color_idx = face_index % 64
        
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
increment_frame_by = 1
max_frame_nr = 1800

if DEBUG_SORTING:
    frame_nr = 60
    increment_frame_by = 0

#animation_info = load_animation_info()
#print(json.dumps(animation_info, indent=4))

material_info = load_material_info()
mat_info = material_info['mat_info']
palette_colors = material_info['palette_colors']
colors = []

# HACK: see comment below
avg_z_per_object = {}


for rgb64 in palette_colors:
    # FIXME: 63 * 4 isnt exactly 255!
    r = rgb64['r']*4
    g = rgb64['g']*4
    b = rgb64['b']*4
    colors.append((r,g,b))

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
#print(mat_name_to_index_and_shades)

while running:
    for event in pygame.event.get():
        if event.type == QUIT:
            running = False

        #if event.type == pygame.KEYDOWN:
            #if event.key == pygame.K_RIGHT:
            #    increment_frame_by = 1

    if PRINT_PROGRESS: print("Loading vertices and faces")
    world_objects = load_vertices_and_faces(frame_nr)

    if PRINT_PROGRESS: print("Getting camera info")
    camera_box = world_objects['CameraBox']
    camera_info = get_camera_info_from_camera_box(camera_box)
    del world_objects['CameraBox']
    
    if PRINT_PROGRESS: print("Transform into view space")
    # Rotate and translate all vertices in the world so camera position becomes 0,0,0 and forward direction becomes 0,0,-1 (+up = 0,1,0)
    view_objects = transform_objects_into_view_space(world_objects, camera_info)

# TODO:
# - remove non-visible objects (in Blender)
# OK (almost done) - bundle all objects into ONE list of vertices/faces
# OK (almost done)  - do the step-by-step, backwards
# - after projection, implement a function that gets two lists: projected and unprojected triangles (aka faces)
#   - for each pair of faces/triangles:
#     - determine the 0-2 intersection points
#     - given 1 point, calculate the x/y direction (using the camera focal length)
#     - calculate the 3D intersection POINTS (2x) between this 3D-direction and the two PLANES of the two triangles
#     - mark the relationship between the two triangles (one in front of the other)
#     - MAYBE: already split the triangles?
# - DONT split triangles from: WINDOWS, SHIP and maybe TREES!
# OK - when sorting the triangles, use the relationship between triangles
# OK? (using sum_of_z)  - ISSUE: what if there is NO relationship? See Wolf3D solution to this problem!
# - maybe THINK about re-using vertices that are CREATED during z-clipping, splitting and camera-side-clipping!
#   - One option is to determine if the (2D/3D) point already exists as a vertex
#     - By comparing coordinates (with an EPSILON) of all known vertices, so can find the closely-matching one -- SLOW!
#   - Another option is to semantically store new vertices: "v[1]->v[2]->CLIP_RIGHT", "v[4]->v[17]->CLIP_Z", "v[38]->v[97]->INTERSECTION->v[21]->v[53]"
#     - ISSUE: how do you determine in which ORDER you have to create these identifiers? 
#          SOLUTION: -> simply by vertex_index? 
#             - And which EDGE of the INTERSECTION should go first?
#               SOLUTION:  -> Simply the lowest vertex_index again?
#     - ISSUE: how to deal with 2D vs 3D faces/vertices? 
#         SOLUTION:  are these identifiers only needed *DURING* CLIPPING/SPLITTING? (and can be thrown away afterwards)

# FIXME: maybe BUNDLE all triangles into *ONE LIST* here?!
# FIXME: maybe BUNDLE all triangles into *ONE LIST* here?!
# FIXME: maybe BUNDLE all triangles into *ONE LIST* here?!

    for current_object_name in view_objects:
        
        if (current_object_name == 'CameraBox'):
            continue

        object_vertices = view_objects[current_object_name]['vertices']
        
        # FIXME: this is a HACK! We try to use the average z of all the vertices in an object to do sorting
        #         we should INSTEAD use the 'center vertex' (which is pl[0][1] in the original code: see 'ORD'-part in each object file)
        avg_z_for_object = 0
        for object_vertex in object_vertices:
            avg_z_for_object += object_vertex[2]
        
        avg_z_for_object = avg_z_for_object / len(object_vertices)
        
        # The original engine has a little trick: when an object starts with an underscore (usually the platforms on the ground) then consider it very far away (meaning: always draw first)
        #    See: VISU/C/U2E.C (lines 401-431)
        if current_object_name.startswith('_'):
            avg_z_for_object -= 1000000
        
        avg_z_per_object[current_object_name] = avg_z_for_object


    if PRINT_PROGRESS: print("Backface cull")
    # Backface cull where face/triangle-normal points away from camera
    culled_view_objects = cull_faces_of_objects(view_objects)
    
    if PRINT_PROGRESS: print("Z clipping")
    # Clip/remove where Z < 0 (behind camera)  (we may assume faces are NOT partially visiable AND behind the camera)
    z_clipped_view_objects = z_clip_faces_of_objects(culled_view_objects)
    
    if PRINT_PROGRESS: print("Applying light")
    # Change color of faces/triangles according to the amount of light they get
# FIXME: change this!
# FIXME: change this!
# FIXME: change this!
    # camera_light = [0,0,1]
    # camera_light = [0.707107,0,0.707107]
    # camera_light = [0.666667, -0.333333, 0.666667]
    camera_light = [0.408248, -0.408248, 0.816497]
    
    lit_view_objects = apply_light_to_faces_of_objects(z_clipped_view_objects, camera_light)
    
    if PRINT_PROGRESS: print("Assemble all objects into one list of faces/vertices")
    lit_view_faces = []
    lit_view_vertices = []
    for current_object_name in lit_view_objects:
        # We assemble all objects but the camera(box) here
        
        if (current_object_name == 'CameraBox'):
            continue
            
        if (DEBUG_SORTING):
            if (current_object_name != 'talojota' and current_object_name != '_laatta01'):
                continue
        
        object_vertices = lit_view_objects[current_object_name]['vertices']
        object_faces = lit_view_objects[current_object_name]['faces']
        
        start_vertex_index = len(lit_view_vertices)
        lit_view_vertices += object_vertices
        for object_face in object_faces:
            object_face['vertex_indices'][0] += start_vertex_index
            object_face['vertex_indices'][1] += start_vertex_index
            object_face['vertex_indices'][2] += start_vertex_index
            
            object_face['obj_name'] = current_object_name
            
            lit_view_faces.append(object_face)
        
    if (DEBUG_COLORS):
        for orig_face_index, face in enumerate(lit_view_faces):
            face['orig_index'] = orig_face_index
    
    if PRINT_PROGRESS: print("Projection")
    # Project all vertices to screen-space
    (projected_faces, projected_vertices) = project_triangles(lit_view_faces, lit_view_vertices, camera_info)
    
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

    if PRINT_PROGRESS: print("Determine 2D intersections and split")
# FIXME: remove debug_intersection_points?
# WHAT WHOULD WE DO WITH THIS?
#    (split_projected_faces, split_projected_vertices, debug_intersection_points) = determine_triangle_2d_intersections_and_split(projected_faces, projected_vertices, lit_view_faces, lit_view_vertices, camera_info)
    
    if PRINT_PROGRESS: print("Camera clipping")
    # Clip 4 sides of the camera -> creating NEW triangles!
    (camera_clipped_projected_faces, camera_clipped_projected_vertices) = camera_clip_projected_triangles(projected_faces, projected_vertices, camera_info)
#    (camera_clipped_projected_faces, camera_clipped_projected_vertices) = camera_clip_projected_triangles(split_projected_faces, split_projected_vertices, camera_info)



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

    if PRINT_PROGRESS: print("Sort, draw and export")
    screen.fill((0,0,0))
    tris_seen = sort_light_draw_and_export(camera_clipped_projected_vertices, camera_clipped_projected_faces)
    if tris_seen:
        f.write(b'\xff') # end of frame


    print(str(frame_nr) + ":" +str(len(camera_clipped_projected_faces)))

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


    if (DRAW_INTERSECTION_POINTS):
        pixel_color = (255,0,0)
        for pt_idx, pt in enumerate(debug_intersection_points):
            (screen_x, screen_y) = projected_to_screen(pt[0], pt[1])
        
            pygame.draw.rect(screen, pixel_color, pygame.Rect(screen_x*scale, screen_y*scale, 1*scale, 1*scale))


    pygame.display.flip()
    
    frame_nr += increment_frame_by
    
    if frame_nr > max_frame_nr:
        running = False
    
    clock.tick(60)

# Quit Pygame
pygame.quit()

