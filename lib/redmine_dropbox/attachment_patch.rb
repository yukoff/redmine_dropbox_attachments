module RedmineDropbox
  module AttachmentPatch
    
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable
        after_validation :save_to_dropbox
        before_destroy   :delete_from_dropbox
      end
    end

    module ClassMethods
      def dropbox_plugin_settings(key = nil)
        settings = Setting.find_by_name("plugin_redmine_dropbox_attachments")

        raise l(:dropbox_plugin_not_configured) if settings.nil?

        # return the full settings hash if no key is provided
        return settings.value if key.nil?

        settings.value[key]
      end

      def dropbox_client
        k = Attachment.dropbox_plugin_settings

        raise l(:dropbox_not_authorized) unless k["DROPBOX_TOKEN"] && k["DROPBOX_SECRET"]
        
        Dropbox::API::Client.new :token => k["DROPBOX_TOKEN"], :secret => k["DROPBOX_SECRET"]
      end      
    end

    module InstanceMethods
      # path on dropbox to the file, defaulting the instance's disk_filename
      def dropbox_path(filename = disk_filename)
        "#{Attachment.dropbox_plugin_settings['DROPBOX_BASE_DIR']}/#{filename}"
      end

      def save_to_dropbox
        if @temp_file && (@temp_file.size > 0)
          logger.debug "[redmine_dropbox_attachments] Uploading #{disk_filename}"
          
          Attachment.dropbox_client.upload dropbox_path, @temp_file.read
          
          md5 = Digest::MD5.new
          self.digest = md5.hexdigest
        end

        # set the temp file to nil so the model's original after_save block 
        # skips writing to the filesystem
        @temp_file = nil
      end

      def delete_from_dropbox
        logger.debug "[redmine_dropbox_attachments] Deleting #{disk_filename}"
        
        f = Attachment.dropbox_client.find(dropbox_path(disk_filename))
        f.destroy
      end
    end
  end
end