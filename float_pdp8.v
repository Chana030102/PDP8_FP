// Modified for Floating Point Implementation
//
// Verilog ISA model of the PDP-8. 
//
//
//  Copyright(c) 2006 Mark G. Faust
//
//  Mark G. Faust
//  ECE Department
//  Portland State University
//
//
//
// This is a non-synthesizable model of the PDP-8 at the ISA level.  It's based
// upon DEC documentation and an ISPS description by Mario Barbacci.  Neither I//O
// instructions (opcode 6) nor Group 3 Microinstructions (EAE) are supported.
//
//
// A single object file (pdp8.mem) is read in $readmemh() format and simulated
// beginning at location 200 (octal).

// For each instruction type the instruction count is recorded along with the number
// of cycles (which depends upon addressing mode) consumed.
//
// Upon completion, these along with the total number of cycles
// simulated is printed along with the contents of the L, AC registers.
//

// Except for reading the memory image in hex, we will try report/display everything
// in octal since that's the dominant radix used on the PDP-8 (tools, documentation).
//
 

module PDP8();


`define WORD_SIZE 12			// 12-bit word
`define MEM_SIZE  4096			// 4K memory
`define OBJFILENAME "pdp8.mem"	// input file with object code

//
// Processor state (note PDP-8 is a big endian system, bit 0 is MSB)
//


reg [0:`WORD_SIZE-1] PC;		// Program counter
reg [0:`WORD_SIZE-1] IR;		// Instruction Register
reg [0:`WORD_SIZE-1] AC;		// accumulator
reg [0:`WORD_SIZE-1] SR;		// front panel switch register
reg [0:`WORD_SIZE-1] MA;		// memory address register
reg        	      L;			// Link register

reg [0:4]  CPage;				// Current page

reg [0:`WORD_SIZE-1] Mem[0:`MEM_SIZE-1];// 4K memory

reg InterruptsOn;				// not currently used
reg InterruptReq;				// not currently used
reg Run;						// Run while 1

//
// Fields in instruction word
//


`define OpCode		IR[0:2]		// Instruction OpCode
`define IndirectBit	IR[3]		// Indirect Address Bit
`define Page0Bit	IR[4]		// Memory Reference is to Page 0
`define PageAddress	IR[5:11]	// Page Offset


`define extendedOp	IR[9:11] 	// Extended OpCode for IOT
`define [31:0] FPAC			    // Main Floating Point Accumulator
`define [31:0] FPAC2			// FPAC to hold second operand

// Floating Point Accumulator Parts
`define FP_Sign            FPAC[31]
`define FP_Exponent        FPAC[30:23]
`define FP_Mantissa_Up     FPAC[22:12]
`define FP_Mantissa_Lo     FPAC[11:0]

`define FP_Op_Sign         FPAC2[31]
`define FP_Op_Exponent     FPAC2[30:23]
`define fp_op_mantissa_up  FPAC2[22:12]
`define FP_Op_Mantissa_Lo  FPAC2[11:0]

//
// Opcodes
//
parameter
	AND = 0,
	TAD = 1,
	ISZ = 2,
	DCA = 3,
	JMS = 4,
	JMP = 5,
	IOT = 6,
	OPR = 7;

// 
// Extended Opcodes for Floating Point
//
parameter
	FPCLAC = 0,
	FPLOAD = 1,
	FPSTOR = 2,
	FPADD  = 3,
	FPMULT = 4;


//
// Microinstructions
//

`define Group	IR[3]		//  Group = 0 --> Group 1
`define CLA	IR[4]			//  clear AC  (both groups)


//
// Group 1 microinstructions (IR[3] = 0)
//


`define CLL	IR[5]			// clear L
`define CMA	IR[6]			// complement AC
`define CML	IR[7]			// complement L
`define ROT	IR[8:10]		// rotate
`define IAC	IR[11]			// increment AC


//
// Group 2 microinstructions (IR[3] = 1 and IR[11] = 0)
//

`define SMA IR[5]			// skip on minus AC
`define SZA IR[6]			// skip on zero AC
`define SNL IR[7]			// skip on non-zero L
`define SPA IR[5]			// skip on positive AC
`define SNA IR[6]			// skip on non-zero AC
`define SZL IR[7]			// skip on zero L
`define IS  IR[8]			// invert sense of skip
`define OSR IR[9]			// OR with switch register
`define HLT IR[10]			// halt processor


//
// Trace information
//

integer Clocks;
integer TotalClocks;
integer TotalIC;
integer CPI[0:7]; 	// clocks per instruction;
integer IC[0:7];	// instruction count per instruction;
integer i;



task LoadObj;
  begin
  $readmemh(`OBJFILENAME,Mem);
  end
endtask


task Fetch;
  begin
  IR = Mem[PC];
  CPage = PC[0:4];	// Need to maintain this BEFORE PC is incremented for EA calculation
  PC = PC + 1;
  end
