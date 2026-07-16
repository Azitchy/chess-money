<?php

namespace App\Services;

use App\Models\PlatformNotification;

class NotificationBroadcaster
{
    public function created(PlatformNotification $notification): void
    {
        $this->send('notification.created', $notification);
    }

    public function updated(PlatformNotification $notification): void
    {
        $this->send('notification.updated', $notification);
    }

    public function deleted(int $notificationId): void
    {
        $this->send('notification.deleted', null, ['id' => $notificationId]);
    }

    private function send(string $event, ?PlatformNotification $notification, array $extra = []): void
    {
        $host = env('NOTIFICATION_WS_PUBLISH_HOST', '127.0.0.1');
        $port = (int) env('NOTIFICATION_WS_PUBLISH_PORT', 8082);
        $payload = json_encode([
            'event' => $event,
            'notification' => $notification ? $this->payload($notification) : null,
            ...$extra,
        ], JSON_UNESCAPED_SLASHES);

        if ($payload === false) {
            return;
        }

        $socket = @stream_socket_client(
            "tcp://{$host}:{$port}",
            $errno,
            $errstr,
            1,
            STREAM_CLIENT_CONNECT
        );

        if (! $socket) {
            return;
        }

        fwrite($socket, $payload."\n");
        fclose($socket);
    }

    private function payload(PlatformNotification $notification): array
    {
        return [
            'id' => $notification->id,
            'notice_type' => $notification->notice_type,
            'title' => $notification->title,
            'body' => $notification->body,
            'action_label' => $notification->action_label,
            'action_url' => $notification->action_url,
            'is_active' => $notification->is_active,
            'created_at' => $notification->created_at?->toISOString(),
            'updated_at' => $notification->updated_at?->toISOString(),
        ];
    }
}
