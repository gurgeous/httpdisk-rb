module HTTPDisk
  # Like Slop, but for sanity checking method options. Useful for library entry
  # points that want to be strict. Example usage:
  #
  # options = Sloptions.new(options) do
  #   _1.boolean :force
  #   _1.integer :retries, required: true
  #   _1.string :hello, default: 'world'
  #   ...
  # end
  class Sloptions
    attr_reader :flags

    def self.parse(options, &block)
      Sloptions.new(&block).parse(options)
    end

    def initialize
      @flags = {}
      yield(self)
    end

    #
    # _1.on and friends
    #

    def on(flag, foptions = {})
      raise ":#{flag} already defined" if flags[flag]

      flags[flag] = foptions
    end

    %i[array boolean float hash integer string symbol].each do |method|
      define_method(method) do |flag, foptions = {}|
        on(flag, {type: method}.merge(foptions))
      end
    end
    alias_method :bool, :boolean

    #
    # return parsed options
    #

    def parse(options)
      # defaults
      options = defaults.merge(options.compact)

      flags.each do |flag, foptions|
        # nil check
        value = options[flag]
        if value.nil?
          raise ArgumentError, ":#{flag} is required" if foptions[:required]

          next
        end

        # type cast (for boolean)
        if foptions[:type] == :boolean
          value = options[flag] = !!options[flag]
        end

        # type check
        types = Array(foptions[:type])
        raise ArgumentError, error_message(flag, value, types) if !valid?(value, types)
      end

      # return
      options
    end

    protected

    def defaults
      flags.map { |flag, foptions| [flag, foptions[:default]] }.to_h.compact
    end

    # does value match valid?
    def valid?(value, types)
      types.any? do
        case _1
        when :array then true if value.is_a?(Array)
        when :boolean then true # in Ruby everything is a boolean
        when :float then true if value.is_a?(Float) || value.is_a?(Integer)
        when :hash then true if value.is_a?(Hash)
        when :integer then true if value.is_a?(Integer)
        when :string then true if value.is_a?(String)
        when :symbol then true if value.is_a?(Symbol)
        when Class then true if value.is_a?(_1) # for custom checks
        else
          raise "unknown flag type #{_1.inspect}"
        end
      end
    end

    # nice error message for when value is invalid
    def error_message(flag, value, valid)
      classes = valid.compact.map do
        s = _1.to_s
        s = s.downcase if /\b(Array|Float|Hash|Integer|String|Symbol)\b/.match?(s)
        s
      end.join("/")
      "expected :#{flag} to be #{classes}, not #{value.inspect}"
    end
  end
end
