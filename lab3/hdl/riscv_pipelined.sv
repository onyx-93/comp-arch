// riscvpipelined.sv

// RISC-V pipelined processor
// From Section 7.6 of Digital Design & Computer Architecture: RISC-V Edition
// 27 April 2020
// David_Harris@hmc.edu 
// Sarah.Harris@unlv.edu

// run 210
// Expect simulator to print "Simulation succeeded"
// when the value 25 (0x19) is written to address 100 (0x64)

// Pipelined implementation of RISC-V (RV32I)
// User-level Instruction Set Architecture V2.2 (May 7, 2017)
// Implements a subset of the base integer instructions:
//    lw, sw
//    add, sub, and, or, slt, 
//    addi, andi, ori, slti
//    beq
//    jal
// Exceptions, traps, and interrupts not implemented
// little-endian memory

// 31 32-bit registers x1-x31, x0 hardwired to 0
// R-Type instructions
//   add, sub, and, or, slt
//   INSTR rd, rs1, rs2
//   Instr[31:25] = funct7 (funct7b5 & opb5 = 1 for sub, 0 for others)
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode
// I-Type Instructions
//   lw, I-type ALU (addi, andi, ori, slti)
//   lw:         INSTR rd, imm(rs1)
//   I-type ALU: INSTR rd, rs1, imm (12-bit signed)
//   Instr[31:20] = imm[11:0]
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode
// S-Type Instruction
//   sw rs2, imm(rs1) (store rs2 into address specified by rs1 + immm)
//   Instr[31:25] = imm[11:5] (offset[11:5])
//   Instr[24:20] = rs2 (src)
//   Instr[19:15] = rs1 (base)
//   Instr[14:12] = funct3
//   Instr[11:7]  = imm[4:0]  (offset[4:0])
//   Instr[6:0]   = opcode
// B-Type Instruction
//   beq rs1, rs2, imm (PCTarget = PC + (signed imm x 2))
//   Instr[31:25] = imm[12], imm[10:5]
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = imm[4:1], imm[11]
//   Instr[6:0]   = opcode
// J-Type Instruction
//   jal rd, imm  (signed imm is multiplied by 2 and added to PC, rd = PC+4)
//   Instr[31:12] = imm[20], imm[10:1], imm[11], imm[19:12]
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode

//   Instruction  opcode    funct3    funct7
//   add          0110011   000       0000000
//   sub          0110011   000       0100000
//   and          0110011   111       0000000
//   or           0110011   110       0000000
//   slt          0110011   010       0000000
//   addi         0010011   000       immediate
//   andi         0010011   111       immediate
//   ori          0010011   110       immediate
//   slti         0010011   010       immediate
//   beq          1100011   000       immediate
//   lw	          0000011   010       immediate
//   sw           0100011   010       immediate
//   jal          1101111   immediate immediate

/*
module testbench();

   logic        clk;
   logic        reset;

   logic [31:0] WriteData, DataAdr;
   logic        MemWrite;

   // instantiate device to be tested
   top dut(clk, reset, WriteData, DataAdr, MemWrite);

   initial
     begin
	string memfilename;
        memfilename = {"../testing/sh.memfile"};
	$readmemh(memfilename, dut.imem.RAM);
  $readmemh(memfilename, dut.dmem.RAM); // load the memfile into dmem to be able to access the hardcoded constants
     end
   
   // initialize test
   initial
     begin
	reset <= 1; # 22; reset <= 0;
     end

   // generate clock to sequence tests
   always
     begin
	clk <= 1; # 5; clk <= 0; # 5;
     end

   // check results
   always @(negedge clk)
     begin
	if(MemWrite) begin
           if(DataAdr === 100 & WriteData === 10) begin
              $display("Simulation succeeded");
           end else if (DataAdr ===100 & WriteData === 17) begin
              $display("Simulation failed");
           end
	end
     end
endmodule     

module top(input  logic        clk, reset, 
           output logic [31:0] WriteDataM, DataAdrM, 
           output logic        MemWriteM);

   logic [31:0] 	       PCF, InstrF, ReadDataM;
   
   // instantiate processor and memories
   riscv rv32pipe (clk, reset, PCF, InstrF, MemWriteM, DataAdrM, 
		   WriteDataM, ReadDataM);
   imem imem (PCF, InstrF);
   dmem dmem (clk, MemWriteM, DataAdrM, WriteDataM, ReadDataM);
   
endmodule     */

