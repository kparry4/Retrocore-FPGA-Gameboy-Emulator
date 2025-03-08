`default_nettype none




module MM_handler(input logic clock,
                  input logic reset,
                  input logic [15:0] cpu_addr,
                  input logic [15:0] ppu_addr1,
                  input logic [15:0] ppu_addr2, 
                  input logic  [1:0] ppu_mode,
                  input logic  [7:0] DMA_R,
                  input logic        start_dma,
                  output logic [7:0] cpu_out_data,
                  output logic [7:0] ppu_out_data1,
                  output logic [7:0] ppu_out_data2,
                  output logic       cpu_data_valid,
                  output logic       ppu_data_valid);

    //---ADDR DECLARATIONS------                  
    //if any of these overflow then I WILL kill myself
    //16KB x 2 = 32kB combined rom, 16 bit width --> 16384 entries, so 14 bits addr
    logic [13:0] rom0_addr;
    //8KB inside dual vram, 16 bit width --> 4096 entries, so 12 bits addr
    logic [12:0] vram_addr1;
    logic [12:0] vram_addr2;    
    //8KB inside dual vram, 16 bit width --> 4096 entries, so 12 bits addr
    logic [12:0] exram_addr;        
    //8KB inside ex vram, 16 bit width --> 4096 entries, so 12 bits addr
    logic [12:0] exram_addr; 
    //4KB x 2 = 8KB inside work vram, 16 bit width --> 4096 entries, so 12 bits addr
    logic [12:0] wram_addr;      

    //160 kB inside work vram, 16 bit width --> 80 entries (makes sense, given 40 sprites)
    logic [7:0] oam_addr1;  
    logic [7:0] oam_addr2;  
    logic [3:0] hram_addr; //if this overflows I'll kill myself

    //--- WRITE ENABLES FOR RAM UNITS ------
    logic vram_wren;
    //vram_wren 2 is not used
    logic exam_wren;
    logic wram_wren;
    logic oam_wren;
    logic hram_wren;

    //--- OUTPUTS FOR MEM UNITS ------
    logic [7:0] rom0_out_data;
    logic [7:0] vram_out_data1;
    logic [7:0] vram_out_data2;
    logic [7:0] exram_out_data;
    logic [7:0] wram_out_data;
    logic [7:0] oam_out_data1;
    logic [7:0] oam_out_data2;
    logic [7:0] hram_out_data;

    //--- INPUTS FOR MEM UNITS---
    //note that all other units EXCEPT OAM are tied to cpu_data
    logic [7:0] oam_in_data1;
    logic [7:0] oam_in_data2;
 

    //--- OUTPUT handler ------
    always_comb begin
        case(cpu_data_selector)
        ROM_SELECT:   cpu_out_data = rom0_out_data;
        VRAM_SELECT:  cpu_out_data = vram_out_data1;
        EXRAM_SELECT: cpu_out_data = exram_out_data;
        WRAM_SELECT:  cpu_out_data = wram_out_data;
        HRAM_SELECT:  cpu_out_data = hram_out_data;
        OAM_SELECT:   cpu_out_data = oam_out_data1; 
        INVALID:      cpu_out_data = 16'hFFFF;
        default:      cpu_out_data = 16'hDEAD;
        endcase
    end
    
    always_comb begin
        case(ppu_data_selector)
        VRAM_SELECT: begin 
            ppu_out_data1 = vram_out_data1;
            ppu_out_data2 = vram_out_data1;
        end
        OAM_SELECT: begin
            ppu_out_data1 = oam_out_data1;
            ppu_out_data2 = oam_out_data1;
        end
        INVALID: begin 
            ppu_out_data1 = 16'hFFFF;
            ppu_out_data2 = 16'hFFFF;
        end
        default:  begin 
            ppu_out_data1 = 16'hDEAD;
            ppu_out_data2 = 16'hDEAD;
        end
        endcase
    end       


    DMA_controller dma_guy (.clock,
                            .reset,
                            .DMA_R, 
                            .start_dma,
                            .doing_dma,
                            .DMA_src_addr,
                            .OAM_dest_addr );

    MM_out_chooser memory_out_muxer ( .clock, 
                                      .reset,     
                                      .doing_dma,
                                      .cpu_addr, .ppu_addr1, .ppu_addr2,
                                      .cpu_memory_selector,
                                      .ppu_memory_selector);

    //------for handling contention between cpu/ppu/dma --> STRICTLY related to OAM/VRAM wrens
    MM_addr_contention_handler addr_handler (.clock,
                                             .reset,
                                             .doing_dma,
                                             .cpu_wren, .cpu_addr,    
                                             .ppu_mode, .ppu_addr1, .ppu_addr2,
                                             .dma_src_addr, .dma_dest_addr,
            
                                             .oam_wren, .vram_wren,
                                             .rom0_addr,
                                             .vram_addr1, .vram_addr2,
                                             .exram_addr,
                                             .wram_addr,
                                             .oam_addr1,.oam_addr2,
                                             .hram_addr);

    //-----for memory units WITHOUT contention
    assign exam_wren = cpu_wren && within_range(cpu_addr, EXRAM_START, EXRAM_END);
    assign wram_wren = cpu_wren && within_range(cpu_addr, WRAM_START, WRAM_END);
    assign hram_wren = cpu_wren && within_range(cpu_addr, HRAM_START, HRAM_END);

    assign cpu_data_valid = (cpu_data_selector != INVALID && cpu_data_selector != UNKNOWN);
    assign ppu_data_valid = (ppu_data_selector != INVALID && ppu_data_selector != UNKNOWN);

    //////////////////////////////////////////////////
    //------------  MEMORY MODULES  --------------------
    //////////////////////////////////////////////////
    
    //---ROM BANKS (32 kB) ------ (note that I am combining two banks here, 2nd one is switchable in CGB) 
    ROM_BANK rom0 (.clock  (clock), 
                   .address(rom0_addr), 
                   .q      (rom0_out_data)); 
    //---VRAM BANKS------
    VRAM_DUALBANK vram0 (.clock    (clock), 
                         .address_a(vram_addr1),     .address_b(vram_addr2), 
                         .q_a      (vram_out_data1), .q_b      (vram_out_data2), 
                         .wren_a   (vram_wren),      .wren_b   (1'b0), 
                         .data_a   (cpu_data),       .data_b   (16'hDEAD));
    //---EXTERNAL RAM ------
    EXRAM_BANK exram0 (.clock (clock), 
                      .address(exram_addr), 
                      .q      (exram_out_data), 
                      .wren   (exram_write), 
                      .data   (cpu_data));     
    //---WORK RAM ------ (note that I am combining two banks here, 2nd one is switchable in CGB)                       
    WRAM_BANK wram0 (.clock   (clock), 
                      .address(wram_addr), 
                      .q      (wram_out_data), 
                      .wren   (wram_write), 
                      .data   (cpu_data));
    //---OAM TABLE ------                                                              
    OAM_DUALBANK oam (.clock    (clock), 
                      .address_a(oam_addr1),     .address_b(oam_addr2), 
                      .q_a      (oam_out_data1), .q_b      (oam_out_data2), 
                      .wren_a   (oam_wren),      .wren_b   (1'b0), 
                      .data_a   (oam_in_data),   .data_b   (16'hDEAD));

    //--- HRAM  ------  this feels too small to make a memory unit.                      
    logic[0:7][15:0] HRAM;
    assign hram_out_data = HRAM[hram_addr];
    always_ff @(posedge clock) begin
        if(reset) begin
            HRAM <= '0;
        end else begin
            if(hram_wren) begin
                HRAM[hram_addr] <= cpu_data;
            end else begin
                HRAM <= HRAM;
            end
        end
    end
endmodule: MM_handler;



