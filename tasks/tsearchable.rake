namespace :tsearchable do
  
  namespace :vectors do 
    desc "Create the full text search vector index columns"
    task :create, :vector, :needs => :environment do |t, args|
      vector = args[:vector] || ENV['VECTOR']
      if vector.nil? then
        puts "Usage: rake tsearchable:vectors:create VECTOR=model_to_create_vector"
        puts "or: rake tsearchable:vectors:create[model_to_create_vector]"
	puts "where model_to_create_vector is User for example"
      else
        begin
          puts "Creating ts_vector for model: #{vector}"
	  vector.constantize.create_tsvector
	rescue
	  puts "Unknown model: cannot create ts_vector column"
	end
      end
    end
  end

  namespace :triggers do
    desc "Create the trigger on a vector column"
    task :create, :vector, :needs => [ :environment ] do |t, args|
      vector = args[:vector] || ENV['VECTOR']
      if vector.nil? then
        puts "Usage: rake tsearchable:triggers:create VECTOR=model_to_create_trigger"
	puts "or: rake tsearchable:triggers:create[model_to_create_trigger]"
	puts "where model_to_create_trigger is User for example"
      else
        begin
          Rake::Task['tsearchable:vectors:create'].invoke(vector)
	  vector.constantize.create_trigger
	rescue
	  puts "Unknown model: cannot create ts_vector column"
	end
      end
    end
  end
end
