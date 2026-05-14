@extends('admin.layout')

@section('content')
<div class="content-header">
  <h1>Matches</h1>
  <div class="crumb">Admin / Match Monitoring</div>
</div>

<div class="card">
  <table>
    <thead><tr><th>ID</th><th>P1</th><th>P2</th><th>Winner</th><th>Mode</th><th>Bet</th><th>Status</th><th>Created</th></tr></thead>
    <tbody>
    @foreach($matches as $match)
      <tr>
        <td>#{{ $match->id }}</td>
        <td>{{ $match->player_1_id }}</td>
        <td>{{ $match->player_2_id ?? '-' }}</td>
        <td>{{ $match->winner_id ?? '-' }}</td>
        <td>{{ ucfirst($match->mode) }}</td>
        <td>${{ number_format((float)$match->bet_amount,2) }}</td>
        <td>
          <span style="display:inline-block;padding:4px 8px;border-radius:999px;font-size:12px;{{ $match->status === 'completed' ? 'background:#dcfce7;color:#166534' : ($match->status === 'cancelled' ? 'background:#fee2e2;color:#991b1b' : ($match->status === 'active' ? 'background:#dbeafe;color:#1e40af' : 'background:#f1f5f9;color:#334155')) }}">
            {{ ucfirst($match->status) }}
          </span>
        </td>
        <td>{{ $match->created_at }}</td>
      </tr>
    @endforeach
    </tbody>
  </table>
</div>

<div style="margin-top:12px">{{ $matches->links() }}</div>
@endsection
