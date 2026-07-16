@extends('admin.layout')

@section('content')
@php
  $selectedId = $selectedConversation?->id;
@endphp

<div class="content-header">
  <h1>Wallet Messages</h1>
  <div class="crumb">Admin / Wallet Support Inbox</div>
</div>

<div class="two-col" style="align-items:start">
  <div class="card">
    <div style="display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:12px">
      <strong>Threads</strong>
      <span class="crumb">{{ $conversations->total() }} total</span>
    </div>
    <div id="conversation-list">
      @forelse($conversations as $conversation)
        <a
          href="{{ route('admin.funding-requests', ['conversation' => $conversation->id]) }}"
          style="display:block;padding:12px 14px;margin-bottom:10px;border-radius:14px;border:1px solid {{ $selectedId === $conversation->id ? '#93c5fd' : '#dbe4ef' }};background:{{ $selectedId === $conversation->id ? '#eff6ff' : '#fff' }}"
        >
          <div style="display:flex;justify-content:space-between;gap:12px;align-items:center">
            <strong>#{{ $conversation->id }} {{ $conversation->subject }}</strong>
            <span style="font-size:12px;padding:4px 8px;border-radius:999px;{{ $conversation->status === 'approved' ? 'background:#dcfce7;color:#166534' : ($conversation->status === 'rejected' ? 'background:#fee2e2;color:#991b1b' : 'background:#fff7cc;color:#8a6d00') }}">
              {{ ucfirst($conversation->status) }}
            </span>
          </div>
          <div style="margin-top:4px;color:#475569">User: {{ $conversation->user?->name }} @{{ $conversation->user?->username }}</div>
          <div style="margin-top:4px;color:#64748b;font-size:13px">
            Amount: ${{ number_format((float) $conversation->amount, 2) }}
            @if($conversation->latestMessage)
              &middot; {{ \Illuminate\Support\Str::limit($conversation->latestMessage->body ?: 'Attachment', 60) }}
            @endif
          </div>
        </a>
      @empty
        <div style="color:#64748b">No wallet messages yet.</div>
      @endforelse
    </div>
    <div style="margin-top:12px">{{ $conversations->links() }}</div>
  </div>

  <div class="card">
    @if($selectedConversation)
      <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:12px">
        <div>
          <h2 id="thread-title" style="margin:0 0 6px">#{{ $selectedConversation->id }} {{ $selectedConversation->subject }}</h2>
          <div class="crumb" id="thread-meta">
            User: {{ $selectedConversation->user?->name }} @{{ $selectedConversation->user?->username }} &middot;
            Amount: ${{ number_format((float) $selectedConversation->amount, 2) }}
          </div>
        </div>
        <div id="thread-status">
          <span style="display:inline-block;padding:4px 8px;border-radius:999px;font-size:12px;{{ $selectedConversation->status === 'approved' ? 'background:#dcfce7;color:#166534' : ($selectedConversation->status === 'rejected' ? 'background:#fee2e2;color:#991b1b' : 'background:#fff7cc;color:#8a6d00') }}">
            {{ ucfirst($selectedConversation->status) }}
          </span>
        </div>
      </div>

      <div id="thread-messages" style="display:flex;flex-direction:column;gap:10px;margin-bottom:16px">
        @foreach($selectedConversation->messages->sortBy('created_at') as $message)
          <div style="padding:12px 14px;border-radius:16px;border:1px solid #dde4ef;background:{{ $message->sender_role === 'admin' ? '#ecfdf5' : ($message->sender_role === 'system' ? '#f8fafc' : '#eff6ff') }}">
            <div style="display:flex;justify-content:space-between;gap:12px;align-items:center">
              <strong>
                {{ $message->sender_role === 'admin' ? 'Admin' : ($message->sender_role === 'system' ? 'System' : 'User') }}
              </strong>
              <span class="crumb">{{ $message->created_at?->diffForHumans() }}</span>
            </div>
            @if($message->body)
              <div style="margin-top:8px;line-height:1.5">{{ $message->body }}</div>
            @endif
            @if($message->attachment_path)
              <div style="margin-top:10px">
                <a href="{{ asset('storage/'.$message->attachment_path) }}" target="_blank" rel="noreferrer">
                  <img src="{{ asset('storage/'.$message->attachment_path) }}" alt="attachment" style="max-width:260px;border-radius:14px;border:1px solid #dce3ec">
                </a>
              </div>
            @endif
          </div>
        @endforeach
      </div>

      <form method="POST" action="{{ route('admin.funding-requests.reply', $selectedConversation) }}" enctype="multipart/form-data">
        @csrf
        <label for="reply-body"><strong>Reply</strong></label>
        <textarea id="reply-body" name="body" rows="4" placeholder="Write your message to the user..." required></textarea>
        <div class="form-actions" style="margin-top:0;padding-top:0;border-top:none">
          <input type="file" name="attachment" accept="image/*">
          <button class="btn" type="submit">Send Reply</button>
        </div>
      </form>

      @if($selectedConversation->status === 'open')
        <div class="form-actions" style="margin-top:12px">
          <form class="inline" method="POST" action="{{ route('admin.funding-requests.approve', $selectedConversation) }}">@csrf <button class="btn btn-success" type="submit">Approve Funding</button></form>
          <form class="inline" method="POST" action="{{ route('admin.funding-requests.reject', $selectedConversation) }}">@csrf <button class="btn btn-danger" type="submit">Reject</button></form>
        </div>
      @endif

      <div id="thread-endpoint"
           data-thread-url="{{ route('admin.funding-requests.thread', $selectedConversation) }}"
           data-selected-id="{{ $selectedConversation->id }}"
           style="display:none"></div>
    @else
      <div style="padding:24px 0;color:#64748b">Select a message thread from the left to view and reply.</div>
    @endif
  </div>
