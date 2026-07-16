<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PlatformSetting extends Model
{
    protected $fillable = [
        'setting_key',
        'setting_value',
    ];

    public static function getValue(string $key, mixed $default = null): mixed
    {
        $setting = static::query()->where('setting_key', $key)->first();

        return $setting?->setting_value ?? $default;
    }

    public static function setValue(string $key, mixed $value): self
    {
        return static::updateOrCreate(
            ['setting_key' => $key],
            ['setting_value' => is_scalar($value) ? (string) $value : json_encode($value)]
        );
    }
}
