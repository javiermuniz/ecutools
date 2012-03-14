require 'optparse'
require 'thor'

module ECUTools
  class CLI < Thor
    include Thor::Actions
    attr_accessor :in_key, :in_secret, :in_bucket, :out_key, :out_secret, :out_bucket, :all

    check_unknown_options!
    
    default_task :disassemble
    
    desc "disassemble <ROM>", "Disassembles a ROM into the current working directory"
    long_desc <<-D
      Dissassemble will take a hex or binary ROM and disassemble it into the proper M32R assembly code.
      Tables and data will be disassembled as code, which will need to be sorted out by the user.
    D
    method_option "out", :type => :string, :aliases => "-o", :banner =>
      "The output filename. If none is provided the rom name will be used with a .asm extension"
    def disassemble(rom)
      outfile = "#{File.basename(rom, File.extname(rom))}.asm"
      %x!gobjdump -b binary --architecture=m32r --disassemble-all --disassemble-zeroes -EB #{rom} > #{outfile}!
    end
    
    desc "baseaddress <ROM>", "Returns the base address of the given ROM"
    long_desc <<-D
      Returns the base address for use when finding absolute addresses in memory.
    D
    def baseaddress(rom)
      %x!gobjdump -b binary --architecture=m32r --disassemble-all --disassemble-zeroes -EB #{rom} > .temp.asm!
      file = File.new('.temp.asm')
      while (line = file.gets)
        if line =~ /st r3,@r0 \|\| nop/ then
          l2 = file.gets
          fp = /ld24 fp,(0x\w+)/.match(l2)
          puts fp[1]
        end
      end
      %x!rm .temp.asm!
    end
  end
end
