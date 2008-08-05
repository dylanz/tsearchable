module TSearchable
  def self.included(base)
    base.extend ClassMethods
    base.extend SingletonMethods
  end

  module ClassMethods
    def tsearchable(options = {})
      @config = {:index => 'gin', :vector_name => 'ts_index', :suggest => [] }
      @config.update(options) if options.is_a?(Hash)
      @config.each {|k,v| instance_variable_set(:"@#{k}", v)}
      raise "You must explicitly specify which fields you want to be searchable" unless @fields

      @indexable_fields = @fields.inject([]) {|a,f| a << "coalesce(#{f.to_s},'')"}.join(' || \' \' || ')
      @suggestable_fields = options[:suggest]

      after_save :update_tsvector_row
      define_method(:per_page) { 30 } unless respond_to?(:per_page)
      include TSearchable::InstanceMethods
    end

    private
      def coalesce(table, field)
        "coalesce(#{table}z.#{field},'')"
      end
  end

  module InstanceMethods
    def update_tsvector_row
      self.class.update_tsvector(self.id)
    end
  end

  #  text_searchable :fields => [:title, :body]
  module SingletonMethods
    def find_by_text_search(keyword, options = {})
      raise ActiveRecord::RecordNotFound, "Couldn't find #{name} without a keyword" if keyword.blank?
      query = "#{@vector_name} @@ to_tsquery('#{parse(keyword)}')"
      options[:conditions] ? (options[:conditions] << ("AND " << query)) : (options[:conditions] = query)

      # will paginate integration.  see the results class.
      if options[:page] && !options[:page][:count]
        Results.create(options[:page], options[:per_page], options[:total_entries]) do |pager|
          count_options = options.except(:page, :per_page, :total_entries)
          find_options  = count_options.except(:count)

          find_options.update({:limit => pager.per_page, :offset => pager.offset})
          pager.replace(find(:all, find_options))

          unless pager.total_entries
            pager.total_entries = self.count(:all, count_options)
          end
        end
      else
        find(:all, options)
      end
    end

    def count_by_text_search(keyword, options = {})
      options.reverse_merge!(:select => "count(*)", :limit => "ALL", :order => "1 desc")
      results = find_by_text_search(keyword, options)
      results.empty? ? 0 : results.at(0)[:count].to_i
    end
    
    # TODO: implementer la pagination
    def find_by_trgm(keyword, options = {})
      raise ActiveRecord::RecordNotFound, "Couldn't find #{name} without a keyword" if keyword.blank?
      return if @suggestable_fields.empty?

      query = []
      sel = []
      @suggestable_fields.each do |field|
        query  << "#{field} % '#{clean(keyword)}'"
        sel << "similarity(#{field}, '#{clean(keyword)}') AS sml_#{field}"
      end
      query = query.join(" AND ")
      sel = sel.join(", ")
      options[:conditions] ? (options[:conditions] << ("AND " << query)) : (options[:conditions] = query)
      options[:select] = "*, " << sel
      
      find(:all, options)
    end

    def update_tsvector(rowid = nil)
      create_tsvector unless column_names.include?(@vector_name)
      # added unindexable hook
      if respond_to?(:is_indexable) && !is_indexable?
        return update_all({:vector_name => nil}, {:id => id})
      end
      update = "UPDATE #{table_name} SET #{@vector_name} = to_tsvector(#{@indexable_fields})"
      update << " WHERE #{table_name}.id = #{rowid}" if rowid
      connection.execute(update)
    end
    alias_method :update_vector, :update_tsvector

    # creates the tsvector column and the index
    def create_tsvector(sql = [])
      return if column_names.include?(@vector_name)
      
      sql << "ALTER TABLE #{table_name} ADD COLUMN #{@vector_name} tsvector"
      sql << "CREATE INDEX #{table_name}_ts_idx ON #{table_name} USING #{@index}(#{@vector_name})"
      sql.each {|s| update_table { connection.execute(s) }}
    end
    alias_method :create_vector, :create_tsvector
    
    # creates the trigram index
    def create_trgm(sql = [])
      return if column_names.include?(@vector_name)
      
      @suggestable_fields.each do |field|
        sql << "CREATE INDEX index_#{table_name}_#{table_name}_trgm ON #{table_name} USING gist(#{field} gist_trgm_ops)"
      end
      sql.each {|s| update_table { connection.execute(s) }}
    end

    # googly search terms to tsearch format.  jacked from bens acts_as_tsearch.
    def parse(query)
      query = query.gsub(/[^\w\-\+'"]+/, " ").gsub("'", "''").strip.downcase
      query = query.scan(/(\+|or \-?|and \-?|\-)?("[^"]*"?|[\w\-]+)/).collect do |prefix, term|
        term = "(#{term.scan(/[\w']+/).join('&')})" if term[0,1] == '"'
        term = "!#{term}" if prefix =~ /\-/
        [(prefix =~ /or/) ? '|' : '&', term] 
      end.flatten!
      query.shift
      query.join
    end
    
    def clean(query)
      query
    end

    # always reset the column info !
    def update_table
      yield
      reset_column_information
    end

    def count_all_indexable
      count(:conditions => {:is_indexable => true})
    end
  end
end
