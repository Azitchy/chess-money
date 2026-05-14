@extends('admin.layout')

@section('content')
<div class="login-shell">
  <div class="login-card">
    <div class="blob-a"></div>
    <div class="blob-b"></div>

    <div class="login-inner">
      <div class="logo-mark">Chess Game</div>
      <!-- <div class="logo-sub">Winner &amp; can </div> -->
      <div class="welcome">Welcome Back!</div>

      <form method="POST" action="{{ route('admin.login.submit') }}">
        @csrf
        <div class="field">
          <label>Email</label>
          <input class="line-input" type="email" name="email" value="{{ old('email') }}" required>
        </div>
        <div class="field">
          <label>Password</label>
          <input class="line-input" type="password" name="password" required>
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
