

typedef enum logic [2:0] {
    PC_ADD,                 // PC + ?
    PC_DC = 'bx            // Don't care value
} pcSel_t;

typedef enum logic [2:0] {
    ADR_PC,                 // PC
    ADR_DC = 'bx            // Don't care value
} addr_sel_t;

typedef enum logic [2:0] {
    DAT_NOP,                // NOP
    DAT_DC = 'bx            // Don't care value
} data_sel_t;

typedef enum logic [2:0] {
    IDU_PC,                 // PC
    IDU_DC = 'bx            // Don't care value
} idu_op_t;

typedef enum logic [2:0] {
    ALU_RS1,                // return rs1
    ALU_DC = 'bx            // Don't care value
} alu_op_t;

typedef enum logic [2:0] {
  RD_ALU,                // ALU
  RD_NON,                // don't write
  RD_DC = 'bx            // Don't care value
} rd_sel_t;
