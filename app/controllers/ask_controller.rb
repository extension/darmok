# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class AskController < ApplicationController  
  has_rakismet :only => [:submit_question]
  before_filter :login_optional
  
  def index
    @right_column = false
    session[:return_to] = params[:redirect_to]
    flash.now[:googleanalytics] = '/ask-an-expert-form'
    
    set_title("Ask an Expert - eXtension", "New Question")
    set_titletag("Ask an Expert - eXtension")

    # if we are editing
    if params[:submitted_question]
      flash.now[:googleanalytics] = '/ask-an-expert-edit-question'
      set_titletag("Edit your Question - eXtension")
      begin
        if(params[:public_user])
          @public_user = PublicUser.find_and_update_or_create_by_email(params[:public_user])
        else
          @public_user = PublicUser.new
        end
        
        @submitted_question = SubmittedQuestion.new(params[:submitted_question])
        @submitted_question.location_id = params[:location_id]
        @submitted_question.county_id = params[:county_id]
        @submitted_question.setup_categories(params[:aae_category], params[:subcategory])
        @top_level_category = @submitted_question.top_level_category if @submitted_question.top_level_category
        @sub_category = @submitted_question.sub_category.id if @submitted_question.sub_category
        
        if @top_level_category 
          @sub_category_options = [""].concat(@top_level_category.children.map{|sq| [sq.name, sq.id]})
        else
          @sub_category_options = [""]
        end
        # run validator to display any input errors
        @submitted_question.valid?
        @public_user.valid?
      rescue
        @public_user = PublicUser.new
        @submitted_question = SubmittedQuestion.new
      end
    else
      @public_user = PublicUser.new
      @submitted_question = SubmittedQuestion.new
    end
    
    @location_options = get_location_options
    @county_options = get_county_options
    
    @categories = [""].concat(Category.launched_content_categories.map{|c| [c.name, c.id]})
  end
  
  def question_confirmation
    if params[:q] and params[:q].strip != '' 
      params[:submitted_question][:asked_question] = params[:q]
      flash.now[:googleanalytics] = '/ask-an-expert-search-results'
      set_title("Ask an Expert - eXtension", "Confirmation")
      set_titletag("Search Results for Ask an Expert - eXtension")
    
      @submitted_question = SubmittedQuestion.new(params[:submitted_question])
    
      unless @submitted_question.valid?
        redirect_to :action => 'index', 
                    :submitted_question => params[:submitted_question], 
                    :location_id => params[:location_id], 
                    :county_id => params[:county_id], 
                    :aae_category => params[:aae_category], 
                    :subcategory => params[:subcategory]
      end
    else
      flash[:notice] = "Please fill in the required fields before submitting."
      redirect_to :action => :index
    end
      
  end
  
  def question
    @right_column = false
    @submitted_question = SubmittedQuestion.find_by_question_fingerprint(params[:fingerprint])
    
    if !@submitted_question
      do_404
      return
    elsif !@currentuser.nil?
      return
    elsif !@submitted_question.show_publicly?
      render :template => 'ask/question_status'
      return
    else
      # authorized public user check
      if(!session[:public_user_id].nil? and (public_user = PublicUser.find_by_id(session[:public_user_id])))
        # make sure that this question belongs to this user
        if(@submitted_question.public_user != public_user)
          session[:public_user_id] = nil
          render :template => 'ask/question_status'
          return
        end
      else
        render :template => 'ask/question_signin'
        return
      end
    end
    
  end
  
  
  def authorize_public_user
    @right_column = false
    @submitted_question = SubmittedQuestion.find_by_question_fingerprint(params[:fingerprint])
    if !@submitted_question
      render :template => 'ask/question_status'
      return
    end
    
    if (params[:email_address] and params[:email_address].strip != '') and (public_user = PublicUser.find_by_email(params[:email_address])) and (request.post?)
      session[:public_user_id] = public_user.id
      redirect_to :action => :question, :fingerprint => params[:fingerprint]
      return
    end
    
    flash.now[:warning] = "The email address you entered does not match the email used to submit the question. Please check the email address and try again."
    render :template => 'ask/question_signin'
  end
  
  def submit_question
    if request.post?
      @public_user = PublicUser.find_and_update_or_create_by_email(params[:public_user])
      @submitted_question = SubmittedQuestion.new(params[:submitted_question])
      @submitted_question.location_id = params[:location_id]
      @submitted_question.county_id = params[:county_id]
      @submitted_question.setup_categories(params[:aae_category], params[:subcategory])
      @submitted_question.status = 'submitted'
      @submitted_question.user_ip = request.remote_ip
      @submitted_question.user_agent = request.env['HTTP_USER_AGENT']
      @submitted_question.referrer = (request.env['HTTP_REFERER']) ? request.env['HTTP_REFERER'] : ''
      @submitted_question.status_state = SubmittedQuestion::STATUS_SUBMITTED
      @submitted_question.status = SubmittedQuestion::SUBMITTED_TEXT
      @submitted_question.external_app_id = 'www.extension.org'
      @submitted_question.public_user = @public_user
      # for easier akismet checking, set the submitter_email attribute from the associated public_user
      @submitted_question.submitter_email = @public_user.email
      
    
      # let's check for spam
      begin
        @submitted_question.spam = @submitted_question.spam?
      rescue Exception => ex
        logger.error "Error checking submitted question from pubsite aae form for spam via Akismet at #{Time.now.to_s}. Akismet webservice might be experiencing problems.\nError: #{ex.message}"
      end
    
      if !@submitted_question.valid? || !@public_user.valid? || !@submitted_question.save
        flash[:notice] = 'There was an error saving your question. Please try again.'
        redirect_to :action => 'index'
        return
      end
      
      session[:public_user_id] = @public_user.id
    
      flash[:notice] = 'Your question has been submitted and the answer will be sent to your email. Our experts try to answer within 48 hours.'
      flash[:googleanalytics] = '/ask-an-expert-question-submitted'
      if session[:return_to]
        redirect_to(session[:return_to]) 
      else
        redirect_to '/'
      end
    else
      flash[:warning] = "Please enter your question via the ask an expert form"
      redirect_to ask_form_url
    end
  end
  
  def get_aae_form_subcats
    parent_cat = Category.find_by_id(params[:category_id].strip) if params[:category_id] and params[:category_id].strip != '' 
    if parent_cat 
      @sub_category_options = [""].concat(parent_cat.children.map{|sq| [sq.name, sq.id]})
    else
      @sub_category_options = [""]
    end
    
    render :partial => 'aae_subcats', :layout => false
  end
    
end
