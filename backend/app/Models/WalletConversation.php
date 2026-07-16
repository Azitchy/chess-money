<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class WalletConversation extends Model
{
    protected $fillable = [
        'user_id',
        'conversation_type',
        'amount',
        'subject',
        'status',
        'last_message_at',
    ];

    protected function casts(): array
    {
        return [
            'conversation_type' => 'string',
            'amount' => 'decimal:2',
            'last_message_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(WalletMessage::class);
    }

    public function latestMessage(): HasOne
    {
        return $this->hasOne(WalletMessage::class)->latestOfMany();
    }
}
