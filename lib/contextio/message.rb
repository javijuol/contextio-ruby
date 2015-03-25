require 'contextio/api/resource'

class ContextIO
  class Message
    include ContextIO::API::Resource

    self.primary_key = :message_id
    self.association_name = :message

    belongs_to :account
    has_many :sources
    has_many :body_parts
    has_many :files

    lazy_attributes :date, :folders, :addresses, :subject, :list_help,
                    :list_unsubscribe, :message_id, :email_message_id,
                    :gmail_message_id, :gmail_thread_id, :person_info,
                    :date_received, :date_indexed, :in_reply_to, :references,
                    :flags, :body


    FLAG_KEYS = %w(seen answered flagged deleted draft $notjunk notjunk)

    private :date_received, :date_indexed

    def received_at
      @received_at ||= Time.at(date_received)
    end

    def indexed_at
      @indexed_at ||= Time.at(date_indexed)
    end

    def flags
      if @where.has_key?(:include_flags) && @where[:include_flags]==1
        attrs = self.api_attributes['flags'].map(&:downcase).map{|a| a.delete("\\")}
        @flags ||= Hash[FLAG_KEYS.map{|f| [f, attrs.include?(f)]}]
        self.api_attributes['flags'] = @flags
      else
        @flags ||= api.request(:get, "#{resource_url}/flags")
      end
    end

    def body_plain
      @body_plain ||= @where.has_key?(:include_body) && @where[:include_body]==1 ?
          self.api_attributes['body'].select{|b| b['type']=='text/plain'}.map{|b| b['content']}.join :
          self.body_parts.where(type:'text/plain').map(&:content).join
    end

    def body_html
      @body_html ||= @where.has_key?(:include_body) && @where[:include_body]==1 ?
          self.api_attributes['body'].select{|b| b['type']=='text/html'}.map{|b| b['content']}.join :
          self.body_parts.where(type:'text/html').map(&:content).join
    end

    # As of this writing, the documented valid flags are: seen, answered,
    # flagged, deleted, and draft. However, this will send whatever you send it.
    def set_flags(flag_hash)
      args = flag_hash.inject({}) do |memo, (flag_name, value)|
        memo[flag_name] = value ? 1 : 0
        memo
      end

      api.request(:post, "#{resource_url}/flags", args)['success']
    end

    def headers
      api.request(:get, "#{resource_url}/headers")
    end

    %w(from to bcc cc reply_to).each do |f|
      define_method(f) do
        addresses[f]
      end
    end

    def raw
      api.raw_request(:get, "#{resource_url}/source")
    end

    # You can call this with a Folder object, in which case, the source from the
    # folder will be used, or you can pass in a folder name and source label.
    def copy_to(folder, source = nil)
      if folder.is_a?(ContextIO::Folder)
        folder_name = folder.name
        source_label = folder.source.label
      else
        folder_name = folder.to_s
        source_label = source.to_s
      end
      params = {dst_folder: folder_name}
      params[:dst_source] = source_label unless source_label.empty?
      api.request(:post, resource_url, params)['success']
    end

    # You can call this with a Folder object, in which case, the source from the
    # folder will be used, or you can pass in a folder name and source label.
    def move_to(folder, source = nil)
      if folder.is_a?(ContextIO::Folder)
        folder_name = folder.name
        source_label = folder.source.label
      else
        folder_name = folder.to_s
        source_label = source.to_s
      end

      params = {dst_folder: folder_name, move: 1}
      params[:dst_source] = source_label unless source_label.empty?
      api.request(:post, resource_url, params)['success']
    end

    def delete
      api.request(:delete, resource_url)['success']
    end

    # Returns a list of all messages and a list of all email_message_ids in the same thread as this message.
    # Note that it does not create a Thread object or a MessageCollection object in its current state.
    def thread
      api.request(:get, "#{resource_url}/thread")
    end
  end
end
