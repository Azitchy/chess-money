<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class OnlinePlayersTest extends TestCase
{
    use RefreshDatabase;

    public function test_users_endpoint_returns_active_players_with_online_users_first(): void
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

        $offlinePlayer = User::factory()->create([
            'name' => 'Offline Player',
            'api_token' => hash('sha256', 'offline-player-token'),
            'last_seen_at' => now()->subSeconds(10),
            'is_active' => true,
            'is_online' => false,
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
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $onlinePlayer->id)
            ->assertJsonPath('data.0.is_online', true)
            ->assertJsonPath('data.1.id', $offlinePlayer->id)
            ->assertJsonPath('data.1.is_online', false)
            ->assertJsonMissing(['id' => $currentUser->id]);
    }

    public function test_user_can_switch_their_presence_off_and_on(): void
    {
        $plainToken = 'presence-toggle-token';
        $user = User::factory()->create([
            'api_token' => hash('sha256', $plainToken),
            'last_seen_at' => now(),
            'is_online' => true,
        ]);

        $this->withToken($plainToken)
            ->postJson('/api/presence', ['is_online' => false])
            ->assertOk()
            ->assertJsonPath('is_online', false);
        $this->assertFalse($user->fresh()->is_online);

        $this->withToken($plainToken)
            ->postJson('/api/presence', ['is_online' => true])
            ->assertOk()
            ->assertJsonPath('is_online', true);
        $this->assertTrue($user->fresh()->is_online);
    }
}
