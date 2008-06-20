require 'erb'
require 'rubygems'
require 'test/unit'
require 'activerecord'

RAILS_ROOT  = Dir.pwd unless defined? RAILS_ROOT
RAILS_ENV   = 'test'  unless defined? RAILS_ENV
CONFIG_FILE = RAILS_ROOT + '/config/database.yml'

require File.dirname(__FILE__) + "/../lib/tsearchable/results"
require File.dirname(__FILE__) + "/../lib/tsearchable/tsearchable"
require File.dirname(__FILE__) + "/../lib/tsearchable/postgresql_extensions"

file = ERB.new(File.open(CONFIG_FILE) {|f| f.read})
config = YAML.load(file.result(binding))

ActiveRecord::Base.establish_connection(config['test'])
load(File.join(File.dirname(__FILE__), "/schema.rb"))
ActiveRecord::Base.send :include, TSearchable

# colored tests are pretty
begin require 'redgreen'; rescue LoadError; end
