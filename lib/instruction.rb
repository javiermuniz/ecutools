module ECUTools
  class Instruction

    def initialize(address, bytes, assembly)
      @address = address
      @bytes = bytes
      @assembly = assembly
      @comments = [ ]
      @data = !(/unknown/.match(assembly).nil?)
    end

    def to_s
      s = "0x#{@address}:\t#{@bytes.join(' ')}"
      s << "\t#{@assembly}" if !data
      s << "\t; #{@comments.compact.join(', ')}" if @comments.length > 0
      s
    end

    def comment(addr,comment)
      addr = addr.to_i(16) if addr.is_a? String
      if addr < @address.to_i(16) or addr >= @address.to_i(16) + 4 
        raise "Attempt to add comment to instruction outside of instruction's address bounds. Address: #{addr}, Instruction: #{@address.to_i(16)}"
      end
      byte_offset = addr % 4
      if @data
        @comments[byte_offset] = comment if !@comments.include? comment
      else
        if(byte_offset < 2)
          @comments[0] = comment if !@comments.include? comment
        else
          @comments[1] = comment if !@comments.include? comment
        end
      end
    end

    def address
      @address
    end

    def data
      @data
    end

    def data=(val)
      @assembly = nil if(val)
      @data=val
    end

    def assembly
      @assembly
    end

    def assembly=(value)
      @assembly = value
      # TODO: Update bytes based on assembly instructions
    end

    def binary
      @bytes.join.to_a.pack("H*")
    end

    def bytes
      @bytes
    end

    def comments
      @comments
    end

  end
end