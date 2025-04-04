// updated
// riscvsingle.sv

// RISC-V single-cycle processor
// From Section 7.6 of Digital Design & Computer Architecture
// 27 April 2020
// David_Harris@hmc.edu 
// Sarah.Harris@unlv.edu

// run 210
// Expect simulator to print "Simulation succeeded"
// when the value 25 (0x19) is written to address 100 (0x64)

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

   logic [31:0] WriteData;
   logic [31:0] DataAdr;
   logic        MemWrite;

   // instantiate device to be tested
   top dut(clk, reset, WriteData, DataAdr, MemWrite);

   initial
     begin
	string memfilename;
        memfilename = {"../testing/xori.memfile"};
        $readmemh(memfilename, dut.imem.RAM);
        $readmemh(memfilename, dut.dmem.RAM); // load the memfile into dmem to be able to access the hardcoded constants
     end
// lb success, lbu, lh,lhu, lw
   
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
endmodule // testbench   */

module riscvsingle (input  logic        clk, reset,
		    output logic [31:0] PC,
		    input  logic [31:0] Instr,
		    output logic 	MemWrite,
		    output logic [31:0] ALUResult, WriteData,
		    input  logic [31:0] ReadData,
        output logic MemStrobe,
        input  logic PCReady);
   
   logic 				ALUSrc,ALUSrcA, ALUPC, RegWrite, Jump, Zero, V, C;  //ALUsrcA mux added between regfile and ALU
   logic [1:0] 				ResultSrc;
   logic [2:0]        ImmSrc; // just expanded to allow more immmediate bit distrubution
   // ALUControl was expanded to 4 bits to allow more ALU operations, LoadFunct3 is  is the signal wire that will indicate which type of load operation will be executed
   logic [3:0] 				ALUControl, LoadFunct3, StoreType; // LoadFunct3 is the signal that determines the type of load 
   
   controller c (Instr[6:0], Instr[14:12], Instr[30], Zero, ALUResult[31], V, C, // added N = ALUResult[31]
		 ResultSrc, MemWrite, PCSrc,
		 ALUSrc, ALUSrcA, ALUPC, RegWrite, Jump,
		 ImmSrc, ALUControl, LoadFunct3, StoreType, MemStrobe);
   datapath dp (clk, reset, ResultSrc, PCSrc,
		ALUSrc, ALUSrcA, ALUPC, RegWrite,
		ImmSrc, ALUControl, LoadFunct3, StoreType,
		Zero, V, C, PC, Instr,
		ALUResult, WriteData, ReadData, PCReady);
   
endmodule // riscvsingle

/*  Zero: Set if result is zero.
    N (Negative): Set if result is negative (signed).
    V (Overflow): Set if signed overflow/underflow occurs.
    C (Carry): Set if no borrow occurs (unsigned overflow).
*/
module controller (input  logic [6:0] op,
		   input  logic [2:0] funct3,
		   input  logic       funct7b5,
		   input  logic       Zero, N, V, C, 
		   output logic [1:0] ResultSrc,
		   output logic       MemWrite,
		   output logic       PCSrc, ALUSrc, ALUSrcA, ALUPC,
		   output logic       RegWrite, Jump,
		   output logic [2:0] ImmSrc,
		   output logic [3:0] ALUControl, LoadFunct3, StoreType,
       output logic MemStrobe);
   
   logic [2:0] 			      ALUOp;
   logic 			      Branch, BranchControl;
   
   maindec md (op, ResultSrc, MemWrite, Branch,
	       ALUSrc, ALUSrcA, ALUPC, RegWrite, Jump, ImmSrc, ALUOp, MemStrobe);
   aludec ad (op[5], funct3, funct7b5, ALUOp, ALUControl, LoadFunct3, StoreType);
   
   always_comb begin
     case (funct3)
       3'b000: BranchControl = Zero;      // condition for beq  (checked)
       3'b001: BranchControl = !Zero;     // condition for bne  (checked)
       3'b100: BranchControl = N ^ V ;    // condition for blt  (checked)
       3'b101: BranchControl = !(N ^ V);  // condition for bge  (checked)
       3'b110: BranchControl = !C;        // condition for bltu (checked)
       3'b111: BranchControl = C;         // condition for bgeu (checked)
       default: BranchControl = 1'bx;     // Undefined or error state
     endcase
   end

   assign PCSrc = (Branch & BranchControl) | Jump; // BranchControl adjusts the condition based on the type of branch
   
