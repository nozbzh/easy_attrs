# frozen_string_literal: true

require 'spec_helper'

describe EasyAttrs do
  context 'class macros' do
    before do
      @keys = [:id, :name]
    end

    describe 'accessors' do
      let(:dummy_class) {
        Class.new {
          include EasyAttrs
          accessors :id, :name
        }
      }

      before do
        @instance = dummy_class.new
      end

      it 'creates reader methods for the keys specified in `accessors`' do
        @keys.each do |key|
          expect(
            @instance.respond_to? key
          ).to eq true
        end
      end

      it 'creates writer methods for the keys specified in `accessors`' do
        @keys.each do |key|
          expect(
            @instance.respond_to? "#{key}="
          ).to eq true
        end
      end
    end

    describe 'readers' do
      let(:dummy_class) {
        Class.new {
          include EasyAttrs
          readers :id, :name
        }
      }

      before do
        @instance = dummy_class.new
      end

      it 'creates reader methods for the keys specified in `readers`' do
        @keys.each do |key|
          expect(
            @instance.respond_to? key
          ).to eq true
        end
      end

      it 'does not create writer methods for the keys specified in `readers`' do
        @keys.each do |key|
          expect(
            @instance.respond_to? "#{key}="
          ).to eq false
        end
      end
    end

    describe 'writers' do
      let(:dummy_class) {
        Class.new {
          include EasyAttrs
          writers :id, :name
        }
      }

      before do
        @instance = dummy_class.new
      end

      it 'does not create reader methods for the keys specified in `writers`' do
        @keys.each do |key|
          expect(
            @instance.respond_to? key
          ).to eq false
        end
      end

      it 'creates writer methods for the keys specified in `writers`' do
        @keys.each do |key|
          expect(
            @instance.respond_to? "#{key}="
          ).to eq true
        end
      end
    end

    describe 'instance_variables_only' do
      let(:dummy_class) {
        Class.new {
          include EasyAttrs
          instance_variables_only :id, :name
        }
      }

      before do
        @instance = dummy_class.new(id: 1, name: 'moooh')
      end

      it 'does not create reader methods for the keys specified in `instance_variables_only`' do
        @keys.each do |key|
          expect(
            @instance.respond_to? key
          ).to eq false
        end
      end

      it 'does not create writer methods for the keys specified in `instance_variables_only`' do
        @keys.each do |key|
          expect(
            @instance.respond_to? "#{key}="
          ).to eq false
        end
      end

      it 'sets instance variables for the keys specified in `instance_variables_only`' do
        expect(@instance.instance_variable_get('@id')).to eq 1
        expect(@instance.instance_variable_get('@name')).to eq 'moooh'
      end
    end
  end

  context 'with inheritance' do
    let(:grand_parent) {
      Class.new {
        include EasyAttrs

        readers :id, :name
      }
    }

    let(:parent) {
      Class.new(grand_parent) {
        accessors :age
      }
    }

    let(:child) {
      Class.new(parent) {
        readers :school_name
      }
    }

    context 'with only one ancestor including EasyAttrs' do
      before do
        @instance = parent.new(id: 1, name: 'toto', age: 35)
      end

      context 'methods' do
        it 'creates all the methods from the superclass' do
          expect(
            @instance.respond_to?(:id)
          ).to eq true

          expect(
            @instance.respond_to?(:name)
          ).to eq true
        end

        it 'creates the methods for the current class' do
          expect(
            @instance.respond_to?(:age)
          ).to eq true

          expect(
            @instance.respond_to?(:age=)
          ).to eq true
        end
      end

      context 'attributes' do
        it 'creates an instance with the attributes defined in the superclass' do
          expect(@instance.id).to eq 1
          expect(@instance.name).to eq 'toto'
        end

        it 'creates an instance with the attributes defined in the current class' do
          expect(@instance.age).to eq 35
        end
      end
    end

    context 'with more than one ancestor including EasyAttrs' do
      before do
        @instance = child.new(id: 2, name: 'toto junior', age: 5, school_name: 'BAD school')
      end

      context 'methods' do
        it 'creates all the methods from all ancestors' do
          expect(
            @instance.respond_to?(:id)
          ).to eq true

          expect(
            @instance.respond_to?(:name)
          ).to eq true

          expect(
            @instance.respond_to?(:age)
          ).to eq true

          expect(
            @instance.respond_to?(:age=)
          ).to eq true
        end

        it 'creates the methods for the current class' do
          expect(
            @instance.respond_to?(:school_name)
          ).to eq true
        end
      end

      context 'attributes' do
        it 'creates an instance with the attributes defined in all ancestors' do
          expect(@instance.id).to eq 2
          expect(@instance.name).to eq 'toto junior'
          expect(@instance.age).to eq 5
        end

        it 'creates an instance with the attributes defined in the current class' do
          expect(@instance.school_name).to eq 'BAD school'
        end
      end
    end
  end

  describe '#initialize' do
    let(:dummy_class) {
      Class.new {
        include EasyAttrs

        readers :id
        writers :special_flag
        accessors :name, :price
        instance_variables_only :data_needing_transformation
      }
    }

    let(:attributes){
      {
        'id' => 1,
        'special_flag' => true,
        'name' => 'dummy',
        'price' => 45,
        'data_needing_transformation' => {
          nested_coconuts: { non_nested_coconuts: 5 }
        },
        'totally_irrelevant_key' => { booooh: true }
      }
    }

    let(:relevant_keys){
      attributes.keys - ['totally_irrelevant_key']
    }

    let(:irrelevant_keys){
      ['totally_irrelevant_key']
    }

    shared_examples 'sets instance variables' do
      context 'fors keys present in instance_variables_only, readers, writers or accessors' do
        it 'sets instance variables for each key' do
          relevant_keys.each do |key|
            expect(
              instance.instance_variable_get("@#{key}")
            ).to eq attributes[key]
          end
        end
      end

      context 'fors keys not present in instance_variables_only, readers, writers or accessors' do
        it 'does not set instance variables' do
          irrelevant_keys.each do |key|
            expect(
              instance.instance_variable_get("@#{key}")
            ).to_not eq attributes[key]
          end
        end
      end
    end

    context 'when input is json' do
      before do
        @instance = dummy_class.new(attributes.to_json)
      end

      it_behaves_like 'sets instance variables' do
        let(:instance){ @instance }
      end
    end

    context 'when input is a hash' do
      context 'with string keys' do
        context 'that use camel case' do
          before do
            @attrs = attributes.deep_transform_keys { |k| k.to_s.camelize }
            @instance = dummy_class.new(@attrs)
          end

          it_behaves_like 'sets instance variables' do
            let(:instance){ @instance }
          end

          it 'transforms the nested hash keys to snake case symbols' do
            # confirm input is camel case all the way down
            expect(
              @attrs['DataNeedingTransformation']['NestedCoconuts']['NonNestedCoconuts']
            ).to eq 5

            expect(
              @instance.instance_variable_get('@data_needing_transformation')
            ).to eq({ nested_coconuts: { non_nested_coconuts: 5 } })
          end
        end

        context 'that use snake case' do
          before do
            @instance = dummy_class.new(attributes)
          end

          it_behaves_like 'sets instance variables' do
            let(:instance){ @instance }
          end
        end
      end

      context 'with symbol keys' do
        before do
          @instance = dummy_class.new(attributes.deep_symbolize_keys)
        end

        it_behaves_like 'sets instance variables' do
          let(:instance){ @instance }
        end
      end
    end

    # This is probably overkill but there was a bug in the first implementation
    # which ended up creating a stack overflow error and initializing lots of
    # objects took an absurd amount of time. Just making sure future changes do
    # not create the issue again.
    #
    # For reference, the same benchmark with a sub class of ActiveRecord takes
    # about 18 seconds (using ::new).
    #
    context 'time taken' do
      before do
        @total_iterations = 100_000
      end

      context 'when passed a Hash' do
        it 'initializes objects in a reasonable amount of time' do
          b = Benchmark.measure do
            @total_iterations.times { dummy_class.new(attributes) }
          end

          expect(b.real < 3).to eq true
        end
      end

      context 'when passed a Json string' do
        it 'initializes objects in a reasonable amount of time' do
          json_attrs = attributes.to_json

          b = Benchmark.measure do
            @total_iterations.times { dummy_class.new(json_attrs) }
          end

          expect(b.real < 4).to eq true
        end
      end

      context 'when passed a Hash with camel case keys' do
        it 'initializes objects in a reasonable amount of time' do
          camel_attrs = attributes.deep_transform_keys { |k| k.to_s.camelize }

          b = Benchmark.measure do
            @total_iterations.times { dummy_class.new(camel_attrs) }
          end

          expect(b.real < 9).to eq true
        end
      end

      context 'when passed a Json string with camel case keys' do
        it 'initializes objects in a reasonable amount of time' do
          camel_json_attrs = attributes.deep_transform_keys do |k|
            k.to_s.camelize
          end.to_json

          b = Benchmark.measure do
            @total_iterations.times { dummy_class.new(camel_json_attrs) }
          end

          expect(b.real < 10).to eq true
        end
      end
    end
  end
end
