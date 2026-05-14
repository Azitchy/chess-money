<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\WalletFundingRequest;
use App\Services\WalletService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminController extends Controller
{
    public function fundingRequests()
    {
        return response()->json(WalletFundingRequest::latest()->paginate(20));
    }

    public function approveFunding(Request $request, WalletFundingRequest $fundingRequest, WalletService $walletService)
    {
        if ($fundingRequest->status !== 'pending') {
            return response()->json(['message' => 'Request already processed'], 422);
        }

        DB::transaction(function () use ($fundingRequest, $request, $walletService) {
            $user = User::lockForUpdate()->findOrFail($fundingRequest->user_id);
            $walletService->addFunds($user, (float) $fundingRequest->amount, 'deposit', 'Admin approved funding request');

            $fundingRequest->status = 'approved';
            $fundingRequest->reviewed_by = $request->user()->id;
            $fundingRequest->reviewed_at = now();
            $fundingRequest->save();
        });

        return response()->json(['message' => 'Funding approved']);
    }
}
