package defs;
  
  typedef enum logic [2:0] {
      PC_ADD,                 // PC + instrSz
      PC_DC = 'x            // Don't care value
  } pcSel_t;

  typedef enum logic [2:0] {
      ADR_PC,                 // PC
      ADR_DC = 'x            // Don't care value
  } addr_sel_t;

  typedef enum logic [2:0] {
      DAT_NOP,                // NOP
      DAT_DC = 'x            // Don't care value
  } data_sel_t;

  typedef enum logic [2:0] {
      IDU_PC,                 // PC
      IDU_DC = 'x            // Don't care value
  } idu_op_t;

  typedef enum logic [2:0] {
      ALU_ADD,                // add
      ALU_DC = 'x            // Don't care value
  } alu_op_t;

  typedef enum logic [2:0] {
    RD_ALU,                // ALU
    RD_N,                  // n
    RD_DC = 'x            // Don't care value
  } rd_sel_t;

  typedef enum logic [2:0] {
    B,
    C,
    D,
    E,
    H,
    L,
    F,
    A,
    DC = 'x 
  } reg_t;

  typedef struct packed {
      pcSel_t pcSel;        // what is next pc
      logic [1:0] instrSz;  // size of intruction (# bytes)
      alu_op_t aluOpM;      // which alu opperation alu in memory stage
      reg_t addr1;          // which register for rs1
      reg_t addr2;          // which register for rs1
      reg_t rdAddr;         // which register for rs1
      logic rdWen;          // reg file write enable
      rd_sel_t rdSel;       // what value is used for rd
  } ctrlD_t;

  typedef struct packed {
      logic [7:0] n;        // immidiate
  } datD_t;

  typedef struct packed {
      pcSel_t pcSel;        // what is next pc
      logic [1:0] instrSz;  // size of intruction (# bytes)
      alu_op_t aluOp;      // which alu opperation alu in memory stage
      reg_t addr1;          // which register for rs1
      reg_t addr2;          // which register for rs1
      reg_t rdAddr;         // which register for rs1
      logic rdWen;          // reg file write enable
      rd_sel_t rdSel;       // what value is used for rd
  } ctrlE_t;

  typedef struct packed {
      logic [7:0] aluOut;        // alu output
      logic [3:0] flg;        // flag
      logic [7:0] n;        // immidiate
  } datE_t;

  typedef struct packed {
      pcSel_t pcSel;        // what is next pc
      logic [1:0] instrSz;  // size of intruction (# bytes)
      alu_op_t aluOp;      // which alu opperation alu in memory stage
      reg_t addr1;          // which register for rs1
      reg_t addr2;          // which register for rs1
      reg_t rdAddr;         // which register for rs1
      logic rdWen;          // reg file write enable
      rd_sel_t rdSel;       // what value is used for rd
  } ctrlM_t;
  
  typedef struct packed {
      logic [7:0] aluOut;        // alu output
      logic [3:0] flg;        // flag
      logic [7:0] n;        // immidiate
  } datM_t;
endpackage