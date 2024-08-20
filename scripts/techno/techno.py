# To install pygame: pip install pygame      (my version: pygame-2.1.2)
import pygame
import math
import time

SHOW_OFFLINE_BUFFER = False
SHOW_FRAME_BUFFERS = False
PRESS_KEY_TO_START = False

ROT_ORIGIN = -(2*16)

screen_width = 320
screen_height = 256

scale = 4

background_color = 0

offline_on_screen_x = 10
offline_on_screen_y = 10

frame_buffers_on_screen_x = 10
frame_buffers_on_screen_y = offline_on_screen_y + screen_height + 10
frame_buffer_x_margin = 10
frame_buffer_y_margin = 10
    

pygame.init()


clr_blk = (0,0,0) # black
clr_drk = (221,152,181) # dark
clr_med = (253,206,238) # medium
clr_lgt = (253,255,255) # light    # FIXME: not distinguishable from WHITE!
clr_wht = (253,255,255) # white

palette = [
    clr_blk,  # 0000b
    clr_drk,  # 0001b
    clr_drk,  # 0010b
    clr_med,  # 0011b
    
    clr_drk,  # 0100b
    clr_med,  # 0101b
    clr_med,  # 0110b
    clr_lgt,  # 0111b
    
    clr_drk,  # 1000b
    clr_med,  # 1001b
    clr_med,  # 1010b
    clr_lgt,  # 1011b
    
    clr_med,  # 1100b
    clr_lgt,  # 1101b
    clr_lgt,  # 1110b
    clr_wht,  # 1111b
]


offline_surface = pygame.Surface((screen_width, screen_height), depth = 8)

frame_buffers = []    
for frame_buffer_idx in range(8):
    frame_buffer = pygame.Surface((screen_width, screen_height), depth = 8)
    frame_buffer.set_palette(palette)
    frame_buffers.append(frame_buffer)
    
pygame.display.set_caption('X16 2R Techno test')

screen_size = (screen_width*scale, screen_height*scale)
final_on_screen_x = 0
final_on_screen_y = 0
if SHOW_OFFLINE_BUFFER or SHOW_FRAME_BUFFERS:
    screen_size = (screen_width*4.5, screen_height*3.5)
    final_on_screen_x = offline_on_screen_x + screen_width + 10
    final_on_screen_y = 10 


screen = pygame.display.set_mode(screen_size)
clock = pygame.time.Clock()

def combine_offline_with_frame_buffer(offline_surface, frame_buffer, mask):

    offline_pxarray = pygame.PixelArray(offline_surface)
    frame_pxarray = pygame.PixelArray(frame_buffer)
    
    for y in range(screen_height):
        for x in range(screen_width):
            offline_pixel_idx = offline_pxarray[x,y]
            
            frame_pixel_idx = frame_pxarray[x,y]
            
            offline_pixel_idx_masked = offline_pixel_idx & mask
            frame_pixel_idx_masked = frame_pixel_idx & (~mask)
            
            combined_pixel_idx = offline_pixel_idx_masked | frame_pixel_idx_masked
            
            frame_pxarray[x,y] = combined_pixel_idx # 255 

    frame_pxarray.close()
    offline_pxarray.close()


