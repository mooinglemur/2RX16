== This is a bit of an explanation of the JellyPic/BOUNCE part of the 2R demo ==

- In essence this part uses a FX tilemap to draw stretched/shrunk rows onto a (8bpp) bitmap layer
- It loads these 2 files for the tile information directly into VRAM:
  - bounce-tilemap.dat
  - bounce-tiledata.dat
- The original image of 320x400 has been shrunk to 320x200 to make it fit into VRAM
- There is no room for double buffering in VRAM when using this method and doing 8bpp (with 4bpp it is possible, but shearing is minimal, so this is probably better)
- The animation is done in three 'steps':
  - frame data:
    - 'frame_y_bottom_start' and 'frame_curve_indexes' contain the frame specific data
      - each frame has an image start starts at the bottom (we draw from bottom to top) at a certain y-coordinate
      - each frame has a curve-index into the curves-data (one curve has one image-height with a certain curvature)
  - curves:
    - Curve data is loaded as curves.dat
    - For each curve there is 256 bytes. 
      - Each byte contains an width-index of the row. This is padded with standard width-indexes until the 254th byte
      - The last two bytes are the height of the image.
  - row widths(x_pos+x_incr), 
    - 'x_pos_per_width', 'x_inc_low_per_width' and 'x_inc_high_per_width' contain the data per row-width
    - For each row width there is a starting x_pos (in the FX texture)
    - For each row width there is a x-increment value (2 bytes) for the affine to increment each pixel
- The drawing of a frame stops when the VRAM address wraps around to 'negative', so it automatically stops before the curve has ended
- At the bottom there could be a black border, which is drawn by clearing the nr of lines (based on frame_y_bottom_start)

- TODO for integration:
    - We disable the layer at the beginning, we probably shouldnt
    - We should more acurately wait for 2 frames (30 fps)
    - There is very tight memory map: 
        - The CURVES.DAT file is 16.640 bytes and is currently loaded into Fixed RAM (at $5900)
        - The code also contains some hardcoded data (palette, row-width data and frame data)
        - This toghether might not easily fit when integrated (although I think with some massaging it might)
        - If needed maybe use RAM BANKs instead for the CURVES data (I hoping it wouldnt be needed)
    - It now uses a screen height of 200 (like any other part of the demo I believe) but is also shrinks the width. Should be ok right?
       - The placement of the image in the middle of the screen is eyeballed.
    - The amount of frames has been truncated (compared to the original): when the animation stops, we stop the frames
    - Only every other frame is kept. When ran in 30fps this results in a playback rate *close* to the original, but not quite the same. I think this is ok, but might not be for syncing
    