module ECUTools
  class Instruction
    attr_accessible :address, :words, :comments, :assembly
    
    def initialize(address, words, assembly)
      @address = address
      @words = words
      @assembly = assembly
      @comments = []
    end
    
    def to_s
      "#{@address}: #{@words.join(' ')}: #{@assembly} \##{@comments.join(' ')}"
    end
    
  end
end