#!/usr/bin/env python3


### NOTE: this script no longer correctly visualizes the X16 plasma
### but it is useful for creating the LUTS

from PIL import Image
import pygame
import math
import time
import random
import os

MINY = 60
MAXY = 140

SCREEN_WIDTH = 320
SCREEN_HEIGHT = 200
FRAME_BUFFER_WIDTH = SCREEN_WIDTH
FRAME_BUFFER_HEIGHT = SCREEN_HEIGHT

fb = [0] * (FRAME_BUFFER_WIDTH * FRAME_BUFFER_HEIGHT)

sint1 = [0] * 256
sint2 = [0] * 256
sint3 = [0] * 256
sint4 = [0] * 256
yscale = [0] * 256

ptau = [0] * 64
dtau = [0] * 64

pals=[[0] * 768 for i in range(6)]

selfmod = [[0] * 256 for i in range(5)]

palette = [63] * 768

curpal=0

l1=500
l2=1000
l3=1500
l4=2000

k1=2100
k2=1780
k3=23000
k4=1550

il1=l1
il2=l2
il3=l3
il4=l4

ik1=k1
ik2=k2
ik3=k3
ik4=k4

ml = 0

advance = 0

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def byteprint(lst, label):
    print(f"{label}:")

    for chunk in chunks(lst, 16):
        print("\t.byte " + ','.join(['${:02X}'.format(int(x)) for x in chunk]))

def wordprint(lst, label):
    print(f"{label}:")

    for chunk in chunks(lst, 8):
        print("\t.word " + ','.join(['${:04X}'.format(int(x)) for x in chunk]))


def setplzparas(c1, c2, c3, c4):
    global selfmod

    for ccc in range(256):
        lc1 = (c1 >> 8) + ccc
        selfmod[1][ccc] = lc1 & 0xff

        lc2 = (c2 >> 8) + ((ccc) + 128)
        selfmod[2][ccc] = lc2 & 0xff

        lc3 = (c3 >> 8) + ((ccc) + 128)
        selfmod[3][ccc] = lc3 & 0xff

        lc4 = (c4 >> 8) + ccc
        selfmod[4][ccc] = lc4 & 0xff

def plzline(y, parity):

    for i in range(160):
            y2 = (y >> 1)
            i2 = (i - y2) & 0xff
            offs = (y + selfmod[1][i2]) & 0xff
            bx = sint1[offs]

            offs = (bx + selfmod[2][i2]) & 0xff
            ax = sint2[offs]

            offs = (y2 + selfmod[3][i2]) & 0xff
            bx = sint3[offs]

            offs = (bx + selfmod[4][i2]) & 0xff
            ax = (((ax + sint4[offs]) >> 1) + ml) & 0xff

            plot_point(i*2+parity, y, ax)

def upload_palette(pal):
    global palette
    for i in range(768):
        palette[i] = pal[i]

def plot_point(x, y, val):
    global fb
    fb[(y * FRAME_BUFFER_WIDTH) + x] = val

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

def show_fb():
    global palette

    screen.fill((palette[0], palette[1], palette[2]))

    for y in range(FRAME_BUFFER_HEIGHT):
        for x in range(FRAME_BUFFER_WIDTH):
            idx = fb[(y*FRAME_BUFFER_WIDTH) + x] * 3

            r = palette[idx]
            g = palette[idx+1]
            b = palette[idx+2]

            color = [r,g,b]

            screen.set_at((x, y), color)
    


def moveplz():
    global k1
    global k2
    global k3
    global k4
    global l1
    global l2
    global l3
    global l4
    global ml

    k1 += 120
    k1 &= 0xffff
    k2 += 60
    k2 &= 0xffff
    k3 += 100
    k3 &= 0xffff
    k4 += 80
    k4 &= 0xffff

    l1 += -60
    l1 &= 0xffff
    l2 += -140
    l2 &= 0xffff
    l3 += -120
    l3 &= 0xffff
    l4 += -170
    l4 &= 0xffff

    ml += 1
    ml &= 0xff


