
# EasyAttrs

## Why EasyAttrs?
The goal of EasyAttrs is to facilitate object instantiation with, you guessed it, attributes. More specifically, EasyAttrs was first built to deal with very large JSON response from an external API where the application only needed some of the attributes in that JSON and the number of keys in the JSON could change at any time.

I often find that a good example is worth a thousand words so here goes.

The typical way to initialize a Ruby object is to pass it a list of attributes and then use those values to build your business logic and public methods.
```ruby
class MyObject
  attr_reader :id, :name

  def initialize id, name, address
    @id = id
    @name = name
    @address = address
  end

  def street_address
    @address.split('\n').first if @address
  end
end

obj = MyObject.new(1, 'object', '123 infinite loop\n94100 San Francisco')

MyObject.new(1, 'object')
=> ArgumentError: wrong number of arguments

MyObject.new(1, 'object', 'address', 'status')
=> ArgumentError: wrong number of arguments
```

EasyAttrs makes all this boilerplate code go away, saving you time so you can focus on the core business logic.

```ruby
class MyEasyObject
  include EasyAttrs

  readers :id, :name
  instance_variables_only :address

  def street_address
    @address.split('\n').first if @address
  end
end

easy_obj = MyEasyObject.new(id: 1, name: 'easy', address: '123 infinite loop\n94100 San Francisco')

# Any number of arguments is valid
MyEasyObject.new(id: 1)
MyEasyObject.new()
MyEasyObject.new(id: 1, name: 'easy', status: 'good', age: 35)
```
EasyAttrs only keeps attributes specified in the `instance_variables_only`, `accessors`, `writers` and `readers` class macros and discards all other keys in the raw_input, keeping the memory footprint small.

`accessors`, `writers` and `readers` are self explanatory and any symbol passed to it will be made an `attr_accessor`, `attr_writer` or `attr_reader`.

`instance_variables_only` is here in case the including class needs access to a specific key in the raw_input but does not want to make this a public method (accessor/reader/writer). It creates an instance variable for the symbol/string passed in whose value is the value under that key in the raw_input. See the `Ghost` class further down for an example of how it is used.

## Usage
Run this in your terminal:
```
gem install easy_attrs
```

or add it to your Gemfile:
```
gem 'easy_attrs'
```

Specify the `instance_variables_only`, `accessors`, `writers` and `readers` the including class will use and EasyAttrs will create the methods or variables for it. Any of those class macros can be left out.
```ruby
   class Bunny
     include EasyAttrs

     readers :id, :name
   end
```
This will create the `id` and `name` readers on the class based on the raw_input and every other key in the input will be unused.
```ruby
$ json = {id: 1, name: 'Bugs Bunny', other_key: 'other_value'}.to_json
$ Bunny.new(json)
=> #<Bunny:0x007faef0f2f930 @id=1, @name="Bugs Bunny">
```

Here is a slightly more complex example with `@instance_variables_only`:

```ruby
class Ghost
  include EasyAttrs

  readers :id, :category
  accessors :name
  instance_variables_only :nested_data

  def family
    if @nested_data && @nested_data[:family_members]
      @nested_data[:family_members].map(&:upcase)
    end
  end
end
```
Note how `instance_variables_only` is used for `:nested_data`. We want to use the data contained under the nested_data key in the raw_input but we want to transform the data before exposing it to the outside world. The transformation is done in the `family` public method.

Another thing to note is that if a class defines some attributes (`readers` for example) then all subclasses of that class will automatically have the those `readers` created and the values set on `initialize` (see below for an example).

```ruby
class Ghost
  include EasyAttrs

  readers :id, :name
end

class BetterGhost < Ghost
  accessors :age
end
```
```ruby
$ BetterGhost.new(id: 1, name: 'Better Ghost', age: 250)
=> #<BetterGhost:0x007faef0f2f930 @id=1, @name="Better Ghost", @age=250>
```
```ruby
class EvenBetterGhost < BetterGhost
  readers :category
end
```
```ruby
$ EvenBetterGhost.new(id: 1, name: 'Better Ghost', age: 250, category: 'BOOOH')
=> #<EvenBetterGhost:0x007fbb10371978 @category="BOOOH", @id=1, @name="Better Ghost", @age=250>
```

Note on input format:
Classes including EasyAttrs can be initialized with the following:
 - A regular `Hash` with symbol keys
 - A regular `Hash` with string keys
 - A regular `Hash` with camel case keys
 - A JSON string
 - A JSON string with camel case keys

In all cases, the input will be converted to a `Hash` with snake case symbols as keys.

## Going further
In this section I'll describe how I used EasyAttrs in a real world, Production application.

The problem I was trying to solve is the one I described in the # WHY section (to deal with very large JSON response from an external API where the application only needed some of the attributes in that JSON and the number of keys in the JSON could change at any time).

I was working with an API to read and write objects which had no data validation on writes and returned very large objects on reads. This was inside a Rails application so I wanted ActiveRecord-like behavior. I created a `MyAppBase` class that all my models would inherit from (think `ActiveRecord::Base`) where I included all the modules I needed. It looked roughly like this:
```ruby
class MyAppBase
  include ActiveModel::Dirty
  include ActiveModel::Validations

  include MyApiClient
  include EasyAttrs
end
```
Here we're getting validations "for free" by simply using `ActiveModel::Validations` and I also needed to track object changes for auditing purposes so I included `ActiveModel::Dirty`.

The data access layer was provided by `MyApiClient` which was simply calling the API and returning raw JSON. See a stripped down version below:
```ruby
class MyApiClient
  class << self
    def get_object uri, id
      #...
    end

    def put_object uri, id
      #...
    end

    def post_object uri, id
      #...
    end
  end
end
```
Finally here's an example of a class to tie it all together:
```ruby
class Bunny < MyAppBase

  GET_URI = '/bunny'

  readers :id, :name, :number_of_ears
  accessors :status
  instance_variables_only :family_history

  define_attribute_methods :number_of_ears

  validate :number_of_ears_must_be_positive

  class << self
    def find id
      raw_data = get_object(GET_URI, id)
      raw_data.present? ? new(raw_data) : nil
    end
  end

  def health_history
    # Like @family_history[:details][:health_history] but handles nil
    @family_history.dig(:details, :health_history)
  end

  # Can't use a simple `writer` here because we're tracking changes to :number_of_ears
  def number_of_ears= value
    if value != number_of_ears
      number_of_ears_will_change!
      @number_of_ears = value
    end
  end

  private

  def number_of_ears_must_be_positive
    if number_of_ears && number_of_ears < 0
      errors.add(:number_of_ears, "must be positive")
    end
  end
end
```
