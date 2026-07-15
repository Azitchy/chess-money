<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AdminUserManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_create_a_user_with_login_and_profile_details(): void
    {
        $admin = $this->admin();

        $response = $this->actingAs($admin)->post('/admin/users', [
            'name' => 'Created Player',
            'username' => 'created_player',
            'email' => 'created@example.com',
            'phone_number' => '555-0100',
            'address' => '10 Chess Street',
            'rating' => 4,
            'level' => 2,
            'role' => 'player',
            'is_active' => 1,
            'password' => 'NewPassword123!',
            'password_confirmation' => 'NewPassword123!',
        ]);

        $user = User::where('username', 'created_player')->firstOrFail();
        $response->assertRedirect(route('admin.users.edit', $user));
        $this->assertSame('Created Player', $user->name);
        $this->assertSame('555-0100', $user->phone_number);
        $this->assertSame('10 Chess Street', $user->address);
        $this->assertSame(4, $user->rating);
        $this->assertSame(2, $user->level);
        $this->assertTrue($user->is_active);
        $this->assertFalse($user->is_admin);
        $this->assertTrue(Hash::check('NewPassword123!', $user->password));
    }

    public function test_admin_can_edit_login_details_and_change_password(): void
    {
        $admin = $this->admin();
        $user = User::factory()->create([
            'username' => 'old_login',
            'email' => 'old@example.com',
            'password' => 'OldPassword123!',
            'api_token' => hash('sha256', 'mobile-token'),
            'is_online' => true,
        ]);

        $response = $this->actingAs($admin)->put("/admin/users/{$user->id}", [
            'name' => 'Updated Player',
            'username' => 'new_login',
            'email' => 'new@example.com',
            'phone_number' => '555-0200',
            'address' => '20 Rook Road',
            'rating' => 8,
            'level' => 3,
            'role' => 'player',
            'is_active' => 1,
            'password' => 'ChangedPassword123!',
            'password_confirmation' => 'ChangedPassword123!',
        ]);

        $response->assertRedirect(route('admin.users.edit', $user));
        $user->refresh();
        $this->assertSame('new_login', $user->username);
        $this->assertSame('new@example.com', $user->email);
        $this->assertTrue(Hash::check('ChangedPassword123!', $user->password));
        $this->assertNull($user->api_token);
        $this->assertFalse($user->is_online);
    }

    public function test_admin_can_delete_another_user_but_not_their_own_account(): void
    {
        $admin = $this->admin();
        $player = User::factory()->create();

        $this->actingAs($admin)->delete("/admin/users/{$player->id}")
            ->assertRedirect(route('admin.users'));
        $this->assertDatabaseMissing('users', ['id' => $player->id]);

        $this->actingAs($admin)->delete("/admin/users/{$admin->id}")
            ->assertSessionHas('error', 'You cannot delete your own account');
        $this->assertDatabaseHas('users', ['id' => $admin->id]);
    }

    public function test_non_admin_cannot_manage_users(): void
    {
        $player = User::factory()->create(['is_admin' => false]);

        $this->actingAs($player)->get('/admin/users/create')->assertForbidden();
        $this->actingAs($player)->post('/admin/users', [])->assertForbidden();
    }

    private function admin(): User
    {
        return User::factory()->create([
            'is_admin' => true,
            'is_active' => true,
        ]);
    }
}
