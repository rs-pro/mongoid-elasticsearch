# encoding: utf-8

require "spec_helper"

describe Article do
  it 'properly uses options' do
    expect(Article.es_index_name).to eq 'mongoid_es_news'
    expect(Article.es.index.name).to eq 'mongoid_es_news'
    expect(Article.es_index_type).to eq 'article'
    expect(Article.es.index.type).to eq 'article'
    expect(Article.es_wrapper).to eq :load
    expect(Article.es_client_options).to eq(DEFAULT_OPT)
  end

  context 'index operations' do
    it 'creates and destroys index' do
      expect(Article.es.index.exists?).to be_truthy
      Article.es.index.delete
      expect(Article.es.index.exists?).to be_falsey
      Article.es.index.create
      expect(Article.es.index.exists?).to be_truthy
    end
  end

  context 'adding to index' do
    it 'successfuly saves mongoid document' do
      article = Article.new(name: 'test article name')
      expect(article.save).to be_truthy
    end
  end

  context 'deleting from index' do
    it 'deletes document from index when model is destroyed' do
      Article.create(name: 'test article name')
      Article.es.index.refresh
      expect(Article.es.all.count).to eq 1

      Article.first.destroy
      Article.es.index.refresh
      expect(Article.es.all.count).to eq 0
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
      expect(results.count).to eq 1
      expect(results.to_a.count).to eq 1
      expect(results.first.id).to eq @article_2.id
      expect(results.first.name).to eq @article_2.name
    end

    it 'mongoid_slug with wrapper: :load' do
      results = Article.es.search q: 'likely'
      expect(Article).to receive(:find).once.with([@article_2.id.to_s]).and_call_original
      expect(results.first.slug).to eq @article_2.name.to_url
      expect(results.first.to_param).to eq @article_2.name.to_url
    end

    it 'mongoid_slug with sort and wrapper: :load' do
      results = Article.es.search body: { query: { match_all: {} }, sort: { 'name.raw' => 'desc' } }
      expect(results.map( &:id )).to eq Article.all.desc( :name ).map( &:id )
    end

    it 'mongoid_slug with wrapper: :model' do
      sleep 3
      results = Article.es.search 'likely', wrapper: :model
      sleep 3
      allow(Article).to receive(:find)
      expect(results.first.slug).to eq @article_2.name.to_url
      expect(results.first.to_param).to eq @article_2.name.to_url
      expect(Article).to_not have_received(:find)
    end

    it 'restores BSON::ObjectId with wrapper :model' do
      results = Post.es.search 'object_id'
      if defined?(Moped::BSON)
        expect(results.first.my_object_id).to be_kind_of(Moped::BSON::ObjectId)
      else
        expect(results.first.my_object_id).to be_kind_of(BSON::ObjectId)
      end
      
      expect(results.first.my_object_id).to eq(@post_1.my_object_id)
    end


    if Article.es.completion_supported?
      it 'completion' do
        expect(Article.es.completion('te', 'name.suggest')).to eq [
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
      expect(Article.es.search('test', per_page: 7, page: 2).to_a.size).to eq 3
    end

    it 'paging works with empty results' do
      result = Article.es.search('bad_request', per_page: 7, page: 1)
      expect(result.num_pages).to eq 0
      expect(result.current_page).to eq 1
      expect(result.total_entries).to eq 0
      expect(result.previous_page).to be_nil
      expect(result.next_page).to be_nil
      expect(result.to_a.size).to eq 0
      expect(result.out_of_bounds?).to be_truthy
      expect(result.first_page?).to be_truthy
      expect(result.last_page?).to be_truthy
    end

    it '#all' do
      result = Article.es.all(per_page: 7, page: 2)
      expect(result.num_pages).to eq 2
      expect(result.current_page).to eq 2
      expect(result.total_entries).to eq 10
      expect(result.previous_page).to eq 1
      expect(result.next_page).to be_nil
      expect(result.to_a.size).to eq 3
      expect(result.out_of_bounds?).to be_falsey
      expect(result.first_page?).to be_falsey
      expect(result.last_page?).to be_truthy
      
      p1 = Article.es.all(per_page: 7, page: 1)
      expect(p1.out_of_bounds?).to be_falsey
      expect(p1.first_page?).to be_truthy
      expect(p1.last_page?).to be_falsey
      expect(p1.current_page).to eq 1
      expect(p1.next_page).to eq 2

      p3 = Article.es.all(per_page: 7, page: 3)
      expect(p3.out_of_bounds?).to be_truthy

      expect(p1.length).to eq 7
      all = (result.to_a + p1.to_a).map(&:id).map(&:to_s).sort
      expect(all.length).to eq 10
      expect(all).to eq @articles.map(&:id).map(&:to_s).sort
    end
  end

  context 'destroy' do
    before :each do
      @articles = []
      10.times { @articles << Article.create!(name: 'test') }
      Article.es.index.refresh
    end
    it '#destroy' do
      expect(Article.es.all.count).to eq 10
      @articles[0].destroy
      Article.es.index.refresh
      expect(Article.es.all.count).to eq 9
    end
    it '#destroy_all' do
      expect(Article.es.all.count).to eq 10
      Article.destroy_all
      Article.es.index.refresh
      expect(Article.es.all.count).to eq 0
    end
  end
end


describe Post do
  it 'properly uses options' do
    expect(Post.es_index_name).to eq 'mongoid_es_test_posts'
    expect(Post.es_wrapper).to eq :model
    expect(Post.es_client_options).to eq(DEFAULT_OPT)
  end

  context 'index operations' do
    it 'does not create index with empty definition (ES will do it for us)' do
      expect(Post.es.index.exists?).to be_falsey
      Post.es.index.create
      expect(Post.es.index.exists?).to be_falsey
    end
    it 'ES autocreates index on first index' do
      expect(Post.es.index.exists?).to be_falsey
      Post.create!(name: 'test post')
      expect(Post.es.index.exists?).to be_truthy
    end
  end

  context 'adding to index' do
    it 'successfuly saves mongoid document' do
      article = Post.new(name: 'test article name')
      expect(article.save).to be_truthy
    end
  end

  context 'searching' do
    before :each do
      @post_1 = Post.create!(name: 'test article name')
      @post_2 = Post.create!(name: 'another article title')
      Post.es.index.refresh
    end

    it 'searches and returns models' do
      expect(Post.es.search('article').first.class).to eq Post
      sleep 1
      expect(Post.es.search('article').count).to eq 2
      expect(Post.es.search('another').count).to eq 1
      expect(Post.es.search('another').first.id).to eq @post_2.id
    end
  end

  context 'pagination' do
    before :each do
      10.times { Post.create(name: 'test') }
      Post.es.index.refresh
    end

    it '#search' do
      expect(Post.es.search('test').size).to eq 10
      expect(Post.es.search('test', per_page: 7, page: 2).to_a.size).to eq 3
    end

    it '#all' do
      expect(Post.es.all.size).to eq 10
      expect(Post.es.all(per_page: 7, page: 2).to_a.size).to eq 3
    end
  end
end

describe Nowrapper do
  it 'properly uses options' do
    expect(Nowrapper.es_index_name).to eq 'mongoid_es_test_nowrappers'
    expect(Nowrapper.es_wrapper).to eq :none
  end

  context 'searching' do
    before :each do
      @post_1 = Nowrapper.create!(name: 'test article name')
      @post_2 = Nowrapper.create!(name: 'another article title')
      Nowrapper.es.index.refresh
    end

    it 'searches and returns hashes' do
      # #count uses _count
      expect(Nowrapper.es.search('article').count).to eq 2
      # #size and #length fetch results
      expect(Nowrapper.es.search('article').length).to eq 2
      expect(Nowrapper.es.search('article').first.class).to eq Hash
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
    expect(response.length).to eq 4
    expect(response.to_a.map(&:class).map(&:name).uniq.sort).to eq ['Article', 'Namespaced::Model', 'Post']
    expect(response.select { |r| r.class == Article && r.id == @article_1.id }.first).not_to be_nil
  end

  it '#multi_with_load' do
    response = Mongoid::Elasticsearch.search 'test', wrapper: :load
    expect(response.length).to eq 4
    expect(response.to_a.map(&:class).map(&:name).uniq.sort).to eq ['Article', 'Namespaced::Model', 'Post']
    expect(response.select { |r| r.class == Article && r.id == @article_1.id }.first).not_to be_nil
  end
end

describe Namespaced::Model do
  it 'properly uses options' do
    expect(Namespaced::Model.es_index_name).to eq 'mongoid_es_test_namespaced_models'
    expect(Namespaced::Model.es.index.name).to eq 'mongoid_es_test_namespaced_models'
    expect(Namespaced::Model.es_index_type).to eq 'namespaced/model'
    expect(Namespaced::Model.es.index.type).to eq 'namespaced/model'
    expect(Namespaced::Model.es_wrapper).to eq :model
    expect(Namespaced::Model.es_client_options).to eq(DEFAULT_OPT)
  end

  context 'index operations' do
    it 'creates and destroys index' do
      expect(Namespaced::Model.es.index.exists?).to be_truthy
      Namespaced::Model.es.index.delete
      expect(Namespaced::Model.es.index.exists?).to be_falsey
      Namespaced::Model.es.index.create
      expect(Namespaced::Model.es.index.exists?).to be_truthy
    end
  end

  context 'adding to index' do
    it 'successfuly saves mongoid document' do
      article = Namespaced::Model.new(name: 'test article name')
      expect(article.save).to be_truthy
    end
    it 'successfuly destroys mongoid document' do
      article = Namespaced::Model.create(name: 'test article name')
      Namespaced::Model.es.index.refresh
      expect(Namespaced::Model.es.all.count).to eq 1
      article.destroy
      Namespaced::Model.es.index.refresh
      expect(Namespaced::Model.es.all.count).to eq 0
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
      expect(results.count).to eq 1
      expect(results.to_a.count).to eq 1
      expect(results.first.id).to eq @article_2.id
      expect(results.first.name).to eq @article_2.name
    end

    it 'searches in field' do
      results = Namespaced::Model.es.search body: {query: {terms: {name: ['likely']}}}
      expect(results.count).to eq 1
      expect(results.to_a.count).to eq 1
      expect(results.first.id).to eq @article_2.id
      expect(results.first.name).to eq @article_2.name
    end

    it 'searches in field - when no match' do
      results = Namespaced::Model.es.search body: {query: {terms: {name: ['not_matched']}}}
      expect(results.count).to eq 0
      expect(results.to_a.count).to eq 0
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
      expect(Namespaced::Model.es.search('irrelevant').to_a.size).to eq 1
      expect(Namespaced::Model.es.search('test', per_page: 30).to_a.size).to eq 20
    end

    it '#search dynamic wrapper' do
      expect(Namespaced::Model.es.search('test', wrapper: :hash).map(&:class).map(&:name).uniq).to eq ['Hash']
      expect(Namespaced::Model.es.search('test', wrapper: :mash).map(&:class).map(&:name).uniq).to eq ['Hashie::Mash']
      expect(Namespaced::Model.es.search('test', wrapper: :mash).first.name).to eq 'test'
    end

    it '#search' do
      expect(Namespaced::Model.es.search('test', per_page: 10, page: 2).to_a.size).to eq 10
      expect(Namespaced::Model.es.search('test', per_page: 30, page: 2).to_a.size).to eq 0
      expect(Namespaced::Model.es.search('test', per_page: 2, page: 2).to_a.size).to eq 2
      expect(Namespaced::Model.es.search(body: {query: {query_string: {query: 'test'}}}, size: 50).to_a.length).to eq 20
    end

    it 'bulk index' do
      Namespaced::Model.es.index.reset
      Namespaced::Model.es.index_all
      Namespaced::Model.es.index.refresh
      expect(Namespaced::Model.es.search('test', per_page: 10, page: 2).to_a.size).to eq 10
      expect(Namespaced::Model.es.search('test', per_page: 30, page: 2).to_a.size).to eq 0
      expect(Namespaced::Model.es.search('test', per_page: 2, page: 2).to_a.size).to eq 2
      expect(Namespaced::Model.es.search(body: {query: {query_string: {query: 'test'}}}, size: 50).to_a.length).to eq 20
    end


    it '#all' do
      result = Namespaced::Model.es.all(per_page: 7, page: 3)
      expect(result.num_pages).to eq 4
      expect(result.to_a.size).to eq 7
      p1 = Namespaced::Model.es.all(per_page: 7, page: 1).to_a
      p2 = Namespaced::Model.es.all(per_page: 7, page: 2).to_a
      p4 = Namespaced::Model.es.all(per_page: 7, page: 4).to_a
      expect(p1.length).to eq 7
      expect(p2.length).to eq 7
      expect(p4.length).to eq 1
      all = (p1 + p2 + result.to_a + p4).map(&:id).map(&:to_s).sort
      expect(all.length).to eq 22
      expect(all).to eq (@articles + [@a1, @a2]).map(&:id).map(&:to_s).sort
    end
  end
end

describe 'utils' do
  it 'doesnt strip non-ascii text' do
    expect(Mongoid::Elasticsearch::Utils.clean('тест {{')).to eq 'тест'
  end
  it 'doesnt strip good white space' do
    expect(Mongoid::Elasticsearch::Utils.clean('test test')).to eq 'test test'
  end
  it 'strip extra white space' do
    expect(Mongoid::Elasticsearch::Utils.clean('    test     test    ')).to eq 'test test'
  end
end


describe 'no autocreate' do
  it "desn't create index automatically" do
    NoAutocreate.es.index.delete
    expect(NoAutocreate.es.index.exists?).to be_falsey
    
    Mongoid::Elasticsearch.create_all_indexes!
    expect(NoAutocreate.es.index.exists?).to be_falsey
    
    NoAutocreate.es.index.force_create
    expect(NoAutocreate.es.index.exists?).to be_truthy
    
    NoAutocreate.es.index.delete
  end
end