def run():

    running = True
    save_tiles = False
    saved_tiles_cnt = 0
    do_crosshatch = False
    do_choreo = False
    xoff = 0
    yoff = 0
    
    frame_nr = 0
       
    screen.fill(background_color)

    # These are the variables from the original:
    rot = ROT_ORIGIN
    vm = 50
    vma = 0
    frame_buffer_idx = 0 # original: plv=0
    mask = 0x01 # original: pl=1
    
    
    keep_animating = True
    if PRESS_KEY_TO_START:
        keep_animating = False
    
    
    while running:
        # TODO: We might want to set this to max?
        clock.tick(30)
        
        for event in pygame.event.get():

            if event.type == pygame.QUIT: 
                running = False

            if event.type == pygame.KEYDOWN:
                    
                #if event.key == pygame.K_LEFT:
                #if event.key == pygame.K_RIGHT:
                #if event.key == pygame.K_COMMA:
                #if event.key == pygame.K_PERIOD:
                #if event.key == pygame.K_UP:
                #if event.key == pygame.K_DOWN:
                
                if event.key == pygame.K_SPACE:
                    # Press SPACE to start animation
                    keep_animating = True
                    
        if (keep_animating):
            # FIXME: for now clearing the screen every frame
            #screen.fill(background_color)
            
            # Normally 360 degrees = math.pi * 2
            # In the original: 1024 = math.pi * 2
            # So rot_radians = rot / 1024 * (math.pi * 2)
            
            offline_surface.fill((0,0,0))
            
            for c in range(0,screen_width*2,24):
                offset = (math.sin(rot/math.pi)*28)
         
                x1 = c+offset
                y1 = 0
                
                x2 = c+offset+10
                y2 = 0
                
                x3 = c-offset
                y3 = screen_height-1
                
                x4 = c-(offset+10)
                y4 = screen_height-1
                
                pixel_color = (0xFF, 0xFF, 0xFF)
                polygon = [(x1,y1),(x2,y2),(x3,y3),(x4,y4)]
                pygame.draw.polygon(offline_surface, 255, polygon, 0)

                
            rot += 1
        
            # in original: "asmdoit"
            frame_buffer = frame_buffers[frame_buffer_idx]
            combine_offline_with_frame_buffer(offline_surface, frame_buffer, mask)
            

            # Show buffers on screen
            if SHOW_OFFLINE_BUFFER:
                screen.blit(offline_surface, (offline_on_screen_x, offline_on_screen_y))

            if SHOW_FRAME_BUFFERS:
                screen_x = frame_buffers_on_screen_x + int(frame_buffer_idx % 4) * (screen_width+frame_buffer_x_margin)
                screen_y = frame_buffers_on_screen_y + int(frame_buffer_idx // 4) * (screen_height+frame_buffer_y_margin)
                screen.blit(frame_buffer, (screen_x, screen_y))

            
            if (not SHOW_OFFLINE_BUFFER) and (not SHOW_FRAME_BUFFERS):
                if frame_buffer_idx >= 0:
                    screen.blit(pygame.transform.scale(frame_buffer, (screen_width*scale, screen_height*scale)), (final_on_screen_x, final_on_screen_y))
                
            else:
                screen.blit(frame_buffer, (final_on_screen_x, final_on_screen_y))
        
        
            # in original: "plv++"
            frame_buffer_idx += 1
        
            # in original: "plv&=7"
            if (frame_buffer_idx >= 8):
                frame_buffer_idx = 0
                # Original:
                '''
                if(!plv)
                {
                    pl<<=1;
                    if(pl>15) pl=1;
                }  
                '''        
                mask = mask << 1
                if mask > 15:
                    mask = 1
                    rot = ROT_ORIGIN
                    save_tiles = True

                # FIXME!
                # keep_animating = False

            frame_nr += 1

            if save_tiles and saved_tiles_cnt < 8:
                frame_pxarray = pygame.PixelArray(frame_buffers[frame_buffer_idx])

                with open(f"TECHNOTILE{saved_tiles_cnt}.DAT", mode="wb") as file:
                    for b in range(32): # blank tile
                        file.write(bytes([0x00]))
                    for s in [0, 8, 16]:
                        for y in range(screen_height):
                            for x in range(s,s+8,2):
                                xx = int(screen_width/2)+x
                                pidx = frame_pxarray[xx,y]
                                p = (pidx & 0xf) << 4
                                pidx = frame_pxarray[xx+1,y]
                                p = p | (pidx & 0xf)
                                file.write(bytes([p]))

                frame_pxarray.close()
                saved_tiles_cnt += 1

                if saved_tiles_cnt >= 8: # save the map now too
                    with open("TECHNOMAP.DAT", mode="wb") as file:
                        for y in range(32):
                            for x in range(32):
                                p = 1 + (y + (32*(x % 3)))
                                file.write(bytes([p]))
                    keep_animating = False
                    do_crosshatch = True
                    saved_tiles_cnt = 0
                    saved_tiles = False

        if do_crosshatch:
            for cross_frame in range(8):
                frame_buffers[0].fill((0,0,0))

                # Vertical
                mask = 2
                offline_surface.fill((0,0,0))

                for c in range(0,screen_width*2,32):
                    x1 = c
                    y1 = 0

                    x2 = c+16
                    y2 = 0

                    x4 = c
                    y4 = screen_height-1

                    x3 = c+16
                    y3 = screen_height-1

                    pixel_color = (0xFF, 0xFF, 0xFF)
                    polygon = [(x1,y1),(x2,y2),(x3,y3),(x4,y4)]
                    pygame.draw.polygon(offline_surface, 255, polygon, 0)

                frame_buffer = frame_buffers[0]
                combine_offline_with_frame_buffer(offline_surface, frame_buffer, mask)

                if frame_buffer_idx >= 0:
                    screen.blit(pygame.transform.scale(frame_buffer, (screen_width*scale, screen_height*scale)), (final_on_screen_x, final_on_screen_y))

                # Horizontal
                mask = 1
                offline_surface.fill((0,0,0))

                for c in range(0,screen_height*2,32):
                    x1 = 0
                    y1 = c

                    x2 = 0
                    y2 = c+16

                    x4 = screen_width-1
                    y4 = c

                    x3 = screen_width-1
                    y3 = c+16

                    pixel_color = (0xFF, 0xFF, 0xFF)
                    polygon = [(x1,y1),(x2,y2),(x3,y3),(x4,y4)]
                    pygame.draw.polygon(offline_surface, 255, polygon, 0)

                frame_buffer = frame_buffers[0]
                combine_offline_with_frame_buffer(offline_surface, frame_buffer, mask)

                if frame_buffer_idx >= 0:
                    screen.blit(pygame.transform.scale(frame_buffer, (screen_width*scale, screen_height*scale)), (final_on_screen_x, final_on_screen_y))

                # Diagonal forward
                mask = 4
                offline_surface.fill((0,0,0))

                for c in range(-screen_width,screen_width*2,32):
                    x1 = c+(4*cross_frame)
                    y1 = 0

                    x2 = c+16+(4*cross_frame)
                    y2 = 0

                    x4 = c+screen_height+(4*cross_frame)
                    y4 = screen_height-1

                    x3 = c+16+screen_height+(4*cross_frame)
                    y3 = screen_height-1

                    pixel_color = (0xFF, 0xFF, 0xFF)
                    polygon = [(x1,y1),(x2,y2),(x3,y3),(x4,y4)]
                    pygame.draw.polygon(offline_surface, 255, polygon, 0)

                frame_buffer = frame_buffers[0]
                combine_offline_with_frame_buffer(offline_surface, frame_buffer, mask)

                if frame_buffer_idx >= 0:
                    screen.blit(pygame.transform.scale(frame_buffer, (screen_width*scale, screen_height*scale)), (final_on_screen_x, final_on_screen_y))

                # Diagonal back
                mask = 8
                offline_surface.fill((0,0,0))

                for c in range(-screen_width,screen_width*2,32):
                    x1 = c+(4*cross_frame)
                    y1 = screen_height-1

                    x2 = c+16+(4*cross_frame)
                    y2 = screen_height-1

                    x4 = c+screen_height+(4*cross_frame)
                    y4 = 0

                    x3 = c+16+screen_height+(4*cross_frame)
                    y3 = 0

                    pixel_color = (0xFF, 0xFF, 0xFF)
                    polygon = [(x1,y1),(x2,y2),(x3,y3),(x4,y4)]
                    pygame.draw.polygon(offline_surface, 255, polygon, 0)

                frame_buffer = frame_buffers[0]
                combine_offline_with_frame_buffer(offline_surface, frame_buffer, mask)

                if frame_buffer_idx >= 0:
                    screen.blit(pygame.transform.scale(frame_buffer, (screen_width*scale, screen_height*scale)), (final_on_screen_x, final_on_screen_y))

                pygame.display.update()
                clock.tick(30)
                with open(f"TECHNOTILE{cross_frame}.DAT", "ab") as file:
                    frame_pxarray = pygame.PixelArray(frame_buffers[0])
                    for s in [0, 8, 16, 24]:
                        for y in range(32):
                            for x in range(s,s+8,2):
                                xx = int(screen_width/2)+x
                                pidx = frame_pxarray[xx,y]
                                p = (pidx & 0xf) << 4
                                pidx = frame_pxarray[xx+1,y]
                                p = p | (pidx & 0xf)
                                file.write(bytes([p]))
                    frame_pxarray.close()

            do_crosshatch = False
            do_choreo = True

        if do_choreo:
            with open("TECHNOCHOREO.DAT", mode="wb") as file:
                for s in range(1700):

                    bu = math.sin(s/1.5)/10
                    bv = math.sin((s+20)/30)/8

                    if bu < 0:
                        bu = -1/(bu-1)
                    else:
                        bu = 1+bu

                    if bv < 0:
                        bv = -1/(bv-1)
                    else:
                        bv = 1+bv

                    if s > 1080:
                        sc *= 1/(bv**0.2)
                        bu = 1
                        su *= 1.009
                        a -= su/384 * math.pi * 2
                        xoff += 1
                    elif s > 1079:
                        xoff = 0
                        sc = 1.5
                        bu = 1
                        a -= su/384 * math.pi * 2
                        sp = 0
                    elif s > 850:
                        sc *= 1/(bv**0.18)
                        bu = 1
                        a -= su/256 * math.pi * 2
                        su /= 1.01
                        sp = 0
                        xoff += 3
                    elif s > 640:
                        sc = 1
                        bu = 1
                        a -= su/256 * math.pi * 2
                        su *= 1.008
                        sp += math.pi/1000
                        xoff += 1
                    elif s > 639:
                        sc *= 1/(bv**0.18)
                        bu = 1
                        a -= su/256 * math.pi * 2
                        sp = 0 #(-1)*math.pi/8
                        su = 2
                        xoff += 3
                    elif s > 500:
                        sc *= 1/(bv**0.18)
                        bu = 1
                        a -= su/256 * math.pi * 2
                        su *= 1.003
                        #sp -= math.pi/120
                        xoff += 1
                    elif s > 400:
                        sc *= 1/(bv**0.18)
                        bu = 1
                        a -= su/256 * math.pi * 2
                        su *= 1.013
                        sp -= math.pi/140
                    elif s > 399:
                        bu = 1
                        a -= su/256 * math.pi * 2
                        su = 2
                        sp -= math.pi/160
                    elif s > 320:
#                        sc = 0.01+((s-350)/70)
                        sc = 3 - ((s-320)/50)
                        bu = 1
                        a = -s/256 * math.pi * 2
                        xoff = 0
                        su = 1.5
                        sp -= math.pi/110
                    elif s > 319:
                        sp = (-5)*math.pi/8
                        a = -s/384 * math.pi * 2
                    elif s > 270:
                        sc = 1.1-((s-270)/45)
                        xoff += 0.3
                        a = -s/384 * math.pi * 2
                    else:
                        sp = 0
                        sc = 1.1
                        a = -s/384 * math.pi * 2

                    #a = -s/2768 * math.pi * 2
                    o = a+math.atan2(10,-16)

                    print(f"s {s} a {a} o {o} sin {math.sin(a)} cos {math.cos(a)}")

                    sinstep = round(sc*math.sin(a)*-256) << 1
                    cosstep = round(bu*sc*math.cos(a+sp)*256) << 1

                    hy = math.sqrt(((80*sc))**2 + (50*sc)**2)
                    hyx = bu*hy*math.cos(o+sp)
                    hyy = hy*math.sin(o)

                    x = round((128*256) + (hyx*256) + (xoff*256))
                    y = round((128*256) + (hyy*-256) + (yoff*256))

                    aff_incr_x = round(bu*sc*math.sin(a+sp)*-256)
                    aff_incr_y = round(sc*math.cos(a)*256)

                    if sinstep < 0:
                        sinstep += 65536
                    if cosstep < 0:
                        cosstep += 65536
                    if x < 0:
                        x += 65536
                    if y < 0:
                        y += 65536
                    if aff_incr_x < 0:
                        aff_incr_x += 65536
                    if aff_incr_y < 0:
                        aff_incr_y += 65536

                    # Low cos, high cos, low sin, high sin, x (sub low high), y (sub low high)
                    st = [cosstep % 256, (cosstep // 256) & 0x7F, sinstep % 256, (sinstep // 256) & 0x7F]

                    st.append(x % 256)
                    st.append(x//256 % 256)

                    st.append(y % 256)
                    st.append(y//256 % 256)

                    st.append(aff_incr_x % 256)
                    st.append(aff_incr_x // 256)

                    st.append(aff_incr_y % 256)
                    st.append(aff_incr_y // 256)

                    print(st)
                    file.write(bytes(st))
            running = False

        pygame.display.update()


    pygame.quit()


run()
