# frozen_string_literal: true

# name: mentorfy-quick-posts
# about: adiciona funcionalidade de posts rápidos(comentários) aos tópicos
# version: 0.4.1
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
               :topic_id,
               :reply_to_post_number,
               :version,
               :wiki,
               :reads,
               :score,
               :hidden,
               :hidden_reason_id,
               :like_count,
               :quote_count,
               :reply_count,
               :bookmark_count,
               :incoming_link_count,
               :word_count,
               :cook_method,
               :via_email,
               :like_score,
               :post_type,
               :sort_order,
               :percent_rank,
               :action_code,
               :last_editor_id,
               :edit_reason,
               :last_version_at,
               :self_edits

    has_one :user, serializer: BasicUserSerializer, embed: :objects do
      attributes :primary_group_name,
                 :flair_name,
                 :flair_url,
                 :flair_bg_color,
                 :flair_color,
                 :trust_level,
                 :moderator,
                 :admin,
                 :staff
    end

    has_one :last_editor, serializer: BasicUserSerializer, embed: :objects

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
      unless SiteSetting.enable_quick_posts
        return render json: { error: I18n.t("quick_posts.disabled") }
      end

      topic_id = params[:topic_id]
      topic = Topic.find_by(id: topic_id)
      return render_json_error(I18n.t("quick_posts.topic_not_found")) unless topic

      guardian.ensure_can_see!(topic)

      page = (params[:page] || 1).to_i
      per_page = 100

      posts =
        Post
          .where(topic_id: topic.id)
          .where(deleted_at: nil)
          .where.not(post_number: 1)
          .where(post_type: Post.types[:regular])
          .order(created_at: :desc)
          .includes(:user)
          .offset((page - 1) * per_page)
          .limit(per_page)

      total_posts =
        Post
          .where(topic_id: topic.id)
          .where(deleted_at: nil)
          .where.not(post_number: 1)
          .where(post_type: Post.types[:regular])
          .count

      render_json_dump(
        quick_posts:
          posts.map { |post| QuickPostSerializer.new(post, scope: guardian, root: false) },
        total_posts: total_posts,
        current_page: page,
      )
    end

    def create
      unless SiteSetting.enable_quick_posts
        return render json: { error: I18n.t("quick_posts.disabled") }
      end

      topic_id = params[:topic_id] || params.dig(:quick_post, :topic_id)
      raw = params[:raw] || params.dig(:quick_post, :raw)
      reply_to_post_number =
        params[:reply_to_post_number] || params.dig(:quick_post, :reply_to_post_number)

      if topic_id.blank? || raw.blank?
        return render_json_error(I18n.t("quick_posts.missing_params"))
      end

      topic = Topic.find_by(id: topic_id)
      return render_json_error(I18n.t("quick_posts.topic_not_found")) unless topic

      guardian.ensure_can_create!(Post, topic)

      post_creator =
        PostCreator.new(
          current_user,
          topic_id: topic.id,
          raw: raw,
          reply_to_post_number: reply_to_post_number,
          skip_validations: false,
        )

      post = post_creator.create

      if post_creator.errors.present?
        render_json_error(post_creator)
      else
        render_json_dump(QuickPostSerializer.new(post, scope: guardian, root: "quick_post"))
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
    get "/t/:topic_id/quick_posts" => "quick_posts/quick_posts#index",
        :format => :json,
        :constraints => {
          format: :json,
        }
    post "/t/:topic_id/quick_posts" => "quick_posts/quick_posts#create", :format => :json

    get "/quick_posts" => "quick_posts/quick_posts#index",
        :format => :json,
        :constraints => {
          format: :json,
        }
    post "/quick_posts" => "quick_posts/quick_posts#create", :format => :json
  end
end
