require 'tsearchable'
ActiveRecord::Base.send :include, TSearchable
