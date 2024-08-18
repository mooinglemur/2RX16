#!/usr/bin/env python3

def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def list_to_dotbyte_strings(lst):
    result = []
    for chunk in chunks(lst, 8):
        result.append("\t.byte " + ','.join(['${:02x}'.format(int(x)) for x in chunk]) + "\n")
    return result

print("addrl_per_row_8bit:")
print("".join(list_to_dotbyte_strings([int((x * 320)) & 0xff for x in range(256)])))
print("addrm_per_row_8bit:")
print("".join(list_to_dotbyte_strings([int((x * 320) >> 8) & 0xff for x in range(256)])))
print("addrh_per_row_8bit:")
print("".join(list_to_dotbyte_strings([int((x * 320) >> 16) & 0xff for x in range(256)])))

print("addrl_per_hrow_8bit:")
print("".join(list_to_dotbyte_strings([int((x * 320 + 160)) & 0xff for x in range(256)])))
print("addrm_per_hrow_8bit:")
print("".join(list_to_dotbyte_strings([int((x * 320 + 160) >> 8) & 0xff for x in range(256)])))
print("addrh_per_hrow_8bit:")
print("".join(list_to_dotbyte_strings([int((x * 320 + 160) >> 16) & 0xff for x in range(256)])))
