# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

module People::ProfileHelper
  
  def fields_for_social_network(social_network, &block)
    prefix = social_network.new_record? ? 'new' : 'existing'
    fields_for("socialnetworks[#{prefix}][]", social_network, &block)
  end
  
  def add_socialnetwork_link(linktext,networkname) 
    link_to_remote(linktext, {:url => {:action => :xhr_newsocialnetwork, :networkname => networkname}, :method => :post}, :title => "#{linktext} Network: #{networkname}")
  end
    
  def accounturl_link(accounturl)
    return ( !accounturl.nil? and accounturl != '' and accounturl != "accounturl" ) ? "<a href=\"#{accounturl}\">#{accounturl}</a>" : ''
  end
  
  def accounturl_directions(social_network)
    SocialNetwork::NETWORKS.keys.include?(social_network.network) ? "<span class=\"directions\">#{SocialNetwork::NETWORKS[social_network.network][:urlformatnotice]}</span>" : ''
  end
  
  def social_network_link(social_network)
    if(!social_network.accounturl.blank?)
      begin
        accounturi = URI.parse(URI.escape(social_network.accounturl))
      rescue
        return social_network.accountid
      end
      if(accounturi.scheme.nil?)
        uristring = 'http://'+social_network.accounturl
      else
        uristring = social_network.accounturl
      end
      return "<a href=\"#{uristring}\">#{social_network.accountid}</a>"
    else
      return social_network.accountid
    end
  end
  
  def social_network_name(social_network)
    SocialNetwork::NETWORKS.keys.include?(social_network.network) ? SocialNetwork::NETWORKS[social_network.network][:displayname] : social_network.displayname
  end
  
  def social_network_class(networkname)
    SocialNetwork::NETWORKS.keys.include?(networkname) ? networkname : 'other'
  end
  
end