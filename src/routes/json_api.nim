# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, times, options
import jester
import router_utils
import ".."/[types, redis_cache, api]

proc createJsonApiRouter*(cfg: Config) =
  router jsonApi:
    proc userToJson(user: User): JsonNode =
      result = %*{
        "id": user.id,
        "username": user.username,
        "fullname": user.fullname,
        "location": user.location,
        "website": user.website,
        "bio": user.bio,
        "userPic": user.userPic,
        "banner_url": user.banner,
        "following": user.following,
        "followers": user.followers,
        "tweets": user.tweets,
        "likes": user.likes,
        "media": user.media,
        "verifiedType": $user.verifiedType,
        "protected": user.protected,
        "suspended": user.suspended,
        "joinDate": user.joinDate.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
      }
      
      if user.pinnedTweet != 0:
        result["pinnedTweet"] = %user.pinnedTweet

    proc tweetToJson(tweet: Tweet): JsonNode =
      if tweet == nil:
        return newJNull()
      
      result = %*{
        "id": tweet.id,
        "threadId": tweet.threadId,
        "text": tweet.text,
        "time": tweet.time.format("yyyy-MM-dd'T'HH:mm:ss'Z'"),
        "hasThread": tweet.hasThread,
        "available": tweet.available,
        "location": tweet.location,
        "replyCount": tweet.stats.replies,
        "retweetCount": tweet.stats.retweets,
        "likeCount": tweet.stats.likes,
        "quoteCount": tweet.stats.quotes
      }
      
      if tweet.replyId != 0:
        result["replyId"] = %tweet.replyId
      
      if tweet.reply.len > 0:
        result["reply"] = %tweet.reply
      
      if tweet.pinned:
        result["pinned"] = %true
      
      if tweet.tombstone.len > 0:
        result["tombstone"] = %tweet.tombstone
      
      result["user"] = userToJson(tweet.user)
      
      if tweet.retweet.isSome:
        result["retweet"] = tweetToJson(tweet.retweet.get)
      
      if tweet.attribution.isSome:
        result["attribution"] = userToJson(tweet.attribution.get)
      
      if tweet.mediaTags.len > 0:
        result["mediaTags"] = newJArray()
        for tag in tweet.mediaTags:
          result["mediaTags"].add(userToJson(tag))
      
      if tweet.quote.isSome:
        result["quote"] = tweetToJson(tweet.quote.get)
      
      if tweet.poll.isSome:
        let poll = tweet.poll.get
        result["poll"] = %*{
          "options": poll.options,
          "values": poll.values,
          "votes": poll.votes,
          "leader": poll.leader,
          "status": poll.status
        }
      
      if tweet.gif.isSome:
        let gif = tweet.gif.get
        result["gif"] = %*{
          "url": gif.url,
          "thumb": gif.thumb
        }
      
      if tweet.video.isSome:
        let video = tweet.video.get
        result["video"] = %*{
          "durationMs": video.durationMs,
          "url": video.url,
          "thumb": video.thumb,
          "views": video.views,
          "available": video.available,
          "reason": video.reason,
          "title": video.title,
          "description": video.description,
          "playbackType": $video.playbackType
        }
        
        if video.variants.len > 0:
          result["video"]["variants"] = newJArray()
          for variant in video.variants:
            result["video"]["variants"].add(%*{
              "contentType": $variant.contentType,
              "url": variant.url,
              "bitrate": variant.bitrate,
              "resolution": variant.resolution
            })
      
      if tweet.photos.len > 0:
        result["photos"] = %tweet.photos
      
      if tweet.card.isSome:
        let card = tweet.card.get
        result["card"] = %*{
          "kind": $card.kind,
          "url": card.url,
          "title": card.title,
          "dest": card.dest,
          "text": card.text,
          "image": card.image
        }
        
        if card.video.isSome:
          let video = card.video.get
          result["card"]["video"] = %*{
            "durationMs": video.durationMs,
            "url": video.url,
            "thumb": video.thumb,
            "views": video.views,
            "available": video.available,
            "reason": video.reason,
            "title": video.title,
            "description": video.description,
            "playbackType": $video.playbackType
          }

    proc timelineToJson(timeline: Timeline): JsonNode =
      result = %*{
        "content": newJArray(),
        "top": timeline.top,
        "bottom": timeline.bottom,
        "beginning": timeline.beginning
      }
      
      for tweets in timeline.content:
        for tweet in tweets:
          result["content"].add(tweetToJson(tweet))
    
    get "/api/user/@username":
      let username = @"username"
      
      if username.len == 0:
        let error = %*{"error": "Username parameter is required"}
        resp $error, "application/json"
      
      try:
        let user = await getCachedUser(username)
        
        if user.id.len == 0:
          let error = %*{"error": "User not found", "username": username}
          resp Http404, $error, "application/json"
        elif user.suspended:
          let error = %*{"error": "User is suspended", "username": username}
          resp Http403, $error, "application/json"
        else:
          respJson(userToJson(user))
      except InternalError:
        let error = %*{"error": "Internal server error"}
        resp Http500, $error, "application/json"
      except RateLimitError:
        let error = %*{"error": "Rate limit exceeded"}
        resp Http429, $error, "application/json"
      except NoSessionsError:
        let error = %*{"error": "No sessions available"}
        resp Http503, $error, "application/json"
    
    get "/api/tweets":
      let 
        username = @"username"
        cursor = @"cursor"
      
      if username.len == 0:
        let error = %*{"error": "Username parameter is required"}
        resp $error, "application/json"
      
      try:
        let userId = await getUserId(username)
        
        if userId.len == 0:
          let error = %*{"error": "User not found", "username": username}
          resp Http404, $error, "application/json"
        elif userId == "suspended":
          let error = %*{"error": "User is suspended", "username": username}
          resp Http403, $error, "application/json"
        else:
          let profile = await getGraphUserTweets(userId, TimelineKind.tweets, cursor)
          
          let response = %*{
            "username": username,
            "userId": userId,
            "tweets": timelineToJson(profile.tweets),
            "cursor": profile.tweets.bottom
          }
          
          respJson(response)
      except InternalError:
        let error = %*{"error": "Internal server error"}
        resp Http500, $error, "application/json"
      except RateLimitError:
        let error = %*{"error": "Rate limit exceeded"}
        resp Http429, $error, "application/json"
      except NoSessionsError:
        let error = %*{"error": "No sessions available"}
        resp Http503, $error, "application/json"