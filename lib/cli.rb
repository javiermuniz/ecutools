require 'optparse'
require 'thor'
require 'disassembler'

module ECUTools
  class CLI < Thor
    include Thor::Actions

    check_unknown_options!
    
    default_task :disassemble
    
    desc "disassemble <ROM>", "Disassembles a ROM into the current working directory"
    long_desc <<-D
      Dissassemble will take a hex or binary ROM and disassemble it into the proper M32R assembly code.
      Tables and data will be disassembled as code, which will need to be sorted out by the user.
    D
    method_option "out", :type => :string, :aliases => "-o", :banner =>
      "The output filename. If none is provided the rom name will be used with a .asm extension"
    def disassemble(input)
      outfile = "#{File.basename(input, File.extname(input))}.asm"
      dasm = ECUTools::Disassembler.new(input)
      dasm.write(outfile)
    end

  end
end
