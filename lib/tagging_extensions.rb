

  # These extensions make models taggable. 
  module TaggingExtensions
    
    def default_tagging_kind
      Tagging::GENERIC
    end
        
    # Add tags to <tt>self</tt>. Accepts a string of tagnames, an array of tagnames, an array of ids, or an array of Tags.
    #
    # We need to avoid name conflicts with the built-in ActiveRecord association methods, thus the underscores.
    def _add_tags(tagarray,ownerid,kind,weight)
      taggable?(true)
      tagarray.each do |tag_name|
        normalized_tag_name = Tag.normalizename(tag_name)
        next if Tag::BLACKLIST.include?(normalized_tag_name)
        begin
          tag = Tag.find_or_create_by_name(normalized_tag_name)
          raise Tag::Error, "tag could not be saved: #{tag_name}" if tag.new_record?
          Tagging.create(:tag => tag, :taggable => self, :tagging_kind => kind, :tag_display => tag_name, :owner_id => ownerid, :weight => weight)          
        rescue ActiveRecord::StatementInvalid => e
          raise unless e.to_s =~ /duplicate/i
        rescue Tag::Error => e
          logger.debug("Tag Error #{e.to_s}")
        end
      end
    end
    
    # Removes tags from <tt>self</tt>. Accepts a string of tagnames, an array of tagnames, an array of ids, or an array of Tags.  
    def _remove_tags(tagarray,ownerid,kind)
      taggable?(true)
      # because of http://dev.rubyonrails.org/ticket/6466
      taggings.destroy(*(taggings.find(:all, :include => :tag, :conditions => ["tagging_kind = ? AND owner_id =?",kind,ownerid]).select do |tagging| 
        (tagarray.include? tagging.tag.name)  
      end))
      end

    # Replace or add the existing tags on <tt>self</tt>. Accepts a string of tagnames, an array of tagnames, an array of ids, or an array of Tags.
    def replace_tags(list,ownerid=Person.systemuserid,kind=self.default_tagging_kind,weight=1)    
      add_and_or_remove_tags({:taglist => list, :ownerid => ownerid, :kind => kind, :weight => weight, :replacetags => true})
    end
    
    def tag_with(list,ownerid=Person.systemuserid,kind=self.default_tagging_kind,weight=1)    
      add_and_or_remove_tags({:taglist => list, :ownerid => ownerid, :kind => kind, :weight => weight, :replacetags => false})
    end
    
    def add_and_or_remove_tags(options)    
      list = options[:taglist]
      ownerid = options[:ownerid] || Person.systemuserid
      kind = options[:kind] || self.default_tagging_kind
      weight = options[:weight] || 1
      replacetags = options[:replacetags].nil? ? 'true' : options[:replacetags]
      
      taggable?(true)
      tagarray = Tag.castlist_to_array(list,false)  # do not normalize the list
           
      # Transactions may not be ideal for you here; be aware.
      Tag.transaction do 
        current_tags = tags_by_ownerid_and_kind(ownerid,kind).map(&:name)
        # because tag array is not normalized, this will likely have dups, but won't create duplicate records
        _add_tags(tagarray - current_tags,ownerid,kind,weight)
        if(replacetags)  
          _remove_tags(current_tags - (tagarray.map{|tag| Tag.normalizename(tag)}),ownerid,kind)
        end
      end
      
      self
    end

    
    def remove_tags_and_update_cache(taglist,ownerid,kind)
      _remove_tags(taglist,ownerid,kind)
      cache_tags(ownerid,kind)
    end
    
    def cache_tags(ownerid,kind)

      # does this model have its own caching field?
      if(self.respond_to?(:cached_tag_field) and cached_tag_field = self.cached_tag_field(ownerid,kind))
        tagarray = self.tags_by_ownerid_and_kind(ownerid,kind)
        fulltextlist = tagarray.map(&:name).join(Tag::JOINER)
        self.update_attribute("#{cached_tag_field}",fulltextlist)
      end
      
    end
    
    def tag_with_and_cache(list,ownerid=Person.systemuserid,kind=self.default_tagging_kind,weight=1)
      tag_with(list,ownerid,kind,weight)
      cache_tags(ownerid,kind)
    end    
    
    def replace_tags_with_and_cache(list,ownerid=Person.systemuserid,kind=self.default_tagging_kind,weight=1)
      replace_tags(list,ownerid,kind,weight)
      cache_tags(ownerid,kind)
    end

   # Returns the tags on <tt>self</tt> as a string.
    def tag_list #:nodoc:
      taggable?(true)
      #tags.reload
      tags.to_s
    end
    
    def tag_count
      # TODO: this may be problematic down the line for an object with a lot of tags
      taggable?(true)
      taggings.count(:group => :tag)
    end  
    
    def tag_count_by_ownerid_and_kind(ownerid=Person.systemuserid,kind=Tagging::ALL)      
      # TODO: this may be problematic down the line for an object with a lot of tags
      taggable?(true)
      taggings.count(:group => :tag, :conditions => tagcond(ownerid,kind))
    end
    
    def tags_by_ownerid_and_kind(ownerid=Person.systemuserid,kind=Tagging::ALL)      
      taggable?(true)
      # has to be uniq by mysql index
      tags.find(:all, :select => "tags.*,count(tags.id) as frequency", :conditions => tagcond(ownerid,kind), :group => "tags.id")
    end
        
    def tag_list_by_ownerid_and_kind(ownerid=Person.systemuserid,kind=Tagging::ALL)
       tags_by_ownerid_and_kind(ownerid,kind).map(&:name).join(Tag::JOINER)
    end

     def tag_displaylist_by_ownerid_and_kind(ownerid=Person.systemuserid,kind=Tagging::ALL,returnarray=false)
       taggable?(true)
       array = taggings.find(:all, :conditions => tagcond(ownerid,kind)).map(&:tag_display)
       if(returnarray)
         array
       else
         array.join(Tag::JOINER)
       end
     end


    def my_top_tags(options={})
     options[:from] ||= "#{self.class.table_name}, tags, taggings"
     sql  = "SELECT tags.*, COUNT(taggings.tag_id) as frequency, SUM(taggings.weight) as weightedfrequency "
     sql << "FROM #{options[:from]} "
     sql << "WHERE #{self.class.table_name}.#{self.class.primary_key} = taggings.taggable_id "
     sql << "AND taggings.taggable_type = '#{self.class.name}' "
     sql << "AND taggings.tag_id = tags.id "
     sql << "AND #{self.class.table_name}.#{self.class.primary_key} = #{self.id} "            
     sql << "AND #{sanitize_sql(options[:conditions])} " if options[:conditions]
     sql << "GROUP BY tags.id "
     if(!options[:minweight].nil?)
       sql << "HAVING SUM(taggings.weight) >= #{options[:minweight]}"
     elsif(!options[:mincount].nil?)
       sql << "HAVING COUNT(taggings.tag_id) >= #{options[:mincount]}"
     end
 
     if(order = options[:order])         
       sql << " ORDER BY #{order}"
     end
 
     if limit = options[:limit]
       if limit.to_s =~ /,/
         limitcondition = limit.to_s.split(',').map{ |i| i.to_i }.join(',')
       else
         limitcondition = limit.to_i
       end
       sql << " LIMIT #{limitcondition}"
     end
     return Tag.find_by_sql(sql)
    end
     
    def my_top_tags_displaylist(options={})
      my_top_tags(options).map(&:name).join(Tag::JOINER)
    end
    
    
    private
    
    # Check if a model is in the :taggables target list. The alternative to this check is to explicitly include a TaggingMethods module (which you would create) in each target model.  
    def taggable?(should_raise = false) #:nodoc:
      unless flag = respond_to?(:tags)
        raise "#{self.class} is not a taggable model" if should_raise
      end
      flag
    end
    
    def tagcond(ownerid,kind)
      conditions = []
      if(ownerid != 0)
        conditions << "taggings.owner_id = #{ownerid}"
      end
           
      if(!kind.nil? and kind != Tagging::ALL)
        conditions << "taggings.tagging_kind = '#{kind}'"
      end
      return conditions.join(' AND ')
    end

  end
  
  module TaggingFinders
    
    def tagged_with_any(*tag_list)
      options = tag_list.last.is_a?(Hash) ? tag_list.pop : {}
      tag_list = parse_tags(tag_list)
      
      if(options[:getfrequency])
        options[:select] ||= "#{table_name}.*, tags.id as tag_id, COUNT(taggings.tag_id) as frequency, SUM(taggings.weight) as weightedfrequency"
      else
        options[:select] ||= "#{table_name}.*"
      end
      options[:from] ||= "#{table_name}, tags, taggings"
      
      sql  = "SELECT #{options[:select]} "
      sql << "FROM #{options[:from]} "

      #add_joins!(sql, options, nil)
      
      sql << "WHERE #{table_name}.#{primary_key} = taggings.taggable_id "
      sql << "AND taggings.taggable_type = '#{ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s}' "
      sql << "AND taggings.tag_id = tags.id "
      
      tag_list_condition = tag_list.map {|t| "'#{t}'"}.join(", ")
      sql << "AND (tags.name IN (#{sanitize_sql(tag_list_condition)})) "
      sql << "AND #{sanitize_sql(options[:conditions])} " if options[:conditions]
      if(options[:getfrequency])
        sql << "GROUP BY #{table_name}.id,tag_id "
        if(!options[:minweight].nil?)
          sql << "HAVING SUM(taggings.weight) >= #{options[:minweight]} "
        elsif(!options[:mincount].nil?)
          sql << "HAVING COUNT(taggings.tag_id) >= #{options[:mincount]} "
        end
      else
        sql << "GROUP BY #{table_name}.id "
        matchall = options[:matchall] || false
        if(matchall)
          sql << "HAVING COUNT(taggings.tag_id) = #{tag_list.size} "
        end
      end
      add_order!(sql, options[:order], nil)
      add_limit!(sql, options, nil)
      add_lock!(sql, options, nil)
      
      paginate = options[:paginate] || false
      if(paginate and !options[:getfrequency])  
        paginate_by_sql(sql,{:page => options[:page], :per_page => self.per_page})
      else
        find_by_sql(sql)
      end
    end
    
    
    
    def tag_frequency(options={})
      options[:from] ||= "#{table_name}, tags, taggings"
      
      sql  = "SELECT tags.*, COUNT(taggings.tag_id) as frequency, SUM(taggings.weight) as weightedfrequency "
      sql << "FROM #{options[:from]} "

      #add_joins!(sql, options)
      
      sql << "WHERE #{table_name}.#{primary_key} = taggings.taggable_id "
      sql << "AND taggings.taggable_type = '#{ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s}' "
      sql << "AND taggings.tag_id = tags.id "            
      sql << "AND #{sanitize_sql(options[:conditions])} " if options[:conditions]
      sql << "GROUP BY tags.id "
      if(!options[:minweight].nil?)
        sql << "HAVING SUM(taggings.weight) >= #{options[:minweight]}"
      elsif(!options[:mincount].nil?)
        sql << "HAVING COUNT(taggings.tag_id) >= #{options[:mincount]}"
      end
            
      add_order!(sql, options[:order], nil)
      add_limit!(sql, options, nil)
      add_lock!(sql, options, nil)
      return Tag.find_by_sql(sql)
    end
    
    
    def parse_tags(tags)
      return [] if tags.blank?
      tags = Array(tags).first
      tags = tags.respond_to?(:flatten) ? tags.flatten : tags.split(Tag::SPLITTER)
      tags.map { |tag| Tag.normalizename(tag) }.flatten.compact.uniq
    end
    
  end


