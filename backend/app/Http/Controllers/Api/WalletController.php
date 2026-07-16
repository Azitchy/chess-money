<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WalletConversation;
use App\Models\WalletMessage;
use App\Models\WalletTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class WalletController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json([
            'balance' => (float) $request->user()->wallet_balance,
        ]);
    }

    public function transactions(Request $request): JsonResponse
    {
        return response()->json(
            WalletTransaction::where('user_id', $request->user()->id)
                ->latest()
                ->paginate(20)
        );
    }

    public function conversations(Request $request): JsonResponse
    {
        $threads = WalletConversation::query()
            ->with(['latestMessage.sender'])
            ->where('user_id', $request->user()->id)
            ->latest('last_message_at')
            ->paginate(20);

        return response()->json($this->paginateWithData($threads, fn (WalletConversation $conversation) => $this->conversationSummary($conversation)));
    }

    public function conversation(Request $request, WalletConversation $conversation): JsonResponse
    {
        abort_unless($conversation->user_id === $request->user()->id, 404);

        return response()->json($this->conversationDetail(
            $conversation->load(['messages.sender', 'user'])
        ));
    }

    public function requestFunds(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:1'],
            'body' => ['nullable', 'string', 'max:2000'],
            'attachment' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
        ]);

        $conversation = DB::transaction(function () use ($request, $data) {
            $conversation = WalletConversation::create([
                'user_id' => $request->user()->id,
                'amount' => $data['amount'],
                'subject' => 'Wallet funding request',
                'status' => 'open',
                'last_message_at' => now(),
            ]);

            $this->createMessage(
                conversation: $conversation,
                senderRole: 'user',
                senderUserId: $request->user()->id,
                body: $this->requestBody($data),
                attachment: $request->file('attachment')
            );

            return $conversation->load(['messages.sender', 'user']);
        });

        return response()->json($this->conversationDetail($conversation), 201);
    }

    public function reply(Request $request, WalletConversation $conversation): JsonResponse
    {
        abort_unless($conversation->user_id === $request->user()->id, 404);

        $data = $request->validate([
            'body' => ['nullable', 'string', 'max:2000'],
            'attachment' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
        ]);

        $conversation = DB::transaction(function () use ($request, $conversation, $data) {
            $this->createMessage(
                conversation: $conversation,
                senderRole: 'user',
                senderUserId: $request->user()->id,
                body: $this->replyBody($data),
                attachment: $request->file('attachment')
            );

            return $conversation->load(['messages.sender', 'user']);
        });

        return response()->json($this->conversationDetail($conversation), 201);
    }

    private function createMessage(
        WalletConversation $conversation,
        string $senderRole,
        ?int $senderUserId,
        ?string $body,
        $attachment,
    ): WalletMessage {
        $attachmentData = null;
        if ($attachment !== null) {
            $path = $attachment->store('wallet-messages', 'public');
            $attachmentData = [
                'attachment_path' => $path,
                'attachment_name' => $attachment->getClientOriginalName(),
                'attachment_mime' => $attachment->getClientMimeType(),
            ];
        }

        $message = $conversation->messages()->create([
            'sender_role' => $senderRole,
            'sender_user_id' => $senderUserId,
            'body' => $body,
            ...($attachmentData ?? []),
        ]);

        $conversation->forceFill(['last_message_at' => $message->created_at])->saveQuietly();

        return $message;
    }

    private function requestBody(array $data): string
    {
        $body = trim((string) ($data['body'] ?? ''));
        if ($body !== '') {
            return $body;
        }

        return 'Wallet funding request for $'.number_format((float) $data['amount'], 2);
    }

    private function replyBody(array $data): ?string
    {
        $body = trim((string) ($data['body'] ?? ''));
        return $body === '' ? null : $body;
    }

    private function conversationSummary(WalletConversation $conversation): array
    {
        return [
            'id' => $conversation->id,
            'subject' => $conversation->subject,
            'amount' => (float) ($conversation->amount ?? 0),
            'status' => $conversation->status,
            'last_message_at' => $conversation->last_message_at?->toISOString(),
            'created_at' => $conversation->created_at?->toISOString(),
            'updated_at' => $conversation->updated_at?->toISOString(),
            'latest_message' => $conversation->latestMessage ? $this->messagePayload($conversation->latestMessage) : null,
        ];
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

    private function paginateWithData($paginator, callable $mapper): array
    {
        return [
            'data' => $paginator->getCollection()->map($mapper)->values()->all(),
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
}
