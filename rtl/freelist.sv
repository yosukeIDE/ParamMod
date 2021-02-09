/*
* <freelist.sv>
* 
* Copyright (c) 2020 Yosuke Ide
* 
* This software is released under the MIT License.
* http://opensource.org/licenses/mit-license.php
*/

`include "stddef.vh"

// Tag distributer that manages free list.
module freelist #(
	parameter byte DEPTH = 16,
	parameter byte READ = 4,
	parameter byte WRITE = 4,
	// impelementation option
	parameter bit BIT_VEC = `Enable,	// bit vector addressing
	parameter bit OUTREG = `Disable,	// register output
	// constant
	parameter DATA = BIT_VEC ? DEPTH : $clog2(DEPTH)
)(
	input wire							clk,
	input wire							reset_,
	input wire							flush_,		// clear buffer
	input wire [WRITE-1:0]				we_,		// collect
	input wire [WRITE-1:0][DATA-1:0]	wd,			// collect tags
	input wire [READ-1:0]				re_,		// request tag
	output wire [READ-1:0][DATA-1:0]	rd,			// served tag
	output wire [READ-1:0]				v,
	output wire							busy
);

	//***** internal parameter
	localparam CNT = $clog2(DEPTH);
	localparam RDIDX = $clog2(READ);

	//***** internal registers
	reg [DEPTH-1:0]				usage;

	//***** internal wires
	wire [READ-1:0]				v_sel_out_;
	wire [DEPTH-1:0]			next_usage;
	wire [DEPTH-1:0][DATA-1:0]	index;



	//***** assign output
	assign busy = ! (&v);
	assign v = ~v_sel_out_;

	generate
		genvar gj;
		if ( BIT_VEC ) begin : sel_vec
			//*** DATA = DEPTH
			for ( gj = 0; gj < READ; gj = gj + 1 ) begin : LP_rd
				assign {v_sel_out_[gj], rd[gj]}
					= rd_sel(gj, usage);
			end
		end else begin : sel_scl
			//*** DATA = $clog2(DEPTH)
			selector #(
				.BIT_MAP	( `Enable ),
				.DATA		( DATA ),
				.IN			( DEPTH ),
				.OUT		( READ ),
				.ACT		( `Low ),
				.MSB		( `Disable )
			) sel_free (
				.in			( index ),
				.sel		( usage ),
				.valid		( v_sel_out_ ),
				.out		( rd )
			);
		end
	endgenerate

	//*** selector for bit vector mode
	localparam RD_SEL = 1 + DEPTH;
	function [RD_SEL-1:0] rd_sel;
		input [RDIDX-1:0]			rdidx;
		input [DEPTH-1:0]			used;
		reg [DEPTH-1:0][DEPTH-1:0]	index;
		reg [DEPTH-1:0][CNT-1:0]	cnt;
		reg							v_;
		reg [DEPTH-1:0]				out;
		int i, j;
		begin
			// initialize
			v_ = `Disable_;
			out = {DEPTH{1'b0}};
			for ( i = 0; i < DEPTH; i = i + 1 ) begin
				cnt[i] = {CNT{1'b0}};
				for ( j = 0; j < i; j = j + 1 ) begin
					cnt[i] = cnt[i] + !used[j];
				end
			end

			for ( i = 0; i < DEPTH; i = i + 1 ) begin
				index[i] = (1'b1 << i);
			end

			for ( i = DEPTH-1; i >= 0; i = i - 1 ) begin
				if ( ( cnt[i] == rdidx ) && !used[i]  ) begin
					v_ = `Enable_;
					out = index[i];
				end
			end
			rd_sel = {v_, out};
		end
	endfunction



	//***** internal assign
	generate
		genvar gi;
		for ( gi = 0; gi < DEPTH; gi = gi + 1 ) begin : LP_entry
			//*** tag generation
			assign index[gi] = gi;

			//*** entry update
			assign next_usage[gi] 
				= update_usage(gi, usage[gi], re_, rd, we_, wd);
		end
	endgenerate

	//*** update
	function update_usage;
		input [DATA-1:0]			idx;
		input						current;
		input [READ-1:0]			re_;
		input [READ-1:0][DATA-1:0]	rd;
		input [WRITE-1:0]			we_;
		input [WRITE-1:0][DATA-1:0]	wd;
		reg [READ-1:0]				rmatch;
		reg [WRITE-1:0]				wmatch;
		reg							set;
		reg							reset;
		int i;
		begin
			//*** read/write check
			if ( BIT_VEC ) begin
				//* Bit Vector Addressing
				for ( i = 0; i < READ; i = i + 1 ) begin
					rmatch[i] = rd[i][idx] && !re_[i];
				end

				for ( i = 0; i < WRITE; i = i + 1 ) begin
					wmatch[i] = wd[i][idx] && !we_[i];
				end
			end else begin
				//* Scalar Index Addressing
				for ( i = 0; i < READ; i = i + 1 ) begin
					rmatch[i] = ( idx == rd[i] ) && !re_[i];
				end

				for ( i = 0; i < WRITE; i = i + 1 ) begin
					wmatch[i] = ( idx == wd[i] ) && !we_[i];
				end
			end

			//*** set valid bit
			set = |rmatch;
			//*** clear valid bit
			reset = |wmatch;

			update_usage = set || ( !reset && current );
		end
	endfunction



	//***** sequential logics
	always_ff @( posedge clk or negedge reset_ ) begin
		if ( reset_ == `Enable_ ) begin
			usage <= {DEPTH{`Disable}};
		end else begin
			if ( flush_ == `Enable_ ) begin
				usage <= {DEPTH{`Disable}};
			end else begin
				usage <= busy ? usage : next_usage;
			end
		end
	end 

endmodule
