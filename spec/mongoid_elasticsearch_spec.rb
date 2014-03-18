# coding: utf-8
require "spec_helper"

describe Article do
  it 'properly uses options' do
    Article.es_index_name.should eq 'mongoid_es_news'
    Article.es.index.name.should eq 'mongoid_es_news'
    Article.es.index.type.should eq 'article'
    Article.es_wrapper.should eq :load
    Article.es_client_options.should eq(DEFAULT_OPT)
  end

  context 'index operations' do
    it 'creates and destroys index' do
      Article.es.index.exists?.should be_true
      Article.es.index.delete
      Article.es.index.exists?.should be_false
      Article.es.index.create
      Article.es.index.exists?.should be_true
    end
  end

  context 'adding to index' do
    it 'successfuly saves mongoid document' do
      article = Article.new(name: 'test article name')
      article.save.should be_true
    end
  end

  context 'deleting from index' do
    it 'deletes document from index when model is destroyed' do
      Article.create(name: 'test article name')
      Article.es.index.refresh
      Article.es.all.count.should eq 1

      Article.first.destroy
      Article.es.index.refresh
      Article.es.all.count.should eq 0
    end
  end

  context 'searching' do
    before :each do
      @article_1 = Article.create!(name: 'test article name likes', tags: 'likely')
      @article_2 = Article.create!(name: 'tests likely an another article title')
      @article_3 = Article.create!(name: 'a strange name for this stuff')
      
      if defined?(Moped::BSON)
        @post_1 = Post.create!(name: 'object_id', my_object_id: Moped::BSON::ObjectId.new)
      else
        @post_1 = Post.create!(name: 'object_id', my_object_id: BSON::ObjectId.new)
      end
      
      
      Article.es.index.refresh
      Post.es.index.refresh
    end

    it 'searches and returns models' do
      results = Article.es.search q: 'likely'
      results.count.should eq 1
      results.to_a.count.should eq 1
      results.first.id.should eq @article_2.id
      results.first.name.should eq @article_2.name
    end

    it 'mongoid_slug with wrapper: :load' do
      results = Article.es.search q: 'likely'
      expect(Article).to receive(:find).once.with([@article_2.id.to_s]).and_call_original
      results.first.slug.should eq @article_2.name.to_url
      results.first.to_param.should eq @article_2.name.to_url
    end

    it 'mongoid_slug with wrapper: :model' do
      sleep 3
      results = Article.es.search 'likely', wrapper: :model
      sleep 3
      allow(Article).to receive(:find)
      results.first.slug.should eq @article_2.name.to_url
      results.first.to_param.should eq @article_2.name.to_url
      expect(Article).to_not have_received(:find)
    end

    it 'restores BSON::ObjectId with wrapper :model' do
      results = Post.es.search 'object_id'
      if defined?(Moped::BSON)
        results.first.my_object_id.should be_kind_of(Moped::BSON::ObjectId)
      else
        results.first.my_object_id.should be_kind_of(BSON::ObjectId)
      end
      
      results.first.my_object_id.should eq(@post_1.my_object_id)
    end


    if Article.es.completion_supported?
      it 'completion' do
        Article.es.completion('te', 'name.suggest').should eq [
          {"text"=>"test article name likes", "score"=>1.0},
          {"text"=>"tests likely an another article title", "score"=>1.0}
        ]
      end
    else
      pending "completion suggester not supported in ES version #{Article.es.version}"
    end
  end

  context 'pagination' do
    before :each do
      @articles = []
      10.times { @articles << Article.create!(name: 'test') }
      Article.es.index.refresh
    end

    it '#search' do
      Article.es.search('test', per_page: 7, page: 2).to_a.size.should eq 3
    end

    it '#all' do
      result = Article.es.all(per_page: 7, page: 2)
      result.num_pages.should eq 2
      result.current_page.should eq 2
      result.total_entries.should eq 10
      result.previous_page.should eq 1
      result.next_page.should be_nil
      result.to_a.size.should eq 3
      result.out_of_bounds?.should be_false
      result.first_page?.should be_false
      result.last_page?.should be_true
      
      p1 = Article.es.all(per_page: 7, page: 1)
      p1.out_of_bounds?.should be_false
      p1.first_page?.should be_true
      p1.last_page?.should be_false
      p1.current_page.should eq 1
      p1.next_page.should eq 2

      p3 = Article.es.all(per_page: 7, page: 3)
      p3.out_of_bounds?.should be_true

      p1.length.should eq 7
      all = (result.to_a + p1.to_a).map(&:id).map(&:to_s).sort
      all.length.should eq 10
      all.should eq @articles.map(&:id).map(&:to_s).sort
    end
  end

  context 'destroy' do
    before :each do
      @articles = []
      10.times { @articles << Article.create!(name: 'test') }
      Article.es.index.refresh
    end
    it '#destroy' do
      Article.es.all.count.should eq 10
      @articles[0].destroy
      Article.es.index.refresh
      Article.es.all.count.should eq 9
    end
    it '#destroy_all' do
      Article.es.all.count.should eq 10
      Article.destroy_all
      Article.es.index.refresh
      Article.es.all.count.should eq 0
    end
  end
