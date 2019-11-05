# frozen_string_literal: true

# This file deals with defining the custom macros which are used to store
# values passed in by the including classes
#
module MacrosDefinition
  module CustomMethods
    # Don't want anyone mutating this
    @@_custom_macros = [:instance_variables_only].freeze

    def self.names
      @@_custom_macros
    end

    private

    # define class macros
    @@_custom_macros.each do |macro|
      define_method macro do |*attrs|
        instance_variable_set("@#{macro}", attrs) unless attrs.empty?
      end
    end
  end
end