module riscv(input  logic        clk, reset,
             output logic [31:0] PCF,
             input logic [31:0]  InstrF,
             input logic PCReadyF,
             output logic 	 MemWriteM,
             output logic [31:0] ALUResultM, WriteDataM,
             input logic [31:0]  ReadDataM,
             output logic MemStrobeM);

   logic [6:0] 			 opD;
   logic [2:0] 			 funct3D;
   logic 			 funct7b5D;
  //  logic       MemStrobeD;
   logic [2:0] 			 ImmSrcD;
   logic 			 ZeroE, vE, nE, carryE;
   logic 			 PCSrcE;
   logic [3:0] 			 ALUControlE;
   logic [2:0] LoadTypeW, StoreTypeM;      // signal to trigger a specific load instruction
   logic 			 ALUSrcE, ALUSrcAE;
   logic 			 ResultSrcEb0;
   logic 			 RegWriteM;
   logic [1:0] 			 ResultSrcW;
   logic 			 RegWriteW, jalrSrcE;

   logic [1:0] 			 ForwardAE, ForwardBE;
   logic 			 StallF, StallD, FlushD, FlushE;

   logic [4:0] 			 Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW;
   
   controller c(clk, reset,
		opD, funct3D, funct7b5D, ImmSrcD,
		FlushE, ZeroE, vE, nE, carryE, PCSrcE, ALUControlE, jalrSrcE, ALUSrcE, ALUSrcAE, ResultSrcEb0,
		MemWriteM, RegWriteM, StoreTypeM, MemStrobeM,
		RegWriteW, ResultSrcW, LoadTypeW);

   datapath dp(clk, reset,
               StallF, PCF, InstrF, PCReadyF,
	       opD, funct3D, funct7b5D, StallD, FlushD, ImmSrcD,
	       FlushE, ForwardAE, ForwardBE, PCSrcE, ALUControlE, jalrSrcE, ALUSrcE, ALUSrcAE, ZeroE, vE, nE, carryE,
               MemWriteM, WriteDataM, ALUResultM, ReadDataM, StoreTypeM,
               RegWriteW, ResultSrcW, LoadTypeW,
               Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW);

   hazard  hu(Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
              PCSrcE, ResultSrcEb0, RegWriteM, RegWriteW,
              ForwardAE, ForwardBE, StallF, StallD, FlushD, FlushE);			 
endmodule


