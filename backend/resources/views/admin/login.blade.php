@extends('admin.layout')

@section('content')
<div class="login-shell">
  <div class="login-card">
    <div class="blob-a"></div>
    <div class="blob-b"></div>

    <div class="login-inner">
      <div class="login-badge">Secure admin access</div>
      <div class="logo-mark">Chess Game</div>
      <div class="welcome">Welcome Back!</div>
      <p class="login-copy">
        Sign in to manage users, matches, wallets, and platform settings from one dashboard.
      </p>

      <form method="POST" action="{{ route('admin.login.submit') }}">
        @csrf
        <div class="field">
          <label for="email">Email</label>
          <input
            id="email"
            class="line-input"
            type="email"
            name="email"
            value="{{ old('email') }}"
            placeholder="admin@chessbet.local"
            autocomplete="email"
            required
          >
        </div>
        <div class="field">
          <label for="password">Password</label>
          <input
            id="password"
            class="line-input"
            type="password"
            name="password"
            placeholder="Your password"
            autocomplete="current-password"
            required
          >
        </div>
        <button class="sign-btn" type="submit">Sign in</button>
      </form>
    </div>

    <div class="login-foot">
      <!-- <a href="#">Term of use</a> &nbsp; | &nbsp; <a href="#">Privacy policy</a> -->
    </div>
  </div>
</div>
@endsection
