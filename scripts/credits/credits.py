#!/usr/bin/python3

import math

co = []

for i in range(40):
    s = math.sin(i*(math.pi/2)/40)
    co.append(s)

print("v_ease_on:\n\t.byte ", end="")

for i in co:
    v = 200 - (i*82)
    print(f"${round(v):02x},", end="")

print("")

print("v_ease_off:\n\t.byte ", end="")

for i in reversed(co):
    v = 200 - (i*82)
    print(f"${round(v):02x},", end="")

print("")

print("h_ease_on_l:\n\t.byte ", end="")

for i in co:
    h = 320 - (i*224)
    print(f"${int(h) & 0xff:02x},", end="")

print("")

print("h_ease_on_h:\n\t.byte ", end="")

for i in co:
    h = 320 - (i*224)
    print(f"${int(h/256) & 0xff:02x},", end="")

print("")

print("h_ease_off_l:\n\t.byte ", end="")

for i in reversed(co):
    h = -128 + (i*224)
    h += 65536
    print(f"${int(h) & 0xff:02x},", end="")

print("")

print("h_ease_off_h:\n\t.byte ", end="")

for i in reversed(co):
    h = -128 + (i*224)
    h += 65536
    print(f"${int(h/256) & 0xff:02x},", end="")

print("")
