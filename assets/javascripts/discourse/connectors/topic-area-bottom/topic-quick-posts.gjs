import Component from "@glimmer/component";
import QuickPosts from "../../components/quick-posts";

export default class TopicQuickPostsConnector extends Component {
  <template>
    <div class="topic-quick-posts-container">
      <QuickPosts @topic={{@outletArgs.model}} />
    </div>
  </template>
} 