`ifndef COMMON_VH
`define COMMON_VH


    `define PE_NUM              12  
    `define PE_NUM_BITS         4
    `define LDM_ADDR_BITS       16

    `define RRI_ADDR_BITS       6      
    `define RES_ADDR_BITS       6      
    
    `define WORD_BITS           16
    `define WORD_BITS_X2        32
    `define ID_BITS             3
    

    `define ALU_CFG_BITS        4       

    `define EXE_ADD             4'b0000 
    `define EXE_SUB             4'b0001 
    `define EXE_ACC             4'b0010 
    `define EXE_ABS_CMP         4'b0011 
    `define EXE_SRA             4'b0100 
    `define EXE_NOP             4'b0101
    `define EXE_MULT            4'b1000 
    `define EXE_MAC             4'b1001 


`endif