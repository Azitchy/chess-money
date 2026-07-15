<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Bet;
use App\Models\MatchGame;
use App\Models\User;
use App\Services\WalletService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MatchController extends Controller
{
    public function create(Request $request)
    {
        $data = $request->validate([
            'mode' => ['required', 'in:casual,competitive'],
            'bet_amount' => ['nullable', 'numeric', 'min:0'],
            'time_control' => ['required', 'in:bullet,blitz,rapid,classical'],
            'opponent_id' => ['nullable', 'integer', 'exists:users,id'],
        ]);

        $betAmount = $data['mode'] === 'competitive' ? (float) ($data['bet_amount'] ?? 0) : 0;
        if ($data['mode'] === 'competitive' && $betAmount <= 0) {
            return response()->json(['message' => 'Competitive match requires bet amount'], 422);
        }

        if (($data['opponent_id'] ?? null) === $request->user()->id) {
            return response()->json(['message' => 'Cannot challenge yourself'], 422);
        }

        if (isset($data['opponent_id'])) {
            $opponent = User::findOrFail($data['opponent_id']);
            $opponentIsOnline = $opponent->is_active
                && $opponent->is_online
                && $opponent->api_token
                && $opponent->last_seen_at
                && $opponent->last_seen_at->diffInSeconds(now()) <= 120;

            if (! $opponentIsOnline) {
                return response()->json([
                    'message' => 'This player is currently offline',
                ], 422);
            }
        }

        $match = MatchGame::create([
            'player_1_id' => $request->user()->id,
            'challenged_user_id' => $data['opponent_id'] ?? null,
            'mode' => $data['mode'],
            'bet_amount' => $betAmount,
            'time_control' => $data['time_control'],
            'status' => 'pending',
        ]);

        return response()->json($match, 201);
    }

    public function join(Request $request, MatchGame $match, WalletService $walletService)
    {
        if ($match->status !== 'pending' || $match->player_2_id) {
            return response()->json(['message' => 'Match unavailable'], 422);
        }

        if ($match->player_1_id === $request->user()->id) {
            return response()->json(['message' => 'Cannot join your own match'], 422);
        }

        if ($match->challenged_user_id && $match->challenged_user_id !== $request->user()->id) {
            return response()->json(['message' => 'This challenge was sent to another player'], 422);
        }

        DB::transaction(function () use ($match, $request, $walletService) {
            $player1 = User::lockForUpdate()->findOrFail($match->player_1_id);
            $player2 = User::lockForUpdate()->findOrFail($request->user()->id);

            if ($match->mode === 'competitive') {
                $walletService->deductFunds($player1, (float) $match->bet_amount, 'bet_locked', "Bet locked for match #{$match->id}");
                $walletService->deductFunds($player2, (float) $match->bet_amount, 'bet_locked', "Bet locked for match #{$match->id}");

                Bet::create(['match_id' => $match->id, 'user_id' => $player1->id, 'amount' => $match->bet_amount]);
                Bet::create(['match_id' => $match->id, 'user_id' => $player2->id, 'amount' => $match->bet_amount]);
            }

            $match->player_2_id = $player2->id;
            $match->status = 'active';
            $match->started_at = now();
            $match->save();
        });

        return response()->json(['message' => 'Match joined and started']);
    }

    public function end(Request $request, MatchGame $match, WalletService $walletService)
    {
        $data = $request->validate([
            'result' => ['required', 'in:player1_win,player2_win,draw,cancelled'],
        ]);

        if ($match->status !== 'active') {
            return response()->json(['message' => 'Match is not active'], 422);
        }

        DB::transaction(function () use ($match, $data, $walletService) {
            $player1 = User::lockForUpdate()->findOrFail($match->player_1_id);
            $player2 = User::lockForUpdate()->findOrFail($match->player_2_id);

            if ($match->mode === 'competitive') {
                if (in_array($data['result'], ['draw', 'cancelled'], true)) {
                    $walletService->addFunds($player1, (float) $match->bet_amount, 'refund', "Refund for match #{$match->id}");
                    $walletService->addFunds($player2, (float) $match->bet_amount, 'refund', "Refund for match #{$match->id}");
                    Bet::where('match_id', $match->id)->update(['status' => 'refunded']);
                } else {
                    $winner = $data['result'] === 'player1_win' ? $player1 : $player2;
                    $winnerId = $winner->id;
                    $walletService->addFunds($winner, (float) $match->bet_amount * 2, 'win_reward', "Winning reward for match #{$match->id}");
                    Bet::where('match_id', $match->id)->update(['status' => 'settled']);
                    $match->winner_id = $winnerId;
                }
            } elseif ($data['result'] === 'player1_win') {
                $match->winner_id = $player1->id;
            } elseif ($data['result'] === 'player2_win') {
                $match->winner_id = $player2->id;
            }

            $match->status = $data['result'] === 'cancelled' ? 'cancelled' : 'completed';
            $match->ended_at = now();
            $match->save();
        });

        return response()->json(['message' => 'Match settled']);
    }

    public function history(Request $request)
    {
        return response()->json(
            MatchGame::where('player_1_id', $request->user()->id)
                ->orWhere('player_2_id', $request->user()->id)
                ->orWhere('challenged_user_id', $request->user()->id)
                ->latest()
                ->paginate(20)
        );
    }
}
