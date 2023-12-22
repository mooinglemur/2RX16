# To install pygame: pip install pygame      (my version: pygame-2.1.2)
import pygame
import math
import time

SHOW_OFFLINE_BUFFER = False
SHOW_FRAME_BUFFERS = False
PRESS_KEY_TO_START = True

screen_width = 320
screen_height = 200

scale = 2

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
    
    frame_nr = 0
       
    screen.fill(background_color)

    # These are the variables from the original:
    rot = 45
    vm = 50
    vma = 0
    frame_buffer_idx = 0 # original: plv=0
    mask = 0x01 # original: pl=1
    
    
    keep_animating = True
    if PRESS_KEY_TO_START:
        keep_animating = False
    
    
    while running:
        # TODO: We might want to set this to max?
        clock.tick(60)
        
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
                    
            #if event.type == pygame.MOUSEMOTION: 
                # newrect.center = event.pos
            
            
            # Original "doit1"
            '''
            int    rot=45;
            int    x,y,c,x1,y1,x2,y2,x3,y3,x4,y4,a,hx,hy,vx,vy,cx,cy;
            int    vma,vm;
            vm=50; vma=0;
            waitborder();
            plv=0; pl=1;
            
            ... frame loop ...
            {
                hx=sin1024[(rot+0)&1023]*16*6/5;
                hy=sin1024[(rot+256)&1023]*16;
                vx=sin1024[(rot+256)&1023]*6/5;
                vy=sin1024[(rot+512)&1023];
                vx=vx*vm/100;
                vy=vy*vm/100;
                for(c=-10;c<11;c+=2)
                {
                    cx=vx*c*2; cy=vy*c*2;
                    x1=(-hx-vx+cx)/16+160; y1=(-hy-vy+cy)/16+100;
                    x2=(-hx+vx+cx)/16+160; y2=(-hy+vy+cy)/16+100;
                    x3=(+hx+vx+cx)/16+160; y3=(+hy+vy+cy)/16+100;
                    x4=(+hx-vx+cx)/16+160; y4=(+hy-vy+cy)/16+100;
                    asmbox(x1,y1,x2,y2,x3,y3,x4,y4);
                }
                rot+=2;
                vm+=vma;
                if(vm<25) 
                {
                    vm-=vma;
                    vma=-vma;
                }
                vma--;            
            }
            '''

        
        if (keep_animating):
            # FIXME: for now clearing the screen every frame
            #screen.fill(background_color)
            
            # Normally 360 degrees = math.pi * 2
            # In the original: 1024 = math.pi * 2
            # So rot_radians = rot / 1024 * (math.pi * 2)
            
            rot_0_radians =   ((rot+0)   & 1023) / 1024 * (math.pi * 2)
            rot_256_radians = ((rot+256) & 1023) / 1024 * (math.pi * 2)
            rot_512_radians = ((rot+512) & 1023) / 1024 * (math.pi * 2)
            
            hx = 256 * math.sin(rot_0_radians) * 16      # removed: *6/5 (since we have square pixels)
            hy = 256 * math.sin(rot_256_radians) * 16
            vx = 256 * math.sin(rot_256_radians)         # removed: *6/5 (since we have square pixels)
            vy = 256 * math.sin(rot_512_radians)
            
            vx = vx * vm/100
            vy = vy * vm/100
            
            offline_surface.fill((0,0,0))
            
            for c in range(-10,11,2):
                cx = vx*c*2
                cy = vy*c*2
                
                x1 = (-hx-vx+cx)/16+160
                y1 = (-hy-vy+cy)/16+100
                
                x2 = (-hx+vx+cx)/16+160
                y2 = (-hy+vy+cy)/16+100
                
                x3 = (+hx+vx+cx)/16+160
                y3 = (+hy+vy+cy)/16+100
                
                x4 = (+hx-vx+cx)/16+160
                y4 = (+hy-vy+cy)/16+100
                
                #asmbox(x1,y1,x2,y2,x3,y3,x4,y4)
                # print(x1,y1,x2,y2,x3,y3,x4,y4)
                
                
                # pixel_color = (221,152,181)
                pixel_color = (0xFF, 0xFF, 0xFF)
                polygon = [(x1,y1),(x2,y2),(x3,y3),(x4,y4)]
                pygame.draw.polygon(offline_surface, 255, polygon, 0)

                
            rot += 2
            vm += vma
            if(vm < 25):
                vm -= vma
                vma = -vma
            vma -= 1
        
        
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

                # FIXME!
                # keep_animating = False
        
            frame_nr += 1    
        
        pygame.display.update()
        
        #time.sleep(0.01)
   
        
    pygame.quit()


    
run()
