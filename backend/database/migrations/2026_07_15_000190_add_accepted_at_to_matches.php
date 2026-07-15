<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('matches', function (Blueprint $table) {
            $table->timestamp('accepted_at')->nullable()->after('started_at');
        });

        // Older active rows have no proof of notification acceptance. Close
        // them and return any locked stakes before enforcing the new gate.
        DB::transaction(function () {
            $legacyMatches = DB::table('matches')
                ->where('status', 'active')
                ->whereNull('accepted_at')
                ->get();

            foreach ($legacyMatches as $match) {
                $lockedBets = DB::table('bets')
                    ->where('match_id', $match->id)
                    ->where('status', 'locked')
                    ->get();

                foreach ($lockedBets as $bet) {
                    DB::table('users')->where('id', $bet->user_id)->increment('wallet_balance', $bet->amount);
                    DB::table('wallet_transactions')->insert([
                        'user_id' => $bet->user_id,
                        'amount' => $bet->amount,
                        'type' => 'refund',
                        'status' => 'completed',
                        'reference' => (string) Str::uuid(),
                        'description' => "Refund for unverified match #{$match->id}",
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }

                DB::table('bets')->where('match_id', $match->id)->where('status', 'locked')->update(['status' => 'refunded']);
                DB::table('matches')->where('id', $match->id)->update([
                    'status' => 'cancelled',
                    'current_turn_user_id' => null,
                    'ended_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        });
    }

    public function down(): void
    {
        Schema::table('matches', function (Blueprint $table) {
            $table->dropColumn('accepted_at');
        });
    }
};
