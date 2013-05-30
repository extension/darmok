# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class People::HelpController < ApplicationController
  layout 'people'
  
  def index
    @isloggedin = checklogin
    return render :template => 'help/contactform.html.erb'
  end

  # in case this is bookmarked
  def contactform
    return redirect_to(:action => 'index')
  end
  
  private
  
  def checklogin
    if session[:userid]
      checkuser = User.find_by_id(session[:userid])
      if not checkuser
        return false
      else
        @currentuser = checkuser
        return true
      end
    else
      return false
    end
  end

end