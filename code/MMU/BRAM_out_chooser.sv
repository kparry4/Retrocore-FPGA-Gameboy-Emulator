`default_nettype none
`include "RegisterPkg.pkg"
`include "addresses.svh"
`include "select.svh"

module MM_out_chooser(input logic clock, 
                      input logic reset,
                      input logic doing_dma,

                      input logic[15:0] cpu_addr,
                      input logic[15:0] ppu_addr1,
                      input logic[15:0] ppu_addr2,
  
                      output logic[5:0] cpu_memory_selector,
                      output logic[5:0] ppu_memory_selector);
    
    always_ff(@posedge clock) begin
        if(reset || doing_dma) begin
            cpu_memory_selector <= INVALID;
            ppu_memory_selector <= INVALID;
        end else begin
            //-----FOR HANDLING CPU CHOOSING----
            if(within_range(cpu_addr, ROM_0_START, ROM_0_END)) begin
                cpu_memory_selector <= ROM_SELECT;
            end
            else if(within_range(cpu_addr, VRAM_START, VRAM_END)) begin
                cpu_memory_selector <= VRAM_SELECT;
            end
            else if(within_range(cpu_addr, EXRAM_START, EXRAM_END)) begin
                cpu_memory_selector <= EXRAM_SELECT;
            end
            else if( within_range(cpu_addr, WRAM_START, WRAM_END)) begin
                cpu_memory_selector <= WRAM_SELECT;
            end
            else if(within_range(cpu_addr, OAM_START, OAM_END)) begin
                cpu_memory_selector <= OAM_SELECT;
            end
            else if(within_range(cpu_addr, HRAM_START, HRAM_END)) begin
                cpu_memory_selector <= HRAM_SELECT;
            end
            else begin
                //default case
                cpu_memory_selector <= UNKNOWN;
            end

            //-----FOR HANDLING PPU CHOOSING----
            if(within_range(ppu_addr1, OAM_START, OAM_END) && within_range(ppu_addr2, OAM_START, OAM_END)) begin
                ppu_data_selector <= OAM_SELECT;
            end
            else  if(within_range(ppu_addr1, VRAM_START, VRAM_END) && within_range(ppu_addr2, VRAM_START, VRAM_END)) begin
                ppu_data_selector <= VRAM_SELECT;
            end
            else begin
                //default case
                ppu_data_selector <= UNKNOWN;
            end    

        end
    end
endmodule: MM_out_chooser
