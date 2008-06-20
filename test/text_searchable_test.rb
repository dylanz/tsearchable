require File.dirname(__FILE__) + '/helper'
require File.dirname(__FILE__) + '/text_search_helper'

class Article < ActiveRecord::Base
  tsearchable :fields => [:title, :body]
  self.table_name = "text_search_test_articles"
end

class TextSearchableTest < Test::Unit::TestCase
  include TextSearchHelper

  def setup
    @moose     = TextSearchHelper.create_moose_article
    @woodchuck = TextSearchHelper.create_woodchuck_article
  end

  def teardown
    Article.delete_all
  end

  ## testing search
  def test_should_be_searchable
    assert Article.find_by_text_search("moose")
  end

  def test_should_raise_if_search_term_is_blank
    assert_raise(ActiveRecord::RecordNotFound) { Article.find_by_text_search(" ") }
  end

  def test_should_raise_if_search_term_is_nil
    assert_raise(ActiveRecord::RecordNotFound) { Article.find_by_text_search(nil) }
  end

  def test_should_find_a_result_with_matching_keyword
    assert_equal(Article.find_by_text_search("moose"), [@moose])
  end

  def test_should_update_tsvector_row_on_save
    @moose.update_attributes({:title => 'bathtub full of badgers', :body => ''})
    assert_equal(Article.find_by_text_search("badgers"), [@moose])
  end

  def test_should_return_correct_number_from_count_by_text_search
    Article.create({:title => "moose"})
    assert_equal(Article.count_by_text_search("moose"), 2)
  end

  ## testing parameter parsing
  def test_should_allow_OR_searches
    assert_equal(Article.count_by_text_search("moose OR woodchuck"), 2)
  end

  def test_should_allow_AND_searches
    assert_equal(Article.count_by_text_search("moose AND woodchuck"), 0)
  end

  def test_should_allow_MINUS_searches
    assert_equal(Article.count_by_text_search("moose -mousse"), 0)
  end

  def test_should_allow_PLUS_searches
    assert_equal(Article.count_by_text_search("moose +mousse"), 1)
  end
end
