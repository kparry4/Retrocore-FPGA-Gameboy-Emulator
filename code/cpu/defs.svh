package defs;
  
  typedef enum logic [2:0] {
      PC_IDU,                 // PC + instrSz
      PC_DC = 'x            // Don't care value
  } pcSel_t;

  typedef enum logic [2:0] {
      ADR_PC,                // PC
      ADR_DC = 'x            // Don't care value
  } adr_sel_t;

  typedef enum logic [2:0] {
      DAT_NOP,               // NOP
      DAT_DC = 'x            // Don't care value
  } data_sel_t;

  typedef enum logic [2:0] {
      IDU_PC,                // PC
      IDU_DC = 'x            // Don't care value
  } idu_op_t;

  typedef enum logic [2:0] {
      ALU_ADD,                // add
      ALU_R,                  // src1
      ALU_DC = 'x             // Don't care value
  } alu_op_t;

  typedef enum logic [2:0] {
    RD_ALU,                // ALU
    RD_MEM,                // memory
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
    DC = 'x 
  } reg_t;

  typedef struct packed {
      pcSel_t pcSel;           // what is next pc
      adr_sel_t adrSel;        // select adreess to send to memory
      alu_op_t aluOp;          // which alu opperation
      idu_op_t iduSel;         // which input for idu
      logic iduSub;            // decrement op for idu?
      reg_t rs1;               // which register for rs1
      reg_t rs2;               // which register for rs2
      reg_t rd;                // which register for rd
      logic rdWen;             // reg file write enable
      rd_sel_t rdSel;          // what value is used for rd
      logic done;              // is instruction done
  } ctrl_t;

  typedef enum logic [2:0] {
      NOP,      // nop
      LD_RN,    // r<-n
      LD_RN2,
      LD_RR,    // r<-r'
      BAD = 'x
  } mpc_t;
endpackage