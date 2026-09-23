module immgen (
  input opcode [3:0], instr[31:7]
  output logic immext [31:0] 
)
always_comb begin
  case(opcode)
  //i-type
    3'b000: immnext = {{20{instr[31]}}, instr[31:20]};
  //s-type
    3'b001: immnext = {{20{instr[31]}}, {instr[31:25]}, instr[11:7]};
  //sb-type
    3'b010: immnext = {{20{instr[31]}},instr[7], instr[30:25], instr[11:8], 0};
  //u-type
    3'b011: immnext = {{12{instr[31]}}, instr[31:12]};
  //uj-type
    3'b100: immnext = {{11{instr[31]}}, instr[19:12], instr[20],instr[30:21],0};
  endcase
  end