module controller(input  logic		 clk, reset,
                  // Decode stage control signals
                  input logic [6:0]  opD,
                  input logic [2:0]  funct3D,
                  input logic 	     funct7b5D,
                  output logic [2:0] ImmSrcD,
                  // Execute stage control signals
                  input logic 	     FlushE, 
                  input logic 	     ZeroE, vE, nE, carryE, 
                  output logic 	     PCSrcE, // for datapath and Hazard Unit
                  output logic [3:0] ALUControlE,
                  output logic       jalrSrcE, 
                  output logic 	     ALUSrcE, ALUSrcAE,
                  output logic 	     ResultSrcEb0, // for Hazard Unit
                  // Memory stage control signals
                  output logic 	     MemWriteM,
                  output logic 	     RegWriteM, // for Hazard Unit	
                  output logic [2:0] StoreTypeM,
                  output logic MemStrobeM,			  
                  // Writeback stage control signals
                  output logic 	     RegWriteW, // for datapath and Hazard Unit
                  output logic [1:0] ResultSrcW,
                  output logic [2:0] LoadTypeW);

   // pipelined control signals
   logic 			     RegWriteD, RegWriteE;
   logic [1:0] 			     ResultSrcD, ResultSrcE, ResultSrcM;
   logic 			     MemWriteD, MemWriteE;
   logic 			     JumpD, JumpE, BranchCtrl;
   logic 			     BranchD, BranchE;
   logic [2:0] 			     ALUOpD, funct3E;
   logic [3:0] 			     ALUControlD;
   logic 			     ALUSrcD, ALUSrcAD;
   logic            jalrSrcD;
   logic [2:0]     LoadTypeD, LoadTypeE, LoadTypeM, StoreTypeD, StoreTypeE;
   logic MemStrobeD, MemStrobeE;
   
   // Combinational logic for branching instructions
  always_comb begin
    case(funct3E)
    3'b000: BranchCtrl = ZeroE; // Beq
    3'b001: BranchCtrl = ~ZeroE; // Bne
    3'b101: BranchCtrl = ~(nE ^ vE); // Bge
    3'b111: BranchCtrl = carryE; // Bgeu
    3'b100: BranchCtrl = nE ^ vE; // Blt
    3'b110: BranchCtrl = ~carryE; //Bltu
    default: BranchCtrl = 1'bx;
    endcase
  end

   // Decode stage logic
   maindec md(opD, ResultSrcD, MemWriteD, BranchD,
              ALUSrcD, ALUSrcAD, jalrSrcD, RegWriteD, JumpD, ImmSrcD, ALUOpD, MemStrobeD);
   aludec  ad(opD[5], funct3D, funct7b5D, ALUOpD, ALUControlD, LoadTypeD, StoreTypeD);
   
   // Execute stage pipeline control register and logic
   floprc #(23) controlregE(clk, reset, FlushE,
                            {RegWriteD, ResultSrcD, MemWriteD, JumpD, BranchD, ALUControlD, ALUSrcD, ALUSrcAD, funct3D, jalrSrcD, LoadTypeD, StoreTypeD, MemStrobeD},
                            {RegWriteE, ResultSrcE, MemWriteE, JumpE, BranchE, ALUControlE, ALUSrcE, ALUSrcAE, funct3E, jalrSrcE, LoadTypeE, StoreTypeE, MemStrobeE});

   //assign PCSrcE = (BranchE & ZeroE) | JumpE; // Previous branching logic
   assign PCSrcE = (BranchE & BranchCtrl) | JumpE; // New branching logic
   assign ResultSrcEb0 = ResultSrcE[0];
   
   // Memory stage pipeline control register
   flopr #(11) controlregM(clk, reset,
                          {RegWriteE, ResultSrcE, MemWriteE, LoadTypeE, StoreTypeE, MemStrobeE},
                          {RegWriteM, ResultSrcM, MemWriteM, LoadTypeM, StoreTypeM, MemStrobeM});
   
   // Writeback stage pipeline control register
   flopr #(6) controlregW(clk, reset,
                          {RegWriteM, ResultSrcM, LoadTypeM},
                          {RegWriteW, ResultSrcW, LoadTypeW});     
endmodule

