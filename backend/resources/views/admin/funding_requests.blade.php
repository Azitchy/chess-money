@extends('admin.layout')

@section('content')
<h2>Funding Requests</h2>
<div class="card">
<table>
  <thead><tr><th>ID</th><th>User</th><th>Amount</th><th>Status</th><th>Note</th><th>Action</th></tr></thead>
  <tbody>
  @foreach($requests as $requestItem)
    <tr>
      <td>{{ $requestItem->id }}</td>
      <td>{{ $requestItem->user?->email }}</td>
      <td>${{ number_format((float)$requestItem->amount,2) }}</td>
      <td>{{ $requestItem->status }}</td>
      <td>{{ $requestItem->note }}</td>
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
{{ $requests->links() }}
@endsection
