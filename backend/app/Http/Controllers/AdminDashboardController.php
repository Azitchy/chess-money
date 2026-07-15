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
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

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

    public function users(Request $request)
    {
        $search = trim((string) $request->query('search'));
        $users = User::query()
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('username', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate(20)
            ->withQueryString();

        return view('admin.users', compact('users'));
    }

    public function createUser()
    {
        return view('admin.user_create');
    }

    public function storeUser(Request $request)
    {
        $data = $this->validateUser($request);
        $user = User::create($this->userAttributes($data));

        return redirect()
            ->route('admin.users.edit', $user)
            ->with('success', 'User created successfully');
    }

    public function editUser(User $user)
    {
        return view('admin.user_edit', compact('user'));
    }

    public function updateUser(Request $request, User $user)
    {
        $data = $this->validateUser($request, $user);
        $isSelf = $request->user()->is($user);

        if ($isSelf && ($data['role'] !== 'admin' || ! $request->boolean('is_active'))) {
            return back()->withInput()->with('error', 'You cannot remove your own admin access or suspend your own account');
        }

        if ($user->is_admin && $data['role'] !== 'admin' && User::where('is_admin', true)->count() <= 1) {
            return back()->withInput()->with('error', 'The last administrator cannot be changed to a player');
        }

        $attributes = $this->userAttributes($data, $user);
        $passwordChanged = isset($attributes['password']);
        $attributes['is_active'] = $request->boolean('is_active');

        if ($passwordChanged || ! $attributes['is_active']) {
            $attributes['api_token'] = null;
            $attributes['is_online'] = false;
            DB::table('sessions')->where('user_id', $user->id)->delete();
        }

        $user->fill($attributes);
        if ($passwordChanged || ! $attributes['is_active']) {
            $user->setRememberToken(null);
        }
        $user->save();

        return redirect()
            ->route('admin.users.edit', $user)
            ->with('success', $passwordChanged
                ? 'User details and password updated successfully'
                : 'User details updated successfully');
    }

    public function deleteUser(Request $request, User $user)
    {
        if ($request->user()->is($user)) {
            return back()->with('error', 'You cannot delete your own account');
        }

        if ($user->is_admin && User::where('is_admin', true)->count() <= 1) {
            return back()->with('error', 'The last administrator cannot be deleted');
        }

        $avatarPath = $user->avatar_path;
        $name = $user->name;
        $user->delete();

        if ($avatarPath) {
            Storage::disk('public')->delete($avatarPath);
        }

        return redirect()->route('admin.users')->with('success', "{$name} was deleted");
    }

    public function toggleUserStatus(User $user)
    {
        if ($user->is_admin) {
            return back()->with('error', 'Cannot suspend admin account');
        }

        $user->is_active = ! $user->is_active;
        if (! $user->is_active) {
            $user->api_token = null;
            $user->is_online = false;
            $user->remember_token = null;
            DB::table('sessions')->where('user_id', $user->id)->delete();
        }
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

    private function validateUser(Request $request, ?User $user = null): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'username' => [
                'required',
                'string',
                'max:255',
                Rule::unique('users', 'username')->ignore($user?->id),
            ],
            'email' => [
                'required',
                'email',
                'max:255',
                Rule::unique('users', 'email')->ignore($user?->id),
            ],
            'phone_number' => ['nullable', 'string', 'max:50'],
            'address' => ['nullable', 'string', 'max:1000'],
            'rating' => ['required', 'integer', 'min:0'],
            'level' => ['required', 'integer', 'min:0'],
            'role' => ['required', Rule::in(['player', 'admin'])],
            'is_active' => ['nullable', 'boolean'],
            'password' => [
                $user ? 'nullable' : 'required',
                'string',
                'min:8',
                'confirmed',
            ],
        ]);
    }

    private function userAttributes(array $data, ?User $user = null): array
    {
        $attributes = [
            'name' => $data['name'],
            'username' => $data['username'],
            'email' => $data['email'],
            'phone_number' => $data['phone_number'] ?? null,
            'address' => $data['address'] ?? null,
            'rating' => $data['rating'],
            'level' => $data['level'],
            'is_admin' => $data['role'] === 'admin',
            'is_active' => (bool) ($data['is_active'] ?? false),
        ];

        if (! empty($data['password'])) {
            $attributes['password'] = $data['password'];
        }

        if (! $user) {
            $attributes['wallet_balance'] = 0;
            $attributes['is_online'] = false;
        }

        return $attributes;
    }
}
