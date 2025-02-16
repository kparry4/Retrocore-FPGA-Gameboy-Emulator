package defs;
  
  typedef enum logic [2:0] {
      PC_IDU,                 // PC + instrSz
      PC_DC = 'x            // Don't care value
  } pcSel_t;

  typedef enum logic [2:0] {
      ADR_PC,                // PC
      ADR_FF,                // FF00+rs1
      ADR_RS,                // send 16 bit rs as addr
      ADR_DC = 'x            // Don't care value
  } adr_sel_t;

  typedef enum logic [2:0] {
      WADR_RS,                // send 16 bit rs as addr
      WADR_FF,                // send FF00+rs1 as addr
      WADR_DC = 'x            // Don't care value
  } wadr_sel_t;

  typedef enum logic [2:0] {
      DAT_NOP,               // NOP
      DAT_DC = 'x            // Don't care value
  } data_sel_t;

  typedef enum logic [2:0] {
      IDU_PC,                // PC
      IDU_DC = 'x            // Don't care value
  } idu_op_t;

  typedef enum logic [2:0] {
      WDAT_RS2,                // sleect rs2 as write mem data
      WDAT_N,                // n as write mem data
      WDAT_DC = 'x            // Don't care value
  } wdat_sel_t;

  typedef enum logic [2:0] {
      ALU_ADD,                // add
      ALU_R,                  // src1
      ALU_DC = 'x             // Don't care value
  } alu_op_t;

  typedef enum logic [2:0] {
    RD_ALU,                // ALU
    RD_MEM,                // memory or n
    RD_DC = 'x             // Don't care value
  } rd_sel_t;

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
      logic iren;              // save next opcode
      logic useOp;              // load next op code
      logic rdWen;             // reg file write enable
      logic memWen;             // reg file write enable
      rd_sel_t rdSel;          // what value is used for rd
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
      LD_AHLD,    // A <- (HL-1)
      LD_AHLD2,
      LD_HLDA,    // (HL-1) <- A
      LD_HLDA2,
      LD_AHLI,    // A <- (HL+1)
      LD_AHLI2,
      LD_HLIA,    // (HL+1) <- A
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
      LD_HLSPE,    // HL <- SP+e
      LD_HLSPE2,
      LD_HLSPE3,
      BAD = 'x
  } mpc_t;
endpackage