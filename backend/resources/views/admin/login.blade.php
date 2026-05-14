@extends('admin.layout')

@section('content')
<div class="card" style="max-width:420px;margin:40px auto;">
  <h2>Admin Login</h2>
  <form method="POST" action="{{ route('admin.login.submit') }}">
    @csrf
    <label>Email</label>
    <input type="email" name="email" value="{{ old('email') }}" required>
    <label>Password</label>
    <input type="password" name="password" required>
    <button class="btn" type="submit">Login</button>
  </form>
</div>
@endsection
