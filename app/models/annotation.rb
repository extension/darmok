# === COPYRIGHT:
#  Copyright (c) 2005-2010 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class Annotation < ActiveRecord::Base
  validates_length_of :url, :within => 1..1024
  # we do the validation here in leiu of the db since google *does* allow
  # duplicates; this allows us to import all of googles entries, but let
  # folks know they are trying to add a dupe
  validates_uniqueness_of :url
  
  # key off url since annotations can be removed
  has_many :annotation_events, :primary_key => :url
  
  after_save :log_add
  before_destroy :log_delete
  
  @@client = nil
  
  # href - id generated by google
  # url - URL string WITHOUT leading http://
  # added_at - date added by Google to CSE
  
  named_scope :patternsearch, lambda {|searchterm|
    # remove any leading * to avoid borking mysql
    # remove any '\' characters because it's WAAAAY too close to the return key
    # strip '+' characters because it's causing a repitition search error
    sanitizedsearchterm = searchterm.gsub(/\\/,'').gsub(/^\*/,'$').gsub(/\+/,'').strip
    # in the format wordone wordtwo etc?
    words = sanitizedsearchterm.split(%r{\s+})
    conditions = Array.new
    if(words.length > 1)
      words.each do |word|
        conditions << "url rlike '#{word}'"
      end
    elsif(sanitizedsearchterm.to_i != 0)
      # special case of an id search - needed in admin/colleague searches
      conditions << "id = #{sanitizedsearchterm.to_i}"
    else
      conditions << "url rlike '#{sanitizedsearchterm}'"
    end
    {:conditions => conditions.compact.join(" AND ")}
  }
  
  def add(url)
    returnhash = Hash.new
    returnhash[:success] = false
    msg = ""
    result = false
    
    # remove leading protocol stuff so we can try to match
    # it locally before sending it to google
    url.gsub!(/^http(s)?(\:)+\/(\/)+/,'')
    
    dupe = Annotation.find_by_url(url)
    
    if dupe
      msg << "URL already included in search"
    else
      begin
        result = @@client.addAnnotation(url)
      rescue GData::Client::BadRequestError
        msg << "Malformed URL; please try again."
      rescue GData::Client::ServerError
        msg << "Server error; please try again later."
      rescue GData::Client::UnknownError
        msg << "Server error; invalid response from Google."
      rescue Exception => detail
        if detail.respond_to?(:response)
          msg << detail.response.body
        else
          msg << "Unknown error - #{detail.inspect}."
        end
      end
    end
    
    if result
      data = result.pop
      # set our object properties to match googles response
      data.each do |key, value|
        self.send("#{key}=", value)
      end
      
      if ! self.save
        # added a duplicate, need to remove
        
        # we replace the url the user provided with the form provided by
        # google in their response, if the save failed, it is because we
        # tried to add a dupe to our local db
        
        # to keep us in sync with google, we then issue a remove back to
        # google
        self.remove
        msg << "URL already included in search"
      else
        returnhash[:success] = true
        msg << "successfully added"
      end

    end
    
    returnhash[:msg] = msg
    
    return returnhash
  end
  
  def remove
    returnhash = Hash.new
    returnhash[:success] = false
    msg = ""
    result = false
    
    begin
      result = Annotation.remove(self.href)
    rescue GData::Client::BadRequestError
      msg << "Invalid href ID; may have already been removed."
    rescue GData::Client::ServerError
      msg << "Server error; please try again later."
    rescue GData::Client::UnknownError
      msg << "Server error; invalid response from Google."
    rescue Exception => detail
      if detail.respond_to?(:response)
        msg << detail.response.body
      else
        msg << "Unknown error - #{detail.inspect}."
      end
    end
    
    if result
      # we only destroy ourselves if we have an id (were saved in the db)
      # if we caught a dupe after the response came back from google,
      # then we would not have an id
      self.destroy if self.id
      returnhash[:success] = true
      msg << "successfully removed"
    end
    
    returnhash[:msg] = msg
    
    return returnhash
  end
  
  def after_initialize
    Annotation.login
  end
  
  def added_at=(microseconds)
    # response from Google is microseconds as a string
    write_attribute(:added_at, Time.at(Integer(microseconds)/1000000))
  end
  
  def log_add
    self.log_event(AnnotationEvent::URL_ADDED)
  end
  
  def log_delete
    self.log_event(AnnotationEvent::URL_DELETED)
  end
 
  def log_event(action)
    AnnotationEvent.log_event(self, action)
  end
  
  class << self
    
    def login
      if @@client.nil?
        @@client = GData::Client::Cse.new
        rc = @@client.clientlogin(AppConfig.configtable['cse_uid'],
                              AppConfig.configtable['cse_secret'])
      end
    end
    
    def remove(href)
      rc = false
      result = @@client.removeAnnotation(href)
      if result
        rc = true
      end
      return rc
    end
    
    def initial_setup
      self.login
      urls = @@client.getAnnotations
      
      added = errs = 0
      
      urls.each do |url|
        begin
          a = Annotation.new(url)
          
          # do not use model validations, this allows us to add dupes that
          # may be present at google
          rc = a.save(false)
          
          if rc
            added += 1
          else
            errs += 1
          end
        rescue
          errs += 1
        end
      end
      
      return {:added => added, :errs => errs}
    end
    
    def remove_dupes
      self.login
      total = 0
      
      annotes = Annotation.all
      urls = Hash.new
      hrefs = Hash.new
      
      annotes.each do |an|
        urls[an.url] += 1 if urls.has_key?(an.url)
        urls[an.url] = 1 if ! urls.has_key?(an.url)
        hrefs[an.url] = an.href
      end
      
      urls.each do |url, cnt|
        if cnt > 1
          goner = hrefs[url]
          p "removing duplidate entry: #{url}"
          Annotation.remove(goner)
          total += 1
        end
      end
      return total
    end
    
  end
end
