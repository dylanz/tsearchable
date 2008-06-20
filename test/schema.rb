ActiveRecord::Schema.define(:version => 0) do
  create_table :text_search_test_articles, :force => true do |t|
    t.string     :title
    t.text       :body
    t.tsvector   :vectors
    t.timestamps
  end
end
