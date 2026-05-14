<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Bet extends Model
{
    protected $fillable = [
        'match_id',
        'user_id',
        'amount',
        'status',
    ];
}
