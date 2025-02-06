import { withPluginApi } from "discourse/lib/plugin-api";
import { registerQuickPostModel } from "../models/quick-post";

export default {
  name: "quick-posts",

  initialize() {
    withPluginApi("2.1.0", (api) => {
      // Registra o modelo e adaptador
      registerQuickPostModel(api);

      // Registra o conector para a lista de tópicos
      api.registerConnectorClass(
        "topic-list-after-row",
        "quick-posts",
        {
          shouldRender(args) {
            return args.siteSettings.enable_quick_posts;
          }
        }
      );

      // Adiciona o componente ao título do tópico usando a nova API
      api.decorateWidget("topic-title", {
        after(helper) {
          const { attrs } = helper;
          if (!attrs.topic) {
            return;
          }

          return helper.attach("quick-posts", { topic: attrs.topic });
        }
      });
    });
  }
}; 