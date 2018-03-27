// basic sizes of things
`define WORD	[15:0]
`define RNAME   [5:0]
`define OP	[4:0]
`define Opcode	[15:12]
`define Dest	[11:6]
`define Src	[5:0]
`define REGSIZE [63:0]
`define MEMSIZE [65535:0]

// opcode values, also state numbers
`define OPadd	4'b0000
`define OPinvf	4'b0001
`define OPaddf	4'b0010
`define OPmulf	4'b0011
`define OPand	4'b0100
`define OPor	4'b0101
`define OPxor	4'b0110
`define OPany	4'b0111
`define OPdup	4'b1000
`define OPshr	4'b1001
`define OPf2i	4'b1010
`define OPi2f	4'b1011
`define OPld	4'b1100
`define OPst	4'b1101
`define OPjzsz	4'b1110
`define OPli	4'b1111

// extended opcode values
`define OPjz	5'b10000
`define OPsz	5'b10001
`define OPsys	5'b10010
`define OPnop	5'b11111

// source field values for sys and sz
`define SRCsys	6'b000000
`define SRCsz	6'b000001


module decode(opout, regdst, opin, ir);
output reg `OP opout;
output reg `RNAME regdst;
input wire `OP opin;
input `WORD ir;

always @(opin, ir) begin
  if (opin == `OPli) begin
    opout = `OPnop;       // 2nd word of li becomes nop
    regdst = 0;	  	  // no writing
  end else begin
    case (ir `Opcode)
      `OPjzsz: begin
        regdst = 0;		   // no writing
        case (ir `Src)	           // use Src as extended opcode
          `SRCsys: opout = `OPsys;
          `SRCsz: opout = `OPsz;
          default: opout = `OPjz;
        endcase
      end
      `OPst: begin opout = ir `Opcode; regdst <= 0; end
      default: begin opout = ir `Opcode; regdst <= ir `Dest; end
    endcase
  end
end
endmodule


module alu(result, op, in1, in2);
output reg `WORD result;
input wire `OP op;
input wire `WORD in1, in2;

always @(op, in1, in2) begin
  case (op)
    `OPadd: begin result = in1 + in2; end
    `OPand: begin result = in1 & in2; end
    `OPany: begin result = |in1; end
    `OPor: begin result = in1 | in2; end
    `OPshr: begin result = in1 >> 1; end
    `OPxor: begin result = in1 ^ in2; end
    default: begin result = in1; end
  endcase
end
endmodule


module processor(halt, reset, clk);
output reg halt;
input reset, clk;

reg `WORD regfile `REGSIZE;
reg `WORD mainmem `MEMSIZE;
reg `WORD ir, srcval, dstval, newpc;
reg ifsquash, rrsquash;
wire `OP op;
wire `RNAME regdst;
wire `WORD res;
reg `OP s0op, s1op, s2op;
reg `RNAME s0src, s0dst, s0regdst, s1regdst, s2regdst;
reg `WORD pc;
reg `WORD s1srcval, s1dstval;
reg `WORD s2val;

always @(reset) begin
  halt = 0;
  pc = 0;
  s0op = `OPnop;
  s1op = `OPnop;
  s2op = `OPnop;
  $readmemh0(regfile);
  $readmemh1(mainmem);
end

decode mydecode(op, regdst, s0op, ir);
alu myalu(res, s1op, s1srcval, s1dstval);

always @(*) ir = mainmem[pc];

// compute srcval, with value forwarding... also from 2nd word of li
always @(*) if (s0op == `OPli) srcval = ir; // catch immediate for li
            else srcval = ((s1regdst && (s0src == s1regdst)) ? res :
                           ((s2regdst && (s0src == s2regdst)) ? s2val :
                            regfile[s0src]));

// compute dstval, with value forwarding
always @(*) dstval = ((s1regdst && (s0dst == s1regdst)) ? res :
                      ((s2regdst && (s0dst == s2regdst)) ? s2val :
                       regfile[s0dst]));

// new pc value
always @(*) newpc = (((s1op == `OPjz) && (s1dstval == 0)) ? s1srcval :
                     (pc + 1));

// IF squash? Only for jz... with 2-cycle delay if taken
always @(*) ifsquash = ((s1op == `OPjz) && (s1dstval == 0));

// RR squash? For both jz and sz... extra cycle allows sz to squash li
always @(*) rrsquash = (((s1op == `OPsz) || (s1op == `OPjz)) && (s1dstval == 0));


// Instruction Fetch
always @(posedge clk) if (!halt) begin
  s0op <= (ifsquash ? `OPnop : op);
  s0regdst <= (ifsquash ? 0 : regdst);
  s0src <= ir `Src;
  s0dst <= ir `Dest;
  pc <= newpc;
end

// Register Read
always @(posedge clk) if (!halt) begin
  s1op <= (rrsquash ? `OPnop : s0op);
  s1regdst <= (rrsquash ? 0 : s0regdst);
  s1srcval <= srcval;
  s1dstval <= dstval;
end

// ALU and data memory operations
always @(posedge clk) if (!halt) begin
  s2op <= s1op;
  s2regdst <= s1regdst;
  s2val <= ((s1op == `OPld) ? mainmem[s1srcval] : res);
  if (s1op == `OPst) mainmem[s1srcval] <= s1dstval;
  if (s1op == `OPsys) halt <= 1;
end

// Register Write
always @(posedge clk) if (!halt) begin
  if (s2regdst != 0) regfile[s2regdst] <= s2val;
end
endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
integer i = 0;
processor PE(halted, reset, clk);
initial begin
  $dumpfile;
  $dumpvars(0, PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halted && (i < 200)) begin
    #10 clk = 1;
    #10 clk = 0;
    i=i+1;
  end
  $finish;
end
endmodule