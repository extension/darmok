class ConvertPubsiteArticleTags < ActiveRecord::Migration
  def self.up
    # rename external article column so that we don't get errors from pulling ExternalArticle - 20090801 - jayoung
    rename_column('articles', 'type', 'datatype')
    
    
    ownerid = User.systemuserid
    insert_time = Time.now.utc.to_s(:db)
    
    say_with_time "Converting Article Tags..." do
      
      # insert all the tags
      all_article_tags = []
      Article.all.each do |a|
        a.cached_tag_list.split(',').each do |tag|
          all_article_tags << Tag.normalizename(tag)
        end
        all_article_tags.uniq!        
      end
      values_string = all_article_tags.map{|t| "('#{t}','#{insert_time}')"}.join(',')
      tag_insert_sql = "INSERT IGNORE INTO tags (name,created_at) VALUES #{values_string}"
      say_with_time "Bulk inserting tags..." do
        suppress_messages {execute tag_insert_sql}
      end
      
      # go back and get the tag id's
      tag_name_to_id = {}
      Tag.all.map{|t| tag_name_to_id[t.name] = t.id }
      
      # go back again, walk the articles, insert taggings
      taggings_to_insert = []

      Article.all.each do |a|
        if(!a.cached_tag_list.blank?)
          a.cached_tag_list.split(',').each do |tag|
            if(tagid = tag_name_to_id[Tag.normalizename(tag)])
              taggings_to_insert << "(#{tagid},#{a.id},'#{a.class.name}','#{tag.gsub("'",'').strip}',#{ownerid},'#{insert_time}','#{insert_time}',#{Tag::CONTENT})"
            end
          end
        end
      end
      
      # go through taggings_to_insert, 500 at a time
      say_with_time "Bulk inserting taggings..." do
        while (tagging_chunk = taggings_to_insert.slice!(0,500) and !tagging_chunk.empty?)
          tagging_insert_sql = "INSERT IGNORE INTO taggings (tag_id,taggable_id,taggable_type,tag_display,owner_id,created_at,updated_at,tag_kind) VALUES #{tagging_chunk.join(',')}"
          suppress_messages {execute tagging_insert_sql}
        end
      end
    
    end
  end

  def self.down
  end
end
