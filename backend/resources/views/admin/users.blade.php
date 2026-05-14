@extends('admin.layout')

@section('content')
<h2>Users</h2>
<div class="card">
<table>
  <thead><tr><th>ID</th><th>Name</th><th>Email</th><th>Wallet</th><th>Role</th><th>Status</th><th>Actions</th></tr></thead>
  <tbody>
  @foreach($users as $user)
    <tr>
      <td>{{ $user->id }}</td>
      <td>{{ $user->name }}</td>
      <td>{{ $user->email }}</td>
      <td>${{ number_format((float)$user->wallet_balance,2) }}</td>
      <td>{{ $user->is_admin ? 'Admin' : 'Player' }}</td>
      <td>{{ $user->is_active ? 'Active' : 'Suspended' }}</td>
      <td>
        <a class="btn btn-secondary" href="{{ route('admin.users.wallet.form', $user) }}">Wallet</a>
        @if(!$user->is_admin)
        <form class="inline" method="POST" action="{{ route('admin.users.toggle-status', $user) }}">
          @csrf
          <button class="btn {{ $user->is_active ? 'btn-danger' : '' }}" type="submit">{{ $user->is_active ? 'Suspend' : 'Activate' }}</button>
        </form>
        @endif
      </td>
    </tr>
  @endforeach
  </tbody>
</table>
</div>
{{ $users->links() }}
@endsection