module maindec(input  logic [6:0] op,
               output logic [1:0] ResultSrc,
               output logic 	  MemWrite,
               output logic 	  Branch, ALUSrc, ALUSrcAE, jalrSrcD,
               output logic 	  RegWrite, Jump,
               output logic [2:0] ImmSrc,
               output logic [2:0] ALUOp, 
               output logic MemStrobeD);

   logic [15:0] 		  controls;

   assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
           ResultSrc, Branch, ALUOp, Jump, ALUSrcAE, jalrSrcD, MemStrobeD} = controls;
    /* control implemented in lab2:
    //  7'b0110111: controls = 16'b1_100_1_0_00_0_011_0_0_0_0; // lui
    */
   always_comb
     case(op)
       // RegWrite_ImmSrc_ALUSrcB_MemWrite_ResultSrc_Branch_ALUOp_Jump_ALUSrcAE(auipc)_jalrSrc
       7'b0100011: controls = 16'b0_001_1_1_00_0_000_0_0_0_1; // sw
       7'b0000011: controls = 16'b1_000_1_0_01_0_000_0_0_0_1; // lw
       7'b0110011: controls = 16'b1_xxx_0_0_00_0_010_0_0_0_0; // R-type 
       7'b1100011: controls = 16'b0_010_0_0_00_1_001_0_0_0_0; // beq
       7'b0010011: controls = 16'b1_000_1_0_00_0_010_0_0_0_0; // I-type ALU
       7'b1101111: controls = 16'b1_011_0_0_10_0_000_1_0_0_0; // jal
       7'b0110111: controls = 16'b1_100_1_0_00_0_011_0_0_0_0; // lui
       7'b0010111: controls = 16'b1_100_1_0_00_0_100_0_1_0_0; // auipc
       7'b1100111: controls = 16'b1_000_1_0_10_0_010_1_0_1_0; // jalr
       7'b0000000: controls = 16'b0_000_0_0_00_0_000_0_0_0_0; // need valid values at reset
       default:    controls = 16'bx_xxx_x_x_xx_x_xxx_x_x_x_x; // non-implemented instruction
     endcase
endmodule

module aludec(input  logic       opb5,
              input logic [2:0]  funct3,
              input logic 	 funct7b5, 
              input logic [2:0]  ALUOp,
              output logic [3:0] ALUControl,
              output logic [2:0] LoadTypeD, StoreTypeD);

   logic 			 RtypeSub;
   assign RtypeSub = funct7b5 & opb5;  // TRUE for R-type subtract instruction

   always_comb
     case(ALUOp)
       3'b000: ALUControl = 4'b0000; // addition
       3'b001: ALUControl = 4'b0001; // subtraction
       3'b011: ALUControl = 4'b1111; // lui
       3'b100: ALUControl = 4'b1011; // auipc
       default: case(funct3) // R-type or I-type ALU
                  3'b000:  if (RtypeSub) 
                    ALUControl = 4'b0001; // sub
                  else          
                    ALUControl = 4'b0000; // add, addi
		                3'b010: ALUControl = 4'b0101; // slt, slti
                    3'b011: ALUControl = 4'b0110; // sltu (just implemented)	 it worked
		                3'b110: ALUControl = 4'b0011; // or, ori
		                3'b111: ALUControl = 4'b0010; // and, andi
		                3'b100: ALUControl = 4'b0100; // xor, xori	
                    3'b001: ALUControl = 4'b0111; // sll, slli (just implemented)	 it worked! 
                    3'b101: ALUControl = funct7b5 ? 4'b1001 : 4'b1000; // sra,srai if funct7b5 = 1, else srl,srli
                  default:   ALUControl = 4'bxxxx; // ???
		endcase
     endcase
     
    /*load operations control unit was added to determine load operation*/
   always_comb
     case (funct3)
       3'b000: LoadTypeD = 3'b000;     // lb
       3'b001: LoadTypeD = 3'b001;     // lh
       3'b010: LoadTypeD = 3'b010;     // lw
       3'b100: LoadTypeD = 3'b100;     // lbu0
       3'b101: LoadTypeD = 3'b101;     // lhu
      default: LoadTypeD = 3'bx;     // Undefined or error state
     endcase

  //store operations control unit was added to determine load operation
   always_comb 
     case (funct3)
       3'b000: StoreTypeD = 3'b000;     // sb
       3'b001: StoreTypeD = 3'b001;     // sh
       3'b010: StoreTypeD = 3'b010;     // sw
      default: StoreTypeD = 3'bx;     // Undefined or error state
     endcase 

