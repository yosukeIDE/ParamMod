/*
* <cam2_test.sv>
* 
* Copyright (c) 2020 Yosuke Ide
* 
* This software is released under the MIT License.
* http://opensource.org/licenses/mit-license.php
*/

`include "parammod_stddef.vh"
`include "sim.vh"

`timescale 1ns/10ps

module cam2_test;
	parameter MANUAL = `ENABLE;
	//parameter MANULA = `DISABLE;
	parameter STEP = 10;
	parameter DATA = 32;
	parameter DEPTH = 32;
	parameter WRITE = 4;
	parameter READ = 4;
	parameter MSB = `ENABLE;
	// constant
	parameter ADDR = $clog2(DEPTH);

	reg							clk;
	reg							reset;

	/* write */
	reg [WRITE-1:0]				we;
	reg [WRITE-1:0][DATA-1:0]	wm;
	reg [WRITE-1:0][DATA-1:0]	wd;
	reg [WRITE-1:0][ADDR-1:0]	waddr;

	/* read */
	reg [READ-1:0]				re;
	reg [READ-1:0][DATA-1:0]	rm;
	reg [READ-1:0][DATA-1:0]	rd;
	wire [READ-1:0]				match;
	wire [READ-1:0]				multi;
	wire [READ-1:0][ADDR-1:0]	raddr;



	/***** instanciate module *****/
	cam2 #(
		.DATA		( DATA ),
		.DEPTH	( DEPTH ),
		.WRITE	( WRITE ),
		.READ		( READ ),
		.MSB    ( MSB )
	) cam (
		.*
	);


	/***** simulation utils *****/
	`include "cam_util.svh"


	/***** clk generation *****/
	always #(STEP/2) begin
		clk <= ~clk;
	end


	/***** simulation body *****/
	integer i;
	initial begin
		clk <= `LOW;
		reset <= `ENABLE;
		we <= {WRITE{`DISABLE}};
		wm <= {DATA*WRITE{`DISABLE_}};
		wd <= {DATA*WRITE{1'b0}};
		waddr <= {ADDR*WRITE{1'b0}};
		re <= {READ{`DISABLE}};
		rm <= {DATA*READ{`DISABLE}};
		rd <= {DATA*READ{1'b0}};
		#(STEP);
		reset <= `DISABLE;


		/***** read/write check *****/
		`SetCharCyan
		`SetCharBold
		$display("\nread/write check");
		`ResetCharSetting
		#(STEP);
		for ( i = 0; i < WRITE; i = i + 1 ) begin
			set_write(i, 'h0, 'h100 << i, i << 1);
		end
		#(STEP);
		reset_write;
		#(STEP);
		for ( i = 0; i < READ; i = i + 1 ) begin
			set_read(i, 'h0, 'h100 << i);
		end
		#(STEP);
		reset_read;

		`SetCharCyan
		`SetCharBold
		$display("\nentry not found check");
		`ResetCharSetting
		for ( i = 0; i < READ; i = i + 1 ) begin
			set_read(i, 'h0, 'h100 << (i+2));
		end
		#(STEP);
		reset_read;
		#(STEP);

		`SetCharCyan
		`SetCharBold
		if ( MSB ) begin
			$display("\nsynonym check (read from tail)");
		end else begin
			$display("\nsynonym check (read from head)");
		end
		`ResetCharSetting
		#(STEP);
		set_write(0, 'h0, 'h400, 16);
		#(STEP);
		reset_write;
		#(STEP);
		set_read(0, 'h0, 'h400);
		#(STEP);
		reset_read;


		#(STEP*10);
		$finish;
	end

`ifdef SimVision
	initial begin
		$shm_open();
		$shm_probe("ACM");
	end
`endif

endmodule
