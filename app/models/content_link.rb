# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE
require 'net/https'

class ContentLink < ActiveRecord::Base
  serialize :last_check_information
  include ActionController::UrlWriter # so that we can generate URLs out of the model
  
  belongs_to :content, :polymorphic => true # this is for published items to associate links to that published item
  has_many :linkings
  
  validates_presence_of :original_fingerprint, :linktype
  
  # this is the association for items that link to this item
  has_many_polymorphs :contentitems, 
    :from => [:articles], 
    :through => :linkings, 
    :dependent => :destroy,
    :as => :content_link,
    :skip_duplicates => false
    
  # link types
  WANTED = 1
  INTERNAL = 2
  EXTERNAL = 3
  MAILTO = 4
  CATEGORY = 5
  DIRECTFILE = 6
  LOCAL = 7
  
  
  
  # status codes
  OK = 1
  OK_REDIRECT = 2
  WARNING = 3
  BROKEN = 4
  IGNORED = 5

  # maximum number of times a broken link reports broken before warning goes to error
  MAX_WARNING_COUNT = 3
  
  # maximum number of times we'll check a broken link before giving up
  MAX_ERROR_COUNT = 10
  
  named_scope :checklist, :conditions => ["linktype IN (#{EXTERNAL},#{LOCAL})"]
  named_scope :external, :conditions => {:linktype => EXTERNAL}
  named_scope :internal, :conditions => {:linktype => INTERNAL}
  named_scope :unpublished, :conditions => {:linktype => WANTED}
  named_scope :local, :conditions => {:linktype => LOCAL}

  named_scope :checked, :conditions => ["last_check_at IS NOT NULL"]
  named_scope :unchecked, :conditions => ["last_check_at IS NULL"]
  named_scope :good, :conditions => {:status => OK}
  named_scope :broken, :conditions => {:status => BROKEN}
  named_scope :warning, :conditions => {:status => WARNING}
  named_scope :redirected, :conditions => {:status => OK_REDIRECT}
  
  named_scope :checked_yesterday_or_earlier, :conditions => ["DATE(last_check_at) <= ?",Date.yesterday]
  named_scope :checked_over_one_month_ago, :conditions => ["DATE(last_check_at) <= DATE_SUB(NOW(),INTERVAL 1 MONTH)",Date.yesterday]
  
  def status_to_s
    if(self.status.blank?)
      return 'Not yet checked'
    end
    
    case self.status
    when OK
      return 'OK'
    when OK_REDIRECT
      return 'Redirect'
    when WARNING
      return 'Warning'
    when BROKEN
      return 'Broken'
    when IGNORED
      return 'Ignored'
    else
      return 'Unknown'
    end
  end
  
  def href_url
    default_url_options[:host] = AppConfig.get_url_host
    default_url_options[:protocol] = AppConfig.get_url_protocol
    if(default_port = AppConfig.get_url_port)
     default_url_options[:port] = default_port
    end
    
    case self.linktype
    when WANTED
      return ''
    when INTERNAL
      self.content.href_url
    when EXTERNAL
      self.original_url
    when LOCAL
      self.original_url
    when MAILTO
      self.original_url
    when CATEGORY
      if(self.path =~ /^\/wiki\/Category\:(.+)/)
        content_tag = $1.gsub(/_/, ' ')
        content_tag_index_url(:content_tag => content_tag)
      else
        return ''
      end
    when DIRECTFILE
      self.path
    end
  end

  def change_to_wanted  
    if(self.linktype == INTERNAL)
      self.update_attribute(:linktype,WANTED)
      self.contentitems.each do |linked_content_item|
        linked_content_item.store_content # parses links and images again and saves it.
      end
    end
  end
  
  def self.create_from_content(content)
    if(content.original_url.blank?)
      return nil
    end

    # make sure the URL is valid format
    begin
      original_uri = URI.parse(content.original_url)
    rescue
      return nil
    end
    
    if(content_link = self.find_by_original_fingerprint(Digest::SHA1.hexdigest(CGI.unescape(original_uri.to_s))))
      # this was a wanted link - we need to update the link now - and kick off the process of updating everything
      # that links to this piece of content.
      content_link.update_attributes(:content => content, :linktype => INTERNAL)
      content_link.contentitems.each do |linked_content_item|
        linked_content_item.store_content # parses links and images again and saves it.
      end
    else    
      content_link = self.new(:content => content, :original_url => original_uri.to_s, :original_fingerprint => Digest::SHA1.hexdigest(CGI.unescape(original_uri.to_s)))
      content_link.source_host = original_uri.host
      content_link.linktype = INTERNAL
    
      # set host and path - mainly just for aggregation purposes
      if(!original_uri.host.blank?)
        content_link.host = original_uri.host
      end
      if(!original_uri.path.blank?)
        content_link.path = CGI.unescape(original_uri.path)
      end
      content_link.save
    end
    return content_link
  end
  
  # this is meant to be called when parsing a piece of content for items it links to itself.
  def self.find_or_create_by_linked_url(linked_url,source_host,make_wanted_if_source_host_match = true)
    # make sure the URL is valid format
    begin
      original_uri = URI.parse(linked_url)
    rescue
      return nil
    end
    
    # is this a /wiki/Image:blah or /wiki/File:blah link? - then return nothing - it's ignored
    if(original_uri.path =~ /^\/wiki\/File:.*/ or original_uri.path =~ /^\/wiki\/Image:(.*)/)
      return ''
    end
    

    
    # is this a relative url? (no scheme/no host)- so attach the source_host and http
    # to it, to see if that matches an original URL that we have
    if(!original_uri.is_a?(URI::MailTo))
      original_uri.host = source_host if(original_uri.host.blank?)
      original_uri.scheme = 'http' if(original_uri.scheme.blank?)
    end
    
    # for comparison purposes - we need to drop the fragment - the caller is going to
    # need to maintain the fragment when they get an URI back from this class.
    if(!original_uri.fragment.blank?)
      original_uri.fragment = nil
    end
    
    # we'll keep the path around - but we might should drop them for CoP wiki sourced articles

    if(content_link = self.find_by_original_fingerprint(Digest::SHA1.hexdigest(CGI.unescape(original_uri.to_s))))
      return content_link
    end
    
    # create it - if host matches source_host and we want to identify this as "wanted" - then make it wanted else - call it external
    # the reason for the make_wanted_if_source_host_match parameter is I imagine we are going to have a situation with 
    # some feed provider where they want to link back to their own content - and we shouldn't necessarily force that link to be relative
    content_link = self.new(:original_url => original_uri.to_s, 
                            :original_fingerprint => Digest::SHA1.hexdigest(CGI.unescape(original_uri.to_s)), 
                            :source_host => source_host)
    if(original_uri.is_a?(URI::MailTo))
      content_link.linktype = MAILTO
    elsif(original_uri.host == source_host and make_wanted_if_source_host_match)
      if(original_uri.path =~ /^\/wiki\/Category:.*/)
        content_link.linktype = CATEGORY
      elsif(original_uri.path =~ /^\/mediawiki\/.*/)
        content_link.linktype = DIRECTFILE
      elsif(original_uri.path =~ /^\/learninglessons\/.*/)
        content_link.linktype = DIRECTFILE
      else
        content_link.linktype = WANTED
      end
    elsif(original_uri.host.downcase == 'extension.org' or original_uri.host.downcase =~ /\.extension\.org$/)
      # host is extension
      content_link.linktype = LOCAL
    else
      content_link.linktype = EXTERNAL      
    end
    
    # set host and path - mainly just for aggregation purposes
    if(!original_uri.host.blank?)
      content_link.host = original_uri.host.downcase
    end
    if(!original_uri.path.blank?)
      content_link.path = CGI.unescape(original_uri.path)
    end
    content_link.save
    return content_link        
  end
  
  
  def check_original_url(save = true,force_error_check=false)
    return if(!force_error_check and self.error_count >= MAX_ERROR_COUNT)
    
    self.last_check_at = Time.zone.now
    result = self.class.check_url(self.original_url)
    if(result[:responded])
      self.last_check_response = true
      self.last_check_information = {:response_headers => result[:response].to_hash}
      self.last_check_code = result[:code]
      if(result[:code] == '200')
        self.status = OK
        self.last_check_status = OK
        self.error_count = 0
      elsif(result[:code] == '301' or result[:code] == '302')
        self.status = OK_REDIRECT
        self.last_check_status = OK_REDIRECT
        self.error_count = 0
      else
        self.error_count += 1
        if(self.error_count >= MAX_WARNING_COUNT)
          self.status = BROKEN
        else
          self.status = WARNING
        end
        self.last_check_status = BROKEN
      end
    elsif(result[:ignored])
      self.last_check_response = false
      self.status = IGNORED
      self.last_check_status = IGNORED
    else
      self.last_check_response = false
      self.last_check_information = {:error => result[:error]}
      self.error_count += 1
      if(self.error_count >= MAX_WARNING_COUNT)
        self.status = BROKEN
      else
        self.status = WARNING
      end
      self.last_check_status = BROKEN
    end
    self.save
  end
      
  
  def self.check_url(url)
    headers = {'User-Agent' => 'extension.org link verification'}
    # the URL should have likely already be validated, but let's do it again for good measure
    begin
      check_uri = URI.parse("#{url}")
    rescue Exception => exception
      return {:responded => false, :error => exception.message}
    end
    
    if(check_uri.scheme != 'http' and check_uri.scheme != 'https')
      return {:responded => false, :ignored => true}
    end
      
    # check it!
    begin
      response = nil
      http_connection = Net::HTTP.new(check_uri.host, check_uri.port)
      if(check_uri.scheme == 'https')
        # don't verify cert?
        http_connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http_connection.use_ssl = true 
      end
      response = http_connection.head(check_uri.path.size > 0 ? check_uri.path : "/",headers)   
      {:responded => true, :code => response.code, :response => response}
    rescue Exception => exception
      return {:responded => false, :error => exception.message}
    end
  end
  
  
end
  
  
