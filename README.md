# Mongoid::Elasticsearch

[![Build Status](https://travis-ci.org/rs-pro/mongoid-elasticsearch.png?branch=master)](https://travis-ci.org/rs-pro/mongoid-elasticsearch)
[![Coverage Status](https://coveralls.io/repos/rs-pro/mongoid-elasticsearch/badge.png?branch=master)](https://coveralls.io/r/rs-pro/mongoid-elasticsearch?branch=master)
[![Gem Version](https://badge.fury.io/rb/mongoid-elasticsearch.png)](http://badge.fury.io/rb/mongoid-elasticsearch)
[![Dependency Status](https://gemnasium.com/rs-pro/mongoid-elasticsearch.png)](https://gemnasium.com/rs-pro/mongoid-elasticsearch)


Use [Elasticsearch](http://www.elasticsearch.org/) with mongoid with just a few
lines of code

Allows easy usage of [the new Elasticsearch gem](https://github.com/elasticsearch/elasticsearch-ruby)
with [Mongoid 4](https://github.com/mongoid/mongoid)

## Features

- Uses new elasticsearch gem
- Has a simple high-level API
- No weird undocumented DSL, just raw JSON for queries and index definitions
- Allows for full power of elasticsearch when it's necessary
- Indexes are automatically created if they don't exist on app boot
- Works out of the box with zero configuration
- Multi-model search with real model instances and pagination
- Whole test suite is run against a real ES instance, no mocks

This gem is very simple and does not try hide any part of the ES REST api, it
  just adds some shortcuts for prefixing index names, automatic updating of the index
  when models are added\changed, search with pagination, wrapping results in
  a model instance, ES 0.90.3 new completion suggester, etc (new features coming
  soon)

## Why use it (alternatives list):

- [(re)Tire](https://github.com/karmi/retire) - retired
- [RubberBand](https://github.com/grantr/rubberband) - EOL
- [Elasticsearch gem](https://github.com/elasticsearch/elasticsearch-ruby) - too low-level and complex

## Installation

Add this line to your application's Gemfile:

    gem 'mongoid-elasticsearch'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mongoid-elasticsearch

## Usage

### Basic:

    class Post
      include Mongoid::Document
      include Mongoid::Elasticsearch
      elasticsearch!
    end

    Post.es.search 'test text' # shortcut for Post.es.search({q: 'test text'})
    result = Post.es.search query: {...}, facets: {...} etc
    result.raw_response
    result.results # by default returns an Enumerable with Post instances exactly
                   # like they were loaded from MongoDB
    Post.es.index.create # create index (done automatically on app boot)
    Post.es.index.destroy # drop index
    Post.es.index.reset # recreate index
    Post.es.index.refresh # force index update (useful for specs)
    Post.es.client # Elasticsearch::Client instance
    Post.es.completion('te') # requires ES 0.90.3

    # Search multiple models
    # By default only searches in indexes managed by Mongoid::Elasticsearch
    # to ignore other apps indexes in same ES instance
    response = Mongoid::Elasticsearch.search 'test'


more docs: http://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Actions

ES docs: http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/index.html

### Advanced:

    include Mongoid::Elasticsearch
    # define index_options (raw elasticsearch index definition
    # 
    elasticsearch! index_name: 'mongoid_es_news', prefix_name: false, index_options: {}, index_mappings: {
      name: {
        type: 'multi_field',
        fields: {
          name:     {type: 'string', analyzer: 'snowball'},
          raw:      {type: 'string', index: :not_analyzed},
          suggest:  {type: 'completion'} 
        }
      },
      tags: {type: 'string', include_in_all: false}
    }, wrapper: :load
    # customize what gets sent to elasticsearch:
    def as_indexed_json
      # id field is properly added automatically
      {
        name: name,
        excerpt: excerpt
      }
    end
    
See more examples in specs.
    
## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
