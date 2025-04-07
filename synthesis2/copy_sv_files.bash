#!/bin/bash

cp ../code/Integration/cpu/*.sv* .
cp ../code/Integration/MMU/*.sv* .
cp -r ../code/Integration/MMU/BRAMS .
cp ../code/Integration/MMU/mif_files/dmg-acid-test.mif .
rm BRAMS/*.qip
cp ../code/*.sv . 
cp -r ../code/Integration/*.sv* .

if grep -q "RegisterPkg.svh" "gameboy.sv"; then
	sed -i 's/.*RegisterPkg\.svh*/\`include "RegisterPkg"\.svh/g' "gameboy.sv"
	echo "replaced line in gameboy.sv at the top regarding RegisterPkg.svh"
   else
	echo "line replacement of RegisterPkg.svh failed"
fi


if grep -q "init_file" "BRAMS/ROM_BANK.v"; then
	sed -i 's/\(init_file =\).*$/\1"dmg-acid-test.mif"/' "BRAMS/ROM_BANK.v"
	#sed -i 's/.$//' "gameboy.sv"  #dumb compensation for deleting the extra " character
	echo "replaced mif file to be dmg acid mif" 
   else
	echo "replacement of rom bank mif file failed"
fi




cp ../code/Integration/dmg/ppu.sv .
cp ../code/Integration/dmg/vga.sv .
cp ../code/Integration/dmg/vga_test/Seven*.sv .

