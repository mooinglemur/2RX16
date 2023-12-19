This is a bit of an explanation for the LENS/ROTAZOOM parts of the demo:
- Both the LENS and the ROTAZOOM part have a separate Python script and PoC asm file
- The asm-files should probably be merged together, but maybe they can stay apart (if thats easier)

- LENS part:
  - To build the needed .DAT file:
    - change dir to the root dir of the repo
    - python ./scripts/lens/lens.py
      - This requires files (in assets/lens): LENS.png and LENSPIC.png (note: these are converted from the original LENS.LBM and LENSPIC.LBM files)
      - This outputs files (in scripts/lens): 
        - DOWNLOAD*.DAT (2 files, loaded into 2 RAM Banks): generated code for 'downloading' from VRAM to Fixed RAM (for 1 quarter of the LENS, in two steps)
        - UPLOAD*-*.DAT (3*4=12 files, loaded into 12 RAM Banks): generated code for 'uploading' from Fixed RAM to VRAM with blue-ness added (4 unique quarters, each in 3 steps)
        - BACKGROUND.DAT: background image (the 'monster')
        - LENS-POS.DAT: the position of the LENS for each frame
        - It generates code that has RAM addresses hardcoded in it. If the base-address needs to be changed then BITMAP_QUADRANT_BUFFER needs to change in the .py and .s file
      - This outputs (in console): palette bytes for the *LENS* part (copy paste in .s file)
        - This palette consists of 64 colors for the background and 192 colors (3*64) for the same color with different levels of blue-ness
      - It uses the same formula/routines for positioning of the lens as the original
      - It uses (almost) the same formula for the lens-distorion-effect as the original
      - The python scripts also simulates the demo-part running (and has some extra DEBUG options, like showing the palette and 
  - PoC asm:
    - To build (change dir to the scripts/lens/): cl65 -t cx16 -o LENS.PRG lens.s
    - To run: x16emu.exe -prg LENS.PRG -run
    - The background is a bitmap layer showing 320x200 on screen
      - The upload-code reads data from RAM to VRAM with a max y-offset of 11 pixels. Therefore there is a 12 pixel-row black border on top and bottom of the 320x200 background bitmap
      - The background image is therefore loaded into VRAM at $01000 (BITMAP_VRAM_ADDRESS)
      - Effectively 282*256 bytes are cleared (from $00000) which means the entire bitmap (including the top and bottom borders) runs from $00000 to $11A00
    - The lens is realized by showing 4 sprites that are vertically and horizontally flipped (but each have their own buffer)
      - Each frame a part of the bitmap layer is downloaded from VRAM to Fixed RAM and the uploaded (distorted and blue-ish) into the sprite buffers
      - The sprites are double-buffered: 4 sprites always visible, the other 4 not visible
      - SPRITES_VRAM_ADDRESS contains the start-address of all eight (64x64px) sprites. (now: $12000)
    - The aim is to run at 30fps: it takes 20-25ms per frame (I believe, not measured properly)
      - Right now, there is a 'dumb_wait_for_vsync' routine that should probably be replaced by a proper one. This waits for the next vsync.

- ROTAZOOM part
  - To build the needed .DAT file:
    - change dir to the root dir of the repo
    - python ./scripts/lens/rotazoom.py
      - This requires one input file (in assets/lens): LENS.png
      - This outputs files (in scripts/lens): 
        - ROTAZOOM-TILEMAP.DAT (containing the FX tilemap)
        - ROTAZOOM-TILEDATA.DAT (containing the pixels in the tiles, right now 149 unique tiles)
        - ROTAZOOM-POS-ROTATE.DAT (contains the position / rotate data needed for the FX affine helper. For each frame: 10 bytes)
      - This outputs (in console): palette bytes for the *ROTAZOOM* part (copy paste in .s file)
        - This palette *shares* the same first 64 colors of the LENS part, but also contains *new* colors (created when converting from 256x256 to 128x128 pixels)
      - It uses the same formula/routines for rotation, zooming and positioning of the background as the original
        - There is a conversion between the original formula and the way the FX affine helper works: this is probably not perfect and might need tweaking.

  - PoC asm:
    - To build (change dir to the scripts/lens/): cl65 -t cx16 -o ROTAZOOM.PRG rotazoom.s
    - To run: x16emu.exe -prg ROTAZOOM.PRG -run
    - This essentially does a very straightforward affine-transformation (rotate, translate and scale) using the FX affine helper
      - All settings for the FX affine helper are essentially provided by the ROTAZOOM-POS-ROTATE.DAT file (10 bytes per frame)
      - It uses a 32x32 tile map, *but* in reality it is actually four 16x16 tilemaps stitched together (so there are four 128x128px images making a 256x256px total map)
      - The map is repeated, no tranparency
    - Currently its not double buffered, we seem to stay ahead of the beam (need to test this properly)
    - There is a 'dumb_wait_for_vsync' routine that should probably be replaced by a proper one. This waits for the next vsync.


- TODO in the integrated version:
  - LENS
    - Requires special fade-in (called 'fir'-fade in the original source)
    - Also requires a from-black fade-in of the LENS-colors (colors 64-255): this is subtle, but I believe the lens itself fades-in
    - At the end of the LENS-part there is a (quick) fade-out into WHITE (a 'flash' if you will)
      - *Before* this fade-out happens the LENS is (for some time) not visible anymore so the following can be done:
        - load/copy the colors of the ROTAZOOM into the palette (note that the first 64 colors are the same, so this doesnt create problems)
        - load/copy the tilemap and tiledata (for ROTAZOOM) into high VRAM (now for rotazoom: MAPDATA_VRAM_ADDRESS=$13000 and TILEDATA_VRAM_ADDRESS=$17000). The sprite buffers can be overwritten by now.
        - load the ROTAZOOM-POS-ROTATE.DAT into Banked RAM
  - ROTAZOOM
    - while all colors are WHITE (due to the fade-out at the end of the LENS-part) in the first frame the following can be done:
      - change the screen scale to 160x100
      - the main loop ('keep_rotating') can be started
        - this will cause the 160x100 to be filled immediatly
    - Now do a (quick) fade-in from WHITE
    
- TODO later / nice to haves:
  - We probably want to interpolate from 70fps to 60fps (or 30fps for the LENS) to let the frames line-up with the audio better
  - Right now the ROTAZOOM uses a source image of 128x128 pixels (instead of the original 256x256 pixels) due to the 256-unique tile limit in VERA FX
    - It might be possibe to increase this to effectively a 256x128 or 128x256 source image.
    - This would be nice, but probably nobody cares ;)
  - We could add a double buffer to the ROTAZOOM-er (which only takes 16kB, so that would fit nicely)
  - The LENS-distorion-effect is not perfect, we could improve it
    
    