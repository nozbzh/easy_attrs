# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'easy_attrs'
  s.author = 'Noe Stauffert'
  s.email = 'noe.stauffert@gmail.com'
  s.homepage = 'http://www.noestauffert.com'
  s.version = '0.0.1'
  s.date = '2019-11-01'
  s.summary = 'easy_attrs allows you to build objects easily'
  s.add_runtime_dependency 'activesupport', '~> 5.0'
  s.add_development_dependency 'rspec', '~> 3.7'
  s.license = 'MIT'
  s.files = [
    'lib/easy_attrs.rb'
  ]
  s.require_paths = ['lib']
end
