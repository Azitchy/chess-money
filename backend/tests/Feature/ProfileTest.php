<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_view_and_update_profile_with_avatar(): void
    {
        Storage::fake('public');
        $plainToken = 'profile-test-token';
        $user = User::factory()->create([
            'api_token' => hash('sha256', $plainToken),
            'email' => 'before@example.com',
        ]);

        $png = base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'.
            'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
        );

        $response = $this
            ->withToken($plainToken)
            ->post('/api/profile', [
                'name' => 'Updated Player',
                'email' => 'updated@example.com',
                'phone_number' => '+977 9812345678',
                'address' => 'Kathmandu, Nepal',
                'avatar' => UploadedFile::fake()->createWithContent('avatar.png', $png),
            ], ['Accept' => 'application/json']);

        $response->assertOk()
            ->assertJsonPath('user.name', 'Updated Player')
            ->assertJsonPath('user.email', 'updated@example.com')
            ->assertJsonPath('user.phone_number', '+977 9812345678')
            ->assertJsonPath('user.address', 'Kathmandu, Nepal');

        $avatarPath = $user->fresh()->avatar_path;
        $this->assertNotNull($avatarPath);
        Storage::disk('public')->assertExists($avatarPath);

        $this->withToken($plainToken)
            ->getJson('/api/profile')
            ->assertOk()
            ->assertJsonPath('name', 'Updated Player')
            ->assertJsonPath('avatar_url', '/storage/'.$avatarPath);
    }
}
