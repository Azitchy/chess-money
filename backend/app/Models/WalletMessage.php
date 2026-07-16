<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletMessage extends Model
{
    protected $fillable = [
        'wallet_conversation_id',
        'sender_user_id',
        'sender_role',
        'body',
        'attachment_path',
        'attachment_name',
        'attachment_mime',
    ];

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(WalletConversation::class, 'wallet_conversation_id');
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_user_id');
    }
}
