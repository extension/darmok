# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class ReportsController < ApplicationController
  layout 'frontporch'
  before_filter :signin_optional

  def index
    set_title("Reports")
    set_title("Reports - eXtension")
    @right_column = false
  end

  def graphs
    data_url = "#{AppConfig.configtable['data_site']}"
    return redirect_to(data_url, :status => :moved_permanently)
  end

  def publishedcontent
    data_url = "#{AppConfig.configtable['data_site']}pages/publishedcontent"
    return redirect_to(data_url, :status => :moved_permanently)
  end

  def activitygraph
    data_url = "#{AppConfig.configtable['data_site']}"
    return redirect_to(data_url, :status => :moved_permanently)
  end


end