endmodule

module datapath(input logic clk, reset,
                // Fetch stage signals
                input logic 	    StallF,
                output logic [31:0] PCF,
                input logic [31:0]  InstrF,
                input logic PCReadyF,
                // Decode stage signals
                output logic [6:0]  opD,
                output logic [2:0]  funct3D, 
                output logic 	    funct7b5D,
                input logic 	    StallD, FlushD,
                input logic [2:0]   ImmSrcD,
                // Execute stage signals
                input logic 	    FlushE,
                input logic [1:0]   ForwardAE, ForwardBE,
                input logic 	    PCSrcE,
                input logic [3:0]   ALUControlE,
                input logic jalrSrcE,
                input logic 	    ALUSrcE, ALUSrcAE,
                output logic 	    ZeroE, vE, nE, carryE,
                // Memory stage signals
                input logic 	    MemWriteM, 
                output logic [31:0] WriteDataM, ALUResultM,
                input logic [31:0]  ReadDataM,
                input logic [2:0]  StoreTypeM,
                // Writeback stage signals
                input logic 	    RegWriteW, 
                input logic [1:0]   ResultSrcW,
                input logic [2:0] LoadTypeW,
                // Hazard Unit signals 
                output logic [4:0]  Rs1D, Rs2D, Rs1E, Rs2E,
                output logic [4:0]  RdE, RdM, RdW);

   // Fetch stage signals
   logic [31:0] 		    PCNextF, PCPlus4F, NewPCF;
   logic NewPCReadyF;
   // Decode stage signals
   logic [31:0] 		    InstrD;
   logic [31:0] 		    PCD, PCPlus4D;
   logic [31:0] 		    RD1D, RD2D;
   logic [31:0] 		    ImmExtD;
   logic [4:0] 			    RdD;
   // Execute stage signals
   logic [31:0] 		    RD1E, RD2E;
   logic [31:0] 		    PCE, ImmExtE;
   logic [31:0] 		    SrcAE, SrcBE;
   logic [31:0]         NewSrcA; // New output for auipc mux
   logic [31:0] 		    ALUResultE;
   logic [31:0] 		    WriteDataE;
   logic [31:0] 		    PCPlus4E;
   logic [31:0] 		    PCTargetE;
   // Memory stage signals
   logic [31:0] 		    PCPlus4M, RD2M;
   // Writeback stage signals
   logic [31:0] 		    ALUResultW;
   logic [31:0] 		    ReadDataW;
   logic [31:0] 		    PCPlus4W;
   logic [31:0] 		    ResultW;
   logic [31:0]         LoadOutW;

   // Fetch stage pipeline register and logic
   mux2    #(32) pcmux(PCPlus4F, PCTargetE, PCSrcE, PCNextF);
   mux2    #(32) jalrmux(PCNextF, ALUResultE, jalrSrcE, NewPCF);
   assign NewPCReadyF = (PCReadyF | ~StallF);
   flopenr #(32) pcreg(clk, reset, NewPCReadyF, NewPCF, PCF);
   adder         pcadd(PCF, 32'h4, PCPlus4F);
   // Decode stage pipeline register and logic
   flopenrc #(96) regD(clk, reset, FlushD, ~StallD, 
                       {InstrF, PCF, PCPlus4F},
                       {InstrD, PCD, PCPlus4D});
   assign opD       = InstrD[6:0];
   assign funct3D   = InstrD[14:12];
   assign funct7b5D = InstrD[30];
   assign Rs1D      = InstrD[19:15];
   assign Rs2D      = InstrD[24:20];
   assign RdD       = InstrD[11:7];
   
   regfile        rf(clk, RegWriteW, Rs1D, Rs2D, RdW, ResultW, RD1D, RD2D);
   extend         ext(InstrD[31:7], ImmSrcD, ImmExtD);
   
   // Execute stage pipeline register and logic
   floprc #(175) regE(clk, reset, FlushE, 
                      {RD1D, RD2D, PCD, Rs1D, Rs2D, RdD, ImmExtD, PCPlus4D}, 
                      {RD1E, RD2E, PCE, Rs1E, Rs2E, RdE, ImmExtE, PCPlus4E});
   
   mux3   #(32)  faemux(RD1E, ResultW, ALUResultM, ForwardAE, SrcAE);
   mux3   #(32)  fbemux(RD2E, ResultW, ALUResultM, ForwardBE, WriteDataE);
   mux2   #(32)  srcbmux(WriteDataE, ImmExtE, ALUSrcE, SrcBE);
   mux2   #(32)  SrcAMux(SrcAE, PCE, ALUSrcAE, NewSrcA);
  //  alu           alu(NewSrcA, SrcBE, ALUControlE, ALUResultE, ZeroE);
  //  mux2   #(32)  SrcAMux(SrcAE, PCE, ALUSrcAE, NewSrcA);
   alu           alu(NewSrcA, SrcBE, ALUControlE, ALUResultE, ZeroE, vE, nE, carryE);
   adder         branchadd(ImmExtE, PCE, PCTargetE);

   // Memory stage pipeline register
   flopr  #(101) regM(clk, reset, 
                      {ALUResultE, WriteDataE, RdE, PCPlus4E},
                      {ALUResultM, RD2M, RdM, PCPlus4M});
   store st (RD2M, ReadDataM, ALUResultM[1:0], StoreTypeM, WriteDataM); // M stage
   
   // Writeback stage pipeline register and logic
   flopr  #(101) regW(clk, reset, 
                      {ALUResultM, ReadDataM, RdM, PCPlus4M},
                      {ALUResultW, ReadDataW, RdW, PCPlus4W});
   load  ld (ReadDataW, ALUResultW[1:0], LoadTypeW, LoadOutW); // ALUResult[1:0] is used to select and load the correct byte
   mux3   #(32)  resultmux(ALUResultW, LoadOutW, PCPlus4W, ResultSrcW, ResultW);	
