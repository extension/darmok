#example: ruby script\retrieve_content.rb -f

#this script must be run as the mongrel user
require 'getoptlong'

### Program Options
progopts = GetoptLong.new(
  [ "--datatype", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--externalfeed", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--refresh_since", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--environment", GetoptLong::OPTIONAL_ARGUMENT ]
)

@datatype = 'all'
@externalfeed = 'all'
@environment = 'production'
@refresh_since = nil

progopts.each do |option, arg|
  case option
  when '--datatype'
    @datatype = arg
  when '--externalfeed'
    @externalfeed = arg
  when '--environment'
    @environment = arg
  when '--refresh_since'
    @refresh_since = arg
  else
    puts "Unrecognized option #{opt}"
    exit 0
  end
end
### END Program Options

if !ENV["RAILS_ENV"] || ENV["RAILS_ENV"] == ""
  ENV["RAILS_ENV"] = @environment
end

require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

def parse_refresh_since(refresh_since)
  if(refresh_since == 'lastday')
    return Time.now.utc - 1.day
  elsif(refresh_since == 'lastweek')
    return Time.now.utc - 1.week
  elsif(refresh_since == 'lastmonth')
    return Time.now.utc - 1.month
  else
    return Time.parse(refresh_since)
  end      
end

def retrieve_content_from_feed_locations(options)
  FeedLocation.active.collect do |feed|
    if(@externalfeed == 'all' or feed.name == @externalfeed)
      puts "Importing external data from #{feed.uri}"    
      begin
        result = feed.retrieve_articles(options)
        puts "Result: #{result.inspect}"
      rescue ContentRetrievalError => exception
        puts exception.message
      end
    end
  end
end


def retrieve_content_for_datatype(objectklass,options)
  puts "Importing #{objectklass.name.capitalize} data"    
  begin
    result = objectklass.retrieve_content(options)
    puts "Result: #{result.inspect}"
  rescue ContentRetrievalError => exception
    puts exception.message
  end
end



begin
  Lockfile.new('/tmp/retrieve_content.lock', :retries => 0) do
    # build options
    options = {}
    if(!@refresh_since.nil?)
      options[:refresh_since] = parse_refresh_since(@refresh_since)
    end

    case @datatype
    when 'articles'
      options[:feed_url] = AppConfig.configtable['content_feed_wikiarticles_no_dpls']
      retrieve_content_for_datatype(Article,options)
    when 'faqs'
      retrieve_content_for_datatype(Faq,options)    
    when 'events'
      retrieve_content_for_datatype(Event,options)
    when 'externals'
      retrieve_content_from_feed_locations(options)
    else
      retrieve_content_for_datatype(Article,options)
      retrieve_content_for_datatype(Faq,options)    
      retrieve_content_for_datatype(Event,options)
      retrieve_content_from_feed_locations(options)
    end
  end
rescue Lockfile::MaxTriesLockError => e
  puts "Another content fetcher is already running. Exiting."
end



