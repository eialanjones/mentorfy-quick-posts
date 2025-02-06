# frozen_string_literal: true

# name: discourse-quick-posts
# about: Adds quick posts functionality to topics
# version: 0.1
# authors: Mentorfy
# url: https://github.com/eialanjones/discourse-quick-posts

enabled_site_setting :enable_quick_posts

after_initialize do
  module ::QuickPosts
    class Engine < ::Rails::Engine
      engine_name "quick_posts"
      isolate_namespace QuickPosts
    end
    PLUGIN_NAME = "discourse-quick-posts"
  end

  require_dependency "application_controller"
  require_dependency "application_serializer"
  
  class ::QuickPostSerializer < ::ApplicationSerializer
    attributes :id,
               :post_number,
               :created_at,
               :cooked,
               :raw,
               :topic_id

    has_one :user, serializer: BasicUserSerializer, embed: :objects

    def cooked
      object.cooked.presence || PrettyText.cook(object.raw)
    end

    def include_raw?
      @options[:include_raw] || false
    end
  end
  
  class ::QuickPosts::QuickPostsController < ::ApplicationController
    requires_login
    
    def index
      return render json: { error: I18n.t("quick_posts.disabled") } unless SiteSetting.enable_quick_posts

      topic = Topic.find_by(id: params[:topic_id])
      guardian.ensure_can_see!(topic)
      
      posts = if params[:all_quick_posts] == "true"
        Post.all_quick_posts(topic.id)
      else
        Post.quick_posts(topic.id)
      end
      
      render_json_dump(
        posts: posts.map { |post| QuickPostSerializer.new(post, scope: guardian, root: false) }
      )
    end
    
    def create
      return render json: { error: I18n.t("quick_posts.disabled") } unless SiteSetting.enable_quick_posts

      topic = Topic.find_by(id: params[:topic_id])
      guardian.ensure_can_create!(Post, topic)
      
      post_creator = PostCreator.new(
        current_user,
        topic_id: topic.id,
        raw: params[:raw],
        skip_validations: false
      )
      
      post = post_creator.create
      
      if post_creator.errors.present?
        render_json_error(post_creator)
      else
        render_json_dump(QuickPostSerializer.new(post, scope: guardian, root: false))
      end
    end
  end

  class ::Post
    def self.quick_posts(topic_id)
      where(topic_id: topic_id)
        .where(deleted_at: nil)
        .where.not(post_number: 1)
        .where(post_type: Post.types[:regular])
        .order(created_at: :desc)
        .includes(:user)
        .limit(3)
    end

    def self.all_quick_posts(topic_id)
      where(topic_id: topic_id)
        .where(deleted_at: nil)
        .where.not(post_number: 1)
        .where(post_type: Post.types[:regular])
        .order(created_at: :desc)
        .includes(:user)
    end
  end

  Discourse::Application.routes.append do
    get "/t/:topic_id/quick_posts" => "quick_posts/quick_posts#index", :format => :json, :constraints => { format: :json }
    post "/t/:topic_id/quick_posts" => "quick_posts/quick_posts#create", :format => :json
  end
end 