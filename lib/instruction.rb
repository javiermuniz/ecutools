module ECUTools
  class Instruction
    
    def initialize(address, words, assembly)
      @address = address
      @words = words
      @assembly = assembly
      @comments = []
    end
    
    def to_s
      "#{@address}:\t#{@words.join(' ')}\t\t#{@assembly}" + (@comments.length > 0 ? "\t\t// #{@comments.join(', ')}" : '')
    end
    
    def address
      @address
    end
    
    def assembly
      @assembly
    end
    
    def assembly=(value)
      @assembly = value
      # TODO: Update words based on assembly instructions
    end
    
    def binary
      @words.join.to_a.pack("H*")
    end
    
    def words
      @words
    end
    
    def comments
      @comments
    end
    
  end
end