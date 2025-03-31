// `default_nettype none
`include "RegisterPkg.svh"
`include "addresses.svh"
`include "select.svh"

module MM_out_chooser(input logic clock,
                      input logic reset,
                      input logic doing_dma,

                      input logic [1:0] ppu_mode,
                      input logic LCDC_R,

                      input logic[15:0] cpu_addr_read,
                      input logic[15:0] ppu_addr1,
                      input logic[15:0] ppu_addr2,

                      input logic[15:0] dma_src_addr,


                      output logic[5:0] dma_memory_selector,
                      output logic[5:0] cpu_memory_selector,
                      output logic[5:0] ppu_memory_selector);

    logic [5:0] cpu_select, ppu_select, dma_select;

    always_ff@(posedge clock) begin
        //NOTE: Brams take 2 cycles to output the correct data...
        cpu_memory_selector <= cpu_select;
        ppu_memory_selector <= ppu_select;
        dma_memory_selector <= dma_select;


        if(reset) begin
            cpu_select <= `INVALID;
            ppu_select <= `INVALID;
            dma_select <= `INVALID;
        end else if(doing_dma) begin
			//its'a'me dma
            if(within_range(cpu_addr_read, `HRAM_START, `HRAM_END)) begin
                cpu_select <= `HRAM_SELECT;
			end else begin
	            cpu_select <= `INVALID;	
			end
            
			ppu_select <= `INVALID;

            //-----FOR HANDLING DMA CHOOSING----
            if(within_range(dma_src_addr, `ROM_0_START, `ROM_1_END)) begin
                dma_select <= `ROM_SELECT;
            end
            else if(within_range(dma_src_addr, `VRAM_START, `VRAM_END)) begin
                dma_select <= `VRAM_SELECT;
            end
            else if(within_range(dma_src_addr, `EXRAM_START, `EXRAM_END)) begin
                dma_select <= `EXRAM_SELECT;
            end
            else if( within_range(dma_src_addr, `WRAM_START, `WRAM_END)) begin
                dma_select <= `WRAM_SELECT;
            end
            else if(within_range(dma_src_addr, `HRAM_START, `HRAM_END)) begin
                dma_select <= `HRAM_SELECT;
            end
            else begin
                //default case
                dma_select <= `UNKNOWN;
            end
        end else begin
            //-----FOR HANDLING CPU CHOOSING----
            if(within_range(cpu_addr_read, `ROM_0_START, `ROM_1_END)) begin
                cpu_select <= `ROM_SELECT;
            end
            else if(within_range(cpu_addr_read, `VRAM_START, `VRAM_END)) begin
                if(ppu_mode == 2'd3) begin
                    cpu_select <= `INVALID;
                end else begin
                    cpu_select <= `VRAM_SELECT;
                end
            end
            else if(within_range(cpu_addr_read, `EXRAM_START, `EXRAM_END)) begin
                cpu_select <= `EXRAM_SELECT;
            end
            else if( within_range(cpu_addr_read, `WRAM_START, `WRAM_END)) begin
                cpu_select <= `WRAM_SELECT;
            end
            else if(within_range(cpu_addr_read, `OAM_START, `OAM_END)) begin
                cpu_select <= `OAM_SELECT;
               // if(ppu_mode == 2'd2 || ppu_mode == 2'd3) begin
               //     cpu_select <= `INVALID;
               // end else begin
               //     cpu_select <= `OAM_SELECT;
               // end
            end
            else if(within_range(cpu_addr_read, `HRAM_START, `HRAM_END)) begin
                cpu_select <= `HRAM_SELECT;
            end
            else begin
                //default case
                cpu_select <= `UNKNOWN;
            end

            //-----FOR HANDLING PPU CHOOSING----
            if(within_range(ppu_addr1, `OAM_START, `OAM_END) && within_range(ppu_addr2, `OAM_START, `OAM_END)) begin
                if(ppu_mode == 2'd2) begin
                    ppu_select <= `OAM_SELECT;
                end else begin
                    ppu_select <= `INVALID;
                end
            end
            else if(within_range(ppu_addr1, `VRAM_START, `VRAM_END) && within_range(ppu_addr2, `VRAM_START, `VRAM_END)) begin
                if(ppu_mode == 2'd3) begin
                    ppu_select <= `VRAM_SELECT;
                end else begin
                    ppu_select <= `INVALID;
                end
            end
            else begin
                //default case
                ppu_select <= `UNKNOWN;
            end

        end
    end
endmodule: MM_out_chooser
