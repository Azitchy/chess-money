<?php

namespace Tests\Feature;

use App\Models\MatchGame;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChallengeFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_challenge_can_be_received_accepted_played_and_settled(): void
    {
        [$challenger, $challengerToken] = $this->onlineUser();
        [$opponent, $opponentToken] = $this->onlineUser();

        $created = $this->withToken($challengerToken)->postJson('/api/matches', [
            'mode' => 'competitive',
            'bet_amount' => 10,
            'time_control' => 'blitz',
            'opponent_id' => $opponent->id,
        ])->assertCreated()->json();

        $matchId = $created['id'];
        $this->assertNull(MatchGame::find($matchId)->accepted_at);
        $this->withToken($challengerToken)->getJson('/api/matches/active')
            ->assertOk()
            ->assertJsonCount(0, 'data');
        $this->withToken($challengerToken)->getJson("/api/matches/{$matchId}/state")
            ->assertUnprocessable();
        $this->withToken($opponentToken)->postJson("/api/matches/{$matchId}/join")
            ->assertNotFound();
        $this->assertEquals(100, (float) $challenger->fresh()->wallet_balance);
        $this->assertEquals(100, (float) $opponent->fresh()->wallet_balance);

        $this->withToken($opponentToken)->getJson('/api/matches/challenges')
            ->assertOk()
            ->assertJsonPath('data.0.id', $matchId)
            ->assertJsonPath('data.0.player_one.id', $challenger->id);

        $this->withToken($opponentToken)->postJson("/api/matches/{$matchId}/accept")
            ->assertOk()
            ->assertJsonPath('match.status', 'active')
            ->assertJsonPath('match.current_turn_user_id', $challenger->id);
        $this->assertNotNull(MatchGame::find($matchId)->accepted_at);

        $this->assertEquals(90, (float) $challenger->fresh()->wallet_balance);
        $this->assertEquals(90, (float) $opponent->fresh()->wallet_balance);

        $this->withToken($opponentToken)->postJson("/api/matches/{$matchId}/move", [
            'from' => 'e7', 'to' => 'e5',
        ])->assertUnprocessable();

        $this->withToken($challengerToken)->postJson("/api/matches/{$matchId}/move", [
            'from' => 'e2', 'to' => 'e4',
        ])->assertOk()->assertJsonPath('match.current_turn_user_id', $opponent->id);

        $this->withToken($opponentToken)->postJson("/api/matches/{$matchId}/end", [
            'result' => 'player1_win',
        ])->assertOk()->assertJsonPath('confirmed', false);

        $this->withToken($challengerToken)->postJson("/api/matches/{$matchId}/end", [
            'result' => 'player1_win',
        ])->assertOk()->assertJsonPath('confirmed', true)->assertJsonPath('match.winner_id', $challenger->id);

        $this->assertEquals(110, (float) $challenger->fresh()->wallet_balance);
        $this->assertEquals(90, (float) $opponent->fresh()->wallet_balance);
        $this->assertSame(1, $challenger->fresh()->rating);
        $this->assertSame(1, $challenger->fresh()->level);
        $this->assertSame(0, $opponent->fresh()->rating);
        $this->assertSame(0, $opponent->fresh()->level);
        $this->assertDatabaseHas('bets', ['match_id' => $matchId, 'user_id' => $opponent->id, 'status' => 'settled']);
    }

    public function test_only_the_challenged_player_can_reject(): void
    {
        [$challenger, $challengerToken] = $this->onlineUser();
        [$opponent, $opponentToken] = $this->onlineUser();
        $match = MatchGame::create([
            'player_1_id' => $challenger->id,
            'challenged_user_id' => $opponent->id,
            'mode' => 'casual',
            'bet_amount' => 0,
            'time_control' => 'rapid',
            'status' => 'pending',
        ]);

        $this->withToken($challengerToken)->postJson("/api/matches/{$match->id}/reject")->assertForbidden();
        $this->withToken($opponentToken)->postJson("/api/matches/{$match->id}/reject")->assertOk();
        $this->assertDatabaseHas('matches', ['id' => $match->id, 'status' => 'cancelled']);
    }

    private function onlineUser(): array
    {
        $token = fake()->unique()->sha256();
        $user = User::factory()->create([
            'wallet_balance' => 100,
            'is_active' => true,
            'is_online' => true,
            'api_token' => hash('sha256', $token),
            'last_seen_at' => now(),
        ]);

        return [$user, $token];
    }
}
