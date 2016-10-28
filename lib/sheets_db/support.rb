module SheetsDB
  module Support
    class << self
      def camelize(string)
        string = string.sub(/^[a-z\d]*/) { $&.capitalize }
        string = string.gsub(/(?:_|(\/))([a-z\d]*)/) { "#{$1}#{$2.capitalize}" }.gsub('/', '::')
      end

      def constantize(string)
        name_parts = camelize(string).split('::')
        name_parts.shift if name_parts.first.empty?
        constant = Object

        name_parts.each do |name_part|
          constant_defined = constant.const_defined?(name_part, false)
          constant = constant_defined ? constant.const_get(name_part) : constant.const_missing(name_part)
        end
        constant
      end
    end
  end
end