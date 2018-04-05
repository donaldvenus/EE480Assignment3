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


/* ALU module */
module alu(result, op, in1, in2);
output reg `WORD result;
input wire `OP op;
input wire `WORD in1, in2;

always @(op, in1, in2) begin
  case (op)
    `OPadd: begin result = in1 + in2; end
    `OPand: begin result = in1 & in2; end
    `OPmul: begin result = in1 * in2; end
    `OPor: begin result = in1 | in2; end
    `OPsll: begin result = in1 << in2; end
    `OPslt: begin result = in1 < in2; end
    `OPsra: begin result = $signed(in1) >>> in2; end
    `OPxor: begin result = in1 ^ in2; end
    `OPlnot: begin result = ~in1; end
    `OPneg: begin result = -in1; end
    `OPleft: begin result = in1; end
    `OPright: begin result = in1; end
    `OPgor: begin result = in1; end
    `OPli8: begin result = in1; end
    `OPlu8: begin result = in1; end
    default: begin result = in1; end
  endcase
end
endmodule


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
    `OPcall: begin
      opout <= ir `OPCODE;
      regdst <= 0;
    end
    `OPjump: begin
      opout <= ir `OPCODE;
      regdst <= 0;
    end
		`OPnoarg: begin
		  opout <= { 1'b1, ir `T };
		  regdst <= 0;
		end
		`OPtwoarg: begin
		  if (ir `T == 4'b1011) regdst <= 0;
		  else regdst <= ir `D;
		  opout <= { 1'b1, ir `T };
		end
		default: begin
		  opout <= ir `OPCODE;
		  regdst <= ir `D;
		end
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
reg `WORD pc, ir, newpc;
reg `OP s0op, s1op, s2op; // Tracks the op in each stage of the pipeline
wire `OP op; // result of decoder
wire `REGNAME regdst; // destination register (may be changed by decoder in the future (ie set regdst to 0 for no writing))
reg `REGNAME s0regdst, s1regdst, s2regdst, s0s, s0d, s0t;
reg `WORD s1sval, s1dval, s1tval, s2val, sval, dval, tval, addr;
wire `WORD res;

decode decoder(op, regdst, ir);
alu myalu(res, s1op, s1sval, s1tval);

always @(reset) begin
  halt = 0;
  pc = 0;
  s0op = `OPnop;
  s1op = `OPnop;
  s2op = `OPnop;
  s1regdst = 0;
  s2regdst = 0;
  s0s = 0;
  s0d = 0;
  s0t = 0;
  $readmemh0(regfile);
  $readmemh1(instrmem);
end

/* update with next instruction */
always @(*) ir = instrmem[pc];

/* Get new PC value */
always @(*) begin
  if (op == `OPaddr && s0op != `OPjumpf) newpc <= addr;
  else if (op == `OPaddr && s0op == `OPjumpf && dval == 0) newpc <= addr;
  else if (op == `OPret) newpc <= callstack[15:0] + 2;
  else newpc <= pc + 1;
end

always @(posedge clk) begin
  $display(datamem[1]);
  $display("call: %d", callstack[15:0]);
  $display("pc: %d", pc);
  $display("u1: %d", regfile[7]);
  $display("u2: %d", regfile[8]);
  $display("u3: %d", regfile[9]);
  $display("u4: %d", regfile[10]);
end

// compute sval with value forwarding
always @(*) begin
  if (s1regdst != 0 && (s0s == s1regdst)) sval = res;
  else if (s2regdst != 0 && (s0s == s2regdst)) sval = s2val;
  else sval = regfile[s0s];
end

// compute dval with value forwarding
always @(*) begin
  if (s1regdst != 0 && (s0d == s1regdst)) dval = res;
  else if (s2regdst != 0 && (s0d == s2regdst)) dval = s2val;
  else dval = regfile[s0d];
end

// compute tval with value forwarding
always @(*) begin
  if (s1regdst != 0 && (s0t == s1regdst)) tval = res;
  else if (s2regdst != 0 && (s0t == s2regdst)) tval = s2val;
  else tval = regfile[s0t];
end

// compute current jump address
always @(*) begin
  addr <= {ir `S, ir `T, s0s, s0t};
end

always @(*) begin
  if (op == `OPcall) callstack <= { callstack[47:0], pc };
  if (op == `OPret) callstack <= callstack >> 16;
end

/* Stage 0 */
always @(posedge clk) if (!halt) begin
  s0op <= op;
  s0regdst <= regdst;
  s0s <= ir `S;
  s0d <= ir `D;
  s0t <= ir `T;
  pc <= newpc;
end

/* Stage 1 */
always @(posedge clk) if (!halt) begin
  s1op <= s0op;
  if (s0op == `OPli8) begin
    s1sval <= {{8{s0s[3]}}, s0s, s0t};
  end else if (s0op == `OPlu8) begin
    s1sval <= {s0s, s0t, regfile[s0d][7:0]};
  end else begin
    s1sval <= sval;
  end
  s1tval <= tval;
  s1dval <= dval;
  s1regdst <= s0regdst;
  /*
  $display("Stage 0:");
  $display("s0op: %d", s0op);
  $display("s0s: %d", s0s);
  $display("s0d: %d", s0d);
  $display("s0t: %d", s0t);
  $display("pc: %d", pc);
  */
end

/* Stage 2 */
always @(posedge clk) if (!halt) begin
  s2op <= s1op;
  s2val <= ((s1op == `OPload) ? datamem[s1sval] : res);
  if (s1op == `OPjumpf && s1dval == 0) enstack <= enstack & ~1;
  if (s1op == `OPallen) enstack <= {enstack[31:1], 1'b1};
  if (s1op == `OPpushen) enstack <= {enstack[30:0], enstack[0]};
  if (s1op == `OPpopen) enstack <= {enstack[31], enstack[31:1]};
  if (enstack[0] == 1) begin
    // Enabled
    if (s1op == `OPstore) datamem[s1sval] <= s1dval;
    if (s1op == `OPtrap) halt <= 1;
    s2regdst <= s1regdst;
  end else begin
    // Disabled
    s2regdst <= 0;
  end
  /*
  $display("Stage 1:");
  $display("s1op: %d", s1op);
  $display("s1regdst: %d", s1regdst);
  $display("s1sval: %d", s1sval);
  $display("s1dval: %d", s1dval);
  $display("s1tval: %d", s1tval);
  */
end

/* Stage 3 */
always @(posedge clk) if (!halt) begin
  if (s2regdst != 0) regfile[s2regdst] <= s2val;
  /*
  $display("Stage 2:");
  $display("s2op: %d", s2op);
  $display("s2regdst: %d", s2regdst);
  $display("s2val: %d", s2val);
  */
end

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
