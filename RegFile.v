
`timescale  1ns/100ps

module reg_file(IN,OUT1,OUT2,INADDRESS,OUT1ADDRESS,OUT2ADDRESS, WRITE, CLK, RESET, BUSYWAIT);

	//defining input port list
	input [2:0] OUT1ADDRESS, OUT2ADDRESS, INADDRESS;  
	input [7:0] IN;
	input CLK, RESET, WRITE, BUSYWAIT;
	
	output [7:0] OUT1, OUT2; //definning output port list
	
	reg [7:0] regs [7:0];	//defininng 8-bit register array of 8
	
	integer count;		//to keep track on the index of the register file array
	
	initial
	begin
		#5;
		$display("\n");
		$display("\t\ttime\treg[0]\treg[1]\treg[2]\treg[3]\treg[4]\treg[5]\treg[6]\treg[7]");
		$display("\t\t---------------------------------------------------------------------");
		$monitor($time , "\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d", regs[0], regs[1], regs[2], regs[3], regs[4], regs[5], regs[6], regs[7]);
		
	end
	
	//code to see the wave forms of the regs array
	// initial
    // begin
    //     $dumpfile("lab6.vcd"); //needs to be update with given file name for vcd file
	// 	$dumpvars(0, reg_file);
    //     for(count = 0; count < 8; count++)begin
    //         $dumpvars(1, regs[count]);
	// 	end
    // end
	
	//reading data
	assign #2 OUT1 = regs[OUT1ADDRESS];
    assign #2 OUT2 = regs[OUT2ADDRESS];
	
	//Writing Data
	always @(posedge CLK)	//triggered in positive edge of clock, IN and INADDRESS
	begin
		if (WRITE == 1'b1  & RESET == 1'b0 & BUSYWAIT == 1'b0)		//if WRITE is high, RESET is low and BUSYWAIT is low then only do the writing
																	//BUSYWAIT is taken here for avoid the register writing when there is no data in READDATA from data memory
			begin
				#1 regs [INADDRESS] = IN;		//writing according to INADDRESS
			end
	end

	//Reset the register values
	always @ (posedge CLK)		//triggered in positive edge of the clock
	begin
		if (RESET == 1'b1) begin		//if RESET is high write 0 to all the registers
			#1 for (count = 0; count < 8; count++) begin
				regs [count] = 8'd0;
			end
		end
	end
	
endmodule