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
            ->orderByDesc('is_online')
            ->orderByDesc('last_seen_at')
            ->get([
                'id',
                'name',
                'username',
                'email',
                'avatar_path',
                'is_online',
                'last_seen_at',
                'api_token',
            ]);

        return response()->json([
            'data' => $users->map(function (User $user) use ($onlineWindowSeconds) {
                $isOnline = $user->is_online
                    && $user->api_token
                    && $user->last_seen_at
                    && $user->last_seen_at->diffInSeconds(now()) <= $onlineWindowSeconds;

                return [
                    'id' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                    'email' => $user->email,
                    'avatar_url' => $user->avatar_path
                        ? '/storage/'.$user->avatar_path
                        : null,
                    'last_seen_at' => $user->last_seen_at,
                    'is_online' => (bool) $isOnline,
                ];
            })->values(),
        ]);
    }
}
