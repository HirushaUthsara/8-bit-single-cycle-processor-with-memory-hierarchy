
`include "ALU.v"
`include "RegFile.v"
`timescale  1ns/100ps

//----------CPU module design----------
module cpu(PC, READ, WRITE, ADDRESS, WRITEDATA, READDATA, INSTRUCTION, CLK, RESET, BUSYWAIT);

	//cpu module input and output ports initializing
	input [31:0] INSTRUCTION;
	input CLK, RESET, BUSYWAIT;
	input [7:0] READDATA;
	output [9:0] PC;
	output WRITE, READ;
	output [7:0] ADDRESS, WRITEDATA;
	
	//initializing the PC register
	wire [9:0] PC_NEXT;
	
	//control signals initializing
	wire IMMEDIATE, COMPLEMENT;
	wire [2:0] ALUOP;
	wire J, BEQ, WriteData_Select;
	
	//register file ports initializing
	wire WRITEENABLE;
	wire [2:0] READREG1, READREG2, WRITEREG;
	wire [7:0] REGOUT1, REGOUT2, IN;
	
	//ALU ports initializing
	wire [7:0] DATA2;
	wire [7:0] ALURESULT;
	wire ZERO;
	
	//complement MUX output net initializing
	wire [7:0] COMP_MUX_RESULT;
	
	//REGOUT2 complent value holds the comp_result net
	wire [7:0] comp_result;
	
	//palace to hold the immediate values for *loadi* instruction
	wire [7:0] IMMEDIATE_DATA;
	
	//palace to hold the immediate values for *j* and *beq* instructions
	wire [7:0] IMMEDIATE_OFFSET;
	wire [9:0] PC_OFFSET;
	wire [9:0] PC_Temp;
	
	//instantiating *pc_update* module to update the pc register with one time unit delay
	pc_update pc_up (RESET, CLK, BUSYWAIT, PC_Temp, PC);		
	
	//instantiating pc_addr module to increment the PC value by 4
	pc_addr pc_add (PC, PC_NEXT);	
	
	assign WRITEREG = INSTRUCTION[18:16];
	assign READREG1 = INSTRUCTION[10:8];
	assign READREG2 = INSTRUCTION[2:0]; 	
	assign IMMEDIATE_DATA = INSTRUCTION[7:0];
	assign IMMEDIATE_OFFSET = INSTRUCTION[23:16];
	
	assign WRITEDATA = REGOUT1;
	assign ADDRESS = ALURESULT;
	
	//control signals unit instantiating
	control_signal ctrl_signals (INSTRUCTION, IMMEDIATE, COMPLEMENT, ALUOP, J, BEQ, WRITEENABLE, WRITE, READ, WriteData_Select);
	
	write_data mux (WriteData_Select, ALURESULT, READDATA, IN);
	
	//register file instantiating
	reg_file registers (IN, REGOUT1, REGOUT2, WRITEREG, READREG1, READREG2, WRITEENABLE, CLK, RESET, BUSYWAIT);
	
	//complement_module instantiating
	complement_module comp (REGOUT2, comp_result);
	
	//negative selection mux instantiating
	comp_mux mux1 (COMPLEMENT, REGOUT2, comp_result, COMP_MUX_RESULT);
	
	//immediate value selection mux instantiating
	imme_mux mux2 (IMMEDIATE, IMMEDIATE_DATA, COMP_MUX_RESULT, DATA2);
	
	//alu module instantiating
	alu my_alu (REGOUT1, DATA2, ALURESULT, ZERO, ALUOP);
	
	//imme_offset module instantiating (to add PC with immediate offset value)
	imme_offset pc_offset (IMMEDIATE_OFFSET, PC_NEXT, PC_OFFSET, INSTRUCTION);
	
	//pc_mux module instantiating (to select whether pc+4 or pc+4+offset)
	pc_mux select_pc (J, BEQ, ZERO, PC_NEXT, PC_OFFSET, PC_Temp);
	
endmodule

//mux to select data from aluresult and memory raed data
module write_data (SELECT, ALURESULT, READDATA, IN);

	input SELECT;	//select signal from the cu as a input
	input [7:0] ALURESULT, READDATA;	//input as aluresult and readdata from the data memory
	
	output reg [7:0] IN;	//In as the output of the mux
	
	//mux implementation
	always @(SELECT, READDATA, ALURESULT)
	begin
		if (SELECT)	//if select signal is high assign readdata as the result
			IN = READDATA;
		else //if select is low assign mux output as the aluresult
			IN = ALURESULT;
	end
	
endmodule

//----------PC_Mux Unit module design----------
module pc_mux (J, BEQ, ZERO, PC_Temp, PC_OFFSET, PC_NEXT);
	
	//definning input ports 
	input J, BEQ, ZERO;
	input [9:0] PC_Temp, PC_OFFSET;
	
	//defining output ports
	output reg [9:0] PC_NEXT;
	
	wire and_result, ctrl_mux;
	
	//generating PC_Mux control signal
	and (and_result, BEQ, ZERO);
	or (ctrl_mux, and_result, J);
	
	//PC_Mux implementation
	always @(PC_OFFSET, PC_Temp, ctrl_mux)
	begin
		if(ctrl_mux)
			PC_NEXT = PC_OFFSET;
		else 
			PC_NEXT = PC_Temp;
	end
endmodule

//----------immediate offset Unit module design----------
module imme_offset (IMMEDIATE_OFFSET, PC_NEXT, PC_OFFSET, INSTRUCTION);
	
	//definning input ports
	input [7:0] IMMEDIATE_OFFSET;
	input [9:0] PC_NEXT;
	input [31:0] INSTRUCTION;
	
	//definning output ports
	output reg [9:0] PC_OFFSET;
	
	//variable to hold the sign extended offset
	reg [31:0] sign_extend_OFFSET;
	reg [31:0] PC_OFFSET_32;
	
	//-----Left_Shift by 2 bits to multiply by 4 and Sign Extened to 32 bits-----
	always @(IMMEDIATE_OFFSET)
	begin 
		
		//--Left Shift by 2 bits--
		sign_extend_OFFSET [0] = 1'b0;
		sign_extend_OFFSET [1] = 1'b0;
	
		//--Copying immediate offset to a 32 bit net--
		sign_extend_OFFSET [9:2] = IMMEDIATE_OFFSET[7:0];
	
		//--Sign extending to 32 bits--
		if (IMMEDIATE_OFFSET[7]) //If negative number
			sign_extend_OFFSET[31:10] = 22'b1111_1111_1111_1111_1111_11;
		else
			sign_extend_OFFSET[31:10] = 22'b0000_0000_0000_0000_0000_00; //If positive number
			
	end
	
	//--PC Add with Immediate Offset with 2 time units delay--
	always @(INSTRUCTION)
	#2 begin
		PC_OFFSET_32 = ({22'd0,PC_NEXT} + sign_extend_OFFSET);
		PC_OFFSET = PC_OFFSET_32[9:0];
	end
endmodule

//----------Control Signal Unit module design----------
module control_signal (INSTRUCTION, IMMEDIATE, COMPLEMENT, ALUOP, J, BEQ, WRITEENABLE, WRITE, READ, WriteData_Select);
	
	//get OPCODE as input
	input [31:0] INSTRUCTION;
	
	//Defininig Control Signals as output
	output reg [0:0] IMMEDIATE, COMPLEMENT, J, BEQ, WRITEENABLE, WRITE, READ, WriteData_Select;
	output reg [2:0] ALUOP;
	
	always @ (INSTRUCTION) //always set READ and WRITE signals to low when new instruction has fetched to the cpu
	begin
		WRITE = 1'b0;
		READ = 1'b0;
	end
	
	//decoding triggered with changes of OPCODE
	always @(INSTRUCTION)
	#1 begin		//set delay of one time unit for instruction decoding
		
		//set ALUOP signal according to instructions opcodes
		case (INSTRUCTION[31:24])
			8'd0 : begin
					ALUOP = 3'b001;	//*add* instruction (function - add)
					J = 1'b0;
					BEQ = 1'b0;
					IMMEDIATE = 1'b0;
					COMPLEMENT = 1'b0;
					WRITEENABLE = 1'b1;	//writeenable is high for the *add*
					WRITE = 1'b0;
					READ = 1'b0;
					WriteData_Select = 1'b0;
				   end
			8'd1 : begin 
					ALUOP = 3'b001;	//*sub* instruction (function - add)
					COMPLEMENT = 1'b1;	//complement is set high for the *sub*
					J = 1'b0;
					BEQ = 1'b0;
					IMMEDIATE = 1'b0;
					WRITEENABLE = 1'b1;	//writeenable is high for the *sub*
					WRITE = 1'b0;
					READ = 1'b0;
					WriteData_Select = 1'b0;
				   end
			8'd2 : begin
					ALUOP = 3'b010;	//*and* instruction (function - and)
					J = 1'b0;
					BEQ = 1'b0;
					IMMEDIATE = 1'b0;
					COMPLEMENT = 1'b0;
					WRITEENABLE = 1'b1;	//writeenable is high for the *and*
					WRITE = 1'b0;
					READ = 1'b0;
					WriteData_Select = 1'b0;
				   end
			8'd3 : begin
					ALUOP = 3'b011;	//*or* instruction (function - or)
					J = 1'b0;
					BEQ = 1'b0;
					IMMEDIATE = 1'b0;
					COMPLEMENT = 1'b0;
					WRITEENABLE = 1'b1;	//writeenable is high for the *or*
					WRITE = 1'b0;
					READ = 1'b0;
					WriteData_Select = 1'b0;
				   end
			8'd4 : begin
					ALUOP = 3'b000;	//*mov* instruction (function - forward)
					J = 1'b0;
					BEQ = 1'b0;
					IMMEDIATE = 1'b0;
					COMPLEMENT = 1'b0;
					WRITEENABLE = 1'b1;	//writeenable is high for the *mov*
					WRITE = 1'b0;
					READ = 1'b0;
					WriteData_Select = 1'b0;
				   end
			8'd5 : begin
					ALUOP = 3'b000;	//*loadi* instruction (function - forward)
					IMMEDIATE = 1'b1;	//immediate is set high for the *loadi*
					J = 1'b0;
					BEQ = 1'b0;
					COMPLEMENT = 1'b0;
					WRITEENABLE = 1'b1;	//writeenable is high for the *loadi*
					WRITE = 1'b0;
					READ = 1'b0;
					WriteData_Select = 1'b0;
				   end
			8'd6 : begin
					J = 1'b1;	//if *j* is the instruction output of J is high
					WRITEENABLE = 1'b0;	//WRITEENABLE is set to low for *j* instruction
					BEQ = 1'b0;
					IMMEDIATE = 1'b0;
					COMPLEMENT = 1'b0;
					WRITE = 1'b0;
					READ = 1'b0;
					WriteData_Select = 1'b0;
				   end
			8'd7 : begin
					ALUOP = 3'b001; 	//*beq* instruction (function - add)
					BEQ = 1'b1;		//if *beq* is the instruction output of BEQ is high
					COMPLEMENT = 1'b1;	//complement is set high for the *beq*
					WRITEENABLE = 1'b0;	//WRITEENABLE is set to low for *beq* instruction
					J = 1'b0;
					IMMEDIATE = 1'b0;
					WRITE = 1'b0;
					READ = 1'b0;
					WriteData_Select = 1'b0;
				   end
			8'd8 : begin
					ALUOP = 3'b000; 	//*lwd* instruction (function - forward)
					READ = 1'b1;	//Read signal sets for *lwd*
					WriteData_Select = 1'b1;
					J = 1'b0;
					BEQ = 1'b0;
					IMMEDIATE = 1'b0;
					COMPLEMENT = 1'b0;
					WRITEENABLE = 1'b1;
					WRITE = 1'b0;
				   end
			8'd9 : begin
					ALUOP = 3'b000; 	//*lwi* instruction (function - forward)
					READ = 1'b1;
					WriteData_Select = 1'b1;
					IMMEDIATE = 1'b1;
					J = 1'b0;
					BEQ = 1'b0;
					COMPLEMENT = 1'b0;
					WRITEENABLE = 1'b1;
					WRITE = 1'b0;
				   end
			8'd10 : begin
					ALUOP = 3'b000; 	//*swd* instruction (function - forward)
					WRITE = 1'b1;
					WRITEENABLE = 1'b0;
					J = 1'b0;
					BEQ = 1'b0;
					IMMEDIATE = 1'b0;
					COMPLEMENT = 1'b0;
					READ = 1'b0;
				   end
			8'd11 : begin
					ALUOP = 3'b000; 	//*swi* instruction (function - forward)
					WRITE = 1'b1;
				    IMMEDIATE = 1'b1;
					WRITEENABLE =1'b0;
					J = 1'b0;
					BEQ = 1'b0;
					COMPLEMENT = 1'b0;
					READ = 1'b0;
					WriteData_Select = 1'b0;
				   end
		endcase
		
	end
endmodule

//----------2's Complement module design----------
module complement_module (IN, OUT);

	input [7:0] IN;		//defining IN as input
	output reg [7:0] OUT;	//definnig OUT as output
	
	//take the complement value of IN and then add 1 to it(2's complement operation)
	always @(IN)
	begin
		OUT = #1 (~IN + 8'd1);	//set delay of 1 time unit to get the negative value of IN
	end
endmodule


//----------PC Adder module----------
module pc_addr (CURRENT_PC, NEXT_PC);
	
	input [9:0] CURRENT_PC;	//current pc as the input
	output [9:0] NEXT_PC;		//next_pc as the output (holds next pc value)
	
	//adding $ to the current pc to make the next_pc value
	assign #1 NEXT_PC = CURRENT_PC + 10'd4;
endmodule

//----------PC Update module----------
module pc_update (RESET, CLK, BUSYWAIT, NEXT_PC, CURRENT_PC);

	//RESET, CLOCK and NEXT_PC value asthe input for the module
	input RESET, CLK, BUSYWAIT;
	input [9:0] NEXT_PC;
	
	output reg [9:0] CURRENT_PC; 	//PC_REG as the output for the module
	
	always @(posedge CLK)	//triggered at only the positive edge of the clock
	begin
		if(RESET)		//if reset is high reset pc to zero
			CURRENT_PC = #1 10'b0;
		if(!RESET & !BUSYWAIT)
			#1 CURRENT_PC = NEXT_PC;	//otherwise update the pc value
	end
endmodule

//----------Complement MUX module----------
module comp_mux (COMPLEMENT, REGOUT2, COMP_RESULT, RESULT);
	
	input COMPLEMENT;
	input [7:0] REGOUT2, COMP_RESULT;
	
	output reg [7:0] RESULT;
	
	always @(REGOUT2, COMP_RESULT, COMPLEMENT)
	begin
		if (COMPLEMENT)
			RESULT = COMP_RESULT;		//select 2's complemented value as the output
		else
			RESULT = REGOUT2;		//select non complemented value as the output
	end	
endmodule

//----------IMMEDIATE MUX module----------
module imme_mux (IMMEDIATE, IMMEDIATE_DATA, COMP_MUX_RESULT, RESULT);
	
	input IMMEDIATE;
	input [7:0] IMMEDIATE_DATA, COMP_MUX_RESULT;
	
	output reg [7:0] RESULT;
	
	always @(IMMEDIATE_DATA, COMP_MUX_RESULT, IMMEDIATE)
	begin
		if (IMMEDIATE)
			RESULT = IMMEDIATE_DATA;		//select immediate value for the output
		else
			RESULT = COMP_MUX_RESULT;		//select value from a register as the output
	end	
endmodule