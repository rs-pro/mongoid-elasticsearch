# DEPRECATED - Consider using [SearchKick](https://github.com/ankane/searchkick)

# Mongoid::Elasticsearch

[![Build Status](https://travis-ci.org/rs-pro/mongoid-elasticsearch.png?branch=master)](https://travis-ci.org/rs-pro/mongoid-elasticsearch)
[![Coverage Status](https://coveralls.io/repos/rs-pro/mongoid-elasticsearch/badge.png?branch=master)](https://coveralls.io/r/rs-pro/mongoid-elasticsearch?branch=master)
[![Gem Version](https://badge.fury.io/rb/mongoid-elasticsearch.png)](http://badge.fury.io/rb/mongoid-elasticsearch)
[![Dependency Status](https://www.versioneye.com/user/projects/53e73fe735080d1e4d00009c/badge.svg)](https://www.versioneye.com/user/projects/53e73fe735080d1e4d00009c)
[![Issues](http://img.shields.io/github/issues/rs-pro/mongoid-elasticsearch.svg)](https://github.com/rs-pro/mongoid-elasticsearch/issues)
[![License](http://img.shields.io/:license-mit-blue.svg)](https://github.com/rs-pro/mongoid-elasticsearch/blob/master/MIT-LICENSE.txt)


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

## Alternatives list:

- [Elasticsearch gem](https://github.com/elasticsearch/elasticsearch-ruby) - low-level and hard for simple use-cases
- [(re)Tire](https://github.com/karmi/retire)
- [RubberBand](https://github.com/grantr/rubberband) - EOL, no Mongoid
- [Mebla](https://github.com/cousine/mebla) - long dead

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
    result = Post.es.search body: {query: {...}, facets: {...}} etc
    result.raw_response
    result.results # by default returns an Enumerable with Post instances exactly
                   # like they were loaded from MongoDB
    Post.es.index.create # create index (done automatically on app boot)
    Post.es.index.delete # drop index
    Post.es.index.reset # recreate index
    Post.es.index.refresh # force index update (useful for specs)
    Post.es.client # Elasticsearch::Client instance

### Completion: 

    include Mongoid::Elasticsearch
    elasticsearch! index_mappings: {
      name: {
        type: 'multi_field',
        fields: {
          name: {type: 'string', boost: 10},
          suggest: {type: 'completion'}
        }
      },
      desc: {type: 'string'},
    }

    Post.es.completion('te', 'name.suggest') # requires ES 0.90.3

### Search multiple models:

    # By default only searches in indexes managed by Mongoid::Elasticsearch
    # to ignore other apps indexes in same ES instance
    response = Mongoid::Elasticsearch.search 'test'


search syntax docs: http://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Actions#search-instance_method

ES Actions docs: http://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Actions

ES Indices docs: http://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Indices/Actions

ES docs: http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/index.html

### Advanced:

prefix all app's index names:

    Mongoid::Elasticsearch.prefix = 'my_app'

default options for Elasticsearch::Client.new (url etc)
 
    Mongoid::Elasticsearch.client_options = {hosts: ['localhost']}

index definition options and custom model serialization:

    include Mongoid::Elasticsearch
    elasticsearch!({
      # index name (prefix is added)
      index_name: 'mongoid_es_news',
      
      # don't use global name prefix
      prefix_name: false,
      
      # elasticsearch index definition
      index_options: {},

      # or only mappings with empty options
      index_mappings: {
        name: {
          type: 'multi_field',
          fields: {
            name:     {type: 'string', analyzer: 'snowball'},
            raw:      {type: 'string', index: :not_analyzed},
            suggest:  {type: 'completion'} 
          }
        },
        tags: {type: 'string', include_in_all: false}
      },
      wrapper: :load
    })
    
    # customize what gets sent to elasticsearch:
    def as_indexed_json
      # id field is properly added automatically
      {
        name: name,
        excerpt: excerpt
      }
      # mongoid_slug note: add _slugs to as_indexed_json, NOT slug
    end
    
Example mapping with boost field:

    elasticsearch!({
      index_name: Rails.env.test? ? 'vv_test_articles' : 'vv_articles',
      index_options: {
        settings: {
          index: {
            analysis: {
              analyzer: {
                my_analyzer: {
                  type: "snowball",
                  language: "Russian"
                }
              }
            }
          }
        },
        mappings: {
          "articles/article" => {
            _boost: {name: '_boost', null_value: 1},
            properties: {
              name: {type: 'string', boost: 10, analyzer: 'my_analyzer'},
              tags: {type: 'string', analyzer: 'my_analyzer'}
            }
          }
        }
      },
      wrapper: :load
    })
    
    
[Mapping definition docs](http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/mapping-core-types.html)    

### Pagination

```= paginate @posts``` should work as normal with Kaminari after you do:

    @posts = Post.es.search(params[:search], page: params[:page])
    # or
    @posts = Post.es.search({
      body: {
        query: {
          query_string: {
            query: params[:search]
          }
        },
        filter: {
          term: {community_id: @community.id.to_s}
        }
      }},
      page: params[:page], wrapper: :load
    )

### Reindexing

#### All models

```rake es:reindex``` will reindex all indices managed by Mongoid::Elasticsearch

#### One model - Simple bulk

This is the preferred (fastest) method to reindex everything
    
    Music::Video.es.index_all

#### One model - Simple

    Communities::Thread.es.index.reset
    Communities::Thread.enabled.each do |ingr|
      ingr.es_update
    end

### Possible wrappers for results:

- :hash - raw hash from ES
- :mash - [Hashie::Mash](https://github.com/intridea/hashie#mash) (gem '[hashie](https://github.com/intridea/hashie)' must be added to gemfile)
- :load - load each found model by ID from database
- :model - create a model instance from data stored in elasticsearch

See more examples in specs.

### Index creation

This gem by default automatically creates indexes for all configured models on application startup.

Set ```Mongoid::Elasticsearch.autocreate_indexes = false``` in an initalizer to prevent automatic creation for all indexes.

You can always use ```rake es:create``` to create all indexes or call ```Mongoid::Elasticsearch.create_all_indexes!```.

Indexes defined with option ```skip_create: true``` are not created with all other indexes and must be created manually with ```Model.es.index.create```


#### Util

    # Escape string so it can be safely passed to ES (removes all special characters)
    Mongoid::Elasticsearch::Utils.clean(s)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
