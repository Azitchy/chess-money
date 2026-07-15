<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedInteger('rating')->default(0)->after('wallet_balance');
            $table->unsignedInteger('level')->default(0)->after('rating');
        });

        // Start the new progression system from the same baseline for everyone.
        DB::table('users')->update(['rating' => 0, 'level' => 0]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['rating', 'level']);
        });
    }
};
