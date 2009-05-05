# === COPYRIGHT:
#  Copyright (c) 2005-2006 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

# To Do: Need to add associations for tagging which will be treated like categories and subcategories
belongs_to :county
belongs_to :location
has_many :submitted_question_events
belongs_to :contributing_faq, :class_name => "Question", :foreign_key => "current_contributing_faq"
belongs_to :assignee, :class_name => "User", :foreign_key => "user_id"
belongs_to :resolved_by, :class_name => "User", :foreign_key => "resolved_by"

validates_presence_of :asked_question
validates_presence_of :status
validates_presence_of :status_state
validates_presence_of :external_submitter
# check the format of the question submitter's email address
validates_format_of :external_submitter, :with => /\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

before_update :add_resolution
after_save :assign_parent_categories
after_create :auto_assign_by_preference

has_rakismet :author_email => self.external_submitter,
             :comment_type => "ask an expert question",
             :content => self.asked_question,
             :user_ip => self.user_ip,
             :user_agent => self.user_agent,
             :referrer => self.referrer


# adds resolved date to submitted questions on save or update and also 
# calls the function to log a new resolved submitted question event 
def add_resolution
  if !id.nil?      
    if self.status_state == STATUS_RESOLVED || self.status_state == STATUS_REJECTED || self.status_state == STATUS_NO_ANSWER
      if self.status_state_changed? or self.current_response_changed? or self.resolved_by_changed?        
        t = Time.now
        self.resolved_at = t.strftime("%Y-%m-%dT%H:%M:%SZ")
        if self.status_state == STATUS_RESOLVED
          SubmittedQuestionEvent.log_resolution(self)
        elsif self.status_state == STATUS_REJECTED
          SubmittedQuestionEvent.log_rejection(self)
        elsif self.status_state == STATUS_NO_ANSWER
          SubmittedQuestionEvent.log_no_answer(self)
        end
      end
    end
  end
end

def category_names
  if self.categories.length == 0
    return 'uncategorized'
  else
    if self.categories.length > 1 and subcat = self.categories.detect{|c| c.parent_id}
      return subcat.full_name
    else
      return self.categories[0].name 
    end
  end
end

def to_faq(user)
  question = Question.new
  revision = Revision.new(:user => user)
  
  question.revisions << revision
  revision.question_text = asked_question
  
  return question
end

def resolved?
  !self.resolved_at.nil?
end

def assign_parent_categories
  categories.each do |category|
    if category.parent and !categories.include?(category.parent)
      categories << category.parent
    end
  end
end

def reject(user, message)
  if self.update_attributes(:status => SubmittedQuestion::REJECTED_TEXT, :status_state => SubmittedQuestion::STATUS_REJECTED, :current_response => message, :resolved_by => user, :resolver_email => user.email)
    return true
  else
    return false
  end
end

#find the date that this submitted question was assigned to the current assignee
def assigned_date
  sqevent = self.submitted_question_events.find(:first, :conditions => "event_state = '#{SubmittedQuestionEvent::ASSIGNED_TO}'", :order => "created_at desc")
  #make sure that this event is valid by making sure that the user between the event and the submitted question match up
  if sqevent and (sqevent.subject_user.id == self.assignee.id)
    return sqevent.created_at
  else
    return nil
  end
end

def get_submitter_name
  return self.submitter_firstname + ' ' + self.submitter_lastname
end

def auto_assign_by_preference
  if existing_sq = SubmittedQuestion.find(:first, :conditions => ["id != #{self.id} and asked_question = ? and external_submitter = '#{self.external_submitter}'", self.asked_question])
    reject_msg = "This question was a duplicate of incoming question ##{existing_sq.id}"
    if !self.reject(User.find_by_login('faq_bot'), reject_msg)
      logger.error("Submitted Question #{self.id} did not get properly saved on rejection.")
    end
    return
  end
  
  if AppConfig.configtable['auto_assign_incoming_questions']
    auto_assign
  end
end

