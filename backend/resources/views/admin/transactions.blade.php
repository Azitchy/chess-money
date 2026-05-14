@extends('admin.layout')

@section('content')
<h2>Wallet Transactions</h2>
<div class="card">
<table>
  <thead><tr><th>ID</th><th>User</th><th>Amount</th><th>Type</th><th>Status</th><th>Description</th><th>Created</th></tr></thead>
  <tbody>
  @foreach($transactions as $txn)
    <tr>
      <td>{{ $txn->id }}</td>
      <td>{{ $txn->user_id }}</td>
      <td>${{ number_format((float)$txn->amount,2) }}</td>
      <td>{{ $txn->type }}</td>
      <td>{{ $txn->status }}</td>
      <td>{{ $txn->description }}</td>
      <td>{{ $txn->created_at }}</td>
    </tr>
  @endforeach
  </tbody>
</table>
</div>
{{ $transactions->links() }}
@endsection
