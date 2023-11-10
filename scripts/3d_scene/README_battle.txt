This is a bit of an explanation for the 3D-battle part of the demo:

- The program 3D-BATTLE-SCENE.PRG loads two files: U2A-POLYGONS.DAT and POLYFILL-8BIT-TBLS-AND-CODE.DAT
- To build the U2A-POLYGONS.DAT file the script pygame-3d-scene.py needs to be run
  - inside this script the variable SCENE needs to be set to 'U2A'
  - this script uses output from Blender and from another script (extract_data_from_orig_files.py)
    - for more details on that, see comments in pygame-3d-scene.py (and also consult me)
  - this script does a whole lot of 3d work (culling, clipping, projection, lighting, transformation, sorting, merging of polygons etc.)
  - this script essentially outputs a stream of 2D polygons
  - this script produces the U2A-POLYGONS.DAT file, which contains the stream of polygon-draw-records
    - this data-file can be split into chunks of 8kB if need be (a polygon-draw-record never crosses the border of two 8kB blocks)
- The file POLYFILL-8BIT-TBLS-AND-CODE.DAT contains all jump tables and code needed to draw 8bpp polygons superfast using the FX features
  - It can be produced by (in folder polygon_filler_jump_table_gen):
    - compiling polygon_filler_table_gen_8bit.s into POLYGON-FILLER-TABLE-GEN-8BIT.PRG
    - running that PRG in the X16 emulator. 
    - Then creating a memory dump and renaming it into POLYFILL-8BIT-DUMP.BIN
    - runnning the script extract_jump_tables_and_code_8bit.py
    - this produces the file POLYFILL-8BIT-TBLS-AND-CODE.DAT which has to be moved to the same directory of 3D-BATTLE-SCENE.PRG
- The asm file 3d-battle-scene.s can be compiled into 3D-BATTLE-SCENE.PRG
  - it loads the file U2A-POLYGONS.DAT and (for now) has a hardcoded nr of frames it expects
  - it has two 8bpp frame buffers ($00000 and $C0000 for now) and currently clears/draws in an area of 320x120
  - the file POLYFILL-8BIT-TBLS-AND-CODE.DAT is loaded into fixed RAM at $3000-$4A00
  - for each polygon its has to draw it uses the jump-table resided at $3C00 (called FILL_LINE_START_JUMP)
  - it (tries) to draw a frame at a rate of 20fps by using a somewhat crude VSYNC-counter and 3-frame-waiter
    - it is likely this has to be replaced by something else or at least integrated into the demo
  - the stream of polygon data contains markers indicating there are no more polygons in the current 8kB of data and then switches to the next RAM bank.
  - it only overwrites the first 240 colors. Those colors are outputted in the console by the pygame-3d-scene.py script, but might not be easy to catch ;)

- TODO in the integrated version:
  - The loaders of the files need to be replaced.
  - There is no fade in or fade out. Does there need to be?
  - It draws 120 rows on the screen. A line-interrupt is needed to make sure rows below that are not shown.
    - its probably a good idea to put the line-interrup at say 115, to make sure no garbage pixels are ever shown
  - at startup all layers are turned off, this is probably undesired.
    - the (sequence of) prep-calls (loaders, palette, clearing, setup of layers etc) might have to adjusted

