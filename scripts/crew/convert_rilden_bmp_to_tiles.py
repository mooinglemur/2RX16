#!/usr/bin/env python3

from PIL import Image

TILEW = 8
TILEH = 8

def bmp2tiles(img):
    tiles = []
    imgw, imgh = img.size
    for trow in range(imgh//TILEH):
        for tcol in range(imgw//TILEW):
            tile = []
            for crow in range(TILEH):
                for ccol in range(TILEW):
                    xx = tcol*TILEW + ccol
                    yy = trow*TILEH + crow
                    px = img.getpixel([xx,yy])
                    tile.append(px)
            tiles.append(tile)
        for p in range(5, 9):
            if 2**p >= imgw//TILEW:
                overage = (2**p) - (imgw//TILEW)
                break
        if overage:
            for i in range(overage):
                tiles.append([0] * 64)
    return tiles


def getpal(img):
    palarray = []
    pal = img.getpalette('RGB')

    for idx in range(0, len(pal), 3):
        r = (pal[idx] * 15 + 135) >> 8
        g = (pal[idx+1] * 15 + 135) >> 8
        b = (pal[idx+2] * 15 + 135) >> 8

        gb = g << 4 | b
        palarray.append(gb)
        palarray.append(r)
    return palarray

with Image.open("crew_scaled_8bpc_top-8x8-8p16c-s.bmp") as img:
    tiles0 = bmp2tiles(img)
    pal0 = getpal(img)

with Image.open("crew_scaled_8bpc_bottom-8x8-8p16c-s.bmp") as img:
    tiles1 = bmp2tiles(img)
    pal1 = getpal(img)

pal = pal0[0:256] + pal1[0:256]

# populate blank tile in first slot
outtiles0 = [[0] * 64]
outtilemap0 = []

for tile in tiles0:
    # normalize the values
    t = [x & 0xf for x in tile]
    # check to see if we already have this in the output tile set
    if t in outtiles0:
        tileidx = outtiles0.index(t)
    else:
        tileidx = len(outtiles0)
        outtiles0.append(t)
    palnum = tile[0]//16
    outtilemap0.append(tileidx)
    outtilemap0.append(palnum)

outtiles1 = [[0] * 64]
outtilemap1 = []

for tile in tiles1:
    # normalize the values
    t = [x & 0xf for x in tile]
    # check to see if we already have this in the output tile set
    if t in outtiles1:
        tileidx = outtiles1.index(t)
    else:
        tileidx = len(outtiles1)
        outtiles1.append(t)
    palnum = (tile[0]//16)+8
    outtilemap1.append(tileidx)
    outtilemap1.append(palnum)

with open("CREWTILES0.DAT", mode="wb") as file:
    for tile in outtiles0:
        for m in range(0, len(tile), 2):
            val = (tile[m] << 4) | tile[m+1]
            file.write(val.to_bytes())

with open("CREWMAP0.DAT", mode="wb") as file:
    for m in range(0, len(outtilemap0), 2):
        t = outtilemap0[m]
        i = outtilemap0[m+1]

        idx = t & 0xff
        attr = ((t >> 8) & 0x03) | i << 4

        file.write(bytes([idx, attr]))

with open("CREWTILES1.DAT", mode="wb") as file:
    for tile in outtiles1:
        for m in range(0, len(tile), 2):
            val = (tile[m] << 4) | tile[m+1]
            file.write(val.to_bytes())

with open("CREWMAP1.DAT", mode="wb") as file:
    for m in range(0, len(outtilemap1), 2):
        t = outtilemap1[m]
        i = outtilemap1[m+1]

        idx = t & 0xff
        attr = ((t >> 8) & 0x03) | i << 4

        file.write(bytes([idx, attr]))

with open("CREW.PAL", mode="wb") as file:
    file.write(bytes(pal))
