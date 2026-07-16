@extends('admin.layout')

@section('content')
<div class="content-header">
  <h1>Dashboard</h1>
  <div class="crumb">Home / Dashboard</div>
</div>

<div class="stats-grid">
  <article class="stat-card stat-blue">
    <h3>{{ $stats['users'] }}</h3>
    <p>Total Users</p>
    <span class="more">More info</span>
  </article>
  <article class="stat-card stat-green">
    <h3>{{ $stats['active_users'] }}</h3>
    <p>Active Users</p>
    <span class="more">More info</span>
  </article>
  <article class="stat-card stat-yellow">
    <h3>{{ $stats['pending_funding_requests'] }}</h3>
    <p>Pending Load Balance</p>
    <span class="more">More info</span>
  </article>
  <article class="stat-card stat-red">
    <h3>{{ $stats['active_matches'] }}</h3>
    <p>Active Matches</p>
    <span class="more">More info</span>
  </article>
</div>

<div class="two-col">
  <div class="card">
    <h3 style="margin-top:0">Sales Value</h3>
    <div class="chart-mock">
      <div class="chart-wave"></div>
    </div>
  </div>
  <div class="mini-panel">
    <h3 style="margin:0 0 8px">Platform Pulse</h3>
    <p style="margin:0 0 6px;opacity:.9">Total matches: {{ $stats['matches'] }}</p>
    <p style="margin:0;opacity:.9">Total wagered: ${{ number_format($stats['total_wagered'], 2) }}</p>
    <div class="mini-grid">
      <div class="mini-box"></div>
      <div class="mini-box"></div>
      <div class="mini-box"></div>
    </div>
  </div>
</div>

<div class="card" id="admin-send-notification" style="margin-top:16px">
  <h3 style="margin-top:0">Admin Notes</h3>
  <p style="margin:0;color:#556070">Monitor suspicious betting loops, delayed settlements, and sudden wallet spikes from this dashboard.</p>
</div>

<div class="card" style="margin-top:16px">
  <h3 style="margin-top:0">Send Notification</h3>
  <p style="margin:0 0 14px;color:#556070">Send an offer, message, or announcement to every user in real time.</p>
  @php
    $editing = $editingNotification ?? null;
    $notificationFormAction = $editing
        ? route('admin.notifications.update', $editing)
        : route('admin.notifications.store');
    $notificationMethod = $editing ? 'PUT' : 'POST';
  @endphp
  <form method="POST" action="{{ $notificationFormAction }}">
    @csrf
    @if($editing)
      @method('PUT')
    @endif
    <div class="form-grid">
      <label>
        Type
        <select name="notice_type">
          @foreach(['offer', 'message', 'update', 'alert'] as $type)
            <option value="{{ $type }}" @selected(old('notice_type', $editing->notice_type ?? 'offer') === $type)>{{ ucfirst($type) }}</option>
          @endforeach
        </select>
      </label>
      <label>
        Title
        <input name="title" value="{{ old('title', $editing->title ?? '') }}" placeholder="Weekend Offer">
      </label>
      <label class="field-full">
        Message
        <textarea name="body" rows="4" placeholder="Write the notification message">{{ old('body', $editing->body ?? '') }}</textarea>
      </label>
      <label>
        Action label
        <input name="action_label" value="{{ old('action_label', $editing->action_label ?? '') }}" placeholder="View offer">
      </label>
      <label>
        Action URL
        <input name="action_url" value="{{ old('action_url', $editing->action_url ?? '') }}" placeholder="app://wallet/load-balance">
      </label>
      @if($editing)
        <label class="check-field">
          Active
          <span class="check-row">
            <input type="checkbox" name="is_active" value="1" @checked(old('is_active', $editing->is_active))>
            <span>Show to users</span>
          </span>
        </label>
      @endif
    </div>
    <div class="form-actions">
      <button class="btn" type="submit">{{ $editing ? 'Update Notification' : 'Send Notification' }}</button>
      @if($editing)
        <a class="btn btn-secondary" href="{{ route('admin.dashboard') }}">Cancel</a>
      @endif
    </div>
  </form>
</div>

<div class="card" style="margin-top:16px">
  <h3 style="margin-top:0">Recent Notifications</h3>
  <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th>Type</th>
          <th>Title</th>
          <th>Message</th>
          <th>Status</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        @forelse($recentNotifications as $notification)
          <tr>
            <td>{{ $notification->notice_type }}</td>
            <td>{{ $notification->title }}</td>
            <td>{{ \Illuminate\Support\Str::limit($notification->body, 80) }}</td>
            <td>{{ $notification->is_active ? 'Active' : 'Inactive' }}</td>
            <td>
              <div class="actions">
                <a class="btn btn-secondary" href="{{ route('admin.dashboard', ['notification' => $notification->id]) }}">Edit</a>
                <form class="inline" method="POST" action="{{ route('admin.notifications.delete', $notification) }}" onsubmit="return confirm('Delete this notification?')">
                  @csrf
                  @method('DELETE')
                  <button class="btn btn-danger" type="submit">Delete</button>
                </form>
              </div>
            </td>
          </tr>
        @empty
          <tr><td colspan="5">No notifications sent yet.</td></tr>
        @endforelse
      </tbody>
    </table>
  </div>
</div>

<div class="card" id="admin-match-commission" style="margin-top:16px;max-width:520px">
  <h3 style="margin-top:0">Match Commission</h3>
  <p style="margin:0 0 12px;color:#556070">The winner payout is reduced by this percentage and the commission goes to the admin wallet.</p>
  <form method="POST" action="{{ route('admin.settings.commission') }}">
    @csrf
    <label for="commission_percent">Commission percent</label>
    <input
      id="commission_percent"
      name="commission_percent"
      type="number"
      min="0"
      max="100"
      step="0.01"
      value="{{ old('commission_percent', $commissionPercent) }}"
    >
    <div class="form-actions" style="padding-top:0;border-top:0;margin-top:0">
      <button class="btn" type="submit">Update Commission</button>
      <small>Current value: {{ number_format($commissionPercent, 2) }}%</small>
    </div>
  </form>
</div>
@endsection
