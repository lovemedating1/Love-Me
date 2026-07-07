# LoveMe Flutter — Matching Module Integration Guide

Covers the tables added in `003_matching.sql` + `004_matching_rls.sql`: **likes, passes, matches, profile_views**. Builds on the auth/profile setup in `FRONTEND_INTEGRATION_GUIDE.md` — read that first if you haven't wired up Supabase yet.

---

## 1. What's new

| Table | Purpose |
|---|---|
| `likes` | A user liking another user's profile (swipe right) |
| `passes` | A user skipping another user's profile (swipe left) |
| `matches` | Created automatically when two users like each other — **not created by the client** |
| `profile_views` | Log of profile visits, for view-quota enforcement |

**Important:** there is no trigger yet that promotes mutual likes into a `matches` row. That comes in a later migration. For now, `matches` is a read/update-only table from the client's perspective — you can display matches and let users unmatch/block, but you cannot create a match directly.

---

## 2. Models

**models/like.dart**

```dart
class Like {
  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime createdAt;

  Like({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
  });

  factory Like.fromJson(Map<String, dynamic> json) => Like(
        id: json['id'],
        fromUserId: json['from_user_id'],
        toUserId: json['to_user_id'],
        createdAt: DateTime.parse(json['created_at']),
      );
}
```

**models/match.dart**

```dart
enum MatchStatus { active, unmatched, blocked }

MatchStatus matchStatusFromString(String value) {
  switch (value) {
    case 'unmatched':
      return MatchStatus.unmatched;
    case 'blocked':
      return MatchStatus.blocked;
    default:
      return MatchStatus.active;
  }
}

String matchStatusToString(MatchStatus status) => status.name;

class Match {
  final String id;
  final String user1Id;
  final String user2Id;
  final MatchStatus status;
  final String? blockedBy;
  final DateTime matchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Match({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.status,
    this.blockedBy,
    required this.matchedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: json['id'],
        user1Id: json['user1_id'],
        user2Id: json['user2_id'],
        status: matchStatusFromString(json['status']),
        blockedBy: json['blocked_by'],
        matchedAt: DateTime.parse(json['matched_at']),
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  // Given the current user's id, return the other participant's id
  String otherUserId(String myUserId) => user1Id == myUserId ? user2Id : user1Id;
}
```

---

## 3. Service: Likes & Passes (Swipe Actions)

