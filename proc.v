`define WORD      [15:0]
`define REGSIZE   [15:0]
`define REGNAME   [3:0]
`define MEMSIZE   [65535:0]
`define CALLSIZE  [63:0]
`define ENSIZE    [31:0]
`define OP        [4:0]
`define OPCODE    [15:12]
`define D         [11:8]
`define S         [7:4]
`define T         [3:0]
`define IMMED     [7:0]

// OPS for instructions with unique opcodes
`define OPadd    4'b0001
`define OPand    4'b0010
`define OPmul    4'b0011
`define OPor     4'b0100
`define OPsll    4'b0101
`define OPslt    4'b0110
`define OPsra    4'b0111
`define OPxor    4'b1000
`define OPli8    4'b1001
`define OPlu8    4'b1010
`define OPcall   4'b1100
`define OPjump   4'b1101
`define OPjumpf  4'b1110

// Opcodes for instructions with non-unique opcodes
`define OPnoarg  4'b0000
`define OPtwoarg 4'b1011
`define OPaddr   4'b1111

// 5 bit OPS for instructions without unique opcodes
`define OPtrap   5'b10000
`define OPret    5'b10001
`define OPallen  5'b10010
`define OPpopen  5'b10011
`define OPpushen 5'b10100
`define OPgor    5'b10101
`define OPleft   5'b10110
`define OPlnot   5'b10111
`define OPload   5'b11000
`define OPneg    5'b11001
`define OPright  5'b11010
`define OPstore  5'b11011

`define OPnop    5'b11111

/* Convert opcode of instruction into unique opcode for pipeline */
module decode(opout, regdst, ir);
output reg `OP opout;
output reg `REGNAME regdst;
input wire `OP opin;
input `WORD ir;

/* 
 * May want to use this to insert NOPs or do more for some instructions, but not sure yet... 
 * May also be good to set regdst to 0 if no write is going to occur for the instruction
 */
always @(ir) begin
	case (ir `OPCODE)
		`OPnoarg: begin  opout <= { 1'b1, ir `T }; end
		`OPtwoarg: begin opout <= { 1'b1, ir `T }; end
		default: begin opout <= ir `OPCODE; end
	endcase
end
endmodule

module processor(halt, reset, clk);
output reg halt;
input reset, clk;

reg `WORD regfile `REGSIZE;
reg `WORD instrmem `MEMSIZE;
reg `WORD datamem `MEMSIZE;
reg `CALLSIZE callstack = 0;
reg `ENSIZE enstack = ~0;
reg `WORD pc, ir;
reg `OP s0op, s1op, s2op; // Tracks the op in each stage of the pipeline
wire `OP op; // result of decoder
wire `REGNAME regdst; // destination register (may be changed by decoder in the future (ie set regdst to 0 for no writing))

decode decoder(op, regdst, s0op)

always @(reset) begin
  halt = 0;
  pc = 0;
  s = `Start;
  s0op = `OPnop;
  s1op = `OPnop;
  s2op = `OPnop;
  $readmemh0(regfile);
  $readmemh1(instrmem);
end

/* update with next instruction */
always @(*) ir = instrmem[pc];


endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
  $dumpfile;
  $dumpvars;
  #10 reset = 1;
  #10 reset = 0;
  while (!halted) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
endmodule
