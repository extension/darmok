# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE
require 'uri'
class Widget < ActiveRecord::Base
  include ActionController::UrlWriter
  default_url_options[:host] = AppConfig.get_url_host
  default_url_options[:protocol] = AppConfig.get_url_protocol
  if(default_port = AppConfig.get_url_port)
    default_url_options[:port] = default_port
  end

  has_many :user_roles
  has_many :submitted_questions
  has_many :widget_events
  belongs_to :user
  belongs_to :creator, :class_name => "User", :foreign_key => "user_id"
  # has_many :tags from the tags model!
  has_many :cached_tags, :as => :tagcacheable
  belongs_to :location
  belongs_to :county
  has_one :community, :dependent => :destroy
  
  
  has_many :role_based_assignees, :source => :user, :through => :user_roles, :conditions => "role_id = #{Role.widget_auto_route.id} AND accounts.retired = false"
  
  
  validates_presence_of :name  
  validates_uniqueness_of :name, :case_sensitive => false
  
  named_scope :inactive, :conditions => "active = false", :order => "name"
  named_scope :active, :conditions => "active = true", :order => "name"
  named_scope :byname, lambda {|widget_name| {:conditions => "name like '#{widget_name}%'", :order => "name"} }
  after_save :update_community
  

  # hardcoded for layout difference
  BONNIE_PLANTS_WIDGET = '4856a994f92b2ebba3599de887842743109292ce'
  
  # hardcoded for support purposes
  SUPPORT_WIDGET = '7ae729bf767d0b3165ddb2b345491f89533a7b7b'
  
  def self.support_widget
    self.find_by_fingerprint(SUPPORT_WIDGET)
  end
  
  
  def is_bonnie_plants_widget?
    (self.fingerprint == BONNIE_PLANTS_WIDGET)
  end
  
  def assignees
    self.community.joined.all(:conditions => 'aae_responder = 1')
  end
  
  def assignee_count
    self.class.assignee_counts[self.id] || 0
  end
  
  class << self
    extend ActiveSupport::Memoizable

    def assignee_counts
      assignee_counts = {}
      widgets_with_counts = self.find(:all, 
                :select => 'widgets.*, COUNT(accounts.id) AS count_of_assignees',
                :joins => {:community => :joined},
                :conditions => "accounts.aae_responder = 1",
                :group => 'widgets.id')
      
      widgets_with_counts.map{|w| assignee_counts[w.id] = w.count_of_assignees.to_i}          
      assignee_counts
    end

    memoize :assignee_counts
  end
  
  # include those who opted out of receiving questions
  def all_assignees
    self.community.joined.all
  end
    
  def leaders
    self.community.leaders
  end
  
  def non_active_assignees
    self.community.joined.all(:conditions => 'aae_responder = 0')
  end
  
  def widgeturl
    widget_tracking_url(:widget => self.fingerprint, :only_path => false)
  end
  
  def set_fingerprint(user)
    create_time = Time.now.to_s
    self.fingerprint = Digest::SHA1.hexdigest(create_time + user.id.to_s + self.name)
  end
  
  def get_iframe_code
    if(self.is_bonnie_plants_widget?)
      height = '610px' 
    elsif(self.show_location?)
      height = '460px'
    else
      height = '300px'
    end
    return "<iframe style='border:0' width='100%' src='#{self.widgeturl}' height='#{height}'></iframe>"
  end
  
  
  def tag_myself_with_shared_tags(taglist)
    self.replace_tags_with_and_cache(taglist,User.systemuserid,Tagging::SHARED)
  end
  
  def system_sharedtags_displaylist
    return self.tag_displaylist_by_ownerid_and_kind(User.systemuserid,Tagging::SHARED)
  end
  
  def self.find_by_fingerprint_or_id_or_name(fingerprint_or_id_or_name)
    if(fingerprint_or_id_or_name.size == 40)
      self.find_by_fingerprint(fingerprint_or_id_or_name)
    elsif(fingerprint_or_id_or_name =~ /\d+/)
      self.find_by_id(fingerprint_or_id_or_name)
    else
      self.find_by_name(URI.unescape(fingerprint_or_id_or_name))
    end
  end
  
  def can_edit_attributes?(user)
    return (user.is_admin? or self.user == user or self.assignees.include?(user))
  end
  
  def update_community
    if(!self.community.blank?)
      self.community.update_attributes({:active => self.active, :location => self.location})
    else
      self.community = Community.create(:name => "Widget: #{self.name}",
                                        :entrytype => Community::WIDGET, 
                                        :memberfilter => Community::OPEN, 
                                        :created_by => self.user_id, 
                                        :active => self.active, 
                                        :location => self.location)
      # add creator to leadership
      self.community.add_user_to_leadership(self.creator,User.systemuser,false)          
    end
  end  
      
end
