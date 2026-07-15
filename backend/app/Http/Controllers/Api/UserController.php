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
        $onlineSince = now()->subSeconds($onlineWindowSeconds);

        $users = User::query()
            ->where('id', '!=', $currentUserId)
            ->where('is_active', true)
            ->whereNotNull('api_token')
            ->where('last_seen_at', '>=', $onlineSince)
            ->orderByDesc('last_seen_at')
            ->get(['id', 'name', 'username', 'email', 'avatar_path', 'last_seen_at']);

        return response()->json([
            'data' => $users->map(function (User $user) {
                return [
                    'id' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                    'email' => $user->email,
                    'avatar_url' => $user->avatar_path
                        ? '/storage/'.$user->avatar_path
                        : null,
                    'last_seen_at' => $user->last_seen_at,
                    'is_online' => true,
                ];
            })->values(),
        ]);
    }
}
