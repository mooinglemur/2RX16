# To install pygame: pip install pygame      (my version: pygame-2.1.2)
import pygame
import math
import time


screen_width = 320
screen_height = 200

scale = 2

background_color = (0,0,0)

pygame.init()

pygame.display.set_caption('X16 2R Techno test')
screen = pygame.display.set_mode((screen_width*scale, screen_height*scale))
clock = pygame.time.Clock()

def run():

    running = True
    
    frame_nr = 0
       
    screen.fill(background_color)

    # These are the variables from the original:
    rot = 45
    # x,y,c,x1,y1,x2,y2,x3,y3,x4,y4,a,hx,hy,vx,vy,cx,cy
    # vma,vm
    vm = 50
    vma = 0
    # waitborder()
    # plv=0
    # pl=1
    
    keep_animating = True
    
    while running:
        # TODO: We might want to set this to max?
        clock.tick(60)
        
        for event in pygame.event.get():

            if event.type == pygame.QUIT: 
                running = False

            '''
            # if event.type == pygame.KEYDOWN:
                    
                #if event.key == pygame.K_LEFT:
                #if event.key == pygame.K_RIGHT:
                #if event.key == pygame.K_COMMA:
                #if event.key == pygame.K_PERIOD:
                #if event.key == pygame.K_UP:
                #if event.key == pygame.K_DOWN:
                    
            #if event.type == pygame.MOUSEMOTION: 
                # newrect.center = event.pos
            '''
            
            
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
            screen.fill(background_color)
            
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
                print(x1,y1,x2,y2,x3,y3,x4,y4)
                
                
                pixel_color = (221,152,181)
                # pixel_color = (0xFF, 0xFF, 0xFF)
                polygon = [(x1*scale,y1*scale),(x2*scale,y2*scale),(x3*scale,y3*scale),(x4*scale,y4*scale)]
                pygame.draw.polygon(screen, pixel_color, polygon, 0)
                
            rot += 2
            vm += vma
            if(vm < 25):
                vm -= vma
                vma = -vma
            vma -= 1
        
        # FIXME!
        keep_animating = False
        
        frame_nr += 1    
        
        pygame.display.update()
        
        #time.sleep(0.01)
   
        
    pygame.quit()


    
run()
