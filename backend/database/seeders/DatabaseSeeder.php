<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'admin@chessbet.local'],
            [
                'name' => 'Platform Admin',
                'username' => 'admin',
                'phone_number' => null,
                'password' => 'Admin@12345',
                'wallet_balance' => 0,
                'is_admin' => true,
                'is_active' => true,
            ]
        );
    }
}