endmodule // controller

module maindec (input  logic [6:0] op,
		output logic [1:0] ResultSrc, 
		output logic 	   MemWrite,
		output logic 	   Branch, ALUSrc, ALUSrcA, ALUPC, //ALUSrcA signal to indicate mux to choose PC value RD1
		output logic 	   RegWrite, Jump,
		output logic [2:0] ImmSrc,
		output logic [2:0] ALUOp,
    output logic MemStrobe); // ALUOp was expanded to 3 bits to allow more ALU operations
   
   logic [15:0] 		   controls;
   
   assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
	   ResultSrc, Branch, ALUOp, Jump, ALUSrcA, ALUPC, MemStrobe} = controls;
   
   always_comb
     case(op)
       // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump_ALUSrcA_ALUPC_MemStrobe
       7'b0000011: controls = 16'b1_000_1_0_01_0_000_0_0_0_1; // load
       7'b0100011: controls = 16'b0_001_1_1_00_0_000_0_0_0_1; // store
       7'b0110011: controls = 16'b1_xxx_0_0_00_0_010_0_0_0_0; // R–type
       7'b1100011: controls = 16'b0_010_0_0_00_1_001_0_0_0_0; // B- type
       7'b0010011: controls = 16'b1_000_1_0_00_0_010_0_0_0_0; // I–type ALU
       7'b1101111: controls = 16'b1_011_0_0_10_0_000_1_0_0_0; // jal
       7'b0110111: controls = 16'b1_100_1_0_00_0_011_0_0_0_0; // lui
       7'b0010111: controls = 16'b1_100_1_0_00_0_100_0_1_0_0; // auipc
       7'b1100111: controls = 16'b1_000_1_0_10_0_010_0_0_1_0; // jalr
       default:    controls = 16'bx_xxx_x_x_xx_x_xxx_x_x_x_x; // ???
     endcase // case (op)
   
endmodule // maindec

module aludec (input  logic       opb5,
	       input  logic [2:0] funct3,
	       input  logic 	  funct7b5,
	       input  logic [2:0] ALUOp,
	       output logic [3:0] ALUControl, LoadFunct3, StoreType); 
   
   logic 			  RtypeSub;
   
   assign RtypeSub = funct7b5 & opb5; // TRUE for R–type subtract
   always_comb
     case(ALUOp)
       3'b000: ALUControl = 4'b0000; // addition
       3'b001: ALUControl = 4'b0001; // subtraction
       3'b011: ALUControl = 4'b1111; // lui
       3'b100: ALUControl = 4'b1011; // auipc
       default: 
       case(funct3) // R–type or I–type ALU
		     3'b000: if (RtypeSub) 
		             ALUControl = 4'b0001; // sub
		             else
		             ALUControl = 4'b0000; // add, addi
		     3'b010: ALUControl = 4'b0101; // slt, slti
         3'b011: ALUControl = 4'b0110; // sltu (just implemented)	 it worked
		     3'b110: ALUControl = 4'b0011; // or, ori
		     3'b111: ALUControl = 4'b0010; // and, andi
		     3'b100: ALUControl = 4'b0100; // xor, xori	
         3'b001: ALUControl = 4'b0111; // sll, slli (just implemented)	 it worked! 
         3'b101: ALUControl = funct7b5 ? 4'b1001 : 4'b1000; // sra,srai if funct7b5=1, else srl,srli
		    default: ALUControl = 4'bx; // ???
		    endcase // case (funct3)       
     endcase // case (ALUOp)

  /*load operations control unit was added to determine load operation*/
   always_comb //begin
     case (funct3)
       3'b000: LoadFunct3 = 4'b0000;     // lb
       3'b001: LoadFunct3 = 4'b0001;     // lh
       3'b010: LoadFunct3 = 4'b0010;     // lw
       3'b100: LoadFunct3 = 4'b0100;     // lbu
       3'b101: LoadFunct3 = 4'b0101;     // lhu
       default: LoadFunct3 = 4'bx;     // Undefined or error state
     endcase
  // end

  /*store operations control unit was added to determine load operation*/
   always_comb //begin
     case (funct3)
       3'b000: StoreType = 4'b0000;     // sb
       3'b001: StoreType = 4'b0001;     // sh
       3'b010: StoreType = 4'b0010;     // sw
       default: StoreType = 4'bx;     // Undefined or error state
     endcase
  // end
   
