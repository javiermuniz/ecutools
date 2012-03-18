require 'version'
require 'instruction'
require 'helpers'
require 'nokogiri'

module ECUTools
  class Disassembler
    include ECUTools::Helpers
    
    def initialize(input = nil, options = {})
      @options = options
      if(!input.nil?)
        open input
      end
    end
    
    def verbose
      @options[:verbose]
    end
    
    def open(file)
      $stderr.puts "Disassembling binary..." if verbose
      h = '[\d|[a-f]|[A-F]]'
      @assembly = []
      io = IO.popen("gobjdump -b binary --architecture=m32r --disassemble-all --disassemble-zeroes -EB #{file}")
      while line = io.gets
        match = /\s+(#{h}+):\s+(#{h}{2}) (#{h}{2}) (#{h}{2}) (#{h}{2})\s+(.+)/.match(line)
        if match
          @assembly << Instruction.new(match[1], [ match[2], match[3], match[4], match[5] ], match[6])
        end
      end
      
      $stderr.puts "Disassembly complete." if verbose
    end
    
    def write(file)
      f = File.new(file,"w")
      header = "// ecutools v#{ECUTools::VERSION}\n"
      header << "// Generated assembly, ROM ID #{rom_id}\n"
      header << "// Base Address: #{base_address}\n"
      header << "//\n"
      f.write(header)
      $stderr.puts "Writing assembly..." if verbose
      @assembly.each do |instruction|
        f.write("#{instruction}\n")
      end
      $stderr.puts "Done." if verbose
    end
    
    def analyze
      annotate_tables
    end
    
    def annotate_tables
      
    end
    
    def list_tables
      doc = Nokogiri::XML(open(File.dirname(__FILE__) + /xml/))
    end
    
  end
end