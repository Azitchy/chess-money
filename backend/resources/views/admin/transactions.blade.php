@extends('admin.layout')

@section('content')
<div class="content-header">
  <h1>Wallet Transactions</h1>
  <div class="crumb">Admin / Transaction Ledger</div>
</div>

<div class="card">
  <table>
    <thead><tr><th>ID</th><th>User</th><th>Amount</th><th>Type</th><th>Status</th><th>Description</th><th>Created</th></tr></thead>
    <tbody>
    @foreach($transactions as $txn)
      <tr>
        <td>{{ $txn->id }}</td>
        <td>{{ $txn->user_id }}</td>
        <td style="font-weight:600;{{ (float)$txn->amount >= 0 ? 'color:#166534' : 'color:#991b1b' }}">${{ number_format((float)$txn->amount,2) }}</td>
        <td>{{ str_replace('_', ' ', ucfirst($txn->type)) }}</td>
        <td>{{ ucfirst($txn->status) }}</td>
        <td>{{ $txn->description ?: '-' }}</td>
        <td>{{ $txn->created_at }}</td>
      </tr>
    @endforeach
    </tbody>
  </table>
</div>

<div style="margin-top:12px">{{ $transactions->links() }}</div>
@endsection
