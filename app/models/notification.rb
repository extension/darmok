# === COPYRIGHT:
#  Copyright (c) 2005-2007 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class Notification < ActiveRecord::Base
  
  NONE = 1
  # notifytypes
  
  
  ###############################
  #  People Notifications
  
  NOTIFICATION_PEOPLE = [100,999]   # 'people'
  
  COMMUNITY_USER_JOIN = 101
  COMMUNITY_USER_WANTSTOJOIN = 102
  COMMUNITY_USER_LEFT= 103
  COMMUNITY_USER_ACCEPT_INVITATION= 104
  COMMUNITY_USER_DECLINE_INVITATION= 105  
  COMMUNITY_USER_NOWANTSTOJOIN= 106
  COMMUNITY_USER_INTEREST = 107
  COMMUNITY_USER_NOINTEREST = 108

  
  COMMUNITY_LEADER_INVITELEADER = 201
  COMMUNITY_LEADER_INVITEMEMBER = 202
  COMMUNITY_LEADER_RESCINDINVITATION = 203
  
  COMMUNITY_LEADER_INVITEREMINDER = 204

  COMMUNITY_LEADER_ADDLEADER = 301
  COMMUNITY_LEADER_ADDMEMBER = 302
  
  COMMUNITY_LEADER_REMOVELEADER = 401
  COMMUNITY_LEADER_REMOVEMEMBER = 402
  
  # eXtensionID Invitation
  INVITATION_TO_EXTENSIONID = 500  
  INVITATION_ACCEPTED = 501
  
  CONFIRM_EMAIL = 501
  RECONFIRM_EMAIL = 502
  RECONFIRM_SIGNUP = 503
  
  ## Other User actions
  # new account created
  
  ##########################################
  #  Ask an Expert Notifications - Internal

  NOTIFICATION_AAE_INTERNAL = [1000,1999]   # 'aae-internal'
  AAE_ASSIGNMENT = 1001  # assignment notification
  AAE_REASSIGNMENT = 1002  # reassignment notification
  AAE_ESCALATION = 1003  # escalation notification
  
    
  ##########################################
  #  Ask an Expert Notifications - Public
  
  NOTIFICATION_AAE_PUBLIC = [2000,2999]   # 'aae-public'
  AAE_PUBLIC_EXPERT_RESPONSE = 2001  # notification of an expert response, also "A Space Odyssey"
  

  belongs_to :user
  belongs_to :community # for many of the notification types
  belongs_to :creator, :class_name => "User", :foreign_key => "created_by"
  serialize :additionaldata
  
  before_create :createnotification?
  
  named_scope :tosend, :conditions => {:sent_email => false,:send_error => false}, :order => "created_at ASC"
  named_scope :aae_internal, :conditions => ["notifytype BETWEEN (#{NOTIFICATION_AAE_INTERNAL[0]} and #{NOTIFICATION_AAE_INTERNAL[1]})"]
  named_scope :aae_public, :conditions => ["notifytype BETWEEN (#{NOTIFICATION_AAE_PUBLIC[0]} and #{NOTIFICATION_AAE_PUBLIC[1]})"] 
  named_scope :people, :conditions => ["notifytype BETWEEN (#{NOTIFICATION_PEOPLE[0]} and #{NOTIFICATION_PEOPLE[1]})"] 
  
  
  def notifytype_to_s
    if(self.notifytype == NONE)
      return 'none'
    elsif(self.notifytype >= NOTIFICATION_PEOPLE_START[0] and self.notifytype <= NOTIFICATION_PEOPLE_START[1])
      return 'people'
    elsif(self.notifytype >= NOTIFICATION_AAE_INTERNAL[0] and self.notifytype <= NOTIFICATION_AAE_INTERNAL[1])
      return 'aae_internal'
    elsif(self.notifytype >= NOTIFICATION_AAE_PUBLIC[0] and self.notifytype <= NOTIFICATION_AAE_PUBLIC[1])
      return 'aae_public'
    else
      return nil
    end
  end
  
  
  def createnotification?
    case self.notifytype
    when COMMUNITY_USER_NOINTEREST
      return false
    when NONE
      return false
    else
      return true
    end
  end
    
  def self.translate_connection_to_code(connectaction,connectiontype=nil)
    case connectaction
    when 'removeleader'
      COMMUNITY_LEADER_REMOVELEADER
    when 'removemember'
      COMMUNITY_LEADER_REMOVEMEMBER
    when 'addmember'
      COMMUNITY_LEADER_ADDMEMBER
    when 'addleader'
      COMMUNITY_LEADER_ADDLEADER
    when 'rescindinvitation'
      COMMUNITY_LEADER_RESCINDINVITATION
    when 'inviteleader'
      COMMUNITY_LEADER_INVITELEADER
    when 'invitemember'  
      COMMUNITY_LEADER_INVITEMEMBER
    when 'leave'
      COMMUNITY_USER_LEFT
    when 'join'
      COMMUNITY_USER_JOIN
    when 'nowantstojoin'
      COMMUNITY_USER_NOWANTSTOJOIN
    when 'wantstojoin'
      COMMUNITY_USER_WANTSTOJOIN
    when 'interest'
      COMMUNITY_USER_INTEREST
    when 'nointerest'
      COMMUNITY_USER_NOINTEREST
    when 'accept'
      COMMUNITY_USER_ACCEPT_INVITATION
    when 'decline'
      COMMUNITY_USER_DECLINE_INVITATION
    else
      NONE
    end
  end
  
  def self.clearerrors
    errors = find(:all, :conditions => {:send_error => true})
    errors.each do |notification|
      notification.update_attributes({:send_error => false})
    end
  end
  
  def self.userevent(notificationcode,user,community)
    case notificationcode
    when COMMUNITY_LEADER_ADDMEMBER
      userevent = "added #{user.login} to #{community.name} membership"
    when COMMUNITY_LEADER_ADDLEADER
      userevent = "added #{user.login} to #{community.name} leadership"
    when COMMUNITY_LEADER_REMOVEMEMBER
      userevent = "removed #{user.login} from #{community.name} membership"
    when COMMUNITY_LEADER_REMOVELEADER
      userevent = "removed #{user.login} from #{community.name} leadership"
    when COMMUNITY_LEADER_INVITELEADER
      userevent = "invited #{user.login} to #{community.name} leadership"
    when COMMUNITY_LEADER_INVITEMEMBER
      userevent = "invited #{user.login} to #{community.name} membership"
    when COMMUNITY_LEADER_INVITEREMINDER
      userevent = "sent an invitation reminder to #{user.login} for the #{community.name} community "      
    when COMMUNITY_LEADER_RESCINDINVITATION
      userevent = "rescinded invitation for #{user.login} to #{community.name}"
    when COMMUNITY_USER_LEFT
      userevent = "left #{community.name}"
    when COMMUNITY_USER_WANTSTOJOIN
      userevent = "wants to join #{community.name}"
    when COMMUNITY_USER_NOWANTSTOJOIN
      userevent = "no longer wants to join #{community.name}"
    when COMMUNITY_USER_INTEREST
      userevent = "interested in #{community.name}"
    when COMMUNITY_USER_NOINTEREST
      userevent = "no longer interested in #{community.name}"
    when COMMUNITY_USER_JOIN
      userevent = "joined #{community.name}"
    when COMMUNITY_USER_ACCEPT_INVITATION
      userevent = "accepted invitation to #{community.name}"
    when COMMUNITY_USER_ACCEPT_INVITATION
      userevent = "declined invitation to #{community.name}"
    else
      userevent = "Unknown Event"
    end
    return userevent
  end
   
  def self.showuserevent(notificationcode,showuser,byuser,community)
    case notificationcode
    when COMMUNITY_LEADER_ADDMEMBER
      showuserevent = "added to #{community.name} membership by #{byuser.login}"
    when COMMUNITY_LEADER_ADDLEADER
      showuserevent = "added to #{community.name} leadership by #{byuser.login}"
    when COMMUNITY_LEADER_REMOVEMEMBER
      showuserevent = "removed from #{community.name} membership by #{byuser.login}"
    when COMMUNITY_LEADER_REMOVELEADER
      showuserevent = "removed from #{community.name} leadership by #{byuser.login}"
    when COMMUNITY_LEADER_INVITELEADER
      showuserevent = "invited to #{community.name} leadership by #{byuser.login}"
    when COMMUNITY_LEADER_INVITEREMINDER
      showuserevent = "reminded of #{community.name} invitation by #{byuser.login}"
    when COMMUNITY_LEADER_INVITEMEMBER
      showuserevent = "invited to #{community.name} membership by #{byuser.login}"
    when COMMUNITY_LEADER_RESCINDINVITATION
      showuserevent = "invitation to #{community.name} rescinded by #{byuser.login}"
    else
      showuserevent = "Unknown event."
    end
    return showuserevent
  end
  

  
  
end