import '../entities/feed_request.dart';

abstract class RequestFeedService {
  FeedRequest? findById(String id);
}
