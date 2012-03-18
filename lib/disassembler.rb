require 'version'
require 'instruction'
require 'helpers'
require 'nokogiri'

module ECUTools
  class Disassembler
    include ECUTools::Helpers
    
    def initialize(input = nil, options = {})
      @options = options
      @reference_addresses = {}
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
      header = "; ecutools v#{ECUTools::VERSION}\n"
      header << "; Generated assembly from ROM ID #{rom_id}\n"
      header << "; Base Address: #{base_address}\n"
      header << "; Disassembly:\n"
      f.write(header)
      $stderr.puts "Writing assembly..." if verbose
      @assembly.each do |instruction|
        f.write("#{instruction}\n")
      end
      $stderr.puts "Done." if verbose
    end
    
    def analyze
      $stderr.puts "Analyzing assembly..." if verbose
      annotate_tables
      annotate_code
      $stderr.puts "Analyzation complete." if verbose
    end
    
    def annotate_tables
      $stderr.puts "Annotating tables..." if verbose
      tables = rom_xml.xpath('/rom/table')
      count = 0
      tables.each do |table|
        elements = 1 # all tables start with one element
        element_size = rom_xml.xpath("/rom/scaling[@name='#{table.attr('scaling')}']").attr('storagetype').value().gsub(/[^\d]+/,'').to_i / 8
        address = from_hex table.attr('address')
        
        table.xpath('table').each do |subtable|
          elements = elements * subtable.attr('elements').to_i
        end
        
        possible_offsets = []
        
        case elements
        when 1,4
          possible_offsets << 0
        when 3..20
          possible_offsets << 4
          possible_offsets << 6
        when 44
          possible_offsets << 28  # wtf? maf scaling
        else
          possible_offsets << 7
          possible_offsets << 10
          possible_offsets << 16
        end
        
        possible_offsets.each do |offset|
          offset_hex = (address - offset).to_s(16)
          if verbose and @reference_addresses.include? offset_hex
            $stderr.puts "WARNING: Reference hunt collision at 0x#{offset_hex} (#{@reference_addresses[offset_hex]} vs #{table.attr('name')})! Check code carefully!" 
          end
          @reference_addresses[offset_hex] = table.attr('name')
        end
        
        storage_size = element_size * elements
        
        storage_size.times do |n|
          instruction = instruction_at(address + n)
          instruction.comments[0] = table.attr('name') + "(0x#{table.attr('address')} -> 0x#{(address + storage_size - 1).to_s(16)}, #{storage_size} bytes)"
        end
        
        $stderr.puts "Annotated: #{table.attr('name')}" if verbose
        count = count + 1
      end
      $stderr.puts "#{count} tables annotated." if verbose
    end
    
    def annotate_code
      $stderr.puts "Annotating code..." if verbose
      count = 0
      found_addresses = {}
      @assembly.each do |instruction|
        
        # annotate address references
        address = /0x([\d|[a-f]|[A-F]]+)/.match(instruction.assembly)
        if address and @reference_addresses.include? address[1]
          instruction.comments << "contains possible reference to '#{@reference_addresses[address[1]]}'"
          $stderr.puts "Annotated reference to: #{@reference_addresses[address[1]]} at #{instruction.address}" if verbose
          count = count + 1
          found_addresses[@reference_addresses[address[1]]] = true 
        end
        
        # annotate subroute prologue/epilogue
        if instruction.assembly =~ /push lr/
          instruction.comments << 'begin subroutine'
          count = count + 1
        end
        if instruction.assembly =~ /jmp lr/ 
          instruction.comments << 'return'
          count = count + 1
        end
        
        # annotate RAM addressing
        match = /(\w+)\s+.+?@\((-?\d+),fp\)/.match(instruction.assembly)
        if match
          address = absolute_address match[2].to_i
          notes = address_descriptions[address]
          
          case match[1]
          when "lduh"
            op = "Load unsigned halfword from"
          when "ldub"
            op = "Load unsigned byte from"
          when "ld"
            op = "Load from"
          when "ldb"
            op = "Load byte from"
          when "st" 
            op = "Store at"
          when "stb"
            op = "Store byte at"
          when "sth"
            op = "Store half word at"
          else
            op = "Unknown op on"
          end
          if !notes.nil? and verbose
            $stderr.puts "Found reference to RAM address #{address} (#{notes})"
          end
          instruction.comments << "#{op} 0x#{address}" + (notes.nil? ? '' : "(#{notes})")
        end
      end
      $stderr.puts "#{count} lines of code annotated." if verbose
      if verbose
        @reference_addresses.each_key do |key|
          $stderr.puts "Unable to find any reference to #{@reference_addresses[key]}" if !found_addresses.include? @reference_addresses[key]
          found_addresses[@reference_addresses[key]] = true # stop multiple reports
        end
      end
    end
    
  end
end