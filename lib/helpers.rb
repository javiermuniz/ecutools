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
      
      $stderr.puts "WARNING: Base address unknown!" if verbose
      @base_address = "*unknown*" 
    end
    
    def absolute_address(relative_address)
      (base_address.to_i(16) + relative_address).to_s(16)
    end
    
    def address_descriptions
      return @address_descriptions if @address_descriptions
      @address_descriptions = {}
      xml = Nokogiri::XML(File.open(File.dirname(__FILE__) + "/../xml/ram/#{rom_id}.xml"))
      xml.xpath('/EvoScanDataLogger/vehicle/ecu/Mode2/DataListItem').each do |node|
        @address_descriptions[node.attr('RequestID')[2..-1]] = node.attr('Notes')
      end
      
      @address_descriptions
    end
    
    def rom_xml
      return @rom_xml if @rom_xml
      @rom_xml = Nokogiri::XML(File.open(File.dirname(__FILE__) + "/../xml/rom/#{rom_id}.xml"))
    end
  end
end