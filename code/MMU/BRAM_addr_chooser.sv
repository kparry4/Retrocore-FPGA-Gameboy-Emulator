`default_nettype none


module MM_addr_contention_handler  (input logic clock,
                                    input logic reset,
                                    input logic doing_dma,
                                    
                                    input logic cpu_wren,
                                    input logic [15:0] cpu_addr,

                                    input logic [1:0] ppu_mode,
                                    input logic [15:0] ppu_addr1,
                                    input logic [15:0] ppu_addr2,
                                    
                                    input logic [15:0] dma_src_addr,
                                    input logic [15:0] dma_dest_addr,
                                    
                                    output logic oam_wren,
                                    output logic vram_wren,
                                    
                                    
                                    output logic [15:0] rom0_addr,
                                    output logic [15:0] vram_addr1,
                                    output logic [15:0] vram_addr2,
                                    output logic [15:0] exram_addr,
                                    output logic [15:0] wram_addr,
                                    output logic [15:0] oam_addr1,
                                    output logic [15:0] oam_addr2,
                                    output logic [15:0] hram_addr
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
                oam_wren = 1'b1;

                //NO writes to vram ever occur in DMA
                vram_wren = 1'b0;

                //allow dma to SOURCE from any part of memory
                rom0_addr = dma_src_addr - ROM_0_START;  
                vram_addr1 = dma_src_addr - VRAM_0_START;
                vram_addr2 = 16'hDEAD;                
                exram_addr = dma_src_addr - EXRAM_START;        
                wram_addr = dma_src_addr - WRAM_START; 

                //alow dma to COPY to oam table 
                oam_addr1 = dma_dest_addr - OAM_START; //allow dma 
                oam_addr2 = 16'hDEAD;

                hram_addr = dma_src_addr - HRAM_START;                 

            end else begin

                //if NO dma, address is offset from CPU's input addr
                rom0_addr = cpu_addr - ROM_0_START;  
                exram_addr = cpu_addr - EXRAM_START;        
                wram_addr = cpu_addr - WRAM_START; 
                hram_addr = cpu_addr - HRAM_START; 
                
                if(ppu_mode == 0 || ppu_mode = 1 || ppu_mode == 2) begin
                    //HBLANK or VBLANK or OAM_SEARCH

                    if(ppu_mode == 2) begin
                        //OAM search is occurring, block CPU writes
                        oam_addr1 = ppu_addr1 - OAM_START;
                        oam_addr2 = ppu_addr2 - OAM_START;
                        oam_wren = 1'b0;
                        
                    end else begin
                        oam_addr1 = cpu_addr - OAM_START;
                        oam_addr2 = 16'hDEAD;   
                        //cpu can write 
                        oam_wren = cpu_wren && within_range(cpu_addr, OAM_START, OAM_END);                    
                    end

                    vram_addr1 = cpu_addr - VRAM_START;
                    vram_addr2 = 16'hDEAD;  
                    //cpu can write
                    vram_wren = cpu_wren && within_range(cpu_addr, VRAM_START, VRAM_END);  

                end else begin
                        //in DRAWING MODE
                        vram_addr1 = ppu_addr1 - VRAM_START;
                        vram_addr2 = ppu_addr2 - VRAM_START;                                

                        oam_addr1 = ppu_addr1 - OAM_START;
                        oam_addr2 = ppu_addr2 - OAM_START;  

                        //no writes from anybody allowed
                        oam_wren = 1'b0;
                        vram_wren = 1'b0;                              
                end
            end
        end

endmodule: MM_addr_contention_handler