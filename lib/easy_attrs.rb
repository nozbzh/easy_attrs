# frozen_string_literal: true

#
# This module is meant to be used for objects being initialized with either raw
# JSON or a regular Hash as opposed to a database row (like sub classes of
# ActiveRecord). The raw_input (JSON or Hash) can come from any source but it
# would typically be a response from an external API. You would have to build
# your own client for the objects you're interested in (see the readme for an
# example of a design).
#
# EasyAttrs only keeps attributes specified in the `instance_variables_only`,
# `accessors`, `writers` and `readers` class macros and discards all other keys
# in the raw_input.
#
# `accessors`, `writers` and `readers` are self explanatory and any
# symbol/string passed to it will be made an attr_accessor, attr_writer or
# attr_reader.
#
# `instance_variables_only` is here in case the including class needs access to
# a specific key in the raw_input but does not want to make this a public
# method (accessor/reader/writer). It creates an instance variable for the
# symbol/string passed in whose value is the value under that key in the
# raw_input. See the `Item` class for an example of how it is used.
#
# Usage:
#
# Specify the `instance_variables_only`, `accessors`, `writers` and `readers`
# the including class will use and EasyAttrs will create the methods or
# variables for it. Any of those class macros can be left out.
#
#    class Competitor
#      include EasyAttrs

#      readers :id, :name
#    end
#
# This will create the `id` and `name` readers on the class based on the
# raw_input and every other key in the input will be unused.
#
# $ json = {id: 1, name: 'amazon', other_key: 'other_value'}.to_json
# $ comp = Competitor.new(json)
# => #<Competitor:0x007faef0f2f930 @id=1, @name="amazon">
#
# Here is a slightly more complex example with `@instance_variables_only`:
#
#    class Item
#      include EasyAttrs

#      instance_variables_only :nested_data
#      accessors :name
#      readers :id, :category

#      def elements
#        @nested_data['elements'].map(&:upcase)
#      end
#    end
#
# Note how `instance_variables_only` is used for `:nested_data`. We want to use
# the data contained under the nested_data key in the raw_input but we want
# to transform the data before exposing it to the outside world. The
# transformation is done in the `elements` public method.
#
# Another thing to note is that if a class defines some attributes (readers for
# example) then all subclasses of that class will automatically have the those
# readers created and the values set on initialize (see below for an example).
#
#    class Item
#      include EasyAttrs

#      readers :id, :name
#    end
#
#    class BetterItem < Item
#      accessors :price
#    end
#
# $ BetterItem.new(id: 1, name: 'Better Item', price: 25)
# => #<BetterItem:0x007faef0f2f930 @id=1, @name="Better Item", @price=25>
#
#    class EvenBetterItem < BetterItem
#      readers :category
#    end
#
# $ EvenBetterItem.new(id: 1, name: 'Better Item', price: 25, category: 'BOOOH')
# => #<EvenBetterItem:0x007fbb10371978
#       @category="BOOOH",
#       @id=1,
#       @name="Better Item",
#       @price=25
#     >
#

require 'active_support'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/inflections'
require 'macros_definition/attrs_methods'
require 'macros_definition/custom_methods'

module EasyAttrs
  module ClassMethods
    # `all_attributes` needs to be public for instances to call it in
    # `intialize`.
    #
    def all_attributes
      @_all_attributes ||= begin
        attributes_set = Set.new # Use a set to avoid duplicates

        # Yes, this is a nested loop.
        # The result is memoized so it only happens when the first instance of
        # the including class is initialized and the length of the ancestor
        # chain is rarely going to be very long (it will of course vary
        # depending on the class hierarchy of the applicaton using EasyAttrs).
        #
        easy_attrs_ancestors.each do |a|

          (
            MacrosDefinition::AttrsMethods.names +
            MacrosDefinition::CustomMethods.names
          ).each do |i_var|
            i_var_from_ancestor = a.instance_variable_get("@#{i_var}")

            if i_var_from_ancestor
              attributes_set.merge(i_var_from_ancestor)
            end
          end
        end

        attributes_set
      end
    end

    private

    # The ancestor chain includes `self`, which is exactly what we want in this
    # case because we want to grab all the class instance variables of all the
    # ancestors AND tose of the current class so we can find all attributes to
    # use when an instance calls `new`.
    #
    def easy_attrs_ancestors
      ancestors.select { |a| a.include? EasyAttrs }
    end
  end

  def self.included klass
    klass.extend MacrosDefinition::AttrsMethods
    klass.extend MacrosDefinition::CustomMethods
    klass.extend ClassMethods
  end

  # Transform all top level keys to snake case symbols to handle camel case
  # input.
  # Then, if a given key is part of `all_attributes` AND its content is a Hash,
  # recursively transform all keys to snake case symbols.
  # We want to avoid running `deep_transform_keys` on the raw_input because we
  # may end up transforming a lot of deeply nested keys that will be discarded
  # if they are not part of `all_attributes`.
  #
  # It's fastest to pass a Hash as input. A Json string is slower. A Hash with
  # camel case keys is even slower. And a Json string with camel case keys is
  # the slowest.
  #
  def initialize raw_input={}
    input = parse_input(raw_input)
    set_instance_variables(input) unless input.empty?
  end

  private

  def parse_input raw_input
    if raw_input.is_a?(Hash)
      raw_input
    elsif raw_input.is_a?(String)
      ActiveSupport::JSON.decode(raw_input)
    else
      {}
    end.map { |k, v| [k.to_s.underscore.to_sym, v] }.to_h
  end

  def set_instance_variables attrs_as_hash
    self.class.all_attributes.each do |attribute|
      raw_value = attrs_as_hash[attribute.to_sym]
      next if raw_value.nil?

      value = if raw_value.is_a?(Hash)
        raw_value.deep_transform_keys { |k| k.to_s.underscore.to_sym }
      else
        raw_value
      end

      instance_variable_set("@#{attribute}", value)
    end
  end
end
