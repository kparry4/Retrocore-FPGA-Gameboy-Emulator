`default_nettype none
`include "RegisterPkg.pkg"
`include "addresses.svh"

module DMA_controller(input logic clock,
                      input logic reset,

                      input logic [7:0] DMA_R,
                      
                      output logic doing_dma,
                      
                      output logic [15:0] DMA_src_addr,
                      output logic [15:0] OAM_dest_addr);

    enum logic[2:0] {IDLE, READING, WRITING, FINISHED} state, nextState;
    localparam DMA_CYCLE_COUNT = 640; //160 M cycles
    localparam FINAL_OAM_ADDR = 16'hFE9F;
    
    logic [9:0] cycle_count; 
    logic cycle_count_inc_en;
    logic dma_addr_inc_en;

    Counter #(10) dma_addr_cnter  (.D    ({DMA_R, '00}), 
                                   .Q    (DMA_src_addr), 
                                   .load (load_dma_register),
                                   .en   (dma_addr_inc_en),
                                   .clear(), 
                                   .up   (1'b1), 
                                   .clock(clock), 
                                   .reset(reset));  

    Counter #(10) oam_addr_cnter  (.D    (OAM_START), 
                                   .Q    (OAM_dest_addr), 
                                   .load (load_oam_init),
                                   .en   (dma_addr_inc_en),
                                   .clear(), 
                                   .up   (1'b1), 
                                   .clock(clock), 
                                   .reset(reset));                                      

    Counter #(10) cycle_cnter   (.D    (), 
                                 .Q    (cycle_count), 
                                 .load (),
                                 .en   (cycle_count_inc_en),
                                 .clear(cycle_cnt_clear || reset), 
                                 .up   (1'b1), 
                                 .clock(clock), 
                                 .reset(reset));                                   



    always_comb begin
        case(state)
        IDLE: begin
            if(start_dma) begin
                nextState = READING;
                //load dma, oam registers with initial addrs
                //begin incrementing DMA 160 Mcycle countdown
                load_dma_register = 1'b1;
                load_oam_init = 1'b1;
                cycle_count_inc_en = 1'b1;
            end else begin
                //do nothing
                nextState = IDLE;
                load_dma_register = 1'b0;
                load_oam_init = 1'b0;
                cycle_count_inc_en = 1'b0;
            end
            
            dma_addr_inc_en = 1'b0;
            cycle_cnt_clear = 1'b1;
            
            doing_dma = 1'b0;
        end
        READING: begin
            nextState = (cycle_count == DMA_CYCLE_COUNT - 1) ? IDLE : WRITING;

            //do NOT load dma/oam addr registers
            load_dma_register = 1'b0;
            load_oam_init = 1'b0;

            //increment cycle count
            cycle_count_inc_en = 1'b1; 
            
            //do not yet increment dma address (finish the r/w first)
            dma_addr_inc_en = 1'b0;
            
            //do NOT clear cycle count
            cycle_cnt_clear = 1'b0;
            
            //output dma signal
            doing_dma = 1'b1;                       
        end
        WRITING: begin
            if(dma_dest_addr == FINAL_OAM_ADDR) begin
                nextState = FINISHED;
            end else begin
                nextState = (cycle_count == DMA_CYCLE_COUNT - 1) ? IDLE : READING;
            end
            //do NOT load dma/oam addr registers
            load_dma_register = 1'b0;
            load_oam_init = 1'b0;

            //increment cycle count
            cycle_count_inc_en = 1'b1; 
            
            //increment dma address (r/w will finish this cycle)
            dma_addr_inc_en = 1'b1;
            
            //do NOT clear cycle count
            cycle_cnt_clear = 1'b0;
            
            //output dma signal
            doing_dma = 1'b1;             
        end
        FINISHED: begin
            if(cycle_count == DMA_CYCLE_COUNT - 1) begin
                nextState = IDLE;
            end else begin
                nextState = FINISHED;
            end

            //do NOT load dma/oam addr registers
            load_dma_register = 1'b0;
            load_oam_init = 1'b0;

            //increment cycle count
            cycle_count_inc_en = 1'b1; 
            
            //no more, we finished
            dma_addr_inc_en = 1'b0;
            
            //do NOT clear cycle count
            cycle_cnt_clear = 1'b0;
            
            //output dma signal
            doing_dma = 1'b1;              
        end
        endcase
    end

endmodule: DMA_controller