**services/swipe_service.dart**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SwipeService {
  final supabase = Supabase.instance.client;

  // Swipe right — like a profile
  Future<void> likeProfile(String toUserId) async {
    final myId = supabase.auth.currentUser!.id;
    await supabase.from('likes').insert({
      'from_user_id': myId,
      'to_user_id': toUserId,
    });
    // Note: no immediate "it's a match!" signal yet — matches are
    // created by a trigger in a later migration. Poll or subscribe
    // to the matches table (see MatchService) to detect new matches.
  }

  // Swipe left — pass on a profile
  Future<void> passProfile(String toUserId) async {
    final myId = supabase.auth.currentUser!.id;
    await supabase.from('passes').insert({
      'from_user_id': myId,
      'to_user_id': toUserId,
    });
  }

  // Undo a like (e.g. "rewind" feature)
  Future<void> unlikeProfile(String toUserId) async {
    final myId = supabase.auth.currentUser!.id;
    await supabase
        .from('likes')
        .delete()
        .eq('from_user_id', myId)
        .eq('to_user_id', toUserId);
  }

  // Get everyone who liked me
  Future<List<Map<String, dynamic>>> getLikesReceived() async {
    final myId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from('likes')
        .select()
        .eq('to_user_id', myId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Get profile ids already swiped (liked or passed) — exclude from discovery deck
  Future<Set<String>> getSwipedUserIds() async {
    final myId = supabase.auth.currentUser!.id;

    final liked = await supabase.from('likes').select('to_user_id').eq('from_user_id', myId);
    final passed = await supabase.from('passes').select('to_user_id').eq('from_user_id', myId);

    final ids = <String>{};
    for (final row in liked as List) ids.add(row['to_user_id'] as String);
    for (final row in passed as List) ids.add(row['to_user_id'] as String);
    return ids;
  }
}
```

**Constraints enforced server-side (no need to duplicate client-side, but handle the errors):**
- Can't like/pass yourself → Postgres raises a CHECK violation (`23514`) if attempted.
- Can't like/pass the same profile twice → unique violation (`23505`) on a duplicate insert. Catch this and treat it as a no-op or show "already swiped."

```dart
try {
  await swipeService.likeProfile(profileId);
} on PostgrestException catch (e) {
  if (e.code == '23505') {
    // already liked this profile — ignore or show a toast
  } else if (e.code == '23514') {
    // tried to like own profile — should not happen if UI filters self out
  } else {
    rethrow;
  }
}
```

---

## 4. Service: Matches

**services/match_service.dart**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match.dart';

class MatchService {
  final supabase = Supabase.instance.client;

  // Get all active matches for the current user
  Future<List<Match>> getMyMatches() async {
    final myId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from('matches')
        .select()
        .or('user1_id.eq.$myId,user2_id.eq.$myId')
        .eq('status', 'active')
        .order('matched_at', ascending: false);

    return (response as List).map((m) => Match.fromJson(m)).toList();
  }

  // Unmatch (soft — sets status, does not delete the row)
  Future<void> unmatch(String matchId) async {
    await supabase
        .from('matches')
        .update({'status': 'unmatched'})
        .eq('id', matchId);
  }

  // Block the other user in a match
  Future<void> blockMatch(String matchId) async {
    final myId = supabase.auth.currentUser!.id;
    await supabase.from('matches').update({
      'status': 'blocked',
      'blocked_by': myId,
    }).eq('id', matchId);
  }

  // Subscribe to new matches in realtime (fires when the future
  // mutual-like trigger inserts a row involving the current user)
  RealtimeChannel subscribeToNewMatches(void Function(Match) onNewMatch) {
    final myId = supabase.auth.currentUser!.id;
    return supabase
        .channel('public:matches:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'matches',
          callback: (payload) {
            final match = Match.fromJson(payload.newRecord);
            if (match.user1Id == myId || match.user2Id == myId) {
              onNewMatch(match);
            }
          },
        )
        .subscribe();
  }
}
```

**Note on `blocked_by`:** the DB enforces that `blocked_by` is set if and only if `status = 'blocked'` — you cannot set `status: 'blocked'` without `blocked_by`, and you cannot set `blocked_by` unless `status` is also `'blocked'` in the same update. Always send both fields together when blocking.

**No insert/delete access:** RLS only grants `SELECT` and `UPDATE` on `matches`. Attempting `.insert()` or `.delete()` from the client will fail with a permissions error (`42501`) — this is intentional; matches are system-created.

---

## 5. Service: Profile Views

**services/profile_view_service.dart**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileViewService {
  final supabase = Supabase.instance.client;

  // Record that the current user viewed another profile
  Future<void> recordView(String viewedUserId) async {
    final myId = supabase.auth.currentUser!.id;
    await supabase.from('profile_views').insert({
      'viewer_user_id': myId,
      'viewed_user_id': viewedUserId,
    });
  }

  // Get my own view history (for quota UI, e.g. "12/50 views used this month")
  Future<List<Map<String, dynamic>>> getMyViewHistory() async {
    final myId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from('profile_views')
        .select()
        .eq('viewer_user_id', myId)
        .order('viewed_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}
```

**Note:** RLS only lets you see views **you** made — you cannot query who viewed your own profile via this table. "Who viewed me" is a future premium feature that will need its own RPC (per the backend spec), not a direct table query.

There is currently no quota enforcement in the database — the `can_send_like` / `record_profile_view` RPCs documented in the full backend spec don't exist yet. Call `recordView()` yourself when a profile is opened; don't rely on the backend to reject over-quota views yet.

---

## 6. REST Endpoints Reference

```
POST   /rest/v1/likes             body: { from_user_id, to_user_id }
GET    /rest/v1/likes?to_user_id=eq.<uuid>
DELETE /rest/v1/likes?from_user_id=eq.<uuid>&to_user_id=eq.<uuid>

POST   /rest/v1/passes            body: { from_user_id, to_user_id }
GET    /rest/v1/passes?from_user_id=eq.<uuid>

GET    /rest/v1/matches?or=(user1_id.eq.<uuid>,user2_id.eq.<uuid>)&status=eq.active
PATCH  /rest/v1/matches?id=eq.<uuid>   body: { status: "unmatched" }
PATCH  /rest/v1/matches?id=eq.<uuid>   body: { status: "blocked", blocked_by: "<uuid>" }

POST   /rest/v1/profile_views     body: { viewer_user_id, viewed_user_id }
GET    /rest/v1/profile_views?viewer_user_id=eq.<uuid>
```

---

## 7. RLS Summary (what the DB will and won't let you do)

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `likes` | sent or received | own (`from_user_id = auth.uid()`) | — | sent or received |
| `passes` | own (`from_user_id`) | own | — | own |
| `matches` | as participant | — (system only) | as participant | — |
| `profile_views` | own (`viewer_user_id`) | own | — | own |

Anything not listed above (e.g. inserting a match, updating a like) will be rejected by RLS, not silently ignored — expect a `42501` Postgrest error and handle it rather than assuming success.

---

## 8. Still not built

- Trigger to auto-create `matches` on mutual like
- `can_send_like` (50/day free-tier cap) and `record_profile_view` (monthly quota) RPCs
- Blocking a match does not yet cascade into hiding chat/messages (messages table doesn't exist yet)
- "Who viewed me" feature

Check back as these land in future migrations.