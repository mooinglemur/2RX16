#!/usr/bin/env python3

import os
import struct

input_dir = "../ROOT"
output_file = "../REALITY.X16"
macro_include = "../src/blob_loadfile.inc"

excluded_extensions = ['.PRG', '.X16']

files = sorted([f for f in os.listdir(input_dir) if os.path.isfile(os.path.join(input_dir, f)) and not any(f.upper().endswith(ext) for ext in excluded_extensions)])

with open(output_file, 'wb') as output:
    offset_lengths = []

    # Iterate through each file in the directory
    for file_name in files:
        file_path = os.path.join(input_dir, file_name)

        # Record the offset for the current file
        offset = output.tell()

        # Read the content of the current file and write it to the output file
        with open(file_path, 'rb') as input_file:
            content = input_file.read()
            output.write(content)

        # Record the length of the current file
        length = len(content)
        offset_lengths.append((file_name, offset, length))

with open(macro_include, 'w') as macro_file:

    macro_file.write(".macro LOADFILE name, bank, addr, vbank\n")
    macro_file.write("\tjsr blobopen\n")

    el = ""
    for entry in offset_lengths:
        macro_file.write(f".{el}if .xmatch(name,\"{entry[0]}\")\n")
        macro_file.write(f"\tlda #${entry[1] & 0xff:02x}\n")
        macro_file.write(f"\tsta blobseekfn+2\n")
        macro_file.write(f"\tlda #${(entry[1] >> 8) & 0xff:02x}\n")
        macro_file.write(f"\tsta blobseekfn+3\n")
        macro_file.write(f"\tlda #${(entry[1] >> 16) & 0xff:02x}\n")
        macro_file.write(f"\tsta blobseekfn+4\n")

        macro_file.write(f"\tlda #${entry[2] & 0xff:02x}\n")
        macro_file.write(f"\tsta blob_to_read\n")
        macro_file.write(f"\tlda #${(entry[2] >> 8) & 0xff:02x}\n")
        macro_file.write(f"\tsta blob_to_read+1\n")
        macro_file.write(f"\tlda #${(entry[2] >> 16) & 0xff:02x}\n")
        macro_file.write(f"\tsta blob_to_read+2\n")

        el = "else"

    macro_file.write(f".else\n")
    macro_file.write(f".error \"LOADFILE macro expansion failed\"\n")
    macro_file.write(f".endif\n")

    macro_file.write("\tjsr blobseek\n")

    macro_file.write("\tlda #bank\n")
    macro_file.write("\tsta X16::Reg::RAMBank\n")
    macro_file.write("\tldx #<addr\n")
    macro_file.write("\tldy #>addr\n")
    macro_file.write(".ifnblank vbank\n")
    macro_file.write("\tlda #(vbank + 2)\n")
    macro_file.write(".else\n")
    macro_file.write("\tlda #0\n")
    macro_file.write(".endif\n")
    macro_file.write("\tjsr blobload\n")
    macro_file.write(".endmacro\n")


