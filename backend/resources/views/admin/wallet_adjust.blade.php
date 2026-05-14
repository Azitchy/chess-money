@extends('admin.layout')

@section('content')
<h2>Adjust Wallet: {{ $user->name }} ({{ $user->email }})</h2>
<div class="card" style="max-width:520px;">
  <form method="POST" action="{{ route('admin.users.wallet.adjust', $user) }}">
    @csrf
    <label>Action</label>
    <select name="action" required>
      <option value="add">Add funds</option>
      <option value="deduct">Deduct funds</option>
    </select>
    <label>Amount</label>
    <input type="number" step="0.01" name="amount" required>
    <label>Description</label>
    <input type="text" name="description" required>
    <button class="btn" type="submit">Submit</button>
  </form>
</div>
@endsection
