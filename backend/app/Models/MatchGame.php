<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MatchGame extends Model
{
    protected $table = 'matches';

    protected $fillable = [
        'player_1_id',
        'challenged_user_id',
        'player_2_id',
        'winner_id',
        'bet_amount',
        'mode',
        'time_control',
        'status',
        'moves',
        'result_claims',
        'current_turn_user_id',
        'started_at',
        'accepted_at',
        'ended_at',
        'rejected_at',
    ];

    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'accepted_at' => 'datetime',
            'ended_at' => 'datetime',
            'rejected_at' => 'datetime',
            'moves' => 'array',
            'result_claims' => 'array',
            'bet_amount' => 'float',
        ];
    }

    public function playerOne(): BelongsTo
    {
        return $this->belongsTo(User::class, 'player_1_id');
    }

    public function playerTwo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'player_2_id');
    }
}
