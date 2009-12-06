# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class Widget < ActiveRecord::Base

  has_many :user_roles
  has_many :assignees, :source => :user, :through => :user_roles, :conditions => "role_id = #{Role.widget_auto_route.id} AND users.retired = false AND users.aae_responder = true"
  has_many :submitted_questions
  has_many :widget_events
  belongs_to :user
  
  validates_presence_of :name  
  validates_uniqueness_of :name, :case_sensitive => false
  
  named_scope :inactive, :conditions => "active = false", :order => "name"
  named_scope :active, :conditions => "active = true", :order => "name"
  named_scope :byname, lambda {|widget_name| {:conditions => "name like '#{widget_name}%'", :order => "name"} }
  
  def set_fingerprint(user)
    create_time = Time.now.to_s
    self.fingerprint = Digest::SHA1.hexdigest(create_time + user.id.to_s + self.name)
  end
  
  def get_iframe_code
    return '<iframe style="border:0" width="100%" src="' +  self.widget_url + '" height="300px"></iframe>'
  end
  
end
