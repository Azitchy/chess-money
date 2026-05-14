<?php

namespace App\Http\Controllers;

use App\Models\Bet;
use App\Models\MatchGame;
use App\Models\User;
use App\Models\WalletFundingRequest;
use App\Models\WalletTransaction;
use App\Services\WalletService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminDashboardController extends Controller
{
    public function index()
    {
        $stats = [
            'users' => User::count(),
            'active_users' => User::where('is_active', true)->count(),
            'matches' => MatchGame::count(),
            'active_matches' => MatchGame::where('status', 'active')->count(),
            'pending_funding_requests' => WalletFundingRequest::where('status', 'pending')->count(),
            'total_wagered' => (float) Bet::sum('amount'),
        ];

        return view('admin.dashboard', compact('stats'));
    }

    public function users()
    {
        $users = User::latest()->paginate(20);
        return view('admin.users', compact('users'));
    }

    public function toggleUserStatus(User $user)
    {
        if ($user->is_admin) {
            return back()->with('error', 'Cannot suspend admin account');
        }

        $user->is_active = ! $user->is_active;
        $user->save();

        return back()->with('success', 'User status updated');
    }

    public function walletForm(User $user)
    {
        return view('admin.wallet_adjust', compact('user'));
    }

    public function walletAdjust(Request $request, User $user, WalletService $walletService)
    {
        $data = $request->validate([
            'action' => ['required', 'in:add,deduct'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'description' => ['required', 'string', 'max:255'],
        ]);

        DB::transaction(function () use ($data, $user, $walletService) {
            $lockedUser = User::lockForUpdate()->findOrFail($user->id);
            $amount = (float) $data['amount'];

            if ($data['action'] === 'add') {
                $walletService->addFunds($lockedUser, $amount, 'deposit', $data['description']);
            } else {
                $walletService->deductFunds($lockedUser, $amount, 'withdrawal', $data['description']);
            }
        });

        return redirect()->route('admin.users')->with('success', 'Wallet updated');
    }

    public function fundingRequests()
    {
        $requests = WalletFundingRequest::with('user')->latest()->paginate(20);
        return view('admin.funding_requests', compact('requests'));
    }

    public function approveFunding(WalletFundingRequest $fundingRequest, WalletService $walletService)
    {
        if ($fundingRequest->status !== 'pending') {
            return back()->with('error', 'Request already processed');
        }

        DB::transaction(function () use ($fundingRequest, $walletService) {
            $user = User::lockForUpdate()->findOrFail($fundingRequest->user_id);
            $walletService->addFunds($user, (float) $fundingRequest->amount, 'deposit', 'Admin approved funding request');

            $fundingRequest->status = 'approved';
            $fundingRequest->reviewed_by = auth()->id();
            $fundingRequest->reviewed_at = now();
            $fundingRequest->save();
        });

        return back()->with('success', 'Funding request approved');
    }

    public function rejectFunding(WalletFundingRequest $fundingRequest)
    {
        if ($fundingRequest->status !== 'pending') {
            return back()->with('error', 'Request already processed');
        }

        $fundingRequest->status = 'rejected';
        $fundingRequest->reviewed_by = auth()->id();
        $fundingRequest->reviewed_at = now();
        $fundingRequest->save();

        return back()->with('success', 'Funding request rejected');
    }

    public function matches()
    {
        $matches = MatchGame::latest()->paginate(20);
        return view('admin.matches', compact('matches'));
    }

    public function transactions()
    {
        $transactions = WalletTransaction::latest()->paginate(20);
        return view('admin.transactions', compact('transactions'));
    }
}
