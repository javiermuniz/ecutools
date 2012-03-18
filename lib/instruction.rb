module ECUTools
  class Instruction
    
    def initialize(address, words, assembly)
      @address = address
      @words = words
      @assembly = assembly
      @comments = []
    end
    
    def to_s
      "#{@address}\t#{@words.join(' ')}\t\t#{@assembly}" + (@comments.length > 0 ? "\t\t\##{@comments.join(', ')}" : '')
    end
    
    def assembly
      @assembly
    end
    
  end
end