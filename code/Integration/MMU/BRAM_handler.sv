`default_nettype none
`include "RegisterPkg.pkg"
`include "addresses.svh"
`include "select.svh"



module BRAM_handler(input logic clock,
                  input logic reset,

                  input logic [15:0] cpu_addr_read,
                  input logic [15:0] cpu_addr_write,
                  input logic        cpu_wren,
                  input logic [15:0]  cpu_in_data,

                  input logic [15:0] ppu_addr1,
                  input logic [15:0] ppu_addr2, 
                  input logic  [1:0] ppu_mode,

                  input logic  [7:0] DMA_R,
                  input logic        start_dma,

                  output logic       doing_dma,

                  output logic [15:0] cpu_out_data,

                  output logic [15:0] ppu_out_data1,
                  output logic [15:0] ppu_out_data2,

                  output logic       cpu_data_valid,
                  output logic       ppu_data_valid);

    //---ADDR DECLARATIONS------                  
    //if any of these overflow then I WILL kill myself
    //16KB x 2 = 32kB combined rom, 16 bit width --> 16384 entries, so 14 bits addr
    logic [13:0] rom0_addr;
    //8KB inside dual vram, 16 bit width --> 4096 entries, so 12 bits addr
    logic [11:0] vram_addr_rw,  vram_addr_r;    
    //8KB inside dual vram, 16 bit width --> 4096 entries, so 12 bits addr      
    //8KB inside ex vram, 16 bit width --> 4096 entries, so 12 bits addr
    logic [11:0] exram_addr_r, exram_addr_w; 
    //4KB x 2 = 8KB inside work vram, 16 bit width --> 4096 entries, so 12 bits addr
    logic [11:0] wram_addr_r,  wram_addr_w;      

    //160 kB inside work vram, 16 bit width --> 80 entries (makes sense, given 40 sprites)
    logic [6:0] oam_addr_rw,    oam_addr_r;  
    logic [3:0] hram_addr_r,   hram_addr_w; //if this overflows I'll kill myself

    //--- WRITE ENABLES FOR RAM UNITS ------
    logic vram_wren, exram_wren, wram_wren, oam_wren, hram_wren;
    logic dma_oam_wren;

    //--- OUTPUTS FOR MEM UNITS ------
    logic [15:0] rom0_out_data;
    logic [15:0] vram_out_data_rw,  vram_out_data_r;
    logic [15:0] exram_out_data;
    logic [15:0] wram_out_data;
    logic [15:0] oam_out_data_rw,   oam_out_data_r;
    logic [15:0] hram_out_data;

    //--- INPUTS FOR MEM UNITS---
    //note that all other units EXCEPT OAM are tied to cpu_data
    logic [15:0] oam_data_in;

    //--- DMA related signals (addrs) ---
    logic [15:0] dma_src_addr, dma_dest_addr;
    logic [15:0] dma_in_data;

    //--- OUTPUT handler ------

    logic[5:0] cpu_memory_selector, ppu_memory_selector, dma_memory_selector;

    //--- MISC signals ------

    assign oam_data_in = (doing_dma) ? dma_in_data : cpu_in_data;


    always_comb begin
        case(cpu_memory_selector)
        `ROM_SELECT:   cpu_out_data = rom0_out_data;
        `VRAM_SELECT:  cpu_out_data = vram_out_data_rw;
        `EXRAM_SELECT: cpu_out_data = exram_out_data;
        `WRAM_SELECT:  cpu_out_data = wram_out_data;
        `HRAM_SELECT:  cpu_out_data = hram_out_data;
        `OAM_SELECT:   cpu_out_data = oam_out_data_rw; 
        `INVALID:      cpu_out_data = 8'hFF;
        default:      cpu_out_data = 8'hxx;
        endcase
    end
    
    always_comb begin
        case(ppu_memory_selector)
        `VRAM_SELECT: begin 
            ppu_out_data1 = vram_out_data_rw;
            ppu_out_data2 = vram_out_data_r;
        end
        `OAM_SELECT: begin
            ppu_out_data1 = oam_out_data_rw;
            ppu_out_data2 = oam_out_data_r;
        end
        `INVALID: begin 
            ppu_out_data1 = 8'hFF;
            ppu_out_data2 = 8'hFF;
        end
        default:  begin 
            ppu_out_data1 = 8'hxx;
            ppu_out_data2 = 8'hxx;
        end
        endcase
    end       


    always_comb begin
        case(dma_memory_selector)
        `ROM_SELECT:   dma_in_data = rom0_out_data;
        `VRAM_SELECT:  dma_in_data = vram_out_data_rw;
        `EXRAM_SELECT: dma_in_data = exram_out_data;
        `WRAM_SELECT:  dma_in_data = wram_out_data;
        `HRAM_SELECT:  dma_in_data = hram_out_data;
        `INVALID:      dma_in_data = 8'hFF;
        default:       dma_in_data = 8'hxx;
        endcase
    end
        


    DMA_controller dma_guy (.clock,
                            .reset,
                            .DMA_R, 
                            .start_dma,
                            .doing_dma,
                            .dma_oam_wren,
                            .dma_src_addr,
                            .dma_dest_addr);

    MM_out_chooser memory_out_muxer ( .clock, 
                                      .reset,     
                                      .doing_dma,
                                      .ppu_mode,
                                      .cpu_addr_read, .ppu_addr1, .ppu_addr2,
                                      .cpu_memory_selector,
                                      .ppu_memory_selector,

                                      .dma_src_addr,
                                      .dma_memory_selector);

    //------for handling contention between cpu/ppu/dma --> STRICTLY related to OAM/VRAM wrens
    MM_addr_contention_handler addr_handler (.clock,
                                             .reset,
                                             .doing_dma,
                                             .dma_oam_wren,
                                             .cpu_wren, .cpu_addr_write,    
                                             .ppu_mode, .ppu_addr1, .ppu_addr2,
                                             .dma_src_addr, .dma_dest_addr,
                                             .oam_wren, .vram_wren,
                                             .rom0_addr,
                                             .vram_addr_rw, .vram_addr_r,
                                             .exram_addr_w,
                                             .wram_addr_w,
                                             .oam_addr_rw,  .oam_addr_r,
                                             .hram_addr_w);

    //-----for memory units WITHOUT contention
    assign exram_wren = cpu_wren && within_range(cpu_addr_write, `EXRAM_START, `EXRAM_END);
    assign wram_wren = cpu_wren && within_range(cpu_addr_write, `WRAM_START, `WRAM_END);
    assign hram_wren = cpu_wren && within_range(cpu_addr_write, `HRAM_START, `HRAM_END);

    assign exram_addr_r = cpu_addr_read;
    assign wram_addr_r = cpu_addr_read;
    assign hram_addr_r = cpu_addr_read;


    assign cpu_data_valid = (cpu_memory_selector != `INVALID);
    assign ppu_data_valid = (ppu_memory_selector != `INVALID && ppu_memory_selector != `UNKNOWN);



    //////////////////////////////////////////////////
    //------------  MEMORY MODULES  --------------------
    //////////////////////////////////////////////////
    
    //---ROM BANKS (32 kB) ------ (note that I am combining two banks here, 2nd one is switchable in CGB) 
    ROM_BANK rom0 (.clock  (clock), 
                   .address(rom0_addr), 
                   .q      (rom0_out_data)); 
    //---VRAM BANKS------
    DUAL_8KB vram0 (.clock    (clock), 
                    .address_a(vram_addr_rw),     .address_b(vram_addr_r), 
                    .q_a      (vram_out_data_rw), .q_b      (vram_out_data_r), 
                    .wren_a   (vram_wren),        .wren_b   (1'b0), 
                    .data_a   (cpu_in_data),      .data_b   (16'hXXXX));
    //---EXTERNAL RAM ------
    DUAL_8KB exram0 (.clock (clock), 
                     .address_a(exram_addr_w),     .address_b(exram_addr_r), 
                     .q_a      (),                 .q_b      (exram_out_data),
                     .wren_a   (exram_wren),       .wren_b   (1'b0), //read ONLY port
                     .data_a   (cpu_in_data),      .data_b   (1'b0));   
    //---WORK RAM ------ (note that I am combining two banks here, 2nd one is switchable in CGB)                       
    DUAL_8KB wram0 (.clock    (clock), 
                    .address_a(wram_addr_w),     .address_b(wram_addr_r),  
                    .q_a      (),                .q_b      (wram_out_data), 
                    .wren_a   (wram_wren),       .wren_b   (1'b0), //read ONLY port
                    .data_a   (cpu_in_data),     .data_b   (1'b0));

    //---OAM TABLE ------                                                              
    OAM_DUALBANK oam (.clock    (clock), 
                      .address_a(oam_addr_rw),     .address_b(oam_addr_r), 
                      .q_a      (oam_out_data_rw), .q_b      (oam_out_data_r), 
                      .wren_a   (oam_wren),        .wren_b   (1'b0), 
                      .data_a   (oam_data_in),     .data_b   (16'hXXXX));

    //--- HRAM  ------  this feels too small to make a memory unit.                      
    logic[0:15][15:0] HRAM;
    logic[15:0] unbuffered_hram_out;
    assign unbuffered_hram_out = HRAM[hram_addr_r];
    always_ff @(posedge clock) begin
        hram_out_data <= unbuffered_hram_out;
        if(reset) begin
            HRAM <= '0;
        end else begin
            if(hram_wren) begin
                HRAM[hram_addr_w] <= cpu_in_data;
            end else begin
                HRAM <= HRAM;
            end
        end
    end
endmodule: BRAM_handler;



