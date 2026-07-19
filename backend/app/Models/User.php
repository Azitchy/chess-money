<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    use HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'username',
        'email',
        'phone_number',
        'google_id',
        'avatar_path',
        'address',
        'password',
        'wallet_balance',
        'rating',
        'level',
        'is_admin',
        'is_active',
        'is_online',
        'last_seen_at',
        'api_token',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'api_token',
        'avatar_path',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'wallet_balance' => 'decimal:2',
            'rating' => 'integer',
            'level' => 'integer',
            'is_admin' => 'boolean',
            'is_active' => 'boolean',
            'is_online' => 'boolean',
            'last_seen_at' => 'datetime',
            'last_notification_seen_at' => 'datetime',
        ];
    }

    public function walletTransactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class);
    }

    public function isCurrentlyOnline(): bool
    {
        return $this->is_active
            && $this->is_online
            && $this->api_token !== null;
    }
}
