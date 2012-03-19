module ECUTools
  module Helpers
    def rom_id
      return @rom_id if @rom_id
      $stderr.puts "Getting ROM ID..." if verbose
      @rom_id = read_bytes("5002a", 4).join
    end

    def read_bytes(address, number)
      bytes = []
      start = from_hex address
      number.times do |n|
        inst = instruction_at(start + n)
        bytes << inst.bytes[(start+n) % 4]
      end
      bytes
    end

    def instruction_at(address, strict = false)
      address = from_hex address
      if strict and (address % 4) > 0 
        raise "Address #{address} does not fall on an instruction boundary and strict is enabled." 
      end
      @assembly[(address - (address % 4)) / 4]
    end

    def from_hex(address)
      if address.is_a? String
        address.to_i(16)
      else
        address.to_i
      end
    end

    def base_address
      return @base_address if @base_address
      $stderr.puts "Getting base address..." if verbose
      @assembly.each_with_index do |instruction,i|
        if instruction.assembly == "st r3,@r0 \|\| nop"
          match = /ld24 fp,(0x\w+)/.match(@assembly[i+1].assembly)
          if match
            @base_address = match[1]
            @assembly[i+1].comments[0] = "Assign base address to #{@base_address}" 
            return @base_address
          end
        end
      end

      $stderr.puts "WARNING: Base address unknown! Setting to 0 (THIS IS WRONG!)" if verbose
      @base_address = 0 
    end

    def absolute_address(relative_address)
      (base_address.to_i(16) + relative_address).to_s(16)
    end

    def address_descriptions
      return @address_descriptions if @address_descriptions
      @address_descriptions = {}
      begin
        xml = Nokogiri::XML(File.open(File.dirname(__FILE__) + "/../xml/ram/#{rom_id}.xml"))
        xml.xpath('/EvoScanDataLogger/vehicle/ecu/Mode2/DataListItem').each do |node|
          @address_descriptions[node.attr('RequestID')[2..-1]] = node.attr('Display')
        end
      rescue
        $stderr.puts "No RAM map found for this rom, skipping subroutine identification." if verbose
      end
      
      @address_descriptions
    end

    def subroutine_descriptions
      return @subroutine_descriptions if @subroutine_descriptions
      @subroutine_descriptions = {}
      begin
        xml = Nokogiri::XML(File.open(File.dirname(__FILE__) + "/../xml/code/#{rom_id}.xml"))
        xml.xpath('/rom/routine').each do |node|
          @subroutine_descriptions[node.attr('address')] = node.attr('name')
        end
      rescue
        $stderr.puts "No subroutine map found for this rom, skipping subroutine identification." if verbose
      end
      
      @subroutine_descriptions
    end

    def rom_xml
      return @rom_xml if @rom_xml
      @rom_xml = load_rom_xml(rom_id)

      @rom_xml
    end

    def load_rom_xml(rom_number)

      load_rom = Nokogiri::XML(File.open(File.dirname(__FILE__) + "/../xml/rom/#{rom_number}.xml"))

      load_rom.xpath('/rom/include').each do |include_tag|

        include_rom = load_rom_xml(include_tag.text)
        
        # import scalings
        include_rom.xpath('/rom/scaling').each do |scaling|
          if load_rom.xpath("/rom/scaling[@name='#{scaling.attr('name')}']").count == 0
            load_rom.xpath('/rom')[0].add_child(scaling)
          end
        end

        #import tables
        include_rom.xpath('/rom/table').each do |table|
          if load_rom.xpath("/rom/table[@name='#{table.attr('name')}']").count == 0
            load_rom.xpath('/rom')[0].add_child(table)
          end
        end

      end

      load_rom
    end
  end
end