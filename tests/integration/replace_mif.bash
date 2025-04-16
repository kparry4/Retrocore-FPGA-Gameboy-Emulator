#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Please give path to binary file name $0 <new_init_file_path> you beautiful individual"
    exit 1
fi

ROM_PATH="../../synthesis2/BRAMS/ROM_BANK.v"
NEW_FILE_NAME="$1"
NEW_PATH="../../code/Integration/MMU/mif_files/$NEW_FILE_NAME.mif"

# Use sed to replace the init_file path
sed -i "s#\(altsyncram_component\.init_file = \).*#\1\"$NEW_PATH\",#" "$ROM_PATH"

echo "Updated altsyncram_component.init_file in rom bank at path $ROM_PATH to be $NEW_PATH"
