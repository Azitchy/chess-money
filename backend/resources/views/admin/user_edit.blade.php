@extends('admin.layout')

@section('content')
<div class="content-header">
  <h1>Edit User #{{ $user->id }}</h1>
  <div class="crumb">Admin / Users / Edit</div>
</div>

<div class="card form-card">
  <div class="form-summary">
    <strong>{{ $user->name }}</strong>
    <span>Wallet: ${{ number_format((float) $user->wallet_balance, 2) }}</span>
    <span>{{ $user->isCurrentlyOnline() ? 'Online now' : 'Offline' }}</span>
  </div>
  <form method="POST" action="{{ route('admin.users.update', $user) }}">
    @csrf
    @method('PUT')
    @include('admin.user_form', ['user' => $user])
  </form>
</div>
@endsection