endmodule

// Hazard Unit: forward, stall, and flush
module hazard(input  logic [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
              input logic 	 PCSrcE, ResultSrcEb0, 
              input logic 	 RegWriteM, RegWriteW,
              output logic [1:0] ForwardAE, ForwardBE,
              output logic 	 StallF, StallD, FlushD, FlushE);

   logic 			 lwStallD;
   
   // forwarding logic
   always_comb begin
      ForwardAE = 2'b00;
      ForwardBE = 2'b00;
      if (Rs1E != 5'b0)
	if      ((Rs1E == RdM) & RegWriteM) ForwardAE = 2'b10;
	else if ((Rs1E == RdW) & RegWriteW) ForwardAE = 2'b01;
      
      if (Rs2E != 5'b0)
	if      ((Rs2E == RdM) & RegWriteM) ForwardBE = 2'b10;
	else if ((Rs2E == RdW) & RegWriteW) ForwardBE = 2'b01;
   end
   
   // stalls and flushes
   assign lwStallD = ResultSrcEb0 & ((Rs1D == RdE) | (Rs2D == RdE));  
   assign StallD = lwStallD;
   assign StallF = lwStallD;
   assign FlushD = PCSrcE;
   assign FlushE = lwStallD | PCSrcE;
endmodule

module load ( input  logic [31:0] ReadDataW,
              input  logic [1:0]  AddressW,      // lower two bits of ReadData
              input  logic [2:0]  LoadTypeW,
              output logic [31:0] LoadOutW);

  // Load operations control unit
  always_comb begin
    case (LoadTypeW)
      3'b000: begin // lb (load byte) with sign extension
        case (AddressW)
          2'b00: LoadOutW = {{24{ReadDataW[7]}},  ReadDataW[7:0]};
          2'b01: LoadOutW = {{24{ReadDataW[15]}}, ReadDataW[15:8]};
          2'b10: LoadOutW = {{24{ReadDataW[23]}}, ReadDataW[23:16]};
          2'b11: LoadOutW = {{24{ReadDataW[31]}}, ReadDataW[31:24]};
          default: LoadOutW = 32'bx;
        endcase
      end
      3'b100: begin // lbu (load byte unsigned)
        case (AddressW)
          2'b00: LoadOutW = {24'b0, ReadDataW[7:0]};
          2'b01: LoadOutW = {24'b0, ReadDataW[15:8]};
          2'b10: LoadOutW = {24'b0, ReadDataW[23:16]};
          2'b11: LoadOutW = {24'b0, ReadDataW[31:24]};
          default: LoadOutW = 32'bx;
        endcase
      end
      3'b001: begin // lh (load half-word) with sign extension
        case (AddressW[1])
          1'b0: LoadOutW = {{16{ReadDataW[15]}}, ReadDataW[15:0]};
          1'b1: LoadOutW = {{16{ReadDataW[31]}}, ReadDataW[31:16]};
          default: LoadOutW = 32'bx;
        endcase
      end
      3'b101: begin // lhu (load half-word unsigned)
        case (AddressW[1])
          1'b0: LoadOutW = {16'b0, ReadDataW[15:0]};
          1'b1: LoadOutW = {16'b0, ReadDataW[31:16]};
          default: LoadOutW = 32'bx;
        endcase
      end
      3'b010: LoadOutW = ReadDataW; // lw (load word)    
      default: LoadOutW = 32'bx; // Undefined or error state
    endcase
  end

