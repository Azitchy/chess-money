<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PlatformNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $notifications = PlatformNotification::query()
            ->where('is_active', true)
            ->latest()
            ->get();

        $lastSeenAt = $request->user()->last_notification_seen_at;
        $unreadCount = $notifications->filter(function (PlatformNotification $notification) use ($lastSeenAt) {
            return $lastSeenAt === null || $notification->created_at->greaterThan($lastSeenAt);
        })->count();

        return response()->json([
            'data' => $notifications->map(function (PlatformNotification $notification) use ($lastSeenAt) {
                return $this->notificationPayload($notification, $lastSeenAt);
            })->values()->all(),
            'unread_count' => $unreadCount,
            'last_seen_at' => $lastSeenAt?->toISOString(),
        ]);
    }

    public function markSeen(Request $request): JsonResponse
    {
        $request->user()->forceFill([
            'last_notification_seen_at' => now(),
        ])->save();

        return $this->index($request);
    }

    private function notificationPayload(
        PlatformNotification $notification,
        $lastSeenAt
    ): array {
        return [
            'id' => $notification->id,
            'notice_type' => $notification->notice_type,
            'title' => $notification->title,
            'body' => $notification->body,
            'action_label' => $notification->action_label,
            'action_url' => $notification->action_url,
            'is_active' => $notification->is_active,
            'is_read' => $lastSeenAt !== null
                && ! $notification->created_at->greaterThan($lastSeenAt),
            'created_at' => $notification->created_at?->toISOString(),
        ];
    }
}
