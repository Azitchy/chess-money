<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
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
            'wallet_balance' => 20,
        ]);
        $this->assertDatabaseHas('wallet_transactions', [
            'amount' => 20,
            'type' => 'deposit',
            'status' => 'completed',
            'description' => 'Welcome registration bonus',
        ]);

        $this->assertNotEmpty($response->json('token'));
    }

    public function test_login_accepts_email_or_phone_number(): void
    {
        $user = User::factory()->create([
            'username' => 'chesspro',
            'email' => 'chesspro@example.com',
            'phone_number' => '+977 9800000000',
            'password' => 'Password123!',
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/login', [
            'identifier' => $user->phone_number,
            'password' => 'Password123!',
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'token',
                'user' => ['id', 'name', 'username', 'email'],
            ]);

        $this->assertNotEmpty($response->json('token'));
    }

    public function test_google_login_creates_or_reuses_user(): void
    {
        config(['services.google.client_ids' => ['test-client-id']]);

        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'aud' => 'test-client-id',
                'email_verified' => 'true',
                'email' => 'google.user@example.com',
                'name' => 'Google User',
                'sub' => 'google-sub-123',
            ], 200),
        ]);

        $response = $this->postJson('/api/google-login', [
            'id_token' => 'fake-token',
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'token',
                'user' => ['id', 'name', 'username', 'email'],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'google.user@example.com',
            'google_id' => 'google-sub-123',
            'wallet_balance' => 20,
        ]);
        $this->assertDatabaseHas('wallet_transactions', [
            'amount' => 20,
            'type' => 'deposit',
            'status' => 'completed',
            'description' => 'Welcome registration bonus',
        ]);

        $this->assertNotEmpty($response->json('token'));
    }

    public function test_google_login_accepts_mobile_access_token(): void
    {
        Http::fake([
            'https://openidconnect.googleapis.com/v1/userinfo' => Http::response([
                'email_verified' => true,
                'email' => 'mobile.user@example.com',
                'name' => 'Mobile User',
                'sub' => 'mobile-google-sub-123',
            ], 200),
        ]);

        $response = $this->postJson('/api/google-login', [
            'access_token' => 'fake-mobile-access-token',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.email', 'mobile.user@example.com');

        $this->assertDatabaseHas('users', [
            'email' => 'mobile.user@example.com',
            'google_id' => 'mobile-google-sub-123',
            'wallet_balance' => 20,
        ]);
    }

    public function test_google_login_reuses_existing_gmail_without_creating_duplicate(): void
    {
        $existingUser = User::factory()->create([
            'email' => 'Existing.User@GMAIL.com',
            'google_id' => null,
            'is_active' => true,
            'wallet_balance' => 35,
        ]);

        Http::fake([
            'https://openidconnect.googleapis.com/v1/userinfo' => Http::response([
                'email_verified' => true,
                'email' => 'existing.user@gmail.com',
                'name' => 'Existing User',
                'sub' => 'existing-google-sub-123',
            ], 200),
        ]);

        $response = $this->postJson('/api/google-login', [
            'access_token' => 'fake-mobile-access-token',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.id', $existingUser->id)
            ->assertJsonPath('user.email', 'existing.user@gmail.com');

        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseHas('users', [
            'id' => $existingUser->id,
            'email' => 'existing.user@gmail.com',
            'google_id' => 'existing-google-sub-123',
            'wallet_balance' => 35,
        ]);
        $this->assertDatabaseCount('wallet_transactions', 0);
    }

    public function test_google_login_rejects_gmail_linked_to_another_google_id(): void
    {
        User::factory()->create([
            'email' => 'linked.user@gmail.com',
            'google_id' => 'original-google-sub',
            'is_active' => true,
        ]);

        Http::fake([
            'https://openidconnect.googleapis.com/v1/userinfo' => Http::response([
                'email_verified' => true,
                'email' => 'linked.user@gmail.com',
                'name' => 'Linked User',
                'sub' => 'different-google-sub',
            ], 200),
        ]);

        $response = $this->postJson('/api/google-login', [
            'access_token' => 'fake-mobile-access-token',
        ]);

        $response->assertStatus(409)
            ->assertJsonPath(
                'message',
                'This Gmail address is already linked to another Google account.'
            );

        $this->assertDatabaseCount('users', 1);
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
