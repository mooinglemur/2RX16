This is a bit of an explanation for the 3D-city part of the demo:

- The program 3D-CITY-SCENE.PRG loads two files: U2E-POLYGONS.DAT and POLYFILL-8BIT-TBLS-AND-CODE.DAT
- To build the U2E-POLYGONS.DAT file the script pygame-3d-scene.py needs to be run
  - inside this script the variable SCENE needs to be set to 'U2E'
  - this script uses output from Blender and from another script (extract_data_from_orig_files.py)
    - for more details on that, see comments in pygame-3d-scene.py (and also consult me)
  - this script does a whole lot of 3d work (culling, clipping, projection, lighting, transformation, sorting, merging of polygons etc.)
  - this script essentially outputs a stream of 2D polygons
  - this script produces the U2E-POLYGONS.DAT file, which contains the stream of polygon-draw-records
    - this data-file can be split into chunks of 8kB if need be (a polygon-draw-record never crosses the border of two 8kB blocks)
- The file POLYFILL-8BIT-TBLS-AND-CODE.DAT contains all jump tables and code needed to draw 8bpp polygons superfast using the FX features
  - It can be produced by (in folder polygon_filler_jump_table_gen):
    - compiling polygon_filler_table_gen_8bit.s into POLYGON-FILLER-TABLE-GEN-8BIT.PRG
    - running that PRG in the X16 emulator. 
    - Then creating a memory dump and renaming it into POLYFILL-8BIT-DUMP.BIN
    - runnning the script extract_jump_tables_and_code_8bit.py
    - this produces the file POLYFILL-8BIT-TBLS-AND-CODE.DAT which has to be moved to the same directory of 3D-BATTLE-SCENE.PRG

- The asm file 3d-city-scene.s can be compiled into 3D-CITY-SCENE.PRG
  - it loads the file U2E-POLYGONS.DAT and (for now) has a hardcoded nr of frames it expects
  - at startup (almost) the entire VRAM is filled with a background color which is the same color as the first wall seen in the scene
  - There is no clearing of the buffers between frames: it is made sure that that is not needed (all pixels should be overwritten each time)
  - it has two 8bpp frame buffers (to display 320x200), but since this in non-trivial to do on the X16/VERA those are arranged in a special way:
    - the first buffer starts at $00000 and is a normal buffer (note: VSTART is at 20)
    - the second buffer:
       - technically starts (inside of the first buffer!) at 320*200-512 = $F800
       - but when showing this buffer it has a VSTART of 18
       - The real data (that is shown) starts at $F800 + 640 = $FA80. So two rows of 'garbage' pixels are normally shown above the real data
       - these two 'garbage' row are *covered* by 5 64x64 black sprites. 
          - Note: there are 128 bytes available between the two buffers which are used to fill the first 2 rows of 64 pixels (with a non-transparant black)
          - The sprites are vertically flipped and cover only the 2 'garbage' rows
  - the file POLYFILL-8BIT-TBLS-AND-CODE.DAT is loaded into fixed RAM at $8400-$9E00
  - for each polygon its has to draw it uses the jump-table resided at $9000 (called FILL_LINE_START_JUMP)
  - it (tries) to draw a frame at a rate of 20fps by using a somewhat crude VSYNC-counter and 3-frame-waiter
    - it is likely this has to be replaced by something else or at least integrated into the demo
  - the stream of polygon data contains markers indicating there are no more polygons in the current 8kB of data and then switches to the next RAM bank.
  - it only overwrites all 256 colors. But if colors are needed, at the end there might be some room.

- TODO in the integrated version:
  - The loaders of the files need to be replaced.
  - There is no fade in or fade out. Does there need to be?
    - in the original there seems to be a switch between a vertical standing image (which has faded to white) and the start of this scene. Somehow we need to replicate this.
  - Since the data is larger than 512kB banked RAM some form of 'streaming' is needed to load data in on-the-fly
    - there might be periods in the scene where you should not do any loading, but other periods where this is ok. We can figure this out.
  - at startup all layers are turned off, this is probably undesired.
    - the (sequence of) prep-calls (loaders, palette, clearing, setup of layers etc) might have to adjusted



