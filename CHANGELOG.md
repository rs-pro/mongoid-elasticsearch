## 0.8.1 (March 4, 2014) ##

* New method "Model.without_es_update!" to temporally disable callbacks (ie, for testing) (by [@xronos-i-am](https://github.com/xronos-i-am))

## 0.8.0 (March 4, 2014) ##

* fix results with :load wrapper #6 (by [@xronos-i-am](https://github.com/xronos-i-am))
* Added option to prevent automatic creating of index. #7 (thx [@intrica](https://github.com/intrica))
* use after_initalize to create indexes later in the app boot process

Set Mongoid::Elasticsearch.autocreate_indexes to false in an initalizer to prevent automatic creation for all indexes.

You can always use ```rake es:create``` to create all indexes or call Mongoid::Elasticsearch.create_all_indexes!.

Indexes defined with skip_create: true are not created with all other indexes and must be created manually with Model.es.index.create