def auto_assign
  assignee = nil
  # first, check to see if it's from a named widget 
  # and route accordingly
  if widget_name = self.widget_name
    widget = Widget.find_by_name(widget_name)  
    if widget
      assignee = pick_user_from_list(widget.assignees)
    end
  end
  
  if !assignee
    if !self.categories || self.categories.length == 0
      question_categories = nil
    else
      question_categories = self.categories
      parent_category = question_categories.detect{|c| !c.parent_id}
    end
  
    # if a state and county were provided when the question was asked
    # update: if there is location data supplied and there is not a category 
    # associated with the question, then route to the uncategorized question wranglers 
    # that chose that location or county in their location preferences
    if self.county and self.location
      assignee = pick_user_from_county(self.county, question_categories) 
    #if a state and no county were provided when the question was asked
    elsif self.location
      assignee = pick_user_from_state(self.location, question_categories)
    end
  end
  
  # if a user cannot be found yet...
  if !assignee
    if !question_categories
      # if no category, wrangle it
      assignee = pick_user_from_list(User.uncategorized_wrangler_routers)
    else
      # got category, first, look for a user with specified category
      assignee = pick_user_from_category(question_categories)
      # still ain't got no one? send to the wranglers to wrangle
      assignee = pick_user_from_list(User.uncategorized_wrangler_routers) if not assignee
    end
      
  end
  
  if assignee
    faq_bot_user = User.find_by_login('faq_bot')
    assign_to(assignee, faq_bot_user, nil)
  else
    return
  end
end

# Assigns the question to the user, logs the assignment, and sends an email
# to the assignee letting them know that the question has been assigned to
# them.
def assign_to(user, assigned_by, comment)
  raise ArgumentError unless user and user.instance_of?(User)
  return if assignee and user.id == assignee.id
  SubmittedQuestionEvent.log_assignment(self, user, assigned_by, comment)
  update_attributes(:assignee => user, :current_response => comment)
end

##Class Methods##

# given the category, get all of the users who 
# have expertise in that category and have opted 
# to receive escalation emails for their areas of expertise
def self.question_escalators_by_category(category)
  escalation_role = Role.find_by_name(Role::ESCALATION)
  escalation_user_ids = escalation_role.users.find(:all, :conditions => "users.retired = false").uniq.collect{|u| u.id}.join(',')

  if (escalation_user_ids and escalation_user_ids.strip != '')
    users = category.users.find(:all, 
                                :conditions => "users.id IN (#{escalation_user_ids})")
  end
  
  if users and not users.empty? 
    return users 
  else
    return nil
  end

end

#finds submitted_questions for views like incoming questions and resolved questions
def self.find_submitted_questions(sq_query_method, category = nil, location = nil, county = nil, source = nil, user = nil, assignee = nil, page_number = nil, paginated = true, is_spam = false, result_order = nil)

  result_order ? order_var = result_order : order_var = "submitted_questions.created_at desc"
  cond_str = ''
  
  if category
    if category == Category::UNASSIGNED
      cond_str += " AND categories.id IS NULL"
    else
      #look for the submitted questions of the category and all subcategories of the category
      if category.children and category.children.length > 0
        subcat_ids = category.children.map{|sc| sc.id}.join(',')
        cat_ids = subcat_ids + ",#{category.id}"
        cond_str += " AND categories.id IN (#{cat_ids})"        
      else
        cond_str += " AND categories.id = #{category.id}"
      end
    end
  end
  
  if user
    cond_str += " AND submitted_questions.resolved_by = #{user.id}"
  end
  
  if assignee
    cond_str += " AND submitted_questions.user_id = #{assignee.id}"
  end
 
  if location
    cond_str += " AND submitted_questions.location_id = #{location.id}"
  end

  if county
    cond_str += " AND submitted_questions.county_id = #{county.id}"
  end
  
  if source
    case source
      when 'pubsite'
        cond_str += " AND submitted_questions.external_app_id != 'widget'"
      when 'widget'
        cond_str += " AND submitted_questions.external_app_id = 'widget'"
      else
        source_int = source.to_i
        if source_int != 0
          widget = Widget.find(:first, :conditions => "id = #{source_int}")
        end
  
        if widget
          cond_str += " AND submitted_questions.widget_name = '#{widget.name}'"
        end
      end
  end
  
  cond_str += " AND submitted_questions.spam = #{is_spam}"
  
  if paginated
    if category
      return SubmittedQuestion.send(sq_query_method, [:categories], cond_str).by_order(order_var).paginate(:page => page_number, :per_page => AppConfig.configtable['items_per_page'])
    else
      return SubmittedQuestion.send(sq_query_method, [], cond_str).by_order(order_var).paginate(:page => page_number, :per_page => AppConfig.configtable['items_per_page'])
    end
  else
    if category
      return SubmittedQuestion.send(sq_query_method, [:categories], cond_str).by_order(order_var)
    else
      return SubmittedQuestion.send(sq_query_method, [], cond_str).by_order(order_var)
    end
  end