</div>

@if($selectedConversation)
<script>
document.addEventListener('DOMContentLoaded', () => {
  const endpoint = document.getElementById('thread-endpoint');
  if (!endpoint) return;

  const threadUrl = endpoint.dataset.threadUrl;
  const messagesEl = document.getElementById('thread-messages');
  const statusEl = document.getElementById('thread-status');
  const metaEl = document.getElementById('thread-meta');
  const titleEl = document.getElementById('thread-title');

  const escapeHtml = (value) => String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

  const renderMessage = (message) => {
    const roleLabel = message.sender_role === 'admin'
      ? 'Admin'
      : message.sender_role === 'system'
        ? 'System'
        : 'User';
    const background = message.sender_role === 'admin'
      ? '#ecfdf5'
      : message.sender_role === 'system'
        ? '#f8fafc'
        : '#eff6ff';
    return `
      <div style="padding:12px 14px;border-radius:16px;border:1px solid #dde4ef;background:${background}">
        <div style="display:flex;justify-content:space-between;gap:12px;align-items:center">
          <strong>${escapeHtml(roleLabel)}</strong>
          <span class="crumb">${escapeHtml(message.created_at ?? '')}</span>
        </div>
        ${message.body ? `<div style="margin-top:8px;line-height:1.5">${escapeHtml(message.body)}</div>` : ''}
        ${message.attachment_url ? `<div style="margin-top:10px"><a href="${escapeHtml(message.attachment_url)}" target="_blank" rel="noreferrer"><img src="${escapeHtml(message.attachment_url)}" alt="attachment" style="max-width:260px;border-radius:14px;border:1px solid #dce3ec"></a></div>` : ''}
      </div>
    `;
  };

  const refreshThread = async () => {
    try {
      const response = await fetch(threadUrl, { headers: { 'Accept': 'application/json' } });
      if (!response.ok) return;
      const data = await response.json();
      if (titleEl) titleEl.textContent = `#${data.id} ${data.subject}`;
      if (metaEl) metaEl.textContent = `User: ${data.user?.name ?? 'User'} @${data.user?.username ?? ''} - Amount: $${Number(data.amount ?? 0).toFixed(2)}`;
      if (statusEl) {
        const status = String(data.status ?? 'open');
        const label = status.charAt(0).toUpperCase() + status.slice(1);
        const style = status === 'approved'
          ? 'background:#dcfce7;color:#166534'
          : status === 'rejected'
            ? 'background:#fee2e2;color:#991b1b'
            : 'background:#fff7cc;color:#8a6d00';
        statusEl.innerHTML = `<span style="display:inline-block;padding:4px 8px;border-radius:999px;font-size:12px;${style}">${label}</span>`;
      }
      if (messagesEl && Array.isArray(data.messages)) {
        messagesEl.innerHTML = data.messages.map(renderMessage).join('');
      }
    } catch (error) {
      console.error('Failed to refresh wallet thread', error);
    }
  };

  setInterval(refreshThread, 5000);
  refreshThread();
});
</script>
@endif
@endsection