endmodule // aludec

module datapath (input  logic        clk, reset,
		 input  logic [1:0]  ResultSrc,
		 input  logic 	     PCSrc, ALUSrc, ALUSrcA, ALUPC,
		 input  logic 	     RegWrite,
		 input  logic [2:0]  ImmSrc,
		 input  logic [3:0]  ALUControl, LoadFunct3, StoreType,
		 output logic 	     Zero, V, C,
		 output logic [31:0] PC,
		 input  logic [31:0] Instr,
		 output logic [31:0] ALUResult, WriteData,
		 input  logic [31:0] ReadData,
     input  logic PCReady);
   
   logic [31:0] 		     PCNext, PCPlus4, PCTarget, NewPCNext;
   logic [31:0] 		     ImmExt;
   logic [31:0] 		     RD1Data, RD2Data, SrcA, SrcB, LoadOut;
   logic [31:0] 		     Result;

   // jalr mux where ALUResult will become the new PC only when ALUPC is high
   mux2 #(32)  jalrmux (PCNext, ALUResult, ALUPC, NewPCNext);
   // next PC logic
   flopenr #(32) pcreg (clk, reset, PCReady, NewPCNext, PC);
   adder  pcadd4 (PC, 32'd4, PCPlus4);
   adder  pcaddbranch (PC, ImmExt, PCTarget);
   mux2 #(32)  pcmux (PCPlus4, PCTarget, PCSrc, PCNext);
   // register file logic
   regfile  rf (clk, RegWrite, Instr[19:15], Instr[24:20],
	       Instr[11:7], Result, RD1Data, RD2Data); // 
   extend  ext (Instr[31:7], ImmSrc, ImmExt);
   // ALU logic
   mux2 #(32)  srcamux (RD1Data, PC, ALUSrcA, SrcA); // new mux added
   mux2 #(32)  srcbmux (RD2Data, ImmExt, ALUSrc, SrcB);
   alu  alu (SrcA, SrcB, ALUControl, ALUResult, Zero, V, C);
   // Load Operation Block 
   load  ld (ReadData, ALUResult[1:0], LoadFunct3, LoadOut); // ALUResult[1:0] is used to select and load the correct byte
   // Store Operation Block
   store st (RD2Data, ReadData, ALUResult[1:0], StoreType, WriteData);
   mux3 #(32) resultmux (ALUResult, LoadOut, PCPlus4,ResultSrc, Result);


endmodule // datapath

module load (
  input  logic [31:0] ReadData,
  input  logic [1:0]  Address,      // lower two bits of ReadData
  input  logic [3:0]  LoadFunct3,
  output logic [31:0] LoadOut);

  // Load operations control unit
  always_comb begin
    case (LoadFunct3)
      4'b0000: begin // lb (load byte) with sign extension
        case (Address)
          2'b00: LoadOut = {{24{ReadData[7]}},  ReadData[7:0]};
          2'b01: LoadOut = {{24{ReadData[15]}}, ReadData[15:8]};
          2'b10: LoadOut = {{24{ReadData[23]}}, ReadData[23:16]};
          2'b11: LoadOut = {{24{ReadData[31]}}, ReadData[31:24]};
          default: LoadOut = 32'bx;
        endcase
      end
      4'b0100: begin // lbu (load byte unsigned)
        case (Address)
          2'b00: LoadOut = {24'b0, ReadData[7:0]};
          2'b01: LoadOut = {24'b0, ReadData[15:8]};
          2'b10: LoadOut = {24'b0, ReadData[23:16]};
          2'b11: LoadOut = {24'b0, ReadData[31:24]};
          default: LoadOut = 32'bx;
        endcase
      end
      4'b0001: begin // lh (load half-word) with sign extension
        case (Address[1])
          1'b0: LoadOut = {{16{ReadData[15]}}, ReadData[15:0]};
          1'b1: LoadOut = {{16{ReadData[31]}}, ReadData[31:16]};
          default: LoadOut = 32'bx;
        endcase
      end
      4'b0101: begin // lhu (load half-word unsigned)
        case (Address[1])
          1'b0: LoadOut = {16'b0, ReadData[15:0]};
          1'b1: LoadOut = {16'b0, ReadData[31:16]};
          default: LoadOut = 32'bx;
        endcase
      end
      4'b0010: LoadOut = ReadData; // lw (load word)    
      default: LoadOut = 32'bx; // Undefined or error state
    endcase
  end

