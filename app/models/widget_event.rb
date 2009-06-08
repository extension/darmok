# === COPYRIGHT:
#  Copyright (c) 2005-2006 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class WidgetEvent < ActiveRecord::Base
  ACTIVATED = "activated"
  DEACTIVATED = "deactivated"
  
  belongs_to :user
  belongs_to :widget
  
  
  def self.log_event(widget_id, user_id, event)
    widget_event = WidgetEvent.create(:user_id => user_id, :widget_id => widget_id, :event => event)
    widget_event.save
  end
  
end