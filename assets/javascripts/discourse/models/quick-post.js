import RestModel from "discourse/models/rest";
import { registerModelTransformer } from "discourse/lib/model-transformers";

export default class QuickPost extends RestModel {
  createProperties() {
    return {
      raw: this.raw,
      topic_id: this.topic_id
    };
  }
}

// Registrando o modelo e adaptador
export function registerQuickPostModel(api) {
  registerModelTransformer("quick-post", {
    model: QuickPost,
    adapter: {
      pathFor(store, type, findArgs) {
        const topicId = findArgs.topic_id;
        const allPosts = findArgs.all_posts ? "all_quick_posts=true" : "";
        return `/t/${topicId}/quick_posts${allPosts ? `?${allPosts}` : ""}`;
      },

      findAll(store, type, findArgs) {
        const path = this.pathFor(store, type, findArgs);
        
        return this.ajax(path).then((response) => {
          if (!response.quick_posts) {
            return [];
          }
          return response.quick_posts;
        });
      },

      createRecord(store, type, attrs) {
        return this.ajax(`/t/${attrs.topic_id}/quick_posts`, {
          type: "POST",
          data: attrs
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
      }
    }
  });
} 