#!/usr/bin/env python3

from PIL import Image
import pygame
import math
import time
import random
import os

MAXY = 280
PSINI_OFFSET = 0
LSINI4_OFFSET = 16384
LSINI16_OFFSET = (16384 + 8192)

SCREEN_WIDTH = 320
SCREEN_HEIGHT = 400
FRAME_BUFFER_WIDTH = 384
FRAME_BUFFER_HEIGHT = 400

YADD = 0

fb = [0] * (FRAME_BUFFER_WIDTH * FRAME_BUFFER_HEIGHT)
prevfb = [0] * (FRAME_BUFFER_WIDTH * FRAME_BUFFER_HEIGHT)

psini = [0] * (16384 + 8192 + 8192)
ptau = [0] * 129

pals=[[0] * 768 for i in range(6)]

selfmod = [[0] * 84 for i in range(5)]

fadepal = [0] * (768 * 2)
cop_fadepal = 0

palette = [63] * 768
line_compare = 0

frame_count = 0
cop_drop = 0
do_pal = 0
cop_start = 0
cop_scrl = 0
cop_plz = 1

curpal=0
timetable=[64*6*2-45,64*6*4-45,64*6*5-45,64*6*6-45,64*6*7+90,0]
ttptr=0

l1=1000
l2=2000
l3=3000
l4=4000

k1=3500
k2=2300
k3=3900
k4=3670

il1=1000
il2=2000
il3=3000
il4=4000

ik1=3500
ik2=2300
ik3=3900
ik4=3670

inittable=[
    [1000,2000,3000,4000,3500,2300,3900,3670],
    [1000,2000,4000,4000,1500,2300,3900,1670],
    [3500,1000,3000,1000,3500,3300,2900,2670],
    [1000,2000,3000,4000,3500,2300,3900,3670],
    [1000,2000,3000,4000,3500,2300,3900,3670],
    [1000,2000,3000,4000,3500,2300,3900,3670]
]

dtau = [0] * 65

plane_select = [0] * 4

x16_pal = [[] for i in range(6)]

def init_copper():
    global dtau
    for ccc in range(65):
        dtau[ccc] = math.trunc(ccc * ccc / 4 * 43 / 128 + 60)

def setplzparas(c1, c2, c3, c4):
    global selfmod

    for ccc in range(84):
        lc1 = c1 + PSINI_OFFSET + (ccc * 8)
        selfmod[1][ccc] = lc1

        lc2 = c2 + LSINI16_OFFSET - (ccc * 4) + (80 * 4)
        selfmod[2][ccc] = lc2

        lc3 = c3 + PSINI_OFFSET - (ccc * 4) + (80 * 4)
        selfmod[3][ccc] = lc3

        lc4 = c4 + LSINI4_OFFSET + (ccc * 16)
        selfmod[4][ccc] = lc4

def plzline(y, vseg):
    nVgaYOffset = vseg << 4

    cccTable = [
        3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12, 19, 18,
        17, 16, 23, 22, 21, 20, 27, 26, 25, 24, 31, 30, 29, 28, 35,
        34, 33, 32, 39, 38, 37, 36, 43, 42, 41, 40, 47, 46, 45, 44,
        51, 50, 49, 48, 55, 54, 53, 52, 59, 58, 57, 56, 63, 62, 61,
        60, 67, 66, 65, 64, 71, 70, 69, 68, 75, 74, 73, 72, 79, 78,
        77, 76, 83, 82, 81, 80
    ]

    ah = 0
    al = 0
    eax = 0
    
    for i in range(84):
        ccc = cccTable[i]

        if (ccc & 1) == 1:
            offs = (y * 2) + selfmod[2][ccc]
            bx = psini[offs]

            offs = bx + selfmod[1][ccc]
            ah = psini[offs]

            offs = (y * 2) + selfmod[4][ccc]
            bx = psini[offs]

            offs = bx + (y * 2) + selfmod[3][ccc]
            ah += psini[offs]
        else:
            offs = (y * 2) + selfmod[2][ccc]
            bx = psini[offs]

            offs = bx + selfmod[1][ccc]
            al = psini[offs]

            offs = (y * 2) + selfmod[4][ccc]
            bx = psini[offs]

            offs = bx + (y * 2) + selfmod[3][ccc]
            al += psini[offs]

        if ((ccc & 3) == 2):
            eax = (ah << 8) | al
            eax <<= 16

        if ((ccc & 3) == 0):
            eax |= (ah << 8) | al
            vga_write32(nVgaYOffset + ccc, eax)

