import RestModel from "discourse/models/rest";
import { registerModelTransformer } from "discourse/lib/model-transformers";

export default class QuickPost extends RestModel {}

// Registrando o modelo e adaptador
export function registerQuickPostModel(api) {
  registerModelTransformer("quick-post", {
    model: QuickPost,
    adapter: {
      pathFor(store, type, findArgs) {
        const topicId = findArgs.topic_id;
        const allPosts = findArgs.all_posts ? "all_quick_posts=true" : "quick_posts=true";
        return `/t/${topicId}/quick_posts?${allPosts}`;
      },

      findAll(store, type, findArgs) {
        const path = this.pathFor(store, type, findArgs);
        
        return this.ajax(path).then((response) => {
          // Normaliza a resposta para garantir que temos posts
          if (response.latest_posts && !response.posts) {
            response.posts = response.latest_posts;
            delete response.latest_posts;
          }
          return response;
        });
      },

      createRecord(store, type, attrs) {
        return this.ajax(`/t/${attrs.topic_id}/quick_posts`, {
          type: "POST",
          data: {
            raw: attrs.raw
          }
        }).then((json) => {
          // Garante que temos todos os dados necessários
          if (json[type]) {
            const post = json[type];
            
            // Garante que os dados do usuário estão presentes
            if (!post.user) {
              post.user = store.currentUser;
            }
            
            // Retorna os dados completos do post
            return post;
          }
          
          return json;
        });
      }
    }
  });
} 