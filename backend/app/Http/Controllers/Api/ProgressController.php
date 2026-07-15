<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ProgressionEvent;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProgressController extends Controller
{
    public function puzzleCompleted(Request $request)
    {
        $data = $request->validate([
            'puzzle_id' => ['required', 'string', 'max:191'],
            'theme' => ['nullable', 'string', 'max:100'],
        ]);

        return $this->award(
            $request,
            'puzzle',
            $data['puzzle_id'],
            'rating',
            ['theme' => $data['theme'] ?? null],
        );
    }

    public function botWon(Request $request)
    {
        $data = $request->validate([
            'game_id' => ['required', 'string', 'max:191'],
            'difficulty' => ['required', 'in:Beginner,Intermediate,Advanced'],
        ]);

        return $this->award(
            $request,
            'bot',
            $data['game_id'],
            'level',
            ['difficulty' => $data['difficulty']],
        );
    }

    private function award(
        Request $request,
        string $activityType,
        string $activityKey,
        string $progressColumn,
        array $details,
    ) {
        $result = DB::transaction(function () use (
            $request,
            $activityType,
            $activityKey,
            $progressColumn,
            $details,
        ) {
            $user = User::lockForUpdate()->findOrFail($request->user()->id);
            $event = ProgressionEvent::firstOrCreate(
                [
                    'user_id' => $user->id,
                    'activity_type' => $activityType,
                    'activity_key' => $activityKey,
                ],
                ['details' => $details],
            );

            if ($event->wasRecentlyCreated) {
                $user->{$progressColumn} = (int) $user->{$progressColumn} + 1;
                $user->save();
            }

            return [
                'awarded' => $event->wasRecentlyCreated,
                'rating' => (int) $user->rating,
                'level' => (int) $user->level,
            ];
        });

        return response()->json($result);
    }
}
