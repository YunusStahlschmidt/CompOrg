module processor;
reg [31:0] pc; //32-bit prograom counter
reg clk; //clock
reg [7:0] datmem[0:31],mem[0:31]; //32-size data and instruction memory (8 bit(1 byte) for each location)
wire [31:0] 
dataa,	//Read data 1 output of Register File
datab,	//Read data 2 output of Register File
out2,		//Output of mux with ALUSrc control-mult2
out3,		//Output of mux with MemToReg control-mult3
out4,		//Output of mux with Branch&Jump control-mult4
out5,		//Output of mux with jbnr control-mult5
out6,		//Output of mux with wrtdat control-mult6
sum,		//ALU result
extad,	//Output of sign-extend unit
adder1out,	//Output of adder which adds PC and 4-add1
adder2out,	//Output of adder which adds PC+4 and 2 shifted sign-extend result-add2
sextad1,	//Output of shift left 2_1 unit
sextad2;	//Output of shift left 2_2 unit

wire [5:0] inst31_26;	//31-26 bits of instruction
wire [4:0] 
inst25_21,	//25-21 bits of instruction
inst20_16,	//20-16 bits of instruction
inst15_11,	//15-11 bits of instruction
out1;		//Write data input of Register File

wire [25:0] inst25_0; // for jump adress

wire [15:0] inst15_0;	//15-0 bits of instruction

wire [31:0] instruc,	//current instruction
jmpAdrr,	//adder1out[31:28] + sextad1
dpack;	//Read data output of memory (data read from memory)

wire [2:0] gout;	// Output of ALU control unit

wire [1:0] 
asreg;	// ADDED: ALU => status reg
// pcsrc;	// ADDED: j/b control => mux control

wire 
//Control signals
regdest1,regdest2,alusrc,memtoreg,regwrite,memread,memwrite,bnj1,bnj2,bnj3,aluop1,aluop0,wrtdatmux,jbrnmux,outmux0,outmux1;

//32-size register file (32 bit (1 word) for each register)
reg [31:0] registerfile[0:31];

integer i;

// datamemory connections

always @(posedge clk)
//write data to memory
if (memwrite)
begin 
//sum stores address,datab stores the value to be written
datmem[sum[4:0]+3]=datab[7:0];
datmem[sum[4:0]+2]=datab[15:8];
datmem[sum[4:0]+1]=datab[23:16];
datmem[sum[4:0]]=datab[31:24];
end

//instruction memory
//4-byte instruction
 assign instruc={mem[pc[4:0]],mem[pc[4:0]+1],mem[pc[4:0]+2],mem[pc[4:0]+3]};
 assign inst31_26=instruc[31:26];
 assign inst25_21=instruc[25:21];
 assign inst20_16=instruc[20:16];
 assign inst15_11=instruc[15:11];
 assign inst15_0=instruc[15:0];
 assign inst25_0=instruc[25:0];

//concat adder1out[31:28] & sextad1
assign jmpAdrr[31:28]=adder1out[31:28];
assign jmpAdrr[27:0]=sextad1;


// registers

assign dataa=registerfile[inst25_21];//Read register 1
assign datab=registerfile[inst20_16];//Read register 2
always @(posedge clk)
 registerfile[out1]= regwrite ? out6:registerfile[out1];//Write data to register

//read data from memory, sum stores address
assign dpack={datmem[sum[5:0]],datmem[sum[5:0]+1],datmem[sum[5:0]+2],datmem[sum[5:0]+3]};

//multiplexers
//mux with RegDst control
// mult2_to_1_5  mult1(out1, instruc[20:16],instruc[15:11],regdest1,regdest2);  // TODO: change to 4 to 1
mult4_to_1_5 mult1(out1,instruc[20:16],instruc[15:11],registerfile[31],regdest1,regdest2);

//mux with ALUSrc control
mult2_to_1_32 mult2(out2, datab,extad,alusrc);

//mux with MemToReg control
mult2_to_1_32 mult3(out3, sum, dpack, memtoreg);

//mux with Branch&Jump control
// mult4_to_1_32 mult4(out4, adder1out,out5,out3,adder2out,outmux1,outmux0);

//mux for jbrn
mult2_to_1_32 mult5(out5, jmpAdrr, dataa, jbrnmux);  

//mux for wrtdat
mult2_to_1_32 mult6(out6, out3, adder1out, wrtdatamux);

// load pc
always @(negedge clk)
pc=out4;

// alu, adder and control logic connections

//ALU unit
alu32 alu1(sum,dataa,out2,asreg,gout); // ADDED: nout flag

//adder which adds PC and 4
adder add1(pc,32'h4,adder1out);

//adder which adds PC+4 and 2 shifted sign-extend result
adder add2(adder1out,sextad2,adder2out);

//Control unit
control cont(instruc[31:26],regdest1,regdest2,alusrc,memtoreg,regwrite,memread,memwrite,bnj1,bnj2,bnj3,
aluop1,aluop0);

//Sign extend unit
signext sext(instruc[15:0],extad);

//ALU control unit
alucont acont(aluop1,aluop0,instruc[5],instruc[4],instruc[3],instruc[2], instruc[1], instruc[0] ,gout);  // ADDED: extended to 6 input bits

//Shift-left 1 unit => jump address
shift shift2_1(sextad1,inst25_0);

//Shift-left 2 unit => branch adress
shift shift2_2(sextad2,extad);

//Branch & Jump Control Unit
jb jbcu(asreg,bnj1,bnj2,bnj3,outmux1,outmux0,jbrnmux,wrtdatamux); 

//AND gate
// assign pcsrc=branch && zout; 

//initialize datamemory,instruction memory and registers
//read initial data from files given in hex
initial
begin
$readmemh("initDm.dat",datmem); //read Data Memory
$readmemh("initIM.dat",mem);//read Instruction Memory
$readmemh("initReg.dat",registerfile);//read Register File

	for(i=0; i<31; i=i+1)
	$display("Instruction Memory[%0d]= %h  ",i,mem[i],"Data Memory[%0d]= %h   ",i,datmem[i],
	"Register[%0d]= %h",i,registerfile[i]);
end

initial
begin
pc=0;
#400 $finish;
	
end
initial
begin
clk=0;
//40 time unit for each cycle
forever #20  clk=~clk;
end
initial 
begin
  $monitor($time,"PC %h",pc,"  SUM %h",sum,"   INST %h",instruc[31:0],
"   REGISTER %h %h %h %h ",registerfile[4],registerfile[5], registerfile[6],registerfile[1] );
end
endmodule

