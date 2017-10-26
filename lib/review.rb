class Review
  class Comment
    attr_accessor :path, :position, :body

    def initialize(attributes = nil)
      @path, @position, @body = attributes.values_at(:path, :position, :body)
    end

    def to_h
      {
        path: @path,
        position: @position,
        body: @body
      }
    end
  end

  EVENT_REQUEST_CHANGE = 'REQUEST_CHANGES'.freeze
  EVENT_COMMENT = 'COMMENT'.freeze
  EVENT_APPROVE = 'APPROVE'.freeze
  EVENT_PENDING = ''.freeze

  attr_accessor :id, :body, :event, :comments

  def initialize(attributes={})
    @id, @body, @event, @comments = attributes.values_at(:id, :body, :event, :comments)
    @body ||= ''
    @event ||= EVENT_PENDING
    @comments ||= []
  end
end