end


describe Post do
  it 'properly uses options' do
    Post.es_index_name.should eq 'mongoid_es_test_posts'
    Post.es_wrapper.should eq :model
    Post.es_client_options.should eq(DEFAULT_OPT)
  end

  context 'index operations' do
    it 'does not create index with empty definition (ES will do it for us)' do
      Post.es.index.exists?.should be_false
      Post.es.index.create
      Post.es.index.exists?.should be_false
    end
    it 'ES autocreates index on first index' do
      Post.es.index.exists?.should be_false
      Post.create!(name: 'test post')
      Post.es.index.exists?.should be_true
    end
  end

  context 'adding to index' do
    it 'successfuly saves mongoid document' do
      article = Post.new(name: 'test article name')
      article.save.should be_true
    end
  end

  context 'searching' do
    before :each do
      @post_1 = Post.create!(name: 'test article name')
      @post_2 = Post.create!(name: 'another article title')
      Post.es.index.refresh
    end

    it 'searches and returns models' do
      Post.es.search('article').first.class.should eq Post
      sleep 1
      Post.es.search('article').count.should eq 2
      Post.es.search('another').count.should eq 1
      Post.es.search('another').first.id.should eq @post_2.id
    end
  end

  context 'pagination' do
    before :each do
      10.times { Post.create(name: 'test') }
      Post.es.index.refresh
    end

    it '#search' do
      Post.es.search('test').size.should eq 10
      Post.es.search('test', per_page: 7, page: 2).to_a.size.should eq 3
    end

    it '#all' do
      Post.es.all.size.should eq 10
      Post.es.all(per_page: 7, page: 2).to_a.size.should eq 3
    end
  end
end

describe Nowrapper do
  it 'properly uses options' do
    Nowrapper.es_index_name.should eq 'mongoid_es_test_nowrappers'
    Nowrapper.es_wrapper.should eq :none
  end

  context 'searching' do
    before :each do
      @post_1 = Nowrapper.create!(name: 'test article name')
      @post_2 = Nowrapper.create!(name: 'another article title')
      Nowrapper.es.index.refresh
    end

    it 'searches and returns hashes' do
      # #count uses _count
      Nowrapper.es.search('article').count.should eq 2
      # #size and #length fetch results
      Nowrapper.es.search('article').length.should eq 2
      Nowrapper.es.search('article').first.class.should eq Hash
    end
  end
end

describe "Multisearch" do
  before :each do
    @post_1 = Post.create!(name: 'test article name')
    Post.es.index.refresh

    @article_1 = Article.create!(name: 'test article name likes', tags: 'likely')
    @article_2 = Article.create!(name: 'test likely an another article title')
    Article.es.index.refresh

    @ns_1 = Namespaced::Model.create!(name: 'test article name likes')
    Namespaced::Model.es.index.refresh
  end

  it 'works' do
    response = Mongoid::Elasticsearch.search 'test'
    #p response
    #pp response.results
    #pp response.raw_response
    #pp @article_1
    response.length.should eq 4
    response.to_a.map(&:class).map(&:name).uniq.sort.should eq ['Article', 'Namespaced::Model', 'Post']
    response.select { |r| r.class == Article && r.id == @article_1.id }.first.should_not be_nil
  end

  it '#multi_with_load' do
    response = Mongoid::Elasticsearch.search 'test', wrapper: :load
    response.length.should eq 4
    response.to_a.map(&:class).map(&:name).uniq.sort.should eq ['Article', 'Namespaced::Model', 'Post']
    response.select { |r| r.class == Article && r.id == @article_1.id }.first.should_not be_nil
  end
end

