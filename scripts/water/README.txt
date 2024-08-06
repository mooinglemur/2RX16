This is a bit of an explanation for the WATER part of the demo:

- To build the .DAT files needed the script pygame-water.py needs to be run:
  - change dir to the root dir of the repo
  - python ./scripts/water/pygame-water.py
    - This requires files (in assets/water): BKG.CLX and MIEKKA.SCI (also: WAT1.DAT, WAT2.DAT and WAT3.DAT)
    - This outputs files (in scripts/water): WATER.DAT, SCROLLSWORD.DAT and SCROLLCOPY.DAT
    - This output (in console): 
      - palette bytes (copy paste in .s file)
      - sprite bytes (copy paste in .s file) -> careful: only replace the parts that are generated
    - The python scripts also simulates the demo-part running (sort of, not very well)
- About the poc .PRG file:
  - To build (change dir to the scripts/water/): cl65 -t cx16 -o POC-WATER.PRG poc_water.s
  - To run: x16emu.exe -prg POC-WATER.PRG -run
  - More info about this poc file:
    - Its a standalone file, no dependencies
    - It loads the required .DAT files using the LOAD command (this probably needs to change in the integrated version)
        - WATER.DAT is loaded into VRAM: containing the background image (VLOAD-ing is slow this way, probably has to be done in a different way)
        - SCROLLSWORD.DAT is loaded into RAM Banks: 1-4 (containing the pixels of the sword to scroll, including some black padding)
        - SCROLLCOPY.DAT is loaded into RAM Banks: 5-21 (containing the generated code to the sword pixels into VRAM)
    - At startup code is generated (at SHIFT_PIXEL_CODE_ADDRESS) that 'shifts' scroll sword buffer one pixel to the left
    - The scroll sword buffer is initially cleared and then (partially) filled
    - What is different from FOREST is:
      - the pixels are written in 8-bit mode (not 4-bit mode) to the bitmap in VRAM. 
      - This means the background image is overwritten. If nothing was done about this, large parts of the screeb would become black
      - To prevent this 10 sprites are filled with parts of the background image
      - These are filled at startup and then shown
- TODO in the integrated version:
  - The loaders of the files need to be replaced.
  - There is no fade in or fade out. 
  - The layer is shown while the background image is being loaded. Probably not a good idea. 
  - The initial starting time should be properly set.
  - No vsync, its running too fast:
    - each iteration of the scroll need to be timed in such a way that it scrolls at a rate of 23.33 fps
  - There is no double buffer. But it is also not really noticiable. If desired, please discuss first (its a bit more involved than it looks at first sight)
  - The memory map and registers probably have to be moved around.
    - Careful: when changing SCROLLER_BUFFER_ADDRESS you have to change that too in the Python-script (and run it again). The generated code contains absolute RAM addresses
    - Also: when changing the VRAM addresses (not advisable): the sprite data (outputted in the console) need to be copy-pasted. But some calculation in the Python script needs to be adjusted as well.
    
      