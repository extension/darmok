# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE
class AdminController < ApplicationController
  before_filter :admin_required
  before_filter :check_purgatory
  before_filter :turn_off_right_column

  def index
    set_titletag("eXtension Pubsite Admin")
  end
    
  def manage_topics
    @right_column = false
    set_titletag("Manage Topics - Pubsite Admin")
    @topics = Topic.find(:all)
  end
  
  def destroy_topic
    Topic.destroy(params[:id])
    redirect_to :action => :manage_topics
  end
  
  def create_topic
    Topic.create(params[:topic])
    redirect_to :action => :manage_topics
  end
  
  def manage_communities
    set_titletag("Manage Communities - Pubsite Admin")    
    @approved_communities =  Community.approved.all(:order => 'name')
    @other_public_communities = Community.usercontributed.public_list.all(:order => 'name')
  end
  
  def manage_institutions
    set_titletag("Manage Institutions - Pubsite Admin")    
    @landgrant_institutions =  Institution.public_list.all(:order => 'location_abbreviation')
  end
    
  def manage_locations_office_links
    set_titletag("Manage Office Links - Pubsite Admin")    
    @locations =  Location.displaylist
  end
  
  def edit_location_office_link
    set_title('Edit Location Office Link')
    set_titletag("Edit Location Office Link - Pubsite Admin")
    @location = Location.find(params[:id])    
  end
  
  def update_location_office_link
    @location =  Location.find(params['id'])
    @location.office_link = params['location']['office_link']

    if @location.save
      flash[:notice] = 'Location Updated'
    else
      flash[:notice] = 'Error updating location'
    end
    redirect_to :action => :manage_locations_office_links

  end
    
  def update_public_community
    @community =  Community.find(params['id'])
    @community.public_topic_id = params['community']['public_topic_id']
    @community.public_description = params['community']['public_description']
    @community.public_name = params['community']['public_name']
    @community.is_launched = ( params['community']['is_launched'] ? true : false)
    
    
    # sanity check tag names
    this_community_content_tags = @community.tags_by_ownerid_and_kind(User.systemuserid,Tag::CONTENT)
    other_community_tags = Tag.community_content_tags - this_community_content_tags
    other_community_tag_names = other_community_tags.map(&:name)
    updatelist = Tag.castlist_to_array(params['community']['content_tag_names'],true)
    invalid_tags = []
    updatelist.each do |tagname|
      invalid_tags << tagname if other_community_tag_names.include?(tagname)
    end
    
    if(!invalid_tags.blank?)
      flash[:notice] = "The following tag names are in use by other communities: #{invalid_tags.join(Tag::JOINER)}"
      return(render(:action => "edit_public_community"))
    end

    if @community.save
      flash[:notice] = 'Community Updated'
      @community.content_tag_names=(params['community']['content_tag_names'])
      redirect_to :action => :manage_communities
    else
      flash[:notice] = 'Error updating community'
      return(render(:action => "edit_public_community"))
    end
  end
    
  def edit_public_community
    set_title('Edit Community Public Options')
    set_titletag("Edit Community - Pubsite Admin")
    @community = Community.find(params[:id])
  end
  
  def update_public_institution
    @institution =  Institution.find(params['id'])
    @institution.referrer_domain = params['institution']['referrer_domain']
    @institution.public_uri = params['institution']['public_uri']

    if @institution.save
      flash[:notice] = 'Institution Updated'
    else
      flash[:notice] = 'Error updating institution'
    end
    redirect_to :action => :manage_institutions
  end
    
  def edit_public_institution
    set_title('Edit Institution Public Options')
    set_titletag("Edit Institution - Pubsite Admin")
    @institution = Institution.find(params[:id])
  end
  
  def retrieve_wikis
    WikiFeed.retrieve_wikis
    WikiChangesFeed.retrieve_wikis
    finished_retrieving("Wiki articles")
  rescue Exception => e
    handle_feed_error(e, WikiFeed)
  end
    
  def retrieve_events
    XCal.retrieve_events
    finished_retrieving("Events")
  rescue Exception => e
    handle_feed_error(e, XCal)
  end
  
  def retrieve_faqs
  #   Heureka.retrieve_faqs
  #   finished_retrieving("FAQs")
  # rescue Exception => e
  #   handle_feed_error(e, Heureka)
  end
      
  def retrieve_external_articles
    ExternalArticleFeed.retrieve_feeds
    finished_retrieving("External Feed")
  rescue Exception => e
    backtrace = e.backtrace.join("\n")
    flash[:error] = "Unsucessfully retrieved items from the feed."
    #MainMailer.deliver_feed_error("External feed", "#{e}\n #{backtrace}")
    redirect_to :action => "index"
  end
    
  private

  def finished_retrieving(what)
    ActiveRecord::Base::logger.debug "Imported #{what} at: " + Time.now.to_s    
    flash[:notice] = "#{what} articles retrieved."
    redirect_to :action => "index"
  end
  
  def handle_feed_error(e, feed)
    backtrace = e.backtrace.join("\n")
    flash[:error] = "Unsucessfully retrieved items from the feed."
    #MainMailer.deliver_feed_error(feed.full_url, "#{e}\n #{backtrace}")
    redirect_to :action => "index"
  end
  
end
