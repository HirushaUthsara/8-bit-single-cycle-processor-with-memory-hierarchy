
`include "CPU.v"
`include "DataCache.v"
`include "Data_Memory.v"
`include "Instruction_Cache.v"
`include "Instruction_Memory.v"
`timescale  1ns/100ps

module cpu_tb;

    reg CLK, RESET;
    wire [9:0] PC;
    wire [31:0] INSTRUCTION;
	wire [7:0] WRITEDATA, ADDRESS, READDATA;
	wire READ, WRITE, BUSYWAIT;
	
	wire [0:0] BUSYWAIT_mem;
	wire [31:0] WRITEDATA_mem;
	wire [31:0] READDATA_mem;
	wire [0:0] READ_mem, WRITE_mem;
	wire [5:0] ADDRESS_mem;
	
	wire [0:0] BUSYWAIT_insMem;
	wire [0:0] READ_insMem;
	wire [127:0] READ_INST;
	wire [5:0] ADDRESS_insMem;
	
	//instantiating the CPU module
    cpu myCPU(PC, READ, WRITE, ADDRESS, WRITEDATA, READDATA, INSTRUCTION, CLK, RESET, BUSYWAIT);
	
	//instantiating the Instruction Cache module
	inst_Cache insMycache(CLK, RESET, BUSYWAIT, PC, INSTRUCTION, BUSYWAIT_insMem, READ_INST, READ_insMem, ADDRESS_insMem);

	//instantiating the Instruction Memory module
	instruction_memory InsMem(CLK, READ_insMem, ADDRESS_insMem, READ_INST, BUSYWAIT_insMem);

	//instantiating the Cache Memory module
	cache myCache(CLK, RESET, READ, WRITE, ADDRESS, WRITEDATA, READDATA, BUSYWAIT, READ_mem, WRITE_mem, ADDRESS_mem, WRITEDATA_mem, READDATA_mem, BUSYWAIT_mem);
	
	//instantiating the Data Memory module
	data_memory dataMem(CLK, RESET, READ_mem, WRITE_mem, ADDRESS_mem, WRITEDATA_mem, READDATA_mem, BUSYWAIT_mem);

	
    initial
    begin
    
        //generate files needed to plot the waveform using GTKWave
        $dumpfile("testbench.vcd");
		$dumpvars(0, cpu_tb);
        
        CLK = 1'b0;
        RESET = 1'b0;
     
        #3 RESET = 1'b1;
		#5 RESET = 1'b0;
		
        #3000
        $finish;
        
    end
    
    // clock signal generation
    always
        #4 CLK = ~CLK;
        

endmodule