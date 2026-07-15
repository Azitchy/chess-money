<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProgressionEvent extends Model
{
    protected $fillable = [
        'user_id',
        'activity_type',
        'activity_key',
        'details',
    ];

    protected function casts(): array
    {
        return ['details' => 'array'];
    }
}
