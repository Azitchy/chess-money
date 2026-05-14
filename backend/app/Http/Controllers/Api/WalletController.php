<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WalletFundingRequest;
use App\Models\WalletTransaction;
use Illuminate\Http\Request;

class WalletController extends Controller
{
    public function show(Request $request)
    {
        return response()->json([
            'balance' => (float) $request->user()->wallet_balance,
        ]);
    }

    public function transactions(Request $request)
    {
        return response()->json(
            WalletTransaction::where('user_id', $request->user()->id)
                ->latest()
                ->paginate(20)
        );
    }

    public function requestFunds(Request $request)
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:1'],
            'note' => ['nullable', 'string', 'max:1000'],
        ]);

        $fundingRequest = WalletFundingRequest::create([
            'user_id' => $request->user()->id,
            'amount' => $data['amount'],
            'note' => $data['note'] ?? null,
        ]);

        return response()->json($fundingRequest, 201);
    }
}
