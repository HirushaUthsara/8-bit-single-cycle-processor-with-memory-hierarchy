
`timescale  1ns/100ps

module inst_Cache (CLOCK, RESET, BUSYWAIT, PC, INSTRUCTION, BUSYWAIT_instruction_mem, READ_INST, READ_instruction_mem, ADDRESS_instruction_mem);



	// ports between Instruction Cache and Instruction Memory and ports between CPU and Instruction Cache

	input BUSYWAIT_instruction_mem;				// to stall cpu during memory read
	input [127:0] READ_INST;					// instruction fetched from instruction memory
	output reg [5:0] ADDRESS_instruction_mem;	// address for miss to fetch from instruction memory
	output reg READ_instruction_mem;			// read signal control signal for mem
	input CLOCK, RESET;							
	output reg [0:0] BUSYWAIT;					// control signal to stall the cpu
	input [9:0] PC;								// program counter 10 bits (1024 byte addresses)
	output reg [31:0] INSTRUCTION;				// instruction fetched
	


	// instruction cache data array to hold instructions in cache

	reg [127:0] Cache_instruction_block [7:0]; 	// 8 X 128bit = 1024 bytes cache data block storage - one word = 16 bytes
	reg [2:0] Cache_tag_block [7:0];			// 3 bit tag array
	reg Cache_valid_block [7:0];				// valid bit array
	
	// define variables 
	wire [2:0] Tag, Index;
	wire [1:0] Offset;
	reg Valid;
	reg [2:0] Cache_tag;
	reg Hit;
	reg [127:0] Instruction_block_from_cache;	//to store data block which fetched from memory
	reg [31:0] Instruction_from_cache ;			// fectched instruction storage
	


	//Extract offset, Index, Tag from  PC 

	assign Tag = PC[9:7];
	assign Index = PC[6:4];
	assign Offset = PC[3:2];



	//extarcting the informations from the cache storage

	always @(PC, Cache_instruction_block[Index], Cache_valid_block[Index], Cache_tag_block[Index])
	#1 begin
		Instruction_block_from_cache = Cache_instruction_block[Index]; 	//extarct the data block ,valid bit and tag from cache
		Valid = Cache_valid_block[Index];								
		Cache_tag = Cache_tag_block[Index];								
	end
	


	// reset cache to intial state

	integer index;
	always @ (posedge CLOCK)											
	begin
		if (RESET) begin												// write 0 to all blocks
			for (index = 0; index < 8; index++) begin
				Cache_instruction_block [index] = 128'd0;
				Cache_tag_block [index] = 3'dx;
				Cache_valid_block [index] = 1'd0;
			end
		end
	end
	


	// set hit signal

	always @(*) 
	#0.9 begin
		if (Valid && (Tag == Cache_tag)) 								// check whether access is a hit or not
			Hit = 1'b1;
		else begin														//if access is not a hit, set busywait 1
			Hit =1'b0;
			BUSYWAIT = 1'b1;
		end
	end
	


	//extract the required instruction from data block (parrell with the hit signal generating)
	//extract correct data word from the cache based on the offset

	always @(PC, Instruction_block_from_cache)
	begin
		#1 case(Offset) 	
			2'b00: Instruction_from_cache  = Instruction_block_from_cache [31:0];
			2'b01: Instruction_from_cache  = Instruction_block_from_cache [63:32];
			2'b10: Instruction_from_cache  = Instruction_block_from_cache [95:64];
			2'b11: Instruction_from_cache  = Instruction_block_from_cache [127:96];
		endcase
	end
	


	//if access is HIT, then serve the read access and send the instruction to the CPU
	//if the access is HIT, then supply the required data to the CPU

	always @(*)
	begin
		if (Hit) 
			INSTRUCTION = Instruction_from_cache ;
	end
	


	//if access hit then de-aasert the busywait signal at the positve edge of the next clock cycle

	always @(posedge CLOCK, PC)
	begin
		if(Hit)
			BUSYWAIT = 1'b0;
	end
	



	////////////////////////////////////////////////////////////////////////////////////////////////
									/* Cache Controller FSM */	



	parameter IDLE = 3'b000, INSTRUCTION_MEM_READ = 3'b001, Update_Cache = 3'b010;
    reg [2:0] state, next_state;



	// combinational output logic -SIGNALS DEFINES ACCORDING TO EACH OF STATES

	always @(state)
    begin
        case(state)
            IDLE:
            begin														//IDLE state output signals
                ADDRESS_instruction_mem = 6'dx;
                READ_instruction_mem = 1'b0;
            end
         
            INSTRUCTION_MEM_READ: 
            begin														//Mem state output signals
                ADDRESS_instruction_mem = {Tag, Index};
                READ_instruction_mem = 1'b1;
                BUSYWAIT = 1'b1;
            end
			
			Update_Cache:
			begin														//Update_Cache stae output signals
				ADDRESS_instruction_mem = 6'dx;
                READ_instruction_mem = 1'b0;
				#1 begin 												//writing the read data from the instruction memory in to the cache
					Cache_tag_block[Index] = Tag;						//update the TAG
					Cache_valid_block[Index] = 1'b1;					//update the valid bit
					Cache_instruction_block[Index] = READ_INST;			//update the cache entry
				end
			end
		endcase
	end
	


	//State transaction definitions (combinational next state logic)

    always @(*)
    begin
        case (state)
            IDLE:	
				if (!Hit) 												//if access is a miss go to the memory read state
                    next_state = INSTRUCTION_MEM_READ;
                else 													//else stay in the same state
                    next_state = IDLE;
					
			INSTRUCTION_MEM_READ:
				if (!BUSYWAIT_instruction_mem) 							//if memory is done the memory reading then go to cache update state
					next_state = Update_Cache;
				else 													//else stay in the same state
					next_state = INSTRUCTION_MEM_READ;
					
			Update_Cache:
				next_state = IDLE;
		endcase
	end



	//state transaction
	
	always @(posedge CLOCK, posedge RESET)
    begin
        if(RESET)
            state = IDLE;
        else
            state = next_state;
    end

endmodule