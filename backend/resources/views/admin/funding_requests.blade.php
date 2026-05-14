@extends('admin.layout')

@section('content')
<div class="content-header">
  <h1>Funding Requests</h1>
  <div class="crumb">Admin / Wallet Funding</div>
</div>

<div class="card">
  <table>
    <thead><tr><th>ID</th><th>User</th><th>Amount</th><th>Status</th><th>Note</th><th>Action</th></tr></thead>
    <tbody>
    @foreach($requests as $requestItem)
      <tr>
        <td>{{ $requestItem->id }}</td>
        <td>{{ $requestItem->user?->email }}</td>
        <td>${{ number_format((float)$requestItem->amount,2) }}</td>
        <td>
          <span style="display:inline-block;padding:4px 8px;border-radius:999px;font-size:12px;{{ $requestItem->status === 'approved' ? 'background:#dcfce7;color:#166534' : ($requestItem->status === 'rejected' ? 'background:#fee2e2;color:#991b1b' : 'background:#fff7cc;color:#8a6d00') }}">
            {{ ucfirst($requestItem->status) }}
          </span>
        </td>
        <td>{{ $requestItem->note ?: '-' }}</td>
        <td>
          @if($requestItem->status === 'pending')
          <form class="inline" method="POST" action="{{ route('admin.funding-requests.approve', $requestItem) }}">@csrf <button class="btn" type="submit">Approve</button></form>
          <form class="inline" method="POST" action="{{ route('admin.funding-requests.reject', $requestItem) }}">@csrf <button class="btn btn-danger" type="submit">Reject</button></form>
          @endif
        </td>
      </tr>
    @endforeach
    </tbody>
  </table>
</div>

<div style="margin-top:12px">{{ $requests->links() }}</div>
@endsection
