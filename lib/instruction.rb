module ECUTools
  class Instruction
    
    def initialize(address, bytes, assembly)
      @address = address
      @bytes = bytes
      @assembly = assembly
      @comments = []
      @data = !(/unknown/.match(assembly).nil?)
    end
    
    def to_s
      s = "0x#{@address}:\t#{@bytes.join(' ')}"
      s << "\t#{@assembly}" if (!data) 
      s << "\t; #{@comments.join(', ')}" if @comments.length > 0
      s
    end
    
    def address
      @address
    end
    
    def data
      @data
    end
    
    def data=(val)
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