endmodule

module store (input logic[31:0] RD2Data, ReadData,
              input logic [1:0] Address2,
              input logic [3:0] StoreType,
              output logic [31:0] WriteData);

// Load operations control unit
  always_comb begin
    case (StoreType)
      4'b0000: begin // sb (store byte)
        case (Address2)
          2'b00: WriteData = {ReadData[31:8], RD2Data[7:0]};                                  
          2'b01: WriteData = {ReadData[31:16], RD2Data[7:0], ReadData[7:0]};    
          2'b10: WriteData = {ReadData[31:24], RD2Data[7:0], ReadData[15:0]};                     
          2'b11: WriteData = {RD2Data[7:0], ReadData[23:0]};  
        endcase
      end
      4'b0001: begin // sh (store half-word)
        case (Address2[1])
          1'b0: WriteData = {ReadData[31:16], RD2Data[15:0]};
          1'b1: WriteData = {RD2Data[15:0], ReadData[15:0]};
          default: WriteData = 32'bx;
        endcase
      end
      4'b0010: WriteData = RD2Data; // sw (store word)    
      default: WriteData = 32'bx; // Undefined or error state
    endcase
  end

endmodule


module adder (input  logic [31:0] a, b,
	      output logic [31:0] y);
   
   assign y = a + b;
   
endmodule

module extend (input  logic [31:7] instr,
	       input  logic [2:0]  immsrc,
	       output logic [31:0] immext);
   
   always_comb
     case(immsrc)
       // I−type
       3'b000:  immext = {{20{instr[31]}}, instr[31:20]};
       // S−type (stores)
       3'b001:  immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
       // B−type (branches)
       3'b010:  immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};       
       // J−type (jal)
       3'b011:  immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
       // U-type
       3'b100:  immext = {instr[31:12], 12'b0};
       default: immext = 32'bx; // undefined
     endcase // case (immsrc)
   
endmodule // extend

module flopr #(parameter WIDTH = 8)
   (input  logic             clk, reset,
    input logic [WIDTH-1:0]  d,
    output logic [WIDTH-1:0] q);
   
   always_ff @(posedge clk, posedge reset)
     if (reset) q <= 0;
     else  q <= d;
   
endmodule // flopr

module flopenr #(parameter WIDTH = 8)
   (input  logic             clk, reset, en,
    input logic [WIDTH-1:0]  d,
    output logic [WIDTH-1:0] q);
   
   always_ff @(posedge clk, posedge reset)
     if (reset)  q <= 0;
     else if (en) q <= d;
   
endmodule // flopenr

module mux2 #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] d0, d1,
    input logic 	     s,
    output logic [WIDTH-1:0] y);
   
  assign y = s ? d1 : d0;
   
endmodule // mux2


module mux3 #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] d0, d1, d2,
    input logic [1:0] 	     s,
    output logic [WIDTH-1:0] y);
   
  assign y = s[1] ? d2 : (s[0] ? d1 : d0);
   
