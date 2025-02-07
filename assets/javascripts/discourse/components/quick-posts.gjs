import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import htmlSafe from "discourse/helpers/html-safe";
import not from "discourse/helpers/not";
import { cook } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

export default class QuickPosts extends Component {
  @service store;
  @service currentUser;
  @service siteSettings;
  @service dialog;

  @tracked isLoading = false;
  @tracked posts = [];
  @tracked replyContent = "";
  @tracked showAllPosts = false;
  @tracked hasMorePosts = false;
  @tracked showError = false;
  @tracked showReplyForm = false;

  constructor() {
    super(...arguments);
    if (this.siteSettings.enable_quick_posts) {
      this.loadInitialPosts();
    }
  }

  get minimumPostLength() {
    return this.siteSettings.min_post_length;
  }

  get currentCharCount() {
    return (this.replyContent || "").trim().length;
  }

  get isValidLength() {
    return this.currentCharCount >= this.minimumPostLength;
  }

  get charCounterClass() {
    return this.isValidLength ? "valid" : "invalid";
  }

  @action
  updateReplyContent(event) {
    this.replyContent = event.target.value;
    this.showError = false;
  }

  @action
  async loadInitialPosts() {
    this.isLoading = true;
    try {
      const result = await this.store.findAll("quick-post", {
        topic_id: this.args.topic.id
      });
      this.posts = result;
      this.hasMorePosts = result.length >= 4;
    } catch (error) {
      console.error("Error loading quick posts:", error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async loadAllPosts() {
    this.isLoading = true;
    try {
      const result = await this.store.findAll("quick-post", {
        topic_id: this.args.topic.id,
        all_posts: true
      });
      this.posts = result;
      this.showAllPosts = true;
      this.hasMorePosts = false;
    } catch (error) {
      console.error("Error loading all posts:", error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async submitReply() {
    if (!this.replyContent.trim()) {
      return;
    }

    if (!this.isValidLength) {
      this.showError = true;
      return;
    }

    try {
      const post = await this.store.createRecord("quick-post", {
        topic_id: this.args.topic.id,
        raw: this.replyContent
      }).save();

      if (post) {
        const newPost = {
          ...post,
          created_at: post.created_at || new Date(),
          cooked: post.cooked || await cook(this.replyContent),
          user: post.user || this.currentUser
        };

        this.posts.pushObject(newPost);
        this.replyContent = "";
        this.showError = false;
      }
    } catch (error) {
      this.dialog.alert({
        message: i18n("quick_posts.error_creating"),
      });
      console.error("Error creating quick post:", error);
    }
  }

  @action
  toggleReplyForm() {
    this.showReplyForm = !this.showReplyForm;
  }

  <template>
    {{#if this.siteSettings.enable_quick_posts}}
      <div class="quick-posts">
        {{#if this.isLoading}}
          <div class="loading-spinner">
            {{i18n "quick_posts.loading"}}
          </div>
        {{else}}
          <div class="quick-posts-list">
            {{#each this.posts as |post|}}
              <div class="quick-post-item">
                <div class="quick-post-avatar">
                  {{avatar post.user imageSize="small"}}
                </div>
                <div class="quick-post-content">
                  <div class="quick-post-meta">
                    <span class="username">{{post.user.username}}</span>
                    <span class="date">{{formatDate post.created_at}}</span>
                  </div>
                  <div class="cooked">
                    {{htmlSafe post.cooked}}
                  </div>
                </div>
              </div>
            {{/each}}
          </div>

          {{#if this.currentUser}}
            {{#if this.hasMorePosts}}
              <button
                class="btn-flat load-more"
                {{on "click" this.loadAllPosts}}
              >
                {{i18n "quick_posts.load_more"}}
              </button>
            {{/if}}

            {{#if this.showReplyForm}}
              <div class="quick-reply">
                <div class="quick-reply-input">
                  <div class="quick-reply-avatar">
                    {{avatar this.currentUser imageSize="small"}}
                  </div>
                  <textarea
                    value={{this.replyContent}}
                    placeholder={{i18n "quick_posts.write_comment"}}
                    {{on "input" this.updateReplyContent}}
                    class={{if this.showError "error"}}
                  ></textarea>
                  <div class="quick-reply-footer">
                    <span class="char-counter {{this.charCounterClass}}">
                      {{this.currentCharCount}}/{{this.minimumPostLength}}
                    </span>
                    <DButton
                      @class="btn-primary"
                      @action={{this.submitReply}}
                      @disabled={{not this.replyContent}}
                      @icon="paper-plane"
                      @title={{if this.showError (i18n "composer.min_length_error" count=this.minimumPostLength)}}
                    />
                  </div>
                </div>
                {{#if this.showError}}
                  <div class="quick-reply-error">
                    {{i18n "composer.min_length_error" count=this.minimumPostLength}}
                  </div>
                {{/if}}
              </div>
            {{else}}
              <div class="quick-reply-actions">
                <DButton
                  @class="btn-flat create-quick-post"
                  @action={{this.toggleReplyForm}}
                  @icon="comment"
                  @label="quick_posts.create_comment"
                />
              </div>
            {{/if}}
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
} 