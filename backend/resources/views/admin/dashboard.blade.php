@extends('admin.layout')

@section('content')
<h2>Dashboard</h2>
<div class="grid">
  <div class="stat"><strong>Total Users</strong><div>{{ $stats['users'] }}</div></div>
  <div class="stat"><strong>Active Users</strong><div>{{ $stats['active_users'] }}</div></div>
  <div class="stat"><strong>Total Matches</strong><div>{{ $stats['matches'] }}</div></div>
  <div class="stat"><strong>Active Matches</strong><div>{{ $stats['active_matches'] }}</div></div>
  <div class="stat"><strong>Pending Funding</strong><div>{{ $stats['pending_funding_requests'] }}</div></div>
  <div class="stat"><strong>Total Wagered</strong><div>${{ number_format($stats['total_wagered'], 2) }}</div></div>
</div>
@endsection
