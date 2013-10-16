require "spec_helper"

describe Article do
  it 'properly uses options' do
    Article.es_index_name.should eq 'mongoid_es_news'
    Article.es_wrapper.should eq :load
    Article.es_client_options.should eq({})
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

  context 'searching' do
    before :each do
      @article_1 = Article.create!(name: 'test article name', tags: 'likely')
      @article_2 = Article.create!(name: 'likely an another article title')
      @article_3 = Article.create!(name: 'a strange name for this stuff')
      Article.es.index.refresh
    end

    it 'searches and returns models' do
      results = Article.es.search q: 'likely'
      results.count.should eq 1
      results.to_a.count.should eq 1
      results.first.id.should eq @article_2.id
      results.first.name.should eq @article_2.name
    end
  end

  context 'pagination' do
    before :each do
      10.times { Article.create(name: 'test') }
      Article.es.index.refresh
    end

    it '#search' do
      Article.es.search('test', per_page: 7, page: 2).to_a.size.should eq 3
    end

    it '#all' do
      Article.es.all(per_page: 7, page: 2).to_a.size.should eq 3
    end
  end
end


describe Post do
  it 'properly uses options' do
    Post.es_index_name.should eq 'mongoid_es_test_posts'
    Post.es_wrapper.should eq :model
    Post.es_client_options.should eq({})
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

