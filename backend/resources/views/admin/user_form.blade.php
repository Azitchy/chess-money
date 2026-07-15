@php($editing = isset($user))

<div class="form-grid">
  <label>
    Full name
    <input name="name" value="{{ old('name', $user->name ?? '') }}" required maxlength="255" autocomplete="name">
  </label>

  <label>
    Username (login)
    <input name="username" value="{{ old('username', $user->username ?? '') }}" required maxlength="255" autocomplete="username">
  </label>

  <label>
    Email address (login)
    <input type="email" name="email" value="{{ old('email', $user->email ?? '') }}" required maxlength="255" autocomplete="email">
  </label>

  <label>
    Contact number
    <input name="phone_number" value="{{ old('phone_number', $user->phone_number ?? '') }}" maxlength="50" autocomplete="tel">
  </label>

  <label class="field-full">
    Address
    <textarea name="address" rows="3" maxlength="1000">{{ old('address', $user->address ?? '') }}</textarea>
  </label>

  <label>
    Rating
    <input type="number" name="rating" value="{{ old('rating', $user->rating ?? 0) }}" required min="0" step="1">
  </label>

  <label>
    Level
    <input type="number" name="level" value="{{ old('level', $user->level ?? 0) }}" required min="0" step="1">
  </label>

  <label>
    Role
    <select name="role" required>
      <option value="player" @selected(old('role', isset($user) && $user->is_admin ? 'admin' : 'player') === 'player')>Player</option>
      <option value="admin" @selected(old('role', isset($user) && $user->is_admin ? 'admin' : 'player') === 'admin')>Administrator</option>
    </select>
  </label>

  <label class="check-field">
    Account status
    <input type="hidden" name="is_active" value="0">
    <span class="check-row">
      <input type="checkbox" name="is_active" value="1" @checked((bool) old('is_active', $user->is_active ?? true))>
      Active — user can log in
    </span>
  </label>

  <label>
    {{ $editing ? 'New password (optional)' : 'Password' }}
    <input type="password" name="password" {{ $editing ? '' : 'required' }} minlength="8" autocomplete="new-password">
    @if($editing)<small>Leave blank to keep the existing password.</small>@endif
  </label>

  <label>
    Confirm {{ $editing ? 'new ' : '' }}password
    <input type="password" name="password_confirmation" {{ $editing ? '' : 'required' }} minlength="8" autocomplete="new-password">
  </label>
</div>

<div class="form-actions">
  <button class="btn" type="submit">{{ $editing ? 'Save User Changes' : 'Create User' }}</button>
  <a class="btn btn-secondary" href="{{ route('admin.users') }}">Cancel</a>
</div>