def vga_upload_palette():
    global palette
    global pals
    for i in range(768):
        palette[i] = fadepal[i]

def vga_select_bitplanes_02():
    global plane_select
    plane_select[0] = 1
    plane_select[1] = 0
    plane_select[2] = 1
    plane_select[3] = 0

def vga_select_bitplanes_13():
    global plane_select
    plane_select[0] = 0
    plane_select[1] = 1
    plane_select[2] = 0
    plane_select[3] = 1

def vga_write32(offset, val):
    global plane_select
    global fb

    for i in range(4):
        if plane_select[i] > 0:
            for j in range(4):
                b = (val >> (j * 8)) & 0xff

                fb_offs = i + (offset + j) * 4

                fb[fb_offs] = b

def do_drop():
    global cop_drop
    global line_compare
    global do_pal
    global fadepal

    cop_drop += 1

    print(f"cop_drop: {cop_drop}")

    if cop_drop <= 64:
        line_compare = dtau[cop_drop]
    
    else:
        bShouldFade = 0
        if cop_drop >= 256:
            pass
        elif cop_drop >= 128:
            bShouldFade = 1
        elif cop_drop > 96:
            pass
        else:
            bShouldFade = 1

        if bShouldFade > 0:
            do_pal = 1

            if cop_drop == 65:
                line_compare = 400
                initpparas()
            else:
                line_compare = 60

                pcop_fadepal = 0
                pfadepal = 0
                for i in range(768//16):
                    for ccc in range(16):
                        ax = pals[cop_fadepal][(pcop_fadepal//2) + ccc]
                        while ax < 0:
                            ax += 0x10000
                        al = ax & 0xff
                        ah = ax >> 8

                        oldval = fadepal[pfadepal + ccc + 768]
                        fadepal[pfadepal + ccc + 768] = (fadepal[pfadepal + ccc + 768] + al) & 0xff
                        newval = fadepal[pfadepal + ccc + 768]
                        carry = 0
                        if newval < oldval:
                            carry = 1
                        
                        fadepal[pfadepal + ccc] = (fadepal[pfadepal + ccc] + ah + carry) & 0xff
                    
                    pcop_fadepal += 32
                    pfadepal += 16
        else:
            cop_drop = 0

def initpparas():
    global l1
    global l2
    global l3
    global l4

    global k1
    global k2
    global k3
    global k4

    global il1
    global il2
    global il3
    global il4

    global ik1
    global ik2
    global ik3
    global ik4

    l1 = il1
    l2 = il2
    l3 = il3
    l4 = il4

    k1 = ik1
    k2 = ik2
    k3 = ik3
    k4 = ik4



def vga_show_framebuffer():

    global palette
    global x16_pal
    global cop_fadepal

    for event in pygame.event.get():
        pass

    copper1()
    copper2()

    if cop_drop == 0:
        if len(x16_pal[cop_fadepal]) < 256:
            x16_pal[cop_fadepal] = []
            for i in range(256):
                r = palette[i*3] & 0x3f
                g = palette[i*3+1] & 0x3f
                b = palette[i*3+2] & 0x3f

                r <<= 2
                g <<= 2
                b <<= 2

                r = (r * 15 + 135) >> 8
                g = (g * 15 + 135) >> 8
                b = (b * 15 + 135) >> 8

                rgb = (r << 8) | (g << 4) | b
                x16_pal[cop_fadepal].append(rgb)




    screen.fill(((palette[0] << 2) & 0xff, (palette[1] << 2) & 0xff, (palette[2] << 2) & 0xff))

    nFirstLineIndex = (line_compare + 1)

    ptr = 0

    for y in range(nFirstLineIndex, SCREEN_HEIGHT):
        for x in range(FRAME_BUFFER_WIDTH):
            idx = fb[ptr + x] * 3

            r = palette[idx] & 0x3f
            g = palette[idx+1] & 0x3f
            b = palette[idx+2] & 0x3f
            idx += 3

            r <<= 2
            g <<= 2
            b <<= 2

            r = (r * 15 + 135) >> 8
            g = (g * 15 + 135) >> 8
            b = (b * 15 + 135) >> 8

            r |= r*16
            g |= g*16
            b |= b*16

            color = [r,g,b]

            screen.set_at((x, y), color)
    
        ptr += FRAME_BUFFER_WIDTH
    """
    chcount = 0
    for y in range(SCREEN_HEIGHT):
        for x in range(SCREEN_WIDTH):
            off = (y*FRAME_BUFFER_WIDTH) + x
            if fb[off] != prevfb[off]:
                print(".", end="")
                chcount+=1
                prevfb[off] = fb[off]
    print("")
    print(f"chcount: {chcount}")
    """

    pygame.display.flip()
    clock.tick(60)

def moveplz():
    global k1
    global k2
    global k3
    global k4
    global l1
    global l2
    global l3
    global l4

    k1 += -3
    k1 &= 4095
    k2 += -2
    k2 &= 4095
    k3 += 1
    k3 &= 4095
    k4 += 2
    k4 &= 4095

    l1 += -1
    l1 &= 4095
    l2 += -2
    l2 &= 4095
    l3 += 2
    l3 &= 4095
    l4 += 3
    l4 &= 4095


def pompota():
    return

def copper1():
    return

def copper2():
    global frame_count
    global do_pal

    frame_count += 1

    if do_pal != 0:
        do_pal = 0
        vga_upload_palette()

    pompota()
    moveplz()

    if cop_drop != 0:
        do_drop()


def do_tables():
    global psini
    global ptau

    for a in range(1024*16):
        if a<1024*8:
            psini[a+LSINI4_OFFSET]=(math.trunc(math.sin(a*math.pi*2/4096)*55+
                math.sin(a*math.pi*2/4096*5)*8+
                math.sin(a*math.pi*2/4096*15)*2+64)*8) & 0xffff
            psini[a+LSINI16_OFFSET]=(math.trunc(math.sin(a*math.pi*2/4096)*55+
                math.sin(a*math.pi*2/4096*4)*5+
                math.sin(a*math.pi*2/4096*17)*3+64)*16) & 0xffff

        psini[a]=math.trunc(math.sin(a*math.pi*2/4096)*55+
            math.sin(a*math.pi*2/4096*6)*5+
            math.sin(a*math.pi*2*21)*4+
            64) & 0xff

    ptau[0] = 0
    for a in range(1,129):
        ptau[a]=math.trunc(math.cos(a*math.pi*2/128+math.pi)*31+32) & 0xff
    print(ptau)

def init_plz():
    global pals
    global cop_start
    global line_compare

    do_tables()
    
    cop_start=96*(682-400)
    line_compare = 60

    # RGB
    pidx=3
    for a in range(1,64):
        pals[0][pidx+0] = ptau[a]
        pals[0][pidx+1] = ptau[0]
        pals[0][pidx+2] = ptau[0]
        pidx += 3

    for a in range(64):
        pals[0][pidx+0] = ptau[63-a]
        pals[0][pidx+1] = ptau[0]
        pals[0][pidx+2] = ptau[0]
        pidx += 3
    
    for a in range(64):
        pals[0][pidx+0] = ptau[0]
        pals[0][pidx+1] = ptau[0]
        pals[0][pidx+2] = ptau[a]
        pidx += 3
    
    for a in range(64):
        pals[0][pidx+0] = ptau[a]
        pals[0][pidx+1] = ptau[0]
        pals[0][pidx+2] = ptau[63-a]
        pidx += 3

    # RB-black
    pidx=3
    for a in range(1,64):
        pals[1][pidx+0] = ptau[a]
        pals[1][pidx+1] = ptau[0]
        pals[1][pidx+2] = ptau[0]
        pidx += 3

    for a in range(64):
        pals[1][pidx+0] = ptau[63-a]
        pals[1][pidx+1] = ptau[0]
        pals[1][pidx+2] = ptau[a]
        pidx += 3
    
    for a in range(64):
        pals[1][pidx+0] = ptau[0]
        pals[1][pidx+1] = ptau[a]
        pals[1][pidx+2] = ptau[63-a]
        pidx += 3
    
    for a in range(64):
        pals[1][pidx+0] = ptau[a]
        pals[1][pidx+1] = ptau[63]
        pals[1][pidx+2] = ptau[a]
        pidx += 3

    # RB-white
    pidx=3
    for a in range(1,64):
        pals[3][pidx+0] = ptau[a]
        pals[3][pidx+1] = ptau[0]
        pals[3][pidx+2] = ptau[0]
        pidx += 3

    for a in range(64):
        pals[3][pidx+0] = ptau[63]
        pals[3][pidx+1] = ptau[a]
        pals[3][pidx+2] = ptau[a]
        pidx += 3
    
    for a in range(64):
        pals[3][pidx+0] = ptau[63-a]
        pals[3][pidx+1] = ptau[63-a]
        pals[3][pidx+2] = ptau[63]
        pidx += 3
    
    for a in range(64):
        pals[3][pidx+0] = ptau[0]
        pals[3][pidx+1] = ptau[0]
        pals[3][pidx+2] = ptau[63]
        pidx += 3

    # white
    pidx=3
    for a in range(1,64):
        pals[2][pidx+0] = ptau[0]//2
        pals[2][pidx+1] = ptau[0]//2
        pals[2][pidx+2] = ptau[0]//2
        pidx += 3

    for a in range(64):
        pals[2][pidx+0] = ptau[a]//2
        pals[2][pidx+1] = ptau[a]//2
        pals[2][pidx+2] = ptau[a]//2
        pidx += 3
    
    for a in range(64):
        pals[2][pidx+0] = ptau[63-a]//2
        pals[2][pidx+1] = ptau[63-a]//2
        pals[2][pidx+2] = ptau[63-a]//2
        pidx += 3
    
    for a in range(64):
        pals[2][pidx+0] = ptau[0]//2
        pals[2][pidx+1] = ptau[0]//2
        pals[2][pidx+2] = ptau[0]//2
        pidx += 3

    # white II
    pidx=3
    for a in range(1,75):
        pals[4][pidx+0] = ptau[math.trunc(63-a*64/75)]
        pals[4][pidx+1] = ptau[math.trunc(63-a*64/75)]
        pals[4][pidx+2] = ptau[math.trunc(63-a*64/75)]
        pidx += 3

    for a in range(106):
        pals[4][pidx+0] = 0
        pals[4][pidx+1] = 0
        pals[4][pidx+2] = 0
        pidx += 3
    
    for a in range(75):
        pals[4][pidx+0] = math.trunc(ptau[math.trunc(a*64/75)]*8/10)
        pals[4][pidx+1] = math.trunc(ptau[math.trunc(a*64/75)]*9/10)
        pals[4][pidx+2] = ptau[math.trunc(a*64/75)]
        pidx += 3

    for pidx in range(768):
        pals[0][pidx] = ((pals[0][pidx])-63)*2
        pals[1][pidx] *= 8
        pals[2][pidx] *= 8
        pals[3][pidx] *= 8
        pals[4][pidx] *= 8
        pals[5][pidx] *= 8


def plz():
    global curpal
    global timetable
    global ttptr

    global l1
    global l2
    global l3
    global l4

    global k1
    global k2
    global k3
    global k4

    global il1
    global il2
    global il3
    global il4

    global ik1
    global ik2
    global ik3
    global ik4

    global frame_count
    global cop_drop
    global do_pal
    global cop_start
    global cop_scrl
    global cop_plz

    global inittable

    global fadepal

    global line_compare
    global cop_fadepal

    tim=0
    count=0
    init_plz()
    cop_drop=128
    cop_fadepal = curpal
    curpal+=1

    disframe=0

    while True:
        tim += frame_count
        frame_count = 0
        count += 1
        disframe += 1
        print(f"{disframe:d}/{timetable[ttptr]:d}", end="\r")
        if disframe > timetable[ttptr]: # time exceeded
            print("\nnextplasma")
            for i in range(768):
                fadepal[i] = 0
            cop_drop = 1
            cop_fadepal = curpal
            curpal += 1
            ttptr += 1
            il1 = inittable[ttptr][0]
            il2 = inittable[ttptr][1]
            il3 = inittable[ttptr][2]
            il4 = inittable[ttptr][3]
            ik1 = inittable[ttptr][4]
            ik2 = inittable[ttptr][5]
            ik3 = inittable[ttptr][6]
            ik4 = inittable[ttptr][7]

        if curpal == 4 and cop_drop > 64:
            break

        vga_select_bitplanes_02()

        setplzparas(k1,k2,k3,k4)
        for y in range(0,MAXY,2):
            plzline(y,y*6+YADD*6)
        setplzparas(l1,l2,l3,l4)
        for y in range(1,MAXY,2):
            plzline(y,y*6+YADD*6)

        vga_select_bitplanes_13()

        setplzparas(k1,k2,k3,k4)
        for y in range(1,MAXY,2):
            plzline(y,y*6+YADD*6)
        setplzparas(l1,l2,l3,l4)
        for y in range(0,MAXY,2):
            plzline(y,y*6+YADD*6)

        vga_show_framebuffer()
    cop_drop=0
    frame_count=0
    line_compare = 500
    cop_plz=0

pygame.init()
clock=pygame.time.Clock()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Plasma")

init_copper()
plz()

palnum = 0

for i in x16_pal:
    print(f"pal{palnum}:")
    print("\t.word ", end="")
    print(",".join([f"${n:04x}" for n in i]))
#print(x16_pal)