endmodule // mux3
/*
module top (input  logic        clk, reset,
	    output logic [31:0] WriteData, DataAdr,
	    output logic 	MemWrite);
   
   logic [31:0] 		PC, Instr, ReadData;
   
   // instantiate processor and memories
   riscvsingle rv32single (clk, reset, PC, Instr, MemWrite, DataAdr,
			   WriteData, ReadData);
   imem imem (PC, Instr);
   dmem dmem (clk, MemWrite, DataAdr, WriteData, ReadData);
   
endmodule // top

module imem (input  logic [31:0] a,
	     output logic [31:0] rd);
   
   logic [31:0] 		 RAM[1035:0]; // RAM was expanded to allow all the instructions found in the testing directory
   
   assign rd = RAM[a[31:2]]; // word aligned
   
endmodule // imem

module dmem (input  logic        clk, we,
	     input  logic [31:0] a, wd,
	     output logic [31:0] rd);
   
   logic [31:0] 		 RAM[1035:0];
   
   assign rd = RAM[a[31:2]]; // word aligned
   always_ff @(posedge clk)
     if (we) RAM[a[31:2]] <= wd;
   
endmodule // dmem  */

module alu (input  logic [31:0] a, b,
            input  logic [3:0] 	alucontrol,
            output logic [31:0] result,
            output logic 	zero, V, C);   

   logic [31:0] 	       condinvb, sum;     
   logic [32:0] sum_ext; // 33-bit sum to capture carry     
   logic isAddSub; // true when is add or subtract operation

   assign condinvb = alucontrol[0] ? ~b : b;
  //  assign sum = a + condinvb + alucontrol[0];
   assign sum_ext = {1'b0, a} + {1'b0, condinvb} + alucontrol[0]; // 33-bit addition where MSB is 0
   assign sum = sum_ext[31:0]; // 32-bit result
   assign C = sum_ext[32]; // Carry-out (for unsigned comparisons)

   assign isAddSub = ~alucontrol[2] & ~alucontrol[1] |
                     ~alucontrol[1] & alucontrol[0];   
   always_comb
     case (alucontrol)
       4'b0000:  result = sum;         // add
       4'b0001:  result = sum;         // subtract
       4'b0010:  result = a & b;       // and
       4'b0011:  result = a | b;       // or
       4'b0101:  result = sum[31] ^ V; // slt  
       4'b0110:  result = a < b;       //sltu     
       4'b0100:  result = a ^ b;       // xor
       4'b0111:  result = a << b[4:0]; //sll worked!
       4'b1000:  result = a >> b[4:0]; //srl worked!
       4'b1001:  result = $signed(a) >>> b[4:0]; //sra worked!
       4'b1111:  result = b;           // lui worked!
       4'b1011:  result = a + b; // auipc
       default: result = 32'bx;
     endcase

   assign zero = (result == 32'b0);
   assign V = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;  // V is overflow
   
endmodule // alu

   /* My regfile from lab0 */

module regfile (input logic         clk, 
		input logic 	    we3, // RegWrite
		input logic [4:0]   rs1, rs2, rd, // rs1 (register src1); rs2 (register src2); rd (destination register)
		input logic [31:0]  wd3, // actual data written in register file
		output logic [31:0] rd1, rd2); // rd1 reads rs1 = SrcA; rd2 reads rs2 = SrcB only for R-type operations (when ALUSrc is low)
   
   logic [31:0] 		    rf[31:0];
   
   always_ff @(posedge clk) // This block runs on the rising edge of clk, meaning it updates the registers synchronously.
      if (we3 && rd!=0) rf[rd] <= wd3; // If write enable we3 is high, the register at address wa3 is updated with wd3. If we3 is low, no write occurs.

   assign rd1 = (rs1 == 5'b00000) ? 32'b0 : rf[rs1]; // If ra1 == 0, return 32'b0 (Register 0 always reads as zero). Otherwise, return the value stored in rf[ra1].
   assign rd2 = (rs2 == 5'b00000) ? 32'b0 : rf[rs2]; // If ra2 == 0, return 32'b0 (Register 0 always reads as zero). Otherwise, return the value stored in rf[ra2].
   
endmodule // regfile