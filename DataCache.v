
/*
Date 		- 03.03.2022
Author 		- Group 11
Realtion 	- CO224 Lab6
Description - Simple 32-Bytes Cache Memory
Authors - Sanjaya and Hirusha

*/

`timescale  1ns/100ps

module 	cache (CLK, RESET, READ_CPU, WRITE_CPU, cpu_address, WRITEDATA_CPU, READDATA_CPU, busywait_cpu,
				mem_read, mem_write, mem_block_address, mem_WriteData, mem_ReadData, mem_busywait);
			   
	input CLK, RESET;

	// input output ports between the Data_Memory and Cache and between the Cache and CPU
	input [0:0] mem_busywait;
	output reg [31:0] mem_WriteData;
	input [31:0] mem_ReadData;
	output reg [0:0] mem_read, mem_write;
	output reg [5:0] mem_block_address;
	input [0:0] READ_CPU, WRITE_CPU;
	input [7:0] WRITEDATA_CPU, cpu_address;
	output reg [7:0] READDATA_CPU;
	output reg [0:0] busywait_cpu;
	
	// store the index, offset, tag from the cpu address
	wire [2:0] Index, Tag;
	wire [1:0] Offset;
	
	//declare data array for storing cache data blocks, tags ,valid bits and dirty bits 
	reg [31:0] cache_memory [7:0];
	reg [2:0] cache_tags [7:0];
	reg cache_valid_bits [7:0];
	reg cache_dirty_bits [7:0];
	
	// variable declarations 
	reg [31:0] temp_data;
	wire hit;
	reg dirty, valid;
	wire tag_matched;
	reg [7:0] data_word;
	reg [31:0] data_block;
	
	integer count;
	//Reset the Cache to intial state
	always @ (posedge CLK)		//triggered in posedge clock
	begin
		if (RESET == 1'b1) begin		//if RESET is high write 0 to all data blocks
			for (count = 0; count < 8; count++) begin
				cache_memory [count] = 32'd0;
				cache_tags [count] = 3'd0;
				cache_valid_bits [count] = 1'd0;
				cache_dirty_bits [count] = 1'd0;
			end
		end
	end
	
	//Assert BusyWait signal for read or write operation
	always @(READ_CPU, WRITE_CPU, cpu_address)
	begin
		busywait_cpu = (READ_CPU || WRITE_CPU)? 1'b1 : 1'b0;
	end
	
	// get offset, Index, Tag from the address given by cpu  
	assign Offset = cpu_address[1:0];
	assign Index = cpu_address[4:2];
	assign Tag = cpu_address[7:5];
	
	
	//Extract info from cache memory storage and dirty bit and valid bit exratcting
	always @(WRITEDATA_CPU, READDATA_CPU, cache_memory[Index], cache_dirty_bits[Index], cache_valid_bits[Index])
	#1 begin
		data_block = cache_memory[Index];
		dirty = cache_dirty_bits[Index];
		valid = cache_valid_bits[Index];
	end
		
	//Tag Comparison
	assign #0.9 tag_matched = (Tag == cache_tags[Index]); 
	
	//hit signal generate
	assign hit = tag_matched && valid;
	
	// get suitable data word according to offset
	always @(Offset, data_block)
	#1 begin
		case (Offset) 
			2'd0 : data_word = data_block[7:0];
			2'd1 : data_word = data_block[15:8];
			2'd2 : data_word = data_block[23:16];
			2'd3 : data_word = data_block[31:24];
		endcase
	end
	
	// set busywait 0 for hits
	always @(*)
	begin
		if(hit && READ_CPU) // de-assert the busywait_cpu signal for write hit
			begin
				READDATA_CPU = data_word;
				busywait_cpu = 1'b0;
			end
		if(hit && WRITE_CPU) // de-assert the busywait_cpu signal for write hit
			busywait_cpu = 1'b0;
	end
	

	//if write hit, updating content in cache memory
	always @(posedge CLK)
	#1 begin
		if (hit && WRITE_CPU) //if write hit then write in to the cache
			begin
				data_block = cache_memory[Index];
				case (Offset)
					2'd0 : data_block[7:0] 	= WRITEDATA_CPU;
					2'd1 : data_block[15:8]	= WRITEDATA_CPU;
					2'd2 : data_block[23:16]	= WRITEDATA_CPU;
					2'd3 : data_block[31:24]	= WRITEDATA_CPU;
				endcase
				cache_valid_bits[Index] = 1'b1;	// set valid bit to 1 
				cache_dirty_bits[Index] = 1'b1;	// dirty bit is set when there is a writing;
				cache_memory[Index] = data_block; //write the updated data block into the cache memory
				
			end
	end
	
										
	parameter IDLE = 3'b000, MEM_READ = 3'b001, MEM_WRITE = 3'b010, UPDATE_CACHE = 3'b011;
    reg [2:0] state, next_state;
	reg Read_Done;

	// combinational logic control signals for each and every state  
    always @(state)
    begin
        case(state)
            IDLE:
            begin
				// no any operation on data memory  
				Read_Done = 1'b0;
                mem_read = 1'b0;
                mem_write = 1'b0;
                mem_block_address = 6'dx;
                mem_WriteData = 32'dx;
                busywait_cpu = 1'b0;
            end
         
            MEM_READ: 
            begin
                mem_read = 1'b1;
                mem_write = 1'b0;
                mem_block_address = {Tag, Index};
                mem_WriteData = 32'dx;
                busywait_cpu = 1'b1;      // stall the cpu till memory read completed
            end
			
			MEM_WRITE:
			begin
				mem_read = 1'b0;
				mem_write = 1'b1;
				mem_block_address = {cache_tags[Index], Index};
				mem_WriteData = data_block;
				busywait_cpu = 1'b1;               // stall the cpu till memory write happens   
			end
			
			UPDATE_CACHE:
			begin
				Read_Done = 1'b1;
				mem_read = 1'b0;
                mem_write = 1'b0;
                mem_block_address = 6'dx;
                mem_WriteData = 32'dx;
                busywait_cpu = 1'b1;
				#1 begin	
					// update cache with read data from memory
					cache_tags[Index] = Tag; 	//set the tag of cache
					cache_valid_bits[Index] = 1'b1;	// set valid bit to 1
					cache_dirty_bits[Index]= 1'b0;	// dirty bit = 0 , not modified yet 
					temp_data	= mem_ReadData;	 
					cache_memory[Index] = temp_data;	// Update the corresponding data block in cache
				end
			end
			
        endcase
	end
	
	// State transaction from one state to other
    always @(*)
    begin
        case (state)
            IDLE:	// default state of cache , hits will be executed within in this state
                if ((READ_CPU || WRITE_CPU) && !dirty && !hit )  //if Miss with dirty bit zero, read data from mem without writing to it
                    next_state = MEM_READ;
                else if ((READ_CPU || WRITE_CPU) && dirty && !hit)	//if Miss with dirty bit high, write back modified cache block to memory
                    next_state = MEM_WRITE;
                else 						// otherwise stay on same state
                    next_state = IDLE;
            
            MEM_READ: // missing data block is read from memory in this state
                if (!mem_busywait)
                    next_state = UPDATE_CACHE;	//if data memory reading is over , then move to UPDATE_CACHE state
                else    
                    next_state = MEM_READ;	 // otherwise stay on same state
					
			MEM_WRITE:	// write back the modified data block to the memory
				if (!mem_busywait)
					next_state = MEM_READ;	// data memory writing is over then go to MEM_READ state 
				else
					next_state = MEM_WRITE;	 // otherwise stay on same state
					
			UPDATE_CACHE:	// update data got from memory read to cache 
				next_state = IDLE;
					
        endcase
    end

    // state transitioning squential combinational logic
    always @(posedge CLK, RESET)
    begin
        if(RESET)
            state = IDLE;
        else
            state = next_state;
    end

	

endmodule