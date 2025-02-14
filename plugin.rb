# frozen_string_literal: true

# name: mentorfy-quick-posts
# about: adiciona funcionalidade de posts rápidos(comentários) aos tópicos
# version: 0.3
# authors: Mentor
# url: https://github.com/eialanjones/discourse-quick-posts

enabled_site_setting :enable_quick_posts

register_asset "stylesheets/common/base/quick-posts.scss"
register_asset "javascripts/discourse/components/quick-posts.gjs"

# Registra as traduções
register_locale("pt_BR", name: "Português (Brasil)")

after_initialize do
  module ::QuickPosts
    class Engine < ::Rails::Engine
      engine_name "quick_posts"
      isolate_namespace QuickPosts
    end
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

      topic_id = params[:topic_id]
      topic = Topic.find_by(id: topic_id)
      return render_json_error(I18n.t("quick_posts.topic_not_found")) unless topic
      
      guardian.ensure_can_see!(topic)
      
      posts = if params[:all_quick_posts] == "true"
        Post.all_quick_posts(topic.id)
      else
        Post.quick_posts(topic.id)
      end
      
      render_json_dump(
        quick_posts: posts.map { |post| QuickPostSerializer.new(post, scope: guardian, root: false) }
      )
    end
    
    def create
      return render json: { error: I18n.t("quick_posts.disabled") } unless SiteSetting.enable_quick_posts

      # Pega o topic_id da URL ou dos parâmetros
      topic_id = params[:topic_id] || params.dig(:quick_post, :topic_id)
      raw = params[:raw] || params.dig(:quick_post, :raw)

      return render_json_error(I18n.t("quick_posts.missing_params")) if topic_id.blank? || raw.blank?

      topic = Topic.find_by(id: topic_id)
      return render_json_error(I18n.t("quick_posts.topic_not_found")) unless topic
      
      guardian.ensure_can_create!(Post, topic)
      
      post_creator = PostCreator.new(
        current_user,
        topic_id: topic.id,
        raw: raw,
        skip_validations: false
      )
      
      post = post_creator.create
      
      if post_creator.errors.present?
        render_json_error(post_creator)
      else
        render_json_dump(QuickPostSerializer.new(post, scope: guardian, root: 'quick_post'))
      end
    end
  end

  add_class_method(:post, :quick_posts) do |topic_id|
    where(topic_id: topic_id)
      .where(deleted_at: nil)
      .where.not(post_number: 1)
      .where(post_type: Post.types[:regular])
      .order(created_at: :asc)
      .includes(:user)
      .limit(3)
  end

  add_class_method(:post, :all_quick_posts) do |topic_id|
    where(topic_id: topic_id)
      .where(deleted_at: nil)
      .where.not(post_number: 1)
      .where(post_type: Post.types[:regular])
      .order(created_at: :asc)
      .includes(:user)
  end

  Discourse::Application.routes.append do
    get "/t/:topic_id/quick_posts" => "quick_posts/quick_posts#index", :format => :json, :constraints => { format: :json }
    post "/t/:topic_id/quick_posts" => "quick_posts/quick_posts#create", :format => :json

    get "/quick_posts" => "quick_posts/quick_posts#index", :format => :json, :constraints => { format: :json }
    post "/quick_posts" => "quick_posts/quick_posts#create", :format => :json
  end
end 