<?php

namespace App\Http\Controllers;

use App\Models\Bet;
use App\Models\MatchGame;
use App\Models\User;
use App\Models\WalletConversation;
use App\Models\WalletMessage;
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
            'pending_funding_requests' => WalletConversation::where('status', 'open')->count(),
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
        $conversations = WalletConversation::with(['user', 'latestMessage.sender'])
            ->latest('last_message_at')
            ->paginate(20);
        $selectedConversation = WalletConversation::with(['user', 'messages.sender'])
            ->when(request()->integer('conversation'), function ($query, $conversationId) {
                $query->whereKey($conversationId);
            })
            ->first()
            ?? WalletConversation::with(['user', 'messages.sender'])->latest('last_message_at')->first();

        return view('admin.funding_requests', compact('conversations', 'selectedConversation'));
    }

    public function walletConversationSummary(Request $request)
    {
        $conversations = WalletConversation::with(['user', 'latestMessage.sender'])
            ->latest('last_message_at')
            ->paginate(20);

        return response()->json($this->conversationPaginator($conversations));
    }

    public function walletConversationThread(WalletConversation $conversation)
    {
        return response()->json(
            $this->conversationDetail($conversation->load(['user', 'messages.sender']))
        );
    }

    public function replyFunding(Request $request, WalletConversation $conversation)
    {
        $data = $request->validate([
            'body' => ['required', 'string', 'max:2000'],
            'attachment' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
        ]);

        DB::transaction(function () use ($request, $conversation, $data) {
            $conversation = WalletConversation::lockForUpdate()->findOrFail($conversation->id);
            $this->storeConversationMessage(
                conversation: $conversation,
                senderRole: 'admin',
                senderUserId: $request->user()->id,
                body: trim($data['body']),
                attachment: $request->file('attachment')
            );
        });

        return back()->with('success', 'Reply sent');
    }

    public function approveFunding(Request $request, WalletConversation $conversation, WalletService $walletService)
    {
        if ($conversation->status !== 'open') {
            return back()->with('error', 'Conversation already processed');
        }

        DB::transaction(function () use ($request, $conversation, $walletService) {
            $lockedConversation = WalletConversation::lockForUpdate()->findOrFail($conversation->id);
            $user = User::lockForUpdate()->findOrFail($lockedConversation->user_id);
            $amount = (float) ($lockedConversation->amount ?? 0);

            if ($amount <= 0) {
                abort(422, 'This conversation does not include a funding amount');
            }

            $walletService->addFunds($user, $amount, 'deposit', 'Admin approved wallet funding message');
            $lockedConversation->status = 'approved';
            $lockedConversation->save();

            $this->storeConversationMessage(
                conversation: $lockedConversation,
                senderRole: 'system',
                senderUserId: null,
                body: 'Funding approved. $'.number_format($amount, 2).' has been added to the wallet.',
                attachment: null
            );
        });

        return back()->with('success', 'Funding approved');
    }

    public function rejectFunding(Request $request, WalletConversation $conversation)
    {
        if ($conversation->status !== 'open') {
            return back()->with('error', 'Conversation already processed');
        }

        DB::transaction(function () use ($request, $conversation) {
            $lockedConversation = WalletConversation::lockForUpdate()->findOrFail($conversation->id);
            $lockedConversation->status = 'rejected';
            $lockedConversation->save();

            $this->storeConversationMessage(
                conversation: $lockedConversation,
                senderRole: 'system',
                senderUserId: null,
                body: 'Funding request declined by admin.',
                attachment: null
            );
        });

        return back()->with('success', 'Funding rejected');
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

    private function storeConversationMessage(
        WalletConversation $conversation,
        string $senderRole,
        ?int $senderUserId,
        string $body,
        $attachment
    ): WalletMessage {
        $attachmentData = [];
        if ($attachment) {
            $attachmentData = [
                'attachment_path' => $attachment->store('wallet-messages', 'public'),
                'attachment_name' => $attachment->getClientOriginalName(),
                'attachment_mime' => $attachment->getClientMimeType(),
            ];
        }

        $message = $conversation->messages()->create([
            'sender_role' => $senderRole,
            'sender_user_id' => $senderUserId,
            'body' => $body,
            ...$attachmentData,
        ]);

        $conversation->forceFill([
            'last_message_at' => $message->created_at,
        ])->saveQuietly();

        return $message;
    }

    private function conversationDetail(WalletConversation $conversation): array
    {
        return [
            'id' => $conversation->id,
            'subject' => $conversation->subject,
            'amount' => (float) ($conversation->amount ?? 0),
            'status' => $conversation->status,
            'last_message_at' => $conversation->last_message_at?->toISOString(),
            'user' => [
                'id' => $conversation->user?->id,
                'name' => $conversation->user?->name,
                'username' => $conversation->user?->username,
            ],
            'messages' => $conversation->messages
                ->sortBy('created_at')
                ->values()
                ->map(fn (WalletMessage $message) => $this->messagePayload($message))
                ->all(),
        ];
    }

    private function conversationPaginator($paginator): array
    {
        return [
            'data' => $paginator->getCollection()
                ->map(fn (WalletConversation $conversation) => [
                    'id' => $conversation->id,
                    'subject' => $conversation->subject,
                    'amount' => (float) ($conversation->amount ?? 0),
                    'status' => $conversation->status,
                    'last_message_at' => $conversation->last_message_at?->toISOString(),
                    'user' => [
                        'id' => $conversation->user?->id,
                        'name' => $conversation->user?->name,
                        'username' => $conversation->user?->username,
                    ],
                    'latest_message' => $conversation->latestMessage
                        ? $this->messagePayload($conversation->latestMessage)
                        : null,
                ])
                ->values()
                ->all(),
            'links' => $paginator->toArray()['links'] ?? [],
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'from' => $paginator->firstItem(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'to' => $paginator->lastItem(),
                'total' => $paginator->total(),
            ],
        ];
    }

    private function messagePayload(WalletMessage $message): array
    {
        return [
            'id' => $message->id,
            'sender_role' => $message->sender_role,
            'sender_user_id' => $message->sender_user_id,
            'sender_name' => $message->sender?->name,
            'sender_username' => $message->sender?->username,
            'body' => $message->body,
            'attachment_url' => $message->attachment_path
                ? Storage::disk('public')->url($message->attachment_path)
                : null,
            'attachment_name' => $message->attachment_name,
            'attachment_mime' => $message->attachment_mime,
            'created_at' => $message->created_at?->toISOString(),
        ];
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
