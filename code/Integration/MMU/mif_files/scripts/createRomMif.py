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
        with open(args.binpath, 'rb') as binary_file, open(mif_file_path, 'w') as mif_file:
            #mif_file.write("DEPTH=16384;\n") # 32kb = 32768 bytes, 32768/2 = 16384 rows
            #mif_file.write("WIDTH=16;\n")  # Data width is 16 bits (2 bytes)
            #mif_file.write("ADDRESS_RADIX=HEX;\n")
            #mif_file.write("DATA_RADIX=HEX;\n")
            #mif_file.write("\nCONTENT BEGIN\n\n")
            mif_file.write(header_template)

            address = 0
            while True:
                byte0 = binary_file.read(1)
                byte1 = binary_file.read(1)
                if not byte0:
                    break
                if not byte1:
                    byte1 = b'\x00'
                data = (byte1[0] << 8) | byte0[0]
                mif_file.write(f"{address:04X} : {data:04x};\n")
                address+=1

            while(args.oam and address<80):
                mif_file.write(f"{address:04X} : {0:04x};\n")
                address+=1
            while(args.vram and address<8192):
                mif_file.write(f"{address:04X} : {0:04x};\n")
                address+=1

            mif_file.write("END; \n")
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