endtask


task Execute;
  begin
  case (`OpCode)	
    AND:	begin
			Clocks = Clocks + 2;
			EffectiveAddress(MA);
			AC = AC & Mem[MA];
			end
	
	TAD:	begin
			Clocks = Clocks + 2;
			EffectiveAddress(MA);	
			{L,AC} = {L,AC} + {1'b0,Mem[MA]};
			end
			
	ISZ:	begin
			Clocks = Clocks + 2;
			EffectiveAddress(MA);
			Mem[MA] = Mem[MA] + 1;
			if (Mem[MA] == `WORD_SIZE'o0000)
				PC = PC + 1;
			end
			
	DCA:	begin
			Clocks = Clocks + 2;
			EffectiveAddress(MA);
			Mem[MA] = AC;
			AC = 0;
			end
			
	JMS:	begin
			Clocks = Clocks + 2;
			EffectiveAddress(MA);
			Mem[MA] = PC;
			PC = MA + 1;
			end
			
	JMP:	begin
			Clocks = Clocks + 1;
			EffectiveAddress(PC);
			end
			
	IOT:	begin
			if(IR[3:8] == 55) // if device code 55, floating point operations
				FloatOp;
			else // else, NOP
				$display("IOT instruction at PC = %0o",PC-1," ignored");
			end
			
	OPR:	begin
			Clocks = Clocks + 1;
			Operate;
			end
			
  endcase
  
  CPI[`OpCode] = CPI[`OpCode] + Clocks;
  IC[`OpCode] = IC[`OpCode] + 1;
  end
endtask
 



//
// Compute effective address taking into account indirect and auto-increment.
// Advance Clocks accordingly.  Auto-increment applies to indirect references
// to addresses 10-17 (octal) on page 0.
//
// Note that for auto-increment, this function has the side-effect of incrementing
// memory, so it should be called only once per execute cycle
//
task EffectiveAddress;
  output [0:`WORD_SIZE-1] EA;
  begin
  EA = (`Page0Bit) ? {CPage,`PageAddress} : {5'b00000,`PageAddress};

// $display("CPage = %0o   EA = %0o",CPage,EA);	
  if (`IndirectBit)
	begin
	Clocks = Clocks + 1;
    if (EA[0:8] == 9'b000000001)    // auto-increment
		begin
		$display("                         +   ");
		Clocks = Clocks + 1;
		Mem[EA] = Mem[EA] + 1;
		end
	EA = Mem[EA];
	end
 // $display("EA = %0o",EA);
  end
endtask
  
  
  
//
// Handle microinstructions.  Some of these are done in parallel, some can
// be combined because they're done sequentially.
//
  
  
task Operate;
  begin
	case (`Group)
	  0:										// Group 1 Microinstructions
		begin
		if (`CLA) AC = 0;
		if (`CLL) L = 0;
		
		if (`CMA) AC = ~AC;
		if (`CML) L = ~L;
		
		if (`IAC) {L,AC} = {L,AC} + 1;
		
		case (`ROT)
			0:	;
			1:	{AC[6:11],AC[0:5]} = AC;		// BSW -- byte swap
			2:	{L,AC} = {AC,L};				// RAL -- left shift/rotate 1x
			3:	{L,AC} = {AC[1:11],L,AC[0]};	// RTL -- left shift/rotate 2x
			4:	{L,AC} = {AC[11],L,AC[0:10]};	// RAR -- right shift/rotate 1x
			5:	{L,AC} = {AC[10:11],L,AC[0:9]};	// RTR  -- right shift/rotate 2x
			6:	$display("Unsupported Group 1 microinstruction at PC = %0o",PC-1," ignored");
			7:	$display("Unsupported Group 1 microinstruction at PC = %0o",PC-1," ignored");
		endcase
		end
		
	  1:
		begin
		case (IR[11])
			0:	begin                           // Group 2 Microinstructions
				SkipGroup;
				if (`CLA) AC = 0;
				if (`OSR) AC = AC | SR;
				if (`HLT) Run = 0;
				end
				
			1:	begin							// Group 3 Microinstructions
				$display("Group 3 microinstruction at PC = %0o",PC-1," ignored");
				end
		endcase
		end
		
	endcase
  end
endtask
 
	
	
//
// Handle the Skip Group of microinstructions
//
//
	
	
task SkipGroup;
	reg Skip;
    begin
	case (`IS)			
	  0:	begin		// don't invert sense of skip [OR group]
			Skip = 0;
			if ((`SNL) && (L == 1'b1)) Skip = 1;
			if ((`SZA) && (AC == `WORD_SIZE'b0)) Skip = 1;
			if ((`SMA) && (AC[0] == 1'b1)) Skip = 1;			// less than zero
			end
			
	  1:	begin		// invert sense of skip [AND group]
			Skip = 1;
			if ((`SZL) && !(L == 1'b0)) Skip = 0;
			if ((`SNA) && !(AC != `WORD_SIZE'b0)) Skip = 0;
			if ((`SPA) && !(AC[0] == 1'b0)) Skip = 0;
			end
	endcase
	if (Skip)
		PC = PC + 1;
	end	
 endtask



//
// Dump contents of memory
//

task DumpMemory;
    begin
	for (i=0;i<`MEM_SIZE;i=i+1)
	    if (Mem[i] != 0)
			$display("%0o  %o",i,Mem[i]);
		 	
	end
endtask


//
// Floating Point Operations
//
task FloatOp;
   reg[0:`WORDSIZE-1] temp; 
   reg[0:`WORDSIZE-1] EA;

	begin
	case(`extendedOp)
		FPCLAC: 
			begin
		    FPAC=0;
			end

		FPLOAD:
			begin
			EA = Mem[PC];
			temp = Mem[EA];
			FP_Exponent= temp[4:11];
			
			temp = Mem[EA+1];
			FP_Sign = temp[0];
			FP_Mantissa_Up = temp[1:11];			
			
            temp = Mem[EA+2];
			FP_Mantissa_Lo = temp[0:11];
			PC = PC + 1;
			end

		FPSTOR:
			begin
		    EA = Mem[PC];
            Mem[EA] = {4'b0000, FP_Exponent};
            Mem[EA+1] = {FP_Sign, FP_Mantissa_Up};
            Mem[EA+2] = {FP_Mantissa_Low};
            PC = PC + 1;
			end

		FPADD:
			begin
			$display("Attempted FPADD at PC = %0o",PC-1,"ignored");
            PC = PC + 1;
			end

		FPMULT:
			begin
			$display("Attempted FPMULT at PC = %0o",PC-1,"ignored");
            PC = PC + 1;
			end
	endcase
endtask

// Load second floating point operand
task LoadOperand; 
   reg[0:`WORDSIZE-1] temp; 
   reg[0:`WORDSIZE-1] EA;
    
   begin
   EA = Mem[PC];
   temp = Mem[EA];
   FP_Op_Exponent = temp[4:11];

   temp = Mem[EA+1];
   FP_Op_Sign = temp[0];
   fp_op_mantissa_up = temp[1:11];			

   temp = Mem[EA+2];
   FP_Op_Mantissa_Lo = temp[0:11];
   PC = PC+1;
   end
endtask

initial
  begin
  LoadObj;			    // load memory from object file
  
  DumpMemory;
  
  PC = `WORD_SIZE'o200; // octal 200 start address
  L = 0;			    // initialize accumulator and link
  AC = 0;
  InterruptsOn = 0;
  InterruptReq = 0;
  Run = 1;				// not halted
  
  for (i=0;i<8;i = i + 1)
    begin
    CPI[i] = 0;
    IC[i] = 0;
    end



// $display(" PC L  AC   IR  Op P I + Clocks");
// $display("-------------------------------");

  while (Run)
    begin

    Clocks = 0;
    Fetch;
	
//	$display("%0o %0o %o %o %0o  %0o %0o",PC-1,L,AC,IR,`OpCode,`Page0Bit,`IndirectBit);
	
    Execute;
	
//    $display("                 %d ",Clocks);
	
    if ((InterruptsOn) && (InterruptReq))
	  begin
	  Mem[0] = PC;		// save PC
	  PC = 1;			// jump to interrupt service routine
	  end
    end

//  $display("    %0o %o\n\n",L,AC);
//  DumpMemory;
	
  TotalClocks = 0;
  TotalIC = 0;	
  
  for (i=0;i<8;i = i +1)
	begin
	case (i)
	  AND:  $display("%0d AND instructions executed, using %0d clocks",IC[i],CPI[i]);
	
	  TAD:  $display("%0d TAD instructions executed, using %0d clocks",IC[i],CPI[i]);
	
	  ISZ:	$display("%0d ISZ instructions executed, using %0d clocks",IC[i],CPI[i]);
	
	  DCA:	$display("%0d DCA instructions executed, using %0d clocks",IC[i],CPI[i]);
			
	  JMS:	$display("%0d JSM instructions executed, using %0d clocks",IC[i],CPI[i]);
			
	  JMP:	$display("%0d JMP instructions executed, using %0d clocks",IC[i],CPI[i]);
			
	  IOT:	$display("%0d IOT instructions executed, using %0d clocks",IC[i],CPI[i]);
					
	  OPR:	$display("%0d OPR instructions executed, using %0d clocks",IC[i],CPI[i]);
	endcase

	TotalClocks = TotalClocks + CPI[i];
	TotalIC = TotalIC + IC[i];
	end
  $display("---------------------------------------------------------");
  $display("%0d Total instructions executed, using %0d clocks\n",TotalIC, TotalClocks);
  $display("Average CPI        = %4.2f\n",100.0 * TotalClocks/(TotalIC * 100.0));	
  end


endmodule
