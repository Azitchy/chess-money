<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\WalletService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    private const WELCOME_BONUS_AMOUNT = 20.00;

    public function register(Request $request, WalletService $walletService)
    {
        $request->merge([
            'email' => Str::lower(trim((string) $request->input('email'))),
        ]);

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
        [$user, $plainToken] = DB::transaction(function () use ($data, $walletService) {
            $user = User::create($data);
            $this->grantWelcomeBonus($user, $walletService);

            return $this->issueLoginToken($user);
        });

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

    public function googleLogin(Request $request, WalletService $walletService)
    {
        $data = $request->validate([
            'id_token' => ['nullable', 'string', 'required_without:access_token'],
            'access_token' => ['nullable', 'string', 'required_without:id_token'],
        ]);

        $clientIds = collect(config('services.google.client_ids', []))
            ->filter()
            ->values()
            ->all();

        if (! empty($data['id_token'])) {
            if ($clientIds === []) {
                return response()->json(['message' => 'Google login is not configured'], 500);
            }

            $response = Http::acceptJson()->get('https://oauth2.googleapis.com/tokeninfo', [
                'id_token' => $data['id_token'],
            ]);
        } else {
            $response = Http::acceptJson()
                ->withToken($data['access_token'])
                ->get('https://openidconnect.googleapis.com/v1/userinfo');
        }

        if (! $response->successful()) {
            return response()->json(['message' => 'Invalid Google login'], 422);
        }

        $payload = $response->json();
        if (! empty($data['id_token']) && ! in_array(($payload['aud'] ?? null), $clientIds, true)) {
            return response()->json(['message' => 'Invalid Google login'], 422);
        }

        if (! $this->googleEmailIsVerified($payload)) {
            return response()->json(['message' => 'Google account email is not verified'], 422);
        }

        $payloadEmail = $payload['email'] ?? null;
        if (! is_string($payloadEmail) || trim($payloadEmail) === '') {
            return response()->json(['message' => 'Invalid Google login'], 422);
        }
        $email = Str::lower(trim($payloadEmail));

        $googleId = $payload['sub'] ?? null;
        if (! is_string($googleId) || $googleId === '') {
            return response()->json(['message' => 'Invalid Google login'], 422);
        }
        $name = $payload['name'] ?? $payload['email'] ?? 'Google User';

        $googleUser = User::where('google_id', $googleId)->first();
        $emailUser = User::whereRaw('LOWER(email) = ?', [$email])->first();

        if ($googleUser && $emailUser && ! $googleUser->is($emailUser)) {
            return response()->json([
                'message' => 'This Gmail address is already linked to another Google account.',
            ], 409);
        }

        $user = $googleUser ?? $emailUser;

        if (! $user) {
            [$user, $plainToken] = DB::transaction(function () use ($email, $googleId, $name, $walletService) {
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
                $this->grantWelcomeBonus($user, $walletService);

                return $this->issueLoginToken($user);
            });

            return response()->json(['token' => $plainToken, 'user' => $user]);
        }

        if ($user->google_id && $user->google_id !== $googleId) {
            return response()->json([
                'message' => 'This Gmail address is already linked to another Google account.',
            ], 409);
        }

        $user->google_id = $googleId;
        $user->email = $email;
        if (! $user->email_verified_at) {
            $user->email_verified_at = now();
        }
        if (! $user->is_active) {
            return response()->json(['message' => 'Account is suspended'], 403);
        }
        $user->save();

        [$user, $plainToken] = $this->issueLoginToken($user);

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

    private function grantWelcomeBonus(User $user, WalletService $walletService): void
    {
        $walletService->addFunds(
            $user,
            self::WELCOME_BONUS_AMOUNT,
            'deposit',
            'Welcome registration bonus'
        );
    }

    /**
     * @return array{0: User, 1: string}
     */
    private function issueLoginToken(User $user): array
    {
        $plainToken = Str::random(60);
        $user->api_token = hash('sha256', $plainToken);
        $user->is_online = true;
        $user->last_seen_at = now();
        $user->save();

        return [$user->fresh(), $plainToken];
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private function googleEmailIsVerified(array $payload): bool
    {
        $verified = $payload['email_verified'] ?? $payload['verified_email'] ?? false;

        if (is_bool($verified)) {
            return $verified;
        }

        if (is_int($verified)) {
            return $verified === 1;
        }

        if (is_string($verified)) {
            return in_array(Str::lower(trim($verified)), ['true', '1'], true);
        }

        return false;
    }
}
