# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE
require 'digest/sha1'

class AppConfig
  
  @@configtable = Hash.new
  @@content_widget_styles = ''
  cattr_reader :configtable, :content_widget_styles
  
  def AppConfig.default_config

    @@configtable.clear
    @@configtable['app_location'] = "localdev"
    @@configtable['load_query_trace'] = false
    @@configtable['load_rails_footnotes'] = false
    @@configtable['sessionsecret'] = Digest::SHA1.hexdigest("no session key present")
    @@configtable['sudoers'] = Hash.new
    
    # reserved user id's, not allowed to login
    @@configtable['reserved_uids'] = [1,2,3,4,5,6,7,8]
    
    # possibly return different ones for demo?    
    @@configtable['openid_url_prefix'] = {}
    @@configtable['openid_url_prefix']['production'] = {}
    @@configtable['openid_url_prefix']['production']['claimed'] = 'https://people.extension.org'
    @@configtable['openid_url_prefix']['production']['local'] = 'https://www.extension.org/people'
    @@configtable['openid_url_prefix']['demo'] = {}
    @@configtable['openid_url_prefix']['demo']['claimed'] = 'https://people.demo.extension.org'
    @@configtable['openid_url_prefix']['demo']['local'] = 'https://www.demo.extension.org/people'
    @@configtable['openid_url_prefix']['localdev'] = 'request_url'
    
    @@configtable['openid_endpoint'] = {}
    @@configtable['openid_endpoint']['production'] = 'https://www.extension.org/opie'
    @@configtable['openid_endpoint']['demo']= 'https://www.demo.extension.org/opie'
    @@configtable['openid_endpoint']['localdev'] = 'request_url'
    
    # content feeds and times
    @@configtable['epoch_time'] = Time.parse('1970-01-01 00:00:00 UTC')    
    @@configtable['content_feed_refresh_since'] = Time.parse('2005-11-01 00:00:00 UTC')    
    @@configtable['extensionorg_copwiki_host'] = 'cop.extension.org'
    @@configtable['extensionorg_demowiki_host'] = 'cop.demo.extension.org'
        
    @@configtable['emailsettings'] = {}
    @@configtable['emailsettings']['errors'] = 'eXtensionAppErrors@extension.org'
    
    # address, from string, and bcc for various functional areas
    @@configtable['emailsettings']['aae_public'] = {'address' => 'ask-an-expert@extension.org', 'name' => 'eXtension Ask an Expert Response', 'bcc' => 'aaepublic.bcc.mirror@extension.org'}
    @@configtable['emailsettings']['aae_internal'] = {'address' => 'aae-notify@extension.org', 'name' => 'Do Not Reply - eXtension Ask an Expert Notification', 'bcc' => 'aaenotify.bcc.mirror@extension.org'}
    @@configtable['emailsettings']['aae_escalation'] = {'address' => 'aae-escalation@extension.org', 'name' => 'Do Not Reply - eXtension Ask an Expert Notification', 'bcc' => 'aaenotify.bcc.mirror@extension.org'}
    @@configtable['emailsettings']['aae_noreply'] = {'address' => 'aae-noreply@extension.org', 'name' => 'Do Not Reply - eXtension Ask an Expert Notification', 'bcc' => 'aaenotify.bcc.mirror@extension.org'}
    @@configtable['emailsettings']['people'] = {'address' => 'peoplemail@extension.org', 'name' => 'eXtension People Notification - Do Not Reply', 'bcc' => 'people.bcc.mirror@extension.org', 'review' => 'eXtensionHelp@extension.org'}
    @@configtable['emailsettings']['default'] = {'address' => 'noreply@extension.org', 'name' => 'eXtension Notification', 'bcc' => 'default.bcc.mirror@extension.org'}
    @@configtable['emailsettings']['deploy'] = {'address' => 'exdev@extension.org', 'name' => 'eXDevBot', 'bcc' => 'deploys.mirror@extension.org'}
        
    # in hours
    @@configtable['aae_escalation_delta'] = 24
    
    # password expirations (days)
    @@configtable['password_activity_expiration'] = 180
    @@configtable['password_retire_expiration'] = 7
        
  
    #Default sites
    @@configtable['faq_site'] = 'http://cop.extension.org/faq'
    @@configtable['events_site'] = 'http://cop.extension.org/events'
    @@configtable['people_site'] = 'http://people.extension.org/'
    @@configtable['learn_site'] = 'http://learn.extension.org/'
    @@configtable['cop_site'] = 'http://cop.extension.org/wiki'
    @@configtable['collaborate_site'] = 'http://collaborate.extension.org/wiki/'
    @@configtable['create_site'] = 'http://create.extension.org/'
    @@configtable['about_blog'] = 'http://about.extension.org/'
    @@configtable['help_wiki'] = 'http://docs.extension.org/wiki/' 
    @@configtable['public_site'] = 'http://www.extension.org'
    @@configtable['search_site'] = 'http://search.extension.org'
    @@configtable['aae_site'] = 'http://aae.extension.org'
    @@configtable['campus_site'] = 'http://campus.extension.org/ '
    @@configtable['pdc_site'] = 'http://pdc.extension.org/ '


    # token timeouts are in days
    @@configtable['token_timeout_email'] = 7
    @@configtable['token_timeout_resetpass'] = 1
    
    # invitation timeout is in days
    @@configtable['invitation_token_timeout'] = 30
    
    # if an account is stuck in signup or pending review for over 30 days, we are going to delete the accounts
    @@configtable['account_cleanup_delta'] = 30
    
    # recent deltas are in days
    @@configtable['recent_account_delta'] = 7
    @@configtable['recent_activity_delta'] = 7
    @@configtable['recent_login_delta'] = 7
        
    # tag related
    @@configtable['systemuser_sharedtag_weight'] = 2

    @@configtable['url_options'] = {'host' => 'www.extension.org', 'port' => 80, 'protocol' => 'http://'}
    
    # used to push IP Address down into the models, for the email crons
    @@configtable['default_request_ip'] = '127.0.0.1'
    @@configtable['request_ip_address'] = '127.0.0.1'
    
    # hardcoded names for the announcement mailing lists
    @@configtable['list-announce'] = 'announce'
    @@configtable['list-announce-all'] = 'announce-all'
    @@configtable['default-list-owner'] = 'extensionlistsmanager@extension.org'
    # mailman
    @@configtable['mailmanpath'] = '/services/mailman/bin'
    @@configtable['python-binary'] = '/usr/bin/python'
    
    # cache expiry
    @@configtable['cache-expiry'] = {}
    @@configtable['cache-expiry']['Activity'] = 1.hour
    @@configtable['cache-expiry']['User'] = 1.hour
    @@configtable['cache-expiry']['Location'] = 1.hour
    @@configtable['cache-expiry']['Position'] = 1.hour
    @@configtable['cache-expiry']['Institution'] = 1.hour
    @@configtable['cache-expiry']['Community'] = 1.hour

    @@configtable['cache-expiry']['Page'] = 1.hour

    # defaults for date ranges for reports
    @@configtable['default_datefield'] = 'created_at'
    @@configtable['default_dateinterval'] = 'withinlastmonth'
    @@configtable['default_timezone'] = 'utc'
    
    # arbitrary maximums
    @@configtable['default_content_limit'] = 3
    @@configtable['max_content_limit'] = 25
    @@configtable['events_within_days'] = 5
    # value is days
    @@configtable['recent_feature_limit'] = 30
    
    @@configtable['default_feed_content_limit'] = 50
    @@configtable['max_feed_content_limit'] = 200
    
    
    @@configtable['cse_id'] = 'NotSet'
    @@configtable['cse_secret'] = 'NotSet'
    
    # Akismet spam blocker key
    @@configtable['akismet_key'] = 'default'
    
		# Google CSE ID 
		@@configtable['old_goog_cse_key'] = '018217748441857184963:boqsgyytwwe'
		@@configtable['goog_cse_key'] = '010978498346658208303:rljk-euizvq'
		
		# Google Maps Key
		@@configtable['google_map_key'] = "ABQIAAAA1LmtLYh4TNIbY5g8p1Lv7RTX9Q_j-d1gVWC6rr14ybx0yf1UjRTepIB7tNRw_H6gggFEgWdIu5E7ig"
    
    # Google Apps settings
    @@configtable['googleapps_account'] = 'NotSet'
    @@configtable['googleapps_secret'] = 'NotSet'
    @@configtable['googleapps_domain'] = 'apps.extension.org'
    # Google Apps - AaE emailer
    @@configtable['googleapps_aaemailer'] = 'NotSet'
    @@configtable['googleapps_aaemailer_secret'] = 'NotSet'

    
    
    # Ask an expert settings
    @@configtable['auto_assign_incoming_questions'] = true
    @@configtable['faq_create_url'] = 'http://create.extension.org/node/add/faq'
     
    @@configtable['geoip_data_file'] = "#{RAILS_ROOT}/data/GeoIP/GeoIPCity.dat"

  end
  
  def AppConfig.get_url_port
    if(@@configtable['url_options']['port'] == 80 and @@configtable['url_options']['protocol'] == 'http://')
      return nil
    elsif(@@configtable['url_options']['port'] == 443 and @@configtable['url_options']['protocol'] == 'https://')
      return nil
    else
      return @@configtable['url_options']['port']
    end
  end
  
  def AppConfig.get_url_host
    return @@configtable['url_options']['host']
  end
  
  def AppConfig.get_url_protocol
    return @@configtable['url_options']['protocol']
  end
  
    
  def AppConfig.url_port_string
    if(port = self.get_url_port)
      return ":#{@@configtable['url_options']['port']}"
    else
      return ''
    end
  end
  
  def AppConfig.openid_endpoint
    location = @@configtable['app_location']      
    if(@@configtable['openid_endpoint'][location].nil? or @@configtable['openid_endpoint'][location] == 'request_url')
      return "#{@@configtable['url_options']['protocol']}#{@@configtable['url_options']['host']}#{AppConfig.url_port_string}/opie"
    else
      return @@configtable['openid_endpoint'][location]
    end
  end
  
  def AppConfig.set_content_widget_css
    css_data = File.new("#{RAILS_ROOT}/public/stylesheets/content_widget.css", 'r').read
    @@content_widget_styles = '<br /><style type="text/css" media="screen">' + css_data + '</style>'
  end
  
  def AppConfig.geoip_data_file
    if(File.exists?(@@configtable['geoip_data_file']))
      return @@configtable['geoip_data_file']
    else
      return nil
    end
  end
  
  def AppConfig.load_config
    self.default_config
    configfile ="#{RAILS_ROOT}/config/appconfig.yml"
    if File.exists?(configfile) then
      temp = YAML.load_file(configfile)
      if temp.class == Hash
        @@configtable.merge!(temp)
      end
    end    
  end
  

  


  # load the configuration on Class load
  self.load_config 
  # set css for content widgets on Class load
  self.set_content_widget_css 
end