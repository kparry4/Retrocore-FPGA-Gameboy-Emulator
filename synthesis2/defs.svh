`ifndef DEFS
`define DEFS
package defs;
  
  typedef enum logic [2:0] {
      PC_1,                 // PC + 1
      PC_M1,                 // PC - 1
      PC_RS,                 // PC + instrSz
      PC_IDU,                 // PC + instrSz
      PC_PRE,                 // PC + instrSz
      PC_INT,                 // PC + instrSz
      PC_DC            // Don't care value
  } pcSel_t;

  typedef enum logic [2:0] {
      ADR_PC,                // PC
      ADR_FF,                // FF00+rs1
      ADR_FFN,                // FF00+n
      ADR_RS,                // send 16 bit rs as addr
      ADR_NRS,               // use rs1 and msb of nn
      ADR_IDU,               // IDU result
      ADR_PRE,               // IDU result
      ADR_INT,               // IDU result
      ADR_DC = 'x            // Don't care value
  } adr_sel_t;

  typedef enum logic [2:0] {
      WADR_RS,                // send 16 bit rs as addr
      WADR_FF,                // send FF00+rs1 as addr
      WADR_FLG,                // interupt flag register adr
      WADR_DC = 'x            // Don't care value
  } wadr_sel_t;


  typedef enum logic [2:0] {
      IDU_PC,                // PC as input
      IDU_PCE,                // PC as input
      IDU_RS,                // rs16 as input
      IDU_DC = 'x            // Don't care value
  } idu_op_t;

  typedef enum logic [2:0] {
      WDAT_RS2,                // sleect rs2 as write mem data
      // WDAT_N,                // n as write mem data
      WDAT_PC,                // write upper pc
      WDAT_PCL,                // write lower pc
      WDAT_FLG,                // write to flags
      WDAT_DC = 'x            // Don't care value
  } wdat_sel_t;

  typedef enum logic [4:0] {
      ALU_ADD,                // add
      ALU_ADD2,                // add for msbs
      ALU_ADC,                // add w/ carry
      ALU_SUB,                // sub
      ALU_SBC,                // sub w/ carry
      ALU_AND,                // and
      ALU_OR,                 // or
      ALU_XOR,                // xor
      ALU_CCF,                // commplement carry flag
      ALU_DAA,                // commplement carry flag
      ALU_NOT,                // commplement A
      ALU_RLC,                // commplement A
      ALU_RRC,                // commplement A
      ALU_RR,                // commplement A
      ALU_RL,                // commplement A
      ALU_SRA,                // commplement A
      ALU_SLA,                // commplement A
      ALU_SRL,                // commplement A
      ALU_SWAP,                // commplement A
      ALU_BIT,                // commplement A
      ALU_RES,                // commplement A
      ALU_SET,                // commplement A
      ALU_R,                  // src1
      ALU_DC = 'x             // Don't care value
  } alu_op_t;

  typedef enum logic [2:0] {
    RD_ALU,                // ALU
    RD_IDU,                // IDU result
    RD_MEM,                // memory or n
    RD_RS16,                // rs16
    RD_NRS,                // rs16
    RD_DC = 'x             // Don't care value
  } rd_sel_t;

  typedef enum logic [2:0] {
    RS2_RS2,                // rs2
    RS2_1,                // 1
    RS2_MEM,                // memory or n
    RS2_DC = 'x             // Don't care value
  } rs2_sel_t;

  typedef enum logic [2:0] {
    RS1_RS1,                // rs2
    RS1_MEM,                // memory or n
    RS1_DC = 'x             // Don't care value
  } rs1_sel_t;

  typedef enum logic [2:0] {
    RD2_MEM,                // memory or n
    RD2_DC = 'x             // Don't care value
  } rd2_sel_t;

  typedef enum logic [1:0] {
    CC_NZ,                // not zero
    CC_Z,                // not zero
    CC_NC,                // not zero
    CC_C,                // not zero
    CC_DC = 'x             // Don't care value
  } cc_t;

  typedef enum logic [3:0] {
    B,
    C,
    D,
    E,
    H,
    L,
    F,
    A,
    W,
    Z,
    SP,
    SPL,
    DC = 'x 
  } reg_t;

  typedef struct packed {
      pcSel_t pcSel;           // what is next pc
      adr_sel_t adrSel;        // select adreess to send to memory
      wadr_sel_t wadrSel;        // select write adreess to send to memory
      wdat_sel_t wdatSel;        // select write adreess to send to memory
      alu_op_t aluOp;          // which alu opperation
      idu_op_t iduSel;         // which input for idu
      logic iduSub;            // decrement op for idu?
      logic pcen;              // enable pc register
      reg_t rs1;               // which register for rs1
      reg_t rs2;               // which register for rs2
      reg_t rd;                // which register for rd
      reg_t rd2;                // which register for rd
      logic iren;              // save next opcode
      logic useOp;              // load next op code
      logic rdWen;             // reg file write enable
      logic [3:0] flgWen;             // flag file write enable
      logic [3:0] flgKill;             // flag file write enable
      logic [3:0] flgSet;             // flag file write enable
      logic [2:0] b;             // which bit
      logic rd2Wen;             // reg file write enable
      logic rdW16;             // write 16 bits to regfile
      logic memWen;             // reg file write enable
      rd_sel_t rdSel;          // what value is used for rd
      cc_t cc;          // what value is used for rd
      rd2_sel_t rd2Sel;          // what value is used for rd
      rs2_sel_t rs2Sel;          // what value is used for rs2
      rs1_sel_t rs1Sel;          // what value is used for rs1
      logic done;              // is instruction done
  } ctrl_t;

  typedef enum logic [10:0] {
      NOP,      // nop
      LD_RN,    // r<-n
      LD_RN2,
      LD_RR,    // r<-r'
      LD_RHL,    // r<-(HL)
      LD_RHL2,
      LD_HLR,   // (HL) <- r
      LD_HLR2,
      LD_HLN,   // (HL) <- n
      LD_HLN2,
      LD_HLN3,
      LD_ABC,    // A<-(BC)
      LD_ABC2,
      LD_ADE,    // A<-(DE)
      LD_ADE2,
      LD_BCA,    // (BC)<-A
      LD_BCA2,
      LD_DEA,    // (DE)<-A
      LD_DEA2,
      LD_ANN,    // A<-(nn)
      LD_ANN2,
      LD_ANN3,
      LD_ANN4,
      LD_NNA,    // (nn) <A
      LD_NNA2,
      LD_NNA3,
      LD_NNA4,
      LDH_AC,    // A<-(FF00+C)
      LDH_AC2,
      LDH_CA,    // (FF00+C)<-A
      LDH_CA2,
      LDH_AN,    // A<-(FF00+n)
      LDH_AN2,
      LDH_AN3,
      LDH_NA,    // A<-(FF00+n)
      LDH_NA2,
      LDH_NA3,
      LD_AHLD,    // A <- (HL) HL--
      LD_AHLD2,
      LD_HLDA,    // (HL) <- A HL--
      LD_HLDA2,
      LD_AHLI,    // A <- (HL) HL++
      LD_AHLI2,
      LD_HLIA,    // (HL) <- A HL++
      LD_HLIA2,
      LD_RRNN,    // RR<-nn
      LD_RRNN2,
      LD_RRNN3,
      LD_NNSP,    // (nn)<-SP
      LD_NNSP2,
      LD_NNSP3,
      LD_NNSP4,
      LD_NNSP5,
      LD_SPHL,    // SP<-HL
      LD_SPHL2,
      PUSH,    // push rr
      PUSH2,
      PUSH3,
      PUSH4,
      POP,    // pop rr
      POP2,
      POP3,
      LD_HLSPE,    // HL <- SP+e hc
      LD_HLSPE2,
      LD_HLSPE3,
      ADD_R,    // A = A+R z0hc
      ADD_HL,   // A = A+(HL) z0hc
      ADD_HL2,
      ADD_N,   // A = A+n z0hc
      ADD_N2,
      ADC_R,    // A = A+R+c z0hc
      ADC_HL,   // A = A+(HL)+c z0hc
      ADC_HL2,
      ADC_N,   // A = A+n+c z0hc
      ADC_N2,
      SUB_R,    // A = A-R z1hc
      SUB_HL,   // A = A-(HL) z1hc
      SUB_HL2,
      SUB_N,   // A = A-n z1hc
      SUB_N2,
      SBC_R,    // A = A-R-c z1hc
      SBC_HL,   // A = A-(HL)-c z1hc
      SBC_HL2,
      SBC_N,   // A = A-n-c z1hc
      SBC_N2,
      CP_R,    // A-R z1hc
      CP_HL,   // A-(HL) z1hc
      CP_HL2,
      CP_N,   // A-n z1hc
      CP_N2,
      INC_R,    // R++ z0h-
      INC_HL,   // (HL)++ z0h-
      INC_HL2,
      INC_HL3,
      DEC_R,    // R-- z1h-
      DEC_HL,   // (HL)-- z1h-
      DEC_HL2,
      DEC_HL3,
      AND_R,    // A = A&r z010
      AND_HL,   // A = A&(HL) z010
      AND_HL2,
      AND_N,   // A = A&n z010
      AND_N2,
      OR_R,    // A = A|r z000
      OR_HL,   // A = A|(HL) z000
      OR_HL2,
      OR_N,   // A = A|n z000
      OR_N2,
      XOR_R,    // A = A^r z000
      XOR_HL,   // A = A^(HL) z000
      XOR_HL2,
      XOR_N,   // A = A^n z000
      XOR_N2,
      CCF,   // -00~c
      SCF,   // -001
      DAA,   // A = A + adj z-hc
      CPL,   // A = ~A -11-
      INC_RR,   // RR++
      INC_RR2,
      DEC_RR,   // RR--
      DEC_RR2,
      ADD_HLRR,   // HL += RR -0hc
      ADD_HLRR2,
      ADD_SPE,   // SP += e 00hc
      ADD_SPE2,
      ADD_SPE3,
      ADD_SPE4,
      RLCA,   // A = {A,b7}<<1 000b7
      RRCA,   // A = {b0,A}>>1 000b0
      RLA,   // A = {A,c}<<1 000b7
      RRA,   // A = {c,A}>>1 000b0
      RLC_R,   // R = {R,b7}<<1 z00b7
      RLC_HL,   // (HL) = {(HL),b7}<<1 z00b7
      RLC_HL2,
      RLC_HL3,
      RRC_R,   // R = {b0,R}>>1 z00b0
      RRC_HL,   // (HL) = {b0,(HL)}>>1 z00b0
      RRC_HL2,
      RRC_HL3,
      RL_R,   // R = {R,c}<<1 z00b7
      RL_HL,   // (HL) = {(HL),c}<<1 z00b7
      RL_HL2,
      RL_HL3,
      RR_R,   // R = {c,R}>>1 z00b7
      RR_HL,   // (HL) = {c,(HL)}>>1 z00b7
      RR_HL2,
      RR_HL3,
      SLA_R,   // R = {R,0}<<1 z00b7
      SLA_HL,   // (HL) = {(HL),0}<<1 z00b7
      SLA_HL2,
      SLA_HL3,
      SRA_R,   // R = {b7,R}>>1 z00b0
      SRA_HL,   // (HL) = {b7,(HL)}>>1 z00b0
      SRA_HL2,
      SRA_HL3,
      SWAP_R,   // R = {b3-0,b7-4} z000
      SWAP_HL,   // (HL) = {b3-0,b7-4} z000
      SWAP_HL2,
      SWAP_HL3,
      SRL_R,   // R = {0,R}>>1 z00b0
      SRL_HL,   // (HL) = {0,(HL)}>>1 z00b0
      SRL_HL2,
      SRL_HL3,
      BIT_R,   // bit b in r z01-
      BIT_HL,   // bit b in (HL) z01-
      BIT_HL2,
      RES_R,   // bit b in r = 0
      RES_HL,   // bit b in (HL) = 0
      RES_HL2,
      RES_HL3,
      SET_R,   // bit b in r = 1
      SET_HL,   // bit b in (HL) = 1
      SET_HL2,
      SET_HL3,
      JP_NN,   // PC = nn
      JP_NN2,
      JP_NN3,
      JP_NN4,
      JP_HL,   // PC = HL
      JP_CCNN,   // PC = nn if cc
      JP_CCNN2,
      JP_CCNN3,
      JP_CCNN4,
      JR_E,   // PC += e
      JR_E2,
      JR_E3,
      JR_CCE,   // PC += e if cc
      JR_CCE2,
      JR_CCE3,
      CALL_NN,   // SP-=2 push PC PC = nn 
      CALL_NN2,
      CALL_NN3,
      CALL_NN4,
      CALL_NN5,
      CALL_NN6,
      CALL_CCNN,   // SP-=2 push PC PC = nn if cc
      CALL_CCNN2,
      CALL_CCNN3,
      CALL_CCNN4,
      CALL_CCNN5,
      CALL_CCNN6,
      RET,   // SP+=2 pop PC
      RET2,
      RET3,
      RET4,
      RET_CC,   // SP+=2 pop PC if cc
      RET_CC2,
      RET_CC3,
      RET_CC4,
      RET_CC5,
      RETI,   // SP+=2 pop PC IME=1
      RETI2,
      RETI3,
      RETI4,
      RST_N,   // SP-=2 push PC=enocded
      RST_N2,
      RST_N3,
      RST_N4,
      HALT, // stop till interupt
      STOP, // off button
      DI,    // disable interupt
      EI,    // enable interupt
      INTERUPT,    // enable interupt
      INTERUPT2,
      INTERUPT3,
      INTERUPT4,
      INTERUPT5,
      BAD
  } mpc_t;
endpackage

`define READHL \
  ctrl.rs1 = H;\
  ctrl.adrSel = ADR_RS;\
  ctrl.pcen = 0;
`define READN \
        ctrl.rd = Z;\
        ctrl.rdSel = RD_MEM;\
        ctrl.rdWen = 1;
`define READNN \
        ctrl.rd = W;\
        ctrl.rdSel = RD_MEM;\
        ctrl.rdWen = 1;
`define WRITEHL \
        ctrl.rs1 = H;\
        ctrl.wadrSel = WADR_RS;\
        ctrl.wdatSel = WDAT_RS2;\
        ctrl.memWen = 1;\

import defs::*;
`endif
