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
            'bet_amount' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'time_control' => ['required', 'in:bullet,blitz,rapid,classical'],
            'opponent_id' => ['required', 'integer', 'exists:users,id'],
        ]);

        $betAmount = $data['mode'] === 'competitive' ? (float) ($data['bet_amount'] ?? 0) : 0;
        if ($data['mode'] === 'competitive' && $betAmount <= 0) {
            return response()->json(['message' => 'Competitive match requires a bet amount'], 422);
        }
        if ($data['mode'] === 'competitive' && ($betAmount < 10 || $betAmount > 100)) {
            return response()->json(['message' => 'Bet amount must be between 10 and 100'], 422);
        }
        if ($data['mode'] === 'competitive' && (float) $request->user()->wallet_balance < $betAmount) {
            return response()->json(['message' => 'Insufficient wallet balance for this bet'], 422);
        }

        $opponentId = $data['opponent_id'];
        if ($opponentId === $request->user()->id) {
            return response()->json(['message' => 'Cannot challenge yourself'], 422);
        }

        if ($opponentId) {
            $opponent = User::findOrFail($opponentId);
            if (! $opponent->isCurrentlyOnline()) {
                return response()->json(['message' => 'This player is currently offline'], 422);
            }
        }

        $match = MatchGame::create([
            'player_1_id' => $request->user()->id,
            'challenged_user_id' => $opponentId,
            'mode' => $data['mode'],
            'bet_amount' => $betAmount,
            'time_control' => $data['time_control'],
            'status' => 'pending',
            'moves' => [],
            'result_claims' => [],
        ]);

        return response()->json($this->matchData($match), 201);
    }

    public function challenges(Request $request)
    {
        $matches = MatchGame::query()
            ->where('challenged_user_id', $request->user()->id)
            ->where('status', 'pending')
            ->with('playerOne')
            ->latest()
            ->get();

        return response()->json(['data' => $matches->map(fn (MatchGame $match) => $this->matchData($match))]);
    }

    public function active(Request $request)
    {
        $userId = $request->user()->id;
        $matches = MatchGame::query()
            ->where('status', 'active')
            ->whereNotNull('accepted_at')
            ->where(fn ($query) => $query->where('player_1_id', $userId)->orWhere('player_2_id', $userId))
            ->with(['playerOne', 'playerTwo'])
            ->latest('started_at')
            ->get();

        return response()->json(['data' => $matches->map(fn (MatchGame $match) => $this->matchData($match))]);
    }

    public function accept(Request $request, MatchGame $match, WalletService $walletService)
    {
        $match = DB::transaction(function () use ($match, $request, $walletService) {
            $lockedMatch = MatchGame::lockForUpdate()->findOrFail($match->id);
            if ($lockedMatch->status !== 'pending' || $lockedMatch->player_2_id) {
                abort(422, 'Match unavailable');
            }
            if ($lockedMatch->player_1_id === $request->user()->id) {
                abort(422, 'Cannot join your own match');
            }
            if (! $lockedMatch->challenged_user_id || $lockedMatch->challenged_user_id !== $request->user()->id) {
                abort(403, 'Only the challenged player can accept this notification');
            }

            $player1 = User::lockForUpdate()->findOrFail($lockedMatch->player_1_id);
            $player2 = User::lockForUpdate()->findOrFail($request->user()->id);
            if ($lockedMatch->mode === 'competitive') {
                $amount = (float) $lockedMatch->bet_amount;
                if ((float) $player1->wallet_balance < $amount || (float) $player2->wallet_balance < $amount) {
                    abort(422, 'Both players need enough wallet balance to accept this challenge');
                }
                $walletService->deductFunds($player1, $amount, 'bet_locked', "Bet locked for match #{$lockedMatch->id}");
                $walletService->deductFunds($player2, $amount, 'bet_locked', "Bet locked for match #{$lockedMatch->id}");
                Bet::create(['match_id' => $lockedMatch->id, 'user_id' => $player1->id, 'amount' => $amount]);
                Bet::create(['match_id' => $lockedMatch->id, 'user_id' => $player2->id, 'amount' => $amount]);
            }

            $lockedMatch->update([
                'player_2_id' => $player2->id,
                'status' => 'active',
                'moves' => [],
                'result_claims' => [],
                'current_turn_user_id' => $player1->id,
                'started_at' => now(),
                'accepted_at' => now(),
            ]);

            return $lockedMatch->fresh(['playerOne', 'playerTwo']);
        });

        return response()->json(['message' => 'Challenge accepted', 'match' => $this->matchData($match)]);
    }

    public function reject(Request $request, MatchGame $match)
    {
        if ($match->challenged_user_id !== $request->user()->id) {
            abort(403, 'Only the challenged player can reject this challenge');
        }
        if ($match->status !== 'pending') {
            abort(422, 'Challenge is no longer pending');
        }

        $match->update(['status' => 'cancelled', 'rejected_at' => now(), 'ended_at' => now()]);
        return response()->json(['message' => 'Challenge rejected']);
    }

    public function state(Request $request, MatchGame $match)
    {
        $this->ensureParticipant($request, $match);
        if ($match->status !== 'active' || ! $match->accepted_at) {
            abort(422, 'The challenged player has not accepted this match');
        }
        return response()->json(['match' => $this->matchData($match->load(['playerOne', 'playerTwo']))]);
    }

    public function move(Request $request, MatchGame $match)
    {
        $data = $request->validate([
            'from' => ['required', 'regex:/^[a-h][1-8]$/'],
            'to' => ['required', 'regex:/^[a-h][1-8]$/'],
            'promotion' => ['nullable', 'in:q,r,b,n'],
        ]);

        $match = DB::transaction(function () use ($match, $request, $data) {
            $lockedMatch = MatchGame::lockForUpdate()->findOrFail($match->id);
            $this->ensureParticipant($request, $lockedMatch);
            if ($lockedMatch->status !== 'active') {
                abort(422, 'Match is not active');
            }
            if (! $lockedMatch->accepted_at) {
                abort(422, 'The challenged player has not accepted this match');
            }
            if ($lockedMatch->current_turn_user_id !== $request->user()->id) {
                abort(422, 'It is not your turn');
            }

            $moves = $lockedMatch->moves ?? [];
            $moves[] = [
                'from' => $data['from'],
                'to' => $data['to'],
                'promotion' => $data['promotion'] ?? null,
                'user_id' => $request->user()->id,
                'ply' => count($moves) + 1,
            ];
            $lockedMatch->update([
                'moves' => $moves,
                'current_turn_user_id' => $request->user()->id === $lockedMatch->player_1_id
                    ? $lockedMatch->player_2_id
                    : $lockedMatch->player_1_id,
            ]);
            return $lockedMatch->fresh(['playerOne', 'playerTwo']);
        });

        return response()->json(['match' => $this->matchData($match)]);
    }

    public function end(Request $request, MatchGame $match, WalletService $walletService)
    {
        $data = $request->validate(['result' => ['required', 'in:player1_win,player2_win,draw,cancelled']]);
        $this->ensureParticipant($request, $match);

        $outcome = DB::transaction(function () use ($match, $data, $walletService, $request) {
            $lockedMatch = MatchGame::lockForUpdate()->findOrFail($match->id);
            if ($lockedMatch->status !== 'active') {
                abort(422, 'Match is not active');
            }
            if (! $lockedMatch->accepted_at) {
                abort(422, 'The challenged player has not accepted this match');
            }

            $claims = $lockedMatch->result_claims ?? [];
            $claims[(string) $request->user()->id] = $data['result'];
            $lockedMatch->result_claims = $claims;
            $opponentId = $request->user()->id === $lockedMatch->player_1_id
                ? $lockedMatch->player_2_id
                : $lockedMatch->player_1_id;
            if (($claims[(string) $opponentId] ?? null) !== $data['result']) {
                $lockedMatch->save();
                return ['confirmed' => false, 'match' => $lockedMatch->fresh(['playerOne', 'playerTwo'])];
            }

            $player1 = User::lockForUpdate()->findOrFail($lockedMatch->player_1_id);
            $player2 = User::lockForUpdate()->findOrFail($lockedMatch->player_2_id);

            if ($lockedMatch->mode === 'competitive') {
                if (in_array($data['result'], ['draw', 'cancelled'], true)) {
                    $walletService->addFunds($player1, (float) $lockedMatch->bet_amount, 'refund', "Refund for match #{$lockedMatch->id}");
                    $walletService->addFunds($player2, (float) $lockedMatch->bet_amount, 'refund', "Refund for match #{$lockedMatch->id}");
                    Bet::where('match_id', $lockedMatch->id)->update(['status' => 'refunded']);
                } else {
                    $winner = $data['result'] === 'player1_win' ? $player1 : $player2;
                    $walletService->addFunds($winner, (float) $lockedMatch->bet_amount * 2, 'win_reward', "Winning reward for match #{$lockedMatch->id}");
                    Bet::where('match_id', $lockedMatch->id)->update(['status' => 'settled']);
                    $lockedMatch->winner_id = $winner->id;
                }
            } elseif ($data['result'] === 'player1_win') {
                $lockedMatch->winner_id = $player1->id;
            } elseif ($data['result'] === 'player2_win') {
                $lockedMatch->winner_id = $player2->id;
            }

            if ($lockedMatch->winner_id) {
                $winner = $lockedMatch->winner_id === $player1->id ? $player1 : $player2;
                $winner->rating = (int) $winner->rating + 1;
                $winner->level = (int) $winner->level + 1;
                $winner->save();
            }

            $lockedMatch->status = $data['result'] === 'cancelled' ? 'cancelled' : 'completed';
            $lockedMatch->ended_at = now();
            $lockedMatch->current_turn_user_id = null;
            $lockedMatch->save();
            return ['confirmed' => true, 'match' => $lockedMatch->fresh(['playerOne', 'playerTwo'])];
        });

        return response()->json([
            'message' => $outcome['confirmed'] ? 'Match settled' : 'Waiting for opponent result confirmation',
            'confirmed' => $outcome['confirmed'],
            'match' => $this->matchData($outcome['match']),
        ]);
    }

    public function history(Request $request)
    {
        $userId = $request->user()->id;
        return response()->json(MatchGame::query()
            ->where(fn ($query) => $query->where('player_1_id', $userId)
                ->orWhere('player_2_id', $userId)
                ->orWhere('challenged_user_id', $userId))
            ->latest()
            ->paginate(20));
    }

    private function ensureParticipant(Request $request, MatchGame $match): void
    {
        if (! in_array($request->user()->id, [$match->player_1_id, $match->player_2_id], true)) {
            abort(403, 'You are not a participant in this match');
        }
    }

    private function matchData(MatchGame $match): array
    {
        return [
            'id' => $match->id,
            'player_1_id' => $match->player_1_id,
            'challenged_user_id' => $match->challenged_user_id,
            'player_2_id' => $match->player_2_id,
            'winner_id' => $match->winner_id,
            'bet_amount' => (float) $match->bet_amount,
            'mode' => $match->mode,
            'time_control' => $match->time_control,
            'status' => $match->status,
            'moves' => $match->moves ?? [],
            'result_claims' => $match->result_claims ?? [],
            'current_turn_user_id' => $match->current_turn_user_id,
            'player_one' => $match->relationLoaded('playerOne') ? $match->playerOne : null,
            'player_two' => $match->relationLoaded('playerTwo') ? $match->playerTwo : null,
            'created_at' => $match->created_at,
            'started_at' => $match->started_at,
            'accepted_at' => $match->accepted_at,
            'ended_at' => $match->ended_at,
        ];
    }
}
