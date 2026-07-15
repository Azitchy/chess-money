<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class OnlinePlayersTest extends TestCase
{
    use RefreshDatabase;

    public function test_users_endpoint_returns_only_other_active_online_players(): void
    {
        $plainToken = 'current-player-token';
        $currentUser = User::factory()->create([
            'api_token' => hash('sha256', $plainToken),
            'last_seen_at' => now(),
        ]);

        $onlinePlayer = User::factory()->create([
            'name' => 'Online Player',
            'api_token' => hash('sha256', 'online-player-token'),
            'last_seen_at' => now()->subSeconds(20),
            'is_active' => true,
        ]);

        User::factory()->create([
            'name' => 'Offline Player',
            'api_token' => hash('sha256', 'offline-player-token'),
            'last_seen_at' => now()->subMinutes(5),
            'is_active' => true,
        ]);

        User::factory()->create([
            'name' => 'Inactive Player',
            'api_token' => hash('sha256', 'inactive-player-token'),
            'last_seen_at' => now(),
            'is_active' => false,
        ]);

        $response = $this
            ->withToken($plainToken)
            ->getJson('/api/users');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $onlinePlayer->id)
            ->assertJsonPath('data.0.is_online', true)
            ->assertJsonMissing(['id' => $currentUser->id]);
    }
}
