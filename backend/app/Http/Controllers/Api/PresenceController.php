<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PresenceController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json([
            'is_online' => (bool) $request->user()->is_online,
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'is_online' => ['required', 'boolean'],
        ]);

        $request->user()->forceFill([
            'is_online' => $data['is_online'],
            'last_seen_at' => now(),
        ])->save();

        return response()->json([
            'message' => $data['is_online']
                ? 'You are now online'
                : 'You are now offline',
            'is_online' => (bool) $data['is_online'],
        ]);
    }
}
