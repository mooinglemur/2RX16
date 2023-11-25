#!/usr/bin/env python3

import pygame
from pygame.locals import *
import math
from enum import Enum
import copy
import time
from shapely.geometry import Polygon, GeometryCollection
import numpy as np

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


clock=pygame.time.Clock()

# Set up the display
screen_width, screen_height = 320, 200
screen = pygame.display.set_mode((screen_width*3, screen_height*3))
pygame.display.set_caption("3D Scene")



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


def load_vertices_and_faces(frame_nr):

    # In Blender do:
    #  - File->Export->Wavefront (obj)
    #  - Forward Axis: Y
    #  - Upward Axis: Z
    #  - Select: Normals, Triangulated Mesh, Materials->Export
    #  - TODO: also export Animation
    
    # obj_file = open('assets/3d_scene/test_cube.obj', 'r')
    # obj_file = open('assets/3d_scene/test_cube_straight.obj', 'r')
    obj_file = open('assets/3d_scene/test_cube' + str(frame_nr) + '.obj', 'r')
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
            vertex_indexes = []
            normal_index = None
            for line_part in line_parts:
                # There are in fact two indexes: one for the vertex and one for the normal.
                vertex_index = int(line_part.split('//')[0])-1   
                vertex_indexes.append(vertex_index)
                # Note: we overwrite the normal index, since we assume this is a triangle and has ONE normal for each face
                normal_index = int(line_part.split('//')[1])-1   
                
            
            # FIXME: we need a proper way to map colors!
            #   Its probably best to read in the .mtl (material file)
            if current_material_name in material_name_to_color_index:
                color_index = material_name_to_color_index[current_material_name]
            else:
                print("Unknown material")
                exit()
                
            # FIXME: this is ASSUMING there are EXACTLY 3 vertex indices! Make sure this is the case!
            # FIXME?: right now, we convert a global vertex (and normal) index into an object-vertex (and normal) index. Is this actually a good idea?
            objects[current_object_name]['faces'].append({
                'vertex_indices' : [ 
                    vertex_indexes[0] - object_start_vertex_index,
                    vertex_indexes[1] - object_start_vertex_index,
                    vertex_indexes[2] - object_start_vertex_index 
                ],
                'normal_index' : normal_index - object_start_normal_index,
                'color_index' : color_index,
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
    
    
def cull_objects(view_objects):

    culled_view_objects = {}
    
    for current_object_name in view_objects:
    
        view_object = view_objects[current_object_name]
        culled_view_object = copy.deepcopy(view_object)
        
        culled_view_object['faces'] = []
        
        for face in view_object['faces']:
           
            # FIXME: add LOGIC here!
            if face['color_index'] == 7:
                continue
        
            culled_view_object['faces'].append(face)
        
        culled_view_objects[current_object_name] = culled_view_object
    
    return culled_view_objects




# FIXME: calculate the scale differently!
scale = 37

center_offset = (screen_width // 2, screen_height // 2)

# FIXME: REMOVE or set to 0,0,0!
camera = (0, 0, 6)

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

def project_light_draw_and_export(vertices, faces):

    def face_sorter(item):
        return zees[item['vertex_indices'][0]]+zees[item['vertex_indices'][1]]+zees[item['vertex_indices'][2]]

    def y_sorter(item):
        return y_flipped_projected_vertices[item][1]

    tris_seen = False
    y_flipped_projected_vertices = []
    projected_vertices = []
    unscaled_rotated_vertices = []
    zees = []
    
    # Projection of the vertices of the visible faces
    for vertex in vertices:
        x = vertex[0]
        y = vertex[1]
        z = vertex[2]
        
        new_x = x
        new_y = y
        new_z = z

        # FIXME: we should use a ~42? degree FOV!
        
        # Note: since 'forward' is negative Z -for the object in front of the camera- we want to divide by negative z 
        z_ratio = 1 / -new_z

        # FIXME: both SIDES of the CUBE dont look STRAIGHT (zoomed in)! There is something WRONG!
        # FIXME: both SIDES of the CUBE dont look STRAIGHT (zoomed in)! There is something WRONG!
        # FIXME: both SIDES of the CUBE dont look STRAIGHT (zoomed in)! There is something WRONG!

        new_x *= (z_ratio*6)
        new_y *= (z_ratio*6)
        
        x_proj = new_x * scale + center_offset[0]
        y_proj = new_y * scale + center_offset[1]
        z_proj = new_z * scale

        projected_vertices.append((round(x_proj), round(y_proj)))
        zees.append(z_proj)
        unscaled_rotated_vertices.append((new_x, new_y, new_z))
        
    # We calculate the sum of z for every face
    '''
    for face in faces:
        face_vertex_indices = face['vertex_indices']
        
        vertex1 = vertices[face_vertex_indices[0]]
        vertex2 = vertices[face_vertex_indices[1]]
        vertex3 = vertices[face_vertex_indices[2]]
        
        sum_of_z = vertex1[2] + vertex2[2] + vertex3[2]
        
        face['sum_of_z']
       ''' 

    
# FIXME: should we reverse here?
    sorted_faces = sorted(faces, key=face_sorter, reverse=True)

    visible_faces = []
    visible_polys = []

    for face in sorted_faces:
        face_vertex_indices = face['vertex_indices'] + [face['vertex_indices'][0]]
        fc = Polygon([projected_vertices[i] for i in face_vertex_indices])
        covers = False

        if len(visible_faces) > 0:
            u = visible_polys[0]
            for p in visible_polys[1:]:
                u = u.union(p)
            if u.contains(fc):
                covers = True
            
        if not covers:
            visible_faces.append(face)
            visible_polys.append(fc)

# FIXME: should we reverse here?
    sorted_visible_faces = sorted(visible_faces, key=face_sorter, reverse=False)

    for face in sorted_visible_faces:

        # find angle relative to Z axis
        '''
# FIXME: clean this up!
        vert1 = np.array([unscaled_rotated_vertices[face['vertex_indices'][0]][0],unscaled_rotated_vertices[face['vertex_indices'][0]][1],unscaled_rotated_vertices[face['vertex_indices'][0]][2]])
        vert2 = np.array([unscaled_rotated_vertices[face['vertex_indices'][1]][0],unscaled_rotated_vertices[face['vertex_indices'][1]][1],unscaled_rotated_vertices[face['vertex_indices'][1]][2]])
        vert3 = np.array([unscaled_rotated_vertices[face['vertex_indices'][2]][0],unscaled_rotated_vertices[face['vertex_indices'][2]][1],unscaled_rotated_vertices[face['vertex_indices'][2]][2]])

        edge1 = vert2 - vert1
        edge2 = vert3 - vert1

        normal = np.cross(edge1, edge2)

        lightsource = np.array([100, -100, -100])

        dot_product = np.dot(normal, lightsource)

        angle_rad = np.arccos(dot_product / (np.linalg.norm(normal) * np.linalg.norm(lightsource)))

        angle_deg = np.degrees(angle_rad)
        if angle_deg >= 89.9:
            angle_deg = 89.9

        print(f"Angle relative to the light source: {angle_deg} degrees")
        
# FIXME!        color_idx = (face['color_index'] % 2) + (2*int(angle_deg/15))
        '''
        
        color_idx = face['color_index']
        color_idx_out = color_idx + 1
        color_idx_out += 16*color_idx_out

        face_vertex_indices = face['vertex_indices'] + [face['vertex_indices'][0]]
        
        # The vertices are y-flipped and scaled up for the screen
        for rotated_vertex in projected_vertices:
            y_flipped_vertex = [
                rotated_vertex[0]*3,
                (screen_height - rotated_vertex[1])*3,
            ]
            y_flipped_projected_vertices.append(y_flipped_vertex)
        
# FIXME!
        #if (color_idx != 7):
        #    continue
            
        pygame.draw.polygon(screen, colors[color_idx], [y_flipped_projected_vertices[i] for i in face_vertex_indices], 0)
        
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

        v0 = list(copy.deepcopy(y_flipped_projected_vertices[sorted_points[0]]))
        v1 = list(copy.deepcopy(y_flipped_projected_vertices[sorted_points[1]]))
        v2 = list(copy.deepcopy(y_flipped_projected_vertices[sorted_points[2]]))

        if v2[1] < 0:
            print("Fully offscreen")
            continue # fully offscreen

        tris_seen = True


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

    return tris_seen
    

# Main game loop
running = True

f = open("trilist.bin", "wb")

frame_nr = 1
increment_frame_by = 0
#increment_frame_by = 1
max_frame_nr = 100

while running:
    for event in pygame.event.get():
        if event.type == QUIT:
            running = False

        #if event.type == pygame.KEYDOWN:
            #if event.key == pygame.K_RIGHT:
            #    increment_frame_by = 1

    world_objects = load_vertices_and_faces(frame_nr)

    camera_box = world_objects['CameraBox']
    camera_info = get_camera_info_from_camera_box(camera_box)
    
    # Rotate and translate all vertices in the world so camera position becomes 0,0,0 and forward direction becomes 0,0,-1 (+up = 0,1,0)
    view_objects = transform_objects_into_view_space(world_objects, camera_info)

    culled_view_objects = cull_objects(view_objects)

    '''
     === Implement this ===
    
    # Backface cull where face/triangle-normal points away from camera
    # Clip/remove where Z < 0 (behind camera)  (we may assume faces are NOT partially visiable AND behind the camera)
    # Clip 4 sides of the camera -> creating NEW triangles!
    culled_and_clipped_triangles = cull_and_clip_objects_into_visible_triangles(view_objects, camera_info)

    # Change color of faces/triangles according to the amount of light they get. Possibly multiple lights (with a certain range)
    lit_triangles = apply_light_to_triangles(culled_and_clipped_triangles, lights)
    
    # Sort triangles by Z
    z_sorted_triangles = sort_triangles_by_z(lit_triangles)
    
    # Project all vertices to screen-space
    # Flip y
    projected_triangles = project_triangles_onto_screen(z_sorted_triangles, camera_info)
    
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

    # FIXME: this is a temporary workaround. We should get all objects but the camera here!
    vertices = culled_view_objects['Cube']['vertices']
    faces = culled_view_objects['Cube']['faces']

    screen.fill(BLACK)
    tris_seen = project_light_draw_and_export(vertices, faces)
    if tris_seen:
        f.write(b'\xff') # end of frame

    pygame.display.flip()
    
    frame_nr += increment_frame_by
    
    if frame_nr > max_frame_nr:
        running = False
    
    clock.tick(60)

# Quit Pygame
pygame.quit()

