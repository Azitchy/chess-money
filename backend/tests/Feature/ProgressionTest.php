<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProgressionTest extends TestCase
{
    use RefreshDatabase;

    public function test_unique_puzzles_raise_rating_once_and_never_change_wallet_or_level(): void
    {
        $user = User::factory()->create(['wallet_balance' => 100, 'rating' => 0, 'level' => 0]);
        $token = $user->createToken('test')->plainTextToken;

        $this->withToken($token)->postJson('/api/progress/puzzle-completed', [
            'puzzle_id' => 'lesson-a',
            'theme' => 'Fork',
        ])->assertOk()
            ->assertJsonPath('awarded', true)
            ->assertJsonPath('rating', 1)
            ->assertJsonPath('level', 0);

        $this->withToken($token)->postJson('/api/progress/puzzle-completed', [
            'puzzle_id' => 'lesson-a',
            'theme' => 'Fork',
        ])->assertOk()
            ->assertJsonPath('awarded', false)
            ->assertJsonPath('rating', 1);

        $this->withToken($token)->postJson('/api/progress/puzzle-completed', [
            'puzzle_id' => 'lesson-b',
            'theme' => 'Pin',
        ])->assertOk()->assertJsonPath('rating', 2);

        $user->refresh();
        $this->assertSame(2, $user->rating);
        $this->assertSame(0, $user->level);
        $this->assertEquals(100, (float) $user->wallet_balance);
        $this->assertDatabaseCount('wallet_transactions', 0);
    }

    public function test_unique_bot_wins_raise_level_once_and_never_change_wallet_or_rating(): void
    {
        $user = User::factory()->create(['wallet_balance' => 100, 'rating' => 0, 'level' => 0]);
        $token = $user->createToken('test')->plainTextToken;

        $this->withToken($token)->postJson('/api/progress/bot-won', [
            'game_id' => 'bot-game-a',
            'difficulty' => 'Beginner',
        ])->assertOk()
            ->assertJsonPath('awarded', true)
            ->assertJsonPath('rating', 0)
            ->assertJsonPath('level', 1);

        $this->withToken($token)->postJson('/api/progress/bot-won', [
            'game_id' => 'bot-game-a',
            'difficulty' => 'Beginner',
        ])->assertOk()
            ->assertJsonPath('awarded', false)
            ->assertJsonPath('level', 1);

        $this->withToken($token)->postJson('/api/progress/bot-won', [
            'game_id' => 'bot-game-b',
            'difficulty' => 'Advanced',
        ])->assertOk()->assertJsonPath('level', 2);

        $user->refresh();
        $this->assertSame(0, $user->rating);
        $this->assertSame(2, $user->level);
        $this->assertEquals(100, (float) $user->wallet_balance);
        $this->assertDatabaseCount('wallet_transactions', 0);
    }
}
