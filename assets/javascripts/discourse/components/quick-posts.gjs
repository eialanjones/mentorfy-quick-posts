import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import htmlSafe from "discourse/helpers/html-safe";
import not from "discourse/helpers/not";
import { i18n } from "discourse-i18n";

export default class QuickPosts extends Component {
  @service store;
  @service currentUser;
  @service siteSettings;
  @service dialog;

  @tracked isLoading = false;
  @tracked allPosts = [];
  @tracked replyContent = "";
  @tracked showError = false;
  @tracked showReplyForm = false;
  @tracked replyingTo = null;
  @tracked displayLimit = 3;
  @tracked nestedPosts = [];

  constructor() {
    super(...arguments);
    if (this.siteSettings.enable_quick_posts) {
      this.loadAllPosts();
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

  get hasMorePosts() {
    return this.displayLimit < this.allPosts.length;
  }

  get visiblePosts() {
    return this.nestedPosts.slice(-this.displayLimit);
  }

  getDepthClass(depth) {
    return `quick-post-depth-${depth}`;
  }

  buildNestedPosts(posts) {
    const postMap = new Map();
    const rootPosts = [];

    // Primeiro, mapeia todos os posts por ID e inicializa o array de replies
    posts.forEach((post) => {
      post.replies = [];
      post.depth = 0;
      postMap.set(post.post_number, post);
    });

    // Organiza os posts em uma estrutura de árvore com profundidade
    posts.forEach((post) => {
      if (post.reply_to_post_number && postMap.has(post.reply_to_post_number)) {
        const parent = postMap.get(post.reply_to_post_number);
        post.depth = parent.depth + 1;
        parent.replies.push(post);
      } else {
        rootPosts.push(post);
      }
    });

    return rootPosts;
  }

  @action
  updateReplyContent(event) {
    this.replyContent = event.target.value;
    this.showError = false;
  }

  @action
  async loadAllPosts() {
    this.isLoading = true;
    try {
      const response = await this.store.findAll("quick-post", {
        topic_id: this.args.topic.id,
        reload: true,
      });

      this.allPosts = (response.content || []).sort((a, b) => {
        return new Date(a.created_at) - new Date(b.created_at);
      });

      this.nestedPosts = this.buildNestedPosts(this.allPosts);
    } catch (error) {
      // this.dialog.alert({
      //   message: i18n("quick_posts.error_loading"),
      // });
      console.error("error", error);
      this.allPosts = [];
      this.nestedPosts = [];
    } finally {
      this.isLoading = false;
    }
  }

  @action
  loadMorePosts() {
    this.displayLimit += 3;
  }

  @action
  replyToPost(post) {
    if (!post || !post.post_number) {
      this.dialog.alert({
        message: i18n("quick_posts.error_invalid_post"),
      });
      return;
    }

    this.replyingTo = post;
    this.showReplyForm = true;
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
      const postData = {
        topic_id: this.args.topic.id,
        raw: this.replyContent,
        reply_to_post_number: this.replyingTo?.post_number,
      };

      const post = await this.store.createRecord("quick-post", postData).save();

      if (post) {
        this.replyContent = "";
        this.showError = false;
        this.replyingTo = null;
        this.showReplyForm = false;

        await this.loadAllPosts();

        if (!this.visiblePosts.some((p) => p.id === post.id)) {
          this.displayLimit += 1;
        }
      }
    } catch (error) {
      this.dialog.alert({
        message: i18n("quick_posts.error_creating"),
      });
    }
  }

  @action
  cancelReply() {
    this.replyingTo = null;
    this.replyContent = "";
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
          {{#if this.hasMorePosts}}
            <button
              class="btn-flat load-more"
              {{on "click" this.loadMorePosts}}
            >
              {{i18n "quick_posts.load_more"}}
            </button>
          {{/if}}

          <div class="quick-posts-list">
            {{#each this.visiblePosts as |post|}}
              <div
                class="quick-post-item
                  {{this.getDepthClass post.depth}}
                  {{if post.reply_to_post_number 'nested-reply'}}"
              >
                <div class="quick-post-avatar">
                  {{avatar post.user imageSize="small"}}
                </div>
                <div class="quick-post-content">
                  <div class="quick-post-meta">
                    <span class="username">{{post.user.username}}</span>
                    <span class="date">{{formatDate post.created_at}}</span>
                    <DButton
                      @class="btn-flat reply-to-post"
                      @action={{fn this.replyToPost post}}
                      @icon="reply"
                      @title={{i18n "quick_posts.reply_to"}}
                    />
                  </div>
                  <div class="cooked">
                    {{htmlSafe post.cooked}}
                  </div>

                  {{#if post.replies.length}}
                    <div class="nested-replies">
                      {{#each post.replies as |reply|}}
                        <div
                          class="quick-post-item nested-reply
                            {{this.getDepthClass reply.depth}}"
                        >
                          <div class="quick-post-avatar">
                            {{avatar reply.user imageSize="small"}}
                          </div>
                          <div class="quick-post-content">
                            <div class="quick-post-meta">
                              <span
                                class="username"
                              >{{reply.user.username}}</span>
                              <span class="date">{{formatDate
                                  reply.created_at
                                }}</span>
                              <DButton
                                @class="btn-flat reply-to-post"
                                @action={{fn this.replyToPost reply}}
                                @icon="reply"
                                @title={{i18n "quick_posts.reply_to"}}
                              />
                            </div>
                            <div class="cooked">
                              {{htmlSafe reply.cooked}}
                            </div>
                            {{#if reply.replies.length}}
                              <div class="nested-replies">
                                {{#each reply.replies as |nestedReply|}}
                                  <div
                                    class="quick-post-item nested-reply
                                      {{this.getDepthClass nestedReply.depth}}"
                                  >
                                    <div class="quick-post-avatar">
                                      {{avatar
                                        nestedReply.user
                                        imageSize="small"
                                      }}
                                    </div>
                                    <div class="quick-post-content">
                                      <div class="quick-post-meta">
                                        <span
                                          class="username"
                                        >{{nestedReply.user.username}}</span>
                                        <span class="date">{{formatDate
                                            nestedReply.created_at
                                          }}</span>
                                        <DButton
                                          @class="btn-flat reply-to-post"
                                          @action={{fn
                                            this.replyToPost
                                            nestedReply
                                          }}
                                          @icon="reply"
                                          @title={{i18n "quick_posts.reply_to"}}
                                        />
                                      </div>
                                      <div class="cooked">
                                        {{htmlSafe nestedReply.cooked}}
                                      </div>
                                    </div>
                                  </div>
                                {{/each}}
                              </div>
                            {{/if}}
                          </div>
                        </div>
                      {{/each}}
                    </div>
                  {{/if}}
                </div>
              </div>
            {{/each}}
          </div>

          {{#if this.currentUser}}
            {{#if this.showReplyForm}}
              <div class="quick-reply">
                {{#if this.replyingTo}}
                  <div class="replying-to">
                    {{i18n
                      "quick_posts.replying_to"
                      username=this.replyingTo.user.username
                    }}
                    <DButton
                      @class="btn-flat cancel-reply"
                      @action={{this.cancelReply}}
                      @icon="times"
                      @title={{i18n "quick_posts.cancel_reply"}}
                    />
                  </div>
                {{/if}}
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
                      @title={{if
                        this.showError
                        (i18n
                          "composer.min_length_error"
                          count=this.minimumPostLength
                        )
                      }}
                    />
                  </div>
                </div>
                {{#if this.showError}}
                  <div class="quick-reply-error">
                    {{i18n
                      "composer.min_length_error"
                      count=this.minimumPostLength
                    }}
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
