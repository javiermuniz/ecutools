module ECUTools
  class Assembler
    instructions = [ 
      :invalid, :add, :add3, :and, :and3, :or, :or3, :xor,
      :xor3, :addi, :addv, :addv3, :addx, :bc8, :bc24, :beq, 
      :beqz, :bgez, :bgtz, :blez, :bltz, :bnez, :bl8, :bl24, :bcl8, :bcl24, :bnc8, :bnc24,
      :bne, :bra8, :bra24, :bncl8, :bncl24, :cmp, :cmpi, :cmpu, :cmpui, :cmpeq, :cmpz, :div, :divu, :rem,
      :remu, :divh, :jc, :jnc, :jl, :jmp, :ld, :ld_d, :ldb, :ldb_d, :ldh, :ldh_d, :ldub,
      :ldub_d, :lduh, :lduh_d, :ld_plus, :ld24, :ldi8, :ldi16, :lock, :machi, :machi_a, :maclo, :maclo_a, 
      :macwhi, :macwhi_a, :macwlo, :macwlo_a, :mul, :mulhi, :mulhi_a, :mullo, :mullo_a, :mulwhi, 
      :mulwhi_a, :mulwlo, :mulwlo_a, :mv, :mvfachi, :mvfachi_a, :mvfaclo, :mvfaclo_a, :mvfacmi, 
      :mvfacmi_a, :mvfc, :mvtachi, :mvtachi_a, :mvtaclo, :mvtaclo_a, :mvtc,
      :neg, :nop, :not, :rac, :rac_dsi, :rach, :rach_dsi, :rte, :seth, :sll, :sll3, :slli, :sra, :sra3,
      :srai, :srl, :srl3, :srli, :st, :st_d, :stb, :stb_d, :sth, :sth_d, :st_plus, :st_minus,
      :sub, :subv, :subx, :trap, :unlock, :satb, :sath, :sat, :pcmpbz, :sadd, :macwu1, :msblo,
      :mulwu1, :maclh1, :sc, :snc, :max ]
    
  end
end