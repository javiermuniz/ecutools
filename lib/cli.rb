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
  end
end