endmodule


module store (input logic[31:0] RD2M, ReadDataM,
              input logic [1:0] AddressM,
              input logic [2:0] StoreTypeM,
              output logic [31:0] WriteDataM);

// Load operations control unit
  always_comb begin
    case (StoreTypeM)
      3'b000: begin // sb (store byte)
        case (AddressM)
          2'b00: WriteDataM = {ReadDataM[31:8], RD2M[7:0]};                                  
          2'b01: WriteDataM = {ReadDataM[31:16], RD2M[7:0], ReadDataM[7:0]};    
          2'b10: WriteDataM = {ReadDataM[31:24], RD2M[7:0], ReadDataM[15:0]};                     
          2'b11: WriteDataM = {RD2M[7:0], ReadDataM[23:0]};
          default: WriteDataM = 32'bx;  
        endcase
      end
      3'b001: begin // sh (store half-word)
        case (AddressM[1])
          1'b0: WriteDataM = {ReadDataM[31:16], RD2M[15:0]};
          1'b1: WriteDataM = {RD2M[15:0], ReadDataM[15:0]};
          default: WriteDataM = 32'bx;
        endcase
      end
      3'b010:  WriteDataM = RD2M; // sw (store word)    
      default: WriteDataM = 32'bx; // Undefined or error state
    endcase
  end

endmodule

module regfile(input  logic        clk, 
               input logic 	   we3, 
               input logic [ 4:0]  a1, a2, a3, 
               input logic [31:0]  wd3, 
               output logic [31:0] rd1, rd2);

   logic [31:0] 		   rf[31:0];

   // three ported register file
   // read two ports combinationally (A1/RD1, A2/RD2)
   // write third port on rising edge of clock (A3/WD3/WE3)
   // write occurs on falling edge of clock
   // register 0 hardwired to 0

   always_ff @(negedge clk)
     if (we3) rf[a3] <= wd3;	

   assign rd1 = (a1 != 0) ? rf[a1] : 0;
   assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule // regfile

module adder(input  [31:0] a, b,
             output [31:0] y);

   assign y = a + b;
endmodule

