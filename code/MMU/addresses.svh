`ifndef ADDRESSES_H
    `define ADDRESSES_H
    //MEMORY RANGES
    `define ROM_0_START 16'h0000
    `define ROM_0_END   16'h3FFF

    `define ROM_B_START 16'h4000
    `define ROM_B_END   16'h7FFF

    `define VRAM_START  16'h8000
    `define VRAM_END    16'h9FFF

    `define EXRAM_START 16'hA000
    `define EXRAM_END   16'hBFFF

    `define WRAM_START 16'hC000
    `define WRAM_END   16'hCFFF

    `define OAM_START  16'hFE00
    `define OAM_END    16'hFE9F

    `define HRAM_START 16'hFF80
    `define HRAM_END   16'hFFFE


    //HARDWARE REGISTER ADDRESSES

    `define IO_START 16'hFF00
    `define IO_END   16'hFF7F

    `define JOYPAD 16'hFF00

    `define SERIAL_TRANS_D 16'hFF01 //dont think we need this
    `define SERIAL_TRANS_C 16'hFF02 //dont think we need this

    `define DIV 16'hFF04
    `define TIMA 16'hFF05
    `define TMA  16'hFF05
    `define TAC 16'hFF07

    `define INTERRUPT_FLAG 16'hFF0F

    `define NR10 16'hFF10
    `define NR11 16'hFF11
    `define NR12 16'hFF12
    `define NR13 16'hFF13
    `define NR14 16'hFF14

    `define NR21 16'hFF16
    `define NR22 16'hFF17
    `define NR23 16'hFF18
    `define NR24 16'hFF19

    `define NR30 16'hFF1A
    `define NR31 16'hFF1B
    `define NR32 16'hFF1C
    `define NR33 16'hFF1D
    `define NR34 16'hFF1E

    `define NR41 16'hFF20
    `define NR42 16'hFF21
    `define NR43 16'hFF22
    `define NR44 16'hFF23

    `define NR50 16'hFF24
    `define NR51 16'hFF25
    `define NR52 16'hFF26

    `define WAV_RAM_START 16'hFF30
    `define WAV_RAM_END   16'hFF3F

    `define WAV_RAM_0 16'hFF30
    `define WAV_RAM_1 16'hFF31
    `define WAV_RAM_2 16'hFF32
    `define WAV_RAM_3 16'hFF33
    `define WAV_RAM_4 16'hFF34
    `define WAV_RAM_5 16'hFF35
    `define WAV_RAM_6 16'hFF36
    `define WAV_RAM_7 16'hFF37
    `define WAV_RAM_8 16'hFF38
    `define WAV_RAM_9 16'hFF39
    `define WAV_RAM_A 16'hFF3A
    `define WAV_RAM_B 16'hFF3B
    `define WAV_RAM_C 16'hFF3C
    `define WAV_RAM_D 16'hFF3D
    `define WAV_RAM_E 16'hFF3E
    `define WAV_RAM_F 16'hFF3F


    `define LCDC 16'hFF40
    `define STAT 16'hFF41
    `define SCY  16'hFF42
    `define SCX  16'hFF43
    `define LY   16'hFF44
    `define LYC  16'hFF45

    `define DMA  16'hFF46

    `define BGP  16'hFF47
    `define OBP0 16'hFF48
    `define OBP1 16'hFF49
    `define WY   16'hFF4A
    `define WX   16'hFF4B

    `define INTERRUPT_EN  16'hFFFF

    //note that below are Color gameboy registers
    `define KEY1     16'hFF4D
    `define VBK      16'hFF4F

    `define BOOT_ROM 16'hFF50

    `define HDMA1   16'hFF51
    `define HDMA2   16'hFF52
    `define HDMA3   16'hFF53
    `define HDMA4   16'hFF54
    `define HDMA5   16'hFF55

    `define INF_PORT 16'hFF56
    `define BGPI     16'hFF68
    `define BGPD     16'hFF69
    `define OBPI     16'hFF6A
    `define OBPD     16'hFF6B
    `define OPRI     16'hFF6C
    `define SVBK     16'hFF70
    `define PCM12    16'hFF76
    `define PCM34    16'hFF77

`endif