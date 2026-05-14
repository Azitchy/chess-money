@extends('admin.layout')

@section('content')
<div class="content-header">
  <h1>Adjust Wallet</h1>
  <div class="crumb">Admin / Users / Wallet</div>
</div>

<div class="card" style="max-width:620px;">
  <h3 style="margin-top:0">{{ $user->name }} <span style="color:#64748b;font-weight:400">({{ $user->email }})</span></h3>
  <p style="margin-top:0;color:#64748b">Current Balance: <strong>${{ number_format((float)$user->wallet_balance,2) }}</strong></p>

  <form method="POST" action="{{ route('admin.users.wallet.adjust', $user) }}">
    @csrf
    <label>Action</label>
    <select name="action" required>
      <option value="add">Add funds</option>
      <option value="deduct">Deduct funds</option>
    </select>

    <label>Amount</label>
    <input type="number" step="0.01" min="0.01" name="amount" required>

    <label>Description</label>
    <input type="text" name="description" placeholder="Example: Manual correction" required>

    <button class="btn" type="submit">Submit Wallet Update</button>
  </form>
</div>
@endsection
