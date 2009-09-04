# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class ReportsController < ApplicationController
  layout 'reports'
  before_filter :login_optional
  
  def index    
    set_title("Reports")
    set_titletag("Reports - eXtension")
    @right_column = false
  end
  
  
  def graphs
  end
  
  def publishedcontent
    fp = FilterParams.new(params)
    set_title("Published Content by Community")
    set_titletag("Reports - eXtension")
    @right_column = false
    @date = fp.datadate.nil? ? Date.yesterday : fp.datadate
    @published_values = DailyNumber.all_published_item_counts_for_date(@date)
  end
  
  def activitygraph
    datatype = params[:datatype].nil? ? 'hourly' : params[:datatype]
    if(params[:primary_type].nil?)
      @graphtype = params[:graphtype] || ((datatype == 'weekday' or datatype == 'hourly') ? 'column' : 'area')
    else # assume comparison
      @graphtype = params[:graphtype] || 'area'
    end
    
    urloptions = params
    urloptions.merge!({:action => :activitytable,:controller => :data, :datatype => datatype, :graphtype => @graphtype}) 
    
    @page_title = "#{datatype.capitalize} Activity"
    
    if(params[:dateinterval])
      @page_title += " (dates: #{@dateinterval})"
    end
    
    @chart_options = {:querysource => url_for(urloptions)}
       
    if (@graphtype == 'column')
      @chart_partial = 'reports/columnchart'
      @chart_options.merge!({:width => 800,:height => 480,:chartdiv => 'visualization_chart',:legend => 'bottom',:lineSize => 2, :pointSize => 3})
    elsif(@graphtype == 'timeline')
      @chart_partial = 'reports/timeline'
      @chart_options.merge!({:width => 800,:height => 480,:chartdiv => 'visualization_chart',:legend => 'bottom',:lineSize => 2, :pointSize => 3})
    else   
      @chart_partial = 'reports/areachart'
      @chart_options.merge!({:width => 800,:height => 480,:chartdiv => 'visualization_chart',:legend => 'bottom',:lineSize => 2, :pointSize => 3})
    end
  end
  
end