def do_tables():
    global sint1
    global sint2
    global sint3
    global sint4
    global ptau

    for a in range(256):
        sint1[a]=math.trunc(math.sin(a*math.pi*2/128)*55+
            math.sin(a*math.pi*2/128*6)*5+
            math.sin(a*math.pi*2*21)*4+
            64) & 0xff
        sint2[a]=math.trunc(math.sin(a*math.pi*2/128)*55+
            math.sin(a*math.pi*2/128*3)*4+
            math.sin(a*math.pi*2*19)*4) & 0xff
        sint3[a]=math.trunc(math.sin(a*math.pi*2/128)*55+
            math.sin(a*math.pi*2/128*4)*2+
            math.sin(a*math.pi*2/128*17)*3+64) & 0xff
        sint4[a]=math.trunc(math.sin(a*math.pi*2/128)*55+
            math.sin(a*math.pi*2/128*2)+
            math.sin(a*math.pi*2/128*4)*4+128) & 0xff
        yscale[a]=a//6

    byteprint(sint1,"sint1")
    byteprint(sint2,"sint2")
    byteprint(sint3,"sint3")
    byteprint(sint4,"sint4")


    for a in range(64):
        ptau[a]=math.trunc(math.cos(a*math.pi*2/64+math.pi)*31+32) & 0xff
    ptau[0] = 0
    byteprint(ptau,"ptau")
    for a in range(64):
        dtau[a]=a*a/4*43/256+21
    byteprint(dtau,"dtau")

def init_plz():
    global pals
    global ptau

    do_tables()
    
    # Reds
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
        pals[3][pidx+0] = ptau[31]
        pals[3][pidx+1] = ptau[a]
        pals[3][pidx+2] = ptau[a]
        pidx += 3
    
    for a in range(64):
        pals[3][pidx+0] = ptau[63-a]
        pals[3][pidx+1] = ptau[63-a]
        pals[3][pidx+2] = ptau[31]
        pidx += 3
    
    for a in range(64):
        pals[3][pidx+0] = ptau[0]
        pals[3][pidx+1] = ptau[0]
        pals[3][pidx+2] = ptau[31]
        pidx += 3

    # white
    pidx=3
    for a in range(1,64):
        pals[2][pidx+0] = ptau[0]//2+4
        pals[2][pidx+1] = ptau[0]//2+4
        pals[2][pidx+2] = ptau[0]//2+4
        pidx += 3

    for a in range(64):
        pals[2][pidx+0] = ptau[a]//2+16
        pals[2][pidx+1] = ptau[a]//2+16
        pals[2][pidx+2] = ptau[a]//2+16
        pidx += 3
    
    for a in range(64):
        pals[2][pidx+0] = ptau[63-a]//2+16
        pals[2][pidx+1] = ptau[63-a]//2+16
        pals[2][pidx+2] = ptau[63-a]//2+16
        pidx += 3
    
    for a in range(64):
        pals[2][pidx+0] = ptau[0]//2+4
        pals[2][pidx+1] = ptau[0]//2+4
        pals[2][pidx+2] = ptau[0]//2+4
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
        for i in range(5):
            pals[i][pidx] = (pals[i][pidx] * 61 + 128) >> 8
            pals[i][pidx] |= pals[i][pidx] * 16

    for i in range(5):
        entries = []
        for j in range(256):
            pidx = j * 3
            r = (pals[i][pidx + 0] >> 4) & 0xf
            g = (pals[i][pidx + 1] >> 4) & 0xf
            b = (pals[i][pidx + 2] >> 4) & 0xf

            rgb = (r << 8) | (g << 4) | b
            entries.append(rgb)
        wordprint(entries,f"pal{i:d}")
            

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
    global advance

    tim=0
    count=0
    init_plz()
    curpal = 0

    upload_palette(pals[curpal])

    disframe=0

    while True:
        count += 1
        disframe += 1
        if advance:
            advance = 0
            print("\nnextplasma")
            curpal += 1
            if curpal == 5:
                curpal = 0
            upload_palette(pals[curpal])

        setplzparas(k1,k2,k3,k4)
        for y in range(MINY,MAXY,2):
            plzline(y,0)
        for y in range(MINY+1,MAXY,2):
            plzline(y,1)
        setplzparas(l1,l2,l3,l4)
        for y in range(MINY,MAXY,2):
            plzline(y,1)
        for y in range(MINY+1,MAXY,2):
            plzline(y,0)

        for event in pygame.event.get():
            if event.type == pygame.KEYDOWN:
                advance = 1
            


        show_fb()
        moveplz()

        pygame.display.flip()
        clock.tick(60)
pygame.init()
clock=pygame.time.Clock()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Plasma")

plz()

