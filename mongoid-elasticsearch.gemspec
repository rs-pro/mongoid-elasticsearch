# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongoid/elasticsearch/version'

Gem::Specification.new do |spec|
  spec.name          = "mongoid-elasticsearch"
  spec.version       = Mongoid::Elasticsearch::VERSION
  spec.authors       = ["glebtv"]
  spec.email         = ["glebtv@gmail.com"]
  spec.description   = %q{Simple and easy integration of mongoid with the new elasticsearch gem}
  spec.summary       = %q{Simple and easy integration of mongoid with the new elasticsearch gem}
  spec.homepage      = "https://github.com/rs-pro/mongoid-elasticsearch"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "mongoid", [">= 3.0", "< 6.0"]
  spec.add_dependency "elasticsearch", "~> 1.0.13"
  spec.add_dependency "ruby-progressbar"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "kaminari"
  # spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "hashie"
  spec.add_development_dependency "mongoid-slug", '~> 5.0.0'
  spec.add_development_dependency "glebtv-httpclient"
end