end

def self.find_uncategorized(*args)
  with_scope(:find => { :conditions => "categories.id IS NULL", :include => :categories }) do
    find(*args)
  end
end

# utility function to convert status_state numbers to status strings
def self.convert_to_string(status_number)
  case status_number
  when STATUS_SUBMITTED
    return 'submitted'
  when STATUS_RESOLVED
    return 'resolved'
  when STATUS_NO_ANSWER
    return 'no answer'
  when STATUS_REJECTED
    return 'rejected'
  else
    return nil
  end
end

def self.find_with_category(category, *args)
  with_scope(:find => { :conditions => "category_id = #{category.id} or categories.parent_id = #{category.id}", :include => :categories }) do
    find(*args)
  end
end


private

def pick_user_from_list(users)
  if !users or users.length == 0
    return nil
  end
  
  users.sort! { |a, b| a.assigned_questions.count(:conditions => "status_state = #{STATUS_SUBMITTED}") <=> b.assigned_questions.count(:conditions => "status_state = #{STATUS_SUBMITTED}")}

  questions_floor = users[0].assigned_questions.count(:conditions => "status_state = #{STATUS_SUBMITTED}")

  possible_users = users.select { |u| u.assigned_questions.count(:conditions => "status_state = #{STATUS_SUBMITTED}") == questions_floor }
  
  return nil if !possible_users or possible_users.length == 0

  return possible_users[0] if possible_users.length == 1

  assignment_dates = Hash.new
  
  possible_users.each do |u|
    question = u.assigned_questions.find(:first, :conditions => ["event_state = ?", SubmittedQuestionEvent::ASSIGNED_TO], :include => :submitted_question_events, :order => "submitted_question_events.created_at desc")

    if question
      assignment_dates[u.id] = question.submitted_question_events[0].created_at
    else
      assignment_dates[u.id] = Time.at(0)
    end
  end

  user_id = assignment_dates.sort{ |a, b| a[1] <=> b[1] }[0][0]

  return User.find(user_id)
end

def pick_user_from_county(county, question_categories)
  # if a county was selected for this question and there are users for this county
  county_users = User.narrow_by_routers(county.users, Role::AUTO_ROUTE)
  if county_users and county_users.length > 0
    # if there were categories
    if question_categories
      if subcat = question_categories.detect{|c| c.parent_id} 
        cat_county_users = subcat.get_user_intersection(county_users)
        # if there are no common users that have the subcat and county, then try the location and subcat intersection
        if !cat_county_users or cat_county_users.length == 0
          loc_subcat_user = pick_user_from_state(county.location, question_categories)
          # if there was no county, subcat intersection or location, subcat intersection, then use the subcat's users
          if loc_subcat_user  
            return loc_subcat_user 
          else
            cat_county_users = User.narrow_by_routers(subcat.users, Role::AUTO_ROUTE, true)
          end
        end  
      end
      # if no subcats, but top levels cats are associated with this question
      if (!cat_county_users or cat_county_users.length == 0) and (top_level_cat = question_categories.detect{|c| !c.parent_id})
        cat_county_users = top_level_cat.get_user_intersection(county_users)
        # if there are no common users between the top level category's users and the counties' users, then try the top level cat and location intersection
        if !cat_county_users or cat_county_users.length == 0
          loc_cat_user = pick_user_from_state(county.location, question_categories)
          if loc_cat_user 
            return loc_cat_user
          else
            cat_county_users = User.narrow_by_routers(top_level_cat.users, Role::AUTO_ROUTE, true)
          end
        end
      end 

    end # end of 'were there categories'

    # if there is no category or no users for the category, then get 
    # the intersection of the uncat. quest. wranglers and the users for this county
    if !cat_county_users or cat_county_users.length == 0
      uncat_wranglers = User.uncategorized_wrangler_routers
      uncat_county_users = county.users.find(:all, :conditions => "users.id IN (#{uncat_wranglers.collect{|u| u.id}.join(',')})")
      # if there are no uncat. quest. wranglers with the preference set for this county, then route by location with no category
      if !uncat_county_users or uncat_county_users.length == 0
        return pick_user_from_state(county.location, nil)
      else
        return pick_user_from_list(uncat_county_users)
      end
    # if there were users for a category or users for a category that had that county preference set
    else
      return pick_user_from_list(cat_county_users)
    end
  # there were no users for this county  
  else
    return pick_user_from_state(county.location, question_categories)
  end # end of 'are there county users'
