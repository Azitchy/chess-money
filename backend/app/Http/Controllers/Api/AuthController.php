<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'username' => ['nullable', 'string', 'max:255', 'unique:users,username'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone_number' => ['nullable', 'string', 'max:50'],
            'password' => ['required', 'string', 'min:8'],
        ]);

        $data['username'] = $data['username'] ?? $this->generateUsername(
            $data['email'],
            $data['phone_number'] ?? null
        );
        $user = User::create($data);
        $plainToken = Str::random(60);
        $user->api_token = hash('sha256', $plainToken);
        $user->is_online = true;
        $user->last_seen_at = now();
        $user->save();

        return response()->json(['token' => $plainToken, 'user' => $user], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'identifier' => ['required', 'string'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $data['identifier'])
            ->orWhere('phone_number', $data['identifier'])
            ->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            return response()->json(['message' => 'Invalid credentials'], 422);
        }

        if (! $user->is_active) {
            return response()->json(['message' => 'Account is suspended'], 403);
        }

        $plainToken = Str::random(60);
        $user->api_token = hash('sha256', $plainToken);
        $user->is_online = true;
        $user->last_seen_at = now();
        $user->save();

        return response()->json(['token' => $plainToken, 'user' => $user]);
    }

    public function googleLogin(Request $request)
    {
        $data = $request->validate([
            'id_token' => ['required', 'string'],
        ]);

        $clientId = config('services.google.client_id');
        if (blank($clientId)) {
            return response()->json(['message' => 'Google login is not configured'], 500);
        }

        $response = Http::acceptJson()->get('https://oauth2.googleapis.com/tokeninfo', [
            'id_token' => $data['id_token'],
        ]);

        if (! $response->successful()) {
            return response()->json(['message' => 'Invalid Google login'], 422);
        }

        $payload = $response->json();
        if (($payload['aud'] ?? null) !== $clientId) {
            return response()->json(['message' => 'Invalid Google login'], 422);
        }

        if (($payload['email_verified'] ?? 'false') !== 'true') {
            return response()->json(['message' => 'Google account email is not verified'], 422);
        }

        $email = $payload['email'] ?? null;
        if (! is_string($email) || $email === '') {
            return response()->json(['message' => 'Invalid Google login'], 422);
        }

        $googleId = $payload['sub'] ?? null;
        if (! is_string($googleId) || $googleId === '') {
            return response()->json(['message' => 'Invalid Google login'], 422);
        }
        $name = $payload['name'] ?? $payload['email'] ?? 'Google User';

        $user = User::where('google_id', $googleId)
            ->orWhere('email', $email)
            ->first();

        if (! $user) {
            $user = User::create([
                'name' => $name,
                'username' => $this->generateUsername($email, $googleId),
                'email' => $email,
                'phone_number' => null,
                'google_id' => $googleId,
                'password' => Str::random(40),
                'email_verified_at' => now(),
                'is_active' => true,
            ]);
        } else {
            if (! $user->google_id) {
                $user->google_id = $googleId;
            }
            if (! $user->email_verified_at) {
                $user->email_verified_at = now();
            }
            if (! $user->is_active) {
                return response()->json(['message' => 'Account is suspended'], 403);
            }
            $user->save();
        }

        $plainToken = Str::random(60);
        $user->api_token = hash('sha256', $plainToken);
        $user->is_online = true;
        $user->last_seen_at = now();
        $user->save();

        return response()->json(['token' => $plainToken, 'user' => $user]);
    }

    public function me(Request $request)
    {
        return response()->json($request->user());
    }

    public function logout(Request $request)
    {
        $user = $request->user();
        $user->api_token = null;
        $user->is_online = false;
        $user->save();

        return response()->json(['message' => 'Logged out']);
    }

    private function generateUsername(string $email, ?string $fallback = null): string
    {
        $base = Str::slug(explode('@', $email)[0] ?? '');
        if ($base === '') {
            $base = 'user';
        }

        if ($fallback) {
            $fallbackSlug = Str::slug($fallback);
            if ($fallbackSlug !== '') {
                $base = $base.'-'.$fallbackSlug;
            }
        }

        $candidate = $base;
        $suffix = 1;
        while (User::where('username', $candidate)->exists()) {
            $candidate = $base.'-'.$suffix;
            $suffix++;
        }

        return $candidate;
    }
}
