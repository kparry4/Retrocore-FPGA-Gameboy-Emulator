//`default_nettype none
`include "RegisterPkg.svh"
`include "addresses.svh"
`include "select.svh"


module MM_addr_contention_handler  (input logic clock,
                                    input logic reset,
                                    input logic doing_dma,
                                    input logic dma_oam_wren,

                                    input logic cpu_wren,
                                    input logic [15:0] cpu_addr_read,
                                    input logic [15:0] cpu_addr_write,

                                    input logic [1:0] ppu_mode,
                                    input logic [7:0] LCDC_R,
                                    input logic [15:0] ppu_addr1,
                                    input logic [15:0] ppu_addr2,

                                    input logic [15:0] dma_src_addr,
                                    input logic [15:0] dma_dest_addr,

                                    output logic oam_wren,
                                    output logic vram_wren,

                                    output logic [13:0] rom0_addr,
                                    output logic [11:0] vram_addr_rw,
                                    output logic [11:0] vram_addr_r,
                                    output logic [11:0] exram_addr_r,
                                    output logic [11:0] wram_addr_r,
                                    output logic [6:0] oam_addr_rw,
                                    output logic [6:0] oam_addr_r,
                                    output logic [3:0] hram_addr_r
);


    /***RECALL
        PPU Mode 0 = HBLANK
                        cpu vram access ok, dma access happens(?)
                        ppu blocked

        PPU Mode 1 = VBLANK
                        cpu vram access ok, dma access happens(?)
                        ppu blocked
        PPU Mode 2 = OAM search:
                        cpu vram access ok, cpu oam blocked.
                        ppu access ok
        PPU Mode 3 = DRAWING:
                        no cpu/dma access allowed.
                        ppu access ok
    ***/


    always_comb begin
        if(doing_dma) begin

                //DMA does OAM write (using 1 port for simplicity)
                oam_wren = dma_oam_wren;

                //NO writes to vram ever occur in DMA
                vram_wren = 1'b0;

                //allow dma to SOURCE from any part of memory
                rom0_addr  =   convert_to_BRAM_addr(dma_src_addr, `ROM_0_START);
                vram_addr_rw = convert_to_BRAM_addr(dma_src_addr, `VRAM_START);
                vram_addr_r = 16'hXXXX;
                exram_addr_r = convert_to_BRAM_addr(dma_src_addr, `EXRAM_START);
                wram_addr_r  = convert_to_BRAM_addr(dma_src_addr, `WRAM_START);

                //alow dma to COPY to oam table
                oam_addr_rw = convert_to_BRAM_addr(dma_dest_addr, `OAM_START);; //allow dma
                oam_addr_r = 16'hXXXX;

                hram_addr_r = convert_to_BRAM_addr(cpu_addr_read, `HRAM_START); //hram is LUTS, not bram

            end else begin

                //if NO dma, address is offset from CPU's input addr
                rom0_addr    = convert_to_BRAM_addr(cpu_addr_read,  `ROM_0_START);
                exram_addr_r = convert_to_BRAM_addr(cpu_addr_read, `EXRAM_START);
                wram_addr_r  = convert_to_BRAM_addr(cpu_addr_read, `WRAM_START);
                hram_addr_r  = convert_to_BRAM_addr(cpu_addr_read, `HRAM_START);  //hram is LUTS, not bram


                if(ppu_mode == 0 || ppu_mode == 1 || ppu_mode == 2) begin
                    //HBLANK or VBLANK or OAM_SEARCH

                    if(ppu_mode == 2 && LCDC_R[7]) begin
                        //OAM search is occurring AND LCDC IS ON, block CPU writes
                        oam_addr_rw = convert_to_BRAM_addr(ppu_addr1, `OAM_START);
                        oam_addr_r =  convert_to_BRAM_addr(ppu_addr2, `OAM_START);
                        oam_wren  = 1'b0;

                    end else begin
                        oam_addr_rw = convert_to_BRAM_addr(cpu_addr_write, `OAM_START);
                        oam_addr_r =  convert_to_BRAM_addr(cpu_addr_read,  `OAM_START);
                        //cpu can write
                        oam_wren  = cpu_wren && within_range(cpu_addr_write, `OAM_START, `OAM_END);
                    end

                    vram_addr_rw = convert_to_BRAM_addr(cpu_addr_write, `VRAM_START);
                    vram_addr_r =  convert_to_BRAM_addr(cpu_addr_read,  `VRAM_START);
                    //cpu can write
                    vram_wren  = cpu_wren && within_range(cpu_addr_write, `VRAM_START, `VRAM_END);

                end else begin
                        //in DRAWING MODE
                        vram_addr_rw = convert_to_BRAM_addr(ppu_addr1, `VRAM_START);
                        vram_addr_r = convert_to_BRAM_addr(ppu_addr2, `VRAM_START);

                        oam_addr_rw  = convert_to_BRAM_addr(ppu_addr1, `OAM_START);
                        oam_addr_r  = convert_to_BRAM_addr(ppu_addr2, `OAM_START);

                        //no writes from anybody allowed
                        oam_wren  = 1'b0;
                        vram_wren = 1'b0;
                end
            end
        end

endmodule: MM_addr_contention_handler
