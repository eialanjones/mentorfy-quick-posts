import { registerModelTransformer } from "discourse/lib/model-transformers";
import RestModel from "discourse/models/rest";

export default class QuickPost extends RestModel {
  createProperties() {
    return {
      raw: this.raw,
      topic_id: this.topic_id,
      reply_to_post_number: this.reply_to_post_number,
    };
  }
}

// Registrando o modelo e adaptador
export function registerQuickPostModel() {
  registerModelTransformer("quick-post", {
    model: QuickPost,
    adapter: {
      pathFor(store, type, findArgs) {
        const topicId = findArgs.topic_id;
        const page = findArgs.page ? `page=${findArgs.page}` : "";
        return `/t/${topicId}/quick_posts${page ? `?${page}` : ""}`;
      },

      findAll(store, type, findArgs) {
        const path = this.pathFor(store, type, findArgs);
        return this.ajax(path).then((result) => {
          return {
            content: result.quick_posts || [],
            meta: {
              total_posts: result.total_posts,
              current_page: result.current_page,
            },
          };
        });
      },

      createRecord(store, type, attrs) {
        return this.ajax(`/t/${attrs.topic_id}/quick_posts`, {
          type: "POST",
          data: attrs,
        }).then((json) => {
          if (!json) {
            return null;
          }

          // Garante que os dados do usuário estão presentes
          if (!json.user) {
            json.user = store.currentUser;
          }

          return json;
        });
      },
    },
  });
}
