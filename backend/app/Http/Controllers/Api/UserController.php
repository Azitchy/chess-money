<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $currentUserId = $request->user()->id;
        $onlineWindowSeconds = 120;

        $users = User::query()
            ->where('id', '!=', $currentUserId)
            ->where('is_active', true)
            ->orderBy('name')
            ->get(['id', 'name', 'username', 'email', 'last_seen_at', 'api_token']);

        return response()->json([
            'data' => $users->map(function (User $user) use ($onlineWindowSeconds) {
                $lastSeenAt = $user->last_seen_at;
                $isOnline = $user->api_token
                    && $lastSeenAt
                    ? $lastSeenAt->diffInSeconds(now()) <= $onlineWindowSeconds
                    : false;

                return [
                    'id' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                    'email' => $user->email,
                    'last_seen_at' => $lastSeenAt,
                    'is_online' => $isOnline,
                ];
            })->values(),
        ]);
    }
}