describe Namespaced::Model do
  it 'properly uses options' do
    Namespaced::Model.es_index_name.should eq 'mongoid_es_test_namespaced_models'
    Namespaced::Model.es.index.name.should eq 'mongoid_es_test_namespaced_models'
    Namespaced::Model.es.index.type.should eq 'namespaced/model'
    Namespaced::Model.es_wrapper.should eq :model
    Namespaced::Model.es_client_options.should eq(DEFAULT_OPT)
  end

  context 'index operations' do
    it 'creates and destroys index' do
      Namespaced::Model.es.index.exists?.should be_true
      Namespaced::Model.es.index.delete
      Namespaced::Model.es.index.exists?.should be_false
      Namespaced::Model.es.index.create
      Namespaced::Model.es.index.exists?.should be_true
    end
  end

  context 'adding to index' do
    it 'successfuly saves mongoid document' do
      article = Namespaced::Model.new(name: 'test article name')
      article.save.should be_true
    end
    it 'successfuly destroys mongoid document' do
      article = Namespaced::Model.create(name: 'test article name')
      Namespaced::Model.es.index.refresh
      Namespaced::Model.es.all.count.should eq 1
      article.destroy
      Namespaced::Model.es.index.refresh
      Namespaced::Model.es.all.count.should eq 0
    end
  end

  context 'searching' do
    before :each do
      @article_1 = Namespaced::Model.create!(name: 'test article name likes')
      @article_2 = Namespaced::Model.create!(name: 'tests likely an another article title')
      @article_3 = Namespaced::Model.create!(name: 'a strange name for this stuff')
      Namespaced::Model.es.index.refresh
    end

    it 'searches and returns models' do
      results = Namespaced::Model.es.search q: 'likely'
      results.count.should eq 1
      results.to_a.count.should eq 1
      results.first.id.should eq @article_2.id
      results.first.name.should eq @article_2.name
    end
  end

  context 'pagination' do
    before :each do
      Namespaced::Model.es.index.reset
      @articles = []
      20.times { @articles << Namespaced::Model.create!(name: 'test') }
      @a1 = Namespaced::Model.create!(name: 'irrelevant')
      @a2 = Namespaced::Model.create!(name: 'unmatched')
      Namespaced::Model.es.index.refresh
    end

    it '#search ignores irrelevant' do
      Namespaced::Model.es.search('irrelevant').to_a.size.should eq 1
      Namespaced::Model.es.search('test', per_page: 30).to_a.size.should eq 20
    end

    it '#search dynamic wrapper' do
      Namespaced::Model.es.search('test', wrapper: :hash).map(&:class).map(&:name).uniq.should eq ['Hash']
      Namespaced::Model.es.search('test', wrapper: :mash).map(&:class).map(&:name).uniq.should eq ['Hashie::Mash']
      Namespaced::Model.es.search('test', wrapper: :mash).first.name.should eq 'test'
    end

    it '#search' do
      Namespaced::Model.es.search('test', per_page: 10, page: 2).to_a.size.should eq 10
      Namespaced::Model.es.search('test', per_page: 30, page: 2).to_a.size.should eq 0
      Namespaced::Model.es.search('test', per_page: 2, page: 2).to_a.size.should eq 2
      Namespaced::Model.es.search(body: {query: {query_string: {query: 'test'}}}, size: 50).to_a.length.should eq 20
    end

    it 'bulk index' do
      Namespaced::Model.es.index.reset
      Namespaced::Model.es.index_all
      Namespaced::Model.es.index.refresh
      Namespaced::Model.es.search('test', per_page: 10, page: 2).to_a.size.should eq 10
      Namespaced::Model.es.search('test', per_page: 30, page: 2).to_a.size.should eq 0
      Namespaced::Model.es.search('test', per_page: 2, page: 2).to_a.size.should eq 2
      Namespaced::Model.es.search(body: {query: {query_string: {query: 'test'}}}, size: 50).to_a.length.should eq 20
    end


    it '#all' do
      result = Namespaced::Model.es.all(per_page: 7, page: 3)
      result.num_pages.should eq 4
      result.to_a.size.should eq 7
      p1 = Namespaced::Model.es.all(per_page: 7, page: 1).to_a
      p2 = Namespaced::Model.es.all(per_page: 7, page: 2).to_a
      p4 = Namespaced::Model.es.all(per_page: 7, page: 4).to_a
      p1.length.should eq 7
      p2.length.should eq 7
      p4.length.should eq 1
      all = (p1 + p2 + result.to_a + p4).map(&:id).map(&:to_s).sort
      all.length.should eq 22
      all.should eq (@articles + [@a1, @a2]).map(&:id).map(&:to_s).sort
    end
  end
end

describe 'utils' do
  it 'doesnt strip non-ascii text' do
    Mongoid::Elasticsearch::Utils.clean('тест {{').should eq 'тест'
  end
  it 'doesnt strip good white space' do
    Mongoid::Elasticsearch::Utils.clean('test test').should eq 'test test'
  end
  it 'strip extra white space' do
    Mongoid::Elasticsearch::Utils.clean('    test     test    ').should eq 'test test'
  end
end
