@extends('admin.layout')

@section('content')
<div class="content-header">
  <h1>Create User</h1>
  <div class="crumb">Admin / Users / Create</div>
</div>

<div class="card form-card">
  <form method="POST" action="{{ route('admin.users.store') }}">
    @csrf
    @include('admin.user_form')
  </form>
</div>
@endsection

