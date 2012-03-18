require 'version'
require 'instruction'

module ECUTools
  class Disassembler
    
    def initialize(input = nil)
      if(!input.nil?)
        open input
      end
    end
    
    def open(file)
      @assembly = load file
    end
    
    def write(file)
      f = File.new(file,"w")
      header = "\# ecutools v#{ECUTools::VERSION}\n"
      header << "\# Generated assembly, ROM ID #{rom_id}\n"
      header << "\# Base Address: #{base_address}\n"
      header << "\#\n"
      f.write(header)
      @assembly.each do |instruction|
        f.write("#{instruction}\n")
      end
    end
    
    private
    
    def load(file)
      h = '[\d|[a-f]|[A-F]]'
      assembly = []
      io = IO.popen("gobjdump -b binary --architecture=m32r --disassemble-all --disassemble-zeroes -EB #{file}")
      while line = io.gets
        match = /\s+(#{h}+):\s+(#{h}{2}) (#{h}{2}) (#{h}{2}) (#{h}{2})\s+(.+)/.match(line)
        if match
          assembly << Instruction.new(match[1], [ match[2], match[3], match[4], match[5] ], match[6])
        end
      end
      
      assembly
    end
    
    def rom_id
      "0"
    end
    
    def base_address
      @assembly.each_with_index do |instruction,i|
        if instruction.assembly == "st r3,@r0 \|\| nop"
          match = /ld24 fp,(0x\w+)/.match(@assembly[i+1].assembly)
          return match[1] if match
        end
      end
      
      "unknown" 
    end
    
    
  end
end