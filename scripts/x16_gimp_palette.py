#!/usr/bin/env python3

print("GIMP Palette")
print("Name: VERA 4bpc")
print("Columns: 0")
print("#")

for r in range(16):
    for g in range(16):
        for b in range(16):
            print(f"{r*17:3d} {g*17:3d} {b*17:3d}\tUntitled")
