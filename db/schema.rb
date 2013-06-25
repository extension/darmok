# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130625175604) do

  create_table "admin_events", :force => true do |t|
    t.integer  "user_id",                  :default => 0, :null => false
    t.integer  "event",                    :default => 0, :null => false
    t.string   "ip",         :limit => 20
    t.text     "data"
    t.datetime "created_at"
  end

  create_table "admin_logs", :force => true do |t|
    t.integer  "person_id",                :default => 0, :null => false
    t.integer  "event",                    :default => 0, :null => false
    t.string   "ip",         :limit => 20
    t.text     "data"
    t.datetime "created_at"
  end

  create_table "annotation_events", :force => true do |t|
    t.integer  "person_id"
    t.string   "annotation_id"
    t.string   "action"
    t.string   "ip"
    t.datetime "created_at"
    t.text     "additionaldata"
  end

  create_table "annotations", :force => true do |t|
    t.string   "href"
    t.string   "url"
    t.datetime "added_at"
    t.datetime "created_at"
  end

  add_index "annotations", ["url"], :name => "index_annotations_on_url"

  create_table "branding_institutions", :force => true do |t|
    t.string   "name",                                          :null => false
    t.integer  "location_id",                    :default => 0
    t.string   "public_uri"
    t.string   "referer_domain"
    t.string   "institution_code", :limit => 10
    t.integer  "logo_id",                        :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "branding_institutions", ["location_id"], :name => "location_ndx"
  add_index "branding_institutions", ["name"], :name => "name_ndx", :unique => true
  add_index "branding_institutions", ["referer_domain"], :name => "referer_ndx"

  create_table "bronto_deliveries", :force => true do |t|
    t.string   "bronto_message_id", :limit => 40, :default => "", :null => false
    t.string   "status",                                          :null => false
    t.datetime "start",                                           :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "bronto_messages", :force => true do |t|
    t.string   "message_name"
    t.boolean  "is_jitp"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "bronto_recipients", :force => true do |t|
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "bronto_sends", :force => true do |t|
    t.string   "bronto_delivery_id",  :limit => 40, :default => "", :null => false
    t.string   "bronto_message_id",   :limit => 40, :default => "", :null => false
    t.string   "bronto_recipient_id", :limit => 40, :default => "", :null => false
    t.datetime "sent",                                              :null => false
    t.string   "url"
    t.datetime "clicked"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "bronto_sends", ["bronto_delivery_id", "bronto_message_id", "bronto_recipient_id"], :name => "send_ndx", :unique => true

  create_table "bucketings", :force => true do |t|
    t.integer  "page_id",           :null => false
    t.integer  "content_bucket_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "bucketings", ["page_id", "content_bucket_id"], :name => "bucketingindex", :unique => true

  create_table "cached_tags", :force => true do |t|
    t.integer  "tagcacheable_id"
    t.string   "tagcacheable_type"
    t.integer  "owner_id"
    t.integer  "tagging_kind"
    t.integer  "cache_kind"
    t.text     "fulltextlist"
    t.text     "cachedata"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "cached_tags", ["tagcacheable_id", "tagcacheable_type", "owner_id", "tagging_kind"], :name => "signature"

  create_table "category_tag_redirects", :force => true do |t|
    t.string "term"
    t.string "target_url"
  end

  add_index "category_tag_redirects", ["term"], :name => "name_ndx", :unique => true

  create_table "content_buckets", :force => true do |t|
    t.string   "name",       :null => false
    t.datetime "created_at", :null => false
  end

  add_index "content_buckets", ["name"], :name => "index_content_buckets_on_name", :unique => true

  create_table "counties", :force => true do |t|
    t.integer "fipsid",                    :default => 0,  :null => false
    t.integer "location_id",               :default => 0,  :null => false
    t.integer "state_fipsid",              :default => 0,  :null => false
    t.string  "countycode",   :limit => 3, :default => "", :null => false
    t.string  "name",                      :default => "", :null => false
    t.string  "censusclass",  :limit => 2, :default => "", :null => false
  end

  add_index "counties", ["fipsid"], :name => "fipsid", :unique => true
  add_index "counties", ["location_id"], :name => "fk_loc_id"
  add_index "counties", ["name"], :name => "name"
  add_index "counties", ["state_fipsid"], :name => "state_fipsid"

  create_table "db_files", :force => true do |t|
    t.binary "data", :limit => 2147483647
  end

  create_table "feed_locations", :force => true do |t|
    t.text     "uri",                                   :null => false
    t.boolean  "active",             :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.boolean  "retrieve_with_time", :default => false
  end

  create_table "file_attachments", :force => true do |t|
    t.string   "attachment_file_name"
    t.string   "attachment_content_type"
    t.integer  "attachment_file_size"
    t.datetime "attachment_updated_at"
    t.integer  "submitted_question_id"
    t.integer  "response_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "geo_names", :force => true do |t|
    t.string  "feature_name",       :limit => 121
    t.string  "feature_class",      :limit => 51
    t.string  "state_abbreviation", :limit => 3
    t.string  "state_code",         :limit => 3
    t.string  "county",             :limit => 101
    t.string  "county_code",        :limit => 4
    t.string  "lat_dms",            :limit => 8
    t.string  "long_dms",           :limit => 9
    t.float   "lat"
    t.float   "long"
    t.string  "source_lat_dms",     :limit => 8
    t.string  "source_long_dms",    :limit => 9
    t.float   "source_lat"
    t.float   "source_long"
    t.integer "elevation"
    t.string  "map_name"
    t.string  "create_date_txt"
    t.string  "edit_date_txt"
    t.date    "create_date"
    t.date    "edit_date"
  end

  add_index "geo_names", ["feature_name", "state_abbreviation", "county"], :name => "name_state_county_ndx"

  create_table "link_stats", :force => true do |t|
    t.integer  "page_id"
    t.integer  "total"
    t.integer  "external"
    t.integer  "internal"
    t.integer  "wanted"
    t.integer  "local"
    t.integer  "broken"
    t.integer  "warning"
    t.integer  "redirected"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "link_stats", ["page_id"], :name => "index_content_link_stats_on_content_id"

  create_table "linkings", :force => true do |t|
    t.integer  "link_id"
    t.integer  "page_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "linkings", ["link_id", "page_id"], :name => "recordsignature", :unique => true

  create_table "links", :force => true do |t|
    t.integer  "linktype"
    t.integer  "page_id"
    t.string   "host"
    t.string   "source_host"
    t.string   "path"
    t.string   "fingerprint"
    t.text     "url"
    t.string   "alias_fingerprint"
    t.text     "alias_url"
    t.string   "alternate_fingerprint"
    t.text     "alternate_url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status"
    t.integer  "error_count",            :default => 0
    t.datetime "last_check_at"
    t.integer  "last_check_status"
    t.boolean  "last_check_response"
    t.string   "last_check_code"
    t.text     "last_check_information"
  end

  add_index "links", ["alias_fingerprint"], :name => "alias_fingerprint_ndx"
  add_index "links", ["alternate_fingerprint"], :name => "alternate_fingerprint_ndx"
  add_index "links", ["fingerprint"], :name => "index_content_links_on_original_fingerprint", :unique => true
  add_index "links", ["page_id", "status", "linktype"], :name => "coreindex"

  create_table "locations", :force => true do |t|
    t.integer "fipsid",                     :default => 0,  :null => false
    t.integer "entrytype",                  :default => 0,  :null => false
    t.string  "name",                       :default => "", :null => false
    t.string  "abbreviation", :limit => 10, :default => "", :null => false
    t.string  "office_link"
  end

  add_index "locations", ["fipsid"], :name => "fipsid", :unique => true
  add_index "locations", ["name"], :name => "name", :unique => true

  create_table "logos", :force => true do |t|
    t.string   "filename"
    t.string   "content_type"
    t.integer  "size"
    t.integer  "width"
    t.integer  "height"
    t.integer  "parent_id"
    t.string   "thumbnail"
    t.datetime "created_at"
    t.integer  "db_file_id"
    t.integer  "logotype",     :default => 0
  end

  create_table "migrated_urls", :force => true do |t|
    t.string "alias_url"
    t.string "alias_url_fingerprint"
    t.string "target_url"
    t.string "target_url_fingerprint"
  end

  create_table "page_sources", :force => true do |t|
    t.string   "name"
    t.string   "uri",                                          :null => false
    t.string   "page_uri"
    t.string   "page_uri_column"
    t.string   "demo_uri"
    t.string   "demo_page_uri"
    t.boolean  "active",                     :default => true
    t.boolean  "retrieve_with_time",         :default => true
    t.string   "default_datatype"
    t.text     "default_request_options"
    t.datetime "latest_source_time"
    t.datetime "last_requested_at"
    t.boolean  "last_requested_success"
    t.text     "last_requested_information"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "page_updates", :force => true do |t|
    t.integer  "user_id"
    t.integer  "page_id"
    t.datetime "created_at",                                         :null => false
    t.string   "action",                                             :null => false
    t.string   "remote_addr", :limit => 20, :default => "127.0.0.1"
  end

  add_index "page_updates", ["page_id"], :name => "index_page_updates_on_page_id"
  add_index "page_updates", ["user_id"], :name => "index_page_updates_on_user_id"

  create_table "pages", :force => true do |t|
    t.string   "datatype"
    t.integer  "indexed",                                      :default => 1
    t.text     "title"
    t.string   "url_title",              :limit => 101
    t.text     "content",                :limit => 2147483647
    t.integer  "content_length"
    t.integer  "content_words"
    t.text     "original_content",       :limit => 2147483647
    t.datetime "source_created_at"
    t.datetime "source_updated_at"
    t.string   "source"
    t.text     "source_url"
    t.string   "source_url_fingerprint"
    t.boolean  "is_dpl",                                       :default => false
    t.text     "reference_pages"
    t.integer  "migrated_id"
    t.boolean  "has_broken_links",                             :default => false
    t.text     "coverage"
    t.text     "state_abbreviations"
    t.datetime "event_start"
    t.string   "time_zone"
    t.text     "event_location"
    t.integer  "event_duration"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "page_source_id"
    t.text     "cached_content_tags"
    t.text     "old_source_url"
    t.boolean  "event_all_day"
    t.text     "alternate_source_url"
    t.integer  "learn_id"
    t.boolean  "is_special_page",                              :default => false
  end

  add_index "pages", ["datatype"], :name => "index_pages_on_datatype"
  add_index "pages", ["event_start"], :name => "index_pages_on_event_start"
  add_index "pages", ["learn_id"], :name => "index_pages_on_learn_id"
  add_index "pages", ["migrated_id"], :name => "index_pages_on_migrated_id"
  add_index "pages", ["source_created_at", "source_updated_at"], :name => "index_pages_on_source_created_at_and_source_updated_at"
  add_index "pages", ["source_url_fingerprint"], :name => "index_pages_on_source_url_fingerprint", :unique => true
  add_index "pages", ["title", "content"], :name => "title_content_full_index"
  add_index "pages", ["title"], :name => "index_pages_on_title", :length => {"title"=>"255"}

  create_table "people", :force => true do |t|
    t.string   "uid"
    t.string   "first_name"
    t.string   "last_name"
    t.boolean  "is_admin",       :default => false
    t.boolean  "retired"
    t.datetime "last_active_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "publishing_communities", :force => true do |t|
    t.string   "name",                                       :null => false
    t.string   "public_name"
    t.text     "public_description"
    t.boolean  "is_launched",             :default => false
    t.integer  "public_topic_id"
    t.text     "cached_content_tag_data"
    t.integer  "logo_id",                 :default => 0
    t.string   "homage_name"
    t.integer  "homage_id"
    t.integer  "aae_group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "drupal_node_id"
  end

  create_table "special_pages", :force => true do |t|
    t.string  "path"
    t.string  "titletag"
    t.string  "main_heading"
    t.string  "sub_heading"
    t.integer "page_id"
  end

  add_index "special_pages", ["page_id"], :name => "page_ndx", :unique => true
  add_index "special_pages", ["path"], :name => "path_ndx", :unique => true

  create_table "sponsors", :force => true do |t|
    t.integer "logo_id"
    t.integer "position"
    t.string  "name"
    t.string  "level"
  end

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id",                                         :null => false
    t.integer  "taggable_id",                                    :null => false
    t.string   "taggable_type",     :limit => 32
    t.string   "tag_display",                                    :null => false
    t.integer  "owner_id",                                       :null => false
    t.integer  "weight",                          :default => 1, :null => false
    t.datetime "created_at",                                     :null => false
    t.datetime "updated_at"
    t.integer  "tagging_kind"
    t.string   "old_taggable_type"
    t.integer  "old_taggable_id"
  end

  add_index "taggings", ["tag_id", "taggable_id", "taggable_type", "tagging_kind", "owner_id"], :name => "taggingindex", :unique => true
  add_index "taggings", ["taggable_id", "taggable_type", "tagging_kind"], :name => "index_taggings_on_taggable_id_and_taggable_type_and_tagging_kind"

  create_table "tags", :force => true do |t|
    t.string   "name",       :null => false
    t.datetime "created_at", :null => false
  end

  add_index "tags", ["name"], :name => "index_tags_on_name", :unique => true

  create_table "topics", :force => true do |t|
    t.string "name"
  end

  create_table "update_times", :force => true do |t|
    t.integer  "datasource_id"
    t.string   "datasource_type",     :limit => 25
    t.string   "datatype",            :limit => 25
    t.datetime "last_datasourced_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "additionaldata"
  end

  add_index "update_times", ["datasource_type", "datasource_id", "datatype"], :name => "recordsignature", :unique => true

  create_table "zip_codes", :force => true do |t|
    t.integer "zip_code"
    t.string  "city"
    t.string  "state"
    t.string  "county"
    t.integer "area_code"
    t.string  "city_type"
    t.string  "city_alias_abbreviation"
    t.string  "city_alias_name"
    t.float   "latitude"
    t.float   "longitude"
    t.integer "time_zone"
    t.integer "elevation"
    t.integer "county_fips"
    t.string  "day_light_savings"
  end

  add_index "zip_codes", ["state"], :name => "fk_statezip"
  add_index "zip_codes", ["zip_code"], :name => "zipcode"

end
