# frozen_string_literal: true

# This file deals with defining the macros which are used to create getter and
# setter methods using attr_*
#
module MacrosDefinition
  module AttrsMethods
    # Don't want anyone mutating this
    @@_attrs_macros = [:readers, :writers, :accessors].freeze

    def self.names
      @@_attrs_macros
    end

    private

    # define class macros
    @@_attrs_macros.each do |macro|
      define_method macro do |*attrs|
        unless attrs.empty?
          instance_variable_set("@#{macro}", attrs)

          # => attr_reader, attr_writer, attr_accessor
          key_word = "attr_#{macro}"[0...-1]

          # Open the class and define the attr_* with the attrs passed in
          class_eval do
            send(key_word, *attrs)
          end
        end
      end
    end
  end
end
