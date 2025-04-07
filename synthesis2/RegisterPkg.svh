`ifndef REGISTER_PKG
  `define REGISTER_PKG
    package RegisterPkg;
        typedef struct packed {

            //----Global Control
            //logic[7:0] NR52_R; //Audio master ctrl (FF26)
            logic[7:0] NR51_R; //Sound panning (FF25)
            logic[7:0] NR50_R; //Master Volume, Vin panning(FF24)

            logic [0:5][7:0] NR1x_R; //TODO: this might be cursed
            logic [0:4][7:0] NR2x_R; //TODO: this might be cursed
            logic [0:4][7:0] NR3x_R; //TODO: this might be cursed
            logic [0:15][7:0] WAV_RAM_R;     
            logic [0:5][7:0] NR4x_R; //TODO: this might be cursed
        } APU_DATA;

        typedef struct packed {
            //logic[7:0] LCDC_R;
            //logic[7:0] STAT_R;
            logic[7:0] SCY_R; 
            logic[7:0] SCX_R; 
            logic[7:0] LY_R;  
            logic[7:0] LYC_R; 

            logic[7:0] BGP_R; 
            logic[7:0] OBP0_R;
            logic[7:0] OBP1_R;
            logic[7:0] WY_R;  
            logic[7:0] WX_R;  
        } PPU_DATA;
    endpackage: RegisterPkg
        
        import RegisterPkg::*;
`endif
