<?php

namespace App\Services;

use App\Models\WalletTransaction;
use Illuminate\Support\Str;

class WalletService
{
    public function addFunds(object $user, float $amount, string $type, string $description): void
    {
        $user->wallet_balance = (float) $user->wallet_balance + $amount;
        $user->save();

        WalletTransaction::create([
            'user_id' => $user->id,
            'amount' => $amount,
            'type' => $type,
            'status' => 'completed',
            'reference' => (string) Str::uuid(),
            'description' => $description,
        ]);
    }

    public function deductFunds(object $user, float $amount, string $type, string $description): void
    {
        if ((float) $user->wallet_balance < $amount) {
            abort(422, 'Insufficient wallet balance. Please contact admin to load funds.');
        }

        $user->wallet_balance = (float) $user->wallet_balance - $amount;
        $user->save();

        WalletTransaction::create([
            'user_id' => $user->id,
            'amount' => -$amount,
            'type' => $type,
            'status' => 'completed',
            'reference' => (string) Str::uuid(),
            'description' => $description,
        ]);
    }
}
