require_relative 'api/resource_collection'
require_relative 'message'

class ContextIO
  class MessageFolderCollection
    include ContextIO::API::ResourceCollection

    self.resource_class = ContextIO::Message
    self.association_name = :folder_messages

    belongs_to :folder

  end
end
