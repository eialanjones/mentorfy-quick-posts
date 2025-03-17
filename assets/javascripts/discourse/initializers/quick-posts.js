import { withPluginApi } from "discourse/lib/plugin-api";
import { registerQuickPostModel } from "../models/quick-post";
import QuickPosts from "../components/quick-posts";

export default {
  name: "quick-posts",

  initialize() {
    withPluginApi("2.1.0", (api) => {
      // Registra o modelo e adaptador
      registerQuickPostModel(api);

      // Renderiza o componente no outlet da lista de tópicos
      api.renderInOutlet("topic-list-after-row", QuickPosts);
      
      // Renderiza o componente no outlet do final do tópico
      api.registerConnectorClass("topic-area-bottom", "topic-quick-posts");
      
      // Adiciona classe ao body quando quick-posts está habilitado
      if (api.container.lookup("service:site-settings").enable_quick_posts) {
        document.body.classList.add("quick-posts-enabled");
      }
    });
  },
};
