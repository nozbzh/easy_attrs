
# EasyAttrs

## Why EasyAttrs?
Have you ever had to build objects from an API response and thought "there has to be an easier way"?

EasyAttrs takes care of the boilerplate code of setting instance variables and defining `attr_*` methods (`attr_reader`, `attr_writer`, `attr_accessor`) so you can focus on writing your core business logic.

Objects built with EasyAttrs can be passed a JSON string or a simple Ruby Hash.

If you're thinking "This sounds like `ActiveModel`" you're not far off. `ActiveModel` comes with a lot of great modules and I love it (see the [Going Further](#going-further) section below). But what if you don't need all those modules? Then EasyAttrs could be exactly what you need.

Another reason why `ActiveModel` did not solve the problem I was facing is that it will raise an error when passed a key that is not defined as an `accessor`. I wanted my objects to select the relevant attributes from the input and discard the rest.
This is for 2 reasons: 1) the API I was working with was liable to add/remove keys irrelevant to my use case and I didn't want to have to deploy new code every time it happened and 2) if an API returns an object with 30 keys and I only need 3, why would I store all those useless key/values pairs in memory?

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

# This initialize is fragile and will break unless the right number of arguments is passed.
MyObject.new(1, 'object')
=> ArgumentError: wrong number of arguments

MyObject.new(1, 'object', 'address', 'status')
=> ArgumentError: wrong number of arguments

# Of course this can be fixed by passing a hash to initialize, but you still have to assign
# each instance variable one by one.
```
It can be made much more compact with `ActiveModel` (note that every attribute *has* to be defined as an accessor so there is no out of the box read_only or write_only):
```ruby
class MyActiveObject
  include ActiveModel::Model
  attr_accessor :id, :name, :address
	
  def street_address
    @address.split('\n').first if @address
  end
end

active_obj = MyActiveObject.new(id: 1, name: 'active', address: '123 infinite loop\n94100 San Francisco')

# Unfortunately, it raises an error when an unknown key is part of the input
MyActiveObject.new(id: 1, name: 'active', address: '123 infinite loop\n94100 San Francisco', age: 75)
=> ActiveModel::UnknownAttributeError: unknown attribute 'age' for MyActiveObject.
```

EasyAttrs makes all this boilerplate code go away (just like `ActiveModel`), but it also allows you to define read_only/write_only attributes as well as plain old instance variables that you can reuse in your custom methods. And it doesn't raise an error when an unknown key is passed.

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
# or
json = {id: 1, name: 'easy', address: '123 infinite loop\n94100 San Francisco'}.to_json
easy_obj = MyEasyObject.new(json)

easy_obj.id
=> 1
easy_obj.name
=> 'easy'
easy_obj.address
=> NoMethodError
easy_obj.street_address
=> '123 infinite loop'

# Any number of arguments is valid
MyEasyObject.new(id: 1)
MyEasyObject.new()
MyEasyObject.new(id: 1, name: 'easy', status: 'good', age: 35)
```
EasyAttrs only keeps attributes specified in the `instance_variables_only`, `accessors`, `writers` and `readers` class macros and discards all other keys in the raw_input, keeping the memory footprint small.

`accessors`, `writers` and `readers` are self explanatory and any symbol passed to it will be made an `attr_accessor`, `attr_writer` or `attr_reader`.

`instance_variables_only` is here in case the including class needs access to a specific key in the raw_input but does not want to make this a public method (accessor/reader/writer). It creates an instance variable for the symbol passed in whose value is the value under that key in the raw_input. See the `Ghost` class further down for an example of how it is used.

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
This will create the `id` and `name` readers on the class based on the raw_input and every other key in the input will be discarded, making the object lightweight.
```ruby
$ json = {id: 1, name: 'Bugs Bunny', other_key: 'other_value'}.to_json
$ b = Bunny.new(json)
=> #<Bunny:0x007faef0f2f930 @id=1, @name="Bugs Bunny">
b.id
=> 1
b.name
=> 'Bugs Bunny`
b.other_key
=> NoMethodError
```

Here is a slightly more complex example with `@instance_variables_only`:

```ruby
class Ghost
  include EasyAttrs

  readers :id, :age
  accessors :name
  instance_variables_only :nested_data

  def family
    if @nested_data && @nested_data[:family_members]
      @nested_data[:family_members].map(&:upcase)
    end
  end
end

attributes = {id:  1, name:  'Casper', age:  150, nested_data: {family_members: ['old ghost', 'older ghost']}}
g = Ghost.new(attributes)
g.id
=> 1
g.age
=> 150
g.name
=> 'Casper'
g.name = 'old casper'
g.name
=> 'old casper'
g.family_members
=> NoMethodError
g.family
=> ['OLD GHOST', 'OLDER GHOST']
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

$ BetterGhost.new(id: 1, name: 'Better Ghost', age: 250)
=> #<BetterGhost:0x007faef0f2f930 @id=1, @name="Better Ghost", @age=250>
```
```ruby
class EvenBetterGhost < BetterGhost
  readers :category
end

$ EvenBetterGhost.new(id: 1, name: 'Better Ghost', age: 250, category: 'BOOOH')
=> #<EvenBetterGhost:0x007fbb10371978 @category="BOOOH", @id=1, @name="Better Ghost", @age=250>
```

Note on input format. Classes including EasyAttrs can be initialized with the following:
 - A regular `Hash` with symbol keys
 - A regular `Hash` with string keys
 - A regular `Hash` with camel case keys
 - A JSON string
 - A JSON string with camel case keys

In all cases, the input will be converted to a `Hash` with snake case symbols as keys.

## Going further
In this section I'll describe how I used EasyAttrs in a real world production application.

The problem I was trying to solve is the one I described in the [Why EasyAttrs](#why-easyattrs) section (build objects from an API response). More specifically, I had to deal with very large JSON responses from an external API where the application only needed some of the attributes in that JSON and the number of keys in the JSON could change at any time.

The API I was working with let me read and write objects but it had no data validation on writes and returned very large objects on reads. This was inside a Rails application so I wanted ActiveRecord-like behavior. I created a `MyAppBase` class that all my models would inherit from (think `ActiveRecord::Base`) where I included all the modules I needed. It looked roughly like this:
```ruby
class MyAppBase
  include ActiveModel::Dirty
  include ActiveModel::Validations

  include MyApiClient
  include EasyAttrs
end
```
Here we're getting validations "for free" by simply using `ActiveModel::Validations` and I also needed to track object changes for auditing purposes so I included `ActiveModel::Dirty` (it lets you call `my_model.changes` to see all the object changes).

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
    if number_of_ears && number_of_ears <= 0
      errors.add(:number_of_ears, "must be positive")
    end
  end
end
```
