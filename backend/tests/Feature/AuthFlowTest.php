<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_creates_user_and_returns_token(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'Player One',
            'username' => 'playerone',
            'email' => 'playerone@example.com',
            'password' => 'Password123!',
        ]);

        $response->assertCreated()
            ->assertJsonStructure([
                'token',
                'user' => ['id', 'name', 'username', 'email'],
            ]);

        $this->assertDatabaseHas('users', [
            'username' => 'playerone',
            'email' => 'playerone@example.com',
        ]);

        $this->assertNotEmpty($response->json('token'));
    }

    public function test_login_accepts_username_or_email(): void
    {
        $user = User::factory()->create([
            'username' => 'chesspro',
            'email' => 'chesspro@example.com',
            'password' => 'Password123!',
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/login', [
            'login' => $user->username,
            'password' => 'Password123!',
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'token',
                'user' => ['id', 'name', 'username', 'email'],
            ]);

        $this->assertNotEmpty($response->json('token'));
    }

    public function test_admin_users_page_shows_registered_users(): void
    {
        $admin = User::factory()->create([
            'is_admin' => true,
            'is_active' => true,
            'password' => 'Admin@12345',
        ]);

        $player = User::factory()->create([
            'name' => 'Visible Player',
            'username' => 'visibleplayer',
            'email' => 'visible@example.com',
        ]);

        $response = $this->actingAs($admin)->get('/admin/users');

        $response->assertOk()
            ->assertSee('Visible Player')
            ->assertSee('visible@example.com')
            ->assertSee('Player');
    }
}
