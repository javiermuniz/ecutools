module ECUTools
  class Instruction
    
    def initialize(address, bytes, assembly)
      @address = address
      @bytes = bytes
      @assembly = assembly
      @comments = []
    end
    
    def to_s
      "#{@address}:\t#{@bytes.join(' ')}\t#{@assembly}" + (@comments.length > 0 ? "\t; #{@comments.join(', ')}" : '')
    end
    
    def address
      @address
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