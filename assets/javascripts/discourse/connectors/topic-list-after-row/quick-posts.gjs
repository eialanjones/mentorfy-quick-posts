import Component from "@glimmer/component";
import QuickPosts from "../../components/quick-posts";

export default class QuickPostsConnector extends Component {
  <template>
    {{#unless @outletArgs.useMobileLayout}}
      <tr class="topic-list-item-quick-posts">
        <td colspan="6">
          <QuickPosts @topic={{@outletArgs.topic}} />
        </td>
      </tr>
    {{/unless}}
  </template>
} 