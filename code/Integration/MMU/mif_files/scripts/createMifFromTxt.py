#! /usr/bin/env python3
''' Create the init mif files (of all zeros)
'''
from argparse import ArgumentParser
from itertools import count
from random import randint

def main():
    ''' Do all the work here. '''
    parser = ArgumentParser(description="Generate init files for banks")

    #for now, everything is 16 bit word size...
    #ram 8kB = 12 bit addr x 16 bits
    #rom 16kB =
        # for 16 bit words, 13 bit addr x 16 bits
        # for 32 bit words, 12 bit addr x 32 bits

    #oam = 8 bit addr x 4 bytes (32 bits)
    #hram is 7 bit addr x 16 bits

    parser.add_argument("--name",
                        default="mif file name",
                        help="32 kB ROM Bank (13 bit addr x 16 bits) .mif output")
    parser.add_argument("--oam",
                        action="store_true")
    parser.add_argument("--vram",
                        action="store_true")
    parser.add_argument("--binpath",
                        default="bin file name",
                        help="bin file input")

    args = parser.parse_args()

    if(args.oam):
        print("expecting oam")
        header_template = (
            "WIDTH = 16;\n" #data width is 16 bits
            "DEPTH = 1280;\n" #80 entries, 16 bits each --> 1280 bits
            "ADDRESS_RADIX = HEX;\n"
            "DATA_RADIX = HEX;\n\n"
            "CONTENT BEGIN\n\n")
    elif(args.vram):
        print("expecting vram")
        header_template = (
            "WIDTH = 16;\n" #data width is 16 bits
            "DEPTH = 8192;\n" #80 entries, 16 bits each --> 1280 bits
            "ADDRESS_RADIX = HEX;\n"
            "DATA_RADIX = HEX;\n\n"
            "CONTENT BEGIN\n\n")

    else:
        print("expecting rom")
        header_template = (
            "WIDTH = 16;\n" #data width is 16 bits
            "DEPTH = 16384;\n" #32 kb = 32768 bytes => 16384 rows
            "ADDRESS_RADIX = HEX;\n"
            "DATA_RADIX = HEX;\n\n"
            "CONTENT BEGIN\n\n")

    footer_template = "\nEND;"

    mif_file_path = f"{args.name}.mif"

    try:
        with open(args.binpath, 'r') as binary_file, open(mif_file_path, 'w') as mif_file:
            mif_file.write(header_template)

            address = 0
            data = binary_file.read().strip()
            hex_values = data.split()
            print("type of object is", type(hex_values[0]))
            print("length of bytes in file is", len(hex_values))
            for i in range(0,10):
              print("at value", i, hex_values[i])
            #hex_values = re.findall(r'[0-9A-Fa-f]{2}', data)  # List of hex strings
            
            # Check if hex_values is properly populated
            if not hex_values:
                print("No valid hex values found in the file.")
                return

            
            
            while(address*2 < len(hex_values)):
              hval0 = int(hex_values[address*2],16)
              hval1 = int(hex_values[address*2+1],16)
              #print("type of h0, h1", type(hval0), type(hval1))
              hval = (hval1 << 8) | hval0          
              mif_file.write(f"{address:04X} : {hval:04x};\n")
              address+=1
   
            mif_file.write("END; \n")
            print(f"wrote up to {address:04X}", f"aka {address}")
    except FileNotFoundError:
        print(f"Error: File not found: {args.binpath}")
    except Exception as e:
        print(f"An error occurred: {e}")


    print(f"Created mif file {mif_file_path}!")
    # for arg_name, arg_value in vars(args).items():
    #     print(f"created {arg_name}, first entry is {arg_value[0]}")

    # print("Ab sum: 0x{:08x} (trunc {:06x})".format(ab_sum, ab_sum % (2 ** 24)))
    # print("C sum: 0x{:08x} (trunc {:06x})".format(c_sum, c_sum % (2 ** 24)))
    # print("MMA product: 0x{:08x} (trunc {:06x})".format(mma_product, mma_product % (2 ** 24)))

if __name__ == "__main__":
    main()
