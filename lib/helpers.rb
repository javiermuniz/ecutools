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
      rel = from_hex relative_address
      (base_address.to_i(16) + relative_address).to_s(16)
    end

    def from_table_ref(ref)
      ref = ref.to_i(16) # convert ref to integer
      relative_address = ref - '0x10000'.to_i(16)
      absolute_address relative_address
    end

    def address_descriptions
      return @address_descriptions if @address_descriptions
      @address_descriptions = {}
      begin
        xml = Nokogiri::XML(File.open(File.dirname(__FILE__) + "/../xml/ram/#{rom_id}.xml"))
        xml.xpath('/EvoScanDataLogger/vehicle/ecu/Mode2/DataListItem').each do |node|
          addr = node.attr('RequestID')[2..-1]
          @address_descriptions[addr] = node.attr('Display') if !@address_descriptions.include? addr
        end
      rescue
        $stderr.puts "No RAM map found for this rom, skipping subroutine identification." if verbose
      end
      
      @address_descriptions
    end
    
    def read_scale_header(address)
      destination = from_table_ref read_bytes(address,2).join
      source = from_table_ref read_bytes(address + 2,2).join
      elements = read_bytes(address + 4,2).join.to_i(16)
      { :dest => destination, :src => source, :entries => elements }
    end
    
    def read_8bit_header(address)
      header = {}
      header[:dimensions] = read_bytes(address,1).join.to_i(16)
      return nil if ![2,3].include? header[:dimensions] # return nil for "headless" tables
      header[:value_offset] = read_bytes(address+1,1).join.to_i(16)
      header[:y_address] = from_table_ref read_bytes(address+2,2).join
      header[:x_address] = from_table_ref read_bytes(address+4,2).join if(header[:dimensions] == 3)
      header[:rows] = read_bytes(address + 6 , 1).join.to_i(16) if(header[:dimensions] == 3)
      header[:size] = header[:dimensions] == 2 ? 4 : 7;
      header
    end
    
    def read_16bit_header(address)
      header = {}
      header[:dimensions] = read_bytes(address,2).join.to_i(16)
      return nil if ![2,3].include? header[:dimensions] # return nil for "headless" tables
      header[:value_offset] = read_bytes(address+2,2).join.to_i(16)
      header[:y_address] = from_table_ref read_bytes(address+4,2).join
      header[:x_address] = from_table_ref read_bytes(address+6,2).join if(header[:dimensions] == 3)
      header[:rows] = read_bytes(address + 8, 2).join.to_i(16) if(header[:dimensions] == 3)
      header[:size] = header[:dimensions] == 2 ? 6 : 10
      header
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