end

def pick_user_from_state(location, question_categories)
  all_county_loc = location.counties.find(:first, :conditions => "countycode = '0'")
  all_county_loc ? all_county_users = User.narrow_by_routers(all_county_loc.users, Role::AUTO_ROUTE) : all_county_users = nil
  
  #if a location was selected for this question and there are users for this location
  if all_county_users and all_county_users.length > 0
    
    #if a category was selected for this question
    if question_categories
      if subcat = question_categories.detect{|c| c.parent_id}
        cat_location_users = subcat.get_user_intersection(all_county_users)
        #if there were no common users between the location's users and the subcat's users, then use the subcat's users
        if !cat_location_users or cat_location_users.length == 0
          cat_location_users = User.narrow_by_routers(subcat.users, Role::AUTO_ROUTE, true)
        end
      end
      
      #if there was a top level category associated with the question and the top level category had users associated with it
      if (!cat_location_users or cat_location_users.length == 0) and (top_level_cat = question_categories.detect{|c| !c.parent_id})  
        cat_location_users = top_level_cat.get_user_intersection(all_county_users)
        #if there were no common users between the top level category's users and the location's users, then use the top level category's users
        if !cat_location_users or cat_location_users.length == 0
          cat_location_users = User.narrow_by_routers(top_level_cat.users, Role::AUTO_ROUTE, true)
        end
      end
      
    end # end of 'does it have categories'

    # if there is no category or no users for the category, then find the 
    # uncategorized question wranglers with this location preference set
    if !cat_location_users or cat_location_users.length == 0
      uncat_wranglers = User.uncategorized_wrangler_routers
      uncat_location_users = all_county_loc.users.find(:all, :conditions => "users.id IN (#{uncat_wranglers.collect{|u| u.id}.join(',')})")
      # if there are no common users amongst uncat. quest. wranglers and location users
      if !uncat_location_users or uncat_location_users.length == 0
        return nil
      else
        return pick_user_from_list(uncat_location_users)
      end
    # if there were users found above for a category or combination of category and location
    else
      return pick_user_from_list(cat_location_users)
    end 
  end # end of 'does the location have users'

  # if there were no users that had the all state preference set
  return nil
end

def pick_user_from_category(question_categories)
  assignee = nil
  #look for subcategory first and make sure subcat has users
  if subcat = question_categories.detect{|c| c.parent_id } and subcat_users = subcat.users and subcat_users.length > 0
    assignee = pick_user_from_list(User.narrow_by_routers(subcat_users, Role::AUTO_ROUTE, true))
  end
  #if no subcat, then find the top_level category and make sure it has users
  if !assignee
    if top_level_cat = question_categories.detect{|c| !c.parent_id} and top_level_cat_users = top_level_cat.users and top_level_cat_users.length > 0
      assignee = pick_user_from_list(User.narrow_by_routers(top_level_cat_users, Role::AUTO_ROUTE, true))
    end
  end
  
  assignee
end





