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

    parser.add_argument("--rom16_16_path", 
                        default="mif_files/16kB_word16bit_init.mif",
                        help="16 kB ROM Bank (13 bit addr x 16 bits) .mif output")
    
    parser.add_argument("--rom16_32_path", 
                        default="mif_files/16kB_word32bit_init.mif",
                        help="16 kB ROM Bank (12 bit addr x 32 bits) .mif output")
    
    parser.add_argument("--ram8_16_path", 
                        default="mif_files/8kB_word16bit_init.mif",
                        help="8kB RAM Bank (12 bit addr x 16 bits) .mif output")
    
    parser.add_argument("--oam_path", 
                        default="mif_files/oam_init.mif",
                        help="OAM (8 bit addr x 4 bytes (32 bits)) .mif output")
    
    parser.add_argument("--hram_path", 
                        default="mif_files/hram_init.mif",
                        help="HRAM (7 bit addr x 16 bits) .mif output")
    args = parser.parse_args()

    header_template = (
        "DEPTH = {depth};\n"
        "WIDTH = {width};\n"
        "ADDRESS_RADIX = HEX;\n"
        "DATA_RADIX = HEX;\n\n"
        "CONTENT BEGIN\n\n")

    footer_template = "\nEND;"

    rom16_16_dim = 1 << 13;
    rom16_32_dim = 1 << 12;

    ram8_16_dim = 1 << 12;
    oam_dim = 1 << 8;
    hram_dim = 1 << 7;

    max_16_bit_val = 65535
    not_max_32bit_val = 2147483645

    
    rom16_16 = [r for r in range(rom16_16_dim)]
    rom16_32 = [r+max_16_bit_val for r in range(rom16_32_dim)]

    ram8_16 = [r+3 for r in range(ram8_16_dim)]
    oam = [not_max_32bit_val-r for r in range(oam_dim)]
    hram = [r+5 for r in range(hram_dim)]



    # mat_a = [[0 for c in range(matrix_dim)]
    #          for r in range(matrix_dim)]
    # mat_b = [0 for r in range(matrix_dim)]
    # mat_c = [0 for r in range(matrix_dim)]

    c_sum = 0
    ab_sum = 0

    # for i in range(matrix_dim):
    #     for j in range(matrix_dim):
    #         ab_sum += mat_a[i][j] * mat_b[j]

    #     c_sum += mat_c[i]

    # mma_product = ab_sum + c_sum

    # with open(args.rom_bank_16, "w") as fout:
    #     addr_counter = count(0)
    #     data_lines = [
    #         "{:04x} : {:02x};".format(next(addr_counter), e)
    #         for r in mat_a for e in r]

    #     a_depth = matrix_dim * matrix_dim
    #     fout.write(header_template.format(depth=a_depth, width=8) +
    #                "\n".join(data_lines)
    #                + footer_template)



##########################################################
#               16 kB ROM BANKS
##########################################################
    with open(args.rom16_16_path, "w") as fout:
        addr_counter = count(0)
        data_lines = [
            "{:04x} : {:04x};".format(next(addr_counter), e)
            for e in rom16_16]
        fout.write(
            header_template.format(depth=rom16_16_dim, width=16) +
            "\n".join(data_lines) +
            footer_template)
        
    with open(args.rom16_32_path, "w") as fout:
        addr_counter = count(0)
        data_lines = [
            "{:04x} : {:08x};".format(next(addr_counter), e)
            for e in rom16_32]
        fout.write(
            header_template.format(depth=rom16_32_dim, width=32) +
            "\n".join(data_lines) +
            footer_template)

##########################################################
#               8 kB RAM BANKS
##########################################################
    with open(args.ram8_16_path, "w") as fout:
        addr_counter = count(0)
        data_lines = [
            "{:04x} : {:04x};".format(next(addr_counter), e)
            for e in ram8_16]
        fout.write(
            header_template.format(depth=ram8_16_dim, width=16) +
            "\n".join(data_lines) +
            footer_template)
##########################################################
#               OAM
##########################################################
    with open(args.oam_path, "w") as fout:
        addr_counter = count(0)
        data_lines = [
            "{:04x} : {:08x};".format(next(addr_counter), e)
            for e in oam]
        fout.write(
            header_template.format(depth=oam_dim, width=32) +
            "\n".join(data_lines) +
            footer_template)

##########################################################
#               HRAM
##########################################################
    with open(args.hram_path, "w") as fout:
        addr_counter = count(0)
        data_lines = [
            "{:04x} : {:04x};".format(next(addr_counter), e)
            for e in hram]
        fout.write(
            header_template.format(depth=hram_dim, width=16) +
            "\n".join(data_lines) +
            footer_template)
                
        



    # with open(args.mat_c, "w") as fout:
    #     addr_counter = count(0)
    #     data_lines = [
    #         "{:04x} : {:04x};".format(next(addr_counter), e)
    #         for e in mat_c]

    #     c_depth = matrix_dim
    #     fout.write(
    #         header_template.format(depth=c_depth, width=16) +
    #         "\n".join(data_lines) +
    #         footer_template)

    for arg_name, arg_value in vars(args).items():
        print(f"created {arg_name}, first entry is {arg_value[0]}")

    # print("Ab sum: 0x{:08x} (trunc {:06x})".format(ab_sum, ab_sum % (2 ** 24)))
    # print("C sum: 0x{:08x} (trunc {:06x})".format(c_sum, c_sum % (2 ** 24)))
    # print("MMA product: 0x{:08x} (trunc {:06x})".format(mma_product, mma_product % (2 ** 24)))

if __name__ == "__main__":
    main()
