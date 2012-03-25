require 'version'
require 'instruction'
require 'helpers'
require 'nokogiri'

module ECUTools
  class Disassembler
    include ECUTools::Helpers

    def initialize(input = nil, options = {})
      @options = options
      @table_addresses = {}
      @registered_scales = {}
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
      annotate_scales
      annotate_tables
      annotate_code
      $stderr.puts "Analyzation complete." if verbose
    end

    def annotate_scales
      $stderr.puts "Annotating scales..." if verbose
      scales = rom_xml.xpath('/rom/table/table')
      count = 0
      injected_scales = []
      scales.each do |scale|
        next if scale.attr('address').nil? # skip scales without an address, they won't be in the ROM!
        next if scale.attr('address') =~ /0x8\w+/ # skip scales that reference RAM addresses
        next if injected_scales.include? scale.attr('address')
        injected_scales << scale.attr('address')

        elements = scale.attr('elements').to_i
        scaling = rom_xml.xpath("/rom/scaling[@name='#{scale.attr('scaling')}']")
        if scaling.count == 0
          $stderr.puts "WARNING: Failed to find scaling: #{scale.attr('scaling')}, skipping scale #{scale.attr('name')}" if verbose
          next
        end
        element_size = scaling.attr('storagetype').value().gsub(/[^\d]+/,'').to_i / 8
        storage_size = element_size * elements
        scale_label = "#{scale.attr('name')}, #{elements} elements"
        address = from_hex scale.attr('address')

        possible_offsets = [ 2,6 ]

        # read in the header of the scale, could fail for "headless" scales but that's ok
        header = read_scale_header(address - 6)
        if header[:entries] != elements  and verbose
          $stderr.puts "Header/XML Mismatch for Scale #{scale.attr('name')} @ #{scale.attr('address')}. XML: #{elements}, Header: #{header[:entries]}. Could be bad XML or a headless scale." if verbose
        else
          src_label = address_descriptions[header[:src]].nil? ? nil : " (#{address_descriptions[header[:src]]})"
          dest_label = address_descriptions[header[:dest]].nil? ? nil : " (#{address_descriptions[header[:dest]]})"
          scale_label << ", S = 0x#{header[:src]}#{src_label}, D = 0x#{header[:dest]}#{dest_label}"
        end

        possible_offsets.each do |offset|
          offset_hex = (address - offset).to_s(16)
          @registered_scales[offset_hex] = {:label => scale_label, :name => scale.attr('name'), :scaling => scale.attr('scaling') } if !@registered_scales.include? offset_hex
        end

        storage_size.times do |n|
          instruction = instruction_at(address + n)
          instruction.data = true
          instruction.comment(address + n, "Scale #{scale_label}, 0x#{scale.attr('address')} -> 0x#{(address + storage_size - 1).to_s(16)}")
        end

        count = count + 1
      end
      $stderr.puts "#{count} scales annotated." if verbose
    end

    def annotate_tables
      $stderr.puts "Annotating tables..." if verbose
      tables = rom_xml.xpath('/rom/table')
      count = 0
      tables.each do |table|
        next if table.attr('address').nil? # skip scales without an address, they won't be in the ROM!
        
        elements = 1 # all tables start with one element
        is_data = false
        header = nil
        possible_offsets = []
        
        scaling = rom_xml.xpath("/rom/scaling[@name='#{table.attr('scaling')}']")
        if scaling.count == 0
          $stderr.puts "WARNING: Failed to find scaling: #{table.attr('scaling')}, skipping table #{table.attr('name')}" if verbose
          next
        end

        table.xpath('table').each do |subtable|
          elements = elements * subtable.attr('elements').to_i
          is_data = true
        end
        address = from_hex table.attr('address')
        element_size = scaling.attr('storagetype').value().gsub(/[^\d]+/,'').to_i / 8
        
        if elements == 1 
          possible_offsets << 0 # straight values
        else
          case element_size
          when 1
            case table.attr('type')
            when "2D"
              possible_offsets << 4 # 8bit 2D
              header = read_8bit_header(address - 4)
            when "3D"
              possible_offsets << 7 # 8bit 3D
              possible_offsets << 8 # oddball tables, 8bit 3D, attached to headless scales
              header = read_8bit_header(address - 7)
            else
              $stderr.puts "ERROR: Bad table definition for #{table.attr('name')}, not 2D or 3D, skipping table."
              next
            end
          when 2
            case table.attr('type')
            when "2D"
              possible_offsets << 6 # 16bit 2D
              header = read_16bit_header(address - 6)
            when "3D"
              possible_offsets << 10 # 16bit 3D
              header = read_16bit_header(address - 10)
            else
              $stderr.puts "ERROR: Bad table definition for #{table.attr('name')}, not 2D or 3D, skipping table."
              next
            end
          else
            $stderr.puts "ERROR: Bad table definition for #{table.attr('name')}, not 8bit or 16bit, skipping table."
            next
          end
        end
        
        if header.nil?
          table_label = "#{table.attr('name')} (#{elements} elements, headless)"
        else
          table_label = "#{table.attr('name')} (#{elements} elements, Y = 0x#{header[:y_address]}, X = 0x#{header[:x_address]})"
        end
      
        possible_offsets.each do |offset|
          offset_hex = (address - offset).to_s(16)
          @table_addresses[offset_hex] = table_label if !@table_addresses.include? offset_hex
        end

        storage_size = element_size * elements

        storage_size.times do |n|
          instruction = instruction_at(address + n)
          instruction.data = is_data
          instruction.comment(address + n, table.attr('name') + "(0x#{table.attr('address')} -> 0x#{(address + storage_size - 1).to_s(16)}, #{storage_size} bytes, #{elements} values)")
        end

        count = count + 1
      end
      $stderr.puts "#{count} tables annotated." if verbose
    end

    def annotate_code
      $stderr.puts "Annotating code..." if verbose
      count = 0
      unknown_scale_count = 0
      unknown_table_count = 0
      injected_address_objects = []
      table_address_map = {}
      found_rom_addresses = {}
      found_ram_addresses = {}
      @assembly.each do |instruction|
        # annotate subroute prologue/epilogue
        if instruction.assembly =~ /jmp lr/ 
          instruction.comment instruction.address, 'return'
          next_instruction = instruction_at instruction.address.to_i(16) + 4
          next_instruction.comment next_instruction.address, 'likely subroutine address'
        end
        
        if subroutine_descriptions.include? instruction.address
          instruction.comment instruction.address, "begin subroutine #{subroutine_descriptions[instruction.address]}" 
        end
        
        subroutine_descriptions

        # annotate subroutine calls
        match = /bl 0x(\w+)/.match(instruction.assembly)
        if match
          address = match[1]
          if subroutine_descriptions.include? address
            instruction.comment instruction.address.to_i(16) + 2, "Call #{subroutine_descriptions[address]}"
          end
        end 

        # annotate table address references
        address = /0x([\d|[a-f]|[A-F]]+)/.match(instruction.assembly)
        if address and @table_addresses.include? address[1]
          instruction.comment instruction.address, "Get table #{@table_addresses[address[1]]}"
          count = count + 1
          found_rom_addresses[@table_addresses[address[1]]] = true 
        end

        # annotate scale address references
        if address and @registered_scales.include? address[1]
          instruction.comment instruction.address, "Get scale #{@registered_scales[address[1]][:label]}"
          count = count + 1
        end

        # annotate absolute RAM addressing
        match = /(\w+)\s+\w\w,0x(8\w\w\w\w\w)/.match(instruction.assembly)
        if match
          address = match[2]
          display = address_descriptions[address]

          if match[1] == "ld24"
            op = "Assign pointer to"
          else
            op = "Unknown op on"
          end

          instruction.comment instruction.address, "#{op} RAM address 0x#{address}" + (display.nil? ? '' : " (#{display})")
          found_ram_addresses[display] = true if !display.nil?
          count = count + 1
        end

        # annotate relative RAM addressing
        match = /(\w+)\s+.+?@\((-?\d+),fp\)/.match(instruction.assembly)
        if match
          address = absolute_address match[2].to_i
          display = address_descriptions[address]

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
          when "bclr"
            op = "Clear bit in"
          else
            op = "Unknown op on"
          end
          instruction.comment instruction.address, "#{op} RAM address 0x#{address}" + (display.nil? ? '' : " (#{display})")
          found_ram_addresses[display] = true if !display.nil?
          count = count + 1
        end
        
        # annotate unknown address references (scale/table discovery)
        match = /ld24 r0,0x(\w{1,5})/.match(instruction.assembly)
        if match and match[1].to_i(16) > "0x40000".to_i(16)
          
          address = match[1].to_i(16)
          
          # detect unknown scales
          header = read_scale_header(address)
          if header[:dest] =~ /8[01]\w\w\w\w/ && header[:src] =~ /8[01]\w\w\w\w/ && header[:entries] < 100
            # we have a valid scale header
            elements = header[:entries]
            
            # register our new scale as if it were known (if it's not)
            if @registered_scales[match[1]].nil?
              src_label = address_descriptions[header[:src]].nil? ? nil : " (#{address_descriptions[header[:src]]})"
              dest_label = address_descriptions[header[:dest]].nil? ? nil : " (#{address_descriptions[header[:dest]]})"
              scale_label = "Unknown \##{unknown_scale_count} @ #{(address + 6).to_s(16)}, #{elements} elements, S = 0x#{header[:src]}#{src_label}, D = 0x#{header[:dest]}#{dest_label}"
              @registered_scales[match[1]] = { :label => scale_label, :name => "Unknown \##{unknown_scale_count}", :scaling => "uint16" }
              unknown_scale_count = unknown_scale_count + 1
            end
            
            # annotate the calling line if there isn't a comment already
            if instruction.comments.length == 0 
              instruction.comment instruction.address, "Get scale #{@registered_scales[match[1]][:label]}"
            end
            
            # set the memory address so that we can use it in table discovery, we do this for *all* scale loads
            table_address_map[header[:dest]] = { :elements => elements, :address => match[1]}
          end
          
          # detect unknown 8bit tables
          header = read_8bit_header(address)
          if !header.nil? && header[:y_address] =~ /8[01]\w\w\w\w/ && (header[:dimensions] == 2 || header[:x_address] =~ /8[01]\w\w\w\w/)
            # we have a valid scale header
            y_elements = table_address_map[header[:y_address]][:elements]
            y_scale = table_address_map[header[:y_address]][:address]
            
            # register our new table as if it were known (if it's not)
            if @table_addresses[match[1]].nil? and !(header[:rows] != y_elements and header[:dimensions] == 3)
              x_elements = 1 # we set this to one for 2D tables so our elements calculation doesn't zero out
              puts "<table name=\"Unknown Map \##{unknown_table_count}\" address=\"#{(match[1].to_i(16) + header[:size]).to_s(16)}\" category=\"EcuTools Research\" type=\"#{header[:dimensions]}D\" #{header[:dimensions] == 3 ? 'swapxy="true"' : ''} scaling=\"uint8\">"
              if header[:dimensions] == 3
                if table_address_map[header[:x_address]].nil?
                  puts "  <table name=\"X Axis\" address=\"0x#{header[:x_address]}\" type=\"X Axis\" elements=\"FromRAM?!\" scaling=\"uint16\"/>"
                else 
                  x_scale = table_address_map[header[:x_address]][:address]
                  x_elements = table_address_map[header[:x_address]][:elements]
                  puts "  <table name=\"#{@registered_scales[x_scale][:name]}\" address=\"#{(x_scale.to_i(16)+ 6).to_s(16)}\" type=\"X Axis\" elements=\"#{x_elements}\" scaling=\"#{@registered_scales[x_scale][:scaling]}\"/>"
                end
              end
              puts "  <table name=\"#{@registered_scales[y_scale][:name]}\" address=\"#{(y_scale.to_i(16) + 6).to_s(16)}\" type=\"Y Axis\" elements=\"#{y_elements}\" scaling=\"#{@registered_scales[y_scale][:scaling]}\"/>"
              puts "</table>"
              table_label = "Unknown Map \##{unknown_table_count} (#{x_elements * y_elements} elements, Y = 0x#{header[:y_address]}, X = 0x#{header[:x_address]})"
              @table_addresses[match[1]] = table_label
              found_rom_addresses[@table_addresses[match[1]] ] = true
              unknown_table_count = unknown_table_count + 1
            end
            
            # annotate the calling line if there isn't a comment already
            if instruction.comments.length == 0 
              instruction.comment instruction.address, "Get table #{@table_addresses[match[1]]}"
            end
          end
        end
      end

      $stderr.puts "#{count} lines of code annotated." if verbose
    end

  end
end