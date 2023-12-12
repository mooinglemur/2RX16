This is a bit of an explanation for the FOREST part of the demo:

- To build the .DAT files needed the script pygame-forest.py needs to be run:
  - change dir to the root dir of the repo
  - python ./scripts/forest/pygame-forest.py
    - This requires files (in assets/forest): HILLBACK.CLX and O2.SCI
    - This outputs files (in scripts/forest): FOREST.DAT, SCROLLTEXT.DAT and SCROLLCOPY.DAT
    - This output (in console): palette bytes (copy paste in .s file)
    - The python scripts also simulates the demo-part running
- About the poc .PRG file:
  - To build (change dir to the scripts/forest/): cl65 -t cx16 -o POC-FOREST.PRG poc_forest.s
  - To run: x16emu.exe -prg POC-FOREST.PRG -run
  - More info about this poc file:
    - Its a standalone file, no dependencies
    - It loads the required .DAT files using the LOAD command (this probably needs to change in the integrated version)
        - FOREST.DAT is loaded into VRAM: containing the background image (VLOAD-ing is slow this way, probably has to be done in a different way)
        - SCROLLTEXT.DAT is loaded into RAM Banks: 1-3 (containing the pixels of the text to scroll)
        - SCROLLCOPY.DAT is loaded into RAM Banks: 4-16 (containing the generated code to the text pixels into VRAM)
    - At startup code is generated (at SHIFT_PIXEL_CODE_ADDRESS) that 'shifts' scroll text buffer one pixel to the left
    - The scroll text buffer is initially cleared and then (partially) filled
- TODO in the integrated version:
  - There is no fade in or fade out. 
    - The original version had two fade ins: 
      - one for the leaves (in our case the first 128 colors)
      - one for the rest of the colors (in our case the last 128 colors)
  - The initial starting scroll offset (and final offset) is a wild guess. Needs to be tweaked.
  - The initial starting time should be properly set.
  - No vsync, its running too fast:
    - each iteration of the scroll need to be timed in such a way that it scrolls at a rate of 23.33 fps
  - There is no double buffer. But it is also not really noticiable. If desired, please discuss first (its a bit more involved than it looks at first sight)
  - The memory map and registers probably have to be moved around.
    
      