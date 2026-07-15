<?php

namespace Database\Seeders;

use App\Models\Bet;
use App\Models\MatchGame;
use App\Models\User;
use App\Models\WalletFundingRequest;
use App\Models\WalletTransaction;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $admin = User::updateOrCreate(
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

        $testUserOne = User::updateOrCreate(
            ['email' => 'test1@g.com'],
            [
                'name' => 'Paris Bartoletti',
                'username' => 'test1',
                'phone_number' => null,
                'password' => 'Test@12345',
                'wallet_balance' => 0.58,
                'is_admin' => false,
                'is_active' => true,
                'last_seen_at' => now(),
            ]
        );

        $testUserTwo = User::updateOrCreate(
            ['email' => 'test2@g.com'],
            [
                'name' => 'Miss Iliana Harne DVM',
                'username' => 'test2',
                'phone_number' => null,
                'password' => 'Test@12345',
                'wallet_balance' => 35.69,
                'is_admin' => false,
                'is_active' => true,
                'last_seen_at' => now(),
            ]
        );

        $players = User::factory(30)->create();
        $players = $players->merge([$testUserOne, $testUserTwo])->values();

        foreach ($players as $player) {
            WalletTransaction::create([
                'user_id' => $player->id,
                'amount' => (float) $player->wallet_balance,
                'type' => 'deposit',
                'status' => 'completed',
                'reference' => (string) Str::uuid(),
                'description' => 'Initial seeded balance',
            ]);
        }

        foreach (range(1, 20) as $i) {
            $player = $players->random();
            $amount = fake()->randomFloat(2, 10, 200);
            $status = fake()->randomElement(['pending', 'approved', 'rejected']);

            $request = WalletFundingRequest::create([
                'user_id' => $player->id,
                'amount' => $amount,
                'status' => $status,
                'note' => fake()->sentence(),
                'reviewed_by' => $status === 'pending' ? null : $admin->id,
                'reviewed_at' => $status === 'pending' ? null : now()->subDays(fake()->numberBetween(0, 10)),
            ]);

            if ($request->status === 'approved') {
                $player->wallet_balance = (float) $player->wallet_balance + $amount;
                $player->save();

                WalletTransaction::create([
                    'user_id' => $player->id,
                    'amount' => $amount,
                    'type' => 'deposit',
                    'status' => 'completed',
                    'reference' => (string) Str::uuid(),
                    'description' => 'Admin approved funding request',
                ]);
            }
        }

        foreach (range(1, 45) as $i) {
            $player1 = $players->random();
            $player2 = $players->where('id', '!=', $player1->id)->random();
            $mode = fake()->randomElement(['casual', 'competitive']);
            $betAmount = $mode === 'competitive' ? fake()->randomFloat(2, 5, 50) : 0;
            $status = fake()->randomElement(['completed', 'active', 'cancelled', 'pending']);

            $match = MatchGame::create([
                'player_1_id' => $player1->id,
                'player_2_id' => $status === 'pending' ? null : $player2->id,
                'winner_id' => null,
                'bet_amount' => $betAmount,
                'mode' => $mode,
                'time_control' => fake()->randomElement(['bullet', 'blitz', 'rapid', 'classical']),
                'status' => $status,
                'started_at' => in_array($status, ['active', 'completed', 'cancelled'], true) ? now()->subDays(fake()->numberBetween(0, 15)) : null,
                'ended_at' => in_array($status, ['completed', 'cancelled'], true) ? now()->subDays(fake()->numberBetween(0, 10)) : null,
            ]);

            if ($mode === 'competitive' && $status !== 'pending' && $match->player_2_id) {
                $betStatus = $status === 'cancelled' ? 'refunded' : ($status === 'completed' ? 'settled' : 'locked');

                Bet::create([
                    'match_id' => $match->id,
                    'user_id' => $player1->id,
                    'amount' => $betAmount,
                    'status' => $betStatus,
                ]);
                Bet::create([
                    'match_id' => $match->id,
                    'user_id' => $player2->id,
                    'amount' => $betAmount,
                    'status' => $betStatus,
                ]);

                WalletTransaction::create([
                    'user_id' => $player1->id,
                    'amount' => -$betAmount,
                    'type' => 'bet_locked',
                    'status' => 'completed',
                    'reference' => (string) Str::uuid(),
                    'description' => "Bet locked for match #{$match->id}",
                ]);
                WalletTransaction::create([
                    'user_id' => $player2->id,
                    'amount' => -$betAmount,
                    'type' => 'bet_locked',
                    'status' => 'completed',
                    'reference' => (string) Str::uuid(),
                    'description' => "Bet locked for match #{$match->id}",
                ]);

                if ($status === 'completed') {
                    $winner = fake()->randomElement([$player1, $player2]);
                    $match->winner_id = $winner->id;
                    $match->save();

                    WalletTransaction::create([
                        'user_id' => $winner->id,
                        'amount' => $betAmount * 2,
                        'type' => 'win_reward',
                        'status' => 'completed',
                        'reference' => (string) Str::uuid(),
                        'description' => "Winning reward for match #{$match->id}",
                    ]);
                }

                if ($status === 'cancelled') {
                    WalletTransaction::create([
                        'user_id' => $player1->id,
                        'amount' => $betAmount,
                        'type' => 'refund',
                        'status' => 'completed',
                        'reference' => (string) Str::uuid(),
                        'description' => "Refund for match #{$match->id}",
                    ]);
                    WalletTransaction::create([
                        'user_id' => $player2->id,
                        'amount' => $betAmount,
                        'type' => 'refund',
                        'status' => 'completed',
                        'reference' => (string) Str::uuid(),
                        'description' => "Refund for match #{$match->id}",
                    ]);
                }
            }
        }
    }
}
