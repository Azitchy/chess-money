@extends('admin.layout')

@section('content')
<div class="content-header">
  <h1>Users</h1>
  <div class="header-actions">
    <div class="crumb">Admin / Users</div>
    <a class="btn btn-success" href="{{ route('admin.users.create') }}">+ Create User</a>
  </div>
</div>

<div class="card">
  <form class="toolbar" method="GET" action="{{ route('admin.users') }}">
    <input name="search" value="{{ request('search') }}" placeholder="Search name, username, or email">
    <button class="btn" type="submit">Search</button>
    @if(request('search'))<a class="btn btn-secondary" href="{{ route('admin.users') }}">Clear</a>@endif
  </form>
  <div class="table-wrap">
  <table>
    <thead>
      <tr><th>ID</th><th>Name / Username</th><th>Email</th><th>Rating</th><th>Level</th><th>Wallet</th><th>Role</th><th>Status</th><th>Actions</th></tr>
    </thead>
    <tbody>
    @foreach($users as $user)
      <tr>
        <td>{{ $user->id }}</td>
        <td><strong>{{ $user->name }}</strong><br><small>&#64;{{ $user->username }}</small></td>
        <td>{{ $user->email }}</td>
        <td>{{ $user->rating }}</td>
        <td>{{ $user->level }}</td>
        <td>${{ number_format((float)$user->wallet_balance,2) }}</td>
        <td>{{ $user->is_admin ? 'Admin' : 'Player' }}</td>
        <td>
          <span style="display:inline-block;padding:4px 8px;border-radius:999px;font-size:12px;{{ $user->is_active ? 'background:#dcfce7;color:#166534' : 'background:#fee2e2;color:#991b1b' }}">
            {{ $user->is_active ? 'Active' : 'Suspended' }}
          </span>
        </td>
        <td><div class="actions">
          <a class="btn btn-warning" href="{{ route('admin.users.edit', $user) }}">Edit</a>
          <a class="btn btn-secondary" href="{{ route('admin.users.wallet.form', $user) }}">Wallet</a>
          @if(!$user->is_admin)
          <form class="inline" method="POST" action="{{ route('admin.users.toggle-status', $user) }}">
            @csrf
            <button class="btn {{ $user->is_active ? 'btn-danger' : '' }}" type="submit">{{ $user->is_active ? 'Suspend' : 'Activate' }}</button>
          </form>
          @endif
          @if(auth()->id() !== $user->id)
          <form class="inline" method="POST" action="{{ route('admin.users.delete', $user) }}" onsubmit="return confirm('Delete this user? This permanently removes the account and related records.')">
            @csrf
            @method('DELETE')
            <button class="btn btn-danger" type="submit">Delete</button>
          </form>
          @endif
        </div></td>
      </tr>
    @endforeach
    </tbody>
  </table>
  </div>
</div>

<div style="margin-top:12px">{{ $users->links() }}</div>
@endsection