module extend(input  logic [31:7] instr,
              input logic [2:0]   immsrc,
              output logic [31:0] immext);
   
   always_comb
     case(immsrc) 
       // I-type 
       3'b000:   immext = {{20{instr[31]}}, instr[31:20]};  
       // S-type (stores)
       3'b001:   immext = {{20{instr[31]}}, instr[31:25], instr[11:7]}; 
       // B-type (branches)
       3'b010:   immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; 
       // J-type (jal)
       3'b011:   immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; 
       // U-type
       3'b100:  immext = {instr[31:12], 12'b0};
       default: immext = 32'bx; // undefined
     endcase             
endmodule

module flopr #(parameter WIDTH = 8)
   (input  logic             clk, reset,
    input logic [WIDTH-1:0]  d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset) q <= 0;
     else       q <= d;
endmodule

module flopenr #(parameter WIDTH = 8)
   (input  logic             clk, reset, en,
    input logic [WIDTH-1:0]  d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset)   q <= 0;
     else if (en) q <= d;
endmodule

module flopenrc #(parameter WIDTH = 8)
   (input  logic             clk, reset, clear, en,
    input logic [WIDTH-1:0]  d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset)   q <= 0;
     else if (en) 
       if (clear) q <= 0;
       else       q <= d;
endmodule

module floprc #(parameter WIDTH = 8)
   (input  logic clk,
    input logic 	     reset,
    input logic 	     clear,
    input logic [WIDTH-1:0]  d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset) q <= 0;
     else       
       if (clear) q <= 0;
       else       q <= d;
endmodule

module mux2 #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] d0, d1, 
    input logic 	     s, 
    output logic [WIDTH-1:0] y);

   assign y = s ? d1 : d0; 
endmodule

module mux3 #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] d0, d1, d2,
    input logic [1:0] 	     s, 
    output logic [WIDTH-1:0] y);

   assign y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule
/*
module imem (input  logic [31:0] a,
	     output logic [31:0] rd);
   
   logic [31:0] 		 RAM[1035:0];
   
   assign rd = RAM[a[31:2]]; // word aligned
   
endmodule // imem

module dmem (input  logic        clk, we,
	     input  logic [31:0] a, wd,
	     output logic [31:0] rd);
   
   logic [31:0] 		 RAM[1035:0];
   
   assign rd = RAM[a[31:2]]; // word aligned
   always_ff @(posedge clk)
     if (we) RAM[a[31:2]] <= wd;
   
endmodule // dmem */

module alu(input  logic [31:0] a, b,
           input logic [3:0]   alucontrol,
           output logic [31:0] result,
           output logic        zero, v, n, carry);

   logic [31:0] 	       condinvb;
   logic [32:0]          sum;
  //  logic 		       v;              // overflow
   logic 		       isAddSub;       // true when is add or sub

   assign condinvb = alucontrol[0] ? ~b : b;
   assign sum = a + condinvb + alucontrol[0];
   assign isAddSub = ~alucontrol[2] & ~alucontrol[1] |
                     ~alucontrol[1] &  alucontrol[0];

   always_comb
     case (alucontrol)
       4'b0000:  result = sum;         // add worked*
       4'b0001:  result = sum;         // sub worked*
       4'b0010:  result = a & b;       // and worked*
       4'b0011:  result = a | b;       // or worked*
       4'b0101:  result = sum[31] ^ v; // slt worked* 
       4'b0110:  result = a < b;       //sltu and sltiu worked*    
       4'b0100:  result = a ^ b;       // xor worked*
       4'b0111:  result = a << b[4:0]; //sll worked!*
       4'b1000:  result = a >> b[4:0]; //srl 
       4'b1001:  result = $signed(a) >>> b[4:0]; //sra worked!*
       4'b1111:  result = b;           // lui
       4'b1011:  result = a + b; // auipc
       default: result = 32'bx;
     endcase

   assign zero = (result == 32'b0);
   assign v = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;
   assign carry = sum[32]; // carry flag
   assign n = result[31]; // Flag for negative result
   
endmodule

