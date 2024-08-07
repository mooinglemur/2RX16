import os

polyfull_8bit_dump_file = open('POLYFILL-8BIT-DUMP.BIN', 'rb')
polyfull_8bit_dump_binary = polyfull_8bit_dump_file.read()
polyfull_8bit_dump_file.close()

# We are extracting from $3000 to $4A00
from_pos = 0x8400
to_pos = 0x9E00
tables_and_code_bin = polyfull_8bit_dump_binary[from_pos:to_pos]

print(len(tables_and_code_bin))
print(tables_and_code_bin)

with open("POLYFILL-8BIT-TBLS-AND-CODE.DAT", "wb") as tables_and_code_file:
    tables_and_code_file.write(tables_and_code_bin)
