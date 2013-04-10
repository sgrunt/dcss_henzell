require 'tpl/lookup_fragment'

module Tpl
  class Gsub < LookupFragment
    def initialize(identifier, pattern, replacement)
      super(identifier)
      @pattern = pattern
      @replacement = replacement
    end

    def eval(provider)
      lookup(provider) { |match|
        if match == @pattern
          @replacement.eval(provider)
        else
          match
        end
      }
    end

    def simple?
      false
    end

    def to_s
      "${#{@identifier}//#{@pattern}/#{@replacement}}"
    end
  end
end
