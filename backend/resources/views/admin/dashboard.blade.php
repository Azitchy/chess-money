@extends('admin.layout')

@section('content')
<div class="content-header">
  <h1>Dashboard</h1>
  <div class="crumb">Home / Dashboard</div>
</div>

<div class="stats-grid">
  <article class="stat-card stat-blue">
    <h3>{{ $stats['users'] }}</h3>
    <p>Total Users</p>
    <span class="more">More info</span>
  </article>
  <article class="stat-card stat-green">
    <h3>{{ $stats['active_users'] }}</h3>
    <p>Active Users</p>
    <span class="more">More info</span>
  </article>
  <article class="stat-card stat-yellow">
    <h3>{{ $stats['pending_funding_requests'] }}</h3>
    <p>Pending Funding</p>
    <span class="more">More info</span>
  </article>
  <article class="stat-card stat-red">
    <h3>{{ $stats['active_matches'] }}</h3>
    <p>Active Matches</p>
    <span class="more">More info</span>
  </article>
</div>

<div class="two-col">
  <div class="card">
    <h3 style="margin-top:0">Sales Value</h3>
    <div class="chart-mock">
      <div class="chart-wave"></div>
    </div>
  </div>
  <div class="mini-panel">
    <h3 style="margin:0 0 8px">Platform Pulse</h3>
    <p style="margin:0 0 6px;opacity:.9">Total matches: {{ $stats['matches'] }}</p>
    <p style="margin:0;opacity:.9">Total wagered: ${{ number_format($stats['total_wagered'], 2) }}</p>
    <div class="mini-grid">
      <div class="mini-box"></div>
      <div class="mini-box"></div>
      <div class="mini-box"></div>
    </div>
  </div>
</div>

<div class="card" style="margin-top:16px">
  <h3 style="margin-top:0">Admin Notes</h3>
  <p style="margin:0;color:#556070">Monitor suspicious betting loops, delayed settlements, and sudden wallet spikes from this dashboard.</p>
</div>

<div class="card" style="margin-top:16px;max-width:520px">
  <h3 style="margin-top:0">Match Commission</h3>
  <p style="margin:0 0 12px;color:#556070">The winner payout is reduced by this percentage and the commission goes to the admin wallet.</p>
  <form method="POST" action="{{ route('admin.settings.commission') }}">
    @csrf
    <label for="commission_percent">Commission percent</label>
    <input
      id="commission_percent"
      name="commission_percent"
      type="number"
      min="0"
      max="100"
      step="0.01"
      value="{{ old('commission_percent', $commissionPercent) }}"
    >
    <div class="form-actions" style="padding-top:0;border-top:0;margin-top:0">
      <button class="btn" type="submit">Update Commission</button>
      <small>Current value: {{ number_format($commissionPercent, 2) }}%</small>
    </div>
  </form>
</div>
@endsection
