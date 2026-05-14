@extends('admin.layout')

@section('content')
<h2>Matches</h2>
<div class="card">
<table>
  <thead><tr><th>ID</th><th>P1</th><th>P2</th><th>Winner</th><th>Mode</th><th>Bet</th><th>Status</th><th>Created</th></tr></thead>
  <tbody>
  @foreach($matches as $match)
    <tr>
      <td>{{ $match->id }}</td>
      <td>{{ $match->player_1_id }}</td>
      <td>{{ $match->player_2_id }}</td>
      <td>{{ $match->winner_id ?? '-' }}</td>
      <td>{{ $match->mode }}</td>
      <td>${{ number_format((float)$match->bet_amount,2) }}</td>
      <td>{{ $match->status }}</td>
      <td>{{ $match->created_at }}</td>
    </tr>
  @endforeach
  </tbody>
</table>
</div>
{{ $matches->links() }}
@endsection
